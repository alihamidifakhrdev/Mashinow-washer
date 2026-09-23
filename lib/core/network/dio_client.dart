import 'package:dio/dio.dart';
import 'package:mashinow_washer/core/constants/common_values.dart';

class DioClient {
  final Dio dio;

  DioClient({required this.dio}) {
    _initialize();
  }

  void _initialize() {
    dio.options = BaseOptions(
      baseUrl: CommonValues.baseUrlApi,
      connectTimeout: const Duration(
        seconds: CommonValues.requestTimeoutSeconds,
      ),
      receiveTimeout: const Duration(
        seconds: CommonValues.requestTimeoutSeconds,
      ),
      contentType: 'application/json',
      responseType: ResponseType.json,
    );
  }

  // :: GET
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => dio.get(path, queryParameters: queryParameters, options: options);

  // :: POST
  Future<Response<T>> post<T>(String path,
          {dynamic data, Options? options}) =>
      dio.post(path, data: data, options: options);

  // :: PUT
  Future<Response<T>> put<T>(String path, {dynamic data, Options? options}) =>
      dio.put(path, data: data, options: options);

  // :: PATCH
  Future<Response<T>> patch<T>(String path,
          {dynamic data, Options? options}) =>
      dio.patch(path, data: data, options: options);

  // :: DELETE
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Options? options,
  }) => dio.delete(path, data: data, options: options);
}
