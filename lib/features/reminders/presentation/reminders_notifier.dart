import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/services/notification_service.dart';
import '../../profile/presentation/profile_notifier.dart';
import '../data/reminder_model.dart';
import '../data/reminder_repository.dart';

class RemindersNotifier extends AsyncNotifier<List<ReminderModel>> {
  StreamSubscription<List<ReminderModel>>? _streamSubscription;
  final Set<String> _knownReminderIds = {};
  final Set<String> _notifiedSharedReminderIds = {};
  bool _isInitialized = false;

  @override
  Future<List<ReminderModel>> build() async {
    final repo = ref.watch(reminderRepositoryProvider);

    _streamSubscription?.cancel();
    _streamSubscription = repo.watchReminders().listen(
      (reminders) {
        _handleIncomingReminders(reminders);
      },
      onError: (err, stack) {
        _fallbackFetch();
      },
    );

    ref.onDispose(() {
      _streamSubscription?.cancel();
    });

    try {
      final list = await repo.fetchReminders();
      for (final r in list) {
        _knownReminderIds.add(r.id);
        if (r.isShared) {
          _notifiedSharedReminderIds.add(r.id);
        }
      }
      _isInitialized = true;
      _scheduleUpcomingNotifications(list);
      return list;
    } catch (_) {
      return [];
    }
  }

  void _handleIncomingReminders(List<ReminderModel> reminders) {
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;

    if (_isInitialized && currentUserId != null) {
      for (final reminder in reminders) {
        final isNew = !_knownReminderIds.contains(reminder.id);
        _knownReminderIds.add(reminder.id);

        // Notify only if:
        // 1. Created by the partner (not me)
        // 2. Shared with partner is TRUE
        // 3. Not completed
        // 4. Either newly created or newly set as shared
        if (reminder.ownerId != currentUserId &&
            reminder.isShared &&
            !reminder.isCompleted) {
          if (isNew || !_notifiedSharedReminderIds.contains(reminder.id)) {
            _notifiedSharedReminderIds.add(reminder.id);
            _notifyPartnerOfSharedReminder(reminder);
          }
        }
      }
    } else {
      for (final r in reminders) {
        _knownReminderIds.add(r.id);
        if (r.isShared) {
          _notifiedSharedReminderIds.add(r.id);
        }
      }
      _isInitialized = true;
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
        id: reminder.notificationId ^ 0x4321,
        title: '💕 New Shared Reminder from $partnerName',
        body:
            '${reminder.title} ($timeFormatted)${reminder.note != null && reminder.note!.isNotEmpty ? '\n"${reminder.note}"' : ''}',
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
    bool isShared = false,
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
      _notifiedSharedReminderIds.add(newReminder.id);
    }

    await ref.read(reminderRepositoryProvider).createReminder(newReminder);

    // Schedule notification for myself
    await NotificationService.scheduleReminder(
      id: newReminder.notificationId,
      title: newReminder.title,
      body: newReminder.note,
      scheduledAt: newReminder.remindAt,
    );

    await _fallbackFetch();
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    await ref.read(reminderRepositoryProvider).updateReminder(reminder);

    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    if (!reminder.isCompleted &&
        reminder.remindAt.isAfter(DateTime.now()) &&
        (reminder.ownerId == currentUserId || reminder.isShared)) {
      await NotificationService.scheduleReminder(
        id: reminder.notificationId,
        title: reminder.title,
        body: reminder.note,
        scheduledAt: reminder.remindAt,
      );
    } else {
      await NotificationService.cancelReminder(reminder.notificationId);
    }

    await _fallbackFetch();
  }

  Future<void> toggleComplete(String reminderId, bool isCompleted) async {
    await ref
        .read(reminderRepositoryProvider)
        .markComplete(reminderId, isCompleted);

    if (isCompleted) {
      await NotificationService.cancelReminder(reminderId.hashCode);
    }
    await _fallbackFetch();
  }

  Future<void> deleteReminder(String reminderId) async {
    await ref.read(reminderRepositoryProvider).deleteReminder(reminderId);
    await NotificationService.cancelReminder(reminderId.hashCode);
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
