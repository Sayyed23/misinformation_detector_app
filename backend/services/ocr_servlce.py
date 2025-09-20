"""
OCR Service for Text Extraction from Images
Handles image processing and text extraction using Google Vision API and Document AI
"""

import os
import asyncio
from typing import Dict, List, Optional, Tuple
from io import BytesIO
import base64

from google.cloud import vision
from google.cloud import documentai
import requests
from PIL import Image
import structlog

logger = structlog.get_logger()


class OCRService:
    """Service for extracting text from images using Google Cloud OCR services"""
    
    def __init__(self):
        self.project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        self.location = os.getenv("DOCUMENT_AI_LOCATION", "us")
        
        # Initialize clients
        self.vision_client = vision.ImageAnnotatorClient()
        self.documentai_client = documentai.DocumentProcessorServiceClient()
        
        # Document AI processor ID (would be configured per use case)
        self.processor_id = os.getenv("DOCUMENT_AI_PROCESSOR_ID")
        
    async def extract_text_from_image(self, image_url: str) -> Dict:
        """
        Extract text from image using Google Vision API
        Returns extracted text with confidence scores and metadata
        """
        try:
            logger.info("Starting OCR processing", image_url=image_url)
            
            # Download image
            image_data = await self._download_image(image_url)
            if not image_data:
                raise ValueError("Failed to download image")
            
            # Create Vision API request
            image = vision.Image(content=image_data)
            
            # Perform text detection
            response = self.vision_client.text_detection(image=image)
            
            if response.error.message:
                raise Exception(f"Vision API error: {response.error.message}")
            
            # Process results
            texts = response.text_annotations
            if not texts:
                return {
                    "text": "",
                    "confidence": 0.0,
                    "language": "unknown",
                    "blocks": [],
                    "processing_method": "vision_api"
                }
            
            # First annotation contains the full text
            full_text = texts[0].description
            
            # Extract individual text blocks with positions
            text_blocks = []
            for text in texts[1:]:  # Skip the first one (full text)
                vertices = [(vertex.x, vertex.y) for vertex in text.bounding_poly.vertices]
                text_blocks.append({
                    "text": text.description,
                    "bounding_box": vertices,
                    "confidence": self._estimate_confidence(text.description)
                })
            
            # Detect language
            detected_language = await self._detect_language(full_text)
            
            # Calculate overall confidence
            overall_confidence = self._calculate_overall_confidence(text_blocks)
            
            result = {
                "text": full_text.strip(),
                "confidence": overall_confidence,
                "language": detected_language,
                "blocks": text_blocks[:20],  # Limit to first 20 blocks
                "processing_method": "vision_api",
                "image_dimensions": None,  # Could extract from image
                "orientation": "normal"  # Could detect orientation
            }
            
            logger.info("OCR processing completed", 
                       text_length=len(full_text), 
                       confidence=overall_confidence,
                       blocks_count=len(text_blocks))
            
            return result
            
        except Exception as e:
            logger.error("OCR processing failed", error=str(e))
            return {
                "text": "",
                "confidence": 0.0,
                "language": "unknown", 
                "blocks": [],
                "processing_method": "failed",
                "error": str(e)
            }
    
    async def extract_text_with_document_ai(self, image_url: str, document_type: str = "general") -> Dict:
        """
        Extract text using Document AI for more specialized document processing
        Better for forms, tables, and structured documents
        """
        try:
            if not self.processor_id:
                logger.warning("Document AI processor not configured, falling back to Vision API")
                return await self.extract_text_from_image(image_url)
            
            logger.info("Starting Document AI processing", image_url=image_url)
            
            # Download image
            image_data = await self._download_image(image_url)
            if not image_data:
                raise ValueError("Failed to download image")
            
            # Determine MIME type
            mime_type = self._get_mime_type(image_url)
            
            # Create Document AI request
            name = f"projects/{self.project_id}/locations/{self.location}/processors/{self.processor_id}"
            
            # Create document object
            document = documentai.Document(
                content=image_data,
                mime_type=mime_type
            )
            
            # Create process request
            request = documentai.ProcessRequest(
                name=name,
                document=document
            )
            
            # Process document
            result = self.documentai_client.process_document(request=request)
            document = result.document
            
            # Extract text and metadata
            full_text = document.text
            
            # Extract structured information
            entities = []
            for entity in document.entities:
                entities.append({
                    "type": entity.type_,
                    "mention_text": entity.mention_text,
                    "confidence": entity.confidence,
                    "normalized_value": getattr(entity, 'normalized_value', None)
                })
            
            # Extract form fields
            form_fields = []
            for page in document.pages:
                for form_field in page.form_fields:
                    field_name = self._get_text(form_field.field_name, document.text)
                    field_value = self._get_text(form_field.field_value, document.text)
                    
                    form_fields.append({
                        "name": field_name,
                        "value": field_value,
                        "confidence": form_field.field_value.confidence
                    })
            
            # Extract tables
            tables = []
            for page in document.pages:
                for table in page.tables:
                    table_data = self._extract_table_data(table, document.text)
                    tables.append(table_data)
            
            result = {
                "text": full_text.strip(),
                "confidence": document.pages[0].blocks[0].confidence if document.pages else 0.0,
                "language": self._detect_language_from_document(document),
                "entities": entities[:10],  # Limit to first 10
                "form_fields": form_fields[:10],  # Limit to first 10
                "tables": tables[:5],  # Limit to first 5
                "processing_method": "document_ai",
                "document_type": document_type
            }
            
            logger.info("Document AI processing completed",
                       text_length=len(full_text),
                       entities_count=len(entities),
                       form_fields_count=len(form_fields),
                       tables_count=len(tables))
            
            return result
            
        except Exception as e:
            logger.error("Document AI processing failed", error=str(e))
            # Fallback to Vision API
            return await self.extract_text_from_image(image_url)
    
    async def extract_text_from_multiple_images(self, image_urls: List[str]) -> List[Dict]:
        """Process multiple images concurrently"""
        try:
            tasks = [self.extract_text_from_image(url) for url in image_urls]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            processed_results = []
            for i, result in enumerate(results):
                if isinstance(result, Exception):
                    logger.error(f"Failed to process image {i}", error=str(result))
                    processed_results.append({
                        "text": "",
                        "confidence": 0.0,
                        "language": "unknown",
                        "blocks": [],
                        "processing_method": "failed",
                        "error": str(result)
                    })
                else:
                    processed_results.append(result)
            
            return processed_results
            
        except Exception as e:
            logger.error("Batch OCR processing failed", error=str(e))
            return [{"text": "", "confidence": 0.0, "error": str(e)} for _ in image_urls]
    
    async def preprocess_image_for_ocr(self, image_url: str) -> str:
        """
        Preprocess image to improve OCR accuracy
        Returns URL of processed image (could be uploaded to Cloud Storage)
        """
        try:
            # Download original image
            image_data = await self._download_image(image_url)
            if not image_data:
                return image_url
            
            # Open image with PIL
            image = Image.open(BytesIO(image_data))
            
            # Apply preprocessing steps
            # 1. Convert to grayscale if needed
            if image.mode != 'L' and image.mode != 'RGB':
                image = image.convert('RGB')
            
            # 2. Resize if too large
            max_size = (2048, 2048)
            image.thumbnail(max_size, Image.Resampling.LANCZOS)
            
            # 3. Enhance contrast (simplified)
            from PIL import ImageEnhance
            enhancer = ImageEnhance.Contrast(image)
            image = enhancer.enhance(1.2)  # Slightly increase contrast
            
            # 4. Sharpen slightly
            sharpness_enhancer = ImageEnhance.Sharpness(image)
            image = sharpness_enhancer.enhance(1.1)
            
            # Convert back to bytes
            output = BytesIO()
            image.save(output, format='JPEG', quality=85)
            processed_data = output.getvalue()
            
            # In a real implementation, you would:
            # 1. Upload processed image to Cloud Storage
            # 2. Return the new URL
            # For now, return original URL
            
            logger.info("Image preprocessing completed", 
                       original_size=len(image_data),
                       processed_size=len(processed_data))
            
            return image_url  # Return original URL for now
            
        except Exception as e:
            logger.error("Image preprocessing failed", error=str(e))
            return image_url  # Return original URL on error
    
    async def _download_image(self, image_url: str) -> Optional[bytes]:
        """Download image from URL"""
        try:
            response = requests.get(image_url, timeout=30, stream=True)
            response.raise_for_status()
            
            # Check content type
            content_type = response.headers.get('content-type', '')
            if not content_type.startswith('image/'):
                logger.warning("URL does not point to an image", content_type=content_type)
                return None
            
            # Check file size (limit to 10MB)
            content_length = int(response.headers.get('content-length', 0))
            if content_length > 10 * 1024 * 1024:
                logger.warning("Image too large", size=content_length)
                return None
            
            return response.content
            
        except Exception as e:
            logger.error("Failed to download image", error=str(e))
            return None
    
    def _get_mime_type(self, image_url: str) -> str:
        """Determine MIME type from URL"""
        extension = image_url.lower().split('.')[-1]
        mime_types = {
            'jpg': 'image/jpeg',
            'jpeg': 'image/jpeg',
            'png': 'image/png',
            'gif': 'image/gif',
            'bmp': 'image/bmp',
            'webp': 'image/webp',
            'tiff': 'image/tiff',
            'pdf': 'application/pdf'
        }
        return mime_types.get(extension, 'image/jpeg')
    
    async def _detect_language(self, text: str) -> str:
        """Detect language of extracted text"""
        try:
            # Use Google Cloud Translation API for language detection
            from google.cloud import translate_v2 as translate
            
            translate_client = translate.Client()
            result = translate_client.detect_language(text)
            
            return result['language']
            
        except Exception as e:
            logger.error("Language detection failed", error=str(e))
            return "unknown"
    
    def _detect_language_from_document(self, document) -> str:
        """Extract language from Document AI result"""
        try:
            if document.pages and document.pages[0].detected_languages:
                return document.pages[0].detected_languages[0].language_code
            return "unknown"
        except:
            return "unknown"
    
    def _estimate_confidence(self, text: str) -> float:
        """Estimate confidence based on text characteristics"""
        if not text:
            return 0.0
        
        # Simple heuristic based on text length and character variety
        length_score = min(1.0, len(text) / 10.0)
        char_variety = len(set(text.lower())) / max(1, len(text))
        
        return min(0.95, (length_score * 0.6 + char_variety * 0.4))
    
    def _calculate_overall_confidence(self, text_blocks: List[Dict]) -> float:
        """Calculate overall confidence from individual blocks"""
        if not text_blocks:
            return 0.0
        
        confidences = [block.get('confidence', 0.0) for block in text_blocks]
        return sum(confidences) / len(confidences)
    
    def _get_text(self, text_segment, full_text: str) -> str:
        """Extract text from Document AI text segment"""
        try:
            if hasattr(text_segment, 'text_segments'):
                segments = text_segment.text_segments
                if segments:
                    start_index = segments[0].start_index
                    end_index = segments[0].end_index
                    return full_text[start_index:end_index]
            return ""
        except:
            return ""
    
    def _extract_table_data(self, table, full_text: str) -> Dict:
        """Extract table data from Document AI table object"""
        try:
            rows = []
            for row in table.body_rows:
                cells = []
                for cell in row.cells:
                    cell_text = self._get_text(cell.layout, full_text)
                    cells.append({
                        "text": cell_text,
                        "confidence": getattr(cell.layout, 'confidence', 0.0)
                    })
                rows.append(cells)
            
            return {
                "rows": rows,
                "row_count": len(rows),
                "column_count": len(rows[0]) if rows else 0
            }
            
        except Exception as e:
            logger.error("Table extraction failed", error=str(e))
            return {"rows": [], "row_count": 0, "column_count": 0}