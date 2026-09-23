import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// پالت رنگ — روشن و تیره
///
/// آبی برند ماشینو #005AFE → رنگ اصلی و غالب (دکمه‌ها، انتخاب، لینک، تم):
/// سبز #00C290 فقط معنای «موفقیت» دارد (انجام شد، درآمد مثبت، تیک موفقیت).
/// قرمز فقط برای خطا/حذف/لغو است.
class AppPalette {
  final Color accent;
  final Color accentDeep;
  final Color blue;
  final Color blueDeep;
  final Color success;
  final Color successDeep;
  final Color canvas;
  final Color card;
  final Color fill;
  final Color fill2;
  final Color chipSurface;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color red;

  const AppPalette({
    required this.accent,
    required this.accentDeep,
    required this.blue,
    required this.blueDeep,
    required this.success,
    required this.successDeep,
    required this.canvas,
    required this.card,
    required this.fill,
    required this.fill2,
    required this.chipSurface,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.red,
  });

  /// پالت روشن — آبی غالب، سطوح با ته‌مایه آبی
  static const AppPalette light = AppPalette(
    accent: Color(0xFF005AFE),
    accentDeep: Color(0xFF0046C8),
    blue: Color(0xFF005AFE),
    blueDeep: Color(0xFF0046C8),
    success: Color(0xFF00C290),
    successDeep: Color(0xFF008F6E),
    canvas: Color(0xFFF2F6FC),
    card: Color(0xFFFFFFFF),
    fill: Color(0xFFE9F0FB),
    fill2: Color(0xFFDBE4F6),
    chipSurface: Color(0xFFFFFFFF),
    ink: Color(0xFF101A2E),
    ink2: Color(0xFF59647B),
    ink3: Color(0xFF8F9AB2),
    red: Color(0xFFE5484D),
  );

  /// پالت تیره (تم شب) — همان زبان رنگی با روشنایی مناسب نمایش تیره
  static const AppPalette dark = AppPalette(
    accent: Color(0xFF5E86FF),
    accentDeep: Color(0xFFA9BEFF),
    blue: Color(0xFF5E86FF),
    blueDeep: Color(0xFFA9BEFF),
    success: Color(0xFF00D9A0),
    successDeep: Color(0xFF3FE8C0),
    canvas: Color(0xFF0B0F1A),
    card: Color(0xFF121927),
    fill: Color(0xFF1A2233),
    fill2: Color(0xFF242E42),
    chipSurface: Color(0xFF1C2536),
    ink: Color(0xFFE9EEFA),
    ink2: Color(0xFFA3B0CB),
    ink3: Color(0xFF657191),
    red: Color(0xFFFF6B6B),
  );
}

/// دسترسی سراسری به رنگ‌ها — همیشه با تم فعلی (روشن/تیره) همگام است.
///
/// نکته: چون این مقادیر «گتر» هستند (با تغییر تم عوض می‌شوند)، در عبارت‌های
/// const قابل استفاده نیستند — در build به‌صورت عادی خوانده می‌شوند.
class AppColors {
  static bool _dark = false;

  /// فعال/غیرفعال‌سازی پالت تیره — از ریشه‌ی اپ هنگام each build ست می‌شود
  static set dark(bool value) => _dark = value;
  static bool get isDark => _dark;

  static AppPalette get _p => _dark ? AppPalette.dark : AppPalette.light;

  // ── رنگ اصلی و غالب: آبی برند ماشینو (#005AFE) ──
  static Color get accent => _p.accent;
  static Color get accentDeep => _p.accentDeep;

  // ── آبی برند (همان رنگ اقدام) ──
  static Color get blue => _p.blue;
  static Color get blueDeep => _p.blueDeep;

  // ── سبز — فقط معنای موفقیت (انجام شد، درآمد مثبت، تیک موفقیت) ──
  static Color get success => _p.success;
  static Color get successDeep => _p.successDeep;

  // ── سطوح ──
  static Color get canvas => _p.canvas;
  static Color get card => _p.card;
  static Color get fill => _p.fill;
  static Color get fill2 => _p.fill2;

  /// سطح چیپ/قرص‌های غیرفعال (در تم تیره سفید نیست!)
  static Color get chipSurface => _p.chipSurface;

  // ── متن ──
  static Color get ink => _p.ink;
  static Color get ink2 => _p.ink2;
  static Color get ink3 => _p.ink3;

  // ── معنایی ──
  /// فقط خطا / حذف / لغو
  static Color get red => _p.red;

  // ── تینت‌ها ──
  static Color accentTint([double a = 0.12]) => accent.withOpacity(a);
  static Color redTint([double a = 0.12]) => red.withOpacity(a);
  static Color blueTint([double a = 0.12]) => blue.withOpacity(a);
  static Color successTint([double a = 0.12]) => success.withOpacity(a);
}

class AppRadius {
  static const double xl = 28;
  static const double lg = 20;
  static const double md = 14;
  static const double sm = 10;
}

List<BoxShadow> get cardShadow => [
      BoxShadow(
        color: const Color(0xFF0A1128).withOpacity(AppColors.isDark ? 0.28 : 0.04),
        blurRadius: 12,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: const Color(0xFF0A1128).withOpacity(AppColors.isDark ? 0.40 : 0.10),
        blurRadius: 28,
        offset: const Offset(0, 10),
        spreadRadius: -8,
      ),
    ];

List<BoxShadow> get buttonShadow => [
      BoxShadow(
        color: AppColors.accent.withOpacity(0.40),
        blurRadius: 20,
        offset: const Offset(0, 8),
        spreadRadius: -6,
      ),
    ];

/// کنترلر تم اپ — سیستم / روشن / شب، ذخیره‌شده بین اجراها
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  static const String _prefsKey = 'theme_mode';

  ThemeMode get mode => _mode;

  String get modeLabel {
    switch (_mode) {
      case ThemeMode.light:
        return 'روشن';
      case ThemeMode.dark:
        return 'شب';
      default:
        return 'سیستم';
    }
  }

  /// بارگذاری انتخاب کاربر (اجرای اول اپ)
  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(_prefsKey);

      switch (saved) {
        case 'light':
          _mode = ThemeMode.light;
        case 'dark':
          _mode = ThemeMode.dark;
        default:
          _mode = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode value) async {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, value.name);
    } catch (_) {}
  }

  /// سیستم ← روشن ← شب ← سیستم
  Future<void> cycle() async {
    switch (_mode) {
      case ThemeMode.system:
        await setMode(ThemeMode.light);
      case ThemeMode.light:
        await setMode(ThemeMode.dark);
      case ThemeMode.dark:
        await setMode(ThemeMode.system);
    }
  }
}

/// نمونه‌ی سراسری کنترلر تم — از ریشه‌ی اپ و صفحه‌ی «تنظیمات» استفاده می‌شود
final ThemeController appTheme = ThemeController();

ThemeData buildAppTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  final AppPalette p = dark ? AppPalette.dark : AppPalette.light;

  final ThemeData base = dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);

  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'IRANYekan'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'IRANYekan'),
    scaffoldBackgroundColor: p.canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: p.accent,
      secondary: p.accent,
      surface: p.card,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: p.ink,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF242E42) : p.ink,
      contentTextStyle: TextStyle(
        fontFamily: 'IRANYekan',
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.fill2, thickness: 1),
  );
}
