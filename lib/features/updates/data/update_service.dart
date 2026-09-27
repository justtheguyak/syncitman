import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'update_model.dart';

class UpdateService {
  static const String githubOwner = 'justtheguyak';
  static const String githubRepo = 'syncitman';
  static const String apiLatestReleaseUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  /// Fetch currently installed app version (e.g. "1.0.0")
  static Future<String> getCurrentAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (e) {
      debugPrint('Error getting package info: $e');
      return '1.0.0';
    }
  }

  /// Fetch full package information
  static Future<PackageInfo?> getPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (e) {
      debugPrint('Error getting package info: $e');
      return null;
    }
  }

  /// Checks GitHub repository for the latest release
  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentAppVersion();
      final uri = Uri.parse(apiLatestReleaseUrl);

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'CoupleSync-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return AppUpdateInfo.fromGitHubRelease(
          json: data,
          currentVersion: currentVersion,
        );
      } else if (response.statusCode == 404) {
        // No releases published yet on the repository
        return AppUpdateInfo(
          latestVersion: currentVersion,
          currentVersion: currentVersion,
          isUpdateAvailable: false,
          releaseName: 'CoupleSync Up to Date',
          releaseNotes: 'You are on the latest version of CoupleSync.',
          htmlUrl: 'https://github.com/$githubOwner/$githubRepo/releases',
        );
      } else {
        debugPrint(
            'GitHub API returned non-200 status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error checking for update: $e');
      return null;
    }
  }

  /// Initiates Over-The-Air APK download and triggers Android package installer
  static Stream<OtaEvent> startOtaUpdate({
    required String apkUrl,
    String destinationFilename = 'CoupleSync-update.apk',
  }) {
    return OtaUpdate().execute(
      apkUrl,
      destinationFilename: destinationFilename,
    );
  }

  /// Launches external GitHub release link in browser as a fallback
  static Future<bool> openReleaseInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint('Error opening release url: $e');
      return false;
    }
  }
}
