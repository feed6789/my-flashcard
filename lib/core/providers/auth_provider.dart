import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flashcard_app/config/supabase_config.dart';
import 'package:flashcard_app/features/flashcard/data/services/sync_service.dart';

final authProvider = StateProvider<AuthState>((ref) => AuthState.initial());

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isSyncing;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isSyncing = false,
  });

  bool get isAuthenticated => user != null;

  factory AuthState.initial() {
    return AuthState(
      user: SupabaseConfig.currentUser,
      isLoading: false,
      isSyncing: false,
    );
  }

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isSyncing,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SyncService _sync = SyncService();

  AuthNotifier() : super(AuthState.initial());

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await SupabaseConfig.signInWithEmail(email, password);
      if (response.user != null) {
        state = state.copyWith(user: response.user, isLoading: false);

        // 🔄 Sync sau khi login
        await _runSync();

        return true;
      } else {
        state = state.copyWith(isLoading: false, error: 'User not found');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await SupabaseConfig.signUpWithEmail(email, password);
      if (response.user != null) {
        state = state.copyWith(user: response.user, isLoading: false);
        await _runSync();
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: 'Sign up failed');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await SupabaseConfig.signOut();
      state = state.copyWith(isLoading: false, clearUser: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _runSync() async {
    state = state.copyWith(isSyncing: true);
    try {
      final result = await _sync.syncProgress();
      print('🔄 Sync result: $result');
    } catch (e) {
      print('⚠️ Sync error: $e');
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
