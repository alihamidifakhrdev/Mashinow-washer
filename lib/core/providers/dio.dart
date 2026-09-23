import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/network/dio_client.dart';
import 'package:mashinow_washer/core/network/interceptor_auth.dart';
import 'package:mashinow_washer/core/network/interceptor_logging.dart';
import 'package:mashinow_washer/core/providers/app_auth.dart';

/// Raw Dio instance shared across the app.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  final client = DioClient(dio: dio);
  final appAuth = ref.watch(appAuthProvider.notifier);

  dio.interceptors.addAll([
    AuthInterceptor(appAuth: appAuth, dioClient: client),
    if (assertionsEnabled) LoggingInterceptor(),
  ]);

  ref.onDispose(dio.close);

  return dio;
});

/// Whether the build is in debug mode (asserts are enabled).
bool get assertionsEnabled {
  var enabled = false;
  assert(() {
    enabled = true;
    return true;
  }());
  return enabled;
}

/// Convenience provider exposing [DioClient] helpers.
final dioClientProvider = Provider<DioClient>(
  (ref) => DioClient(dio: ref.watch(dioProvider)),
);
