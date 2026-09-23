/// تبدیل تاریخ میلادی ↔ شمسی (الگوریتم استاندارد jalaali) + فرمت‌های فارسی
class Jalali {
  final int year;
  final int month;
  final int day;

  const Jalali(this.year, this.month, this.day);

  static const List<String> months = [
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

  /// روزهای هفته به ترتیب شنبه‌محور
  static const List<String> weekdays = [
    'شنبه',
    'یک‌شنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنج‌شنبه',
    'جمعه',
  ];

  /// تبدیل میلادی به شمسی
  factory Jalali.fromDateTime(DateTime g) {
    final List<int> j = _toJalali(g.year, g.month, g.day);
    return Jalali(j[0], j[1], j[2]);
  }

  static List<int> _toJalali(int gy, int gm, int gd) {
    const List<int> gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];

    int jy = (gy <= 1600) ? 0 : 979;
    gy -= (gy <= 1600) ? 621 : 1600;

    final int gy2 = (gm > 2) ? (gy + 1) : gy;
    int days = (365 * gy) +
        ((gy2 + 3) ~/ 4) -
        ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) -
        80 +
        gd +
        gdm[gm - 1];

    jy += 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;

    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }

    final int jm = (days < 186) ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
    final int jd = 1 + ((days < 186) ? (days % 31) : ((days - 186) % 30));

    return [jy, jm, jd];
  }

  /// شماره روز هفته شمسی: شنبه=۱ ... جمعه=۷
  static int persianWeekday(DateTime g) => ((g.weekday + 1) % 7) + 1;

  /// نام روز هفته شمسی
  static String weekdayName(DateTime g) => weekdays[persianWeekday(g) - 1];

  /// تاریخ کامل: «شنبه ۳۰ شهریور ۱۴۰۵»
  static String fullDate(DateTime g) {
    final j = Jalali.fromDateTime(g);
    return '${weekdayName(g)} ${j.day} ${months[j.month - 1]} ${j.year}';
  }

  /// تاریخ کوتاه: «۳۰ شهریور»
  static String shortDate(DateTime g) {
    final j = Jalali.fromDateTime(g);
    return '${j.day} ${months[j.month - 1]}';
  }

  /// ساعت: «۱۰:۳۰» (فونت یکان‌بخ ارقام را فارسی نشان می‌دهد)
  static String clock(DateTime g) =>
      '${g.hour.toString().padLeft(2, '0')}:${g.minute.toString().padLeft(2, '0')}';

  /// شنبه‌ی هفته‌ی جاری (شروع هفته شمسی) — امروز شنبه باشد خودش برمی‌گردد
  static DateTime startOfWeek(DateTime now) {
    return now.subtract(Duration(days: persianWeekday(now) - 1));
  }

  /// تاریخ متناظر با روز هفته شمسی داده‌شده (۱=شنبه .. ۷=جمعه).
  ///
  /// اگر همان روزِ امروز باشد، خودِ امروز برمی‌گردد — تا با ثبتِ
  /// «زمان‌های کاری» در همان روز هم بازه‌های امروز ساخته شود و صفحه‌ی
  /// ساعتِ نوبت حضوری خالی نماند (قبلاً هفته‌ی بعد می‌ساخت).
  static DateTime nextDateOfPersianWeekday(int persianIndex1to7) {
    // نگاشت شماره شمسی به weekday دات‌ (دوشنبه=۱ .. یکشنبه=۷)
    const List<int> map = [6, 7, 1, 2, 3, 4, 5]; // index0=شنبه
    final int target = map[persianIndex1to7 - 1];

    final DateTime today = DateTime.now();
    final int daysUntil = (target - today.weekday + 7) % 7;

    return today.add(Duration(days: daysUntil));
  }

  /// YYYY-MM-DD برای ارسال به سرور
  static String isoDate(DateTime g) =>
      '${g.year.toString().padLeft(4, '0')}-${g.month.toString().padLeft(2, '0')}-${g.day.toString().padLeft(2, '0')}';
}

/// پارس تحمل‌پذیر تاریخ ISO سرور («2026-09-12T10:00:00+03:30» یا بدون offset)
DateTime? parseServerDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  final String s = raw.trim();

  try {
    final List<String> parts = s.split('T');
    final List<String> dateParts = parts[0].split('-');
    if (dateParts.length < 3) return null;

    List<String> timeParts = ['0', '0'];
    if (parts.length > 1) {
      final String timeChunk = parts[1].split('+').first.split('Z').first.split('.').first;
      timeParts = timeChunk.split(':');
    }

    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      timeParts.length > 0 ? int.parse(timeParts[0]) : 0,
      timeParts.length > 1 ? int.parse(timeParts[1]) : 0,
    );
  } catch (_) {
    return null;
  }
}
