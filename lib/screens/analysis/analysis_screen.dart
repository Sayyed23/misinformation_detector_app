import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome Icons
import '../../services/config_service.dart';
import '../../services/ocr_service.dart';
import '../../services/gemini_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final ConfigService _config = ConfigService.instance;
  final OCRService _ocrService = OCRService();
  final GeminiService _geminiService = GeminiService();
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  XFile? _uploadedImage;
  XFile? _uploadedVideo;
  String _extractedText = '';
  bool _isExtractingText = false;
  String _translatedExplanation = '';
  bool _isTranslated = false;
  Map<String, dynamic>?
      _translatedAnalysisResult; // New state variable for full translated analysis
  String _selectedLanguage = 'en'; // Default to English
  final List<Map<String, String>> _translationLanguages = const [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'Hindi'},
    {'code': 'bn', 'name': 'Bengali'},
    {'code': 'te', 'name': 'Telugu'},
    {'code': 'mr', 'name': 'Marathi'},
    {'code': 'ta', 'name': 'Tamil'},
    {'code': 'ur', 'name': 'Urdu'},
    {'code': 'gu', 'name': 'Gujarati'},
    {'code': 'kn', 'name': 'Kannada'},
    {'code': 'ml', 'name': 'Malayalam'},
    {'code': 'or', 'name': 'Odia (Oriya)'},
    {'code': 'pa', 'name': 'Punjabi'},
    {'code': 'as', 'name': 'Assamese'},
    {'code': 'ks', 'name': 'Kashmiri'},
    {'code': 'ne', 'name': 'Nepali'},
    {'code': 'sd', 'name': 'Sindhi'},
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onInputChanged);
    _linkController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onInputChanged);
    _linkController.removeListener(_onInputChanged);
    _textController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {
      // This empty setState rebuilds the widget and re-evaluates the button's onPressed property
    });
  }

  Future<void> _pickMedia() async {
    if (!_config.enableImageAnalysis) {
      // Assuming video analysis also falls under this config
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media analysis is currently disabled')),
      );
      return;
    }

    // Show source selection dialog for image or video
    final MediaType? mediaType = await showDialog<MediaType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Media Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image'),
              onTap: () => Navigator.pop(context, MediaType.image),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Video'),
              onTap: () => Navigator.pop(context, MediaType.video),
            ),
          ],
        ),
      ),
    );

    if (mediaType == null) return;

    ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Media Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    XFile? pickedFile;

    if (mediaType == MediaType.image) {
      pickedFile = await picker.pickImage(source: source);
    } else if (mediaType == MediaType.video) {
      pickedFile = await picker.pickVideo(source: source);
    }

    if (pickedFile != null && mounted) {
      setState(() {
        _uploadedImage = mediaType == MediaType.image ? pickedFile : null;
        _uploadedVideo = mediaType == MediaType.video ? pickedFile : null;
        _extractedText = '';
        _analysisResult = null;
      });

      if (mediaType == MediaType.image) {
        // Automatically extract text from the image
        await _extractTextFromImage();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${mediaType == MediaType.image ? 'Image' : 'Video'} selected: ${pickedFile.name}')),
      );
    }
  }

  Future<void> _extractTextFromImage() async {
    if (_uploadedImage == null) return;

    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Image text extraction is not supported on web')),
        );
      }
      return;
    }

    setState(() {
      _isExtractingText = true;
    });

    try {
      final extractedText =
          await _ocrService.extractTextFromImage(_uploadedImage!);
      setState(() {
        _extractedText = extractedText;
        _isExtractingText = false;
      });

      if (extractedText.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Text extracted from image successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text found in the image')),
        );
      }
    } catch (e) {
      setState(() {
        _isExtractingText = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to extract text: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _analyzeContent() async {
    if (_textController.text.isEmpty &&
        _linkController.text.isEmpty &&
        _uploadedImage == null &&
        _uploadedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please enter text, a link, or upload an image or video to analyze')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    try {
      Map<String, dynamic> result;

      if (_uploadedImage != null) {
        // Analyze image with OCR + Gemini
        result = await _analyzeImageWithGemini();
      } else if (_uploadedVideo != null) {
        // Analyze video with Gemini
        result =
            await _geminiService.analyzeVideoForMisinformation(_uploadedVideo!);
      } else if (_textController.text.isNotEmpty) {
        // Analyze text with Gemini
        result = await _geminiService
            .analyzeTextForMisinformation(_textController.text);
      } else if (_linkController.text.isNotEmpty) {
        // Analyze URL with Gemini
        result = await _geminiService
            .analyzeUrlForMisinformation(_linkController.text);
      } else {
        throw Exception('No content to analyze');
      }

      setState(() {
        _isAnalyzing = false;
        _analysisResult = _formatGeminiAnalysisResult(result);
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _analyzeImageWithGemini() async {
    if (_uploadedImage == null) {
      throw Exception('No image to analyze');
    }

    // Get image bytes
    final imageBytes = await _uploadedImage!.readAsBytes();

    // Use extracted text if available, otherwise let Gemini analyze the image directly
    final extractedText = _extractedText.isNotEmpty ? _extractedText : null;

    // Analyze with Gemini
    return await _geminiService.analyzeImageForMisinformation(
        imageBytes, extractedText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF334155),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const Text(
                    'Check News / Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        // Show help dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('How to use'),
                            content: const Text(
                              'Paste text, links, or upload media to check the credibility of the information.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.help_outline,
                        color: Color(0xFF334155),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Language selection dropdown (moved here)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Translate to:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedLanguage,
                          icon: const Icon(Icons.arrow_downward,
                              color: Color(0xFF0284C7)),
                          iconSize: 20,
                          elevation: 16,
                          style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                          underline: Container(
                            height: 2,
                            color: const Color(0xFF0284C7),
                          ),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedLanguage = newValue!;
                              // Trigger full translation if a new language is selected and there's an analysis result
                              if (_analysisResult != null &&
                                  _selectedLanguage != 'en') {
                                _translateFullAnalysis();
                              } else if (_selectedLanguage == 'en') {
                                _isTranslated = false;
                                _analysisResult =
                                    null; // Clear translated result when switching to English
                              }
                            });
                          },
                          items: _translationLanguages
                              .map<DropdownMenuItem<String>>(
                                  (Map<String, String> lang) {
                            return DropdownMenuItem<String>(
                              value: lang['code'],
                              child: Text(lang['name']!),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Paste text, links, or upload media to check the credibility of the information.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF475569),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Input Fields
                    Column(
                      children: [
                        // Text Area
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: TextField(
                            controller: _textController,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Paste text here',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                            style: const TextStyle(color: Color(0xFF1E293B)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Link Input
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: TextField(
                            controller: _linkController,
                            decoration: const InputDecoration(
                              hintText: 'Paste link here',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                            style: const TextStyle(color: Color(0xFF1E293B)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Upload Media Button & Preview
                        Column(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextButton.icon(
                                onPressed: _pickMedia,
                                icon: const Icon(
                                  Icons.upload_file,
                                  color: Color(0xFF334155),
                                  size: 20,
                                ),
                                label: const Text(
                                  'Upload Media',
                                  style: TextStyle(
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            if (_uploadedImage != null ||
                                _uploadedVideo != null) ...[
                              const SizedBox(height: 12),
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 64,
                                            height: 64,
                                            child: (_uploadedImage != null)
                                                ? FutureBuilder<Uint8List>(
                                                    future: _uploadedImage!
                                                        .readAsBytes(),
                                                    builder:
                                                        (context, snapshot) {
                                                      if (snapshot.connectionState ==
                                                              ConnectionState
                                                                  .done &&
                                                          snapshot.hasData) {
                                                        return Image.memory(
                                                          snapshot.data!,
                                                          fit: BoxFit.cover,
                                                        );
                                                      } else {
                                                        return const Center(
                                                            child:
                                                                CircularProgressIndicator());
                                                      }
                                                    },
                                                  )
                                                : (_uploadedVideo != null)
                                                    ? const Icon(
                                                        Icons.video_file,
                                                        size: 64,
                                                        color: Color(
                                                            0xFF334155)) // Placeholder for video thumbnail
                                                    : const SizedBox.shrink(),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              (_uploadedImage?.name ??
                                                      _uploadedVideo?.name) ??
                                                  '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close,
                                                color: Colors.red),
                                            onPressed: () {
                                              setState(() {
                                                _uploadedImage = null;
                                                _uploadedVideo = null;
                                                _extractedText = '';
                                                _analysisResult = null;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      if (_isExtractingText) ...[
                                        const SizedBox(height: 8),
                                        const Row(
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Extracting text...',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (_extractedText.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Extracted Text:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _extractedText,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF334155),
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Analyze Button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: (_textController.text.isNotEmpty ||
                                    _linkController.text.isNotEmpty ||
                                    _uploadedImage != null ||
                                    _uploadedVideo != null)
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF94A3B8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextButton(
                            onPressed: (_isAnalyzing ||
                                    (_textController.text.isEmpty &&
                                        _linkController.text.isEmpty &&
                                        _uploadedImage == null &&
                                        _uploadedVideo == null))
                                ? null
                                : _analyzeContent,
                            child: _isAnalyzing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Check Credibility',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    // Analysis Results
                    if (_analysisResult != null) ...[
                      const SizedBox(height: 32),

                      // Credibility Score Card
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: (_isTranslated &&
                                        _translatedAnalysisResult != null &&
                                        _translatedAnalysisResult!['isMisinformation'] ==
                                            true) ||
                                    (!_isTranslated &&
                                        _analysisResult != null &&
                                        _analysisResult!['isMisinformation'] ==
                                            true)
                                ? [
                                    const Color(
                                        0xFFDC2626), // Red for misinformation
                                    const Color(0xFFB91C1C), // Darker red
                                  ]
                                : (_isTranslated &&
                                            _translatedAnalysisResult!['credibilityScore'] !=
                                                null &&
                                            (_translatedAnalysisResult!['credibilityScore']
                                                    as num) >=
                                                80) ||
                                        (!_isTranslated &&
                                            _analysisResult!['credibilityScore'] !=
                                                null &&
                                            (_analysisResult!['credibilityScore']
                                                    as num) >=
                                                80)
                                    ? [
                                        const Color(
                                            0xFF10B981), // Green for high credibility
                                        const Color(0xFF059669), // Darker green
                                      ]
                                    : (_isTranslated &&
                                                _translatedAnalysisResult![
                                                        'credibilityScore'] !=
                                                    null &&
                                                (_translatedAnalysisResult!['credibilityScore']
                                                        as num) >=
                                                    60) ||
                                            (!_isTranslated &&
                                                _analysisResult!['credibilityScore'] !=
                                                    null &&
                                                (_analysisResult!['credibilityScore']
                                                        as num) >=
                                                    60)
                                        ? [
                                            const Color(
                                                0xFFF59E0B), // Orange for medium credibility
                                            const Color(
                                                0xFFD97706), // Darker orange
                                          ]
                                        : [
                                            const Color(
                                                0xFFD4A574), // Light brown/wooden color
                                            const Color(
                                                0xFFB8860B), // Darker brown
                                          ],
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Color(0x99000000),
                                Color(0x00000000),
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Credibility Score: ${(_isTranslated && _translatedAnalysisResult!['credibilityScore'] != null ? _translatedAnalysisResult!['credibilityScore'] : _analysisResult!['credibilityScore']) ?? 'N/A'}%',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  softWrap: true,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (_isTranslated &&
                                            _translatedAnalysisResult![
                                                    'credibilityLevel'] !=
                                                null
                                        ? _translatedAnalysisResult![
                                            'credibilityLevel']
                                        : _analysisResult![
                                            'credibilityLevel']) ??
                                    'Unknown',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF86EFAC),
                                ),
                              ),
                              if ((_isTranslated &&
                                      _translatedAnalysisResult![
                                              'isMisinformation'] ==
                                          true) ||
                                  (!_isTranslated &&
                                      _analysisResult!['isMisinformation'] ==
                                          true)) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.red.withOpacity(0.5)),
                                  ),
                                  child: const Text(
                                    '⚠️ Potential Misinformation',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Explanation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Explanation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          // Only show button if explanation exists
                          if ((_isTranslated &&
                                  _translatedAnalysisResult!['explanation'] !=
                                      null &&
                                  (_translatedAnalysisResult!['explanation']
                                          as String)
                                      .isNotEmpty) ||
                              (!_isTranslated &&
                                  _analysisResult!['explanation'] != null &&
                                  (_analysisResult!['explanation'] as String)
                                      .isNotEmpty))
                            TextButton.icon(
                              onPressed: _translateExplanation,
                              icon: Icon(
                                Icons.translate,
                                size: 20,
                                color: Color(0xFF0284C7),
                              ),
                              label: Text(
                                _isTranslated ? 'Show Original' : 'Translate',
                                style: TextStyle(
                                  color: Color(0xFF0284C7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Language selection dropdown
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text(
                            'Translate to:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _selectedLanguage,
                            icon: const Icon(Icons.arrow_downward,
                                color: Color(0xFF0284C7)),
                            iconSize: 20,
                            elevation: 16,
                            style: const TextStyle(
                                color: Color(0xFF0284C7),
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            underline: Container(
                              height: 2,
                              color: const Color(0xFF0284C7),
                            ),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedLanguage = newValue!;
                                // Trigger full translation if a new language is selected and there's an analysis result
                                if (_analysisResult != null &&
                                    _selectedLanguage != 'en') {
                                  _translateFullAnalysis();
                                } else if (_selectedLanguage == 'en') {
                                  _isTranslated = false;
                                  _translatedAnalysisResult =
                                      null; // Clear translated result when switching to English
                                }
                              });
                            },
                            items: _translationLanguages
                                .map<DropdownMenuItem<String>>(
                                    (Map<String, String> lang) {
                              return DropdownMenuItem<String>(
                                value: lang['code'],
                                child: Text(lang['name']!),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isTranslated && _translatedExplanation.isNotEmpty
                            ? _translatedExplanation
                            : _analysisResult!['explanation'] ??
                                'No explanation available.',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Evidence Section
                      if (_currentAnalysisResult != null &&
                          _currentAnalysisResult!['evidence'] != null &&
                          (_currentAnalysisResult!['evidence'] as List)
                              .isNotEmpty) ...[
                        const Text(
                          'Evidence Analysis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(_currentAnalysisResult!['evidence'] as List).map(
                          (evidence) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    _getEvidenceColor(evidence['type'] ?? ''),
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getEvidenceColor(
                                        evidence['type'] ?? ''),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        evidence['description'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF334155),
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (evidence['confidence'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Confidence: ${evidence['confidence'] ?? 'N/A'}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Red Flags Section
                      if (_currentAnalysisResult != null &&
                          _currentAnalysisResult!['redFlags'] != null &&
                          (_currentAnalysisResult!['redFlags'] as List)
                              .isNotEmpty) ...[
                        const Text(
                          'Red Flags',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(_currentAnalysisResult!['redFlags'] as List).map(
                          (flag) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning,
                                  color: Color(0xFFDC2626),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    flag ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Recommendations Section
                      if (_currentAnalysisResult != null &&
                          _currentAnalysisResult!['recommendations'] != null &&
                          (_currentAnalysisResult!['recommendations'] as List)
                              .isNotEmpty) ...[
                        const Text(
                          'Recommendations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(_currentAnalysisResult!['recommendations'] as List)
                            .map(
                          (recommendation) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline,
                                  color: Color(0xFF16A34A),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    recommendation ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFF166534),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Source Evidence
                      if (_currentAnalysisResult != null &&
                          _currentAnalysisResult!['sources'] != null &&
                          (_currentAnalysisResult!['sources'] as List)
                              .isNotEmpty) ...[
                        const Text(
                          'Source Evidence',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(_currentAnalysisResult!['sources'] as List).map(
                          (source) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE0F2FE),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getSourceIcon(source['type'] ?? ''),
                                    color: const Color(0xFF0284C7),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    source['title'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF334155),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Further Reading
                      if (_currentAnalysisResult != null &&
                          _currentAnalysisResult!['furtherReading'] != null &&
                          (_currentAnalysisResult!['furtherReading'] as List)
                              .isNotEmpty) ...[
                        Column(
                          children: [
                            const Text(
                              'Further Reading',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children: (_currentAnalysisResult![
                                      'furtherReading'] as List)
                                  .map(
                                    (item) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0A000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFE0F2FE),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _getSourceIcon(
                                                  item['type'] ?? ''),
                                              color: const Color(0xFF0284C7),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              item['title'] ?? 'N/A',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF334155),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                            // Report Button
                            Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextButton(
                                onPressed: () {
                                  // Handle report functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Report submitted')),
                                  );
                                },
                                child: const Text(
                                  'Report as Misinformation',
                                  style: TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _translateExplanation() async {
    if (_analysisResult == null) {
      return;
    }
    if (_analysisResult?['explanation'] == null) {
      return;
    }

    if (_isTranslated) {
      setState(() {
        _isTranslated = false;
        _translatedExplanation = '';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true; // Indicate that a background operation is happening
    });

    try {
      final originalText = _analysisResult!['explanation'] as String;
      // Assuming `_geminiService` has a translateText method
      final translatedText =
          await _geminiService.translateText(originalText, _selectedLanguage);
      if (mounted) {
        setState(() {
          _translatedExplanation = translatedText;
          _isTranslated = true;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _translateFullAnalysis() async {
    if (_analysisResult == null || _selectedLanguage == 'en') {
      setState(() {
        _isTranslated = false;
        _translatedAnalysisResult = null;
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final originalAnalysis = _analysisResult!;
      final translatedMap = <String, dynamic>{};

      for (var entry in originalAnalysis.entries) {
        if (entry.value is String) {
          translatedMap[entry.key] = await _geminiService.translateText(
              entry.value as String, _selectedLanguage);
        } else if (entry.value is List) {
          final translatedList = [];
          for (var item in entry.value as List) {
            if (item is String) {
              translatedList.add(
                  await _geminiService.translateText(item, _selectedLanguage));
            } else if (item is Map) {
              final translatedItem = <String, dynamic>{};
              for (var subEntry in item.entries) {
                if (subEntry.value is String) {
                  translatedItem[subEntry.key] =
                      await _geminiService.translateText(
                          subEntry.value as String, _selectedLanguage);
                } else {
                  translatedItem[subEntry.key] = subEntry.value;
                }
              }
              translatedList.add(translatedItem);
            } else {
              translatedList.add(item);
            }
          }
          translatedMap[entry.key] = translatedList;
        } else {
          translatedMap[entry.key] = entry.value;
        }
      }

      setState(() {
        _translatedAnalysisResult = translatedMap;
        _isTranslated = true;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Full translation failed: ${e.toString()}')),
        );
      }
    }
  }

  Map<String, dynamic>? get _currentAnalysisResult =>
      _isTranslated && _translatedAnalysisResult != null
          ? _translatedAnalysisResult
          : _analysisResult;

  Map<String, dynamic> _formatGeminiAnalysisResult(
      Map<String, dynamic> result) {
    final credibilityScore =
        (result['credibilityScore'] as num? ?? 50).clamp(0, 100).toInt();
    final credibilityLevel = result['credibilityLevel'] ?? 'Medium';
    final isMisinformation = result['isMisinformation'] ?? false;

    return {
      'credibilityScore': credibilityScore,
      'credibilityLevel': credibilityLevel,
      'isMisinformation': isMisinformation,
      'explanation':
          result['explanation'] ?? 'Analysis completed successfully.',
      'evidence':
          (result['evidence'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      'sources':
          (result['sources'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      'recommendations':
          (result['recommendations'] as List?)?.cast<String>() ?? [],
      'redFlags': (result['redFlags'] as List?)?.cast<String>() ?? [],
      'furtherReading':
          (result['furtherReading'] as List?)?.cast<Map<String, dynamic>>() ??
              [
                {'type': 'article', 'title': 'Related Articles'},
                {
                  'type': 'instagram',
                  'title': 'Instagram Post',
                  'url': 'https://www.instagram.com/'
                },
                {
                  'type': 'youtube',
                  'title': 'YouTube Video',
                  'url': 'https://www.youtube.com/'
                },
              ],
      'extractedText': _extractedText,
    };
  }

  IconData _getSourceIcon(String type) {
    switch (type) {
      case 'newspaper':
        return Icons.newspaper;
      case 'person':
        return Icons.person;
      case 'link':
        return Icons.link;
      case 'article':
        return Icons.article;
      case 'news_article':
        return Icons.newspaper;
      case 'academic_paper':
        return Icons.school;
      case 'government_report':
        return Icons.account_balance;
      case 'expert_opinion':
        return Icons.person;
      case 'fact_check':
        return Icons.verified;
      case 'ai_analysis':
        return Icons.psychology;
      case 'instagram':
        return FontAwesomeIcons.instagram;
      case 'youtube':
        return FontAwesomeIcons.youtube;
      default:
        return Icons.info;
    }
  }

  Color _getEvidenceColor(String type) {
    switch (type) {
      case 'factual':
        return const Color(0xFF10B981); // Green
      case 'suspicious':
        return const Color(0xFFF59E0B); // Orange
      case 'contradictory':
        return const Color(0xFFEF4444); // Red
      case 'unverified':
        return const Color(0xFF6B7280); // Gray
      case 'visual_manipulation':
        return const Color(0xFFDC2626); // Dark red
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }
}

enum MediaType {
  image,
  video,
}
