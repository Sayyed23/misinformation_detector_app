"""
Harm Classification Service
Evaluates claims for potential harm levels
"""

from typing import Dict

class HarmClassifier:
    async def classify_harm(self, claim_text: str, verdict: str) -> Dict:
        """Classifies the potential harm level of a claim."""
        # Basic implementation - should be enhanced with actual AI model
        harm_level = "harmless"
        actions = ["Verify information from trusted sources"]

        if verdict == "false":
            harm_level = "basic"
            actions.append("Share correct information")
        elif verdict == "very_harmful":
            harm_level = "very_harmful"
            actions.append("Report to authorities")

        return {
            "level": harm_level,
            "suggested_actions": actions
        }
