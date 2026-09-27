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

  static Future<bool> requestPermissions() async {
    try {
      if (kIsWeb) return true;
      if (Platform.isAndroid) {
        final androidImplementation = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final notifGranted =
            await androidImplementation?.requestNotificationsPermission();
        await androidImplementation?.requestExactAlarmsPermission();
        return notifGranted ?? true;
      } else if (Platform.isIOS) {
        final iosImplementation = _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      } else if (Platform.isMacOS) {
        final macosImplementation = _plugin
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>();
        final granted = await macosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
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

  /// Sends an immediate test notification right now
  static Future<bool> showImmediateNotification({
    String title = 'CoupleSync ❤️',
    String body = 'Test notification working! Stay connected and accomplish together.',
  }) async {
    try {
      if (!_initialized) await init();
      await requestPermissions();

      const androidDetails = AndroidNotificationDetails(
        'couplesync_test_channel',
        'CoupleSync Test Alerts',
        channelDescription: 'Direct alerts and test notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _plugin.show(
        id: 999999,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Failed to show immediate notification: $e');
      return false;
    }
  }

  /// Schedules a test notification in [delaySeconds] (defaults to 5 seconds)
  static Future<bool> scheduleTestNotification({int delaySeconds = 5}) async {
    try {
      if (!_initialized) await init();
      await requestPermissions();

      final scheduledDate =
          tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds));

      await _plugin.zonedSchedule(
        id: 888888,
        title: 'CoupleSync Test 🔔',
        body:
            'Scheduled test notification arrived after $delaySeconds seconds! ❤️',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'couplesync_test_channel',
            'CoupleSync Test Alerts',
            channelDescription: 'Direct alerts and test notifications',
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
      return true;
    } catch (e) {
      debugPrint('Failed to schedule test notification: $e');
      return false;
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
