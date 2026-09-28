import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/theme_toggle.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../updates/presentation/update_notifier.dart';
import 'avatar_crop_screen.dart';
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
          final anniversaryDate = DateTime(2024, 3, 7, 14, 53);
          final daysTogether =
              DateTime.now().difference(anniversaryDate).inDays;

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
                        color: AppColors.primary.withValues(alpha: 0.3),
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
                          _buildAvatarCircle(
                            context: context,
                            ref: ref,
                            name: myName,
                            avatarUrl: state.currentProfile?.avatarUrl,
                            userId: user?.id,
                            isMe: true,
                          ),
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
                            context: context,
                            ref: ref,
                            name: isPartnerLinked
                                ? partner.displayName
                                : (state.potentialPartners.isNotEmpty
                                    ? state.potentialPartners.first.displayName
                                    : 'Partner'),
                            avatarUrl: isPartnerLinked
                                ? partner.avatarUrl
                                : (state.potentialPartners.isNotEmpty
                                    ? state.potentialPartners.first.avatarUrl
                                    : null),
                            userId: isPartnerLinked
                                ? partner.id
                                : (state.potentialPartners.isNotEmpty
                                    ? state.potentialPartners.first.id
                                    : null),
                            isMe: false,
                            isUnlinked: !isPartnerLinked &&
                                state.potentialPartners.isEmpty,
                            onUnlinkedTap: () => _showLinkPartnerDialog(
                                context, ref, state.potentialPartners),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded,
                                color: Colors.white, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Tap your photo to change 📸',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isPartnerLinked
                            ? '$myName & ${partner.displayName}'
                            : (state.potentialPartners.isNotEmpty
                                ? '$myName & ${state.potentialPartners.first.displayName}'
                                : myName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPartnerLinked
                            ? 'Syncing tasks & memories together 💕'
                            : 'Partner linked • Ready to sync 💕',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Our Anniversary Milestone Card
                _buildAnniversaryCard(context, isDark, daysTogether),

                const SizedBox(height: 20),

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
                  'CoupleSync v1.0.2 • Made with love',
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

  Widget _buildAnniversaryCard(
      BuildContext context, bool isDark, int daysTogether) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with heart and live day counter
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Our Anniversary 💍',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$daysTogether days of love and forever to go',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Day $daysTogether',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          // Details (Date, Afternoon Time, Location)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Date & Time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Special Moment',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '7 March 2024 • 2:53 PM (Afternoon)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Location
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Where It All Began',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'George restaurant',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle({
    required BuildContext context,
    required WidgetRef ref,
    required String name,
    required String? avatarUrl,
    required String? userId,
    required bool isMe,
    bool isUnlinked = false,
    VoidCallback? onUnlinkedTap,
  }) {
    return GestureDetector(
      onTap: () {
        if (isMe && userId != null) {
          _showAvatarPickerSheet(context, ref, name, userId, avatarUrl);
        } else if (isUnlinked && onUnlinkedTap != null) {
          onUnlinkedTap();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Only $name can change their own profile picture 💕'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isUnlinked ? Colors.white24 : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _buildAvatarContent(name, avatarUrl, isUnlinked: isUnlinked),
          ),
          if (isMe)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            )
          else if (isUnlinked)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(String name, String? avatarUrl,
      {required bool isUnlinked}) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('data:image')) {
        try {
          final commaIndex = avatarUrl.indexOf(',');
          final base64Data = commaIndex != -1
              ? avatarUrl.substring(commaIndex + 1)
              : avatarUrl;
          final bytes = base64Decode(base64Data);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) =>
                  _buildInitialText(name, isUnlinked),
            ),
          );
        } catch (_) {
          return _buildInitialText(name, isUnlinked);
        }
      } else if (avatarUrl.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            avatarUrl,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) =>
                _buildInitialText(name, isUnlinked),
          ),
        );
      } else if (avatarUrl.startsWith('emoji:')) {
        final emoji = avatarUrl.replaceFirst('emoji:', '');
        return Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 34),
          ),
        );
      }
    }
    return _buildInitialText(name, isUnlinked);
  }

  Widget _buildInitialText(String name, bool isUnlinked) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
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

  void _showAvatarPickerSheet(
    BuildContext context,
    WidgetRef ref,
    String name,
    String targetUserId,
    String? currentAvatarUrl,
  ) {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera_rounded,
                        color: AppColors.secondary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile Picture for $name',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Choose a photo or romantic couple avatar',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Cute Preset Avatars
              const Text(
                'Quick Romantic Avatars:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    '🤴',
                    '👸',
                    '💖',
                    '💍',
                    '🌸',
                    '🐱',
                    '🐶',
                    '🐻',
                    '🐼',
                    '✨',
                    '🌹',
                    '🍓',
                    '☕'
                  ].map((emoji) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await ref
                              .read(profileNotifierProvider.notifier)
                              .updateAvatar(targetUserId, 'emoji:$emoji');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Avatar updated for $name! $emoji'),
                                backgroundColor: AppColors.statusDone,
                              ),
                            );
                          }
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: currentAvatarUrl == 'emoji:$emoji'
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Pick from Gallery
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppColors.primary, size: 20),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select any photo from your phone'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1600,
                      maxHeight: 1600,
                      imageQuality: 90,
                    );
                    if (picked != null && context.mounted) {
                      final croppedBase64 = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => AvatarCropScreen(
                            imageFile: File(picked.path),
                            title: 'Adjust Profile Picture',
                          ),
                        ),
                      );
                      if (croppedBase64 != null && context.mounted) {
                        await ref
                            .read(profileNotifierProvider.notifier)
                            .updateAvatar(targetUserId, croppedBase64);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Profile picture set for $name! 📸'),
                              backgroundColor: AppColors.statusDone,
                            ),
                          );
                        }
                      }
                    }
                  } on PlatformException catch (e) {
                    if (context.mounted) {
                      final msg = (e.code == 'photo_access_denied')
                          ? 'Gallery permission denied. Please allow Photos/Media permission in phone settings.'
                          : 'Gallery access error: ${e.message ?? e.code}';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: AppColors.priorityHigh,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to pick photo: $e'),
                          backgroundColor: AppColors.priorityHigh,
                        ),
                      );
                    }
                  }
                },
              ),

              // Take Photo
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.secondary, size: 20),
                ),
                title: const Text('Take a Photo'),
                subtitle: const Text('Capture using phone camera'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picked = await picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 1600,
                      maxHeight: 1600,
                      imageQuality: 90,
                    );
                    if (picked != null && context.mounted) {
                      final croppedBase64 = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => AvatarCropScreen(
                            imageFile: File(picked.path),
                            title: 'Adjust Profile Picture',
                          ),
                        ),
                      );
                      if (croppedBase64 != null && context.mounted) {
                        await ref
                            .read(profileNotifierProvider.notifier)
                            .updateAvatar(targetUserId, croppedBase64);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Profile photo updated for $name! 📸'),
                              backgroundColor: AppColors.statusDone,
                            ),
                          );
                        }
                      }
                    }
                  } on PlatformException catch (e) {
                    if (context.mounted) {
                      final msg = (e.code == 'camera_access_denied')
                          ? 'Camera permission denied. Please allow Camera permission in phone settings.'
                          : 'Camera access error: ${e.message ?? e.code}';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: AppColors.priorityHigh,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Camera error: $e'),
                          backgroundColor: AppColors.priorityHigh,
                        ),
                      );
                    }
                  }
                },
              ),

              // Remove Photo (if set)
              if (currentAvatarUrl != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.priorityHigh.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.priorityHigh, size: 20),
                  ),
                  title: const Text(
                    'Remove Picture',
                    style: TextStyle(color: AppColors.priorityHigh),
                  ),
                  subtitle: const Text('Revert back to letter initial'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref
                        .read(profileNotifierProvider.notifier)
                        .updateAvatar(targetUserId, null);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Profile picture removed for $name'),
                          backgroundColor: AppColors.statusDone,
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
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
