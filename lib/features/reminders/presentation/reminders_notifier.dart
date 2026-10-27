import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/push_notification_service.dart';
import '../../profile/presentation/profile_notifier.dart';
import '../data/reminder_model.dart';
import '../data/reminder_repository.dart';

const String _prefsNotifiedRemindersKey = 'notified_shared_reminders_v2';

class RemindersNotifier extends AsyncNotifier<List<ReminderModel>> {
  StreamSubscription<List<ReminderModel>>? _streamSubscription;
  final Set<String> _knownReminderIds = {};
  Set<String> _notifiedSharedReminderIds = {};
  VoidCallback? _alertListenerCallback;

  @override
  Future<List<ReminderModel>> build() async {
    final repo = ref.watch(reminderRepositoryProvider);

    // 1. Load persisted list of notified reminders from SharedPreferences
    await _loadPersistedNotifiedIds();

    // 2. Setup Realtime Postgres Changes subscription
    _streamSubscription?.cancel();
    _streamSubscription = repo.watchReminders().listen(
      (reminders) {
        _handleIncomingReminders(reminders);
      },
      onError: (err, stack) {
        _fallbackFetch();
      },
    );

    // 3. Register global alert listener
    _alertListenerCallback = () => _fallbackFetch();
    PushNotificationService.addAlertListener(_alertListenerCallback!);

    ref.onDispose(() {
      _streamSubscription?.cancel();
      if (_alertListenerCallback != null) {
        PushNotificationService.removeAlertListener(_alertListenerCallback!);
      }
    });

    try {
      final list = await repo.fetchReminders();
      _handleIncomingReminders(list, isInitialFetch: true);
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadPersistedNotifiedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsNotifiedRemindersKey) ?? [];
      _notifiedSharedReminderIds = saved.toSet();
    } catch (e) {
      debugPrint('Error loading notified reminder IDs: $e');
    }
  }

  Future<void> _markReminderAsNotified(String reminderId) async {
    _notifiedSharedReminderIds.add(reminderId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final listToSave = _notifiedSharedReminderIds.toList();
      if (listToSave.length > 200) {
        listToSave.removeRange(0, listToSave.length - 200);
      }
      await prefs.setStringList(_prefsNotifiedRemindersKey, listToSave);
    } catch (e) {
      debugPrint('Error saving notified reminder ID: $e');
    }
  }

  void _handleIncomingReminders(List<ReminderModel> reminders, {bool isInitialFetch = false}) {
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;

    for (final reminder in reminders) {
      _knownReminderIds.add(reminder.id);

      // Check if this is a shared reminder created by partner that hasn't been notified yet
      if (currentUserId != null &&
          reminder.ownerId != currentUserId &&
          reminder.isShared &&
          !reminder.isCompleted) {
        if (!_notifiedSharedReminderIds.contains(reminder.id)) {
          _markReminderAsNotified(reminder.id);
          _notifyPartnerOfSharedReminder(reminder);
        }
      }
    }

    state = AsyncData(reminders);
    _scheduleUpcomingNotifications(reminders);
  }

  Future<void> _notifyPartnerOfSharedReminder(ReminderModel reminder) async {
    try {
      final profileState = ref.read(profileNotifierProvider).value;
      final partnerName =
          profileState?.partnerProfile?.displayName ?? 'Your partner';
      final timeFormatted =
          DateFormat('EEE, MMM d • h:mm a').format(reminder.remindAt);

      await NotificationService.showNotification(
        id: (reminder.notificationId ^ 0x4321).abs() & 0x7FFFFFFF,
        title: '💕 New Shared Reminder from $partnerName',
        body:
            '${reminder.title} ($timeFormatted)${reminder.note != null && reminder.note!.isNotEmpty ? '\n"${reminder.note}"' : ''}',
        channelId: NotificationService.channelSharedReminders,
      );
    } catch (e) {
      debugPrint('Error notifying partner of shared reminder: $e');
    }
  }

  void _scheduleUpcomingNotifications(List<ReminderModel> reminders) {
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    for (final reminder in reminders) {
      // Schedule only if user is owner or if it's shared and not completed and in future
      if (!reminder.isCompleted &&
          reminder.remindAt.isAfter(DateTime.now()) &&
          (reminder.ownerId == currentUserId || reminder.isShared)) {
        NotificationService.scheduleReminder(
          id: reminder.notificationId,
          title: reminder.title,
          body: reminder.note,
          scheduledAt: reminder.remindAt,
        );
      }
    }
  }

  Future<void> _fallbackFetch() async {
    try {
      final list = await ref.read(reminderRepositoryProvider).fetchReminders();
      state = AsyncData(list);
      _scheduleUpcomingNotifications(list);
    } catch (_) {}
  }

  Future<void> createReminder({
    required String title,
    String? note,
    required DateTime remindAt,
    bool isShared = true,
  }) async {
    final currentUser = SupabaseConfig.client.auth.currentUser;
    if (currentUser == null) return;

    final newReminder = ReminderModel(
      id: const Uuid().v4(),
      title: title.trim(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      ownerId: currentUser.id,
      isShared: isShared,
      remindAt: remindAt,
      isCompleted: false,
      createdAt: DateTime.now(),
    );

    _knownReminderIds.add(newReminder.id);
    if (newReminder.isShared) {
      await _markReminderAsNotified(newReminder.id);
    }

    // 1. Insert into database
    await ref.read(reminderRepositoryProvider).createReminder(newReminder);

    // 2. Schedule local notification for myself
    await NotificationService.scheduleReminder(
      id: newReminder.notificationId,
      title: newReminder.title,
      body: newReminder.note,
      scheduledAt: newReminder.remindAt,
    );

    // 3. Dispatch push notification & Realtime broadcast to partner if shared
    if (newReminder.isShared) {
      try {
        final profileState = ref.read(profileNotifierProvider).value;
        final partner = profileState?.partnerProfile;
        final myName = profileState?.currentProfile?.displayName ?? 'Your partner';
        final timeFormatted =
            DateFormat('EEE, MMM d • h:mm a').format(newReminder.remindAt);

        if (partner != null) {
          await PushNotificationService.sendPartnerPush(
            partnerId: partner.id,
            title: '💕 New Reminder from $myName',
            body:
                '${newReminder.title} ($timeFormatted)${newReminder.note != null && newReminder.note!.isNotEmpty ? '\n"${newReminder.note}"' : ''}',
            data: {
              'reminder_id': newReminder.id,
              'remind_at': newReminder.remindAt.toIso8601String(),
              'title': newReminder.title,
              'note': newReminder.note ?? '',
              'type': 'new_shared_reminder',
            },
          );
        }
      } catch (pushErr) {
        debugPrint('Error dispatching partner push on create: $pushErr');
      }
    }

    await _fallbackFetch();
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    await ref.read(reminderRepositoryProvider).updateReminder(reminder);

    if (reminder.isCompleted) {
      await NotificationService.cancelReminder(reminder.notificationId);
    } else if (reminder.remindAt.isAfter(DateTime.now())) {
      await NotificationService.scheduleReminder(
        id: reminder.notificationId,
        title: reminder.title,
        body: reminder.note,
        scheduledAt: reminder.remindAt,
      );
    }

    await _fallbackFetch();
  }

  Future<void> snoozeReminder(String reminderId, int minutes) async {
    final list = state.value ?? [];
    final existing = list.firstWhere((r) => r.id == reminderId);
    final newTime = DateTime.now().add(Duration(minutes: minutes));
    final updated = existing.copyWith(remindAt: newTime, isCompleted: false);
    await updateReminder(updated);
  }

  Future<void> toggleComplete(String reminderId, [bool? isCompleted]) async {
    final list = state.value ?? [];
    final existing = list.firstWhere((r) => r.id == reminderId);
    final targetDone = isCompleted ?? !existing.isCompleted;
    final updated = existing.copyWith(isCompleted: targetDone);
    await updateReminder(updated);
  }

  Future<void> deleteReminder(String reminderId) async {
    final list = state.value ?? [];
    final existing = list.where((r) => r.id == reminderId).firstOrNull;
    if (existing != null) {
      await NotificationService.cancelReminder(existing.notificationId);
    }
    await ref.read(reminderRepositoryProvider).deleteReminder(reminderId);
    await _fallbackFetch();
  }
}

final remindersProvider =
    AsyncNotifierProvider<RemindersNotifier, List<ReminderModel>>(
  RemindersNotifier.new,
);

// My personal reminders
final myRemindersProvider = Provider<List<ReminderModel>>((ref) {
  final async = ref.watch(remindersProvider);
  final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
  return async.maybeWhen(
    data: (list) => list
        .where((r) => r.ownerId == currentUserId && !r.isShared)
        .toList(),
    orElse: () => [],
  );
});

// Shared reminders (either owned by me or shared with me)
final sharedRemindersProvider = Provider<List<ReminderModel>>((ref) {
  final async = ref.watch(remindersProvider);
  return async.maybeWhen(
    data: (list) => list.where((r) => r.isShared).toList(),
    orElse: () => [],
  );
});

// Upcoming reminders
final upcomingRemindersProvider = Provider<List<ReminderModel>>((ref) {
  final async = ref.watch(remindersProvider);
  return async.maybeWhen(
    data: (list) {
      final now = DateTime.now();
      return list
          .where((r) => !r.isCompleted && r.remindAt.isAfter(now))
          .toList()
        ..sort((a, b) => a.remindAt.compareTo(b.remindAt));
    },
    orElse: () => [],
  );
});

// Past / completed reminders
final pastRemindersProvider = Provider<List<ReminderModel>>((ref) {
  final async = ref.watch(remindersProvider);
  return async.maybeWhen(
    data: (list) {
      final now = DateTime.now();
      return list
          .where((r) => r.isCompleted || r.remindAt.isBefore(now))
          .toList()
        ..sort((a, b) => b.remindAt.compareTo(a.remindAt));
    },
    orElse: () => [],
  );
});
