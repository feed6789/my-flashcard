import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flashcard_app/config/supabase_config.dart';

// Auth state
final authProvider = StateProvider<AuthState>((ref) => AuthState.initial());

// Auth notifier
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
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.initial());

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseConfig.signInWithEmail(email, password);
      if (response.user != null) {
        state = state.copyWith(user: response.user, isLoading: false);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: 'User not found');
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        user: null,
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseConfig.signUpWithEmail(email, password);
      if (response.user != null) {
        state = state.copyWith(user: response.user, isLoading: false);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: 'Sign up failed');
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        user: null,
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await SupabaseConfig.signOut();
      state = state.copyWith(user: null, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}
