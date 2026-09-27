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
  });

  /// Compare two semantic version strings like "1.0.1" vs "1.0.0" or "v1.2.0" vs "1.1.0"
  static bool isNewerVersion(String latestStr, String currentStr) {
    try {
      final cleanLatest = latestStr.toLowerCase().replaceAll('v', '').trim();
      final cleanCurrent = currentStr.toLowerCase().replaceAll('v', '').trim();

      // Split build numbers if present (e.g. 1.0.0+2)
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

      // If semantic versions match, compare build numbers if both have them
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
      publishedDate = DateTime.tryParse(json['published_at']);
    }

    // Find the APK in assets
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
    );
  }
}
