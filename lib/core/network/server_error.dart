import 'package:dio/dio.dart';

/// Human-readable message extracted from a Django REST Framework error body.
class ServerError implements Exception {
  final String message;
  final int? statusCode;

  const ServerError(this.message, {this.statusCode});

  factory ServerError.fromDio(DioException error) {
    final response = error.response;
    final data = response?.data;

    String message = _defaultMessage(error);

    if (data is Map<String, dynamic>) {
      final parsed = _parseMap(data);
      if (parsed != null) return ServerError(parsed, statusCode: response?.statusCode);
    } else if (data is String && data.trim().isNotEmpty) {
      return ServerError(data, statusCode: response?.statusCode);
    }

    return ServerError(message, statusCode: response?.statusCode);
  }

  static String _defaultMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'زمان اتصال به سرور به پایان رسید؛ لطفاً دوباره تلاش کنید';
      case DioExceptionType.connectionError:
        return 'ارتباط با سرور برقرار نشد؛ اینترنت خود را بررسی کنید';
      case DioExceptionType.cancel:
        return 'درخواست لغو شد';
      default:
        return 'خطایی رخ داد؛ لطفاً دوباره تلاش کنید';
    }
  }

  static String? _parseMap(Map<String, dynamic> map) {
    // DRF common shapes: {'detail': ...}, {'field': ['msg']},
    // {'field': {'nested': ...}}, {'non_field_errors': [...]}
    for (final key in ['detail', 'message', 'error', 'non_field_errors']) {
      final value = map[key];
      if (value == null) continue;
      final text = _valueToText(value);
      if (text != null) return text;
    }

    // Fall back to first field error
    for (final entry in map.entries) {
      final text = _valueToText(entry.value);
      if (text != null) return text;
    }

    return null;
  }

  static String? _valueToText(Object? value) {
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return _valueToText(value.first);
    if (value is Map<String, dynamic>) return _parseMap(value);
    return null;
  }

  @override
  String toString() => message;
}
