import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mashinow_washer/core/extensions/string.dart';

/// Text field variant: plain (with optional prefix icon).
enum AppTextFieldType { normal, phone, price, number }

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? Function(String?)? validator;
  final AppTextFieldType type;
  final IconData? icon;
  final Widget? suffix;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;
  final TextInputAction textInputAction;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? initialValue;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.validator,
    this.type = AppTextFieldType.normal,
    this.icon,
    this.suffix,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction = TextInputAction.next,
    this.onTap,
    this.onChanged,
    this.onFieldSubmitted,
    this.focusNode,
    this.keyboardType,
    this.inputFormatters,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    TextInputType keyboard = keyboardType ?? _defaultKeyboard();
    List<TextInputFormatter>? formatters = inputFormatters;

    if (type == AppTextFieldType.phone) {
      keyboard = TextInputType.phone;
      formatters = formatters ??
          [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹+]')),
            LengthLimitingTextInputFormatter(11),
          ];
    } else if (type == AppTextFieldType.price ||
        type == AppTextFieldType.number) {
      keyboard = TextInputType.number;
      formatters = formatters ??
          [FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹]'))];
    }

    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      textAlign: maxLines > 1 ? TextAlign.start : TextAlign.start,
      textInputAction: textInputAction,
      onTap: onTap,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      keyboardType: keyboard,
      inputFormatters: formatters,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        helperMaxLines: 3,
        errorMaxLines: 3,
        prefixIcon: icon != null ? Icon(icon, size: 24) : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: enabled
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.surfaceContainerHighest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.error,
            width: 1.4,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.error,
            width: 1.8,
          ),
        ),
      ),
    );
  }

  TextInputType _defaultKeyboard() {
    switch (type) {
      case AppTextFieldType.phone:
        return TextInputType.phone;
      case AppTextFieldType.price:
      case AppTextFieldType.number:
        return TextInputType.number;
      case AppTextFieldType.normal:
        return TextInputType.text;
    }
  }
}

/// Input formatter keeping only Persian/Arabic/Latin digits.
class DigitsOnlyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toEnglishDigits();
    final kept = text.replaceAll(RegExp(r'[^0-9]'), '');
    return TextEditingValue(
      text: kept,
      selection: TextSelection.collapsed(offset: kept.length),
    );
  }
}
