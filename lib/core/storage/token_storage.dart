import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mashinow_washer/core/models/auth_tokens.dart';
import 'package:mashinow_washer/core/storage/local_storage.dart';

/// Stores auth tokens in platform secure storage (Keystore / Keychain).
class TokenStorage {
  TokenStorage._();

  static final TokenStorage instance = TokenStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _accessKey = 'mashinow.washer.access';
  static const _refreshKey = 'mashinow.washer.refresh';

  Future<AuthTokens?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);

    if (access == null || refresh == null || access.isEmpty) return null;

    return AuthTokens(access: access, refresh: refresh);
  }

  Future<void> write(AuthTokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.access);
    await _storage.write(key: _refreshKey, value: tokens.refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// Persists the authenticated user profile JSON.
class UserStorage {
  UserStorage._();

  static final UserStorage instance = UserStorage._();

  static const _userKey = 'mashinow.washer.user';

  String? read() => LocalStorage.instance.getString(_userKey);

  Future<void> write(String userJson) =>
      LocalStorage.instance.setString(_userKey, userJson);

  Future<void> clear() => LocalStorage.instance.remove(_userKey);
}
