import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import 'reminders_notifier.dart';

class CreateReminderScreen extends ConsumerStatefulWidget {
  const CreateReminderScreen({super.key});

  @override
  ConsumerState<CreateReminderScreen> createState() =>
      _CreateReminderScreenState();
}

class _CreateReminderScreenState extends ConsumerState<CreateReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  late DateTime _remindAt;
  bool _isShared = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default to 1 hour from now, rounded to next 15 mins
    final now = DateTime.now();
    _remindAt = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _remindAt,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_remindAt),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _remindAt = DateTime(
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_remindAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time in the future'),
          backgroundColor: AppColors.priorityHigh,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(remindersProvider.notifier).createReminder(
            title: _titleController.text,
            note: _noteController.text,
            remindAt: _remindAt,
            isShared: _isShared,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder set! 🔔'),
            backgroundColor: AppColors.statusDone,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save reminder: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.createReminder),
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
                  label: AppStrings.reminderTitle,
                  hint: 'e.g. Call my love, Drink water, Anniversary gift',
                  prefixIcon: Icons.alarm_rounded,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Please enter a reminder title' : null,
                ),
                const SizedBox(height: 18),

                AppTextField(
                  controller: _noteController,
                  label: AppStrings.reminderNote,
                  hint: 'Any extra details or warm messages...',
                  prefixIcon: Icons.note_alt_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 22),

                // Remind At Picker
                const Text(
                  AppStrings.remindAt,
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
                        const Icon(Icons.notifications_active_rounded,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            DateFormat('EEE, MMM d, yyyy • h:mm a').format(_remindAt),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.edit_calendar_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Share with Partner Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.secondary,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    AppStrings.shareWithPartner,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text(
                    AppStrings.shareWithPartnerDesc,
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isShared,
                  activeThumbColor: AppColors.secondary,
                  onChanged: (val) => setState(() => _isShared = val),
                ),
                const SizedBox(height: 36),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'Set Reminder',
                    icon: Icons.alarm_on_rounded,
                    isLoading: _isSaving,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
