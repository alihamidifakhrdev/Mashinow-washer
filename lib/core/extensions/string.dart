import 'package:mashinow_washer/core/constants/common_values.dart';

const persianNumbers = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

extension StringExtension on String {
  String toEnglishDigits() {
    String text = this;
    for (int index = 0; index < persianNumbers.length; index++) {
      text = text
          .replaceAll(persianNumbers[index], '$index')
          .replaceAll(arabicNumbers[index], '$index');
    }
    return text;
  }

  String toPersianDigits() {
    String text = this;
    for (int index = 0; index < persianNumbers.length; index++) {
      text = text.replaceAll('$index', persianNumbers[index]);
    }
    return text;
  }

  String get normalized {
    return trim()
        .replaceAll('\u200c', '')
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Rebuilds media URLs against the configured API base URL. The backend
  /// sometimes returns absolute URLs pointing at its internal host
  /// (e.g. http://localhost:8001/media/...) — this normalizes them.
  String toMediaUrl() {
    if (isEmpty) return this;

    final mediaPathIndex = indexOf('/media/');
    if (mediaPathIndex < 0) return this;

    return '${CommonValues.baseUrl}${substring(mediaPathIndex)}';
  }
}
