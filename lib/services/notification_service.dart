import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'tropicaguide_channel',
    'TropicaGuide Notifications',
    description: 'Trip updates, packing list changes, and reminders.',
    importance: Importance.high,
  );

  // ── Initialize ───────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    // Request permission (iOS + Android 13+)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set up local notifications channel (Android)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initSettings);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  // ── Save FCM token to Firestore ──────────────────────────────────────────
  static Future<void> saveTokenToFirestore(String uid) async {
    final token = await _messaging.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });

    // Refresh token listener
    _messaging.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([newToken]),
      });
    });
  }

  // ── Remove FCM token on sign out ─────────────────────────────────────────
  static Future<void> removeTokenFromFirestore(String uid) async {
    final token = await _messaging.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayRemove([token]),
    });
  }

  // ── Handle foreground message ────────────────────────────────────────────
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ── Handle notification tap (app opened from notification) ───────────────
  static void _handleNotificationTap(RemoteMessage message) {
    // Navigation logic can be wired here using a global navigator key
    // e.g., navigate to the relevant trip screen
    final tripId = message.data['tripId'];
    if (tripId != null) {
      // NavigatorKey.currentState?.pushNamed('/trip', arguments: tripId);
    }
  }
}
