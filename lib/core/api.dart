import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// کلاینت HTTP — همان قرارداد سایت پنل کارواش:
///  - توکن Bearer روی همه درخواست‌ها (به‌جز ورود)
///  - تمدید توکن خودکار (single-flight) روی 401 و تکرار درخواست
///  - بازکردن پاکت پاسخ {status_code, message, data} (بعضی اندپوینت‌ها
///    بدنه‌ی خام برمی‌گردانند — هر دو حالت پشتیبانی می‌شود)
///  - تشخیص خودکار HTTPS/HTTP برای سرور (اگر سرور گواهی SSL نداشته باشد
///    خودش به HTTP برمی‌گردد و انتخابش را برای اجراهای بعدی یاد می‌گیرد)
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, List<String>>? fieldErrors;

  const ApiException(this.message, {this.statusCode = 0, this.fieldErrors});

  @override
  String toString() => message;
}

/// رابط کوچک تا api.dart به session.dart وابسته‌ی چرخه‌ای نباشد
abstract class SessionStoreRef {
  String? get accessToken;
  String? get refreshToken;

  Future<void> updateAccessToken(String access);

  Future<void> onSessionExpired();
}

class Api {
  static Dio? _dio;
  static SessionStoreRef? _session;
  static Future<String?>? _refreshing;

  /// آدرس بک‌اند — سرور اصلی: api.mashinow.ir
  /// (قابل‌تغییر هنگام بیلد: --dart-define=MASHINOW_API_BASE_URL=http://... )
  static const String apiBase = String.fromEnvironment(
    'MASHINOW_API_BASE_URL',
    defaultValue: 'https://api.mashinow.ir',
  );

  /// کلید ذخیره‌ی انتخاب پروتکل (HTTPS یا HTTP) برای این دامنه
  static String get _schemeKey => 'api_scheme::${apiBase.replaceFirst(RegExp(r'^https?://'), '')}';

  /// آدرس فعال — شاید وسط اجرا از HTTPS به HTTP سوییچ شده باشد
  static String _activeBase = apiBase;

  static Dio get dio => _dio ??= _buildDio();

  /// Future ای که وقتی «بازیابی پروتکل ذخیره‌شده» تمام شود کامل می‌شود.
  /// session.load() قبل از اولین درخواست صبر می‌کند تا رقابت HTTP/HTTPS
  /// پیش نیاید.
  static Future<void>? _schemeRestoreFuture;

  static Future<void> get schemeReady async {
    final Future<void>? f = _schemeRestoreFuture;
    if (f != null) {
      try {
        await f;
      } catch (_) {}
    }
  }

  static void init(SessionStoreRef session) {
    _session = session;
    _dio = _buildDio();
    _schemeRestoreFuture = _restoreScheme();
  }

  /// اگر اجرای قبلی اپ تشخیص داده بود که سرور فقط HTTP جواب می‌دهد،
  /// همان را از ابتدا اعمال می‌کنیم (تا تأخیر اولین درخواست کم شود)
  static Future<void> _restoreScheme() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(_schemeKey);
      if (saved == 'http' && _activeBase.startsWith('https://')) {
        _switchToHttp();
      }
    } catch (_) {}
  }

  static void _switchToHttp() {
    _activeBase = _activeBase.replaceFirst('https://', 'http://');
    _dio = _buildDio();
  }

  static Future<void> _rememberScheme(String base) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _schemeKey,
        base.startsWith('https://') ? 'https' : 'http',
      );
    } catch (_) {}
  }

  static Dio _buildDio() {
    final Dio d = Dio(
      BaseOptions(
        baseUrl: '$_activeBase/api',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
    );

    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final String? token = _session?.accessToken;
          if (token != null && !options.path.contains('token/refresh')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // :: تشخیص پروتکل — اگر HTTPS به سرور نرسید (گواهی نیست/فیلتر/...)
          //    یک‌بار خودکار با HTTP امتحان می‌کنیم؛ اگر آن هم نشد، خطای اصلی
          //    به کاربر می‌رسد. کدهای وضعیت (400/401/404/...) اصلاً این مسیر
          //    را طی نمی‌کنند — فقط خطاهای «اتصال».
          final bool connectionLevelFailure =
              error.type == DioExceptionType.connectionError ||
                  error.type == DioExceptionType.badCertificate ||
                  error.type == DioExceptionType.connectionTimeout;

          final RequestOptions req = error.requestOptions;

          if (connectionLevelFailure &&
              _activeBase.startsWith('https://') &&
              req.extra['schemeFallback'] != true) {
            try {
              _switchToHttp();

              final RequestOptions retry = req.copyWith(
                baseUrl: '$_activeBase/api',
                extra: <String, dynamic>{...req.extra, 'schemeFallback': true},
              );

              if (_session?.accessToken != null &&
                  !retry.path.contains('token/refresh')) {
                retry.headers['Authorization'] =
                    'Bearer ${_session?.accessToken}';
              }

              final Response response = await Dio(BaseOptions(
                baseUrl: '$_activeBase/api',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              )).fetch(retry);

              await _rememberScheme(_activeBase);
              handler.resolve(response);
              return;
            } catch (_) {
              // HTTP هم جواب نداد — خطای اصلی را عبور بده
            }
          }

          final int? status = error.response?.statusCode;

          // فقط 401 ناشی از انقضای توکن؛ خطای ورود خودش 400 است
          if (status != 401 ||
              req.path.contains('token/refresh') ||
              req.extra['retried'] == true) {
            handler.next(error);
            return;
          }

          try {
            final bool ok = await _refreshToken();
            if (!ok) {
              await _session?.onSessionExpired();
              handler.next(error);
              return;
            }

            final RequestOptions options = req;
            options.extra['retried'] = true;
            options.baseUrl = '$_activeBase/api';
            options.headers['Authorization'] = 'Bearer ${_session?.accessToken}';

            final Response retry = await Dio(BaseOptions(
              baseUrl: '$_activeBase/api',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            )).fetch(options);

            handler.resolve(retry);
          } catch (_) {
            await _session?.onSessionExpired();
            handler.next(error);
          }
        },
      ),
    );

    return d;
  }

  static Future<bool> _refreshToken() async {
    // چند درخواست هم‌زمان → یک تمدید مشترک
    _refreshing ??= _doRefresh();

    try {
      final String? access = await _refreshing;
      return access != null;
    } finally {
      _refreshing = null;
    }
  }

  static Future<String?> _doRefresh() async {
    final String? refresh = _session?.refreshToken;
    if (refresh == null) return null;

    try {
      final Response response = await Dio(
        BaseOptions(
          baseUrl: '$_activeBase/api',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      ).post(
        '/accounts/mobile/token/refresh/',
        data: {'refresh': refresh},
      );

      final dynamic body = response.data;
      final dynamic data = body is Map<String, dynamic> ? body['data'] : null;
      final String? access =
          data is Map<String, dynamic> ? data['access'] as String? : null;

      if (access != null) {
        await _session?.updateAccessToken(access);
      }

      return access;
    } catch (_) {
      return null;
    }
  }

  // :: درخواست‌ها — خروجی همیشه «داخل پاکت» (data) است

  static Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return _run(() => dio.get(path, queryParameters: query));
  }

  static Future<dynamic> post(String path, {dynamic data}) async {
    return _run(() => dio.post(path, data: data));
  }

  static Future<dynamic> put(String path, {dynamic data}) async {
    return _run(() => dio.put(path, data: data));
  }

  static Future<dynamic> patch(String path, {dynamic data}) async {
    return _run(() => dio.patch(path, data: data));
  }

  static Future<dynamic> _run(Future<Response> Function() call) async {
    try {
      final Response response = await call();
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// درخواست با فرم چندبخشی (عکس‌های ثبت‌نام)
  static Future<dynamic> postForm(String path, FormData formData) async {
    try {
      final Response response = await dio.post(path, data: formData);
      return _unwrap(response.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// اگر بدنه پاکت استاندارد {status_code|message, data} باشد داخلش را
  /// برمی‌گرداند؛ وگرنه خود بدنه (آرایه/آبجکت خام) برگردانده می‌شود.
  static dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> &&
        body.containsKey('data') &&
        (body.containsKey('status_code') || body.containsKey('message'))) {
      return body['data'];
    }

    return body;
  }

  static ApiException _toApiException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const ApiException('سرور پاسخ نمی‌دهد؛ دوباره تلاش کنید');
    }

    if (e.type == DioExceptionType.connectionError) {
      return const ApiException(
        'اتصال به سرور برقرار نشد؛ اینترنت خود را بررسی کنید',
      );
    }

    if (e.type == DioExceptionType.badCertificate) {
      return const ApiException('اتصال امن به سرور برقرار نشد');
    }

    final Response? response = e.response;
    final int status = response?.statusCode ?? 0;
    final dynamic body = response?.data;

    String message = 'مشکلی پیش آمد؛ دوباره تلاش کنید';
    Map<String, List<String>>? fieldErrors;
    // آیا پیام واقعی از پاسخ سرور درآمد؟ اگر نه (بدنه HTML/خالی — مثلاً
    // خطای فایروال/وب‌سرور قبل از رسیدن به جنگو) کد وضعیت را ضمیمه می‌کنیم
    // تا علت از دست نرود: 403 = فایروال، 502/504 = وب‌سرور پایین، و غیره.
    bool fromServer = false;

    if (body is Map<String, dynamic>) {
      final dynamic dataField = body['data'];
      final dynamic messageField = body['message'];
      final dynamic detailField = body['detail'];
      final dynamic nonField = body['non_field_errors'];

      if (messageField is String && messageField.isNotEmpty) {
        message = messageField;
        fromServer = true;
      } else if (detailField is String && detailField.isNotEmpty) {
        message = detailField;
        fromServer = true;
      } else if (nonField is List && nonField.isNotEmpty) {
        message = nonField.join(' ');
        fromServer = true;
      } else if (dataField is Map<String, dynamic>) {
        // خطای اعتبارسنجی داخل data
        fieldErrors = _extractFieldErrors(dataField);
        if (fieldErrors.isNotEmpty) {
          message = fieldErrors.values.first.first;
          fromServer = true;
        }
      } else {
        fieldErrors = _extractFieldErrors(body);
        if (fieldErrors.isNotEmpty) {
          message = fieldErrors.values.first.first;
          fromServer = true;
        }
      }

      if (status == 401) {
        message = 'نشست شما منقضی شده است؛ دوباره وارد شوید';
        fromServer = true;
      }
    }

    if (!fromServer && status > 0) {
      message = 'مشکلی پیش آمد (خطای سرور $status)؛ دوباره تلاش کنید';
    }

    return ApiException(message, statusCode: status, fieldErrors: fieldErrors);
  }

  static Map<String, List<String>> _extractFieldErrors(
    Map<String, dynamic> body,
  ) {
    final Map<String, List<String>> out = <String, List<String>>{};

    for (final MapEntry<String, dynamic> entry in body.entries) {
      final dynamic value = entry.value;
      if (value is List && value.isNotEmpty) {
        out[entry.key] = value.map((e) => e.toString()).toList();
      } else if (value is String && value.isNotEmpty) {
        out[entry.key] = [value];
      }
    }

    return out;
  }
}
