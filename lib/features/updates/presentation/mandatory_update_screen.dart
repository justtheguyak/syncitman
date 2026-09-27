import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import '../../../core/constants/app_colors.dart';
import '../data/update_model.dart';
import 'update_notifier.dart';

class MandatoryUpdateScreen extends ConsumerWidget {
  final AppUpdateInfo updateInfo;

  const MandatoryUpdateScreen({
    super.key,
    required this.updateInfo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDownloading = updateState.isDownloading;
    final progress = updateState.downloadProgress;

    return PopScope(
      canPop: false, // Mandatory update: user cannot go back
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // Mandatory Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.priorityHigh.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.priorityHigh
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.priorityHigh,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'MANDATORY UPDATE REQUIRED',
                                style: TextStyle(
                                  color: AppColors.priorityHigh,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Animated Center Icon with Glow
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.system_update_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Title & Subtitle
                        const Text(
                          'Update CoupleSync',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Version comparison pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Installed: v${updateInfo.currentVersion}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward_rounded,
                                  size: 14, color: AppColors.primary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v${updateInfo.latestVersion}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'A new update is required to keep your couple tasks, reminders, and realtime sync running smoothly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // What's New Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
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
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    updateInfo.releaseName.isNotEmpty
                                        ? updateInfo.releaseName
                                        : "What's New in v${updateInfo.latestVersion}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Divider(
                                height: 1,
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                updateInfo.releaseNotes.isNotEmpty
                                    ? updateInfo.releaseNotes
                                    : 'Performance enhancements, security updates, and couple sync improvements.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Area (Always visible)
                Container(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      // Error Message if any
                      if (updateState.errorMessage != null && !isDownloading) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.priorityHigh.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.priorityHigh
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppColors.priorityHigh, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  updateState.errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.priorityHigh,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Downloading progress view
                      if (isDownloading) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    updateState.otaStatus ==
                                            OtaStatus.INSTALLING
                                        ? 'Opening Android Installer...'
                                        : 'Downloading update directly...',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '$progress%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress > 0 ? progress / 100 : null,
                                  minHeight: 10,
                                  backgroundColor: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                updateState.otaStatus == OtaStatus.INSTALLING
                                    ? 'Tap "Update" on the Android system prompt to complete.'
                                    : 'Please keep this screen open. The Android installer will pop up automatically.',
                                textAlign: TextAlign.center,
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
                      ] else ...[
                        // Single Mandatory Update Now Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.download_rounded, size: 22),
                            label: Text(
                              updateState.errorMessage != null
                                  ? 'Retry Update'
                                  : 'Update Now',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
                    ],
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
