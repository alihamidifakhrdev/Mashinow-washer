import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences] with a synchronous in-memory cache.
class LocalStorage {
  LocalStorage._();

  static final LocalStorage instance = LocalStorage._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _requirePrefs {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('LocalStorage not initialized — call init() first');
    }
    return prefs;
  }

  String? getString(String key) => _requirePrefs.getString(key);

  Future<void> setString(String key, String value) =>
      _requirePrefs.setString(key, value);

  bool getBool(String key, {bool defaultValue = false}) =>
      _requirePrefs.getBool(key) ?? defaultValue;

  Future<void> setBool(String key, bool value) =>
      _requirePrefs.setBool(key, value);

  Future<void> remove(String key) => _requirePrefs.remove(key);
}
