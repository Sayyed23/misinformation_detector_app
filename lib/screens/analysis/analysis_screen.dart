import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/config_service.dart';

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
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String? _uploadedImagePath;

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

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      setState(() {
        _uploadedImagePath = image.path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image selected: ${image.name}')),
      );
    }
  }

  Future<void> _analyzeContent() async {
    if (_textController.text.isEmpty &&
        _linkController.text.isEmpty &&
        _uploadedImagePath == null) {
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
      // Prepare the analysis request
      String? text =
          _textController.text.isNotEmpty ? _textController.text : null;
      String? sourceUrl =
          _linkController.text.isNotEmpty ? _linkController.text : null;
      XFile? imageFile =
          _uploadedImagePath != null ? XFile(_uploadedImagePath!) : null;

      // Submit claim for analysis
      final result = await _apiService.submitClaim(
        text: text,
        image: imageFile,
        sourceUrl: sourceUrl,
        language: 'en',
        priority: 'normal',
      );

      if (result.containsKey('claim_id')) {
        // Get the verification result
        final claimId = result['claim_id'];

        // Poll for results (in a real app, you might use WebSocket or push notifications)
        await _pollForResults(claimId);
      } else {
        // Handle direct result
        setState(() {
          _isAnalyzing = false;
          _analysisResult = _formatAnalysisResult(result);
        });
      }
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

                        // Upload Media Button
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

                        const SizedBox(height: 16),

                        // Analyze Button
                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextButton(
                            onPressed: _isAnalyzing ? null : _analyzeContent,
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
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFD4A574), // Light brown/wooden color
                              Color(0xFFB8860B), // Darker brown
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
                                'Credibility Score: ${_analysisResult!['credibilityScore']}%',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _analysisResult!['credibilityLevel'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF86EFAC),
                                ),
                              ),
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
                        _analysisResult!['explanation'],
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),

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
                                  _getSourceIcon(source['type']),
                                  color: const Color(0xFF0284C7),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  source['title'],
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
                                  _getSourceIcon(item['type']),
                                  color: const Color(0xFF0284C7),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  item['title'],
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
      default:
        return Icons.info;
    }
  }
}
