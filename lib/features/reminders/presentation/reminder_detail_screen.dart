import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../profile/presentation/profile_notifier.dart';
import '../data/reminder_model.dart';
import 'reminders_notifier.dart';

class ReminderDetailScreen extends ConsumerStatefulWidget {
  final ReminderModel reminder;

  const ReminderDetailScreen({super.key, required this.reminder});

  @override
  ConsumerState<ReminderDetailScreen> createState() =>
      _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends ConsumerState<ReminderDetailScreen> {
  late ReminderModel _reminder;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _reminder = widget.reminder;
  }

  String _formatRelativeTime(DateTime remindAt, bool isCompleted) {
    if (isCompleted) return 'Completed ✓';
    final now = DateTime.now();
    final difference = remindAt.difference(now);

    if (difference.isNegative) {
      final past = difference.abs();
      if (past.inDays > 0) {
        return '${past.inDays} ${past.inDays == 1 ? "day" : "days"} ago (Overdue)';
      } else if (past.inHours > 0) {
        return '${past.inHours} ${past.inHours == 1 ? "hour" : "hours"} ago (Overdue)';
      } else {
        return '${past.inMinutes} ${past.inMinutes == 1 ? "min" : "mins"} ago (Overdue)';
      }
    } else {
      if (difference.inDays > 0) {
        return 'In ${difference.inDays} ${difference.inDays == 1 ? "day" : "days"}';
      } else if (difference.inHours > 0) {
        final hours = difference.inHours;
        final mins = difference.inMinutes % 60;
        return mins > 0 ? 'In $hours hrs $mins mins' : 'In $hours ${hours == 1 ? "hour" : "hours"}';
      } else {
        return 'In ${difference.inMinutes} ${difference.inMinutes == 1 ? "min" : "mins"}';
      }
    }
  }

  Future<void> _toggleComplete() async {
    final nextState = !_reminder.isCompleted;
    setState(() => _isUpdating = true);
    try {
      await ref
          .read(remindersProvider.notifier)
          .toggleComplete(_reminder.id, nextState);
      setState(() {
        _reminder = _reminder.copyWith(isCompleted: nextState);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nextState
                ? 'Reminder marked as completed! 🎉'
                : 'Reminder marked as active! 🔔'),
            backgroundColor: AppColors.statusDone,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.priorityHigh,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _snoozeOrReschedule(DateTime newDateTime) async {
    setState(() => _isUpdating = true);
    try {
      final updated = _reminder.copyWith(
        remindAt: newDateTime,
        isCompleted: false,
      );
      await ref.read(remindersProvider.notifier).updateReminder(updated);
      setState(() {
        _reminder = updated;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Rescheduled for ${DateFormat('EEE, MMM d • h:mm a').format(newDateTime)} ⏰'),
            backgroundColor: AppColors.statusDone,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reschedule: $e'),
            backgroundColor: AppColors.priorityHigh,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _toggleSharing() async {
    final nextShared = !_reminder.isShared;
    setState(() => _isUpdating = true);
    try {
      final updated = _reminder.copyWith(isShared: nextShared);
      await ref.read(remindersProvider.notifier).updateReminder(updated);
      setState(() {
        _reminder = updated;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nextShared
                ? 'Reminder shared with partner! 💕'
                : 'Reminder made private to you 🔒'),
            backgroundColor:
                nextShared ? AppColors.secondary : AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update sharing: $e'),
            backgroundColor: AppColors.priorityHigh,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _showEditDialog() async {
    final titleController = TextEditingController(text: _reminder.title);
    final noteController = TextEditingController(text: _reminder.note ?? '');
    DateTime editRemindAt = _reminder.remindAt;
    bool editIsShared = _reminder.isShared;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Edit Reminder ✏️',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: titleController,
                  label: 'Title',
                  prefixIcon: Icons.alarm_rounded,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: noteController,
                  label: 'Note (Optional)',
                  prefixIcon: Icons.note_alt_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: ctx,
                      initialDate: editRemindAt,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (pickedDate != null && ctx.mounted) {
                      final pickedTime = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(editRemindAt),
                      );
                      if (pickedTime != null && ctx.mounted) {
                        setModalState(() {
                          editRemindAt = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            DateFormat('EEE, MMM d, yyyy • h:mm a')
                                .format(editRemindAt),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.edit_calendar_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.favorite_rounded,
                      color: AppColors.secondary),
                  title: const Text('Share with Partner',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'Partner is notified and synced in realtime',
                      style: TextStyle(fontSize: 12)),
                  value: editIsShared,
                  activeThumbColor: AppColors.secondary,
                  onChanged: (val) => setModalState(() => editIsShared = val),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'Save Changes',
                    icon: Icons.check_rounded,
                    onPressed: () async {
                      final newTitle = titleController.text.trim();
                      if (newTitle.isEmpty) return;

                      Navigator.pop(ctx);
                      final updated = _reminder.copyWith(
                        title: newTitle,
                        note: noteController.text.trim().isEmpty
                            ? null
                            : noteController.text.trim(),
                        remindAt: editRemindAt,
                        isShared: editIsShared,
                      );
                      await ref
                          .read(remindersProvider.notifier)
                          .updateReminder(updated);
                      if (mounted) {
                        setState(() {
                          _reminder = updated;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reminder updated successfully! 🔔'),
                            backgroundColor: AppColors.statusDone,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reminder?'),
        content: Text('Are you sure you want to delete "${_reminder.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.priorityHigh),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(remindersProvider.notifier).deleteReminder(_reminder.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _testNotification() async {
    final success = await NotificationService.showNotification(
      id: 777777,
      title: '🔔 ${_reminder.title}',
      body: _reminder.note ?? 'CoupleSync Reminder Alert 💕',
      channelId: NotificationService.channelTest,
      channelName: 'CoupleSync Test Alerts',
    );
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent to your phone! 🔔'),
            backgroundColor: AppColors.statusDone,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not show notification. Please check system notification permissions! ⚠️'),
            backgroundColor: AppColors.priorityHigh,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    final isOwner = _reminder.ownerId == currentUserId;

    final profileState = ref.watch(profileNotifierProvider).value;
    final partnerName = profileState?.partnerProfile?.displayName ?? 'Partner';
    final creatorName = isOwner ? 'You' : partnerName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Test Alert',
            onPressed: _testNotification,
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.priorityHigh),
              tooltip: 'Delete Reminder',
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
                    color: _reminder.isPast
                        ? AppColors.priorityHigh.withValues(alpha: 0.4)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Badges Row
                    Row(
                      children: [
                        // Status Badge
                        _buildStatusBadge(),
                        const Spacer(),
                        // Shared with partner badge
                        _buildSharedBadge(partnerName),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Reminder Title
                    Text(
                      _reminder.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        decoration: _reminder.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: _reminder.isCompleted
                            ? (isDark
                                ? AppColors.darkTextSecondary
                                : Colors.grey)
                            : null,
                      ),
                    ),

                    // Note Section
                    if (_reminder.note != null &&
                        _reminder.note!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.sticky_note_2_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _reminder.note!,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Remind At Time & Countdown Card
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.alarm_rounded,
                              color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scheduled Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('EEEE, MMM d, yyyy • h:mm a')
                                    .format(_reminder.remindAt),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _reminder.isCompleted
                            ? AppColors.statusDone.withValues(alpha: 0.12)
                            : (_reminder.isPast
                                ? AppColors.priorityHigh.withValues(alpha: 0.12)
                                : AppColors.primary.withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _reminder.isCompleted
                                ? Icons.check_circle_rounded
                                : (_reminder.isPast
                                    ? Icons.warning_rounded
                                    : Icons.timer_rounded),
                            size: 14,
                            color: _reminder.isCompleted
                                ? AppColors.statusDone
                                : (_reminder.isPast
                                    ? AppColors.priorityHigh
                                    : AppColors.primary),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatRelativeTime(
                                _reminder.remindAt, _reminder.isCompleted),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _reminder.isCompleted
                                  ? AppColors.statusDone
                                  : (_reminder.isPast
                                      ? AppColors.priorityHigh
                                      : AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),

                    // Quick Reschedule / Snooze Options
                    const Text(
                      'Quick Reschedule / Snooze:',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickTimeChip(
                          label: '+15 Mins',
                          onTap: () => _snoozeOrReschedule(
                            DateTime.now().add(const Duration(minutes: 15)),
                          ),
                        ),
                        _buildQuickTimeChip(
                          label: '+1 Hour',
                          onTap: () => _snoozeOrReschedule(
                            DateTime.now().add(const Duration(hours: 1)),
                          ),
                        ),
                        _buildQuickTimeChip(
                          label: 'Tomorrow 9 AM',
                          onTap: () {
                            final now = DateTime.now();
                            final tomorrow = now.add(const Duration(days: 1));
                            _snoozeOrReschedule(
                              DateTime(tomorrow.year, tomorrow.month,
                                  tomorrow.day, 9, 0),
                            );
                          },
                        ),
                        _buildQuickTimeChip(
                          label: 'Pick Time 📅',
                          onTap: () async {
                            final now = DateTime.now();
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _reminder.remindAt,
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 365)),
                            );
                            if (date != null && context.mounted) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime:
                                    TimeOfDay.fromDateTime(_reminder.remindAt),
                              );
                              if (time != null && context.mounted) {
                                _snoozeOrReschedule(
                                  DateTime(date.year, date.month, date.day,
                                      time.hour, time.minute),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Partner Sharing Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _reminder.isShared
                        ? AppColors.secondary.withValues(alpha: 0.5)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _reminder.isShared
                            ? AppColors.secondary.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _reminder.isShared
                            ? Icons.favorite_rounded
                            : Icons.lock_outline_rounded,
                        color: _reminder.isShared
                            ? AppColors.secondary
                            : Colors.grey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _reminder.isShared
                                ? 'Shared with $partnerName 💕'
                                : 'Personal Reminder 🔒',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _reminder.isShared
                                ? 'Both phones will alert at the scheduled time. When set or changed, $partnerName is notified.'
                                : 'Only you can see and receive alerts for this reminder. $partnerName is not notified.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          if (isOwner) ...[
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: _toggleSharing,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  _reminder.isShared
                                      ? 'Switch to Private Reminder'
                                      : 'Share with $partnerName ❤️',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _reminder.isShared
                                        ? Colors.grey
                                        : AppColors.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Metadata Card
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
                      icon: Icons.person_rounded,
                      iconColor: AppColors.primary,
                      label: 'Created By',
                      value: creatorName,
                    ),
                    const Divider(height: 24),
                    _buildMetaRow(
                      icon: Icons.access_time_rounded,
                      iconColor: Colors.grey,
                      label: 'Created On',
                      value: DateFormat('MMM d, yyyy • h:mm a')
                          .format(_reminder.createdAt),
                    ),
                    const Divider(height: 24),
                    _buildMetaRow(
                      icon: Icons.notifications_active_rounded,
                      iconColor: AppColors.secondary,
                      label: 'Alert Status',
                      value: _reminder.isCompleted
                          ? 'Completed'
                          : (_reminder.isPast ? 'Overdue' : 'Active Alarm'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: _reminder.isCompleted
                      ? 'Mark as Active'
                      : 'Mark as Completed',
                  icon: _reminder.isCompleted
                      ? Icons.restart_alt_rounded
                      : Icons.check_circle_rounded,
                  isLoading: _isUpdating,
                  backgroundColor: _reminder.isCompleted
                      ? AppColors.primary
                      : AppColors.statusDone,
                  onPressed: _toggleComplete,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'Edit Details',
                      icon: Icons.edit_rounded,
                      isOutlined: true,
                      onPressed: _showEditDialog,
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        isOutlined: true,
                        backgroundColor: AppColors.priorityHigh,
                        textColor: AppColors.priorityHigh,
                        onPressed: _confirmDelete,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (_reminder.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.statusDone.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 14, color: AppColors.statusDone),
            SizedBox(width: 4),
            Text(
              'Completed',
              style: TextStyle(
                color: AppColors.statusDone,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    } else if (_reminder.isPast) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.priorityHigh.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 14, color: AppColors.priorityHigh),
            SizedBox(width: 4),
            Text(
              'Overdue',
              style: TextStyle(
                color: AppColors.priorityHigh,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm_rounded, size: 14, color: AppColors.primary),
            SizedBox(width: 4),
            Text(
              'Upcoming',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSharedBadge(String partnerName) {
    if (_reminder.isShared) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, size: 13, color: AppColors.secondary),
            SizedBox(width: 4),
            Text(
              'Shared 💕',
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 13, color: Colors.grey),
            SizedBox(width: 4),
            Text(
              'Private',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildQuickTimeChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Text(label),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
