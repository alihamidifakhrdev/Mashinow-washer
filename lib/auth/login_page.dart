import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// ورود کارواش‌دار — دو مرحله: شماره موبایل → کد تایید.
///
/// محتوا وسط صفحه قرار دارد (نه چسبیده به بالا). جریان کد تایید دقیقاً
/// مثل اپ اصلی کاربر است: درخواست «ارسال کد» به همان اندپوینت پیامکی
/// سایت/اپ زده می‌شود و اگر درگاه پیامک فعال باشد کد پیامک می‌شود.
/// تا وقتی درگاه روی بک‌اند فعال نشده، سرور کد را داخل پاسخ هم برمی‌گرداند؛
/// در آن حالت باکس‌ها خودکار پر و «ورود» خودکار زده می‌شود (مثل اپ اصلی).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _codeControllers =
      List<TextEditingController>.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _codeFocus =
      List<FocusNode>.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _codeSent = false;
  String? _serverCode;
  String? _phoneError;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  SessionStore get _session => SessionScope.of(context);

  @override
  void dispose() {
    _phoneController.dispose();
    for (final TextEditingController c in _codeControllers) {
      c.dispose();
    }
    for (final FocusNode f in _codeFocus) {
      f.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  String get _phone => normalizeDigits(_phoneController.text).trim();

  String get _code =>
      _codeControllers.map((TextEditingController c) => c.text).join();

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 72);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _sendCode({bool isResend = false}) async {
    final String phone = _phone;

    if (phone.length != 11 || !phone.startsWith('09')) {
      setState(() => _phoneError = 'شماره موبایل معتبر نیست (مثال: 09123456789)');
      return;
    }

    setState(() {
      _phoneError = null;
      _loading = true;
    });

    try {
      final dynamic data = await Api.post(
        '/accounts/send-code/',
        data: <String, dynamic>{'phone_number': phone, 'role': 'carwash'},
      );

      if (!mounted) return;

      String? serverCode;
      if (data is Map<String, dynamic>) {
        final dynamic code = data['code'];
        if (code is String && code.isNotEmpty) {
          serverCode = code;
        } else if (code is num) {
          serverCode = code.toString();
        }
      }

      setState(() {
        _loading = false;
        _codeSent = true;
        _serverCode = serverCode;
      });

      // باکس‌های کد را با کد سرور (اگر برگشته) پر کن و مثل اپ اصلی
      // خودکار بررسی کن — وقتی درگاه پیامک واقعی وصل شود کد در پاسخ
      // نیست، این بخش خودبه‌خود بی‌اثر می‌شود و کاربر کد پیامکی را وارد می‌کند
      if (serverCode != null) {
        _fillCode(serverCode);
        _verifyCode();
        return;
      }

      _startResendCooldown();

      if (!isResend) {
        FocusScope.of(context).requestFocus(_codeFocus.first);
      }

      showToast(context, 'کد تایید پیامک شد');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, e.message, error: true);
    }
  }

  void _fillCode(String code) {
    // کد ممکن است با ارقام فارسی تایپ/پیست شده باشد → لاتین می‌شود
    final List<String> digits = normalizeDigits(code).split('');

    for (int i = 0; i < _codeControllers.length; i++) {
      _codeControllers[i].text = i < digits.length ? digits[i] : '';
    }
  }

  Future<void> _verifyCode() async {
    if (_code.length != 6) {
      showToast(context, 'کد ۶ رقمی را کامل وارد کنید', error: true);
      return;
    }

    // نشست را قبل از هر await می‌گیریم تا بعد از بازگشت، context معتبر باشد
    final SessionStore session = _session;

    setState(() => _loading = true);

    try {
      final dynamic data = await Api.post(
        '/accounts/mobile/verify-code/',
        data: <String, dynamic>{'phone_number': _phone, 'code': _code},
      );

      final String? access;
      final String? refresh;

      if (data is Map<String, dynamic>) {
        access = data['access'] as String?;
        refresh = data['refresh'] as String?;
      } else {
        access = null;
        refresh = null;
      }

      if (access == null || refresh == null) {
        throw const ApiException('پاسخ ورود نامعتبر بود');
      }

      await session.saveTokens(access, refresh);
      await session.refreshProfileStatus();

      // AppGate با نوتیفای نشست، خودش مسیر را عوض می‌کند
      session.notifyUI();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      final Map<String, List<String>>? fields = e.fieldErrors;
      if (e.statusCode == 400 || (fields != null && fields.isNotEmpty)) {
        showToast(context, 'کد تایید درست نیست', error: true);
      } else {
        showToast(context, e.message, error: true);
      }
    }
  }

  void _onCodeChanged(int index, String value) {
    if (value.length > 1) {
      // paste یا autofill — همه را پخش کن
      _fillCode(value);
      FocusScope.of(context).requestFocus(_codeFocus.last);
      return;
    }

    if (value.isNotEmpty && index < 5) {
      FocusScope.of(context).requestFocus(_codeFocus[index + 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      glyph: Icons.local_car_wash_rounded,
      // لهجه آبی برند — لاگین ورودی اصلی ماشینو است
      glyphColor: AppColors.blue,
      glyphTint: AppColors.blueTint(),
      title: 'کارواش ماشینو',
      subtitle: _codeSent
          ? 'کد ۶ رقمی ارسال‌شده به $_phone را وارد کنید'
          : 'ورود کارواش‌دارها با شماره موبایل',
      appBarLeading: _codeSent
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => setState(() {
                _codeSent = false;
                _serverCode = null;
                _fillCode('');
              }),
            )
          : null,
      footerCaption: 'ماشینو — پنل کارواش‌داران',
      children: <Widget>[
        if (!_codeSent) ...<Widget>[
          PhoneField(controller: _phoneController),
          if (_phoneError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 4),
              child: Text(
                _phoneError!,
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.red,
                ),
              ),
            ),
          const SizedBox(height: 24),
        ] else ...<Widget>[
          _OtpBoxes(
            controllers: _codeControllers,
            focusNodes: _codeFocus,
            onChanged: _onCodeChanged,
          ),
          if (_serverCode != null) ...<Widget>[
            const SizedBox(height: 18),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.blueTint(),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.sms_outlined,
                      size: 18, color: AppColors.blue),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'کد تایید شما: $_serverCode',
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.blueDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تا فعال‌شدن درگاه پیامک، کد تایید همین‌جا هم نمایش داده می‌شود',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.ink3,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _resendButton(),
        ],
      ],
      bottomButton: AppButton(
        text: !_codeSent
            ? 'دریافت کد تایید'
            : 'بررسی کد و ورود به پنل',
        loading: _loading,
        onPressed: _loading ? null : (!_codeSent ? _sendCode : _verifyCode),
      ),
    );
  }

  Widget _resendButton() {
    if (_resendSeconds > 0) {
      return Text(
        'ارسال مجدد کد تا $_resendSeconds ثانیه دیگر',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'IRANYekan',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.ink3,
        ),
      );
    }

    return TextButton(
      onPressed: _loading ? null : () => _sendCode(isResend: true),
      child: Text(
        'ارسال مجدد کد تایید',
        style: TextStyle(
          fontFamily: 'IRANYekan',
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

class _OtpBoxes extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final void Function(int, String) onChanged;

  const _OtpBoxes({
    required this.controllers,
    required this.focusNodes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List<Widget>.generate(controllers.length, (int index) {
          return Container(
            margin: EdgeInsets.symmetric(
              horizontal: index == 0 || index == controllers.length - 1
                  ? 0
                  : 4,
            ),
            width: 48,
            height: 58,
            child: TextField(
              controller: controllers[index],
              focusNode: focusNodes[index],
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              inputFormatters: <TextInputFormatter>[
                SmartDigitsInputFormatter(),
              ],
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: AppColors.fill,
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                  borderSide: const BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                  borderSide:
                      BorderSide(color: AppColors.blue, width: 1.6),
                ),
              ),
              onChanged: (String v) => onChanged(index, v),
            ),
          );
        }),
      ),
    );
  }
}
