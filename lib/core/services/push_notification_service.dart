import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app_settings_service.dart';
import 'notification_service.dart';

/// Top-level background message handler required by FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('FCM background message received: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Check if Firebase is initialized
    if (Firebase.apps.isEmpty) {
      debugPrint('Firebase not yet initialized. Push notification setup skipped.');
      return;
    }

    try {
      // 1. Setup background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Request permissions on iOS and Android 13+
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('User notification permission status: ${settings.authorizationStatus}');

      // 3. Setup local notification channel for foreground alerts (Android)
      const androidChannel = AndroidNotificationChannel(
        'live_scores_channel',
        'Live Scores & Goal Alerts',
        description: 'Instant notifications when goals and match events happen.',
        importance: Importance.max,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotifications.initialize(initSettings);

      // 4. Unsubscribe from global live_scores topic so devices never receive
      // background/closed-app goal push alerts. Alerts run in-app when active.
      try {
        await messaging.unsubscribeFromTopic('live_scores');
        debugPrint('Unsubscribed from background FCM topic: live_scores');
      } catch (e) {
        debugPrint('Note unsubscribing from live_scores: $e');
      }

      // 5. Only surface foreground FCM messages if master alerts are on,
      // a live match is active, and it is not a redundant global goal push.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground message received: ${message.notification?.title}');
        final notification = message.notification;
        if (notification == null) return;

        final title = notification.title ?? '⚽ Match Alert';
        final isGoalPush = message.from == '/topics/live_scores' ||
            title.toUpperCase().contains('GOAL');
        if (isGoalPush) return;
        if (!AppSettingsService.instance.masterAlerts) return;
        if (!NotificationService.instance.canShowActiveAlert) return;

        _localNotifications.show(
          notification.hashCode,
          title,
          notification.body ?? '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              androidChannel.id,
              androidChannel.name,
              channelDescription: androidChannel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/launcher_icon',
            ),
          ),
        );
      });

      _initialized = true;
    } catch (e) {
      debugPrint('PushNotificationService initialization error: $e');
    }
  }

  /// Background per-match goal pushes are disabled (alerts are in-app only).
  Future<void> subscribeToMatch(String matchId) async {
    await unsubscribeFromMatch(matchId);
  }

  /// Unsubscribe from a match
  Future<void> unsubscribeFromMatch(String matchId) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('match_$matchId');
    } catch (e) {
      debugPrint('Error unsubscribing from match $matchId: $e');
    }
  }
}
