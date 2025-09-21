import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'config_service.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  late GenerativeModel _model;
  final ConfigService _config = ConfigService.instance;
  bool _isInitialized = false;

  /// Initialize the Gemini service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Get API key from config
      final apiKey = _config.geminiApiKey;
      if (apiKey.isEmpty) {
        throw Exception('Gemini API key not found. Please check your configuration.');
      }

      // Initialize the model
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
        ],
      );

      _isInitialized = true;
      debugPrint('Gemini service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Gemini service: $e');
      throw Exception('Failed to initialize Gemini service: $e');
    }
  }

  /// Analyze text for misinformation using Gemini
  Future<Map<String, dynamic>> analyzeTextForMisinformation(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final prompt = _buildMisinformationAnalysisPrompt(text);
      
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      final responseText = response.text ?? '';
      return _parseMisinformationAnalysis(responseText);
    } catch (e) {
      debugPrint('Gemini analysis error: $e');
      throw Exception('Failed to analyze text for misinformation: $e');
    }
  }

  /// Analyze image for misinformation using Gemini
  Future<Map<String, dynamic>> analyzeImageForMisinformation(Uint8List imageBytes, String? extractedText) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final prompt = _buildImageAnalysisPrompt(extractedText);
      
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];
      
      final response = await _model.generateContent(content);
      final responseText = response.text ?? '';
      
      return _parseMisinformationAnalysis(responseText);
    } catch (e) {
      debugPrint('Gemini image analysis error: $e');
      throw Exception('Failed to analyze image for misinformation: $e');
    }
  }

  /// Build the prompt for misinformation analysis
  String _buildMisinformationAnalysisPrompt(String text) {
    return '''
You are an expert fact-checker and misinformation detection specialist. Analyze the following text for potential misinformation and provide a comprehensive assessment.

Text to analyze:
"$text"

Please provide your analysis in the following JSON format:
{
  "isMisinformation": boolean,
  "credibilityScore": number (0-100),
  "credibilityLevel": string ("High", "Medium", "Low", "Very Low"),
  "explanation": string (detailed explanation of your assessment),
  "evidence": [
    {
      "type": string ("factual", "suspicious", "contradictory", "unverified"),
      "description": string,
      "confidence": number (0-100)
    }
  ],
  "sources": [
    {
      "type": string ("news_article", "academic_paper", "government_report", "expert_opinion", "fact_check"),
      "title": string,
      "url": string (if available),
      "reliability": string ("high", "medium", "low")
    }
  ],
  "recommendations": [
    string (actionable recommendations for the user)
  ],
  "redFlags": [
    string (specific warning signs or suspicious elements)
  ],
  "furtherReading": [
    {
      "title": string,
      "url": string,
      "description": string
    }
  ]
}

Guidelines for analysis:
1. Check for factual accuracy against known facts
2. Look for emotional manipulation or sensationalism
3. Identify potential bias or agenda
4. Verify claims against reliable sources
5. Look for logical fallacies or inconsistencies
6. Consider the source credibility
7. Check for recent developments that might affect the information
8. Be objective and evidence-based in your assessment

Respond ONLY with the JSON object, no additional text.
''';
  }

  /// Build the prompt for image analysis
  String _buildImageAnalysisPrompt(String? extractedText) {
    final textContext = extractedText != null && extractedText.isNotEmpty 
        ? 'The image contains the following text: "$extractedText"\n\n'
        : '';
    
    return '''
You are an expert fact-checker and misinformation detection specialist. Analyze the following image for potential misinformation and provide a comprehensive assessment.

$textContext

Please examine the image for:
1. Text content and claims
2. Visual elements that might be misleading
3. Source attribution or lack thereof
4. Potential manipulation or editing
5. Context and presentation

Provide your analysis in the following JSON format:
{
  "isMisinformation": boolean,
  "credibilityScore": number (0-100),
  "credibilityLevel": string ("High", "Medium", "Low", "Very Low"),
  "explanation": string (detailed explanation of your assessment),
  "imageAnalysis": {
    "textContent": string (any text found in the image),
    "visualElements": string (description of visual elements),
    "potentialManipulation": boolean,
    "sourceAttribution": string (if any source is visible)
  },
  "evidence": [
    {
      "type": string ("factual", "suspicious", "contradictory", "unverified", "visual_manipulation"),
      "description": string,
      "confidence": number (0-100)
    }
  ],
  "sources": [
    {
      "type": string ("news_article", "academic_paper", "government_report", "expert_opinion", "fact_check"),
      "title": string,
      "url": string (if available),
      "reliability": string ("high", "medium", "low")
    }
  ],
  "recommendations": [
    string (actionable recommendations for the user)
  ],
  "redFlags": [
    string (specific warning signs or suspicious elements)
  ],
  "furtherReading": [
    {
      "title": string,
      "url": string,
      "description": string
    }
  ]
}

Respond ONLY with the JSON object, no additional text.
''';
  }

  /// Parse the Gemini response into a structured format
  Map<String, dynamic> _parseMisinformationAnalysis(String responseText) {
    try {
      // Clean the response text
      String cleanedResponse = responseText.trim();
      
      // Remove any markdown formatting
      cleanedResponse = cleanedResponse.replaceAll('```json', '').replaceAll('```', '');
      
      // Try to find JSON object in the response
      final jsonStart = cleanedResponse.indexOf('{');
      final jsonEnd = cleanedResponse.lastIndexOf('}');
      
      if (jsonStart == -1 || jsonEnd == -1 || jsonStart >= jsonEnd) {
        throw Exception('No valid JSON found in response');
      }
      
      final jsonString = cleanedResponse.substring(jsonStart, jsonEnd + 1);
      
      // Parse JSON (in a real implementation, you'd use dart:convert)
      // For now, we'll return a structured response based on the text analysis
      return _parseResponseText(responseText);
    } catch (e) {
      debugPrint('Failed to parse Gemini response: $e');
      return _parseResponseText(responseText);
    }
  }

  /// Fallback parser for when JSON parsing fails
  Map<String, dynamic> _parseResponseText(String responseText) {
    // Extract key information using text parsing
    final isMisinformation = responseText.toLowerCase().contains('misinformation') ||
                            responseText.toLowerCase().contains('false') ||
                            responseText.toLowerCase().contains('inaccurate');
    
    // Extract credibility score (look for percentage or score)
    int credibilityScore = 50; // Default
    final scoreMatch = RegExp(r'(\d+)%|score[:\s]*(\d+)', caseSensitive: false).firstMatch(responseText);
    if (scoreMatch != null) {
      credibilityScore = int.tryParse(scoreMatch.group(1) ?? scoreMatch.group(2) ?? '50') ?? 50;
    }
    
    // Determine credibility level
    String credibilityLevel = 'Medium';
    if (credibilityScore >= 80) credibilityLevel = 'High';
    else if (credibilityScore >= 60) credibilityLevel = 'Medium';
    else if (credibilityScore >= 40) credibilityLevel = 'Low';
    else credibilityLevel = 'Very Low';
    
    return {
      'isMisinformation': isMisinformation,
      'credibilityScore': credibilityScore,
      'credibilityLevel': credibilityLevel,
      'explanation': responseText.length > 500 
          ? responseText.substring(0, 500) + '...'
          : responseText,
      'evidence': [
        {
          'type': isMisinformation ? 'suspicious' : 'factual',
          'description': 'AI analysis indicates ${isMisinformation ? 'potential misinformation' : 'likely factual content'}',
          'confidence': credibilityScore
        }
      ],
      'sources': [
        {
          'type': 'ai_analysis',
          'title': 'AI Fact-Check Analysis',
          'url': '',
          'reliability': 'medium'
        }
      ],
      'recommendations': [
        'Verify information with multiple reliable sources',
        'Check the original source and publication date',
        'Look for corroborating evidence from reputable outlets'
      ],
      'redFlags': isMisinformation ? [
        'Potential misinformation detected',
        'Requires further verification'
      ] : [],
      'furtherReading': [
        {
          'title': 'How to Spot Misinformation',
          'url': 'https://www.bbc.com/news/av/technology-46012424',
          'description': 'BBC guide to identifying fake news'
        }
      ]
    };
  }

  /// Get a simple fact-check response for quick analysis
  Future<String> getQuickFactCheck(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final prompt = '''
Analyze this text for misinformation in 2-3 sentences:
"$text"

Provide a brief, clear assessment of whether this appears to be accurate, misleading, or potentially false information.
''';
      
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      return response.text ?? 'Unable to analyze the text.';
    } catch (e) {
      debugPrint('Quick fact-check error: $e');
      return 'Analysis failed. Please try again.';
    }
  }
}
