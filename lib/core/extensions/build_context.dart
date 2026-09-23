import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension BuildContextExtension on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get types => Theme.of(this).textTheme;

  TextDirection get textDirection => Directionality.of(this);

  MediaQueryData get mediaQuery => MediaQuery.of(this);

  Size get screenSize => mediaQuery.size;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  void back<T extends Object?>({T? result}) {
    try {
      pop(result);
    } catch (error) {
      debugPrint(error.toString());
    }
  }
}
