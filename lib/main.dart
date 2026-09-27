import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/supabase/supabase_client.dart';
import 'shared/services/notification_service.dart';

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

  runApp(const ProviderScope(child: CoupleSyncApp()));
}
