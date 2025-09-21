"""
Claims Verification Router
Handles claim submission, verification, and result delivery
"""

import os
import uuid
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any

from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Depends, BackgroundTasks
from pydantic import BaseModel, Field
from google.cloud import pubsub_v1, translate_v2 as translate
import structlog

from backend.services.firebase import firebase_auth, firebase_db, firebase_storage
from backend.services.al_serwce import VertexAIService
from backend.services.ocr_servlce import OCRService
from backend.services.knowledge_service import KnowledgeService
from backend.services.harm_service import HarmClassifier

router = APIRouter()
logger = structlog.get_logger()

# Initialize services
ocr_service = OCRService()
vertex_ai = VertexAIService()
knowledge_service = KnowledgeService()
harm_classifier = HarmClassifier()


# ------------------ MODELS ------------------

class Citation(BaseModel):
    url: str
    title: str
    snippet: str


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


# ------------------ ROUTES ------------------

@router.post("/submitClaim", response_model=Dict[str, str])
async def submit_claim(
    background_tasks: BackgroundTasks,
    text: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    source_url: Optional[str] = Form(None),
    language: str = Form("en"),
    priority: str = Form("normal"),
    user = Depends(lambda: None)  # Replace with actual auth
):
    """Submit a claim for verification (text or image)."""

    if not text and not image:
        raise HTTPException(status_code=400, detail="Either text or image must be provided")

    # Generate unique claim ID
    claim_id = str(uuid.uuid4())
    db = firebase_db

    # Process image upload
    image_url = None
    if image:
        file_extension = image.filename.split('.')[-1] if '.' in image.filename else 'jpg'
        blob_name = f"claims/{claim_id}/image.{file_extension}"
        image_content = await image.read()
        blob = firebase_storage.blob(blob_name)
        blob.upload_from_string(
            image_content,
            content_type=image.content_type or "image/jpeg"
        )
        blob.make_public()
        image_url = blob.public_url
        logger.info("Image uploaded", claim_id=claim_id, image_url=image_url)

    # Save claim
    claim_data = {
        "claim_id": claim_id,
        "text": text,
        "image_url": image_url,
        "source_url": source_url,
        "language": language,
        "priority": priority,
        "status": "submitted",
        "submitted_at": datetime.now(timezone.utc),
        "user_id": user["uid"] if user and "uid" in user else None
    }
    db.collection("claims").document(claim_id).set(claim_data)

    if priority == "high":
        background_tasks.add_task(process_claim_immediate, claim_id, claim_data)
    else:
        await queue_claim_for_processing(claim_id, claim_data, priority)

    return {
        "claim_id": claim_id,
        "status": "submitted",
        "message": "Claim submitted for verification"
    }


@router.get("/verifyClaim/{claim_id}", response_model=ClaimVerificationResponse)
async def verify_claim(claim_id: str, user = Depends(lambda: None)):
    """Get verification results for a specific claim."""

    db = firebase_db
    claim_doc = db.collection("claims").document(claim_id).get()

    if not claim_doc.exists:
        raise HTTPException(status_code=404, detail="Claim not found")

    claim_data = claim_doc.to_dict()

    if user and claim_data.get("user_id") != user.get("uid"):
        if not claim_data.get("is_public", False):
            raise HTTPException(status_code=403, detail="Access denied")

    if claim_data.get("status") != "completed":
        return {
            "claim_id": claim_id,
            "status": claim_data.get("status", "processing"),
            "message": "Verification in progress"
        }

    verification_doc = db.collection("verifications").document(claim_id).get()
    if not verification_doc.exists:
        raise HTTPException(status_code=404, detail="Verification results not found")

    verification_data = verification_doc.to_dict()
    return ClaimVerificationResponse(**verification_data)


@router.get("/claims/history")
async def get_user_claim_history(
    user = Depends(lambda: None),
    limit: int = 50,
    offset: int = 0
):
    """Get authenticated user's claim history."""
    if not user:
        raise HTTPException(status_code=401, detail="Authentication required")

    try:
        db = firebase_db
        claims_query = (
            db.collection("claims")
            .where("user_id", "==", user["uid"])
            .order_by("submitted_at", direction="DESCENDING")
            .limit(limit + offset)
        )
        claims_stream = list(claims_query.stream())

        claims = []
        for doc in claims_stream[offset:offset+limit]:
            claim_data = doc.to_dict()
            claims.append({
                "claim_id": claim_data["claim_id"],
                "text": claim_data.get("text", "")[:100] + "..." if claim_data.get("text") else None,
                "status": claim_data["status"],
                "submitted_at": claim_data["submitted_at"],
                "verdict": claim_data.get("verdict"),
                "confidence_score": claim_data.get("confidence_score"),
                "harm_level": claim_data.get("harm_level")
            })

        return {
            "claims": claims,
            "total": len(claims_stream),
            "limit": limit,
            "offset": offset
        }

    except Exception as e:
        logger.error("Failed to get user history", error=str(e))
        raise HTTPException(status_code=500, detail="Failed to retrieve claim history")


# ------------------ PROCESSING ------------------

async def queue_claim_for_processing(claim_id: str, claim_data: Dict, priority: str):
    """Queue claim for background processing using Pub/Sub"""
    try:
        publisher = pubsub_v1.PublisherClient()
        project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        topic_path = publisher.topic_path(project_id, "claim-processing")

        submitted_at = claim_data["submitted_at"]
        if hasattr(submitted_at, "isoformat"):
            submitted_at = submitted_at.isoformat()

        message_data = {
            "claim_id": claim_id,
            "priority": priority,
            "submitted_at": submitted_at
        }

        future = publisher.publish(
            topic_path,
            str(message_data).encode("utf-8"),
            claim_id=claim_id,
            priority=priority
        )
        logger.info("Claim queued for processing", claim_id=claim_id, message_id=future.result())

    except Exception as e:
        logger.error("Failed to queue claim", claim_id=claim_id, error=str(e))
        await process_claim_immediate(claim_id, claim_data)


async def process_claim_immediate(claim_id: str, claim_data: Dict):
    """Process claim immediately for high-priority requests"""
    db = firebase_db
    try:
        db.collection("claims").document(claim_id).update({
            "status": "processing",
            "updated_at": datetime.now(timezone.utc)
        })

        # Step 1: Extract text
        claim_text = claim_data.get("text", "")
        processing_steps = {"steps": []}

        if claim_data.get("image_url") and not claim_text:
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
            translated_text = await translate_claim_text(claim_text, original_language, "en")
            processing_steps["steps"].append({
                "step": "translation",
                "original_language": original_language,
                "translated_length": len(translated_text)
            })
            claim_text = translated_text

        # Step 3: Claim detection
        claims_detected = await vertex_ai.detect_claims(claim_text)
        processing_steps["steps"].append({
            "step": "claim_detection",
            "claims_found": len(claims_detected)
        })

        # Step 4: Knowledge retrieval
        relevant_sources = await knowledge_service.search_relevant_sources(claim_text, claims_detected)
        processing_steps["steps"].append({
            "step": "knowledge_retrieval", 
            "sources_found": len(relevant_sources)
        })

        # Step 5: Verification
        verification_result = await vertex_ai.verify_claim(claim_text, relevant_sources)
        processing_steps["steps"].append({
            "step": "verification",
            "verdict": verification_result["verdict"],
            "confidence": verification_result["confidence"]
        })

        # Step 6: Harm classification
        harm_result = await harm_classifier.classify_harm(claim_text, verification_result["verdict"])
        processing_steps["steps"].append({
            "step": "harm_classification",
            "harm_level": harm_result["level"]
        })

        # Step 7: Generate explanation
        explanation = await vertex_ai.generate_explanation(
            claim_text, verification_result, relevant_sources[:3]
        )

        # Step 8: Final result
        final_result = ClaimVerificationResponse(
            claim_id=claim_id,
            verdict=verification_result["verdict"],
            confidence_score=verification_result["confidence"],
            harm_level=harm_result["level"],
            explanation=explanation["text"],
            citations=[Citation(**src) for src in relevant_sources[:3]],
            processing_steps=processing_steps,
            suggested_actions=harm_result["suggested_actions"],
            processed_at=datetime.now(timezone.utc)
        )

        db.collection("verifications").document(claim_id).set(final_result.dict())
        db.collection("claims").document(claim_id).update({
            "status": "completed",
            "verdict": verification_result["verdict"],
            "confidence_score": verification_result["confidence"],
            "harm_level": harm_result["level"],
            "updated_at": datetime.now(timezone.utc)
        })

    except Exception as e:
        logger.error("Failed to process claim", claim_id=claim_id, error=str(e), exc_info=True)
        db.collection("claims").document(claim_id).update({
            "status": "failed",
            "error": str(e),
            "updated_at": datetime.now(timezone.utc)
        })


# ------------------ HELPERS ------------------

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
        return text
