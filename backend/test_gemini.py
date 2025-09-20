"""
Test script for Gemini API integration
Run this to verify that the Gemini API is working correctly
"""

import asyncio
import sys
import os
from pathlib import Path

# Add parent directory to path
sys.path.append(str(Path(__file__).parent))

from services.gemini_service import get_gemini_service


async def test_gemini_service():
    """Test the Gemini AI service with sample claims"""
    
    print("=" * 60)
    print("Testing Gemini AI Service")
    print("=" * 60)
    
    # Initialize the service
    try:
        gemini = get_gemini_service()
        print("✅ Gemini service initialized successfully\n")
    except Exception as e:
        print(f"❌ Failed to initialize Gemini service: {e}")
        return
    
    # Test 1: Claim Detection
    print("Test 1: Claim Detection")
    print("-" * 40)
    test_text = """
    The COVID-19 vaccines have been proven safe and effective by multiple studies. 
    They have undergone rigorous testing. Over 5 billion doses have been administered worldwide.
    Some people claim vaccines cause autism, but this has been thoroughly debunked by science.
    """
    
    try:
        claims = await gemini.detect_claims(test_text)
        print(f"Detected {len(claims)} claims:")
        for i, claim in enumerate(claims, 1):
            print(f"  {i}. {claim}")
        print("✅ Claim detection successful\n")
    except Exception as e:
        print(f"❌ Claim detection failed: {e}\n")
    
    # Test 2: Claim Verification
    print("Test 2: Claim Verification")
    print("-" * 40)
    test_claim = "COVID-19 vaccines cause autism"
    
    try:
        result = await gemini.verify_claim(test_claim)
        print(f"Claim: '{test_claim}'")
        print(f"Verdict: {result['verdict']}")
        print(f"Confidence: {result['confidence']:.0%}")
        print(f"Reasoning:")
        for reason in result.get('reasoning', []):
            print(f"  • {reason}")
        print("✅ Claim verification successful\n")
    except Exception as e:
        print(f"❌ Claim verification failed: {e}\n")
    
    # Test 3: Claim Analysis
    print("Test 3: Claim Analysis")
    print("-" * 40)
    test_claim2 = "Bill Gates said in 2015 that vaccines would reduce the world population by 15%"
    
    try:
        analysis = await gemini.analyze_claim_complexity(test_claim2)
        print(f"Claim: '{test_claim2}'")
        print(f"Complexity Score: {analysis.complexity_score}")
        print(f"Keywords: {', '.join(analysis.keywords[:5])}")
        print(f"Topics: {', '.join(analysis.topics)}")
        print(f"Entities: {len(analysis.entities)} found")
        print("✅ Claim analysis successful\n")
    except Exception as e:
        print(f"❌ Claim analysis failed: {e}\n")
    
    # Test 4: Translation
    print("Test 4: Translation")
    print("-" * 40)
    hindi_text = "कोविड-19 टीके सुरक्षित हैं"
    
    try:
        translated = await gemini.translate_text(hindi_text, "hi", "en")
        print(f"Hindi: {hindi_text}")
        print(f"English: {translated}")
        print("✅ Translation successful\n")
    except Exception as e:
        print(f"❌ Translation failed: {e}\n")
    
    # Test 5: Harm Check
    print("Test 5: Harm Content Check")
    print("-" * 40)
    harmful_claim = "Drinking bleach can cure COVID-19 infection immediately"
    
    try:
        harm_result = await gemini.check_harmful_content(harmful_claim)
        print(f"Claim: '{harmful_claim}'")
        print(f"Contains Harm: {harm_result['contains_harm']}")
        print(f"Harm Type: {harm_result['harm_type']}")
        print(f"Severity: {harm_result['severity']}")
        print(f"Recommended Action: {harm_result['recommended_action']}")
        print("✅ Harm check successful\n")
    except Exception as e:
        print(f"❌ Harm check failed: {e}\n")
    
    # Test 6: Generate Explanation
    print("Test 6: Generate Explanation")
    print("-" * 40)
    
    try:
        verification_result = {
            "verdict": "false",
            "confidence": 0.95,
            "reasoning": [
                "No scientific evidence supports this claim",
                "Extensive studies have shown no link between vaccines and autism",
                "The original study claiming this link was retracted for fraud"
            ]
        }
        
        explanation = await gemini.generate_explanation(
            "Vaccines cause autism",
            verification_result
        )
        
        print("Explanation:")
        print(explanation['text'][:500] + "..." if len(explanation['text']) > 500 else explanation['text'])
        print(f"\nReadability Score: {explanation['readability_score']:.2f}")
        print("✅ Explanation generation successful\n")
    except Exception as e:
        print(f"❌ Explanation generation failed: {e}\n")
    
    print("=" * 60)
    print("All tests completed!")
    print("=" * 60)


if __name__ == "__main__":
    # Run the async tests
    asyncio.run(test_gemini_service())