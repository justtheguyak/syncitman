import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/profile_model.dart';
import '../data/profile_repository.dart';
import '../../../core/supabase/supabase_client.dart';

class ProfileState {
  final ProfileModel? currentProfile;
  final ProfileModel? partnerProfile;
  final List<ProfileModel> potentialPartners;
  final bool isLoading;
  final String? error;

  ProfileState({
    this.currentProfile,
    this.partnerProfile,
    this.potentialPartners = const [],
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    ProfileModel? currentProfile,
    ProfileModel? partnerProfile,
    List<ProfileModel>? potentialPartners,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      currentProfile: currentProfile ?? this.currentProfile,
      partnerProfile: partnerProfile ?? this.partnerProfile,
      potentialPartners: potentialPartners ?? this.potentialPartners,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProfileNotifier extends AsyncNotifier<ProfileState> {
  @override
  Future<ProfileState> build() async {
    return _fetchData();
  }

  Future<ProfileState> _fetchData() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      return ProfileState();
    }

    final repo = ref.read(profileRepositoryProvider);
    final myProfile = await repo.fetchProfile(user.id);
    ProfileModel? partner;
    if (myProfile?.partnerId != null) {
      partner = await repo.fetchPartner(myProfile!.partnerId!);
    }

    final others = await repo.fetchOtherProfiles(user.id);

    return ProfileState(
      currentProfile: myProfile,
      partnerProfile: partner,
      potentialPartners: others,
      isLoading: false,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchData());
  }

  Future<void> updateName(String newName) async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;
    final repo = ref.read(profileRepositoryProvider);
    await repo.updateDisplayName(user.id, newName);
    await refresh();
  }

  Future<void> linkPartner(String partnerId) async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;
    final repo = ref.read(profileRepositoryProvider);
    await repo.linkPartner(user.id, partnerId);
    await refresh();
  }

  Future<void> updateAvatar(String targetUserId, String? avatarUrl) async {
    final repo = ref.read(profileRepositoryProvider);
    await repo.updateAvatar(targetUserId, avatarUrl);
    await refresh();
  }
}

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, ProfileState>(
  ProfileNotifier.new,
);
