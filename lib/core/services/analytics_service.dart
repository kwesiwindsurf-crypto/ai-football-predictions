import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _analytics = FirebaseAnalytics.instance;
      _isInitialized = true;
      debugPrint('AnalyticsService initialized successfully');
    } catch (e) {
      debugPrint('AnalyticsService initialization note: $e');
    }
  }

  /// Log screen view navigation across Web and Android
  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    debugPrint('📊 Analytics Screen View: $screenName');
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      debugPrint('Error logging screen view: $e');
    }
  }

  /// Log when user views match details
  Future<void> logMatchView({
    required String matchId,
    required String homeTeam,
    required String awayTeam,
    String? league,
  }) async {
    debugPrint('📊 Analytics Match View: $homeTeam vs $awayTeam ($matchId)');
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'match_viewed',
        parameters: {
          'match_id': matchId,
          'home_team': homeTeam,
          'away_team': awayTeam,
          'league': league ?? 'Unknown',
        },
      );
    } catch (e) {
      debugPrint('Error logging match view: $e');
    }
  }

  /// Log when user views an AI prediction
  Future<void> logPredictionView({
    required String matchId,
    required String prediction,
    required double confidence,
  }) async {
    debugPrint('📊 Analytics Prediction View: $prediction ($confidence%)');
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'prediction_viewed',
        parameters: {
          'match_id': matchId,
          'prediction': prediction,
          'confidence': confidence,
        },
      );
    } catch (e) {
      debugPrint('Error logging prediction view: $e');
    }
  }

  /// Log filter or tab changes
  Future<void> logFilterChanged({
    required String filterType,
    required String value,
  }) async {
    debugPrint('📊 Analytics Filter Changed: $filterType -> $value');
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'filter_changed',
        parameters: {
          'filter_type': filterType,
          'value': value,
        },
      );
    } catch (e) {
      debugPrint('Error logging filter change: $e');
    }
  }

  /// Log betting tracker activity
  Future<void> logBetTracked({
    required String matchId,
    required String pick,
    required double odds,
    required double stake,
  }) async {
    debugPrint('📊 Analytics Bet Tracked: $pick @ $odds ($stake)');
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'bet_tracked',
        parameters: {
          'match_id': matchId,
          'pick': pick,
          'odds': odds,
          'stake': stake,
        },
      );
    } catch (e) {
      debugPrint('Error logging bet tracked: $e');
    }
  }

  /// Log settings modification
  Future<void> logSettingsChanged({
    required String settingKey,
    required dynamic value,
  }) async {
    debugPrint('📊 Analytics Setting Changed: $settingKey = $value');
    if (!_isInitialized || _analytics == null) return;
    try {
      await _analytics!.logEvent(
        name: 'setting_changed',
        parameters: {
          'setting_key': settingKey,
          'setting_value': value.toString(),
        },
      );
    } catch (e) {
      debugPrint('Error logging setting change: $e');
    }
  }
}
