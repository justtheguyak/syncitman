import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import 'reminder_model.dart';

class ReminderRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<ReminderModel>> fetchReminders() async {
    final response = await _client
        .from('reminders')
        .select()
        .order('remind_at', ascending: true);

    return (response as List)
        .map((e) => ReminderModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Stream<List<ReminderModel>> watchReminders() {
    return _client
        .from('reminders')
        .stream(primaryKey: ['id'])
        .order('remind_at', ascending: true)
        .map((list) => list.map((item) => ReminderModel.fromJson(item)).toList());
  }

  Future<void> createReminder(ReminderModel reminder) async {
    await _client.from('reminders').insert(reminder.toJson());
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    await _client
        .from('reminders')
        .update(reminder.toJson())
        .eq('id', reminder.id);
  }

  Future<void> markComplete(String reminderId, bool isCompleted) async {
    await _client
        .from('reminders')
        .update({'is_completed': isCompleted})
        .eq('id', reminderId);
  }

  Future<void> deleteReminder(String reminderId) async {
    await _client.from('reminders').delete().eq('id', reminderId);
  }
}

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository();
});
