import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import 'task_model.dart';

class TaskRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<TaskModel>> fetchTasks() async {
    final response = await _client
        .from('tasks')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Stream<List<TaskModel>> watchTasks() {
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) => list.map((item) => TaskModel.fromJson(item)).toList());
  }

  Future<void> createTask(TaskModel task) async {
    final json = task.toJson();
    await _client.from('tasks').insert(json);
  }

  Future<void> updateTask(TaskModel task) async {
    final json = task.toJson();
    json['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client.from('tasks').update(json).eq('id', task.id);
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    await _client.from('tasks').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', taskId);
  }

  Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});
