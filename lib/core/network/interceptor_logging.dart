import 'package:dio/dio.dart';

/// Pretty-prints API requests and responses in debug mode.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // ignore: avoid_print
    print(
      '#DIO REQUEST [${options.method}] => ${options.uri}\n'
      'Headers: ${options.headers}\n'
      'Data: ${options.data}',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // ignore: avoid_print
    print(
      '#DIO RESPONSE [${response.statusCode}] <= ${response.requestOptions.uri}\n'
      'Data: ${response.data}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // ignore: avoid_print
    print(
      '#DIO ERROR [${err.response?.statusCode}] <= ${err.requestOptions.uri}\n'
      'Response: ${err.response?.data}\n'
      'Message: ${err.message}',
    );
    handler.next(err);
  }
}
