import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Direct Google FCM HTTP v1 API Client
/// Uses service account credentials to send push notifications directly to partner devices.
class FcmSender {
  static const String projectId = 'couplesync-syncitman';
  static const String clientEmail =
      'firebase-adminsdk-fbsvc@couplesync-syncitman.iam.gserviceaccount.com';
  static const String _privateKey =
      '-----BEGIN PRIVATE KEY-----\n'
      'MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDSz4rMSiiFu7qa\n'
      'YUSr3fds5vaEFChc0K1HcSywrrMnlC4PmzKOuhfjuZ0pR9PmMnKDoM5wHNcuDi/x\n'
      'oh/s1bEdtAHwbq0Y2QPycWd04QYiqVXQMNTNgW/9vDD+VyUPwcwE2oaVYg/gfGu4\n'
      'Vrgy9UF+zZ9M1ncxqhvD+eHxg9463QOnjLwhtN6HWTH6/HPWTC0lfjWXZ/CvStsH\n'
      'PfwIHtU8E3wUWeCJUU8NOcAYQEF49zxzIlvabAau/y6JYut1kpMnsO6/8yXfgrpn\n'
      'zqywArdWc26Cfr67NvN1Mv2gpXjzj53DuLTYtRIp8rGVxexqrUBSb8PzvwfaitON\n'
      '0rzm8aI9AgMBAAECggEAVurlUledH46IYJCMLMSG+Gq95zUcczBC0XrzLyHIkiAB\n'
      'YcPec4R8xxLHnraTwoy4NFc/5m+ttLp6wAjVWuO8c/+88PHhAqavfu2M9160FeR1\n'
      'kjIf+19L2nUWSjeJ+1YvFS04Yi0dWLRUAZwXtEL0ryB+dsLSQDLf4cyMgPSa0u9/\n'
      'eeqF6hri8X+VPH7Pv4H2luo87CLsY7CAr8tshCZVSsJxW2dTtX7dDesOOXFitgEh\n'
      'WzT0NgQZ2mNnkaHEuwfIcU/hnuVaOiwZA5BLUIVlH289Y6AN95wPRORPuhjfuWBW\n'
      'YXJgJntMaV7iHtkoxrPM8uaLpnq8MI7e9nkp4/z67QKBgQD0iGfFq1/qHcoFUqGV\n'
      'rx11R6yblRPnkI6JNb1jBrvZCfz+jitG006QKE7/CEuEM9P8llC6xdwqYnN9xXr4\n'
      'CydS6pt3HnqquBdGnqiX8VxDad8aoPB88UMerTOjhEKZn7dFGWmScgA3uNxHwa0f\n'
      'Cqi3ssDAQ3X4DXQPzQ6kq/76GwKBgQDcsk5H7JbxBFejw/Pc6K870EgphPfgPjDR\n'
      't1CZUAhe27IoivXBM2UqwlEGndWk0rrU9BgEllNvlqF7OgkbV22O4d+d+X6veXs+\n'
      'bkUoQ13HwLEfBE1yzTiFB1OPv9s5RbpkOcmSeMnNMzgDb1FuvU3IBwDujTfSbM/6\n'
      'h2/bW48ahwKBgHaU82XLLm8U1RPxt0QkMG/gOxcTmxxvYH+vXND5wfyFOHelL91f\n'
      'uTh1I6HPPve0Pne92RZJvvOa3JDARFqm5gHynUONt0S0kyz+4ZkVRX23iKacJyMf\n'
      'yEHHEkSYbcebyT8sDKMkv3BGKCRwCmkEPT8f4xMZY8rPk1naQeCfO73DAoGAIp8S\n'
      'KrRRxYOB4B34XppeCwsUlvbWD+aRsASK71Ifzgm2/Cc4gFN4tml/XoNaJZ4tUwTr\n'
      '06RleGbv9C3ZieGAPV7vvo+KMSrki5mu3a8bwh9Xad856x2IlU3d7PoTAPwQTnLG\n'
      'TWUHe1pimh9XbgDid9OpcMLUk/0f71RZ1taZL3cCgYEAvhL+mCmifOgTFzw3S6li\n'
      'SD+Tjdn9EJTwFwscyTF47DiDg9awKo5VGuq4/L97tUrCAKysi8i7o2gv8+F6bptA\n'
      'btQnbN4SgvOgV1lgQ4iNGou/AL8g0Vw8FEYz2meuaFJ0EDDrxJRPpdJ1zNX+ceYW\n'
      'mzJjWHaSk3M2QSfkSstwGtU=\n'
      '-----END PRIVATE KEY-----\n';

  static String? _cachedAccessToken;
  static DateTime? _tokenExpiry;

  /// Retrieves a valid OAuth2 Access Token with FCM scope
  static Future<String?> _getAccessToken() async {
    try {
      if (_cachedAccessToken != null &&
          _tokenExpiry != null &&
          DateTime.now().isBefore(_tokenExpiry!)) {
        return _cachedAccessToken;
      }

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final jwt = JWT(
        {
          'iss': clientEmail,
          'scope': 'https://www.googleapis.com/auth/firebase.messaging',
          'aud': 'https://oauth2.googleapis.com/token',
          'iat': now,
          'exp': now + 3600,
        },
      );

      final key = RSAPrivateKey(_privateKey);
      final assertion = jwt.sign(key, algorithm: JWTAlgorithm.RS256);

      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': assertion,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _cachedAccessToken = data['access_token'] as String?;
        final expiresIn = (data['expires_in'] as int?) ?? 3600;
        _tokenExpiry =
            DateTime.now().add(Duration(seconds: (expiresIn - 120).clamp(60, 3600)));
        return _cachedAccessToken;
      } else {
        debugPrint(
            'Google OAuth2 token error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting Google access token: $e');
      return null;
    }
  }

  /// Sends a push notification to [fcmToken] via Firebase Cloud Messaging HTTP v1 API
  static Future<bool> sendPushNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (fcmToken.isEmpty) return false;

    try {
      final token = await _getAccessToken();
      if (token == null) {
        debugPrint('Cannot send FCM push: Failed to acquire OAuth2 access token');
        return false;
      }

      final fcmUrl =
          Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

      // Convert all data values to strings for FCM compatibility
      final stringData = <String, String>{};
      if (data != null) {
        data.forEach((key, value) {
          stringData[key] = value?.toString() ?? '';
        });
      }

      final payload = {
        'message': {
          'token': fcmToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': stringData,
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'couplesync_shared_reminders',
              'sound': 'default',
              'notification_priority': 'PRIORITY_MAX',
              'default_sound': true,
              'default_vibrate_timings': true,
            },
          },
        },
      };

      final response = await http.post(
        fcmUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint('FCM push sent successfully to token: ${fcmToken.substring(0, 15)}...');
        return true;
      } else {
        debugPrint('FCM HTTP v1 Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Exception dispatching FCM push: $e');
      return false;
    }
  }
}
