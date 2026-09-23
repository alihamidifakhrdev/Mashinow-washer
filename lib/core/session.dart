import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

/// وضعیت نشست: توکن‌ها + مرحله‌ی ثبت‌نام کارواش.
///
/// کل اپ از طریق [SessionScope] (در ui.dart) به این نمونه گوش می‌دهد؛ هر
/// تغییر (ورود، خروج، تغییر مرحله) نوتیفای می‌شود و AppGate مسیر عوض می‌کند.
class SessionStore extends ChangeNotifier implements SessionStoreRef {
  String? accessToken;
  String? refreshToken;
  ProfileStatus? profileStatus;

  /// وضعیت بوت: در حال بارگذاری؟ خطا؟ (برای صفحه‌ی تلاش مجدد در AppGate)
  bool bootLoading = false;
  String? bootError;

  bool get isLoggedIn => accessToken != null;

  bool get isCompleted => profileStatus?.completed == true;

  /// مرحله‌ی بعدی ثبت — null یعنی کامل است یا هنوز وضعیت نیامده
  String? get pendingStep {
    final ProfileStatus? s = profileStatus;
    if (s == null || s.completed) return null;
    return s.step;
  }

  /// بارگذاری توکن‌های ذخیره‌شده (اجرای اول اپ)
  ///
  /// اگر گرفتن وضعیت پروفایل به خطا خورد (قطعی اینترنت و...) در
  /// [bootError] ثبت می‌شود تا AppGate صفحه‌ی «تلاش مجدد» نشان بدهد —
  /// قبلاً این حالت اپ را برای همیشه روی اسپلش گیر می‌انداخت.
  Future<void> load() async {
    bootLoading = true;
    notifyListeners();

    try {
      // اول مطمئن شویم بازیابی پروتکل (HTTP/HTTPS) تمام شده تا درخواست
      // اول با آدرس اشتباه نرود
      await Api.schemeReady;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      accessToken = prefs.getString('access_token');
      refreshToken = prefs.getString('refresh_token');

      if (accessToken != null) {
        final bool ok = await refreshProfileStatus();
        bootError = ok
            ? null
            : (bootError ?? 'وضعیت حساب دریافت نشد؛ اینترنت خود را بررسی کنید.');
      } else {
        bootError = null;
      }
    } catch (_) {
      bootError ??= 'اتصال به سرور برقرار نشد؛ اینترنت خود را بررسی کنید.';
    } finally {
      bootLoading = false;
      notifyListeners();
    }
  }

  /// تلاش دوباره برای بوت (دکمه «تلاش مجدد»)
  Future<void> retryBoot() => load();

  Future<void> saveTokens(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
    bootError = null;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  Future<void> updateAccessToken(String access) async {
    accessToken = access;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
  }

  @override
  Future<void> onSessionExpired() => logout();

  /// اطلاع‌رسانی تغییر به UI از بیرون کلاس (notifyListeners محافظت‌شده است)
  void notifyUI() => notifyListeners();

  /// گرفتن وضعیت پروفایل و هدایت به مرحله بعد ثبت‌نام
  /// خروجی: آیا موفق بود؟
  Future<bool> refreshProfileStatus() async {
    try {
      final dynamic data = await Api.get('/status/profile-status/');
      if (data is Map<String, dynamic>) {
        profileStatus = ProfileStatus.fromJson(data);
        return true;
      }
      return false;
    } on ApiException catch (e) {
      // 401 یعنی نشست از سمت سرور باطل شده — refresh هم قبلا شکست خورده
      if (e.statusCode == 401) {
        await logout();
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    accessToken = null;
    refreshToken = null;
    profileStatus = null;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');

    notifyListeners();
  }
}
