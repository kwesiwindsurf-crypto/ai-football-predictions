import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/main/presentation/pages/main_layout.dart';

void main() {
  runApp(const AIScorecastApp());
}

class AIScorecastApp extends StatelessWidget {
  const AIScorecastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Scorecast',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainLayout(),
    );
  }
}
