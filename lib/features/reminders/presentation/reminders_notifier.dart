import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/services/notification_service.dart';
import '../data/reminder_model.dart';
import '../data/reminder_repository.dart';

class RemindersNotifier extends AsyncNotifier<List<ReminderModel>> {
  StreamSubscription<List<ReminderModel>>? _streamSubscription;

  @override
  Future<List<ReminderModel>> build() async {
    final repo = ref.watch(reminderRepositoryProvider);

    _streamSubscription?.cancel();
    _streamSubscription = repo.watchReminders().listen(
      (reminders) {
        state = AsyncData(reminders);
        _scheduleUpcomingNotifications(reminders);
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
      _scheduleUpcomingNotifications(list);
      return list;
    } catch (_) {
      return [];
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

    await ref.read(reminderRepositoryProvider).createReminder(newReminder);

    // Schedule notification
    await NotificationService.scheduleReminder(
      id: newReminder.notificationId,
      title: newReminder.title,
      body: newReminder.note,
      scheduledAt: newReminder.remindAt,
    );

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
