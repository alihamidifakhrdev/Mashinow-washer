import 'package:dio/dio.dart';
import 'package:mashinow_washer/core/models/auth_tokens.dart';
import 'package:mashinow_washer/core/network/dio_client.dart';
import 'package:mashinow_washer/core/providers/app_auth.dart';

/// Attaches the JWT access token to every request and transparently refreshes
/// expired tokens (single-flight) then retries the original request.
class AuthInterceptor extends Interceptor {
  final AppAuth appAuth;
  final DioClient dioClient;

  AuthInterceptor({required this.appAuth, required this.dioClient});

  static const _refreshTokenPath = '/accounts/mobile/token/refresh/';
  static const _retriedRequestKey = 'mashinow.washer.auth.retried';

  Future<AuthTokens>? _refreshingTokens;

  bool _isRefreshingToken(RequestOptions options) =>
      options.path.endsWith(_refreshTokenPath);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final tokens = appAuth.currentTokens;

    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.access}';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    if (_isRefreshingToken(err.requestOptions) ||
        err.requestOptions.extra[_retriedRequestKey] == true) {
      await appAuth.logout();
      handler.next(err);
      return;
    }

    final tokens = appAuth.currentTokens;

    if (tokens == null) {
      handler.next(err);
      return;
    }

    try {
      // :: SINGLE-FLIGHT REFRESH
      // Concurrent 401s share one refresh call instead of racing each other.
      final refreshFuture = _refreshingTokens ??= _refreshTokens(tokens);
      final newTokens = await refreshFuture;

      // :: RETRY REQUEST
      final requestOptions = err.requestOptions;
      requestOptions.extra[_retriedRequestKey] = true;
      requestOptions.headers['Authorization'] = 'Bearer ${newTokens.access}';

      final retryResponse = await dioClient.dio.fetch(requestOptions);
      handler.resolve(retryResponse);
    } catch (_) {
      await appAuth.logout();
      handler.next(err);
    } finally {
      _refreshingTokens = null;
    }
  }

  Future<AuthTokens> _refreshTokens(AuthTokens tokens) async {
    final refreshTokensResponse = await dioClient.post(
      _refreshTokenPath,
      data: {'refresh': tokens.refresh},
    );

    final newTokens = AuthTokens.fromJson(
      refreshTokensResponse.data as Map<String, dynamic>,
    );

    await appAuth.refreshTokens(newTokens);

    return newTokens;
  }
}
