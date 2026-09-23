import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/constants/language.dart';
import 'package:mashinow_washer/core/storage/local_storage.dart';

class AppSettings extends Notifier<ThemeMode> {
  static const _key = 'mashinow.washer.themeMode';

  @override
  ThemeMode build() {
    final saved = LocalStorage.instance.getString(_key);

    switch (saved) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await LocalStorage.instance.setString(_key, mode.name);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettings, ThemeMode>(AppSettings.new);

/// App-wide immutable descriptors derived from [Language].
final languageProvider = Provider<Language>((ref) => Language.fa);
