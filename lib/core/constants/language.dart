import 'package:flutter/material.dart' show Locale;

enum Language {
  fa(Locale('fa', 'IR'), 'Vazirmatn');

  final Locale locale;
  final String fontFamily;

  const Language(this.locale, this.fontFamily);

  factory Language.from(String? key) {
    return Language.values.firstWhere(
      (language) => language.name == key,
      orElse: () => Language.fa,
    );
  }
}
