"""
Harm Classification Service
Evaluates the potential harm level of misinformation and provides escalation recommendations
"""

import os
import json
import re
from typing import Dict, List, Optional, Tuple
from datetime import datetime

import structlog
from models.claim_models import HarmLevel, HarmClassificationResult, VerdictType

logger = structlog.get_logger()


class HarmClassificationService:
    """Service for classifying harm levels and determining escalation needs"""
    
    def __init__(self):
        self.harm_keywords = self._load_harm_keywords()
        self.severity_weights = {
            "health": 0.9,
            "violence": 0.95,
            "financial": 0.7,
            "political": 0.6,
            "social": 0.5,
            "conspiracy": 0.4
        }
        
    async def classify_harm(self, claim_text: str, verdict: str) -> Dict[str, any]:
        """
        Classify the harm level of a claim based on content and verification result
        """
        try:
            logger.info("Starting harm classification", verdict=verdict)
            
            # Analyze content for harm indicators
            harm_indicators = self._analyze_harm_indicators(claim_text)
            
            # Calculate base severity score
            base_severity = self._calculate_base_severity(claim_text, harm_indicators)
            
            # Adjust based on verdict
            verdict_multiplier = self._get_verdict_multiplier(verdict)
            adjusted_severity = base_severity * verdict_multiplier
            
            # Determine harm level
            harm_level = self._determine_harm_level(adjusted_severity)
            
            # Identify risk factors
            risk_factors = self._identify_risk_factors(claim_text, harm_indicators)
            
            # Generate suggested actions
            suggested_actions = self._generate_suggested_actions(harm_level, risk_factors, verdict)
            
            # Determine if escalation is needed
            escalation_required = self._requires_escalation(harm_level, risk_factors)
            
            # Generate reasoning
            reasoning = self._generate_reasoning(harm_level, risk_factors, base_severity, verdict)
            
            # Calculate confidence score
            confidence = self._calculate_confidence(harm_indicators, adjusted_severity)
            
            result = {
                "level": harm_level,
                "confidence": confidence,
                "severity_score": adjusted_severity,
                "risk_factors": risk_factors,
                "suggested_actions": suggested_actions,
                "escalation_required": escalation_required,
                "reasoning": reasoning
            }
            
            logger.info("Harm classification completed", 
                       harm_level=harm_level, 
                       severity_score=adjusted_severity,
                       escalation_required=escalation_required)
            
            return result
            
        except Exception as e:
            logger.error("Harm classification failed", error=str(e))
            return self._create_fallback_classification()
    
    def _analyze_harm_indicators(self, text: str) -> Dict[str, any]:
        """Analyze text for various harm indicators"""
        indicators = {
            "health_misinformation": self._detect_health_claims(text),
            "violence_incitement": self._detect_violence_content(text),
            "financial_fraud": self._detect_financial_scams(text),
            "conspiracy_theories": self._detect_conspiracy_elements(text),
            "discriminatory_content": self._detect_discrimination(text),
            "urgency_manipulation": self._detect_urgency_tactics(text),
            "authority_impersonation": self._detect_authority_claims(text),
            "emotional_manipulation": self._detect_emotional_tactics(text)
        }
        
        return indicators
    
    def _detect_health_claims(self, text: str) -> Dict[str, any]:
        """Detect health-related misinformation patterns"""
        health_keywords = self.harm_keywords.get("health", [])
        dangerous_health_claims = [
            r"\b(cure|treat|prevent)\s+(?:cancer|diabetes|covid|coronavirus|aids)\b",
            r"\b(?:vaccine|vaccination)\s+(?:dangerous|harmful|toxic|poison)\b",
            r"\b(?:doctors|medical)\s+(?:hiding|conspiracy|cover-up)\b",
            r"\bmiracle\s+(?:cure|treatment|remedy)\b",
            r"\b(?:natural|herbal)\s+(?:cure|alternative)\s+to\s+(?:medicine|drugs)\b"
        ]
        
        matches = []
        severity = 0.0
        
        for pattern in dangerous_health_claims:
            pattern_matches = re.findall(pattern, text, re.IGNORECASE)
            if pattern_matches:
                matches.extend(pattern_matches)
                severity += 0.3
        
        # Check for general health keywords
        health_score = sum(1 for keyword in health_keywords if keyword.lower() in text.lower())
        severity += min(0.4, health_score * 0.1)
        
        return {
            "detected": len(matches) > 0,
            "severity": min(1.0, severity),
            "matches": matches[:5],  # Limit to first 5 matches
            "keyword_count": health_score
        }
    
    def _detect_violence_content(self, text: str) -> Dict[str, any]:
        """Detect content that might incite violence"""
        violence_patterns = [
            r"\b(?:kill|murder|assassinate|eliminate)\s+(?:them|those|the)\b",
            r"\b(?:fight|attack|destroy|harm)\s+(?:back|them|those)\b",
            r"\btake\s+(?:action|revenge|justice)\s+into\s+(?:your|our)\s+hands\b",
            r"\b(?:uprising|revolution|revolt|riot)\s+(?:now|today|time)\b",
            r"\b(?:they|government|media)\s+(?:deserve|need)\s+to\s+(?:pay|suffer)\b"
        ]
        
        matches = []
        severity = 0.0
        
        for pattern in violence_patterns:
            pattern_matches = re.findall(pattern, text, re.IGNORECASE)
            if pattern_matches:
                matches.extend(pattern_matches)
                severity += 0.4
        
        return {
            "detected": len(matches) > 0,
            "severity": min(1.0, severity),
            "matches": matches[:3]
        }
    
    def _detect_financial_scams(self, text: str) -> Dict[str, any]:
        """Detect financial fraud or scam patterns"""
        financial_scam_patterns = [
            r"\b(?:guaranteed|instant|easy)\s+(?:money|profit|returns)\b",
            r"\b(?:investment|trading)\s+(?:secret|system|strategy)\b",
            r"\bmake\s+\$?\d+(?:k|,\d+)?\s+(?:per|a)\s+(?:day|week|month)\b",
            r"\b(?:crypto|bitcoin|forex)\s+(?:scam|ponzi|pyramid)\b",
            r"\bget\s+rich\s+quick\b",
            r"\bno\s+(?:risk|investment|experience)\s+required\b"
        ]
        
        matches = []
        severity = 0.0
        
        for pattern in financial_scam_patterns:
            pattern_matches = re.findall(pattern, text, re.IGNORECASE)
            if pattern_matches:
                matches.extend(pattern_matches)
                severity += 0.25
        
        return {
            "detected": len(matches) > 0,
            "severity": min(1.0, severity),
            "matches": matches[:3]
        }
    
    def _detect_conspiracy_elements(self, text: str) -> Dict[str, any]:
        """Detect conspiracy theory indicators"""
        conspiracy_keywords = [
            "deep state", "illuminati", "new world order", "agenda 21",
            "false flag", "cover-up", "mainstream media lies", "wake up",
            "they don't want you to know", "hidden truth", "secret society"
        ]
        
        conspiracy_patterns = [
            r"\b(?:government|media|big pharma)\s+(?:conspiracy|cover-up|lies)\b",
            r"\bthey\s+(?:don't\s+want|are\s+hiding|control)\b",
            r"\b(?:wake\s+up|open\s+your\s+eyes|sheep|sheeple)\b",
            r"\b(?:mainstream|fake)\s+media\b"
        ]
        
        matches = []
        severity = 0.0
        
        # Check keywords
        keyword_count = sum(1 for keyword in conspiracy_keywords if keyword.lower() in text.lower())
        severity += min(0.3, keyword_count * 0.1)
        
        # Check patterns
        for pattern in conspiracy_patterns:
            pattern_matches = re.findall(pattern, text, re.IGNORECASE)
            if pattern_matches:
                matches.extend(pattern_matches)
                severity += 0.15
        
        return {
            "detected": severity > 0,
            "severity": min(1.0, severity),
            "matches": matches[:3],
            "keyword_count": keyword_count
        }
    
    def _detect_discrimination(self, text: str) -> Dict[str, any]:
        """Detect discriminatory or hateful content"""
        # This would use more sophisticated detection in production
        # For now, using basic keyword matching
        discriminatory_patterns = [
            r"\b(?:all|most|these)\s+(?:immigrants|foreigners|minorities)\s+are\b",
            r"\b(?:race|religion|gender)\s+(?:superior|inferior)\b",
            r"\bthose\s+people\s+(?:are|always|never)\b"
        ]
        
        matches = []
        severity = 0.0
        
        for pattern in discriminatory_patterns:
            pattern_matches = re.findall(pattern, text, re.IGNORECASE)
            if pattern_matches:
                matches.extend(pattern_matches)
                severity += 0.3
        
        return {
            "detected": len(matches) > 0,
            "severity": min(1.0, severity),
            "matches": matches[:2]
        }
    
    def _detect_urgency_tactics(self, text: str) -> Dict[str, any]:
        """Detect urgency manipulation tactics"""
        urgency_patterns = [
            r"\b(?:urgent|emergency|immediate|act\s+now|time\s+running\s+out)\b",
            r"\b(?:limited\s+time|expires\s+soon|act\s+fast|don't\s+wait)\b",
            r"\b(?:before\s+it's\s+too\s+late|last\s+chance|final\s+warning)\b"
        ]
        
        matches = []
        severity = 0.0
        
        for pattern in urgency_patterns:
            pattern_matches = re.findall(pattern, text, re.IGNORECASE)
            if pattern_matches:
                matches.extend(pattern_matches)
                severity += 0.1
        
        return {
            "detected": len(matches) > 0,
            "severity": min(1.0, severity),
            "matches": matches[:3]
        }
    
    def _detect_authority_claims(self, text: str) -> Dict[str, any]:
        """Detect false authority or expertise claims"""
        authority_patterns = [
            r"\b(?:doctor|scientist|expert|professor)\s+(?:says|claims|warns)\b",
            r"\b(?:studies\s+show|research\s+proves|scientists\s+agree)\b",
            r"\b(?:top\s+secret|classified|insider)\s+(?:information|knowledge)\b"
        ]
        
        matches = []
        severity = 0.0
        
        for pattern in authority_patterns:
            pattern_matches = re.findall(pattern, text, re.IGNORECASE)
            if pattern_matches:
                matches.extend(pattern_matches)
                severity += 0.15
        
        return {
            "detected": len(matches) > 0,
            "severity": min(1.0, severity),
            "matches": matches[:3]
        }
    
    def _detect_emotional_tactics(self, text: str) -> Dict[str, any]:
        """Detect emotional manipulation tactics"""
        emotional_patterns = [
            r"\b(?:terrifying|shocking|outrageous|disgusting)\b",
            r"\b(?:your\s+children|our\s+children)\s+(?:are\s+in\s+danger|at\s+risk)\b",
            r"\b(?:they\s+want\s+to|trying\s+to)\s+(?:control|manipulate|deceive)\s+you\b"
        ]
        
        matches = []
        severity = 0.0
        
        for pattern in emotional_patterns:
            pattern_matches = re.findall(pattern, text, re.IGNORECASE)
            if pattern_matches:
                matches.extend(pattern_matches)
                severity += 0.1
        
        return {
            "detected": len(matches) > 0,
            "severity": min(1.0, severity),
            "matches": matches[:3]
        }
    
    def _calculate_base_severity(self, text: str, harm_indicators: Dict) -> float:
        """Calculate base severity score from harm indicators"""
        severity = 0.0
        
        for indicator_type, indicator_data in harm_indicators.items():
            if indicator_data.get("detected", False):
                weight = self.severity_weights.get(
                    indicator_type.split('_')[0], 0.5
                )
                severity += indicator_data.get("severity", 0) * weight
        
        return min(1.0, severity)
    
    def _get_verdict_multiplier(self, verdict: str) -> float:
        """Get multiplier based on verification verdict"""
        multipliers = {
            "false": 1.0,        # False claims get full severity
            "misleading": 0.8,   # Misleading claims get reduced severity
            "unverified": 0.6,   # Unverified claims get further reduced
            "true": 0.2          # True claims get minimal harm score
        }
        return multipliers.get(verdict.lower(), 0.5)
    
    def _determine_harm_level(self, severity_score: float) -> str:
        """Determine harm level based on severity score"""
        if severity_score >= 0.7:
            return "very_harmful"
        elif severity_score >= 0.3:
            return "basic"
        else:
            return "harmless"
    
    def _identify_risk_factors(self, text: str, harm_indicators: Dict) -> List[str]:
        """Identify specific risk factors present"""
        risk_factors = []
        
        for indicator_type, indicator_data in harm_indicators.items():
            if indicator_data.get("detected", False):
                severity = indicator_data.get("severity", 0)
                if severity > 0.3:
                    risk_factors.append(indicator_type.replace('_', ' ').title())
        
        # Additional risk factors
        if len(text) > 500:
            risk_factors.append("Long-form content")
        if re.search(r'\b(?:share|spread|tell\s+everyone)\b', text, re.IGNORECASE):
            risk_factors.append("Viral spread potential")
        
        return risk_factors[:5]  # Limit to top 5
    
    def _generate_suggested_actions(self, harm_level: str, risk_factors: List[str], verdict: str) -> List[str]:
        """Generate contextual suggested actions"""
        actions = []
        
        if harm_level == "very_harmful":
            actions.extend([
                "Do not share this content",
                "Report to platform moderators",
                "Consider reporting to relevant authorities"
            ])
            if "Health Misinformation" in risk_factors:
                actions.append("Consult healthcare professionals for medical advice")
            if "Violence Incitement" in risk_factors:
                actions.append("Report to law enforcement if threats are credible")
                
        elif harm_level == "basic":
            actions.extend([
                "Share with caution and provide context",
                "Include fact-check explanation when sharing",
                "Encourage others to verify information"
            ])
            
        else:  # harmless
            actions.extend([
                "Safe to share with fact-check context",
                "Use as educational example of misinformation"
            ])
        
        # Add verdict-specific actions
        if verdict == "false":
            actions.append("Share correct information instead")
        elif verdict == "misleading":
            actions.append("Provide complete context and missing information")
        
        return actions[:4]  # Limit to top 4 actions
    
    def _requires_escalation(self, harm_level: str, risk_factors: List[str]) -> bool:
        """Determine if content requires escalation to authorities"""
        if harm_level == "very_harmful":
            return True
        
        escalation_triggers = [
            "Violence Incitement",
            "Health Misinformation",
            "Discriminatory Content"
        ]
        
        return any(factor in escalation_triggers for factor in risk_factors)
    
    def _generate_reasoning(self, harm_level: str, risk_factors: List[str], severity_score: float, verdict: str) -> str:
        """Generate human-readable reasoning for the classification"""
        reasoning_parts = [
            f"Content classified as '{harm_level}' based on severity score of {severity_score:.2f}."
        ]
        
        if risk_factors:
            risk_list = ", ".join(risk_factors[:3])
            reasoning_parts.append(f"Key risk factors identified: {risk_list}.")
        
        reasoning_parts.append(f"Verification verdict of '{verdict}' was considered in the assessment.")
        
        if harm_level == "very_harmful":
            reasoning_parts.append("Content poses significant potential harm if shared widely.")
        elif harm_level == "basic":
            reasoning_parts.append("Content has moderate potential for harm but can be shared with context.")
        else:
            reasoning_parts.append("Content poses minimal harm risk.")
        
        return " ".join(reasoning_parts)
    
    def _calculate_confidence(self, harm_indicators: Dict, severity_score: float) -> float:
        """Calculate confidence in the harm classification"""
        # Base confidence on number of detected indicators and their severity
        detected_count = sum(1 for indicator in harm_indicators.values() if indicator.get("detected", False))
        
        if detected_count == 0:
            return 0.9  # High confidence in harmless classification
        
        # Confidence increases with more indicators and higher severity
        confidence = 0.6 + (detected_count * 0.1) + (severity_score * 0.3)
        return min(0.95, confidence)
    
    def _create_fallback_classification(self) -> Dict[str, any]:
        """Create safe fallback classification when analysis fails"""
        return {
            "level": "basic",
            "confidence": 0.3,
            "severity_score": 0.5,
            "risk_factors": ["Analysis unavailable"],
            "suggested_actions": [
                "Verify information before sharing",
                "Consult multiple reliable sources"
            ],
            "escalation_required": False,
            "reasoning": "Unable to perform detailed harm analysis. Exercise caution when sharing."
        }
    
    def _load_harm_keywords(self) -> Dict[str, List[str]]:
        """Load keyword lists for different harm categories"""
        # In production, these would be loaded from external files or databases
        return {
            "health": [
                "vaccine", "covid", "coronavirus", "medicine", "treatment", "cure",
                "doctor", "hospital", "symptoms", "disease", "virus", "bacteria",
                "immunity", "antibiotics", "prescription", "dosage", "side effects"
            ],
            "violence": [
                "weapon", "gun", "bomb", "attack", "violence", "harm", "hurt",
                "kill", "murder", "fight", "war", "terrorism", "threat"
            ],
            "financial": [
                "investment", "money", "profit", "scam", "fraud", "bitcoin",
                "crypto", "trading", "stocks", "loan", "debt", "bank",
                "credit", "finance", "pyramid", "ponzi"
            ]
        }