import 'package:flutter/material.dart';
import 'core/services/app_settings_service.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/pages/splash_screen.dart';

import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow GoogleFonts to use runtime fetching but fail gracefully without crashing
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const AIScorecastApp());
}

class AIScorecastApp extends StatelessWidget {
  const AIScorecastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsService.instance,
      builder: (context, _) {
        final settings = AppSettingsService.instance;
        final accent = settings.accentColor;

        return MaterialApp(
          title: 'AI Scorecast',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: AppTheme.lightTheme(accent),
          darkTheme: AppTheme.darkTheme(accent),
          home: const SplashScreen(),
        );
      },
    );
  }
}

