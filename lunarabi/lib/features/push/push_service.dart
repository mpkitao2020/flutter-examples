import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lunarabi/core/app_services.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/push/notification_link_parser.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(); // NO options
  debugPrint('FCM background message: ${message.messageId}');
}

class PushService {
  PushService({
    required this.navigator,
    required this.guard,
    required this.backend,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _local = localNotifications ?? FlutterLocalNotificationsPlugin();

  final AppNavigator navigator;
  final HostGuard guard;
  final PushBackendClient backend;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;

  static const _channelId = 'lunarabi_default';
  static const _channelName = 'Lunarabi';

  Future<void> start() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_lunarabi'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload);
          if (data is Map<String, dynamic>) {
            _openLink(data);
          } else if (data is Map) {
            _openLink(Map<String, dynamic>.from(data));
          }
        } catch (error) {
          debugPrint('PushService: bad local payload $error');
        }
      },
    );

    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              importance: Importance.high,
            ),
          );
    }

    try {
      await _messaging.requestPermission();
    } catch (error) {
      debugPrint('PushService: permission request failed: $error');
    }

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }
    } catch (error) {
      debugPrint('PushService: getToken failed: $error');
    }

    _messaging.onTokenRefresh.listen((token) {
      _registerToken(token);
    });

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      await _onOpened(initial);
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await backend.register(token);
      await AppServices.bridgeHost.notifyPushToken(token);
    } catch (error) {
      debugPrint('PushService: register failed: $error');
    }
  }

  Future<void> _onForeground(RemoteMessage message) async {
    final notification = message.notification;
    final data = Map<String, dynamic>.from(message.data);
    await _local.show(
      id: notification.hashCode,
      title: notification?.title ?? 'Lunarabi',
      body: notification?.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          icon: '@drawable/ic_stat_lunarabi',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(data),
    );
  }

  Future<void> _onOpened(RemoteMessage message) async {
    await _openLink(Map<String, dynamic>.from(message.data));
  }

  Future<void> _openLink(Map<String, dynamic> data) async {
    final uri = parseNotificationLink(data, guard);
    if (uri == null) {
      debugPrint('PushService: link blocked or missing');
      return;
    }
    await navigator.openFromNotification(uri);
  }
}
