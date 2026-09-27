import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/widgets/priority_badge.dart';
import '../../profile/presentation/profile_notifier.dart';
import '../data/task_model.dart';
import 'tasks_notifier.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final TaskModel task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late TaskModel _task;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await ref.read(tasksProvider.notifier).updateTaskStatus(_task.id, newStatus);
      setState(() {
        _task = _task.copyWith(status: newStatus);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.replaceAll('_', ' ').toUpperCase()}'),
            backgroundColor: AppColors.statusDone,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.priorityHigh,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('Are you sure you want to delete "${_task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.priorityHigh),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(tasksProvider.notifier).deleteTask(_task.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    final isCreator = currentUserId == _task.createdBy;
    final isAssignedToMe = currentUserId == _task.assignedTo;

    final profileState = ref.watch(profileNotifierProvider).value;
    final partnerName = profileState?.partnerProfile?.displayName ?? 'Partner';

    final createdByName = isCreator ? 'You' : partnerName;
    final assignedToName = isAssignedToMe ? 'You' : partnerName;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          if (isCreator)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.priorityHigh),
              tooltip: 'Delete Task',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PriorityBadge(priority: _task.priority),
                        const Spacer(),
                        _buildStatusChip(_task.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _task.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        decoration: _task.isDone ? TextDecoration.lineThrough : null,
                        color: _task.isDone
                            ? (isDark ? AppColors.darkTextSecondary : Colors.grey)
                            : null,
                      ),
                    ),
                    if (_task.description != null && _task.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _task.description!,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Metadata card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  children: [
                    _buildMetaRow(
                      icon: Icons.assignment_ind_rounded,
                      iconColor: AppColors.primary,
                      label: 'Assigned To',
                      value: assignedToName,
                    ),
                    const Divider(height: 24),
                    _buildMetaRow(
                      icon: Icons.person_outline_rounded,
                      iconColor: AppColors.secondary,
                      label: 'Created By',
                      value: createdByName,
                    ),
                    if (_task.dueDate != null) ...[
                      const Divider(height: 24),
                      _buildMetaRow(
                        icon: Icons.event_rounded,
                        iconColor: _task.isOverdue
                            ? AppColors.priorityHigh
                            : AppColors.primary,
                        label: 'Due Date',
                        value: DateFormat('EEE, MMM d, yyyy • h:mm a')
                            .format(_task.dueDate!),
                        isHighlighted: _task.isOverdue,
                      ),
                    ],
                    if (_task.isWeeklyReminder && _task.weeklyReminderDay != null) ...[
                      const Divider(height: 24),
                      _buildMetaRow(
                        icon: Icons.repeat_rounded,
                        iconColor: AppColors.secondary,
                        label: 'Weekly Reminder',
                        value: _task.weeklyReminderFormatted ?? 'Every week',
                        isHighlighted: true,
                      ),
                    ],
                    const Divider(height: 24),
                    _buildMetaRow(
                      icon: Icons.access_time_rounded,
                      iconColor: Colors.grey,
                      label: 'Created',
                      value: DateFormat('MMM d, yyyy • h:mm a').format(_task.createdAt),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Weekly Reminder Configure Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _task.isWeeklyReminder
                        ? AppColors.secondary
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.repeat_rounded,
                          color: AppColors.secondary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Weekly Reminder',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            _task.isWeeklyReminder
                                ? (_task.weeklyReminderFormatted ?? 'Active')
                                : 'Not set',
                            style: TextStyle(
                              fontSize: 12,
                              color: _task.isWeeklyReminder
                                  ? AppColors.secondary
                                  : Colors.grey,
                              fontWeight: _task.isWeeklyReminder
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: Icon(
                        _task.isWeeklyReminder
                            ? Icons.edit_rounded
                            : Icons.add_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _task.isWeeklyReminder ? 'Change' : 'Set',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showWeeklyReminderDialog(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Status Change Section
              const Text(
                'Change Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatusButton(
                      label: 'Pending',
                      status: 'pending',
                      color: AppColors.statusPending,
                      icon: Icons.hourglass_empty_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusButton(
                      label: 'In Progress',
                      status: 'in_progress',
                      color: AppColors.statusInProgress,
                      icon: Icons.pending_actions_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusButton(
                      label: 'Done',
                      status: 'done',
                      color: AppColors.statusDone,
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'done':
        color = AppColors.statusDone;
        label = 'Completed';
        break;
      case 'in_progress':
        color = AppColors.statusInProgress;
        label = 'In Progress';
        break;
      case 'pending':
      default:
        color = AppColors.statusPending;
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isHighlighted ? AppColors.priorityHigh : null,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButton({
    required String label,
    required String status,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _task.status == status;
    return InkWell(
      onTap: _isUpdating ? null : () => _updateStatus(status),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? color : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeeklyReminderDialog(BuildContext context) {
    bool isWeekly = _task.isWeeklyReminder;
    int selectedDay = _task.weeklyReminderDay ?? DateTime.sunday;
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    if (_task.weeklyReminderTime != null &&
        _task.weeklyReminderTime!.contains(':')) {
      final p = _task.weeklyReminderTime!.split(':');
      selectedTime = TimeOfDay(
          hour: int.tryParse(p[0]) ?? 10, minute: int.tryParse(p[1]) ?? 0);
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.repeat_rounded,
                          color: AppColors.secondary),
                      const SizedBox(width: 8),
                      const Text(
                        'Weekly Repeating Reminder',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Switch(
                        value: isWeekly,
                        activeThumbColor: AppColors.secondary,
                        onChanged: (val) =>
                            setModalState(() => isWeekly = val),
                      ),
                    ],
                  ),
                  if (isWeekly) ...[
                    const SizedBox(height: 16),
                    const Text('Remind Every Week On:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildModalWeekdayChip(
                              'Mon',
                              DateTime.monday,
                              selectedDay,
                              (d) => setModalState(() => selectedDay = d)),
                          const SizedBox(width: 6),
                          _buildModalWeekdayChip(
                              'Tue',
                              DateTime.tuesday,
                              selectedDay,
                              (d) => setModalState(() => selectedDay = d)),
                          const SizedBox(width: 6),
                          _buildModalWeekdayChip(
                              'Wed',
                              DateTime.wednesday,
                              selectedDay,
                              (d) => setModalState(() => selectedDay = d)),
                          const SizedBox(width: 6),
                          _buildModalWeekdayChip(
                              'Thu',
                              DateTime.thursday,
                              selectedDay,
                              (d) => setModalState(() => selectedDay = d)),
                          const SizedBox(width: 6),
                          _buildModalWeekdayChip(
                              'Fri',
                              DateTime.friday,
                              selectedDay,
                              (d) => setModalState(() => selectedDay = d)),
                          const SizedBox(width: 6),
                          _buildModalWeekdayChip(
                              'Sat',
                              DateTime.saturday,
                              selectedDay,
                              (d) => setModalState(() => selectedDay = d)),
                          const SizedBox(width: 6),
                          _buildModalWeekdayChip(
                              'Sun',
                              DateTime.sunday,
                              selectedDay,
                              (d) => setModalState(() => selectedDay = d)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: Theme.of(context).dividerColor),
                      ),
                      leading: const Icon(Icons.access_time_rounded,
                          color: AppColors.secondary),
                      title: const Text('Reminder Time'),
                      trailing: Text(
                        selectedTime.format(context),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.secondary),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: context, initialTime: selectedTime);
                        if (picked != null) {
                          setModalState(() => selectedTime = picked);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        final timeStr = isWeekly
                            ? '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'
                            : null;
                        await ref
                            .read(tasksProvider.notifier)
                            .updateWeeklyReminder(
                              taskId: _task.id,
                              isWeekly: isWeekly,
                              day: isWeekly ? selectedDay : null,
                              time: timeStr,
                            );
                        if (!mounted) return;
                        setState(() {
                          _task = _task.copyWith(
                            isWeeklyReminder: isWeekly,
                            weeklyReminderDay: isWeekly ? selectedDay : null,
                            weeklyReminderTime: timeStr,
                          );
                        });
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(isWeekly
                                ? 'Weekly reminder saved for every ${_task.weeklyReminderDayName}! 🔔'
                                : 'Weekly reminder turned off'),
                            backgroundColor: AppColors.statusDone,
                          ),
                        );
                      },
                      child: const Text('Save Reminder Settings'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalWeekdayChip(
      String label, int day, int current, ValueChanged<int> onSelect) {
    final isSelected = current == day;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.secondary,
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color:
              isSelected ? AppColors.secondary : Theme.of(context).dividerColor,
        ),
      ),
      onSelected: (selected) {
        if (selected) onSelect(day);
      },
    );
  }
}
