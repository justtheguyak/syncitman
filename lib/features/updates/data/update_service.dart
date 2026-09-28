import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/supabase/supabase_client.dart';
import 'update_model.dart';

class UpdateService {
  static const String githubOwner = 'justtheguyak';
  static const String githubRepo = 'syncitman';
  static const String apiLatestReleaseUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  /// Supabase Storage bucket name for APK releases (fallback)
  static const String storageBucket = 'releases';

  /// Fetch currently installed app version (e.g. "1.0.1")
  static Future<String> getCurrentAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
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

  /// Checks GitHub first, then falls back to Supabase `app_updates` table
  static Future<AppUpdateInfo?> checkForUpdate() async {
    final currentVersion = await getCurrentAppVersion();

    // 1. Check GitHub Release
    try {
      final uri = Uri.parse(apiLatestReleaseUrl);
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'CoupleSync-App',
        },
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final ghInfo = AppUpdateInfo.fromGitHubRelease(
          json: data,
          currentVersion: currentVersion,
        );
        if (ghInfo.apkDownloadUrl != null && ghInfo.apkDownloadUrl!.isNotEmpty) {
          return ghInfo;
        }
      }
    } catch (e) {
      debugPrint('GitHub update check note: $e');
    }

    // 2. Fallback to Supabase app_updates table
    try {
      final client = SupabaseConfig.client;
      final response = await client
          .from('app_updates')
          .select()
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        return AppUpdateInfo.fromSupabaseRow(
          row: response,
          currentVersion: currentVersion,
        );
      }
    } catch (e) {
      debugPrint('Supabase update check note: $e');
    }

    return AppUpdateInfo(
      latestVersion: currentVersion,
      currentVersion: currentVersion,
      isUpdateAvailable: false,
      releaseName: 'CoupleSync Up to Date',
      releaseNotes: 'You are on the latest version of CoupleSync.',
      htmlUrl: 'https://github.com/$githubOwner/$githubRepo/releases',
    );
  }

  /// Gets a public download URL for an APK stored in Supabase Storage
  static String getApkPublicUrl(String fileName) {
    return SupabaseConfig.client.storage
        .from(storageBucket)
        .getPublicUrl(fileName);
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

  /// Launches external URL in browser as a fallback
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
