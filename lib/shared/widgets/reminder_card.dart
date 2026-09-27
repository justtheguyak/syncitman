import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../features/reminders/data/reminder_model.dart';

class ReminderCard extends StatelessWidget {
  final ReminderModel reminder;
  final bool isOwner;
  final ValueChanged<bool>? onToggleComplete;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.isOwner,
    this.onToggleComplete,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDone = reminder.isCompleted;

    Widget content = Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: reminder.isPast
              ? AppColors.priorityHigh.withOpacity(0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Checkbox
            GestureDetector(
              onTap: () {
                if (onToggleComplete != null) {
                  onToggleComplete!(!isDone);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2, right: 12),
                decoration: BoxDecoration(
                  color: isDone ? AppColors.statusDone : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
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

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone
                          ? (isDark ? AppColors.darkTextSecondary : Colors.grey)
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary),
                    ),
                  ),
                  if (reminder.note != null && reminder.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      reminder.note!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        size: 14,
                        color: reminder.isPast
                            ? AppColors.priorityHigh
                            : (isDark ? Colors.grey : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('EEE, MMM d • h:mm a').format(reminder.remindAt),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              reminder.isPast ? FontWeight.bold : FontWeight.w500,
                          color: reminder.isPast
                              ? AppColors.priorityHigh
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                        ),
                      ),
                      if (reminder.isShared) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite_rounded,
                                  size: 11, color: AppColors.secondary),
                              SizedBox(width: 3),
                              Text(
                                'Shared',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            if (isOwner && onDelete != null)
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
                onPressed: onDelete,
              )
            else if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ),
          ],
        ),
      ),
    ),
  );

    if (isOwner && onDelete != null) {
      return Dismissible(
        key: Key('reminder_${reminder.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.priorityHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.white, size: 24),
        ),
        onDismissed: (_) => onDelete!(),
        child: content,
      );
    }

    return content;
  }
}
