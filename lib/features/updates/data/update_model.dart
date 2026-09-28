class AppUpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final bool isUpdateAvailable;
  final String releaseName;
  final String releaseNotes;
  final String? apkDownloadUrl;
  final String? apkFileName;
  final DateTime? publishedAt;
  final String htmlUrl;
  final bool isMandatory;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.isUpdateAvailable,
    required this.releaseName,
    required this.releaseNotes,
    this.apkDownloadUrl,
    this.apkFileName,
    this.publishedAt,
    required this.htmlUrl,
    this.isMandatory = true,
  });

  /// Compare two semantic version strings like "1.0.1" vs "1.0.0"
  static bool isNewerVersion(String latestStr, String currentStr) {
    try {
      final cleanLatest = latestStr.toLowerCase().replaceAll('v', '').trim();
      final cleanCurrent = currentStr.toLowerCase().replaceAll('v', '').trim();

      final latestParts = cleanLatest.split('+');
      final currentParts = cleanCurrent.split('+');

      final latestSem = latestParts[0].split('.').map(int.tryParse).toList();
      final currentSem = currentParts[0].split('.').map(int.tryParse).toList();

      final maxLen = latestSem.length > currentSem.length
          ? latestSem.length
          : currentSem.length;

      for (int i = 0; i < maxLen; i++) {
        final lVal = i < latestSem.length ? (latestSem[i] ?? 0) : 0;
        final cVal = i < currentSem.length ? (currentSem[i] ?? 0) : 0;

        if (lVal > cVal) return true;
        if (lVal < cVal) return false;
      }

      // If semantic versions match, compare build numbers
      if (latestParts.length > 1 && currentParts.length > 1) {
        final lBuild = int.tryParse(latestParts[1]) ?? 0;
        final cBuild = int.tryParse(currentParts[1]) ?? 0;
        return lBuild > cBuild;
      }

      return false;
    } catch (_) {
      return latestStr != currentStr;
    }
  }

  /// Parse from a Supabase `app_updates` row
  factory AppUpdateInfo.fromSupabaseRow({
    required Map<String, dynamic> row,
    required String currentVersion,
  }) {
    final version = row['version'] as String? ?? currentVersion;
    final releaseName = row['release_name'] as String? ?? 'CoupleSync v$version';
    final releaseNotes = row['release_notes'] as String? ?? 'Bug fixes and improvements.';
    final apkUrl = row['apk_url'] as String? ?? '';
    final isMandatory = row['is_mandatory'] as bool? ?? true;

    DateTime? publishedDate;
    if (row['published_at'] != null) {
      publishedDate = DateTime.tryParse(row['published_at'].toString());
    }

    final isNewer = isNewerVersion(version, currentVersion);

    return AppUpdateInfo(
      latestVersion: version.replaceAll('v', '').replaceAll('V', '').trim(),
      currentVersion: currentVersion,
      isUpdateAvailable: isNewer,
      releaseName: releaseName,
      releaseNotes: releaseNotes,
      apkDownloadUrl: apkUrl.isNotEmpty ? apkUrl : null,
      apkFileName: 'CoupleSync-v$version.apk',
      publishedAt: publishedDate,
      htmlUrl: '',
      isMandatory: isMandatory,
    );
  }

  /// Parse from GitHub Release JSON
  factory AppUpdateInfo.fromGitHubRelease({
    required Map<String, dynamic> json,
    required String currentVersion,
  }) {
    final tagName = json['tag_name'] as String? ?? 'v1.0.0';
    final releaseName = json['name'] as String? ?? tagName;
    final body = json['body'] as String? ?? 'No release notes provided.';
    final htmlUrl = json['html_url'] as String? ??
        'https://github.com/justtheguyak/syncitman/releases';

    DateTime? publishedDate;
    if (json['published_at'] != null) {
      publishedDate = DateTime.tryParse(json['published_at'].toString());
    }

    String? apkUrl;
    String? apkName;
    final assets = json['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = asset['name'] as String? ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          apkName = name;
          break;
        }
      }
    }

    final isNewer = isNewerVersion(tagName, currentVersion);

    return AppUpdateInfo(
      latestVersion: tagName.replaceAll('v', '').replaceAll('V', '').trim(),
      currentVersion: currentVersion,
      isUpdateAvailable: isNewer,
      releaseName: releaseName,
      releaseNotes: body,
      apkDownloadUrl: apkUrl,
      apkFileName: apkName ?? 'CoupleSync-update.apk',
      publishedAt: publishedDate,
      htmlUrl: htmlUrl,
      isMandatory: true,
    );
  }
}
