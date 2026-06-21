import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/device_service.dart';

class AuthState {
  final User? user;
  final String? displayName;
  final bool isLoading;
  final String? error;
  final bool isAnonymous;
  final String? deviceId;

  const AuthState({
    this.user,
    this.displayName,
    this.isLoading = false,
    this.error,
    this.isAnonymous = false,
    this.deviceId,
  });

  AuthState copyWith({
    User? user,
    String? displayName,
    bool? isLoading,
    String? error,
    bool? isAnonymous,
    String? deviceId,
  }) {
    return AuthState(
      user: user ?? this.user,
      displayName: displayName ?? this.displayName,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final deviceId = await DeviceService.getOrCreateDeviceId();
    state = state.copyWith(deviceId: deviceId);

    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        final isAnon = user.isAnonymous;
        state = state.copyWith(user: user, isAnonymous: isAnon);
        await _loadProfile(user.id);
      }

      SupabaseService.client.auth.onAuthStateChange.listen((data) {
        final user = data.session?.user;
        if (user != null) {
          final isAnon = user.isAnonymous;
          state = state.copyWith(user: user, isAnonymous: isAnon);
          _loadProfile(user.id);
        } else {
          state = AuthState(deviceId: state.deviceId);
        }
      });
    } catch (e) {
      // Supabase not initialized
    }
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final profile = await SupabaseService.getUser(userId);
      if (profile != null) {
        state = state.copyWith(
          displayName: profile['display_name'] as String?,
        );
      }
    } catch (e) {
      // Profile load failed
    }
  }

  Future<void> signInAnonymously() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final deviceId = state.deviceId ?? await DeviceService.getOrCreateDeviceId();
      final response = await SupabaseService.signInAnonymously();
      if (response.user != null) {
        final name = 'Commander_${deviceId.substring(0, 6)}';
        await SupabaseService.upsertUser(
          response.user!.id,
          name,
          deviceId: deviceId,
        );
        state = state.copyWith(
          user: response.user,
          displayName: name,
          isLoading: false,
          isAnonymous: true,
          deviceId: deviceId,
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
        state = state.copyWith(
          user: response.user,
          isLoading: false,
          isAnonymous: false,
        );
        await DeviceService.markAccountCreated();
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
          isAnonymous: false,
        );
        await DeviceService.markAccountCreated();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> upgradeAnonymousAccount(
      String email, String password, String displayName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseService.client.auth.updateUser(
        UserAttributes(email: email, password: password),
      );
      if (response.user != null) {
        final name =
            displayName.isNotEmpty ? displayName : email.split('@')[0];
        await SupabaseService.updateDisplayName(response.user!.id, name);
        state = state.copyWith(
          user: response.user,
          displayName: name,
          isLoading: false,
          isAnonymous: false,
        );
        await DeviceService.markAccountCreated();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      await SupabaseService.signOut();
    } catch (e) {
      // ignore
    }
    state = AuthState(deviceId: state.deviceId);
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
