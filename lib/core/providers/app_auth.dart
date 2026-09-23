import 'dart:convert';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/models/auth_tokens.dart';
import 'package:mashinow_washer/core/models/user.dart';
import 'package:mashinow_washer/core/storage/token_storage.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated }

class AppState {
  final AuthStatus status;
  final User? user;
  final bool profileCompleted;

  const AppState({
    this.status = AuthStatus.uninitialized,
    this.user,
    this.profileCompleted = false,
  });

  AppState copyWith({
    AuthStatus? status,
    User? user,
    bool? profileCompleted,
    bool clearUser = false,
  }) {
    return AppState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      profileCompleted: profileCompleted ?? this.profileCompleted,
    );
  }
}

/// Keep-alive notifier that owns auth tokens and the authenticated user.
class AppAuth extends Notifier<AppState> {
  AuthTokens? _tokens;

  @override
  AppState build() {
    return const AppState();
  }

  AuthTokens? get currentTokens => _tokens;

  /// Restores a previously persisted session during app startup.
  Future<void> restoreSession() async {
    final tokens = await TokenStorage.instance.read();

    if (tokens == null) {
      _tokens = null;
      state = state.copyWith(status: AuthStatus.unauthenticated, clearUser: true);
      return;
    }

    _tokens = tokens;

    User? user;
    final userJson = UserStorage.instance.read();
    if (userJson != null && userJson.isNotEmpty) {
      try {
        user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }

    state = state.copyWith(status: AuthStatus.authenticated, user: user);
  }

  Future<void> login(LoginResponse response) async {
    _tokens = response.tokens;

    await TokenStorage.instance.write(response.tokens);
    await UserStorage.instance.write(jsonEncode(response.user.toJson()));

    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: response.user,
      profileCompleted: false,
    );
  }

  Future<void> refreshTokens(AuthTokens tokens) async {
    _tokens = tokens;
    await TokenStorage.instance.write(tokens);
  }

  /// Marks the onboarding as finished (owner + carwash profiles exist).
  void completeProfile() {
    state = state.copyWith(profileCompleted: true);
  }

  Future<void> logout() async {
    _tokens = null;
    await TokenStorage.instance.clear();
    await UserStorage.instance.clear();
    state = AppState(
      status: AuthStatus.unauthenticated,
      profileCompleted: false,
    );
  }
}

final appAuthProvider =
    NotifierProvider<AppAuth, AppState>(AppAuth.new);
