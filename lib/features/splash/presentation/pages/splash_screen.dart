import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/app_settings_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _bgDark = Color(0xFF050814);
  static const Color _neonCyan = Color(0xFF38BDF8);
  static const Color _neonPurple = Color(0xFF8B5CF6);

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _logoFadeAnimation;
  late final Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _scaleAnimation = Tween<double>(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.75, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final minDelay = Future<void>.delayed(const Duration(milliseconds: 1700));

    final initServices = () async {
      // 1. Initialize Firebase & Push Notifications safely (never block launch)
      try {
        await Firebase.initializeApp().timeout(const Duration(seconds: 3));
        await PushNotificationService.instance
            .initialize()
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Firebase/FCM init note: $e');
      }

      // 2. Setup Crashlytics
      if (!kIsWeb && Firebase.apps.isNotEmpty) {
        try {
          FlutterError.onError = (errorDetails) {
            FlutterError.presentError(errorDetails);
            try {
              if (Firebase.apps.isNotEmpty) {
                FirebaseCrashlytics.instance
                    .recordFlutterFatalError(errorDetails);
              }
            } catch (_) {}
          };
          PlatformDispatcher.instance.onError = (error, stack) {
            try {
              if (Firebase.apps.isNotEmpty) {
                FirebaseCrashlytics.instance
                    .recordError(error, stack, fatal: true);
              }
            } catch (_) {}
            return true;
          };
        } catch (e) {
          debugPrint('Crashlytics registration note: $e');
        }
      }

      // 3. Load App Settings, Notifications & Analytics
      try {
        await AppSettingsService.instance.loadSettings();
      } catch (_) {}
      try {
        await NotificationService.instance.init();
      } catch (_) {}
      try {
        await AnalyticsService.instance.init();
      } catch (_) {}
    }();

    await Future.wait([minDelay, initServices]);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => const MainNavigationShell(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final logoSize = (screenWidth * 0.64).clamp(200.0, 270.0);

    return Scaffold(
      backgroundColor: _bgDark,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle ambient radial glow matching the neon cyan/purple artwork
          Container(
            width: logoSize * 1.45,
            height: logoSize * 1.45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _neonCyan.withValues(alpha: 0.14),
                  _neonPurple.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.48, 1.0],
              ),
            ),
          ),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoFadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const RadialGradient(
                        radius: 0.68,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.78, 1.0],
                      ).createShader(bounds),
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(
                        'assets/images/app_logo.jpg',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FadeTransition(
                  opacity: _textFadeAnimation,
                  child: Column(
                    children: [
                      const Text(
                        'AI Scorecast',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'AI FOOTBALL PREDICTIONS',
                        style: TextStyle(
                          color: _neonCyan.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: 116,
                        height: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: const LinearProgressIndicator(
                            backgroundColor: Color(0xFF1E293B),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(_neonCyan),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
