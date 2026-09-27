import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://pisabzyatipobpwczbzq.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBpc2FienlhdGlwb2Jwd2N6YnpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA1MTczMDQsImV4cCI6MjEwNjA5MzMwNH0.kzJjK8SzgxWpoKAHfV2aRlSvFiNqF9vhPvhs-uUMpAA';

  static SupabaseClient get client => Supabase.instance.client;
}
