import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

      // 4. Auto-subscribe to the general live_scores topic
      await messaging.subscribeToTopic('live_scores');
      debugPrint('Successfully subscribed to FCM topic: live_scores');

      // 5. Handle foreground notifications (heads-up popup when app is open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground message received: ${message.notification?.title}');
        final notification = message.notification;
        if (notification != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title ?? '⚽ Match Alert',
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
        }
      });

      _initialized = true;
    } catch (e) {
      debugPrint('PushNotificationService initialization error: $e');
    }
  }

  /// Subscribe to a specific match topic (e.g., 'match_12345')
  Future<void> subscribeToMatch(String matchId) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('match_$matchId');
    } catch (e) {
      debugPrint('Error subscribing to match $matchId: $e');
    }
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
