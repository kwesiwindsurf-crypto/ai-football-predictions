import 'package:flutter/material.dart';
import 'core/services/app_settings_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_bottom_nav_bar.dart';

import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

class CustomAppScrollBehavior extends MaterialScrollBehavior {
  const CustomAppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };
}

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
          scrollBehavior: const CustomAppScrollBehavior(),
          themeMode: settings.themeMode,
          theme: AppTheme.lightTheme(accent),
          darkTheme: AppTheme.darkTheme(accent),
          home: const MainNavigationShell(),
        );
      },
    );
  }
}

