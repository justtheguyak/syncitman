import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/theme_toggle.dart';
import '../../../shared/services/notification_service.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../updates/presentation/update_notifier.dart';
import 'profile_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider);
    final updateState = ref.watch(updateNotifierProvider);
    final user = SupabaseConfig.client.auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.tabProfile),
      ),
      body: profileAsync.when(
        data: (state) {
          final myName = state.currentProfile?.displayName ??
              user?.userMetadata?['display_name'] ??
              (user?.email?.split('@').first ?? 'You');
          final partner = state.partnerProfile;
          final isPartnerLinked = partner != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // Couple Avatar Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Couple Avatars Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAvatarCircle(myName, isMe: true),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                          ),
                          _buildAvatarCircle(
                            isPartnerLinked ? partner.displayName : 'Partner',
                            isMe: false,
                            isUnlinked: !isPartnerLinked,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        isPartnerLinked
                            ? '$myName & ${partner.displayName}'
                            : myName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isPartnerLinked
                            ? 'Syncing tasks & memories together 💕'
                            : 'Partner not linked yet',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Profile Details Section
                _buildCardContainer(
                  isDark: isDark,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_rounded,
                          color: AppColors.primary),
                      title: const Text('My Name'),
                      subtitle: Text(myName),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        onPressed: () =>
                            _showEditNameDialog(context, ref, myName),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.email_outlined,
                          color: AppColors.primary),
                      title: const Text('Account Email'),
                      subtitle: Text(user?.email ?? 'No email'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.favorite_outline_rounded,
                          color: AppColors.secondary),
                      title: const Text('Partner Status'),
                      subtitle: Text(isPartnerLinked
                          ? 'Linked to ${partner.displayName}'
                          : 'Tap to connect partner'),
                      trailing: isPartnerLinked
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.statusDone)
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: isPartnerLinked
                          ? null
                          : () => _showLinkPartnerDialog(
                              context, ref, state.potentialPartners),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_reset_rounded,
                          color: AppColors.primary),
                      title: const Text('Change Password'),
                      subtitle: const Text('Update your private account password'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showChangePasswordDialog(context, ref),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Appearance Section
                _buildCardContainer(
                  isDark: isDark,
                  children: const [
                    ThemeToggleTile(),
                  ],
                ),

                const SizedBox(height: 16),

                // App Updates & OTA Section
                _buildCardContainer(
                  isDark: isDark,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.system_update_rounded,
                          color: AppColors.primary),
                      title: const Text('App Updates (OTA)'),
                      subtitle: Text(
                        updateState.isChecking
                            ? 'Checking GitHub for updates...'
                            : (updateState.updateInfo?.isUpdateAvailable == true
                                ? 'New version v${updateState.updateInfo!.latestVersion} available!'
                                : 'CoupleSync is up to date • GitHub OTA'),
                      ),
                      trailing: updateState.isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      onTap: () async {
                        await ref
                            .read(updateNotifierProvider.notifier)
                            .checkForUpdates(silent: false);

                        final state = ref.read(updateNotifierProvider);
                        if (context.mounted) {
                          if (state.errorMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(state.errorMessage!),
                                backgroundColor: AppColors.priorityHigh,
                              ),
                            );
                          } else if (state.updateInfo == null ||
                              !state.updateInfo!.isUpdateAvailable) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'CoupleSync is on the latest version! 🚀'),
                                backgroundColor: AppColors.statusDone,
                              ),
                            );
                          }
                          // If update is available, the app builder automatically transitions to MandatoryUpdateScreen!
                        }
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    ListTile(
                      leading: const Icon(Icons.science_outlined,
                          color: Colors.amber),
                      title: const Text('Demo Mandatory Update Screen'),
                      subtitle: const Text(
                          'Preview the full-screen mandatory OTA update view'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        ref
                            .read(updateNotifierProvider.notifier)
                            .simulateUpdateAvailable();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Notifications Testing Section
                _buildCardContainer(
                  isDark: isDark,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_active_rounded,
                          color: AppColors.secondary),
                      title: const Text('Test Instant Notification'),
                      subtitle:
                          const Text('Trigger a test notification right now'),
                      trailing: const Icon(Icons.send_rounded, size: 20),
                      onTap: () async {
                        final ok =
                            await NotificationService.showImmediateNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Notification sent! Check your notification bar 🔔'
                                  : 'Could not send notification. Check permissions.'),
                              backgroundColor: ok
                                  ? AppColors.statusDone
                                  : AppColors.priorityHigh,
                            ),
                          );
                        }
                      },
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined,
                          color: AppColors.primary),
                      title: const Text('Test Scheduled (5s)'),
                      subtitle:
                          const Text('Locks phone or wait 5s to see popup'),
                      trailing: const Icon(Icons.schedule_rounded, size: 20),
                      onTap: () async {
                        final ok = await NotificationService
                            .scheduleTestNotification(delaySeconds: 5);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Scheduled in 5 seconds! You can lock or minimize.'
                                  : 'Could not schedule. Check alarm permissions.'),
                              backgroundColor: ok
                                  ? AppColors.statusDone
                                  : AppColors.priorityHigh,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'Sign Out',
                    icon: Icons.logout_rounded,
                    isOutlined: true,
                    backgroundColor: AppColors.priorityHigh,
                    textColor: AppColors.priorityHigh,
                    onPressed: () => _confirmSignOut(context, ref),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'CoupleSync v1.0.0 • Made with love',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildAvatarCircle(String name,
      {required bool isMe, bool isUnlinked = false}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: isUnlinked ? Colors.white24 : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: isUnlinked ? Colors.white70 : AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildCardContainer({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(children: children),
    );
  }

  void _showEditNameDialog(
      BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Display Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            labelText: 'Display Name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await ref
                    .read(profileNotifierProvider.notifier)
                    .updateName(newName);
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLinkPartnerDialog(
      BuildContext context, WidgetRef ref, List potentialPartners) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect Your Partner 💕',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your partner from existing accounts or link their UUID:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (potentialPartners.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No other user profiles registered yet in Supabase. Once your partner logs in, they will appear here.',
                    style: TextStyle(fontSize: 14),
                  ),
                )
              else
                ...potentialPartners.map((p) => ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.secondary,
                        child: Icon(Icons.favorite, color: Colors.white),
                      ),
                      title: Text(p.displayName),
                      trailing: FilledButton(
                        onPressed: () async {
                          await ref
                              .read(profileNotifierProvider.notifier)
                              .linkPartner(p.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Link'),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Change Password'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  hintText: 'At least 6 characters',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () {
                      setDialogState(() => obscure = !obscure);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: obscure,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter new password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final pass = passwordController.text.trim();
                final confirm = confirmController.text.trim();

                if (pass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: AppColors.priorityHigh,
                    ),
                  );
                  return;
                }

                if (pass != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Passwords do not match'),
                      backgroundColor: AppColors.priorityHigh,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final success = await ref
                    .read(authNotifierProvider.notifier)
                    .updatePassword(pass);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Password changed successfully! 🔒'
                          : 'Failed to update password'),
                      backgroundColor: success
                          ? AppColors.statusDone
                          : AppColors.priorityHigh,
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out of CoupleSync?'),
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
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }
}
