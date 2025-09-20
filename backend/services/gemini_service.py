"""
Gemini AI Service for Claim Verification
Uses Google's Gemini API for AI-powered claim detection and verification
"""

import os
import json
import asyncio
import requests
from typing import List, Dict, Any, Optional
from datetime import datetime
import google.generativeai as genai
from dotenv import load_dotenv
import structlog

from models.claim_models import (
    VerdictType, ClaimAnalysis, Citation, ExplanationResult, 
    ExplanationRequest, SearchResult
)

# Load environment variables
load_dotenv()

logger = structlog.get_logger()


class GeminiAIService:
    """Service for interacting with Google Gemini AI"""
    
    def __init__(self):
        # Configure Gemini API
        self.api_key = os.getenv("GEMINI_API_KEY")
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY not found in environment variables")
        
        genai.configure(api_key=self.api_key)
        
        # Initialize the model
        self.model = genai.GenerativeModel('gemini-1.5-flash')
        
        # Safety settings
        self.safety_settings = [
            {
                "category": "HARM_CATEGORY_HARASSMENT",
                "threshold": "BLOCK_NONE"
            },
            {
                "category": "HARM_CATEGORY_HATE_SPEECH", 
                "threshold": "BLOCK_NONE"
            },
            {
                "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                "threshold": "BLOCK_NONE"
            },
            {
                "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                "threshold": "BLOCK_NONE"
            }
        ]
        
        logger.info("Gemini AI Service initialized")
    
    async def detect_claims(self, text: str) -> List[str]:
        """
        Extract individual verifiable claims from input text
        Returns list of atomic claims that can be fact-checked
        """
        try:
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
            - Maximum 10 claims
            
            Format your response as a numbered list of claims.
            
            Verifiable Claims:
            """
            
            response = self.model.generate_content(
                prompt,
                safety_settings=self.safety_settings,
                generation_config=genai.GenerationConfig(
                    temperature=0.1,
                    top_p=0.8,
                    max_output_tokens=512
                )
            )
            
            # Parse response to extract claims
            claims = []
            if response.text:
                for line in response.text.strip().split('\n'):
                    line = line.strip()
                    # Remove numbering if present
                    if line and line[0].isdigit() and '. ' in line:
                        line = line.split('. ', 1)[1]
                    if line and not line.startswith('Verifiable Claims:'):
                        claims.append(line)
            
            logger.info("Claims detected", count=len(claims), original_text_length=len(text))
            return claims[:10]  # Limit to 10 claims
            
        except Exception as e:
            logger.error("Failed to detect claims", error=str(e))
            # Fallback: return original text as single claim
            return [text]
    
    async def verify_claim(self, claim_text: str, evidence_sources: List[SearchResult] = None) -> Dict[str, Any]:
        """
        Verify a claim using Gemini AI
        Returns verdict with confidence score and reasoning
        """
        try:
            # Prepare evidence context if available
            evidence_context = ""
            if evidence_sources:
                evidence_context = self._format_evidence_for_verification(evidence_sources)
            
            prompt = f"""
            You are an expert fact-checker. Analyze the following claim and determine its veracity.
            
            CLAIM TO VERIFY: "{claim_text}"
            
            {f"AVAILABLE EVIDENCE: {evidence_context}" if evidence_context else "No specific evidence provided. Use your knowledge to verify."}
            
            TASK:
            1. Determine if the claim is true, false, misleading, or unverified
            2. Provide a confidence score between 0.0 and 1.0
            3. Give clear reasoning for your assessment
            4. Identify key evidence that supports or contradicts the claim
            
            Guidelines for verdicts:
            - "true": Claim is factually accurate and supported by reliable evidence
            - "false": Claim is factually incorrect and contradicted by reliable evidence
            - "misleading": Claim contains some truth but is presented in a misleading way
            - "unverified": Insufficient evidence to make a determination
            
            Respond in JSON format:
            {{
                "verdict": "true/false/misleading/unverified",
                "confidence": 0.85,
                "reasoning": [
                    "Key point 1 explaining the verdict",
                    "Key point 2 with evidence",
                    "Key point 3 about context"
                ],
                "key_evidence": [
                    "Evidence point 1",
                    "Evidence point 2"
                ],
                "context_needed": "Any additional context that would help verify this claim"
            }}
            
            Provide ONLY valid JSON in your response.
            """
            
            response = self.model.generate_content(
                prompt,
                safety_settings=self.safety_settings,
                generation_config=genai.GenerationConfig(
                    temperature=0.2,
                    top_p=0.9,
                    max_output_tokens=512
                )
            )
            
            try:
                # Extract JSON from response
                response_text = response.text.strip()
                # Find JSON content between { and }
                json_start = response_text.find('{')
                json_end = response_text.rfind('}') + 1
                if json_start >= 0 and json_end > json_start:
                    json_str = response_text[json_start:json_end]
                    result = json.loads(json_str)
                else:
                    raise json.JSONDecodeError("No JSON found", response_text, 0)
                
                # Validate and normalize the result
                if result.get("verdict") not in ["true", "false", "misleading", "unverified"]:
                    result["verdict"] = "unverified"
                
                if not isinstance(result.get("confidence"), (int, float)):
                    result["confidence"] = 0.5
                else:
                    result["confidence"] = max(0.0, min(1.0, result["confidence"]))
                    
                if not isinstance(result.get("reasoning"), list):
                    result["reasoning"] = ["Analysis completed with available information"]
                
                logger.info("Claim verified", 
                          verdict=result["verdict"], 
                          confidence=result["confidence"])
                
                return result
                
            except json.JSONDecodeError:
                logger.warning("Failed to parse verification response", response=response.text)
                return {
                    "verdict": "unverified",
                    "confidence": 0.3,
                    "reasoning": ["Unable to process verification with high confidence"],
                    "key_evidence": [],
                    "context_needed": "Additional verification required"
                }
        
        except Exception as e:
            logger.error("Failed to verify claim", error=str(e))
            return {
                "verdict": "unverified",
                "confidence": 0.0,
                "reasoning": ["Verification system temporarily unavailable"],
                "key_evidence": [],
                "context_needed": "System error - please try again"
            }
    
    async def generate_explanation(
        self, 
        claim_text: str, 
        verification_result: Dict[str, Any], 
        citations: List[Citation] = None
    ) -> Dict[str, Any]:
        """
        Generate human-readable explanation for the verification result
        """
        try:
            # Format citations if available
            citations_text = ""
            if citations:
                citations_text = self._format_citations_for_explanation(citations)
            
            prompt = f"""
            Create a clear, educational explanation for why this claim verification reached its conclusion.
            Write for a general audience, avoiding technical jargon.
            
            CLAIM: "{claim_text}"
            VERDICT: {verification_result.get("verdict", "unverified")}
            CONFIDENCE: {verification_result.get("confidence", 0.5):.0%}
            
            REASONING PROVIDED:
            {json.dumps(verification_result.get("reasoning", []), indent=2)}
            
            {f"SUPPORTING SOURCES: {citations_text}" if citations_text else ""}
            
            Write a comprehensive but accessible explanation that:
            1. Clearly states whether the claim is true, false, misleading, or unverified
            2. Explains the key evidence or lack thereof
            3. Provides context about why this matters
            4. Suggests what readers should do with this information
            5. Maintains a neutral, factual tone
            
            Format: Write 2-3 clear paragraphs explaining the verdict.
            """
            
            response = self.model.generate_content(
                prompt,
                safety_settings=self.safety_settings,
                generation_config=genai.GenerationConfig(
                    temperature=0.3,
                    top_p=0.8,
                    max_output_tokens=800
                )
            )
            
            explanation_text = response.text.strip()
            
            # Extract key points from reasoning
            key_points = verification_result.get("reasoning", [])[:3]
            
            # Calculate readability (simplified metric)
            word_count = len(explanation_text.split())
            sentence_count = explanation_text.count('.') + explanation_text.count('!') + explanation_text.count('?')
            readability_score = max(0.1, min(1.0, 1.0 - (word_count / max(1, sentence_count) - 15) / 20))
            
            result = {
                "text": explanation_text,
                "key_points": key_points,
                "confidence": verification_result.get("confidence", 0.5),
                "readability_score": readability_score,
                "citations_used": [c.id for c in (citations[:3] if citations else [])],
            }
            
            logger.info("Explanation generated", 
                      length=len(explanation_text), 
                      key_points=len(key_points))
            
            return result
            
        except Exception as e:
            logger.error("Failed to generate explanation", error=str(e))
            
            # Fallback explanation
            fallback_text = f"Based on our analysis, this claim appears to be {verification_result.get('verdict', 'unverified')}. Our AI system evaluated available information and reached this conclusion with {verification_result.get('confidence', 0.5):.0%} confidence."
            
            return {
                "text": fallback_text,
                "key_points": [f"Claim classified as {verification_result.get('verdict', 'unverified')}"],
                "confidence": 0.3,
                "readability_score": 0.8,
                "citations_used": []
            }
    
    async def analyze_claim_complexity(self, claim_text: str) -> ClaimAnalysis:
        """
        Analyze claim complexity, extract entities, and identify topics
        """
        try:
            prompt = f"""
            Analyze the following claim and provide detailed analysis.
            
            CLAIM: "{claim_text}"
            
            Provide a comprehensive analysis including:
            1. Break down into individual atomic claims (if multiple)
            2. Identify key entities (people, organizations, locations, dates)
            3. Determine the sentiment (positive/negative/neutral)
            4. Identify main topics and categories
            5. Extract important keywords
            6. Assess complexity on a scale of 0 to 1
            
            Format your response as JSON:
            {{
                "atomic_claims": ["claim 1", "claim 2"],
                "entities": [
                    {{"text": "entity name", "type": "PERSON/ORG/LOCATION/DATE", "confidence": 0.9}}
                ],
                "sentiment": {{"positive": 0.2, "negative": 0.1, "neutral": 0.7}},
                "topics": ["topic1", "topic2"],
                "keywords": ["keyword1", "keyword2"],
                "complexity_score": 0.7,
                "category": "health/politics/technology/social/other"
            }}
            
            Respond with ONLY valid JSON.
            """
            
            response = self.model.generate_content(
                prompt,
                safety_settings=self.safety_settings,
                generation_config=genai.GenerationConfig(
                    temperature=0.2,
                    top_p=0.8,
                    max_output_tokens=512
                )
            )
            
            try:
                response_text = response.text.strip()
                json_start = response_text.find('{')
                json_end = response_text.rfind('}') + 1
                if json_start >= 0 and json_end > json_start:
                    json_str = response_text[json_start:json_end]
                    analysis_data = json.loads(json_str)
                else:
                    raise json.JSONDecodeError("No JSON found", response_text, 0)
                
                return ClaimAnalysis(
                    extracted_claims=analysis_data.get("atomic_claims", [claim_text]),
                    entities=analysis_data.get("entities", []),
                    sentiment=analysis_data.get("sentiment", {"neutral": 1.0}),
                    topics=analysis_data.get("topics", []),
                    keywords=analysis_data.get("keywords", []),
                    language_confidence=0.95,
                    complexity_score=analysis_data.get("complexity_score", 0.5)
                )
                
            except json.JSONDecodeError:
                logger.warning("Failed to parse analysis response")
                return self._create_fallback_analysis(claim_text)
        
        except Exception as e:
            logger.error("Failed to analyze claim", error=str(e))
            return self._create_fallback_analysis(claim_text)
    
    async def translate_text(self, text: str, source_lang: str, target_lang: str) -> str:
        """
        Translate text using Gemini
        """
        try:
            lang_names = {
                "en": "English",
                "hi": "Hindi",
                "mr": "Marathi", 
                "ta": "Tamil",
                "bn": "Bengali",
                "te": "Telugu",
                "gu": "Gujarati",
                "kn": "Kannada",
                "ml": "Malayalam",
                "pa": "Punjabi"
            }
            
            source_name = lang_names.get(source_lang, source_lang)
            target_name = lang_names.get(target_lang, target_lang)
            
            prompt = f"""
            Translate the following text from {source_name} to {target_name}.
            Maintain the original meaning and tone as closely as possible.
            
            Original text in {source_name}:
            "{text}"
            
            Translation in {target_name}:
            """
            
            response = self.model.generate_content(
                prompt,
                safety_settings=self.safety_settings,
                generation_config=genai.GenerationConfig(
                    temperature=0.1,
                    top_p=0.9,
                    max_output_tokens=1024
                )
            )
            
            return response.text.strip()
            
        except Exception as e:
            logger.error("Translation failed", error=str(e))
            return text  # Return original text if translation fails
    
    async def check_harmful_content(self, text: str) -> Dict[str, Any]:
        """
        Check if content contains harmful misinformation
        """
        try:
            prompt = f"""
            Analyze the following text for potentially harmful misinformation.
            
            TEXT: "{text}"
            
            Check for:
            1. Health misinformation that could cause physical harm
            2. Content that could incite violence or panic
            3. Financial scams or fraud
            4. Dangerous conspiracy theories
            5. Content targeting vulnerable groups
            
            Respond in JSON format:
            {{
                "contains_harm": true/false,
                "harm_type": "health/violence/financial/conspiracy/discrimination/none",
                "severity": "low/medium/high",
                "specific_risks": ["risk 1", "risk 2"],
                "recommended_action": "what should be done with this content"
            }}
            
            Provide ONLY valid JSON.
            """
            
            response = self.model.generate_content(
                prompt,
                safety_settings=self.safety_settings,
                generation_config=genai.GenerationConfig(
                    temperature=0.1,
                    top_p=0.8,
                    max_output_tokens=256
                )
            )
            
            try:
                response_text = response.text.strip()
                json_start = response_text.find('{')
                json_end = response_text.rfind('}') + 1
                if json_start >= 0 and json_end > json_start:
                    json_str = response_text[json_start:json_end]
                    result = json.loads(json_str)
                    return result
                else:
                    raise json.JSONDecodeError("No JSON found", response_text, 0)
                    
            except json.JSONDecodeError:
                return {
                    "contains_harm": False,
                    "harm_type": "none",
                    "severity": "low",
                    "specific_risks": [],
                    "recommended_action": "Review for accuracy"
                }
                
        except Exception as e:
            logger.error("Harm check failed", error=str(e))
            return {
                "contains_harm": False,
                "harm_type": "none",
                "severity": "low",
                "specific_risks": ["Unable to assess"],
                "recommended_action": "Manual review recommended"
            }
    
    def _format_evidence_for_verification(self, evidence_sources: List[SearchResult]) -> str:
        """Format evidence sources for verification prompt"""
        if not evidence_sources:
            return ""
        
        evidence_lines = []
        for i, source in enumerate(evidence_sources[:5], 1):  # Limit to top 5 sources
            evidence_lines.append(
                f"{i}. {source.title} ({source.source.domain})\n"
                f"   Credibility: {source.source.credibility_score:.2f}\n"
                f"   Content: {source.content[:200]}...\n"
            )
        return "\n".join(evidence_lines)
    
    def _format_citations_for_explanation(self, citations: List[Citation]) -> str:
        """Format citations for explanation generation"""
        if not citations:
            return ""
        
        citation_lines = []
        for i, citation in enumerate(citations[:3], 1):  # Limit to top 3
            citation_lines.append(
                f"{i}. {citation.title} - {citation.domain}"
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


# Singleton pattern for service
_gemini_service_instance = None

def get_gemini_service() -> GeminiAIService:
    """Get singleton instance of Gemini service"""
    global _gemini_service_instance
    if _gemini_service_instance is None:
        _gemini_service_instance = GeminiAIService()
    return _gemini_service_instance