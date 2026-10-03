import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/services/notification_service.dart';
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

class TasksNotifier extends AsyncNotifier<List<TaskModel>> {
  StreamSubscription<List<TaskModel>>? _streamSubscription;

  @override
  Future<List<TaskModel>> build() async {
    final repo = ref.watch(taskRepositoryProvider);

    _streamSubscription?.cancel();
    _streamSubscription = repo.watchTasks().listen(
      (tasks) {
        state = AsyncData(tasks);
        _syncWeeklyNotifications(tasks);
      },
      onError: (err, stack) {
        _fallbackFetch();
      },
    );

    ref.onDispose(() {
      _streamSubscription?.cancel();
    });

    try {
      final tasks = await repo.fetchTasks();
      _syncWeeklyNotifications(tasks);
      return tasks;
    } catch (_) {
      return [];
    }
  }

  int _taskNotifId(String id) => (id.hashCode ^ 0x7777).abs() & 0x7FFFFFFF;

  void _syncWeeklyNotifications(List<TaskModel> tasks) {
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    for (final task in tasks) {
      final notifId = _taskNotifId(task.id);
      if (task.isDone) {
        NotificationService.cancelReminder(notifId);
      } else if (task.isWeeklyReminder &&
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
    }
  }

  Future<void> _fallbackFetch() async {
    try {
      final tasks = await ref.read(taskRepositoryProvider).fetchTasks();
      state = AsyncData(tasks);
      _syncWeeklyNotifications(tasks);
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

    await ref.read(taskRepositoryProvider).createTask(newTask);

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

    await _fallbackFetch();
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    await ref.read(taskRepositoryProvider).updateTaskStatus(taskId, status);
    if (status == 'done') {
      await NotificationService.cancelReminder(_taskNotifId(taskId));
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
