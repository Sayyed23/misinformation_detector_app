import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

// Configuration imports
import 'config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';

// Screen imports
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations (not applicable for web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://fpxczbnluwmxsdpkyddl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZweGN6Ym5sdXdteHNkcGt5ZGRsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3MjkzNjQsImV4cCI6MjA3MjMwNTM2NH0.apU_DKxDUB5Ion8DI6nQNZUJ-uVu_emULzWdve-PPNg',
  );

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Set system UI overlay style (not applicable for web)
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  runApp(
    MultiProvider(
      providers: [
        // Add providers here as needed
        Provider<SharedPreferences>.value(value: prefs),
      ],
      child: TruthLensApp(prefs: prefs),
    ),
  );
}

class TruthLensApp extends StatefulWidget {
  final SharedPreferences prefs;

  const TruthLensApp({
    super.key,
    required this.prefs,
  });

  @override
  State<TruthLensApp> createState() => _TruthLensAppState();
}

class _TruthLensAppState extends State<TruthLensApp> {
  late final GoRouter _router;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _initializeApp() {
    // Get theme mode from preferences
    final themeModeString = widget.prefs.getString(AppConstants.keyThemeMode);
    _themeMode = _getThemeModeFromString(themeModeString);

    // Initialize router
    _router = _createRouter();
  }

  ThemeMode _getThemeModeFromString(String? mode) {
    switch (mode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  GoRouter _createRouter() {
    final bool isFirstLaunch = widget.prefs.getBool(AppConstants.keyFirstLaunch) ?? true;
    final bool hasSupabaseSession = Supabase.instance.client.auth.currentUser != null;
    final bool isLocalGuest = widget.prefs.getBool('is_local_guest') ?? false;
    final bool isAuthenticated = hasSupabaseSession || isLocalGuest;

    return GoRouter(
      initialLocation: _getInitialRoute(isFirstLaunch, isAuthenticated),
      routes: [
        // Splash Screen
        GoRoute(
          path: AppConstants.splashRoute,
          builder: (context, state) => const SplashScreen(),
        ),
        // Onboarding
        GoRoute(
          path: AppConstants.onboardingRoute,
          builder: (context, state) => const OnboardingScreen(),
        ),
        // Auth Routes
        GoRoute(
          path: AppConstants.loginRoute,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppConstants.registerRoute,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: AppConstants.signupRoute,
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: AppConstants.profileSetupRoute,
          builder: (context, state) => const ProfileSetupScreen(),
        ),
        GoRoute(
          path: AppConstants.forgotPasswordRoute,
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        // Main App Routes
        GoRoute(
          path: AppConstants.homeRoute,
          builder: (context, state) => const MainNavigationScreen(),
        ),
        // Feature Routes
        GoRoute(
          path: AppConstants.analysisRoute,
          builder: (context, state) => const AnalysisScreen(),
        ),
        GoRoute(
          path: AppConstants.alertsRoute,
          builder: (context, state) => const AlertsScreen(),
        ),
        GoRoute(
          path: AppConstants.educationRoute,
          builder: (context, state) => const EducationScreen(),
        ),
        GoRoute(
          path: AppConstants.communityRoute,
          builder: (context, state) => const CommunityScreen(),
        ),
        GoRoute(
          path: AppConstants.profileRoute,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppConstants.settingsRoute,
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
      errorBuilder: (context, state) => const ErrorScreen(),
    );
  }

  String _getInitialRoute(bool isFirstLaunch, bool isAuthenticated) {
    if (isFirstLaunch) {
      return AppConstants.splashRoute;
    } else if (!isAuthenticated) {
      return AppConstants.loginRoute;
    } else {
      return AppConstants.homeRoute;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: AppConfig.debugMode,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}

// Temporary placeholder screens - Replace with actual implementations
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final prefs = context.read<SharedPreferences>();
    final isFirstLaunch = prefs.getBool(AppConstants.keyFirstLaunch) ?? true;
    final authToken = prefs.getString(AppConstants.keyAuthToken);
    
    if (!mounted) return;
    
    if (isFirstLaunch) {
      context.go(AppConstants.onboardingRoute);
    } else if (authToken == null || authToken.isEmpty) {
      context.go(AppConstants.loginRoute);
    } else {
      context.go(AppConstants.homeRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user,
              size: 100,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(height: 24),
            Text(
              AppConfig.appName,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppConfig.appDescription,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Register Screen placeholder
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override  
  Widget build(BuildContext context) {
  // TODO: Implement proper register screen with Supabase auth
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: const Center(
        child: Text('Register Screen - To be implemented'),
      ),
    );
  }
}


class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: const Center(child: Text('Forgot Password Screen')),
    );
  }
}


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConfig.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(AppConstants.settingsRoute),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConfig.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConfig.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stay informed and combat misinformation',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Analyzed Today',
                    '5',
                    Icons.analytics,
                    AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Learning Streak',
                    '3 days',
                    Icons.local_fire_department,
                    AppTheme.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Feature Cards
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildFeatureCard(
                  context,
                  'Analyze Content',
                  Icons.search,
                  AppTheme.primaryColor,
                  () => context.push(AppConstants.analysisRoute),
                ),
                _buildFeatureCard(
                  context,
                  'Trending Alerts',
                  Icons.warning_amber,
                  AppTheme.warningColor,
                  () => context.push(AppConstants.alertsRoute),
                ),
                _buildFeatureCard(
                  context,
                  'Learn & Earn',
                  Icons.school,
                  AppTheme.secondaryColor,
                  () => context.push(AppConstants.educationRoute),
                ),
                _buildFeatureCard(
                  context,
                  'Community',
                  Icons.people,
                  AppTheme.infoColor,
                  () => context.push(AppConstants.communityRoute),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.paddingMedium),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.paddingMedium),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content Analysis')),
      body: const Center(child: Text('Analysis Screen')),
    );
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Misinformation Alerts')),
      body: const Center(child: Text('Alerts Screen')),
    );
  }
}

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learning Hub')),
      body: const Center(child: Text('Education Screen')),
    );
  }
}

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: const Center(child: Text('Community Screen')),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Profile Screen')),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings Screen')),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            const Text('Something went wrong'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppConstants.homeRoute),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
