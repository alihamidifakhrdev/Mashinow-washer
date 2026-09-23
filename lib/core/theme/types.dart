import 'package:flutter/material.dart';

class Types {
  // :: Display
  static const TextStyle displayLarge = TextStyle(
    fontWeight: FontWeight.w300,
    fontSize: 57,
  );
  static const TextStyle displayMedium = TextStyle(
    fontWeight: FontWeight.w300,
    fontSize: 45,
  );
  static const TextStyle displaySmall = TextStyle(
    fontWeight: FontWeight.w300,
    fontSize: 36,
  );

  // :: Headline
  static const TextStyle headlineLarge = TextStyle(
    fontWeight: FontWeight.w300,
    fontSize: 32,
  );
  static const TextStyle headlineMedium = TextStyle(
    fontWeight: FontWeight.w300,
    fontSize: 28,
  );
  static const TextStyle headlineSmall = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 24,
  );

  // :: Title
  static const TextStyle titleLarge = TextStyle(
    fontWeight: FontWeight.w300,
    fontSize: 22,
  );
  static const TextStyle titleMedium = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 16,
  );
  static const TextStyle titleSmall = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 14,
  );

  // :: Label
  static const TextStyle labelLarge = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 14,
  );
  static const TextStyle labelMedium = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 12,
  );
  static const TextStyle labelSmall = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 11,
  );

  // :: Body
  static const TextStyle bodyLarge = TextStyle(
    fontWeight: FontWeight.w300,
    fontSize: 16,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontWeight: FontWeight.w300,
    fontSize: 14,
  );
  static const TextStyle bodySmall = TextStyle(
    fontWeight: FontWeight.w300,
    fontSize: 12,
  );

  static TextTheme get textTheme => const TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
  );
}
