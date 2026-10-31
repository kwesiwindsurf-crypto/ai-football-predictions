import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/api_service.dart';
import 'core/services/app_settings_service.dart';
import 'core/services/betting_tracker_service.dart';
import 'core/services/leagues_provider.dart';
import 'core/services/live_sync_engine.dart';
import 'core/services/matches_provider.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow GoogleFonts to use runtime fetching but fail gracefully without crashing
  GoogleFonts.config.allowRuntimeFetching = true;
  // Pre-warm local cache before first frame so HomeScreen starts with data in 0ms without shimmering!
  await ApiService.preWarmCache();

  // ⚡ Start global lifecycle-aware live sync engine (auto-syncs Tracker, Matches, Leagues)
  LiveSyncEngine.instance.init();
  await MatchesProvider.instance.init();
  await BettingTrackerService.instance.init();
  LeaguesProvider.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: MatchesProvider.instance),
        ChangeNotifierProvider.value(value: BettingTrackerService.instance),
        ChangeNotifierProvider.value(value: LeaguesProvider.instance),
        ChangeNotifierProvider.value(value: AppSettingsService.instance),
      ],
      child: const AIScorecastApp(),
    ),
  );
}

class AIScorecastApp extends StatelessWidget {
  const AIScorecastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsService>(
      builder: (context, settings, _) {
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

