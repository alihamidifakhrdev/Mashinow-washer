import 'package:flutter/material.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:toastification/toastification.dart';

/// Lightweight wrapper around toastification with the app's visual language.
class Toast {
  static void success(
    BuildContext context, {
    String? title,
    String? description,
  }) {
    _show(
      context,
      type: ToastificationType.success,
      icon: Icons.check_circle_rounded,
      title: title ?? 'با موفقیت انجام شد',
      description: description,
    );
  }

  static void error(
    BuildContext context, {
    String? title,
    String? description,
  }) {
    _show(
      context,
      type: ToastificationType.error,
      icon: Icons.error_rounded,
      title: title ?? 'خطا',
      description: description,
    );
  }

  static void info(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    _show(
      context,
      type: ToastificationType.info,
      icon: Icons.info_rounded,
      title: title,
      description: description,
    );
  }

  static void _show(
    BuildContext context, {
    required ToastificationType type,
    required IconData icon,
    required String title,
    String? description,
  }) {
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.fillColored,
      backgroundColor: context.colors.surface,
      primaryColor: _primaryColor(context, type),
      direction: context.textDirection,
      alignment: Alignment.topCenter,
      borderRadius: BorderRadius.circular(18),
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      description: description != null ? Text(description) : null,
      borderSide: BorderSide.none,
      showIcon: true,
      icon: Icon(icon, color: _primaryColor(context, type)),
      closeButton: const ToastCloseButton(showType: CloseButtonShowType.none),
      autoCloseDuration: const Duration(seconds: 3),
      pauseOnHover: true,
      dragToClose: true,
      showProgressBar: false,
    );
  }

  static Color _primaryColor(BuildContext context, ToastificationType type) {
    if (type == ToastificationType.success) {
      return const Color(0xff22c55e);
    } else if (type == ToastificationType.error) {
      return context.colors.error;
    } else if (type == ToastificationType.warning) {
      return const Color(0xfff59e0b);
    } else {
      return context.colors.primary;
    }
  }
}
