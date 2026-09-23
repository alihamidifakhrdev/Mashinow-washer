import 'package:flutter_test/flutter_test.dart';

import 'package:mashinow_washer/core/formatters/formatters.dart';

void main() {
  test('price formats with Persian digits and separators', () {
    expect(Formatter.price(150000), '۱۵۰٬۰۰۰');
    expect(Formatter.price(0), '۰');
  });

  test('digits conversion', () {
    expect('۰۹۱۲'.toEnglishDigitsForTest(), '0912');
  });

  test('api date format', () {
    final date = DateTime(2025, 5, 20);
    expect(Formatter.apiDate(date), '2025-05-20');
  });

  test('booking status labels', () {
    expect(Formatter.bookingStatus('reserved'), 'رزرو شده');
    expect(Formatter.bookingStatus('done'), 'انجام شده');
    expect(Formatter.bookingStatus('cancelled'), 'لغو شده');
  });
}

extension on String {
  String toEnglishDigitsForTest() {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var text = this;
    for (var i = 0; i < persian.length; i++) {
      text = text.replaceAll(persian[i], '$i');
    }
    return text;
  }
}
