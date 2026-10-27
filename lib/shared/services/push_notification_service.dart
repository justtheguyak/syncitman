import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase/supabase_client.dart';
import '../../firebase_options.dart';
import 'fcm_sender.dart';
import 'notification_service.dart';

/// Top-level background message handler invoked by Firebase when app is terminated or backgrounded.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  debugPrint('Handling FCM background message: ${message.messageId}');

  // If message contains notification payload, Android system tray displays it automatically.
  // If data-only message arrives in background, display it manually via NotificationService:
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title'] ?? 'CoupleSync Alert 💕';
    final body = message.data['body'] ?? 'You have a new couple notification ❤️';
    final notifId = (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch) & 0x7FFFFFFF;

    await NotificationService.init();
    await NotificationService.showNotification(
      id: notifId,
      title: title,
      body: body,
      channelId: NotificationService.channelSharedReminders,
      channelName: 'Shared Reminders & Partner Alerts',
    );
  }
}

class PushNotificationService {
  static bool _initialized = false;
  static String? _cachedToken;
  static RealtimeChannel? _globalPartnerChannel;
  static final List<VoidCallback> _alertListeners = [];

  /// Retrieves the currently cached or active FCM device token
  static String? get currentToken => _cachedToken;

  /// Add a listener that triggers when a real-time partner alert arrives
  static void addAlertListener(VoidCallback listener) {
    if (!_alertListeners.contains(listener)) {
      _alertListeners.add(listener);
    }
  }

  /// Remove an alert listener
  static void removeAlertListener(VoidCallback listener) {
    _alertListeners.remove(listener);
  }

  /// Initialize Firebase Core and Firebase Messaging
  static Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Initialize Firebase App
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2. Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Request permissions for notifications (POST_NOTIFICATIONS on Android 13+)
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM Authorization status: ${settings.authorizationStatus}');

      // 4. Foreground presentation options (iOS/macOS)
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message received: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // 6. Handle notification click when app opens from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM message clicked from background: ${message.data}');
        _notifyListeners();
      });

      // 7. Check if app was launched directly by tapping a notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App launched via FCM notification: ${initialMessage.data}');
      }

      // 8. Listen to token refresh events
      messaging.onTokenRefresh.listen((newToken) {
        _cachedToken = newToken;
        debugPrint('FCM token refreshed: $newToken');
        syncTokenWithSupabase();
      });

      _initialized = true;
      debugPrint('PushNotificationService initialized successfully');

      // Attempt to retrieve token and sync if user is already logged in
      await syncTokenWithSupabase();

      // Start global broadcast listener if user is logged in
      final currentUser = SupabaseConfig.client.auth.currentUser;
      if (currentUser != null) {
        startGlobalPartnerListener(currentUser.id);
      }
    } catch (e, stack) {
      debugPrint('PushNotificationService init error: $e\n$stack');
    }
  }

  /// Displays foreground notification with heads-up banner, sound, and vibration
  static void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] ?? 'CoupleSync Alert 💕';
    final body = message.notification?.body ?? message.data['body'] ?? 'New notification from partner ❤️';
    final id = (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch) & 0x7FFFFFFF;

    NotificationService.showNotification(
      id: id,
      title: title,
      body: body,
      channelId: NotificationService.channelSharedReminders,
      channelName: 'Shared Reminders & Partner Alerts',
    );

    _notifyListeners();
  }

  static void _notifyListeners() {
    for (final listener in List<VoidCallback>.from(_alertListeners)) {
      try {
        listener();
      } catch (e) {
        debugPrint('Error invoking alert listener: $e');
      }
    }
  }

  /// Starts global Realtime broadcast listener for instant partner alerts on channel `partner_notifications_$userId`
  static void startGlobalPartnerListener(String userId) {
    try {
      _globalPartnerChannel?.unsubscribe();
      final channel = SupabaseConfig.client.channel('partner_notifications_$userId');

      channel.onBroadcast(
        event: 'partner_alert',
        callback: (payload) {
          debugPrint('Realtime partner_alert received: $payload');
          _onRealtimeBroadcast(payload);
        },
      );

      channel.onBroadcast(
        event: 'task_alert',
        callback: (payload) {
          debugPrint('Realtime task_alert received: $payload');
          _onRealtimeBroadcast(payload);
        },
      );

      channel.onBroadcast(
        event: 'reminder_alert',
        callback: (payload) {
          debugPrint('Realtime reminder_alert received: $payload');
          _onRealtimeBroadcast(payload);
        },
      );

      channel.subscribe((status, error) {
        debugPrint('Global partner notification channel status: $status (error: $error)');
      });

      _globalPartnerChannel = channel;
      debugPrint('Subscribed to partner notification broadcast channel for $userId');
    } catch (e) {
      debugPrint('Error starting global partner listener: $e');
    }
  }

  static void _onRealtimeBroadcast(Map<String, dynamic> payload) {
    final title = payload['title'] as String? ?? '💕 CoupleSync Alert';
    final body = payload['body'] as String? ?? 'New update from your partner ❤️';
    final id = (DateTime.now().millisecondsSinceEpoch ^ 0xABCD).abs() & 0x7FFFFFFF;

    NotificationService.showNotification(
      id: id,
      title: title,
      body: body,
      channelId: NotificationService.channelSharedReminders,
      channelName: 'Shared Reminders & Partner Alerts',
    );

    _notifyListeners();
  }

  /// Stops global Realtime broadcast listener
  static void stopGlobalPartnerListener() {
    try {
      _globalPartnerChannel?.unsubscribe();
      _globalPartnerChannel = null;
      debugPrint('Unsubscribed from global partner notification broadcast');
    } catch (e) {
      debugPrint('Error stopping global partner listener: $e');
    }
  }

  /// Saves or updates the device FCM token in Supabase `profiles` (and `user_push_tokens`)
  static Future<void> syncTokenWithSupabase() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        debugPrint('Cannot sync FCM token: User not logged in');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('Cannot sync FCM token: Token is null or empty');
        return;
      }

      _cachedToken = token;
      debugPrint('FCM Token for user ${user.id}: ${token.substring(0, 15)}...');

      // 1. Save into profiles table (encoded safely alongside avatar_url)
      try {
        final profileRes = await SupabaseConfig.client
            .from('profiles')
            .select('avatar_url')
            .eq('id', user.id)
            .maybeSingle();

        final rawAvatar = profileRes?['avatar_url'] as String?;
        String cleanAvatar = '';
        if (rawAvatar != null) {
          cleanAvatar = rawAvatar.split('|||FCM:')[0].trim();
        }

        final combined = cleanAvatar.isEmpty ? '|||FCM:$token' : '$cleanAvatar|||FCM:$token';

        await SupabaseConfig.client.from('profiles').update({
          'avatar_url': combined,
        }).eq('id', user.id);

        debugPrint('FCM Token synced into profiles table successfully');
      } catch (profileErr) {
        debugPrint('Profiles token sync note: $profileErr');
      }

      // 2. Also try upserting to user_push_tokens table if it exists
      try {
        await SupabaseConfig.client.from('user_push_tokens').upsert(
          {
            'user_id': user.id,
            'token': token,
            'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id, token',
        );
        debugPrint('FCM Token saved to user_push_tokens successfully');
      } catch (_) {}
    } catch (e) {
      debugPrint('Failed to sync FCM token: $e');
    }
  }

  /// Deletes this device's token on logout
  static Future<void> deleteTokenOnLogout() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user != null) {
        stopGlobalPartnerListener();

        // Clear token from profiles
        try {
          final profileRes = await SupabaseConfig.client
              .from('profiles')
              .select('avatar_url')
              .eq('id', user.id)
              .maybeSingle();
          final rawAvatar = profileRes?['avatar_url'] as String?;
          if (rawAvatar != null && rawAvatar.contains('|||FCM:')) {
            final cleanAvatar = rawAvatar.split('|||FCM:')[0].trim();
            await SupabaseConfig.client.from('profiles').update({
              'avatar_url': cleanAvatar.isEmpty ? null : cleanAvatar,
            }).eq('id', user.id);
          }
        } catch (_) {}

        // Clear from user_push_tokens
        if (_cachedToken != null) {
          try {
            await SupabaseConfig.client
                .from('user_push_tokens')
                .delete()
                .eq('user_id', user.id)
                .eq('token', _cachedToken!);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error removing push token on logout: $e');
    }
  }

  /// Dispatches a push notification to partner's device with Triple-Channel Redundancy:
  /// Channel 1: Google FCM HTTP v1 Direct Push (works in background & terminated state)
  /// Channel 2: Supabase Realtime Broadcast (instantaneous foreground/active delivery)
  /// Channel 3: Supabase Edge Function fallback
  static Future<bool> sendPartnerPush({
    required String partnerId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return false;

    bool sentFcm = false;
    bool sentBroadcast = false;

    // 1. Fetch partner's FCM Token from profiles or user_push_tokens
    try {
      String? partnerToken;

      // Check profiles table first
      final partnerProfile = await SupabaseConfig.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', partnerId)
          .maybeSingle();

      final rawAvatar = partnerProfile?['avatar_url'] as String?;
      if (rawAvatar != null && rawAvatar.contains('|||FCM:')) {
        final tokenPart = rawAvatar.split('|||FCM:')[1].trim();
        if (tokenPart.isNotEmpty) {
          partnerToken = tokenPart;
        }
      }

      // If not found in profiles, check user_push_tokens table
      if (partnerToken == null || partnerToken.isEmpty) {
        try {
          final tokenRow = await SupabaseConfig.client
              .from('user_push_tokens')
              .select('token')
              .eq('user_id', partnerId)
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (tokenRow != null && tokenRow['token'] != null) {
            partnerToken = tokenRow['token'] as String;
          }
        } catch (_) {}
      }

      // If partner token found, dispatch via FCM v1 directly
      if (partnerToken != null && partnerToken.isNotEmpty) {
        sentFcm = await FcmSender.sendPushNotification(
          fcmToken: partnerToken,
          title: title,
          body: body,
          data: data,
        );
        if (sentFcm) {
          debugPrint('FCM Push notification sent successfully to partner');
        }
      } else {
        debugPrint('No FCM push token found for partner $partnerId');
      }
    } catch (fcmErr) {
      debugPrint('Direct FCM send notice: $fcmErr');
    }

    // 2. Broadcast via Supabase Realtime channel for instantaneous live delivery
    try {
      final channel = SupabaseConfig.client.channel('partner_notifications_$partnerId');
      final completer = Completer<bool>();

      channel.subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          try {
            await channel.sendBroadcastMessage(
              event: 'partner_alert',
              payload: {
                'title': title,
                'body': body,
                'creator_id': user.id,
                'data': data ?? {},
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
            completer.complete(true);
          } catch (e) {
            completer.complete(false);
          }
        } else if (status == RealtimeSubscribeStatus.channelError) {
          completer.complete(false);
        }
      });

      sentBroadcast = await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );

      if (sentBroadcast) {
        debugPrint('Realtime partner_alert broadcasted successfully');
      }
    } catch (broadcastErr) {
      debugPrint('Realtime broadcast notice: $broadcastErr');
    }

    // 3. Fallback: Edge Function invoke (if deployed)
    try {
      final res = await SupabaseConfig.client.functions.invoke(
        'send-reminder-notification',
        body: {
          'partner_id': partnerId,
          'creator_id': user.id,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );
      if (res.status == 200) {
        return true;
      }
    } catch (_) {}

    return sentFcm || sentBroadcast;
  }
}
