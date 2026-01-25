import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../infrastructure/database/sqlite_service.dart';
import '../../data/repositories/sql_activity_repository.dart';
import '../../domain/entities/activity.dart';
import '../../infrastructure/notifications/notification_service.dart';

class BackgroundServiceInstance {
  static Future<void> initialize() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: NotificationService.channelId,
        initialNotificationTitle: 'Active',
        initialNotificationContent: 'Tracking activities...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart, onBackground: onIosBackground),
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    final sqliteService = SqliteService.instance;
    final repository = SqlActivityRepository(sqliteService);
    final notificationService = NotificationService();
    await notificationService.init();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Timer loop
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        if (service is AndroidServiceInstance) {
          if (!(await service.isForegroundService())) {
            return;
          }
        }

        final activities = await repository.getAllActivities();
        final running = activities.where((a) => a.status == ActivityStatus.running).toList();

        if (running.isEmpty) {
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(title: "Active", content: "No active project");
          }
          return;
        }

        // Update notification for the first running activity (or aggregate)
        final primary = running.first;
        if (primary.startedAt == null) return;

        final now = DateTime.now();
        final delta = now.difference(primary.startedAt!).inSeconds;
        final totalSeconds = primary.totalSeconds + delta;

        final hours = totalSeconds ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;

        final timeStr =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(title: "Tracking: ${primary.name}", content: "Elapsed: $timeStr");
        }

        // Send update back to UI if needed
        service.invoke('update', {"id": primary.id, "seconds": totalSeconds});

        // Periodic persistence in background
        if (timer.tick % 10 == 0) {
          for (final a in running) {
            if (a.startedAt == null) continue;
            final d = now.difference(a.startedAt!).inSeconds;
            await repository.saveActivity(a.copyWith(totalSeconds: a.totalSeconds + d, startedAt: () => now));
          }
        }
      } catch (e) {
        debugPrint('Error in background timer: $e');
      }
    });
  }
}
