/// App Configuration
/// Contains all app-wide configuration settings
library;

class AppConfig {
  // App Information
  static const String appName = 'TruthLens';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'AI-Powered Misinformation Detection & Education';

  // API Configuration
  static const String baseUrl = 'https://api.truthlens.com/v1';
  static const String apiVersion = 'v1';
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000;

  // Firebase Configuration (will be configured in firebase files)
  static const bool enableAnalytics = false; // Disabled for development
  static const bool enableCrashlytics = false; // Disabled for development

  // Feature Flags
  static const bool enableGuestMode = true;
  static const bool enableSocialLogin = true;
  static const bool enableOfflineMode = true;
  static const bool enableCommunityFeatures = true;
  static const bool enableGamification = true;

  // Cache Configuration
  static const int cacheValidityDays = 7;
  static const int maxCacheSize = 100; // MB

  // Content Analysis Limits
  static const int maxTextLength = 5000; // characters
  static const int maxImageSize = 10; // MB
  static const int maxVideoSize = 50; // MB
  static const int dailyAnalysisLimit = 50; // for free users

  // Learning Hub Configuration
  static const int quizTimeLimit = 60; // seconds per question
  static const int minPassScore = 70; // percentage
  static const int xpPerQuiz = 10;
  static const int xpPerModule = 50;

  // Community Configuration
  static const int minReputationToModerate = 100;
  static const int reportCooldownMinutes = 5;
  static const int maxReportsPerDay = 10;

  // UI Configuration
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  // Animation Durations
  static const int shortAnimationDuration = 200; // milliseconds
  static const int mediumAnimationDuration = 300;
  static const int longAnimationDuration = 500;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Session Configuration
  static const int sessionTimeoutMinutes = 30;
  static const bool enableBiometricAuth = true;

  // Debug Configuration
  static const bool debugMode = false;
  static const bool showPerformanceOverlay = false;
  static const bool enableLogging = true;
}
