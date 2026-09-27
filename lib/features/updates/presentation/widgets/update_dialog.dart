import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/update_model.dart';
import '../../data/update_service.dart';
import '../update_notifier.dart';

class UpdateDialog extends ConsumerWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
  });

  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(updateInfo: info),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDownloading = updateState.isDownloading;

    return PopScope(
      canPop: !isDownloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon & Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update Available! 🎉',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v${updateInfo.latestVersion}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Current: v${updateInfo.currentVersion}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Release Notes Box
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBackground
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        updateInfo.releaseName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        updateInfo.releaseNotes,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Progress Bar if Downloading
              if (isDownloading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          updateState.otaStatus == OtaStatus.INSTALLING
                              ? 'Opening installer...'
                              : 'Downloading update...',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${updateState.downloadProgress}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: updateState.downloadProgress > 0
                            ? updateState.downloadProgress / 100
                            : null,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please keep this screen open. The Android installer will pop up automatically when download completes.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ] else ...[
                if (updateState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.priorityHigh.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      updateState.errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.priorityHigh,
                      ),
                    ),
                  ),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          ref
                              .read(updateNotifierProvider.notifier)
                              .dismissBanner();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 20),
                        label: const Text(
                          'Update Now',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () {
                          ref
                              .read(updateNotifierProvider.notifier)
                              .startUpdate(context);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                    label: const Text(
                      'Download directly from GitHub',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      UpdateService.openReleaseInBrowser(updateInfo.htmlUrl);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
