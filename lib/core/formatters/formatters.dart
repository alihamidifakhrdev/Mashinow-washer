import 'package:flutter/material.dart';
import 'package:mashinow_washer/core/extensions/string.dart';
import 'package:shamsi_date/shamsi_date.dart';

class Formatter {
  static const List<String> _jalaliMonths = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  /// Price with thousands separators (in Persian digits), e.g. ۱۲۵٬۰۰۰
  static String price(num value, {bool withUnit = false}) {
    final formatted = _groupDigits(value);
    return withUnit ? '$formatted تومان' : formatted;
  }

  static String _groupDigits(num value) {
    final text = value.round().abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[text.length - 1 - i]);
      if ((i + 1) % 3 == 0 && i + 1 != text.length) {
        buffer.write('٬');
      }
    }
    return buffer.toString().split('').reversed.join().toPersianDigits();
  }

  /// Jalali date, e.g. ۱۴۰۴/۰۶/۲۸
  static String jalaliDate(DateTime dateTime) {
    final jalali = Jalali.fromDateTime(dateTime.toLocal());
    final y = jalali.year.toString().toPersianDigits();
    final m = jalali.month.toString().padLeft(2, '0').toPersianDigits();
    final d = jalali.day.toString().padLeft(2, '0').toPersianDigits();
    return '$y/$m/$d';
  }

  /// Jalali full date, e.g. ۲۸ شهریور ۱۴۰۴
  static String jalaliFullDate(DateTime dateTime) {
    final jalali = Jalali.fromDateTime(dateTime.toLocal());
    final monthName = _jalaliMonths[jalali.month - 1];
    final day = jalali.day.toString().toPersianDigits();
    final year = jalali.year.toString().toPersianDigits();
    return '$day $monthName $year';
  }

  /// Weekday name in Persian for a [dateTime].
  static String weekdayName(DateTime dateTime) {
    // DateTime.weekday: Monday = 1 ... Sunday = 7
    const map = {
      DateTime.saturday: 'شنبه',
      DateTime.sunday: 'یکشنبه',
      DateTime.monday: 'دوشنبه',
      DateTime.tuesday: 'سه‌شنبه',
      DateTime.wednesday: 'چهارشنبه',
      DateTime.thursday: 'پنجشنبه',
      DateTime.friday: 'جمعه',
    };
    return map[dateTime.toLocal().weekday] ?? '';
  }

  /// Time of day, e.g. ۰۹:۳۰
  static String timeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute'.toPersianDigits();
  }

  /// Time from a DateTime, e.g. ۱۴:۰۰
  static String time(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute'.toPersianDigits();
  }

  /// API date format (YYYY-MM-DD) from a local DateTime.
  static String apiDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Booking status to Persian label.
  static String bookingStatus(String status) {
    switch (status) {
      case 'reserved':
        return 'رزرو شده';
      case 'cancelled':
        return 'لغو شده';
      case 'done':
        return 'انجام شده';
      default:
        return status;
    }
  }

  /// Payment method to Persian label.
  static String paymentMethod(String method) {
    switch (method) {
      case 'wallet':
        return 'پرداخت از کیف پول';
      case 'in_place':
        return 'پرداخت حضوری';
      default:
        return method;
    }
  }

  /// Wallet transaction type to Persian label.
  static String transactionType(String type) {
    switch (type) {
      case 'signup_bonus':
        return 'هدیه ثبت‌نام';
      case 'invite_bonus':
        return 'پاداش معرفی';
      case 'booking_payment':
        return 'پرداخت رزرو';
      case 'booking_income':
        return 'درآمد رزرو';
      case 'manual_recharge':
        return 'شارژ دستی';
      case 'withdrawal':
        return 'برداشت';
      default:
        return type;
    }
  }
}
