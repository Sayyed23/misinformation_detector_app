import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static ConfigService? _instance;
  static ConfigService get instance {
    _instance ??= ConfigService._();
    return _instance!;
  }

  ConfigService._();

  // API Configuration
  String get backendApiUrl =>
      dotenv.env['BACKEND_API_URL'] ??
      'https://misinformation-detection-api-abc123-uc.a.run.app';
  String get backendApiKey => dotenv.env['BACKEND_API_KEY'] ?? '';

  // Google Cloud APIs
  String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  String get googleCloudProjectId =>
      dotenv.env['GOOGLE_CLOUD_PROJECT_ID'] ?? '';

  // Supabase Configuration
  String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://fpxczbnluwmxsdpkyddl.supabase.co';
  String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZweGN6Ym5sdXdteHNkcGt5ZGRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3MjkzNjQsImV4cCI6MjA3MjMwNTM2NH0.apU_DKxDUB5Ion8DI6nQNZUJ-uVu_emULzWdve-PPNg';

  // API Endpoints
  String get analyzeTextEndpoint =>
      dotenv.env['API_ENDPOINT_ANALYZE_TEXT'] ?? '/api/claims/submitClaim';
  String get analyzeUrlEndpoint =>
      dotenv.env['API_ENDPOINT_ANALYZE_URL'] ?? '/api/claims/submitClaim';
  String get analyzeImageEndpoint =>
      dotenv.env['API_ENDPOINT_ANALYZE_IMAGE'] ?? '/api/claims/submitClaim';
  String get getResultEndpoint =>
      dotenv.env['API_ENDPOINT_GET_RESULT'] ?? '/api/claims/verifyClaim';
  String get userHistoryEndpoint =>
      dotenv.env['API_ENDPOINT_USER_HISTORY'] ?? '/api/users/userHistory';

  // App Configuration
  String get appName => dotenv.env['APP_NAME'] ?? 'TruthLens';
  String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  bool get debugMode => dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';

  // Feature Flags
  bool get enableImageAnalysis =>
      dotenv.env['ENABLE_IMAGE_ANALYSIS']?.toLowerCase() == 'true';
  bool get enableUrlAnalysis =>
      dotenv.env['ENABLE_URL_ANALYSIS']?.toLowerCase() == 'true';
  bool get enableTextAnalysis =>
      dotenv.env['ENABLE_TEXT_ANALYSIS']?.toLowerCase() == 'true';

  // Storage Configuration
  String get supabaseStorageBucket =>
      dotenv.env['SUPABASE_STORAGE_BUCKET'] ?? 'images';

  // Rate Limiting
  int get apiRateLimitRequestsPerMinute =>
      int.tryParse(dotenv.env['API_RATE_LIMIT_REQUESTS_PER_MINUTE'] ?? '60') ??
      60;
  int get apiRateLimitRequestsPerHour =>
      int.tryParse(dotenv.env['API_RATE_LIMIT_REQUESTS_PER_HOUR'] ?? '1000') ??
      1000;

  // Cache Configuration
  int get cacheDurationMinutes =>
      int.tryParse(dotenv.env['CACHE_DURATION_MINUTES'] ?? '30') ?? 30;
  int get cacheMaxEntries =>
      int.tryParse(dotenv.env['CACHE_MAX_ENTRIES'] ?? '100') ?? 100;

  /// Initialize the configuration service
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // If .env file doesn't exist or can't be loaded, use default values
      debugPrint(
          'Warning: Could not load .env file. Using default configuration. Error: $e');
    }
  }

  /// Check if all required configuration is available
  bool get isConfigurationValid {
    return backendApiUrl.isNotEmpty &&
        supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty;
  }

  /// Get configuration summary for debugging
  Map<String, dynamic> get configurationSummary {
    return {
      'backendApiUrl': backendApiUrl,
      'supabaseUrl': supabaseUrl,
      'appName': appName,
      'appVersion': appVersion,
      'debugMode': debugMode,
      'enableImageAnalysis': enableImageAnalysis,
      'enableUrlAnalysis': enableUrlAnalysis,
      'enableTextAnalysis': enableTextAnalysis,
      'isConfigurationValid': isConfigurationValid,
    };
  }
}
