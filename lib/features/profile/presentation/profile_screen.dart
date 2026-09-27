import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/theme_toggle.dart';
import '../../auth/presentation/auth_notifier.dart';
import 'profile_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider);
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
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
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
