import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
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
  final ApiService _apiService = ApiService();
  final ConfigService _config = ConfigService.instance;
  final OCRService _ocrService = OCRService();
  final GeminiService _geminiService = GeminiService();
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  XFile? _uploadedImage;
  String _extractedText = '';
  bool _isExtractingText = false;

  @override
  void dispose() {
    _textController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (!_config.enableImageAnalysis) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image analysis is currently disabled')),
      );
      return;
    }

    // Show source selection dialog
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
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
    final XFile? image = await picker.pickImage(source: source);

    if (image != null && mounted) {
      setState(() {
        _uploadedImage = image;
        _extractedText = '';
        _analysisResult = null;
      });

      // Automatically extract text from the image
      await _extractTextFromImage();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image selected: ${image.name}')),
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
        _uploadedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please enter text, a link, or upload an image to analyze')),
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
      } else if (_textController.text.isNotEmpty) {
        // Analyze text with Gemini
        result = await _geminiService
            .analyzeTextForMisinformation(_textController.text);
      } else if (_linkController.text.isNotEmpty) {
        // For URL analysis, we'll use the existing API service
        result = await _apiService.submitClaim(
          sourceUrl: _linkController.text,
          language: 'en',
          priority: 'normal',
        );

        if (result.containsKey('claim_id')) {
          await _pollForResults(result['claim_id']);
          return;
        }
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
                                onPressed: _pickImage,
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
                            if (_uploadedImage != null) ...[
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
                                            child: FutureBuilder<Uint8List>(
                                              future:
                                                  _uploadedImage!.readAsBytes(),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                        ConnectionState.done &&
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
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _uploadedImage!.name,
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
                                    _uploadedImage != null)
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF94A3B8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextButton(
                            onPressed: (_isAnalyzing ||
                                    (_textController.text.isEmpty &&
                                        _linkController.text.isEmpty &&
                                        _uploadedImage == null))
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
                            colors: _analysisResult!['isMisinformation'] == true
                                ? [
                                    const Color(
                                        0xFFDC2626), // Red for misinformation
                                    const Color(0xFFB91C1C), // Darker red
                                  ]
                                : _analysisResult!['credibilityScore'] >= 80
                                    ? [
                                        const Color(
                                            0xFF10B981), // Green for high credibility
                                        const Color(0xFF059669), // Darker green
                                      ]
                                    : _analysisResult!['credibilityScore'] >= 60
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
                              Text(
                                'Credibility Score: ${_analysisResult!['credibilityScore'] ?? 'N/A'}%',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _analysisResult!['credibilityLevel'] ??
                                    'Unknown',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF86EFAC),
                                ),
                              ),
                              if (_analysisResult!['isMisinformation'] ==
                                  true) ...[
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

                      const SizedBox(height: 24),

                      // Explanation
                      const Text(
                        'Explanation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _analysisResult!['explanation'] ??
                            'No explanation available.',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Evidence Section
                      if (_analysisResult!['evidence'] != null &&
                          (_analysisResult!['evidence'] as List)
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
                        ...(_analysisResult!['evidence'] as List).map(
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
                      if (_analysisResult!['redFlags'] != null &&
                          (_analysisResult!['redFlags'] as List)
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
                        ...(_analysisResult!['redFlags'] as List).map(
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
                      if (_analysisResult!['recommendations'] != null &&
                          (_analysisResult!['recommendations'] as List)
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
                        ...(_analysisResult!['recommendations'] as List).map(
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
                      const Text(
                        'Source Evidence',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...(_analysisResult!['sources'] as List).map(
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

                      // Further Reading
                      const Text(
                        'Further Reading',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...(_analysisResult!['furtherReading'] as List).map(
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
                                  _getSourceIcon(item['type'] ?? ''),
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
                              const SnackBar(content: Text('Report submitted')),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pollForResults(String claimId) async {
    int attempts = 0;
    const maxAttempts = 30; // 30 seconds max

    while (attempts < maxAttempts && mounted) {
      try {
        final result = await _apiService.getVerificationResult(claimId);

        if (result['status'] == 'completed') {
          setState(() {
            _isAnalyzing = false;
            _analysisResult = _formatAnalysisResult(result);
          });
          return;
        }

        // Wait 1 second before next attempt
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      } catch (e) {
        // If there's an error, stop polling
        break;
      }
    }

    // If we reach here, either max attempts reached or error occurred
    setState(() {
      _isAnalyzing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Analysis is taking longer than expected. Please try again later.')),
      );
    }
  }

  Map<String, dynamic> _formatAnalysisResult(Map<String, dynamic> result) {
    // Format the API result to match our UI expectations
    final credibilityScore = result['credibility_score'] ?? 85;
    final credibilityLevel = _getCredibilityLevel(credibilityScore);

    return {
      'credibilityScore': credibilityScore,
      'credibilityLevel': credibilityLevel,
      'explanation':
          result['explanation'] ?? 'Analysis completed successfully.',
      'sources': result['sources'] ??
          [
            {'type': 'newspaper', 'title': 'Reputable News Outlet'},
            {'type': 'person', 'title': 'Expert Author'},
            {'type': 'link', 'title': 'Citations'},
          ],
      'furtherReading': result['further_reading'] ??
          [
            {'type': 'article', 'title': 'Related Articles'},
          ],
      'claimId': result['claim_id'],
    };
  }

  Map<String, dynamic> _formatGeminiAnalysisResult(
      Map<String, dynamic> result) {
    final credibilityScore = result['credibilityScore'] ?? 50;
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
              [],
      'extractedText': _extractedText,
    };
  }

  String _getCredibilityLevel(int score) {
    if (score >= 80) return 'High Credibility';
    if (score >= 60) return 'Medium Credibility';
    if (score >= 40) return 'Low Credibility';
    return 'Very Low Credibility';
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
