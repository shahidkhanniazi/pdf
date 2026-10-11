import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Phone notifications (the ones that appear in the status bar) for new
/// episodes. They are shown by the app itself after it finds new content,
/// so no server or Firebase setup is needed.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Payload of a notification the user tapped ("lang|kind:id").
  final StreamController<String> taps = StreamController.broadcast();
  String? launchPayload;

  static const _channel = AndroidNotificationDetails(
    'new_content',
    'New episodes',
    channelDescription: 'New stories and posts on Something Historic',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFFA67C2D),
  );

  Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload != null) taps.add(r.payload!);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        launchPayload = launch!.notificationResponse?.payload;
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: _channel,
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }
}
