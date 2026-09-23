import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/constants/common_values.dart';
import 'package:mashinow_washer/core/constants/drawables.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/core/extensions/string.dart';
import 'package:mashinow_washer/core/network/server_error.dart';
import 'package:mashinow_washer/core/presentation/widgets/button.dart';
import 'package:mashinow_washer/core/presentation/widgets/text_field.dart';
import 'package:mashinow_washer/core/presentation/widgets/toast.dart';
import 'package:mashinow_washer/core/providers/app_auth.dart';
import 'package:mashinow_washer/features/auth/auth_repository.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';

enum _LoginStep { phone, code }

/// Two-step login: phone number → OTP verification code.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _phoneFormKey = GlobalKey();
  final GlobalKey<FormState> _codeFormKey = GlobalKey();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  final ButtonController _sendCodeButton = ButtonController();
  final ButtonController _verifyButton = ButtonController();

  _LoginStep _step = _LoginStep.phone;

  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = CommonValues.resendCodeTimeoutSeconds);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _sendCode() async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;

    _sendCodeButton.setLoading();

    final repository = ref.read(authRepositoryProvider);

    try {
      await repository.sendCode(_phoneController.text.trim().toEnglishDigits());
      _sendCodeButton.setSuccess();

      if (mounted) {
        setState(() {
          _step = _LoginStep.code;
          _codeController.clear();
        });
        _startResendTimer();
        Toast.success(context, title: 'کد تایید ارسال شد');
      }
    } catch (error) {
      _sendCodeButton.reset();
      if (mounted) {
        Toast.error(
          context,
          title: 'خطا در ارسال کد',
          description: error is ServerError ? error.message : error.toString(),
        );
      }
    }
  }

  Future<void> _verifyCode() async {
    if (!(_codeFormKey.currentState?.validate() ?? false)) return;

    _verifyButton.setLoading();

    final repository = ref.read(authRepositoryProvider);
    final auth = ref.read(appAuthProvider.notifier);

    try {
      final result = await repository.verifyCode(
        _phoneController.text.trim().toEnglishDigits(),
        _codeController.text.trim().toEnglishDigits(),
      );

      await auth.login(result);

      // Check whether the washer already finished registration; the router
      // redirect then routes to /main or /onboarding accordingly.
      try {
        await ref.read(profileStatusProvider.future);
      } catch (_) {/* onboarding will handle */ }

      _verifyButton.setSuccess();

      if (mounted) {
        final completed = ref.read(appAuthProvider).profileCompleted;
        context.go(completed ? '/main' : '/onboarding');
      }
    } catch (error) {
      _verifyButton.reset();
      if (mounted) {
        Toast.error(
          context,
          title: 'کد تایید نشد',
          description: error is ServerError ? error.message : error.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;
    final isDark = context.isDarkMode;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),

                    // :: LOGO
                    Center(
                      child: Image.asset(
                        isDark
                            ? Drawables.imageLogoTypeDark
                            : Drawables.imageLogoTypeLight,
                        width: 190,
                      ),
                    ),

                    const SizedBox(height: 28),
                    Text(
                      _step == _LoginStep.phone
                          ? 'ورود کارواش‌دار'
                          : 'کد تایید را وارد کنید',
                      textAlign: TextAlign.center,
                      style: types.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _step == _LoginStep.phone
                          ? 'شماره موبایل خود را وارد کنید تا کد تایید برایتان ارسال شود'
                          : 'کد ۵ رقمی ارسال‌شده به ${_phoneController.text} را وارد کنید',
                      textAlign: TextAlign.center,
                      style: types.bodyMedium?.copyWith(color: colors.outline),
                    ),

                    const SizedBox(height: 36),

                    if (_step == _LoginStep.phone) ...[
                      // :: STEP 1 — PHONE NUMBER
                      Form(
                        key: _phoneFormKey,
                        child: AppTextField(
                          controller: _phoneController,
                          label: 'شماره موبایل',
                          hint: '۰۹۱۲۳۴۵۶۷۸۹',
                          type: AppTextFieldType.phone,
                          icon: Icons.phone_iphone_rounded,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _sendCode(),
                          validator: (value) {
                            final text = value?.trim().toEnglishDigits() ?? '';
                            if (text.isEmpty) return 'شماره موبایل را وارد کنید';
                            if (!RegExp(r'^09\d{9}$').hasMatch(text)) {
                              return 'شماره موبایل باید با ۰۹ شروع شده و ۱۱ رقم باشد';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'دریافت کد تایید',
                        icon: Icons.sms_rounded,
                        controller: _sendCodeButton,
                        onPressed: _sendCode,
                      ),
                    ] else ...[
                      // :: STEP 2 — VERIFICATION CODE
                      Form(
                        key: _codeFormKey,
                        child: AppTextField(
                          controller: _codeController,
                          label: 'کد تایید',
                          hint: '— — — — — —',
                          icon: Icons.password_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (value) {
                            if (value.trim().toEnglishDigits().length == 6) {
                              _verifyCode();
                            }
                          },
                          validator: (value) {
                            final text = value?.trim().toEnglishDigits() ?? '';
                            if (text.isEmpty) return 'کد تایید را وارد کنید';
                            if (text.length != 6) return 'کد تایید ۶ رقم است';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _resendSeconds > 0
                            ? 'ارسال مجدد کد تا ${_resendSeconds.toString().toPersianDigits()} ثانیه دیگر'
                            : 'کد جدیدی دریافت نکردید؟',
                        textAlign: TextAlign.center,
                        style:
                            types.bodySmall?.copyWith(color: colors.outline),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: _resendSeconds > 0
                            ? 'ارسال مجدد کد'
                            : 'ارسال مجدد کد',
                        icon: Icons.refresh_rounded,
                        onPressed:
                            _resendSeconds > 0 ? null : () => _sendCode(),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'تایید و ورود',
                        icon: Icons.login_rounded,
                        controller: _verifyButton,
                        onPressed: _verifyCode,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() => _step = _LoginStep.phone);
                        },
                        child: const Text('ویرایش شماره موبایل'),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
