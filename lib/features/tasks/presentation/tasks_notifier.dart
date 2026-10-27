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
import '../data/task_model.dart';
import '../data/task_repository.dart';

enum TaskFilter { all, assignedToMe, createdByMe }

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.all;

  void setFilter(TaskFilter filter) {
    state = filter;
  }
}

final taskFilterProvider =
    NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);

const String _prefsNotifiedTasksKey = 'notified_assigned_tasks_v2';

class TasksNotifier extends AsyncNotifier<List<TaskModel>> {
  StreamSubscription<List<TaskModel>>? _streamSubscription;
  final Set<String> _knownTaskIds = {};
  Set<String> _notifiedTaskIds = {};
  VoidCallback? _alertListenerCallback;

  @override
  Future<List<TaskModel>> build() async {
    final repo = ref.watch(taskRepositoryProvider);

    // 1. Load persisted notified task IDs
    await _loadPersistedNotifiedIds();

    // 2. Setup Realtime Postgres Changes subscription
    _streamSubscription?.cancel();
    _streamSubscription = repo.watchTasks().listen(
      (tasks) {
        _handleIncomingTasks(tasks);
      },
      onError: (err, stack) {
        _fallbackFetch();
      },
    );

    // 3. Register listener for partner alert events to trigger immediate refresh
    _alertListenerCallback = () => _fallbackFetch();
    PushNotificationService.addAlertListener(_alertListenerCallback!);

    ref.onDispose(() {
      _streamSubscription?.cancel();
      if (_alertListenerCallback != null) {
        PushNotificationService.removeAlertListener(_alertListenerCallback!);
      }
    });

    try {
      final tasks = await repo.fetchTasks();
      _handleIncomingTasks(tasks, isInitialFetch: true);
      return tasks;
    } catch (_) {
      return [];
    }
  }

  int _taskNotifId(String id) => (id.hashCode ^ 0x7777).abs() & 0x7FFFFFFF;
  int _taskDueDateNotifId(String id) => (id.hashCode ^ 0x8888).abs() & 0x7FFFFFFF;

  Future<void> _loadPersistedNotifiedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsNotifiedTasksKey) ?? [];
      _notifiedTaskIds = saved.toSet();
    } catch (e) {
      debugPrint('Error loading notified task IDs: $e');
    }
  }

  Future<void> _markTaskAsNotified(String taskId) async {
    _notifiedTaskIds.add(taskId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final listToSave = _notifiedTaskIds.toList();
      if (listToSave.length > 200) {
        listToSave.removeRange(0, listToSave.length - 200);
      }
      await prefs.setStringList(_prefsNotifiedTasksKey, listToSave);
    } catch (e) {
      debugPrint('Error saving notified task ID: $e');
    }
  }

  void _handleIncomingTasks(List<TaskModel> tasks, {bool isInitialFetch = false}) {
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;

    for (final task in tasks) {
      _knownTaskIds.add(task.id);

      // Check if this task is assigned to me by my partner and not yet notified
      if (currentUserId != null &&
          task.assignedTo == currentUserId &&
          task.createdBy != currentUserId &&
          task.status != 'done') {
        if (!_notifiedTaskIds.contains(task.id)) {
          _markTaskAsNotified(task.id);
          _notifyPartnerOfAssignedTask(task);
        }
      }
    }

    state = AsyncData(tasks);
    _syncTaskNotifications(tasks);
  }

  Future<void> _notifyPartnerOfAssignedTask(TaskModel task) async {
    try {
      final profileState = ref.read(profileNotifierProvider).value;
      final partnerName = profileState?.partnerProfile?.displayName ?? 'Your partner';

      String subtitle = task.title;
      if (task.dueDate != null) {
        final dueFormatted = DateFormat('EEE, MMM d • h:mm a').format(task.dueDate!);
        subtitle += ' (Due: $dueFormatted)';
      }
      if (task.description != null && task.description!.isNotEmpty) {
        subtitle += '\n"${task.description}"';
      }

      await NotificationService.showNotification(
        id: _taskNotifId(task.id),
        title: '📋 New Task from $partnerName',
        body: subtitle,
        channelId: NotificationService.channelSharedReminders,
        channelName: 'Shared Reminders & Partner Alerts',
      );
    } catch (e) {
      debugPrint('Error notifying of assigned task: $e');
    }
  }

  void _syncTaskNotifications(List<TaskModel> tasks) {
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    for (final task in tasks) {
      final notifId = _taskNotifId(task.id);
      final dueNotifId = _taskDueDateNotifId(task.id);

      if (task.isDone) {
        NotificationService.cancelReminder(notifId);
        NotificationService.cancelReminder(dueNotifId);
      } else {
        // 1. Sync Weekly Repeating Task Reminder
        if (task.isWeeklyReminder &&
            task.weeklyReminderDay != null &&
            (task.assignedTo == currentUserId || task.createdBy == currentUserId)) {
          int hour = 10;
          int minute = 0;
          if (task.weeklyReminderTime != null &&
              task.weeklyReminderTime!.contains(':')) {
            final parts = task.weeklyReminderTime!.split(':');
            hour = int.tryParse(parts[0]) ?? 10;
            minute = int.tryParse(parts[1]) ?? 0;
          }

          NotificationService.scheduleWeeklyReminder(
            id: notifId,
            title: 'Weekly Task: ${task.title}',
            body: task.description ?? 'Time for your weekly couple task!',
            weekday: task.weeklyReminderDay!,
            hour: hour,
            minute: minute,
          );
        }

        // 2. Sync Due Date Alarm if task has a future due date
        if (task.dueDate != null &&
            task.dueDate!.isAfter(DateTime.now()) &&
            (task.assignedTo == currentUserId || task.createdBy == currentUserId)) {
          NotificationService.scheduleReminder(
            id: dueNotifId,
            title: 'Task Due: ${task.title}',
            body: task.description ?? 'Your task is due now! 💕',
            scheduledAt: task.dueDate!,
          );
        }
      }
    }
  }

  Future<void> _fallbackFetch() async {
    try {
      final tasks = await ref.read(taskRepositoryProvider).fetchTasks();
      _handleIncomingTasks(tasks);
    } catch (_) {}
  }

  Future<void> createTask({
    required String title,
    String? description,
    required String assignedTo,
    String priority = 'medium',
    DateTime? dueDate,
    bool isWeeklyReminder = false,
    int? weeklyReminderDay,
    String? weeklyReminderTime,
  }) async {
    final currentUser = SupabaseConfig.client.auth.currentUser;
    if (currentUser == null) return;

    final newTask = TaskModel(
      id: const Uuid().v4(),
      title: title.trim(),
      description:
          description?.trim().isEmpty == true ? null : description?.trim(),
      createdBy: currentUser.id,
      assignedTo: assignedTo,
      priority: priority,
      dueDate: dueDate,
      isWeeklyReminder: isWeeklyReminder,
      weeklyReminderDay: weeklyReminderDay,
      weeklyReminderTime: weeklyReminderTime,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    // Prevent creator from getting alert for their own newly created task
    _knownTaskIds.add(newTask.id);
    await _markTaskAsNotified(newTask.id);

    await ref.read(taskRepositoryProvider).createTask(newTask);

    // Schedule weekly reminder if applicable
    if (isWeeklyReminder && weeklyReminderDay != null) {
      int hour = 10;
      int minute = 0;
      if (weeklyReminderTime != null && weeklyReminderTime.contains(':')) {
        final parts = weeklyReminderTime.split(':');
        hour = int.tryParse(parts[0]) ?? 10;
        minute = int.tryParse(parts[1]) ?? 0;
      }
      await NotificationService.scheduleWeeklyReminder(
        id: _taskNotifId(newTask.id),
        title: 'Weekly Task: ${newTask.title}',
        body: newTask.description ?? 'Time for your weekly couple task!',
        weekday: weeklyReminderDay,
        hour: hour,
        minute: minute,
      );
    }

    // Schedule due date reminder if applicable
    if (dueDate != null && dueDate.isAfter(DateTime.now())) {
      await NotificationService.scheduleReminder(
        id: _taskDueDateNotifId(newTask.id),
        title: 'Task Due: ${newTask.title}',
        body: newTask.description ?? 'Your task is due now! 💕',
        scheduledAt: dueDate,
      );
    }

    // Send push notification to partner if task is assigned to partner
    if (newTask.assignedTo != currentUser.id) {
      try {
        final profileState = ref.read(profileNotifierProvider).value;
        final myName = profileState?.currentProfile?.displayName ?? 'Your partner';
        String notifBody = newTask.title;
        if (dueDate != null) {
          final dueFormatted = DateFormat('EEE, MMM d • h:mm a').format(dueDate);
          notifBody += ' (Due: $dueFormatted)';
        }
        if (newTask.description != null && newTask.description!.isNotEmpty) {
          notifBody += '\n"${newTask.description}"';
        }

        await PushNotificationService.sendPartnerPush(
          partnerId: newTask.assignedTo,
          title: '📋 New Task from $myName',
          body: notifBody,
          data: {
            'task_id': newTask.id,
            'type': 'new_assigned_task',
          },
        );
      } catch (pushErr) {
        debugPrint('Error sending partner task push: $pushErr');
      }
    }

    await _fallbackFetch();
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    await ref.read(taskRepositoryProvider).updateTaskStatus(taskId, status);
    if (status == 'done') {
      await NotificationService.cancelReminder(_taskNotifId(taskId));
      await NotificationService.cancelReminder(_taskDueDateNotifId(taskId));
    }
    await _fallbackFetch();
  }

  Future<void> updateWeeklyReminder({
    required String taskId,
    required bool isWeekly,
    int? day,
    String? time,
  }) async {
    final tasks = state.value ?? [];
    final existing = tasks.firstWhere((t) => t.id == taskId);
    final updated = existing.copyWith(
      isWeeklyReminder: isWeekly,
      weeklyReminderDay: day,
      weeklyReminderTime: time,
    );

    await ref.read(taskRepositoryProvider).updateTask(updated);

    final notifId = _taskNotifId(taskId);
    if (!isWeekly || day == null) {
      await NotificationService.cancelReminder(notifId);
    } else {
      int hour = 10;
      int minute = 0;
      if (time != null && time.contains(':')) {
        final parts = time.split(':');
        hour = int.tryParse(parts[0]) ?? 10;
        minute = int.tryParse(parts[1]) ?? 0;
      }
      await NotificationService.scheduleWeeklyReminder(
        id: notifId,
        title: 'Weekly Task: ${updated.title}',
        body: updated.description ?? 'Time for your weekly couple task!',
        weekday: day,
        hour: hour,
        minute: minute,
      );
    }

    await _fallbackFetch();
  }

  Future<void> deleteTask(String taskId) async {
    await ref.read(taskRepositoryProvider).deleteTask(taskId);
    await NotificationService.cancelReminder(_taskNotifId(taskId));
    await NotificationService.cancelReminder(_taskDueDateNotifId(taskId));
    await _fallbackFetch();
  }
}

final tasksProvider =
    AsyncNotifierProvider<TasksNotifier, List<TaskModel>>(TasksNotifier.new);

// Filtered tasks provider
final filteredTasksProvider = Provider<List<TaskModel>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final filter = ref.watch(taskFilterProvider);
  final currentUserId = SupabaseConfig.client.auth.currentUser?.id;

  return tasksAsync.maybeWhen(
    data: (tasks) {
      if (currentUserId == null) return tasks;
      switch (filter) {
        case TaskFilter.assignedToMe:
          return tasks.where((t) => t.assignedTo == currentUserId).toList();
        case TaskFilter.createdByMe:
          return tasks.where((t) => t.createdBy == currentUserId).toList();
        case TaskFilter.all:
          return tasks;
      }
    },
    orElse: () => [],
  );
});

// Pending count for current user
final pendingTasksCountProvider = Provider<int>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
  if (currentUserId == null) return 0;

  return tasksAsync.maybeWhen(
    data: (tasks) => tasks
        .where((t) => t.assignedTo == currentUserId && t.status != 'done')
        .length,
    orElse: () => 0,
  );
});
