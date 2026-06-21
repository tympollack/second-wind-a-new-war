import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthState {
  final User? user;
  final String? displayName;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.displayName,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    String? displayName,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      displayName: displayName ?? this.displayName,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  void _init() {
    final user = SupabaseService.currentUser;
    if (user != null) {
      state = state.copyWith(user: user);
      _loadProfile(user.id);
    }

    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        state = state.copyWith(user: user);
        _loadProfile(user.id);
      } else {
        state = const AuthState();
      }
    });
  }

  Future<void> _loadProfile(String userId) async {
    final profile = await SupabaseService.getUser(userId);
    if (profile != null) {
      state = state.copyWith(
        displayName: profile['display_name'] as String?,
      );
    }
  }

  Future<void> signInAnonymously() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseService.signInAnonymously();
      if (response.user != null) {
        final name = 'Commander_${response.user!.id.substring(0, 6)}';
        await SupabaseService.upsertUser(response.user!.id, name);
        state = state.copyWith(
          user: response.user,
          displayName: name,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response =
          await SupabaseService.signInWithEmail(email, password);
      if (response.user != null) {
        await _loadProfile(response.user!.id);
        state = state.copyWith(user: response.user, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signUpWithEmail(
      String email, String password, String displayName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response =
          await SupabaseService.signUpWithEmail(email, password);
      if (response.user != null) {
        final name =
            displayName.isNotEmpty ? displayName : email.split('@')[0];
        await SupabaseService.upsertUser(response.user!.id, name);
        state = state.copyWith(
          user: response.user,
          displayName: name,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    state = const AuthState();
  }

  Future<void> updateDisplayName(String name) async {
    if (state.user == null) return;
    await SupabaseService.updateDisplayName(state.user!.id, name);
    state = state.copyWith(displayName: name);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
