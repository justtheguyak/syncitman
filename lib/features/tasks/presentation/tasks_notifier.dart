import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/task_model.dart';
import '../data/task_repository.dart';
import '../../../core/supabase/supabase_client.dart';

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
      },
      onError: (err, stack) {
        _fallbackFetch();
      },
    );

    ref.onDispose(() {
      _streamSubscription?.cancel();
    });

    try {
      return await repo.fetchTasks();
    } catch (_) {
      return [];
    }
  }

  Future<void> _fallbackFetch() async {
    try {
      final tasks = await ref.read(taskRepositoryProvider).fetchTasks();
      state = AsyncData(tasks);
    } catch (_) {}
  }

  Future<void> createTask({
    required String title,
    String? description,
    required String assignedTo,
    String priority = 'medium',
    DateTime? dueDate,
  }) async {
    final currentUser = SupabaseConfig.client.auth.currentUser;
    if (currentUser == null) return;

    final newTask = TaskModel(
      id: const Uuid().v4(),
      title: title.trim(),
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      createdBy: currentUser.id,
      assignedTo: assignedTo,
      priority: priority,
      dueDate: dueDate,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await ref.read(taskRepositoryProvider).createTask(newTask);
    await _fallbackFetch();
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    await ref.read(taskRepositoryProvider).updateTaskStatus(taskId, status);
    await _fallbackFetch();
  }

  Future<void> deleteTask(String taskId) async {
    await ref.read(taskRepositoryProvider).deleteTask(taskId);
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
