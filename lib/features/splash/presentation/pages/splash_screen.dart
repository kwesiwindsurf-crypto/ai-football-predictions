import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/app_settings_service.dart';
import '../../../../core/services/betting_tracker_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../main/presentation/pages/main_layout.dart';
import '../../../onboarding/presentation/pages/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Initialize Firebase safely
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase core initialized');
      // Initialize Push Notifications (FCM)
      await PushNotificationService.instance.initialize();
    } catch (e) {
      debugPrint('Firebase initializeApp note: $e');
    }

    // 2. Setup Crashlytics
    if (!kIsWeb && Firebase.apps.isNotEmpty) {
      try {
        FlutterError.onError = (errorDetails) {
          FlutterError.presentError(errorDetails);
          try {
            if (Firebase.apps.isNotEmpty) {
              FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
            }
          } catch (_) {}
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          try {
            if (Firebase.apps.isNotEmpty) {
              FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
            }
          } catch (_) {}
          return true;
        };
      } catch (e) {
        debugPrint('Crashlytics registration note: $e');
      }
    } else {
      FlutterError.onError = (errorDetails) {
        FlutterError.presentError(errorDetails);
      };
    }

    // 3. Load App Services
    await AppSettingsService.instance.loadSettings();
    await BettingTrackerService.instance.init();
    await NotificationService.instance.init();
    await AnalyticsService.instance.init();

    // 4. Wait for animation to finish if it's faster than init
    await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
    ]);

    // Navigate to Main App or Onboarding
    if (mounted) {
      if (AppSettingsService.instance.hasSeenOnboarding) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainLayout()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep sleek navy from theme
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                  image: const DecorationImage(
                    image: AssetImage('assets/images/app_logo.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Text(
                    'AI Scorecast',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Initializing AI Engine...',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
