import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import '../data/update_model.dart';
import '../data/update_service.dart';

class UpdateState {
  final bool isChecking;
  final AppUpdateInfo? updateInfo;
  final bool isDismissed;
  final OtaStatus? otaStatus;
  final int downloadProgress; // 0 to 100
  final String? errorMessage;

  const UpdateState({
    this.isChecking = false,
    this.updateInfo,
    this.isDismissed = false,
    this.otaStatus,
    this.downloadProgress = 0,
    this.errorMessage,
  });

  /// Mandatory update flag: whenever an update is available, full-screen blocking UI takes over
  bool get hasMandatoryUpdate =>
      updateInfo != null && updateInfo!.isUpdateAvailable;

  bool get hasUpdate =>
      updateInfo != null && updateInfo!.isUpdateAvailable && !isDismissed;

  bool get isDownloading =>
      otaStatus == OtaStatus.DOWNLOADING || otaStatus == OtaStatus.INSTALLING;

  UpdateState copyWith({
    bool? isChecking,
    AppUpdateInfo? updateInfo,
    bool? isDismissed,
    OtaStatus? otaStatus,
    int? downloadProgress,
    String? errorMessage,
  }) {
    return UpdateState(
      isChecking: isChecking ?? this.isChecking,
      updateInfo: updateInfo ?? this.updateInfo,
      isDismissed: isDismissed ?? this.isDismissed,
      otaStatus: otaStatus ?? this.otaStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage,
    );
  }
}

class UpdateNotifier extends Notifier<UpdateState> {
  StreamSubscription<OtaEvent>? _otaSubscription;

  @override
  UpdateState build() {
    ref.onDispose(() {
      _otaSubscription?.cancel();
    });

    // Automatically check for updates silently on app startup
    Future.microtask(() => checkForUpdates(silent: true));

    return const UpdateState();
  }

  Future<void> checkForUpdates({bool silent = false}) async {
    state = state.copyWith(isChecking: true, errorMessage: null);

    try {
      final info = await UpdateService.checkForUpdate();
      state = state.copyWith(
        isChecking: false,
        updateInfo: info,
        isDismissed: false,
      );
    } catch (e) {
      state = state.copyWith(
        isChecking: false,
        errorMessage: silent ? null : 'Failed to check for updates: $e',
      );
    }
  }

  void dismissBanner() {
    state = state.copyWith(isDismissed: true);
  }

  void resetUpdate() {
    _otaSubscription?.cancel();
    state = const UpdateState();
  }

  /// Trigger OTA direct APK download and Android package installation without external browser redirect
  Future<void> startUpdate(BuildContext context) async {
    final info = state.updateInfo;
    if (info == null) return;

    // Direct APK download link from GitHub release
    final String apkUrl = (info.apkDownloadUrl != null &&
            info.apkDownloadUrl!.isNotEmpty)
        ? info.apkDownloadUrl!
        : 'https://github.com/${UpdateService.githubOwner}/${UpdateService.githubRepo}/releases/download/v${info.latestVersion}/app-release.apk';

    // Cancel any previous subscription
    await _otaSubscription?.cancel();

    state = state.copyWith(
      otaStatus: OtaStatus.DOWNLOADING,
      downloadProgress: 0,
      errorMessage: null,
    );

    try {
      _otaSubscription = UpdateService.startOtaUpdate(
        apkUrl: apkUrl,
        destinationFilename: info.apkFileName ?? 'CoupleSync-update.apk',
      ).listen(
        (OtaEvent event) {
          debugPrint('OTA Status: ${event.status}, Value: ${event.value}');
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final percent = int.tryParse(event.value ?? '0') ?? 0;
              state = state.copyWith(
                otaStatus: OtaStatus.DOWNLOADING,
                downloadProgress: percent,
              );
              break;
            case OtaStatus.INSTALLING:
              state = state.copyWith(
                otaStatus: OtaStatus.INSTALLING,
                downloadProgress: 100,
              );
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              state = state.copyWith(
                errorMessage: 'An update download is already in progress.',
              );
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              state = state.copyWith(
                errorMessage:
                    'Install permission not granted. Please enable install permissions for CoupleSync in Android Settings.',
              );
              break;
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
            default:
              state = state.copyWith(
                otaStatus: null,
                errorMessage:
                    'Download failed (${event.status.name}). Please tap Retry Update.',
              );
              break;
          }
        },
        onError: (err) {
          debugPrint('OTA stream error: $err');
          state = state.copyWith(
            otaStatus: null,
            errorMessage: 'Download interrupted. Tap Retry Update to continue.',
          );
        },
      );
    } catch (e) {
      debugPrint('OTA start error: $e');
      state = state.copyWith(
        otaStatus: null,
        errorMessage: 'Failed to start download: $e',
      );
    }
  }

  /// For testing/demo purposes when previewing the full-screen mandatory update UI
  void simulateUpdateAvailable() {
    state = state.copyWith(
      isChecking: false,
      isDismissed: false,
      updateInfo: const AppUpdateInfo(
        latestVersion: '1.0.1',
        currentVersion: '1.0.0',
        isUpdateAvailable: true,
        releaseName: 'CoupleSync v1.0.1 🚀',
        releaseNotes:
            '• Mandatory couple sync update\n• Weekly repeating reminders enabled\n• Direct in-app background OTA installer\n• UI performance enhancements',
        apkDownloadUrl:
            'https://github.com/justtheguyak/syncitman/releases/latest/download/app-release.apk',
        apkFileName: 'CoupleSync-v1.0.1.apk',
        htmlUrl: 'https://github.com/justtheguyak/syncitman/releases',
      ),
    );
  }
}

final updateNotifierProvider =
    NotifierProvider<UpdateNotifier, UpdateState>(UpdateNotifier.new);
