import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth/login_page.dart';
import 'core/api.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'core/theme_reveal.dart';
import 'core/ui.dart';
import 'home/shell.dart';
import 'onboarding/carwash_page.dart';
import 'onboarding/hours_page.dart';
import 'onboarding/owner_profile_page.dart';
import 'onboarding/services_page.dart';

class MashinowCarwashApp extends StatefulWidget {
  const MashinowCarwashApp({super.key});

  @override
  State<MashinowCarwashApp> createState() => _MashinowCarwashAppState();
}

class _MashinowCarwashAppState extends State<MashinowCarwashApp> {
  late final SessionStore session;
  bool bootstrapped = false;

  @override
  void initState() {
    super.initState();

    session = SessionStore();
    Api.init(session);

    Future.wait(<Future<void>>[
      appTheme.load(),
      session.load(),
    ]).whenComplete(() {
      if (mounted) setState(() => bootstrapped = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // با تغییر حالت تم (سیستم/روشن/شب) کل MaterialApp از نو ساخته می‌شود
    return ListenableBuilder(
      listenable: appTheme,
      builder: (BuildContext context, Widget? _) {
        return MaterialApp(
          title: 'کارواش ماشینو',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: appTheme.mode,
          // تم باید «لحظه‌ای» عوض شود تا افشای دایره‌ای ThemeReveal خالص
          // دیده شود (کراس‌فید پیش‌فرض متریال با آن تداخل می‌کرد)
          themeAnimationDuration: Duration.zero,
          builder: (BuildContext context, Widget? child) {
            // پالت رنگی (روشن/تیره) را با تم فعلی همگام می‌کنیم.
            // MediaQuery در همین نقطه در دسترس است و با تغییر روشنایی سیستم
            // این builder دوباره اجرا می‌شود.
            final Brightness platform =
                MediaQuery.of(context).platformBrightness;
            final bool dark = appTheme.mode == ThemeMode.dark ||
                (appTheme.mode == ThemeMode.system &&
                    platform == Brightness.dark);
            AppColors.dark = dark;

            // ⚠️ ThemeReveal برای انیمیشن تغییر تم از این RepaintBoundary
            // عکس می‌گیرد — بیرونی‌ترین لایه تا کل صفحه (حتی دیالوگ‌ها) بگیرد
            return RepaintBoundary(
              key: ThemeReveal.boundaryKey,
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness:
                      dark ? Brightness.light : Brightness.dark,
                  statusBarBrightness:
                      dark ? Brightness.dark : Brightness.light,
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  // ⚠️ SessionScope باید «بالای» Navigator باشد تا صفحات
                  // push شده (مثل ویرایش زمان‌های کاری) هم به نشست دسترسی
                  // داشته باشند — دقیقاً علت کرش قبلی اینجا بود.
                  child: SessionScope(
                    notifier: session,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
          home: !bootstrapped ? const _SplashScreen() : const AppGate(),
        );
      },
    );
  }
}

/// دروازه‌ی مسیر — بر اساس نشست تصمیم می‌گیرد کدام صفحه نشان داده شود:
/// ورود / مراحل ثبت / پنل اصلی
///
/// داخل ListenableBuilder روی تم است تا تغییر تم (حتی از سیستم) همان لحظه
/// روی همه‌ی صفحات ریشه اعمال شود (آبجکت‌های const دوباره build نمی‌شوند!).
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionStore session = SessionScope.of(context);

    return ListenableBuilder(
      listenable: appTheme,
      builder: (BuildContext context, Widget? _) => _screenFor(session),
    );
  }

  Widget _screenFor(SessionStore session) {
    if (!session.isLoggedIn) {
      return LoginPage();
    }

    // توکن هست ولی وضعیت پروفایل هنوز نیامده:
    //  - در حال بارگذاری → اسپلش
    //  - خطا → صفحه‌ی خطا با دکمه تلاش مجدد (قبلاً اینجا برای همیشه روی
    //    اسپلش گیر می‌کرد و اپ «بالا نمی‌آمد»)
    if (session.profileStatus == null) {
      if (session.bootError != null) {
        return _BootErrorScreen(message: session.bootError!);
      }
      return const _SplashScreen();
    }

    // این اپ فقط برای نقش کارواش است
    if (session.profileStatus!.role != 'carwash') {
      return const _WrongRoleScreen();
    }

    final String? step = session.pendingStep;

    if (step == null) {
      return HomeShell();
    }

    switch (step) {
      case 'waiting_for_profile_data':
        return CarwashRegisterPage();
      case 'waiting_for_owner_profile':
        return OwnerProfilePage();
      case 'waiting_for_services':
        return ServicesSetupPage();
      case 'waiting_for_timeslots':
        return WorkingHoursPage();
      default:
        // نقش یا مرحله‌ی ناشناخته — اگر نقش مشتری بود پیام مناسب بده
        return const _WrongRoleScreen();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // آبی برند ماشینو (#005AFE) — رنگ اصلی کل اپ
      backgroundColor: AppColors.blue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.local_car_wash_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'کارواش ماشینو',
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'پنل مدیریت کارواش‌داران',
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// خطای بوت — وقتی توکن هست ولی وضعیت پروفایل گرفته نشده (قطعی اینترنت و...)
class _BootErrorScreen extends StatelessWidget {
  final String message;

  const _BootErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    final SessionStore session = SessionScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.accentTint(),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(Icons.wifi_off_rounded,
                      color: AppColors.accent, size: 34),
                ),
                const SizedBox(height: 20),
                Text(
                  'اتصال به سرور برقرار نشد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink2,
                    height: 1.9,
                  ),
                ),
                const SizedBox(height: 28),
                AppButton(
                  text: 'تلاش مجدد',
                  icon: Icons.refresh_rounded,
                  onPressed: () => session.retryBoot(),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => session.logout(),
                  child: Text(
                    'خروج از حساب',
                    style: TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WrongRoleScreen extends StatelessWidget {
  const _WrongRoleScreen();

  @override
  Widget build(BuildContext context) {
    final SessionStore session = SessionScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.info_outline_rounded,
                  size: 56, color: AppColors.ink3),
              const SizedBox(height: 16),
              Text(
                'این شماره به حساب مشتری ثبت شده است',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'برای ورود به پنل کارواش، با شماره‌ای وارد شوید که نقش کارواش دارد.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink2,
                  height: 1.9,
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'خروج از حساب',
                type: AppButtonType.danger,
                onPressed: () => session.logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
