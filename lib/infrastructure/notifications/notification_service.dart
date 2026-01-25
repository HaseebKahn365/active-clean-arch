import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'dart:async';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final _onResponse = StreamController<String?>.broadcast();
  Stream<String?> get onResponse => _onResponse.stream;

  static const String channelId = 'running_activities';
  static const String channelName = 'Running Activities';
  static const String channelDescription = 'Notifications for active timers';

  static const String goalChannelId = 'goal_reached';
  static const String goalChannelName = 'Goal Reached';
  static const String goalChannelDescription = 'Notifications when goals are exceeded';

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        _onResponse.add(details.payload);
      },
    );

    // Create Notification Channels for Android
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.low,
          showBadge: false,
          playSound: false,
          enableVibration: false,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          goalChannelId,
          goalChannelName,
          description: goalChannelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
  }

  void dispose() {
    _onResponse.close();
  }

  Future<void> showRunningNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      onlyAlertOnce: true,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: false),
      macOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: false),
    );

    await _notificationsPlugin.show(id, title, body, platformChannelSpecifics, payload: payload);
  }

  Future<void> scheduleGoalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      goalChannelId,
      goalChannelName,
      channelDescription: goalChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      macOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
