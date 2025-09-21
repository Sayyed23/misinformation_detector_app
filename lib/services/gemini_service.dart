import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'config_service.dart';
import 'dart:convert'; // Import for JSON decoding
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'package:image_picker/image_picker.dart'; // For XFile
import 'package:video_thumbnail/video_thumbnail.dart'; // For video thumbnail generation

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
        throw Exception(
            'Gemini API key not found. Please check your configuration.');
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
          SafetySetting(
              HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
          SafetySetting(
              HarmCategory.dangerousContent, HarmBlockThreshold.medium),
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
  Future<Map<String, dynamic>> analyzeImageForMisinformation(
      Uint8List imageBytes, String? extractedText) async {
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

  /// Translate text using Gemini
  Future<String> translateText(String text, String targetLanguage) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final prompt = 'Translate the following text to $targetLanguage: "$text"';
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'Translation failed.';
    } catch (e) {
      debugPrint('Gemini translation error: $e');
      throw Exception('Failed to translate text: $e');
    }
  }

  /// Analyze video for misinformation using Gemini
  Future<Map<String, dynamic>> analyzeVideoForMisinformation(
      XFile videoFile) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // 1. Generate thumbnail from video
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512, // Max width of thumbnail
        quality: 75, // Thumbnail quality
      );

      if (thumbnailBytes == null) {
        throw Exception('Failed to generate video thumbnail.');
      }

      // 2. (Conceptual) Transcribe audio from video
      // This would require an external service/library for actual audio transcription.
      // For now, we'll use a placeholder or assume no audio transcription.
      const String audioTranscription = ''; // Placeholder

      // 3. Send thumbnail and (optional) transcribed text to Gemini
      final prompt = _buildVideoAnalysisPrompt(audioTranscription);
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', thumbnailBytes),
        ])
      ];

      final response = await _model.generateContent(content);
      final responseText = response.text ?? '';

      return _parseMisinformationAnalysis(responseText);
    } catch (e) {
      debugPrint('Gemini video analysis error: $e');
      return {
        'isMisinformation': true,
        'credibilityScore': 0,
        'credibilityLevel': 'Unknown',
        'explanation': 'Failed to analyze video content: ${e.toString()}',
        'evidence': [],
        'sources': [],
        'recommendations': [],
        'redFlags': [],
        'furtherReading': [],
      };
    }
  }

  /// Analyze URL for misinformation using Gemini
  Future<Map<String, dynamic>> analyzeUrlForMisinformation(String url) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to load URL content: ${response.statusCode}');
      }

      // For simplicity, we'll take the first 2000 characters of the body
      // In a real app, you might want a more sophisticated content extraction
      final contentToAnalyze =
          response.body.substring(0, response.body.length.clamp(0, 2000));

      final prompt =
          _buildMisinformationAnalysisPrompt(contentToAnalyze, sourceUrl: url);
      final geminiContent = [Content.text(prompt)];
      final geminiResponse = await _model.generateContent(geminiContent);
      final responseText = geminiResponse.text ?? '';

      return _parseMisinformationAnalysis(responseText);
    } catch (e) {
      debugPrint('Gemini URL analysis error: $e');
      return {
        'isMisinformation': true,
        'credibilityScore': 0,
        'credibilityLevel': 'Unknown',
        'explanation': 'Failed to analyze URL content: ${e.toString()}',
        'evidence': [],
        'sources': [],
        'recommendations': [],
        'redFlags': [],
        'furtherReading': [],
      };
    }
  }

  /// Build the prompt for misinformation analysis
  String _buildMisinformationAnalysisPrompt(String text, {String? sourceUrl}) {
    String urlContext = sourceUrl != null && sourceUrl.isNotEmpty
        ? 'The information is sourced from the following URL: $sourceUrl\n\n'
        : '';
    return '''
${urlContext}You are an expert fact-checker and misinformation detection specialist. Analyze the following text for potential misinformation and provide a comprehensive assessment.

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

  /// Build the prompt for video analysis
  String _buildVideoAnalysisPrompt(String audioTranscription) {
    final textContext = audioTranscription.isNotEmpty
        ? 'The video contains the following audio transcription: "$audioTranscription"\n\n'
        : '';

    return '''
You are an expert fact-checker and misinformation detection specialist. Analyze the following video for potential misinformation and provide a comprehensive assessment.

$textContext

Please examine the video for:
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
  "videoAnalysis": {
    "textContent": string (any text found in the video),
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
      cleanedResponse =
          cleanedResponse.replaceAll('```json', '').replaceAll('```', '');

      // Try to find JSON object in the response
      final jsonStart = cleanedResponse.indexOf('{');
      final jsonEnd = cleanedResponse.lastIndexOf('}');

      if (jsonStart == -1 || jsonEnd == -1 || jsonStart >= jsonEnd) {
        throw Exception('No valid JSON found in response');
      }

      final jsonString = cleanedResponse.substring(jsonStart, jsonEnd + 1);

      // Parse JSON
      return jsonDecode(jsonString);
    } catch (e) {
      debugPrint('Failed to parse Gemini response: $e');
      // Fallback to simpler parsing if JSON fails
      return {
        'isMisinformation': true,
        'credibilityScore': 0,
        'credibilityLevel': 'Unknown',
        'explanation': 'Failed to parse analysis result. Please try again.',
        'evidence': [],
        'sources': [],
        'recommendations': [],
        'redFlags': [],
        'furtherReading': [],
      };
    }
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
