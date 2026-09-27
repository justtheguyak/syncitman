import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import 'profile_model.dart';

class ProfileRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<ProfileModel?> fetchProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        // If profile doesn't exist yet, insert a default one
        final user = _client.auth.currentUser;
        if (user != null && user.id == userId) {
          final defaultName = user.userMetadata?['display_name'] ??
              (user.email?.split('@').first ?? 'You');
          final inserted = await _client
              .from('profiles')
              .upsert({
                'id': userId,
                'display_name': defaultName,
              })
              .select()
              .single();
          return ProfileModel.fromJson(inserted);
        }
        return null;
      }
      return ProfileModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<ProfileModel?> fetchPartner(String partnerId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', partnerId)
          .maybeSingle();

      if (data == null) return null;
      return ProfileModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<List<ProfileModel>> fetchOtherProfiles(String currentUserId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .neq('id', currentUserId);
      return (data as List)
          .map((item) => ProfileModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> updateDisplayName(String userId, String displayName) async {
    await _client.from('profiles').update({
      'display_name': displayName,
    }).eq('id', userId);
  }

  Future<void> updateAvatar(String userId, String? avatarUrl) async {
    await _client.from('profiles').update({
      'avatar_url': avatarUrl,
    }).eq('id', userId);
  }

  Future<void> linkPartner(String currentUserId, String partnerId) async {
    // Two-way link
    await _client.from('profiles').update({
      'partner_id': partnerId,
    }).eq('id', currentUserId);

    try {
      await _client.from('profiles').update({
        'partner_id': currentUserId,
      }).eq('id', partnerId);
    } catch (_) {
      // partner RLS update might be restricted if policy is only own; 
      // User can also link from partner account
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});
