import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Channel IDs
  static const String channelReminders = 'couplesync_reminders';
  static const String channelSharedReminders = 'couplesync_shared_reminders';
  static const String channelWeekly = 'couplesync_weekly';
  static const String channelTest = 'couplesync_test_channel';

  /// Default notification icon (custom monochrome vector drawable)
  static const String notificationIcon = '@drawable/ic_notification';

  /// Ensures IDs fit within positive 31-bit integer for Android Java compatibility
  static int safeId(int id) {
    final val = id.abs() & 0x7FFFFFFF;
    return val == 0 ? 1 : val;
  }

  /// Initialize notifications and create channels
  static Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Timezone Database Setup
      tz_data.initializeTimeZones();
      _calibrateLocalTimezone();

      // 2. Platform initialization settings
      const androidSettings = AndroidInitializationSettings(notificationIcon);
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

      // 3. Register Android Notification Channels (API 26+)
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        if (androidImpl != null) {
          await _createNotificationChannels(androidImpl);
        }
      }

      _initialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Sets up device timezone accurately
  static void _calibrateLocalTimezone() {
    try {
      final offset = DateTime.now().timeZoneOffset;
      final name = DateTime.now().timeZoneName;

      tz.Location? matched;
      if (tz.timeZoneDatabase.locations.containsKey(name)) {
        matched = tz.getLocation(name);
      } else {
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (loc.currentTimeZone.offset == offset) {
            matched = loc;
            break;
          }
        }
      }

      if (matched != null) {
        tz.setLocalLocation(matched);
        debugPrint('Configured tz.local: ${matched.name}');
      }
    } catch (e) {
      debugPrint('Timezone calibration note: $e');
    }
  }

  /// Explicitly creates Android Notification Channels so OS never drops notifications
  static Future<void> _createNotificationChannels(
      AndroidFlutterLocalNotificationsPlugin androidImpl) async {
    const channels = [
      AndroidNotificationChannel(
        channelReminders,
        'CoupleSync Reminders',
        description: 'Notifications for couple tasks and reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
      AndroidNotificationChannel(
        channelSharedReminders,
        'Shared Reminders & Partner Alerts',
        description:
            'Notifications when your partner sets or updates shared reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
      AndroidNotificationChannel(
        channelWeekly,
        'Weekly Reminders',
        description: 'Weekly repeating notifications for tasks',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
      AndroidNotificationChannel(
        channelTest,
        'CoupleSync Test Alerts',
        description: 'Direct alerts and test notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    ];

    for (final channel in channels) {
      try {
        await androidImpl.createNotificationChannel(channel);
      } catch (e) {
        debugPrint('Failed to create channel ${channel.id}: $e');
      }
    }
  }

  /// Request runtime notification permissions (POST_NOTIFICATIONS on Android 13+)
  static Future<bool> requestPermissions() async {
    try {
      if (kIsWeb) return true;
      if (Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final notifGranted =
            await androidImpl?.requestNotificationsPermission();
        return notifGranted ?? true;
      } else if (Platform.isIOS) {
        final iosImpl = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      } else if (Platform.isMacOS) {
        final macosImpl = _plugin.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();
        final granted = await macosImpl?.requestPermissions(
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

  /// Check if notification permissions are currently enabled
  static Future<bool> arePermissionsGranted() async {
    try {
      if (kIsWeb) return true;
      if (Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await androidImpl?.areNotificationsEnabled() ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Check whether exact alarms can be scheduled on Android 12+
  static Future<bool> canScheduleExactAlarms() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await androidImpl?.canScheduleExactNotifications() ?? true;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Requests exact alarm permissions if needed (takes user to system settings)
  static Future<void> requestExactAlarmsPermission() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestExactAlarmsPermission();
      }
    } catch (e) {
      debugPrint('Error requesting exact alarm permission: $e');
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

  /// Schedules a future reminder with exact / inexact fallback
  static Future<bool> scheduleReminder({
    required int id,
    required String title,
    required String? body,
    required DateTime scheduledAt,
  }) async {
    try {
      if (!_initialized) await init();
      if (scheduledAt.isBefore(DateTime.now())) return false;

      final sId = safeId(id);
      final scheduledDate = tz.TZDateTime.from(scheduledAt, tz.local);

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelReminders,
          'CoupleSync Reminders',
          channelDescription: 'Notifications for couple tasks and reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: notificationIcon,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      // Attempt exact alarm first, fallback to inexact if disallowed
      try {
        await _plugin.zonedSchedule(
          id: sId,
          title: title,
          body: body ?? 'CoupleSync Reminder',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint(
            'Exact alarm schedule not allowed, falling back to inexact: $e');
        await _plugin.zonedSchedule(
          id: sId,
          title: title,
          body: body ?? 'CoupleSync Reminder',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }

      debugPrint('Scheduled notification $sId at $scheduledAt');
      return true;
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
      return false;
    }
  }

  /// Schedules a weekly repeating reminder with fallback
  static Future<bool> scheduleWeeklyReminder({
    required int id,
    required String title,
    required String? body,
    required int weekday, // 1 = Monday ... 7 = Sunday
    required int hour,
    required int minute,
  }) async {
    try {
      if (!_initialized) await init();
      final sId = safeId(id);
      final scheduledDate = _nextInstanceOfDayAndTime(weekday, hour, minute);

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelWeekly,
          'Weekly Reminders',
          channelDescription: 'Weekly repeating notifications for tasks',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: notificationIcon,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      try {
        await _plugin.zonedSchedule(
          id: sId,
          title: title,
          body: body ?? 'Weekly Task Reminder',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        debugPrint(
            'Weekly exact alarm not allowed, falling back to inexact: $e');
        await _plugin.zonedSchedule(
          id: sId,
          title: title,
          body: body ?? 'Weekly Task Reminder',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }

      debugPrint(
          'Scheduled weekly notification $sId on weekday $weekday at $hour:$minute');
      return true;
    } catch (e) {
      debugPrint('Failed to schedule weekly notification: $e');
      return false;
    }
  }

  /// Displays an immediate notification (e.g. partner alerts, shared tasks)
  static Future<bool> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = channelSharedReminders,
    String channelName = 'Shared Reminders & Partner Alerts',
  }) async {
    try {
      if (!_initialized) await init();

      final sId = safeId(id);
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription:
            'Notifications when your partner sets or updates shared items',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: notificationIcon,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _plugin.show(
        id: sId,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
        ),
      );
      debugPrint('Immediate notification $sId shown successfully');
      return true;
    } catch (e) {
      debugPrint('Failed to show notification: $e');
      return false;
    }
  }

  /// Sends an immediate test notification right now
  static Future<bool> showImmediateNotification({
    String title = 'CoupleSync ❤️',
    String body =
        'Test notification working! Stay connected and accomplish together.',
  }) async {
    return showNotification(
      id: 999999,
      title: title,
      body: body,
      channelId: channelTest,
      channelName: 'CoupleSync Test Alerts',
    );
  }

  /// Schedules a test notification in [delaySeconds] (defaults to 5 seconds)
  static Future<bool> scheduleTestNotification({int delaySeconds = 5}) async {
    try {
      if (!_initialized) await init();

      final scheduledDate =
          tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds));
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelTest,
          'CoupleSync Test Alerts',
          channelDescription: 'Direct alerts and test notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: notificationIcon,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      try {
        await _plugin.zonedSchedule(
          id: 888888,
          title: 'CoupleSync Test 🔔',
          body:
              'Scheduled test notification arrived after $delaySeconds seconds! ❤️',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Test exact alarm fallback to inexact: $e');
        await _plugin.zonedSchedule(
          id: 888888,
          title: 'CoupleSync Test 🔔',
          body:
              'Scheduled test notification arrived after $delaySeconds seconds! ❤️',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }

      debugPrint('Scheduled test notification in $delaySeconds seconds');
      return true;
    } catch (e) {
      debugPrint('Failed to schedule test notification: $e');
      return false;
    }
  }

  static Future<void> cancelReminder(int id) async {
    try {
      await _plugin.cancel(id: safeId(id));
      debugPrint('Cancelled notification $id');
    } catch (e) {
      debugPrint('Failed to cancel notification: $e');
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      debugPrint('Cancelled all notifications');
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
  }
}
