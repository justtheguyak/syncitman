import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../features/tasks/data/task_model.dart';
import 'priority_badge.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool isCreatedByMe;
  final bool isAssignedToMe;
  final String assigneeName;
  final VoidCallback? onTap;
  final ValueChanged<String>? onStatusChanged;
  final VoidCallback? onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.isCreatedByMe,
    required this.isAssignedToMe,
    required this.assigneeName,
    this.onTap,
    this.onStatusChanged,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDone = task.isDone;

    Widget cardContent = Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: task.isOverdue
              ? AppColors.priorityHigh.withOpacity(0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: task.isOverdue ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: () => _showStatusBottomSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status check button
                  GestureDetector(
                    onTap: () {
                      if (onStatusChanged != null) {
                        onStatusChanged!(isDone ? 'pending' : 'done');
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      margin: const EdgeInsets.only(top: 2, right: 12),
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppColors.statusDone
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone
                              ? AppColors.statusDone
                              : (isDark ? Colors.white38 : Colors.black26),
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),

                  // Title and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone
                                ? (isDark ? AppColors.darkTextSecondary : Colors.grey)
                                : (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary),
                          ),
                        ),
                        if (task.description != null &&
                            task.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Priority badge
                  PriorityBadge(priority: task.priority),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom details row
              Row(
                children: [
                  // Assignee pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAssignedToMe
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.partnerAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAssignedToMe
                              ? Icons.person_rounded
                              : Icons.favorite_rounded,
                          size: 13,
                          color: isAssignedToMe
                              ? AppColors.primary
                              : AppColors.partnerAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAssignedToMe ? 'For You' : 'For $assigneeName',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isAssignedToMe
                                ? AppColors.primary
                                : AppColors.partnerAccent,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Weekly reminder chip
                  if (task.isWeeklyReminder && task.weeklyReminderDay != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.repeat_rounded,
                              size: 12, color: AppColors.secondary),
                          const SizedBox(width: 3),
                          Text(
                            task.weeklyReminderFormatted ?? 'Weekly',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Due Date
                  if (task.dueDate != null) ...[
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: task.isOverdue
                          ? AppColors.priorityHigh
                          : (isDark ? Colors.grey : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(task.dueDate!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            task.isOverdue ? FontWeight.bold : FontWeight.w500,
                        color: task.isOverdue
                            ? AppColors.priorityHigh
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Swipe to delete only if created by current user
    if (isCreatedByMe && onDelete != null) {
      return Dismissible(
        key: Key('task_${task.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.priorityHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Task?'),
                  content: Text('Are you sure you want to delete "${task.title}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.priorityHigh,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ) ??
              false;
        },
        onDismissed: (_) => onDelete!(),
        child: cardContent,
      );
    }

    return cardContent;
  }

  void _showStatusBottomSheet(BuildContext context) {
    if (onStatusChanged == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Update Status: "${task.title}"',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.radio_button_unchecked, color: AppColors.statusPending),
                title: const Text('Pending'),
                trailing: task.isPending ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onStatusChanged!('pending');
                },
              ),
              ListTile(
                leading: const Icon(Icons.pending_actions_rounded, color: AppColors.statusInProgress),
                title: const Text('In Progress'),
                trailing: task.isInProgress ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onStatusChanged!('in_progress');
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_rounded, color: AppColors.statusDone),
                title: const Text('Done'),
                trailing: task.isDone ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onStatusChanged!('done');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
