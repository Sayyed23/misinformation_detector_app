import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extract text from an image file
  Future<String> extractTextFromImage(XFile imageFile) async {
    try {
      // Read the image file
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Create input image
      final InputImage inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: Size(0, 0), // Will be determined by the image
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888, // Use BGRA8888 for image bytes
          bytesPerRow: 0, // Will be determined by the image
        ),
      );

      // Process the image
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      // Extract all text blocks
      String extractedText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText += '${line.text}\n';
        }
      }

      return extractedText.trim();
    } catch (e) {
      debugPrint('OCR Error: $e');
      throw Exception('Failed to extract text from image: $e');
    }
  }

  /// Extract text from image bytes
  Future<String> extractTextFromBytes(Uint8List imageBytes) async {
    try {
      // Create input image
      final InputImage inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: Size(0, 0), // Will be determined by the image
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888, // Use BGRA8888 for image bytes
          bytesPerRow: 0, // Will be determined by the image
        ),
      );

      // Process the image
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      // Extract all text blocks
      String extractedText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText += '${line.text}\n';
        }
      }

      return extractedText.trim();
    } catch (e) {
      debugPrint('OCR Error: $e');
      throw Exception('Failed to extract text from image bytes: $e');
    }
  }

  /// Extract text with confidence scores
  Future<Map<String, dynamic>> extractTextWithConfidence(
      XFile imageFile) async {
    try {
      // Read the image file
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Create input image
      final InputImage inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: Size(0, 0), // Will be determined by the image
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888, // Use BGRA8888 for image bytes
          bytesPerRow: 0, // Will be determined by the image
        ),
      );

      // Process the image
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      // Extract text with confidence scores
      String extractedText = '';
      List<Map<String, dynamic>> textBlocks = [];
      double totalConfidence = 0;
      int blockCount = 0;

      for (TextBlock block in recognizedText.blocks) {
        List<Map<String, dynamic>> lines = [];
        for (TextLine line in block.lines) {
          List<Map<String, dynamic>> elements = [];
          for (TextElement element in line.elements) {
            elements.add({
              'text': element.text,
              'confidence': element.confidence ?? 0.0,
              'boundingBox': {
                'left': element.boundingBox.left,
                'top': element.boundingBox.top,
                'right': element.boundingBox.right,
                'bottom': element.boundingBox.bottom,
              }
            });
            extractedText += '${element.text} ';
            totalConfidence += element.confidence ?? 0.0;
            blockCount++;
          }
          lines.add({
            'text': line.text,
            'confidence': line.confidence ?? 0.0,
            'elements': elements,
            'boundingBox': {
              'left': line.boundingBox.left,
              'top': line.boundingBox.top,
              'right': line.boundingBox.right,
              'bottom': line.boundingBox.bottom,
            }
          });
        }

        textBlocks.add({
          'text': block.text,
          'confidence': 0.0, // TextBlock doesn't have confidence
          'lines': lines,
          'boundingBox': {
            'left': block.boundingBox.left,
            'top': block.boundingBox.top,
            'right': block.boundingBox.right,
            'bottom': block.boundingBox.bottom,
          }
        });
      }

      final averageConfidence =
          blockCount > 0 ? totalConfidence / blockCount : 0.0;

      return {
        'extractedText': extractedText.trim(),
        'confidence': averageConfidence,
        'textBlocks': textBlocks,
        'totalBlocks': recognizedText.blocks.length,
      };
    } catch (e) {
      debugPrint('OCR Error: $e');
      throw Exception('Failed to extract text with confidence: $e');
    }
  }

  /// Dispose the text recognizer
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
