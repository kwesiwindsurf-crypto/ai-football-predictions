import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'app_settings_service.dart';
import 'matches_provider.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Channel Constants
  static const String _channelId = 'ai_scorecast_alerts';
  static const String _channelName = 'AI Scorecast Match Alerts';
  static const String _channelDescription =
      'Notifications for match kickoffs, live score changes, and AI prediction alerts.';

  Future<void> init() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped with payload: ${response.payload}');
        },
      );

      // Create Android Notification Channel
      if (!kIsWeb) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          const AndroidNotificationChannel channel = AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );

          await androidPlugin.createNotificationChannel(channel);
          await androidPlugin.requestNotificationsPermission();
        }
      }

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize NotificationService: $e');
    }
  }

  AndroidNotificationDetails get _androidDetails => AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: AppSettingsService.instance.alertSoundHaptics,
        enableVibration: AppSettingsService.instance.alertSoundHaptics,
        icon: '@mipmap/ic_launcher',
      );

  NotificationDetails get _notificationDetails => NotificationDetails(
        android: _androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  /// Notifications are only permitted while the app is open in the foreground
  /// and at least one match is currently LIVE.
  bool get canShowActiveAlert {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return false;
    }
    return MatchesProvider.instance.hasLiveMatches ||
        ApiService.liveMatchesNotifier.value.isNotEmpty;
  }

  Future<void> _showIfAllowed({
    required int id,
    required String title,
    required String body,
    required bool categoryEnabled,
    required String debugLabel,
  }) async {
    final settings = AppSettingsService.instance;
    if (!settings.masterAlerts || !categoryEnabled) return;
    if (!canShowActiveAlert) return;

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        _notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing $debugLabel: $e');
    }
  }

  /// Fires a local notification if masterAlerts & alertKickoff are enabled.
  Future<void> showKickoffAlert({
    required int id,
    required String homeTeam,
    required String awayTeam,
    required String kickoffTime,
  }) {
    return _showIfAllowed(
      id: id,
      title: '⚽ Match Kickoff Soon',
      body: '$homeTeam vs $awayTeam starts at $kickoffTime!',
      categoryEnabled: AppSettingsService.instance.alertKickoff,
      debugLabel: 'kickoff alert',
    );
  }

  /// Fires a local notification when a goal is scored in an active live match.
  Future<void> showGoalAlert({
    required int id,
    required String homeTeam,
    required String awayTeam,
    required int homeScore,
    required int awayScore,
    String? scoringTeam,
  }) {
    final title = scoringTeam != null ? '⚽ GOAL! $scoringTeam' : '⚽ Goal Alert!';
    final body = '$homeTeam $homeScore - $awayScore $awayTeam';

    return _showIfAllowed(
      id: id,
      title: title,
      body: body,
      categoryEnabled: AppSettingsService.instance.alertGoals,
      debugLabel: 'goal alert',
    );
  }

  /// Fires a local notification for high confidence AI predictions.
  Future<void> showHighConfidenceAlert({
    required int id,
    required String homeTeam,
    required String awayTeam,
    required String prediction,
    required double confidence,
  }) {
    return _showIfAllowed(
      id: id,
      title: '🔥 High Confidence AI Pick (${confidence.toStringAsFixed(0)}%)',
      body: '$homeTeam vs $awayTeam: $prediction',
      categoryEnabled: AppSettingsService.instance.alertAiHighConfidence,
      debugLabel: 'high confidence alert',
    );
  }

  /// Fires a local notification for value bet opportunities.
  Future<void> showValueBetAlert({
    required int id,
    required String homeTeam,
    required String awayTeam,
    required String detail,
  }) {
    return _showIfAllowed(
      id: id,
      title: '💎 Value Bet Opportunity',
      body: '$homeTeam vs $awayTeam — $detail',
      categoryEnabled: AppSettingsService.instance.alertValueBets,
      debugLabel: 'value bet alert',
    );
  }
}
