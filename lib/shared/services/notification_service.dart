import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      await requestPermissions();
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  static Future<void> requestPermissions() async {
    try {
      if (kIsWeb) return;
      if (Platform.isAndroid) {
        final androidImplementation = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
        await androidImplementation?.requestExactAlarmsPermission();
      } else if (Platform.isIOS) {
        final iosImplementation = _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else if (Platform.isMacOS) {
        final macosImplementation = _plugin
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>();
        await macosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime(
      int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String? body,
    required DateTime scheduledAt,
  }) async {
    try {
      if (!_initialized) await init();
      if (scheduledAt.isBefore(DateTime.now())) return;

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body ?? 'CoupleSync Reminder',
        scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'couplesync_reminders',
            'CoupleSync Reminders',
            channelDescription: 'Notifications for couple tasks and reminders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('Scheduled notification $id at $scheduledAt');
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  static Future<void> scheduleWeeklyReminder({
    required int id,
    required String title,
    required String? body,
    required int weekday, // 1 = Monday ... 7 = Sunday
    required int hour,
    required int minute,
  }) async {
    try {
      if (!_initialized) await init();
      final scheduledDate = _nextInstanceOfDayAndTime(weekday, hour, minute);

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body ?? 'Weekly Task Reminder',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'couplesync_weekly',
            'Weekly Reminders',
            channelDescription: 'Weekly repeating notifications for tasks',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      debugPrint(
          'Scheduled weekly notification $id on weekday $weekday at $hour:$minute');
    } catch (e) {
      debugPrint('Failed to schedule weekly notification: $e');
    }
  }

  static Future<void> cancelReminder(int id) async {
    try {
      await _plugin.cancel(id: id);
      debugPrint('Cancelled notification $id');
    } catch (e) {
      debugPrint('Failed to cancel notification: $e');
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
  }
}
