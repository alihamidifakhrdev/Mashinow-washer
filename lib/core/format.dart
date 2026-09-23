/// قالب‌بندی پول و اعداد — قیمت‌ها در بک‌اند «ریال» هستند و همه‌جا
/// مثل سایت به «تومان» (تقسیم بر ۱۰) نمایش داده می‌شوند.
String groupDigits(int number) {
  final String raw = number.abs().toString();
  final StringBuffer out = StringBuffer();

  for (int i = 0; i < raw.length; i++) {
    final int posFromEnd = raw.length - i;
    out.write(raw[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) out.write(',');
  }

  return number < 0 ? '-${out.toString()}' : out.toString();
}

/// ریال → تومان با جداکننده هزارگان
String toToman(int rial) => groupDigits((rial / 10).round());

/// ریال → تومان + واحد
String tomanLabel(int rial) => '${toToman(rial)} تومان';

/// برچسب روش پرداخت
String paymentMethodLabel(String? method) {
  switch (method) {
    case 'wallet':
      return 'کیف پول';
    case 'in_place':
      return 'حضوری';
    default:
      return '—';
  }
}
