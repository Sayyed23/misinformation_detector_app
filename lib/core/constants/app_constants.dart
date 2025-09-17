/// App Constants
/// Contains all constant values used throughout the app
library;

class AppConstants {
  // Route Names
  static const String splashRoute = '/';
  static const String onboardingRoute = '/onboarding';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String homeRoute = '/home';
  static const String analysisRoute = '/analysis';
  static const String alertsRoute = '/alerts';
  static const String educationRoute = '/education';
  static const String communityRoute = '/community';
  static const String profileRoute = '/profile';
  static const String settingsRoute = '/settings';

  // Storage Keys
  static const String keyFirstLaunch = 'first_launch';
  static const String keyAuthToken = 'auth_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyUserName = 'user_name';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyAnalysisHistory = 'analysis_history';
  static const String keyLearningProgress = 'learning_progress';

  // API Endpoints
  static const String endpointLogin = '/auth/login';
  static const String endpointRegister = '/auth/register';
  static const String endpointLogout = '/auth/logout';
  static const String endpointRefreshToken = '/auth/refresh';
  static const String endpointForgotPassword = '/auth/forgot-password';
  static const String endpointResetPassword = '/auth/reset-password';
  static const String endpointAnalyzeText = '/analysis/text';
  static const String endpointAnalyzeUrl = '/analysis/url';
  static const String endpointAnalyzeImage = '/analysis/image';
  static const String endpointGetAlerts = '/alerts';
  static const String endpointGetModules = '/education/modules';
  static const String endpointGetQuizzes = '/education/quizzes';
  static const String endpointSubmitReport = '/community/report';
  static const String endpointGetReports = '/community/reports';
  static const String endpointGetProfile = '/user/profile';
  static const String endpointUpdateProfile = '/user/profile/update';

  // Credibility Score Ranges
  static const double scoreVeryLow = 20.0;
  static const double scoreLow = 40.0;
  static const double scoreMedium = 60.0;
  static const double scoreHigh = 80.0;

  // Alert Risk Levels
  static const String riskLevelLow = 'LOW';
  static const String riskLevelMedium = 'MEDIUM';
  static const String riskLevelHigh = 'HIGH';
  static const String riskLevelCritical = 'CRITICAL';

  // Content Categories
  static const List<String> contentCategories = [
    'Health',
    'Politics',
    'Finance',
    'Technology',
    'Entertainment',
    'Science',
    'Environment',
    'Education',
    'Sports',
    'Other',
  ];

  // Learning Module Difficulty
  static const String difficultyBeginner = 'BEGINNER';
  static const String difficultyIntermediate = 'INTERMEDIATE';
  static const String difficultyAdvanced = 'ADVANCED';

  // User Roles
  static const String roleGuest = 'GUEST';
  static const String roleUser = 'USER';
  static const String roleModerator = 'MODERATOR';
  static const String roleAdmin = 'ADMIN';

  // Achievement Types
  static const String achievementFirstAnalysis = 'first_analysis';
  static const String achievementTenAnalyses = 'ten_analyses';
  static const String achievementFirstReport = 'first_report';
  static const String achievementCommunityHelper = 'community_helper';
  static const String achievementLearningStreak = 'learning_streak';
  static const String achievementQuizMaster = 'quiz_master';

  // Error Messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork =
      'No internet connection. Please check your network.';
  static const String errorTimeout = 'Request timed out. Please try again.';
  static const String errorUnauthorized =
      'You are not authorized. Please login again.';
  static const String errorInvalidInput =
      'Invalid input. Please check and try again.';
  static const String errorServerError =
      'Server error. Please try again later.';

  // Success Messages
  static const String successLogin = 'Login successful!';
  static const String successRegister =
      'Registration successful! Please verify your email.';
  static const String successAnalysis = 'Analysis completed successfully!';
  static const String successReportSubmitted = 'Report submitted successfully!';
  static const String successProfileUpdated = 'Profile updated successfully!';

  // Regular Expressions
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp urlRegex = RegExp(
    r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
  );
  static final RegExp phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
}
