"""
Claims Verification Router
Handles claim submission, verification, and result delivery
"""

import os
import uuid
import asyncio
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from io import BytesIO

from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Depends, BackgroundTasks
from pydantic import BaseModel, Field
from google.cloud import firestore, storage, pubsub_v1, tasks_v2
from google.cloud import vision, documentai, translate_v2 as translate, language_v1
import structlog

from services.ai_service import VertexAIService
from services.ocr_service import OCRService  
from services.knowledge_service import KnowledgeService
from services.harm_classifier import HarmClassificationService
from models.claim_models import ClaimSubmission, ClaimVerificationResult, Citation

logger = structlog.get_logger()
router = APIRouter()

# Initialize services (these will be created in the services directory)
vertex_ai = VertexAIService()
ocr_service = OCRService()
knowledge_service = KnowledgeService()
harm_classifier = HarmClassificationService()


class SubmitClaimRequest(BaseModel):
    """Request model for claim submission"""
    text: Optional[str] = Field(None, description="Text claim to verify")
    image_url: Optional[str] = Field(None, description="URL of image to verify")
    source_url: Optional[str] = Field(None, description="Source URL where claim was found")
    language: str = Field("en", description="Language of the claim (ISO 639-1)")
    priority: str = Field("normal", description="Processing priority: low, normal, high")


class ClaimVerificationResponse(BaseModel):
    """Response model for claim verification"""
    claim_id: str = Field(..., description="Unique identifier for the claim")
    verdict: str = Field(..., description="Verification verdict: true, false, misleading, unverified")
    confidence_score: float = Field(..., description="Confidence score (0.0 to 1.0)")
    harm_level: str = Field(..., description="Harm classification: harmless, basic, very_harmful")
    explanation: str = Field(..., description="Detailed explanation of the verdict")
    citations: List[Citation] = Field(..., description="Supporting citations (max 3)")
    processing_steps: Dict[str, Any] = Field(..., description="Breakdown of processing steps")
    suggested_actions: List[str] = Field(..., description="Recommended actions based on harm level")
    processed_at: datetime = Field(..., description="When the claim was processed")


@router.post("/submitClaim", response_model=Dict[str, str])
async def submit_claim(
    background_tasks: BackgroundTasks,
    text: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    source_url: Optional[str] = Form(None),
    language: str = Form("en"),
    priority: str = Form("normal"),
    user = Depends(lambda: None)  # Will be replaced with actual auth dependency
):
    """
    Submit a claim for verification
    Accepts either text or image input, queues for processing
    """
    try:
        # Validate input
        if not text and not image:
            raise HTTPException(status_code=400, detail="Either text or image must be provided")
        
        # Generate unique claim ID
        claim_id = str(uuid.uuid4())
        
        # Initialize Firestore client
        db = firestore.Client()
        
        # Process image upload if provided
        image_url = None
        extracted_text = None
        
        if image:
            # Upload image to Cloud Storage
            storage_client = storage.Client()
            bucket_name = os.getenv("STORAGE_BUCKET", "your-project-id.appspot.com")
            bucket = storage_client.bucket(bucket_name)
            
            # Create unique filename
            file_extension = image.filename.split('.')[-1] if '.' in image.filename else 'jpg'
            blob_name = f"claims/{claim_id}/image.{file_extension}"
            blob = bucket.blob(blob_name)
            
            # Upload file
            image_content = await image.read()
            blob.upload_from_string(
                image_content,
                content_type=image.content_type or "image/jpeg"
            )
            
            # Make blob publicly readable (consider security implications)
            blob.make_public()
            image_url = blob.public_url
            
            logger.info("Image uploaded", claim_id=claim_id, image_url=image_url)
        
        # Create claim record in Firestore
        claim_data = {
            "claim_id": claim_id,
            "user_id": user.get("uid") if user else "anonymous",
            "text": text,
            "image_url": image_url,
            "source_url": source_url,
            "language": language,
            "priority": priority,
            "status": "submitted",
            "submitted_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc)
        }
        
        # Store in Firestore
        db.collection("claims").document(claim_id).set(claim_data)
        
        # Queue for processing
        if priority == "high":
            # Process immediately for high priority
            background_tasks.add_task(process_claim_immediate, claim_id, claim_data)
        else:
            # Queue for batch processing
            await queue_claim_for_processing(claim_id, claim_data, priority)
        
        logger.info("Claim submitted successfully", claim_id=claim_id, priority=priority)
        
        return {
            "claim_id": claim_id,
            "status": "submitted",
            "message": "Claim submitted for verification"
        }
        
    except Exception as e:
        logger.error("Failed to submit claim", error=str(e), exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to submit claim: {str(e)}")


@router.get("/verifyClaim/{claim_id}", response_model=ClaimVerificationResponse)
async def verify_claim(claim_id: str, user = Depends(lambda: None)):
    """
    Get verification results for a specific claim
    Returns comprehensive verification data with explanations
    """
    try:
        # Get claim from Firestore
        db = firestore.Client()
        claim_doc = db.collection("claims").document(claim_id).get()
        
        if not claim_doc.exists:
            raise HTTPException(status_code=404, detail="Claim not found")
        
        claim_data = claim_doc.to_dict()
        
        # Check if user has access to this claim
        if user and claim_data.get("user_id") != user.get("uid"):
            # Allow access if claim is public or user is admin
            if not claim_data.get("is_public", False):
                raise HTTPException(status_code=403, detail="Access denied")
        
        # Check if verification is complete
        if claim_data.get("status") != "completed":
            return {
                "claim_id": claim_id,
                "status": claim_data.get("status", "processing"),
                "message": "Verification in progress"
            }
        
        # Get verification results
        verification_doc = db.collection("verifications").document(claim_id).get()
        if not verification_doc.exists:
            raise HTTPException(status_code=404, detail="Verification results not found")
        
        verification_data = verification_doc.to_dict()
        
        # Convert to response model
        response = ClaimVerificationResponse(**verification_data)
        
        logger.info("Verification results retrieved", claim_id=claim_id)
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to get verification results", claim_id=claim_id, error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve verification results")


@router.get("/claims/history")
async def get_user_claim_history(
    user = Depends(lambda: None),
    limit: int = 50,
    offset: int = 0
):
    """Get user's claim verification history"""
    try:
        if not user:
            raise HTTPException(status_code=401, detail="Authentication required")
        
        db = firestore.Client()
        
        # Query user's claims
        claims_query = (
            db.collection("claims")
            .where("user_id", "==", user["uid"])
            .order_by("submitted_at", direction=firestore.Query.DESCENDING)
            .limit(limit)
            .offset(offset)
        )
        
        claims = []
        for doc in claims_query.stream():
            claim_data = doc.to_dict()
            claims.append({
                "claim_id": claim_data["claim_id"],
                "text": claim_data.get("text", "")[:100] + "..." if claim_data.get("text", "") else None,
                "status": claim_data["status"],
                "submitted_at": claim_data["submitted_at"],
                "verdict": claim_data.get("verdict"),
                "confidence_score": claim_data.get("confidence_score"),
                "harm_level": claim_data.get("harm_level")
            })
        
        return {
            "claims": claims,
            "total": len(claims),
            "limit": limit,
            "offset": offset
        }
        
    except Exception as e:
        logger.error("Failed to get user history", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve claim history")


# Background processing functions

async def queue_claim_for_processing(claim_id: str, claim_data: Dict, priority: str):
    """Queue claim for background processing using Cloud Tasks or Pub/Sub"""
    try:
        # Use Pub/Sub for asynchronous processing
        publisher = pubsub_v1.PublisherClient()
        project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        topic_path = publisher.topic_path(project_id, "claim-processing")
        
        # Prepare message
        message_data = {
            "claim_id": claim_id,
            "priority": priority,
            "submitted_at": claim_data["submitted_at"].isoformat()
        }
        
        # Publish message
        future = publisher.publish(
            topic_path,
            str(message_data).encode("utf-8"),
            claim_id=claim_id,
            priority=priority
        )
        
        logger.info("Claim queued for processing", claim_id=claim_id, message_id=future.result())
        
    except Exception as e:
        logger.error("Failed to queue claim", claim_id=claim_id, error=str(e))
        # Fallback to immediate processing if queueing fails
        await process_claim_immediate(claim_id, claim_data)


async def process_claim_immediate(claim_id: str, claim_data: Dict):
    """Process claim immediately for high-priority requests"""
    try:
        logger.info("Starting immediate claim processing", claim_id=claim_id)
        
        # Update status
        db = firestore.Client()
        db.collection("claims").document(claim_id).update({
            "status": "processing",
            "updated_at": datetime.now(timezone.utc)
        })
        
        # Step 1: Extract text if image provided
        claim_text = claim_data.get("text", "")
        processing_steps = {"steps": []}
        
        if claim_data.get("image_url") and not claim_text:
            logger.info("Starting OCR processing", claim_id=claim_id)
            ocr_result = await ocr_service.extract_text_from_image(claim_data["image_url"])
            claim_text = ocr_result["text"]
            processing_steps["steps"].append({
                "step": "ocr",
                "confidence": ocr_result["confidence"],
                "extracted_text_length": len(claim_text)
            })
        
        if not claim_text:
            raise ValueError("No text found in claim or extracted from image")
        
        # Step 2: Translate if not English
        original_language = claim_data.get("language", "en")
        if original_language != "en":
            logger.info("Translating claim text", claim_id=claim_id, language=original_language)
            translated_text = await translate_claim_text(claim_text, original_language, "en")
            processing_steps["steps"].append({
                "step": "translation",
                "original_language": original_language,
                "translated_length": len(translated_text)
            })
            claim_text = translated_text
        
        # Step 3: Claim detection and extraction
        logger.info("Running claim detection", claim_id=claim_id)
        claims_detected = await vertex_ai.detect_claims(claim_text)
        processing_steps["steps"].append({
            "step": "claim_detection",
            "claims_found": len(claims_detected)
        })
        
        # Step 4: Knowledge retrieval
        logger.info("Searching knowledge base", claim_id=claim_id)
        relevant_sources = await knowledge_service.search_relevant_sources(claim_text, claims_detected)
        processing_steps["steps"].append({
            "step": "knowledge_retrieval", 
            "sources_found": len(relevant_sources)
        })
        
        # Step 5: Verification
        logger.info("Running claim verification", claim_id=claim_id)
        verification_result = await vertex_ai.verify_claim(claim_text, relevant_sources)
        processing_steps["steps"].append({
            "step": "verification",
            "verdict": verification_result["verdict"],
            "confidence": verification_result["confidence"]
        })
        
        # Step 6: Harm classification
        logger.info("Classifying harm level", claim_id=claim_id)
        harm_result = await harm_classifier.classify_harm(claim_text, verification_result["verdict"])
        processing_steps["steps"].append({
            "step": "harm_classification",
            "harm_level": harm_result["level"]
        })
        
        # Step 7: Generate explanation
        logger.info("Generating explanation", claim_id=claim_id)
        explanation = await vertex_ai.generate_explanation(
            claim_text, 
            verification_result, 
            relevant_sources[:3]  # Top 3 sources
        )
        
        # Step 8: Prepare final result
        final_result = ClaimVerificationResponse(
            claim_id=claim_id,
            verdict=verification_result["verdict"],
            confidence_score=verification_result["confidence"],
            harm_level=harm_result["level"],
            explanation=explanation["text"],
            citations=relevant_sources[:3],  # Convert to Citation models
            processing_steps=processing_steps,
            suggested_actions=harm_result["suggested_actions"],
            processed_at=datetime.now(timezone.utc)
        )
        
        # Save results to Firestore
        db.collection("verifications").document(claim_id).set(final_result.dict())
        db.collection("claims").document(claim_id).update({
            "status": "completed",
            "verdict": verification_result["verdict"],
            "confidence_score": verification_result["confidence"],
            "harm_level": harm_result["level"],
            "updated_at": datetime.now(timezone.utc)
        })
        
        logger.info("Claim processing completed", claim_id=claim_id, verdict=verification_result["verdict"])
        
    except Exception as e:
        logger.error("Failed to process claim", claim_id=claim_id, error=str(e), exc_info=True)
        
        # Update status to failed
        db = firestore.Client()
        db.collection("claims").document(claim_id).update({
            "status": "failed",
            "error": str(e),
            "updated_at": datetime.now(timezone.utc)
        })


async def translate_claim_text(text: str, source_lang: str, target_lang: str) -> str:
    """Translate claim text using Google Translate API"""
    try:
        translate_client = translate.Client()
        
        result = translate_client.translate(
            text,
            source_language=source_lang,
            target_language=target_lang
        )
        
        return result['translatedText']
        
    except Exception as e:
        logger.error("Translation failed", error=str(e))
        return text  # Return original text if translation fails