import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../profile/presentation/profile_notifier.dart';
import 'tasks_notifier.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String _priority = 'medium';
  bool _assignToMe = true;
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _dueDate != null
            ? TimeOfDay.fromDateTime(_dueDate!)
            : const TimeOfDay(hour: 12, minute: 0),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final profileState = ref.read(profileNotifierProvider).value;
    final partnerId = profileState?.partnerProfile?.id ??
        (profileState?.potentialPartners.isNotEmpty == true
            ? profileState!.potentialPartners.first.id
            : null);

    final assignedTo = _assignToMe ? currentUserId : (partnerId ?? currentUserId);

    setState(() => _isSaving = true);
    try {
      await ref.read(tasksProvider.notifier).createTask(
            title: _titleController.text,
            description: _descController.text,
            assignedTo: assignedTo,
            priority: _priority,
            dueDate: _dueDate,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully! ❤️'),
            backgroundColor: AppColors.statusDone,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: $e'),
            backgroundColor: AppColors.priorityHigh,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileNotifierProvider).value;
    final partnerName = profileState?.partnerProfile?.displayName ??
        (profileState?.potentialPartners.isNotEmpty == true
            ? profileState!.potentialPartners.first.displayName
            : 'Partner');

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.createTask),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: _titleController,
                  label: AppStrings.taskTitle,
                  hint: 'e.g. Pick up groceries, Book dinner reservation',
                  prefixIcon: Icons.task_alt_rounded,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Please enter a task title' : null,
                ),
                const SizedBox(height: 18),

                AppTextField(
                  controller: _descController,
                  label: AppStrings.taskDescription,
                  hint: 'Any notes, details, or sweet reminders...',
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 22),

                // Assignee Toggle
                const Text(
                  AppStrings.assignTo,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceChip(
                        label: 'Myself',
                        icon: Icons.person_rounded,
                        isSelected: _assignToMe,
                        onTap: () => setState(() => _assignToMe = true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildChoiceChip(
                        label: partnerName,
                        icon: Icons.favorite_rounded,
                        isSelected: !_assignToMe,
                        onTap: () => setState(() => _assignToMe = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Priority Selection
                const Text(
                  AppStrings.priority,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildPriorityChip(
                        label: 'Low',
                        val: 'low',
                        color: AppColors.priorityLow,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPriorityChip(
                        label: 'Medium',
                        val: 'medium',
                        color: AppColors.priorityMedium,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPriorityChip(
                        label: 'High',
                        val: 'high',
                        color: AppColors.priorityHigh,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Due Date & Time Picker
                const Text(
                  AppStrings.dueDate,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _dueDate != null
                                ? DateFormat('EEE, MMM d, yyyy • h:mm a')
                                    .format(_dueDate!)
                                : AppStrings.selectDueDate,
                            style: TextStyle(
                              fontSize: 14,
                              color: _dueDate != null
                                  ? null
                                  : Theme.of(context).hintColor,
                            ),
                          ),
                        ),
                        if (_dueDate != null)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(() => _dueDate = null),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'Save Task',
                    icon: Icons.check_circle_rounded,
                    isLoading: _isSaving,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : Theme.of(context).hintColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip({
    required String label,
    required String val,
    required Color color,
  }) {
    final isSelected = _priority == val;
    return InkWell(
      onTap: () => setState(() => _priority = val),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? color : null,
            ),
          ),
        ),
      ),
    );
  }
}
