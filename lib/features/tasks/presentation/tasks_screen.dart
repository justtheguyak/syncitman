import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/task_card.dart';
import '../../profile/presentation/profile_notifier.dart';
import 'create_task_screen.dart';
import 'task_detail_screen.dart';
import 'tasks_notifier.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final filteredTasks = ref.watch(filteredTasksProvider);
    final currentFilter = ref.watch(taskFilterProvider);
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id ?? '';

    final profileState = ref.watch(profileNotifierProvider).value;
    final partnerName = profileState?.partnerProfile?.displayName ?? 'Partner';

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(
                  context,
                  ref,
                  label: AppStrings.allTasks,
                  filter: TaskFilter.all,
                  isSelected: currentFilter == TaskFilter.all,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  ref,
                  label: AppStrings.assignedToMe,
                  filter: TaskFilter.assignedToMe,
                  isSelected: currentFilter == TaskFilter.assignedToMe,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  ref,
                  label: AppStrings.createdByMe,
                  filter: TaskFilter.createdByMe,
                  isSelected: currentFilter == TaskFilter.createdByMe,
                ),
              ],
            ),
          ),

          // Tasks List
          Expanded(
            child: tasksAsync.when(
              data: (_) {
                if (filteredTasks.isEmpty) {
                  return EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No Tasks Found',
                    message: currentFilter == TaskFilter.assignedToMe
                        ? 'You have no tasks assigned to you right now! Relax or help your partner.'
                        : currentFilter == TaskFilter.createdByMe
                            ? 'You have not created any tasks yet.'
                            : 'No tasks on your couple list yet. Tap + to add something sweet or productive!',
                    actionText: 'Create Task',
                    onAction: () => _openCreateTask(context),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(tasksProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 88),
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];
                      final isCreatedByMe = task.createdBy == currentUserId;
                      final isAssignedToMe = task.assignedTo == currentUserId;
                      final assigneeName = isAssignedToMe ? 'You' : partnerName;

                      return TaskCard(
                        task: task,
                        isCreatedByMe: isCreatedByMe,
                        isAssignedToMe: isAssignedToMe,
                        assigneeName: assigneeName,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(task: task),
                            ),
                          );
                        },
                        onStatusChanged: (newStatus) {
                          ref
                              .read(tasksProvider.notifier)
                              .updateTaskStatus(task.id, newStatus);
                        },
                        onDelete: isCreatedByMe
                            ? () {
                                ref
                                    .read(tasksProvider.notifier)
                                    .deleteTask(task.id);
                              }
                            : null,
                      );
                    },
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
                        'Unable to load tasks: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(tasksProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreateTask(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _openCreateTask(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required TaskFilter filter,
    required bool isSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Theme.of(context).dividerColor,
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          ref.read(taskFilterProvider.notifier).setFilter(filter);
        }
      },
    );
  }
}
