"""
Pydantic models for claim verification data structures
"""

from typing import List, Dict, Optional, Any
from datetime import datetime
from pydantic import BaseModel, Field
from enum import Enum


class VerdictType(str, Enum):
    """Verdict types for claim verification"""
    TRUE = "true"
    FALSE = "false"
    MISLEADING = "misleading"
    UNVERIFIED = "unverified"


class HarmLevel(str, Enum):
    """Harm classification levels"""
    HARMLESS = "harmless"
    BASIC = "basic"
    VERY_HARMFUL = "very_harmful"


class Citation(BaseModel):
    """Citation model for supporting sources"""
    id: str = Field(..., description="Citation ID")
    title: str = Field(..., description="Source title")
    url: str = Field(..., description="Source URL") 
    domain: str = Field(..., description="Source domain")
    published_date: Optional[datetime] = Field(None, description="Publication date")
    credibility_score: float = Field(..., description="Source credibility score (0-1)")
    relevance_score: float = Field(..., description="Relevance to claim (0-1)")
    excerpt: str = Field(..., description="Relevant excerpt from source")
    fact_check_rating: Optional[str] = Field(None, description="Fact-check rating if applicable")


class ClaimSubmission(BaseModel):
    """Model for claim submission requests"""
    text: Optional[str] = Field(None, description="Text claim to verify")
    image_url: Optional[str] = Field(None, description="URL of image to verify")
    source_url: Optional[str] = Field(None, description="Source URL where claim was found")
    language: str = Field("en", description="Language of the claim (ISO 639-1)")
    priority: str = Field("normal", description="Processing priority")
    user_id: Optional[str] = Field(None, description="User ID submitting the claim")
    metadata: Optional[Dict[str, Any]] = Field(None, description="Additional metadata")


class ProcessingStep(BaseModel):
    """Individual step in the claim processing pipeline"""
    step: str = Field(..., description="Step name")
    status: str = Field(..., description="Step status: pending, processing, completed, failed")
    started_at: Optional[datetime] = Field(None, description="Step start time")
    completed_at: Optional[datetime] = Field(None, description="Step completion time")
    confidence: Optional[float] = Field(None, description="Step confidence score")
    details: Optional[Dict[str, Any]] = Field(None, description="Additional step details")
    error_message: Optional[str] = Field(None, description="Error message if step failed")


class ClaimVerificationResult(BaseModel):
    """Complete claim verification result"""
    claim_id: str = Field(..., description="Unique claim identifier")
    original_claim: str = Field(..., description="Original claim text")
    translated_claim: Optional[str] = Field(None, description="Translated claim if applicable")
    
    # Verification results
    verdict: VerdictType = Field(..., description="Verification verdict")
    confidence_score: float = Field(..., ge=0, le=1, description="AI confidence score")
    harm_level: HarmLevel = Field(..., description="Harm classification")
    
    # Explanation and citations
    explanation: str = Field(..., description="Detailed explanation of verdict")
    reasoning_chain: List[str] = Field(..., description="Step-by-step reasoning")
    citations: List[Citation] = Field(..., description="Supporting citations")
    counter_evidence: List[Citation] = Field(default_factory=list, description="Contradicting evidence")
    
    # Processing information
    processing_steps: List[ProcessingStep] = Field(..., description="Processing pipeline steps")
    processing_time_seconds: float = Field(..., description="Total processing time")
    
    # Actions and recommendations
    suggested_actions: List[str] = Field(..., description="Recommended user actions")
    escalation_triggers: List[str] = Field(default_factory=list, description="Reasons for escalation")
    
    # Metadata
    processed_at: datetime = Field(..., description="Processing completion timestamp")
    model_versions: Dict[str, str] = Field(..., description="AI model versions used")
    quality_score: float = Field(..., ge=0, le=1, description="Overall result quality score")


class ClaimAnalysis(BaseModel):
    """Intermediate analysis results for claims"""
    extracted_claims: List[str] = Field(..., description="Individual claims extracted from text")
    entities: List[Dict[str, Any]] = Field(..., description="Named entities found")
    sentiment: Dict[str, float] = Field(..., description="Sentiment analysis results")
    topics: List[str] = Field(..., description="Identified topics")
    keywords: List[str] = Field(..., description="Key terms and phrases")
    language_confidence: float = Field(..., description="Language detection confidence")
    complexity_score: float = Field(..., description="Claim complexity assessment")


class KnowledgeSource(BaseModel):
    """Knowledge base source information"""
    source_id: str = Field(..., description="Source identifier")
    name: str = Field(..., description="Source name")
    domain: str = Field(..., description="Source domain")
    source_type: str = Field(..., description="Type: fact_check, news, academic, government")
    credibility_score: float = Field(..., ge=0, le=1, description="Source credibility")
    last_updated: datetime = Field(..., description="Last update timestamp")
    specialties: List[str] = Field(default_factory=list, description="Source specialization areas")
    language: str = Field("en", description="Primary language")
    bias_score: Optional[float] = Field(None, ge=-1, le=1, description="Political bias score")


class SearchResult(BaseModel):
    """Search result from knowledge base"""
    document_id: str = Field(..., description="Document identifier")
    title: str = Field(..., description="Document title")
    content: str = Field(..., description="Relevant content excerpt")
    url: str = Field(..., description="Document URL")
    source: KnowledgeSource = Field(..., description="Source information")
    relevance_score: float = Field(..., ge=0, le=1, description="Relevance to query")
    semantic_similarity: float = Field(..., ge=0, le=1, description="Semantic similarity score")
    date_published: Optional[datetime] = Field(None, description="Publication date")
    fact_check_verdict: Optional[VerdictType] = Field(None, description="Fact-check verdict if applicable")


class HarmClassificationResult(BaseModel):
    """Result of harm level classification"""
    harm_level: HarmLevel = Field(..., description="Classified harm level")
    confidence: float = Field(..., ge=0, le=1, description="Classification confidence")
    risk_factors: List[str] = Field(..., description="Identified risk factors")
    severity_score: float = Field(..., ge=0, le=1, description="Severity assessment")
    suggested_actions: List[str] = Field(..., description="Recommended actions")
    escalation_required: bool = Field(..., description="Whether escalation is needed")
    reasoning: str = Field(..., description="Explanation of classification")


class ExplanationRequest(BaseModel):
    """Request for generating explanation"""
    claim_text: str = Field(..., description="Original claim text")
    verdict: VerdictType = Field(..., description="Verification verdict")
    evidence: List[Citation] = Field(..., description="Supporting evidence")
    target_audience: str = Field("general", description="Target audience level")
    max_length: int = Field(500, description="Maximum explanation length")
    include_citations: bool = Field(True, description="Whether to include citations")


class ExplanationResult(BaseModel):
    """Generated explanation result"""
    text: str = Field(..., description="Generated explanation text")
    key_points: List[str] = Field(..., description="Key explanation points")
    confidence: float = Field(..., ge=0, le=1, description="Explanation quality confidence")
    readability_score: float = Field(..., ge=0, le=1, description="Text readability score")
    citations_used: List[str] = Field(..., description="Citation IDs referenced")
    alternative_explanations: List[str] = Field(default_factory=list, description="Alternative phrasings")