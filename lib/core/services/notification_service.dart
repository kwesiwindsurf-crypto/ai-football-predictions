import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app_settings_service.dart';

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

  /// Fires a local notification if masterAlerts & alertKickoff are enabled.
  Future<void> showKickoffAlert({
    required int id,
    required String homeTeam,
    required String awayTeam,
    required String kickoffTime,
  }) async {
    final settings = AppSettingsService.instance;
    if (!settings.masterAlerts || !settings.alertKickoff) return;

    try {
      await _notificationsPlugin.show(
        id,
        '⚽ Match Kickoff Soon',
        '$homeTeam vs $awayTeam starts at $kickoffTime!',
        _notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing kickoff alert: $e');
    }
  }

  /// Fires a local notification when a goal is scored.
  Future<void> showGoalAlert({
    required int id,
    required String homeTeam,
    required String awayTeam,
    required int homeScore,
    required int awayScore,
    String? scoringTeam,
  }) async {
    final settings = AppSettingsService.instance;
    if (!settings.masterAlerts || !settings.alertGoals) return;

    final title = scoringTeam != null ? '⚽ GOAL! $scoringTeam' : '⚽ Goal Alert!';
    final body = '$homeTeam $homeScore - $awayScore $awayTeam';

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        _notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing goal alert: $e');
    }
  }

  /// Fires a local notification for high confidence AI predictions.
  Future<void> showHighConfidenceAlert({
    required int id,
    required String homeTeam,
    required String awayTeam,
    required String prediction,
    required double confidence,
  }) async {
    final settings = AppSettingsService.instance;
    if (!settings.masterAlerts || !settings.alertAiHighConfidence) return;

    try {
      await _notificationsPlugin.show(
        id,
        '🔥 High Confidence AI Pick (${confidence.toStringAsFixed(0)}%)',
        '$homeTeam vs $awayTeam: $prediction',
        _notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing high confidence alert: $e');
    }
  }

  /// Fires a local notification for value bet opportunities.
  Future<void> showValueBetAlert({
    required int id,
    required String homeTeam,
    required String awayTeam,
    required String detail,
  }) async {
    final settings = AppSettingsService.instance;
    if (!settings.masterAlerts || !settings.alertValueBets) return;

    try {
      await _notificationsPlugin.show(
        id,
        '💎 Value Bet Opportunity',
        '$homeTeam vs $awayTeam — $detail',
        _notificationDetails,
      );
    } catch (e) {
      debugPrint('Error showing value bet alert: $e');
    }
  }
}
