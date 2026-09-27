import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

class AuthUIState {
  final bool isLoading;
  final String? errorMessage;

  const AuthUIState({this.isLoading = false, this.errorMessage});

  AuthUIState copyWith({bool? isLoading, String? errorMessage}) {
    return AuthUIState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthUIState> {
  @override
  AuthUIState build() {
    return const AuthUIState();
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signIn(email: email, password: password);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(e),
      );
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String displayName) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(e),
      );
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.updatePassword(newPassword);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(e),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  String _formatError(dynamic e) {
    final str = e.toString();
    if (str.contains('Invalid login credentials')) {
      return 'Invalid email or password. Please try again.';
    }
    if (str.contains('Email not confirmed')) {
      return 'Please confirm your email address or disable email confirmation in Supabase.';
    }
    return str.replaceAll('Exception:', '').trim();
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthUIState>(AuthNotifier.new);
