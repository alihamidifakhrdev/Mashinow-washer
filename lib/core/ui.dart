import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'session.dart';
import 'theme.dart';

/// دسترسی سراسری به نشست — SessionScope.of(context)
class SessionScope extends InheritedNotifier<SessionStore> {
  const SessionScope({
    super.key,
    required SessionStore notifier,
    required super.child,
  }) : super(notifier: notifier);

  static SessionStore of(BuildContext context) {
    final SessionScope? scope =
        context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope not found in widget tree');
    return scope!.notifier!;
  }
}

// :: دکمه اصلی — قرص آبی سایه‌دار (سبک iOS سایت)

enum AppButtonType { primary, soft, danger, success }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final AppButtonType type;
  final IconData? icon;

  /// دکمه‌های اصلی همیشه تمام‌عرض هستند (سبک اسنپ)
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.type = AppButtonType.primary,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;

    final Color bg;
    final Color fg;
    switch (type) {
      case AppButtonType.primary:
        bg = AppColors.accent;
        fg = Colors.white;
        break;
      case AppButtonType.soft:
        bg = AppColors.accentTint();
        fg = AppColors.accentDeep;
        break;
      case AppButtonType.danger:
        bg = AppColors.redTint();
        fg = AppColors.red;
        break;
      case AppButtonType.success:
        bg = AppColors.success;
        fg = Colors.white;
        break;
    }

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 54,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            // سایه هم‌رنگ خود دکمه (آبی یا سبز)
            boxShadow: enabled && type != AppButtonType.soft
                ? <BoxShadow>[
                    BoxShadow(
                      color: bg.withOpacity(0.40),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: -6,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: ElevatedButton(
            onPressed: loading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledBackgroundColor: bg,
              disabledForegroundColor: fg,
              elevation: 0,
              shadowColor: Colors.transparent,
              splashFactory: InkSplash.splashFactory,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              textStyle: const TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (icon != null) ...<Widget>[
                        Icon(icon, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(text),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// :: تبدیل ارقام فارسی/عربی به لاتین — برای فیلدهای شماره‌ای که کیبورد
// فارسی ممکن است ۰۱۲۳ بفرستد (عیب گزارش‌شده در لاگین)

String normalizeDigits(String input) {
  final StringBuffer out = StringBuffer();

  for (final int code in input.runes) {
    if (code >= 0x06F0 && code <= 0x06F9) {
      out.writeCharCode(code - 0x06F0 + 0x30); // ۰-۹
    } else if (code >= 0x0660 && code <= 0x0669) {
      out.writeCharCode(code - 0x0660 + 0x30); // ٠-٩
    } else {
      out.writeCharCode(code);
    }
  }

  return out.toString();
}

/// ارقام فارسی/عربی را می‌پذیرد، به لاتین تبدیل می‌کند و بقیه را حذف می‌کند
class SmartDigitsInputFormatter extends TextInputFormatter {
  final int? maxLength;

  const SmartDigitsInputFormatter({this.maxLength});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text =
        normalizeDigits(newValue.text).replaceAll(RegExp(r'[^0-9]'), '');

    final int? max = maxLength;
    if (max != null && text.length > max) {
      text = text.substring(0, max);
    }

    if (text == newValue.text) return newValue;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// ورودی «کد پیگیری» — کد پیگیری حروف + رقم است (مثل MS140312):
/// ارقام فارسی/عربی را به لاتین تبدیل می‌کند، فقط حرف و رقم نگه می‌دارد
/// و برای خوانایی هم‌شکل، حروف را بزرگ می‌کند.
class SmartCodeInputFormatter extends TextInputFormatter {
  final int? maxLength;

  const SmartCodeInputFormatter({this.maxLength});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = normalizeDigits(newValue.text)
        .replaceAll(RegExp(r'[^0-9a-zA-Z]'), '')
        .toUpperCase();

    final int? max = maxLength;
    if (max != null && text.length > max) {
      text = text.substring(0, max);
    }

    if (text == newValue.text) return newValue;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// :: فیلد متنی — بدون خط دور، زمینه خاکستری ملایم (سبک سایت)

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helperError;
  final TextInputType? keyboard;
  final bool ltr;
  final int maxLines;
  final int? maxLength;
  final bool digitsOnly;
  final bool optional;

  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.helperError,
    this.keyboard,
    this.ltr = false,
    this.maxLines = 1,
    this.maxLength,
    this.digitsOnly = false,
    this.optional = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Row(
            children: <Widget>[
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink2,
                ),
              ),
              if (widget.optional)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '(اختیاری)',
                    style: TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 12,
                      color: AppColors.ink3,
                    ),
                  ),
                ),
            ],
          ),
        ),
        TextField(
          controller: widget.controller,
          keyboardType: widget.keyboard,
          maxLines: widget.maxLines,
          minLines: widget.maxLines > 1 ? 2 : 1,
          maxLength: widget.maxLength,
          inputFormatters: <TextInputFormatter>[
            if (widget.digitsOnly)
              SmartDigitsInputFormatter(maxLength: widget.maxLength),
          ],
          textAlign: widget.ltr ? TextAlign.left : TextAlign.right,
          textDirection: widget.ltr ? TextDirection.ltr : TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'IRANYekan',
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontFamily: 'IRANYekan',
              fontSize: 13.5,
              color: AppColors.ink3,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: AppColors.fill,
            counterText: '',
            contentPadding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: widget.maxLines > 1 ? 14 : 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: AppColors.accent, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: AppColors.red, width: 1.4),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: AppColors.red, width: 1.6),
            ),
          ),
        ),
        if (widget.helperError != null && widget.helperError!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 4),
            child: Text(
              widget.helperError!,
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.red,
              ),
            ),
          ),
      ],
    );
  }
}

// :: کارت بدون خط دور با سایه نرم

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

// :: چیپ وضعیت نوبت

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    final Color tint;

    switch (status) {
      case 'done':
        label = 'انجام شد';
        color = AppColors.successDeep;
        tint = AppColors.successTint(0.20);
        break;
      case 'cancelled':
        label = 'لغو شده';
        color = AppColors.red;
        tint = AppColors.redTint();
        break;
      default:
        label = 'رزرو شده';
        color = AppColors.accent;
        tint = AppColors.accentTint();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'IRANYekan',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// :: کاشی آمار داشبورد

class StatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color tint;

  const StatTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'IRANYekan',
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'IRANYekan',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

// :: تیتر بخش

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle({super.key, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// :: حالت خالی

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: AppColors.ink3, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'IRANYekan',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.ink3,
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// :: توست — بالای صفحه، سبک نوتیفیکیشن iOS؛ فقط یک نمونه هم‌زمان

_TopToastState? _activeToast;
OverlayEntry? _activeEntry;

void showToast(BuildContext context, String message, {bool error = false}) {
  _activeToast?.dismissNow();

  // اگر توست قبلی هنوز رندر نشده باشد، ورودی آن را مستقیم حذف کن
  _activeEntry?.remove();
  _activeEntry = null;

  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final OverlayEntry entry = OverlayEntry(
    builder: (BuildContext ctx) => _TopToast(
      message: message,
      error: error,
    ),
  );

  _activeEntry = entry;
  overlay.insert(entry);
}

class _TopToast extends StatefulWidget {
  final String message;
  final bool error;

  const _TopToast({
    required this.message,
    required this.error,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    reverseDuration: const Duration(milliseconds: 260),
  );

  Timer? _timer;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    _activeToast = this;
    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 3400), () => _fadeOut());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_activeToast == this) _activeToast = null;
    _controller.dispose();
    super.dispose();
  }

  void _fadeOut() {
    _timer?.cancel();
    _timer = null;

    _controller.reverse().then((_) => _removeEntry());
  }

  void _removeEntry() {
    if (_removed) return;
    _removed = true;
    if (_activeToast == this) _activeToast = null;

    final OverlayEntry? entry = _activeEntry;
    _activeEntry = null;
    entry?.remove();
  }

  /// حذف فوری — وقتی توست جدیدی می‌آید
  void dismissNow() {
    _timer?.cancel();
    _timer = null;
    _removeEntry();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets topInset = MediaQuery.of(context).padding;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.only(top: topInset.top + 10, left: 16, right: 16),
        child: GestureDetector(
          onTap: dismissNow,
          behavior: HitTestBehavior.opaque,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.3, 1, curve: Curves.easeOut),
            ),
            child: SlideTransition(
              position: _controller.drive<Offset>(
                Tween<Offset>(
                  begin: const Offset(0, -1.2),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic)),
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.isDark
                        ? const Color(0xFF242E42)
                        : const Color(0xFF101A2E),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(AppColors.isDark ? 0.45 : 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        widget.error
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_rounded,
                        color: widget.error
                            ? const Color(0xFFFFB3AE)
                            : const Color(0xFF9DE8B2),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            fontFamily: 'IRANYekan',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// :: دیالوگ تأیید — سبک iOS (تیتر وسط‌چین، جداکننده نازک، دکمه‌های دونیم)

Future<bool> showIOSConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
  String cancelText = 'انصراف',
  bool destructive = false,
}) async {
  final bool? result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'بستن',
    barrierColor: Colors.black.withOpacity(0.40),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (BuildContext ctx, Animation<double> _, Animation<double> __) {
      return _IOSConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        destructive: destructive,
      );
    },
    transitionBuilder: (BuildContext ctx, Animation<double> anim,
        Animation<double> _, Widget child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
          child: child,
        ),
      );
    },
  );

  return result ?? false;
}

class _IOSConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool destructive;

  const _IOSConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 300, maxWidth: 340),
          child: Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 16.5,
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink2,
                          height: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: AppColors.fill2),
                SizedBox(
                  height: 50,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        child: _IOSDialogButton(
                          label: cancelText,
                          color: AppColors.ink2,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      Container(width: 1, color: AppColors.fill2),
                      Expanded(
                        child: _IOSDialogButton(
                          label: confirmText,
                          color: destructive ? AppColors.red : AppColors.accent,
                          bold: true,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
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

class _IOSDialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool bold;
  final VoidCallback onTap;

  const _IOSDialogButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IRANYekan',
            fontSize: 14.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

// :: انتخاب‌گر اختصاصی — جایگزین منوی پیش‌فرض اندروید در همه‌جای اپ
// (فیلد + باتم‌شیت با جستجو برای فهرست‌های بلند، تیک کنار گزینه انتخاب‌شده)

class AppSelectField<T> extends StatelessWidget {
  final T? value;
  final String Function(T) labelOf;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String? hint;
  final String? sheetTitle;
  final IconData? icon;
  final bool enabled;

  /// حالت فشرده برای داخل ردیف‌ها (مثل نوع خودرو کنار قیمت)
  final bool compact;

  const AppSelectField({
    super.key,
    required this.value,
    required this.labelOf,
    required this.items,
    required this.onChanged,
    this.hint,
    this.sheetTitle,
    this.icon,
    this.enabled = true,
    this.compact = false,
  });

  Future<void> _open(BuildContext context) async {
    final T? picked = await showAppSelectSheet<T>(
      context: context,
      title: sheetTitle ?? hint ?? 'انتخاب کنید',
      items: items,
      labelOf: labelOf,
      selected: value,
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && items.isNotEmpty ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(compact ? 12 : AppRadius.md),
        child: Container(
          height: compact ? 48 : 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.fill,
            borderRadius:
                BorderRadius.circular(compact ? 12 : AppRadius.md),
          ),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 19, color: AppColors.ink3),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  hasValue ? labelOf(value as T) : (hint ?? 'انتخاب کنید'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: compact ? 13 : 14.5,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                    color: hasValue ? AppColors.ink : AppColors.ink3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: enabled && items.isNotEmpty
                    ? AppColors.ink3
                    : AppColors.ink3.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showAppSelectSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) labelOf,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (BuildContext sheetContext) => _AppSelectSheet<T>(
      title: title,
      items: items,
      labelOf: labelOf,
      selected: selected,
    ),
  );
}

class _AppSelectSheet<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final T? selected;

  const _AppSelectSheet({
    required this.title,
    required this.items,
    required this.labelOf,
    required this.selected,
  });

  @override
  State<_AppSelectSheet<T>> createState() => _AppSelectSheetState<T>();
}

class _AppSelectSheetState<T> extends State<_AppSelectSheet<T>> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool withSearch = widget.items.length > 8;

    final List<T> filtered = _query.isEmpty
        ? widget.items
        : widget.items
            .where(
                (T item) => widget.labelOf(item).contains(_query))
            .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.74,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // :: دستگیره + تیتر + بستن
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4.5,
            decoration: BoxDecoration(
              color: AppColors.fill2,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded,
                      size: 22, color: AppColors.ink3),
                ),
              ],
            ),
          ),

          // :: جستجو برای فهرست‌های بلند (مثل استان‌ها)
          if (withSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: TextField(
                controller: _search,
                onChanged: (String v) => setState(() => _query = v.trim()),
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: 'جستجو...',
                  hintStyle: TextStyle(
                    fontFamily: 'IRANYekan',
                    fontSize: 13.5,
                    color: AppColors.ink3,
                  ),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: AppColors.ink3),
                  filled: true,
                  fillColor: AppColors.fill,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide:
                        BorderSide(color: AppColors.accent, width: 1.4),
                  ),
                ),
              ),
            ),

          // :: گزینه‌ها
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(
                12,
                6,
                12,
                18 + MediaQuery.of(context).padding.bottom,
              ),
              children: <Widget>[
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'موردی پیدا نشد',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'IRANYekan',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink3,
                      ),
                    ),
                  )
                else
                  for (final T item in filtered)
                    _sheetOption(context, item),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetOption(BuildContext sheetContext, T item) {
    final bool isSelected = item == widget.selected;

    return InkWell(
      onTap: () => Navigator.of(sheetContext).pop(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentTint(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                widget.labelOf(item),
                style: TextStyle(
                  fontFamily: 'IRANYekan',
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.accentDeep : AppColors.ink2,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  size: 21, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

// :: صفحه‌ی Auth/Onboarding — محتوا وسط صفحه (نه بالا چسبیده)
//
// ساختار صفحه سه ناحیه‌ی مشخص دارد («هرچیز جای خودش»):
//   ۱) نوار بالا: دکمه بازگشت / چیپ مرحله
//   ۲) بدنه: بلوک هویت (آیکون + عنوان + زیرعنوان) و بلوک فرم —
//      هر دو با هم دقیقاً در «وسط» فضای خالی بین نوار بالا و دکمه پایین
//      می‌نشینند (الگوی LayoutBuilder + minHeight + Center که حتی وقتی
//      محتوا کوتاه‌تر از صفحه است وسط می‌ماند و وقتی بلندتر/کیبورد باز
//      است به‌اصطلاح scroll می‌شود)
//   ۳) پایین: دکمه اصلی همیشه در جای خودش به کف صفحه چسبیده است

class AuthScaffold extends StatelessWidget {
  final IconData glyph;
  final Color glyphColor;
  final Color glyphTint;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? bottomButton;
  final Widget? appBarLeading;
  final String? stepLabel;
  final String? footerCaption;

  const AuthScaffold({
    super.key,
    required this.glyph,
    required this.glyphColor,
    required this.glyphTint,
    required this.title,
    required this.subtitle,
    required this.children,
    this.bottomButton,
    this.appBarLeading,
    this.stepLabel,
    this.footerCaption,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: appBarLeading,
        actions: <Widget>[
          if (stepLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.fill,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    stepLabel!,
                    style: TextStyle(
                      fontFamily: 'IRANYekan',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double bodyHeight = constraints.maxHeight;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: bodyHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // ─── بلوک ۱: هویت صفحه ───
                      Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: glyphTint,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(glyph, color: glyphColor, size: 32),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink2,
                          height: 1.9,
                        ),
                      ),

                      // ─── بلوک ۲: فرم / محتوای اصلی ───
                      const SizedBox(height: 32),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: bottomButton == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    bottomButton!,
                    if (footerCaption != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        footerCaption!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'IRANYekan',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

// :: ویجت شماره موبایل با پیش‌شماره ثابت

class PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const PhoneField({
    super.key,
    required this.controller,
    this.label = 'شماره موبایل',
  });

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hint: '09xxxxxxxxx',
      keyboard: TextInputType.phone,
      ltr: true,
      maxLength: 11,
      digitsOnly: true,
    );
  }
}
