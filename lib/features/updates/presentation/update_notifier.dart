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
        isDismissed: false, // Reset dismissed if explicitly checking
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

  /// Trigger OTA download and Android package installation
  Future<void> startUpdate(BuildContext context) async {
    final info = state.updateInfo;
    if (info == null) return;

    final apkUrl = info.apkDownloadUrl;
    if (apkUrl == null || apkUrl.isEmpty) {
      // If no direct APK asset in release, open GitHub release page in browser
      await UpdateService.openReleaseInBrowser(info.htmlUrl);
      return;
    }

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
                    'Install permission not granted. Please allow installs in Android settings.',
              );
              break;
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
            default:
              state = state.copyWith(
                errorMessage:
                    'Could not download update (${event.status.name}). Opening browser download...',
              );
              UpdateService.openReleaseInBrowser(apkUrl);
              break;
          }
        },
        onError: (err) {
          debugPrint('OTA stream error: $err');
          state = state.copyWith(
            errorMessage: 'Update download failed: $err',
          );
          UpdateService.openReleaseInBrowser(apkUrl);
        },
      );
    } catch (e) {
      debugPrint('OTA start error: $e');
      state = state.copyWith(
        errorMessage: 'Failed to initiate update: $e',
      );
      UpdateService.openReleaseInBrowser(apkUrl);
    }
  }

  /// For testing/demo purposes when no release exists yet on GitHub
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
            '• Added weekly repeating reminders for couples\n• Added in-app OTA auto updates with GitHub Releases\n• Added one-tap "Update Now" installer\n• UI performance enhancements',
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
