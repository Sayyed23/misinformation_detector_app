"""
Vertex AI Service for Claim Verification
Handles AI-powered claim detection, verification, and explanation generation
"""

import os
import json
import asyncio
from typing import List, Dict, Any, Optional
from datetime import datetime

from google.cloud import aiplatform
from google.cloud.aiplatform.gapic.schema import predict
from vertexai.language_models import TextGenerationModel, ChatModel
from vertexai.generative_models import GenerativeModel
import structlog

from models.claim_models import (
    VerdictType, ClaimAnalysis, Citation, ExplanationResult, 
    ExplanationRequest, SearchResult
)

logger = structlog.get_logger()


class VertexAIService:
    """Service for interacting with Vertex AI models"""
    
    def __init__(self):
        self.project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
        self.region = os.getenv("VERTEX_AI_REGION", "us-central1")
        
        # Initialize Vertex AI
        aiplatform.init(project=self.project_id, location=self.region)
        
        # Model configurations
        self.models = {
            "claim_detector": "claim-detection-model-v1",
            "verifier": "claim-verification-model-v1", 
            "harm_classifier": "harm-classification-model-v1",
            "text_generator": "text-bison@002",
            "chat_model": "chat-bison@002",
            "embedding_model": "textembedding-gecko@003"
        }
        
        # Initialize models (in production, these would be lazy-loaded)
        self.text_model = None
        self.chat_model = None
        self.generative_model = None
        
    async def initialize_models(self):
        """Initialize AI models lazily"""
        if not self.text_model:
            self.text_model = TextGenerationModel.from_pretrained(self.models["text_generator"])
        if not self.chat_model:
            self.chat_model = ChatModel.from_pretrained(self.models["chat_model"])
        if not self.generative_model:
            self.generative_model = GenerativeModel("gemini-1.5-flash")
    
    async def detect_claims(self, text: str) -> List[str]:
        """
        Extract individual verifiable claims from input text
        Returns list of atomic claims that can be fact-checked
        """
        try:
            await self.initialize_models()
            
            prompt = f"""
            Analyze the following text and extract all verifiable factual claims.
            A verifiable claim is a statement that can be proven true or false with evidence.
            
            Text: "{text}"
            
            Instructions:
            - Extract only factual claims, not opinions or subjective statements
            - Each claim should be atomic (one fact per claim)
            - Include numerical claims, dates, names, and events
            - Exclude rhetorical questions and hypothetical statements
            - Return each claim on a new line
            
            Verifiable Claims:
            """
            
            response = self.text_model.predict(
                prompt,
                max_output_tokens=512,
                temperature=0.1,
                top_p=0.8,
            )
            
            # Parse response to extract claims
            claims = []
            for line in response.text.strip().split('\n'):
                line = line.strip()
                if line and not line.startswith('Verifiable Claims:'):
                    # Remove numbering if present
                    if line[0].isdigit() and '. ' in line:
                        line = line.split('. ', 1)[1]
                    claims.append(line)
            
            logger.info("Claims detected", count=len(claims), original_text_length=len(text))
            return claims
            
        except Exception as e:
            logger.error("Failed to detect claims", error=str(e))
            # Fallback: return original text as single claim
            return [text]
    
    async def verify_claim(self, claim_text: str, evidence_sources: List[SearchResult]) -> Dict[str, Any]:
        """
        Verify a claim against available evidence sources
        Returns verdict with confidence score and reasoning
        """
        try:
            await self.initialize_models()
            
            # Prepare evidence context
            evidence_context = self._format_evidence_for_verification(evidence_sources)
            
            prompt = f"""
            You are an expert fact-checker. Analyze the following claim against the provided evidence.
            
            CLAIM TO VERIFY: "{claim_text}"
            
            AVAILABLE EVIDENCE:
            {evidence_context}
            
            TASK:
            1. Determine the claim's veracity based on the evidence
            2. Assign a confidence score (0.0 to 1.0)
            3. Provide reasoning for your assessment
            
            RESPONSE FORMAT (JSON):
            {{
                "verdict": "true|false|misleading|unverified",
                "confidence": 0.85,
                "reasoning": [
                    "Key evidence point 1",
                    "Key evidence point 2",
                    "Key evidence point 3"
                ],
                "primary_evidence_used": ["source1", "source2"],
                "contradictory_evidence": ["source3"] or null
            }}
            
            GUIDELINES:
            - "true": Claim is supported by reliable evidence
            - "false": Claim is contradicted by reliable evidence
            - "misleading": Claim contains some truth but misleads overall
            - "unverified": Insufficient evidence to make determination
            
            Respond only with valid JSON:
            """
            
            response = self.text_model.predict(
                prompt,
                max_output_tokens=512,
                temperature=0.2,
                top_p=0.9,
            )
            
            try:
                result = json.loads(response.text.strip())
                
                # Validate and normalize the result
                if result.get("verdict") not in ["true", "false", "misleading", "unverified"]:
                    result["verdict"] = "unverified"
                
                if not isinstance(result.get("confidence"), (int, float)) or result["confidence"] > 1:
                    result["confidence"] = 0.5
                    
                if not isinstance(result.get("reasoning"), list):
                    result["reasoning"] = ["Analysis completed with available evidence"]
                
                logger.info("Claim verified", 
                          verdict=result["verdict"], 
                          confidence=result["confidence"],
                          evidence_sources_count=len(evidence_sources))
                
                return result
                
            except json.JSONDecodeError:
                logger.warning("Failed to parse verification response", response=response.text)
                return {
                    "verdict": "unverified",
                    "confidence": 0.3,
                    "reasoning": ["Unable to process verification results"],
                    "primary_evidence_used": [],
                    "contradictory_evidence": []
                }
        
        except Exception as e:
            logger.error("Failed to verify claim", error=str(e))
            return {
                "verdict": "unverified",
                "confidence": 0.0,
                "reasoning": ["Verification system unavailable"],
                "primary_evidence_used": [],
                "contradictory_evidence": []
            }
    
    async def generate_explanation(
        self, 
        claim_text: str, 
        verification_result: Dict[str, Any], 
        citations: List[Citation]
    ) -> ExplanationResult:
        """
        Generate human-readable explanation for the verification result
        """
        try:
            await self.initialize_models()
            
            # Format citations for context
            citations_text = self._format_citations_for_explanation(citations)
            
            prompt = f"""
            Create a clear, educational explanation for why this claim verification reached its conclusion.
            
            CLAIM: "{claim_text}"
            VERDICT: {verification_result["verdict"]}
            CONFIDENCE: {verification_result["confidence"]}
            
            SUPPORTING EVIDENCE:
            {citations_text}
            
            REASONING CHAIN:
            {json.dumps(verification_result.get("reasoning", []), indent=2)}
            
            TASK: Write a comprehensive but accessible explanation that:
            1. States the verdict clearly
            2. Explains the key evidence considered
            3. Describes why this conclusion was reached
            4. Uses language appropriate for general audiences
            5. Maintains neutral, factual tone
            
            EXPLANATION:
            """
            
            response = self.text_model.predict(
                prompt,
                max_output_tokens=800,
                temperature=0.3,
                top_p=0.8,
            )
            
            explanation_text = response.text.strip()
            
            # Extract key points (simplified approach)
            key_points = []
            for reason in verification_result.get("reasoning", []):
                if len(reason) > 10:  # Filter out very short points
                    key_points.append(reason)
            
            # Calculate readability (simplified metric)
            word_count = len(explanation_text.split())
            sentence_count = explanation_text.count('.') + explanation_text.count('!') + explanation_text.count('?')
            readability_score = max(0.1, min(1.0, 1.0 - (word_count / sentence_count - 15) / 20))
            
            result = ExplanationResult(
                text=explanation_text,
                key_points=key_points,
                confidence=verification_result.get("confidence", 0.5),
                readability_score=readability_score,
                citations_used=[c.id for c in citations[:3]],  # Reference top 3 citations
                alternative_explanations=[]
            )
            
            logger.info("Explanation generated", 
                      length=len(explanation_text), 
                      key_points=len(key_points),
                      readability=readability_score)
            
            return result
            
        except Exception as e:
            logger.error("Failed to generate explanation", error=str(e))
            
            # Fallback explanation
            fallback_text = f"Based on our analysis, this claim appears to be {verification_result.get('verdict', 'unverified')}. Our AI system evaluated available evidence sources and reached this conclusion with {verification_result.get('confidence', 0.5):.0%} confidence."
            
            return ExplanationResult(
                text=fallback_text,
                key_points=[f"Claim classified as {verification_result.get('verdict', 'unverified')}"],
                confidence=0.3,
                readability_score=0.8,
                citations_used=[],
                alternative_explanations=[]
            )
    
    async def analyze_claim_complexity(self, claim_text: str) -> ClaimAnalysis:
        """
        Analyze claim complexity, extract entities, and identify topics
        """
        try:
            await self.initialize_models()
            
            prompt = f"""
            Analyze the following claim and provide detailed linguistic analysis.
            
            CLAIM: "{claim_text}"
            
            Provide analysis in JSON format:
            {{
                "extracted_claims": ["atomic claim 1", "atomic claim 2"],
                "entities": [
                    {{"text": "entity", "type": "PERSON|ORG|LOCATION|DATE|EVENT", "confidence": 0.9}}
                ],
                "sentiment": {{"positive": 0.2, "negative": 0.1, "neutral": 0.7}},
                "topics": ["topic1", "topic2"],
                "keywords": ["keyword1", "keyword2"],
                "complexity_score": 0.7
            }}
            
            Analysis:
            """
            
            response = self.text_model.predict(
                prompt,
                max_output_tokens=512,
                temperature=0.2,
                top_p=0.8,
            )
            
            try:
                analysis_data = json.loads(response.text.strip())
                
                return ClaimAnalysis(
                    extracted_claims=analysis_data.get("extracted_claims", [claim_text]),
                    entities=analysis_data.get("entities", []),
                    sentiment=analysis_data.get("sentiment", {"neutral": 1.0}),
                    topics=analysis_data.get("topics", []),
                    keywords=analysis_data.get("keywords", []),
                    language_confidence=0.95,  # Placeholder
                    complexity_score=analysis_data.get("complexity_score", 0.5)
                )
                
            except json.JSONDecodeError:
                logger.warning("Failed to parse analysis response")
                return self._create_fallback_analysis(claim_text)
        
        except Exception as e:
            logger.error("Failed to analyze claim", error=str(e))
            return self._create_fallback_analysis(claim_text)
    
    async def generate_embeddings(self, texts: List[str]) -> List[List[float]]:
        """Generate embeddings for texts using Vertex AI embedding model"""
        try:
            # This would use the actual Vertex AI embedding endpoint
            # For now, return mock embeddings
            embeddings = []
            for text in texts:
                # Mock embedding of length 768 (typical for text models)
                mock_embedding = [0.1] * 768
                embeddings.append(mock_embedding)
            
            return embeddings
            
        except Exception as e:
            logger.error("Failed to generate embeddings", error=str(e))
            return [[0.0] * 768 for _ in texts]  # Return zero embeddings as fallback
    
    def _format_evidence_for_verification(self, evidence_sources: List[SearchResult]) -> str:
        """Format evidence sources for verification prompt"""
        evidence_lines = []
        for i, source in enumerate(evidence_sources[:5], 1):  # Limit to top 5 sources
            evidence_lines.append(
                f"{i}. {source.title} ({source.source.domain})\n"
                f"   Credibility: {source.source.credibility_score:.2f}, "
                f"Relevance: {source.relevance_score:.2f}\n"
                f"   Content: {source.content[:200]}...\n"
                f"   URL: {source.url}\n"
            )
        return "\n".join(evidence_lines)
    
    def _format_citations_for_explanation(self, citations: List[Citation]) -> str:
        """Format citations for explanation generation"""
        citation_lines = []
        for i, citation in enumerate(citations[:3], 1):  # Limit to top 3
            citation_lines.append(
                f"{i}. {citation.title}\n"
                f"   Source: {citation.domain} (Credibility: {citation.credibility_score:.2f})\n"
                f"   Excerpt: {citation.excerpt}\n"
            )
        return "\n".join(citation_lines)
    
    def _create_fallback_analysis(self, claim_text: str) -> ClaimAnalysis:
        """Create basic analysis when AI processing fails"""
        return ClaimAnalysis(
            extracted_claims=[claim_text],
            entities=[],
            sentiment={"neutral": 1.0},
            topics=["general"],
            keywords=claim_text.split()[:10],  # First 10 words as keywords
            language_confidence=0.8,
            complexity_score=0.5
        )