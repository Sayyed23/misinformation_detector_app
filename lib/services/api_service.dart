import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'config_service.dart';

class ApiService {
  late final String _baseUrl;
  late final Dio _dio;
  final SupabaseClient _supabase = Supabase.instance.client;
  final ConfigService _config = ConfigService.instance;

  ApiService() {
    _baseUrl = _config.backendApiUrl;
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        if (_config.backendApiKey.isNotEmpty)
          'Authorization': 'Bearer ${_config.backendApiKey}',
      },
    ));

    // Add request interceptor to include auth token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          final session = _supabase.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // Use debugPrint instead of print for production code
        debugPrint('API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  // Submit claim for verification
  Future<Map<String, dynamic>> submitClaim({
    String? text,
    XFile? image,
    String? sourceUrl,
    String language = 'en',
    String priority = 'normal',
  }) async {
    try {
      String? imageUrl;

      // Upload image if provided
      if (image != null) {
        imageUrl = await _uploadImage(image);
      }

      final formData = FormData.fromMap({
        if (text != null) 'text': text,
        if (sourceUrl != null) 'source_url': sourceUrl,
        'language': language,
        'priority': priority,
        if (imageUrl != null) 'image_url': imageUrl,
      });

      final response = await _dio.post(
        _config.analyzeTextEndpoint,
        data: formData,
      );

      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to submit claim: $e');
    }
  }

  // Get verification results
  Future<Map<String, dynamic>> getVerificationResult(String claimId) async {
    try {
      final response = await _dio.get('${_config.getResultEndpoint}/$claimId');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to get verification result: $e');
    }
  }

  // Get user verification history
  Future<Map<String, dynamic>> getUserHistory({
    int limit = 50,
    int offset = 0,
    String? statusFilter,
  }) async {
    try {
      final response = await _dio.get(
        _config.userHistoryEndpoint,
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (statusFilter != null) 'status_filter': statusFilter,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to get user history: $e');
    }
  }

  // Get education content
  Future<List<Map<String, dynamic>>> getEducationContent({
    String? category,
    String language = 'en',
    String? difficulty,
    String? contentType,
    bool featuredOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/api/education/getEducationContent',
        queryParameters: {
          if (category != null) 'category': category,
          'language': language,
          if (difficulty != null) 'difficulty': difficulty,
          if (contentType != null) 'content_type': contentType,
          'featured_only': featuredOnly,
          'limit': limit,
          'offset': offset,
        },
      );
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to get education content: $e');
    }
  }

  // Get learning modules
  Future<List<Map<String, dynamic>>> getLearningModules({
    String language = 'en',
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      final response = await _dio.get(
        '/api/education/modules',
        queryParameters: {
          'language': language,
          if (user != null) 'user_id': user.id,
        },
      );
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to get learning modules: $e');
    }
  }

  // Get trending topics
  Future<Map<String, dynamic>> getTrendingTopics({
    String language = 'en',
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/education/trending-topics',
        queryParameters: {
          'language': language,
          'limit': limit,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to get trending topics: $e');
    }
  }

  // Get fact-check sources
  Future<Map<String, dynamic>> getFactCheckSources({
    String language = 'en',
  }) async {
    try {
      final response = await _dio.get(
        '/api/education/fact-check-sources',
        queryParameters: {
          'language': language,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to get fact-check sources: $e');
    }
  }

  // Track learning progress
  Future<Map<String, dynamic>> trackLearningProgress({
    required String moduleId,
    required String lessonId,
    required double completionPercentage,
    required int timeSpentMinutes,
  }) async {
    try {
      final response = await _dio.post(
        '/api/education/track-progress',
        data: {
          'module_id': moduleId,
          'lesson_id': lessonId,
          'completion_percentage': completionPercentage,
          'time_spent_minutes': timeSpentMinutes,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to track learning progress: $e');
    }
  }

  // Get user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await _dio.get('/api/users/profile');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateUserProfile({
    String? displayName,
    String? preferredLanguage,
    Map<String, bool>? notificationPreferences,
  }) async {
    try {
      final response = await _dio.put(
        '/api/users/profile',
        data: {
          if (displayName != null) 'display_name': displayName,
          if (preferredLanguage != null)
            'preferred_language': preferredLanguage,
          if (notificationPreferences != null)
            'notification_preferences': notificationPreferences,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Get user statistics
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final response = await _dio.get('/api/users/stats');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to get user stats: $e');
    }
  }

  // Get user badges
  Future<Map<String, dynamic>> getUserBadges() async {
    try {
      final response = await _dio.get('/api/users/badges');
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to get user badges: $e');
    }
  }

  // Report claim
  Future<Map<String, dynamic>> reportClaim({
    required String claimId,
    required String reason,
    String? additionalInfo,
  }) async {
    try {
      final response = await _dio.post(
        '/api/users/report-claim',
        data: {
          'claim_id': claimId,
          'reason': reason,
          if (additionalInfo != null) 'additional_info': additionalInfo,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to report claim: $e');
    }
  }

  // Get trending analysis (analytics)
  Future<Map<String, dynamic>> getTrendingAnalysis({
    String timeRange = '7d',
    String language = 'en',
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/analytics/trending',
        queryParameters: {
          'time_range': timeRange,
          'language': language,
          'limit': limit,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to get trending analysis: $e');
    }
  }

  // Get misinformation insights
  Future<Map<String, dynamic>> getMisinformationInsights({
    String? category,
    String timeRange = '30d',
    String language = 'en',
  }) async {
    try {
      final response = await _dio.get(
        '/api/analytics/insights',
        queryParameters: {
          if (category != null) 'category': category,
          'time_range': timeRange,
          'language': language,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to get misinformation insights: $e');
    }
  }

  // Upload image to Supabase Storage
  Future<String> _uploadImage(XFile image) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final filePath = 'claims/${user.id}/$fileName';

      final fileBytes = await File(image.path).readAsBytes();
      await _supabase.storage
          .from(_config.supabaseStorageBucket)
          .uploadBinary(filePath, fileBytes);

      final publicUrl = _supabase.storage
          .from(_config.supabaseStorageBucket)
          .getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Handle Dio exceptions
  Exception _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception(
            'Connection timeout. Please check your internet connection.');

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data['detail'] ?? e.response?.statusMessage;

        switch (statusCode) {
          case 400:
            return Exception('Bad request: $message');
          case 401:
            return Exception('Authentication required. Please log in again.');
          case 403:
            return Exception('Access denied: $message');
          case 404:
            return Exception('Resource not found: $message');
          case 429:
            return Exception('Too many requests. Please wait and try again.');
          case 500:
            return Exception('Server error: $message');
          default:
            return Exception('Request failed: $message');
        }

      case DioExceptionType.cancel:
        return Exception('Request was cancelled');

      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return Exception('No internet connection');
        }
        return Exception('Network error: ${e.message}');

      default:
        return Exception('Request failed: ${e.message}');
    }
  }

  // Get quiz for topic
  Future<Map<String, dynamic>> getTopicQuiz({
    required String topic,
    String difficulty = 'beginner',
  }) async {
    try {
      final response = await _dio.get(
        '/api/education/quiz/$topic',
        queryParameters: {
          'difficulty': difficulty,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to get quiz: $e');
    }
  }

  // Submit quiz answers
  Future<Map<String, dynamic>> submitQuizAnswers({
    required String quizId,
    required Map<String, String> answers,
  }) async {
    try {
      final response = await _dio.post(
        '/api/education/submit-quiz',
        data: {
          'quiz_id': quizId,
          'answers': answers,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw Exception('Failed to submit quiz: $e');
    }
  }
}

// Singleton pattern
class ApiServiceSingleton {
  static ApiService? _instance;
  static ApiService get instance {
    _instance ??= ApiService();
    return _instance!;
  }
}
