import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/reminder_card.dart';
import 'create_reminder_screen.dart';
import 'reminders_notifier.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);
    final myReminders = ref.watch(myRemindersProvider);
    final sharedReminders = ref.watch(sharedRemindersProvider);
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id ?? '';

    // Sort: uncompleted first, then completed at bottom
    final sortedMy = [...myReminders]..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return a.remindAt.compareTo(b.remindAt);
      });

    final sortedShared = [...sharedReminders]..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return a.remindAt.compareTo(b.remindAt);
      });

    final totalCount = sortedMy.length + sortedShared.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.tabReminders),
      ),
      body: remindersAsync.when(
        data: (_) {
          if (totalCount == 0) {
            return EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No Reminders Yet',
              message:
                  'Set private reminders for yourself or shared reminders for you and your partner to remember together!',
              actionText: 'Create Reminder',
              onAction: () => _openCreateReminder(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(remindersProvider);
            },
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              children: [
                // Shared Reminders Section
                if (sortedShared.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    title: 'Shared with Partner ❤️',
                    count: sortedShared.length,
                    color: AppColors.secondary,
                  ),
                  ...sortedShared.map((reminder) {
                    final isOwner = reminder.ownerId == currentUserId;
                    return ReminderCard(
                      reminder: reminder,
                      isOwner: isOwner,
                      onToggleComplete: (done) {
                        ref
                            .read(remindersProvider.notifier)
                            .toggleComplete(reminder.id, done);
                      },
                      onDelete: isOwner
                          ? () {
                              ref
                                  .read(remindersProvider.notifier)
                                  .deleteReminder(reminder.id);
                            }
                          : null,
                    );
                  }),
                  const SizedBox(height: 16),
                ],

                // My Reminders Section
                if (sortedMy.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    title: 'My Reminders 🔔',
                    count: sortedMy.length,
                    color: AppColors.primary,
                  ),
                  ...sortedMy.map((reminder) {
                    final isOwner = reminder.ownerId == currentUserId;
                    return ReminderCard(
                      reminder: reminder,
                      isOwner: isOwner,
                      onToggleComplete: (done) {
                        ref
                            .read(remindersProvider.notifier)
                            .toggleComplete(reminder.id, done);
                      },
                      onDelete: isOwner
                          ? () {
                              ref
                                  .read(remindersProvider.notifier)
                                  .deleteReminder(reminder.id);
                            }
                          : null,
                    );
                  }),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 48, color: AppColors.priorityHigh),
                const SizedBox(height: 16),
                Text(
                  'Unable to load reminders: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(remindersProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreateReminder(context),
        child: const Icon(Icons.add_alert_rounded, size: 28),
      ),
    );
  }

  void _openCreateReminder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateReminderScreen()),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
