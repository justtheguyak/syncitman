import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/supabase/supabase_client.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialize warning: $e');
  }

  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService initialize warning: $e');
  }

  try {
    await PushNotificationService.init();
  } catch (e) {
    debugPrint('PushNotificationService initialize warning: $e');
  }

  // Listen for login/logout to sync FCM tokens and manage global partner alert listeners
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;
    if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
      PushNotificationService.syncTokenWithSupabase();
      if (session?.user != null) {
        PushNotificationService.startGlobalPartnerListener(session!.user.id);
      }
    } else if (event == AuthChangeEvent.signedOut) {
      PushNotificationService.deleteTokenOnLogout();
    }
  });

  // Start global partner listener if already logged in
  final currentSession = Supabase.instance.client.auth.currentSession;
  if (currentSession?.user != null) {
    PushNotificationService.startGlobalPartnerListener(currentSession!.user.id);
  }

  runApp(const ProviderScope(child: CoupleSyncApp()));
}
