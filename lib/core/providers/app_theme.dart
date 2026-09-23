import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/constants/language.dart';
import 'package:mashinow_washer/core/providers/app_settings.dart';
import 'package:mashinow_washer/core/theme/colors.dart';
import 'package:mashinow_washer/core/theme/types.dart';

class AppTheme {
  final Language language;

  const AppTheme({required this.language});

  ThemeData _getThemeData(ColorScheme colorScheme) => ThemeData(
        useMaterial3: true,
        fontFamily: language.fontFamily,
        brightness: colorScheme.brightness,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.surface,
        canvasColor: colorScheme.surface,
        textTheme: Types.textTheme.apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        ),
      );

  ThemeData get light => _getThemeData(AppColorScheme.light);

  ThemeData get dark => _getThemeData(AppColorScheme.dark);
}

final appThemeProvider = Provider<AppTheme>((ref) {
  final language = ref.watch(languageProvider);
  return AppTheme(language: language);
});
