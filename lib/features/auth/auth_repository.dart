import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/constants/common_values.dart';
import 'package:mashinow_washer/core/models/auth_tokens.dart';
import 'package:mashinow_washer/core/network/server_error.dart';
import 'package:mashinow_washer/core/providers/dio.dart';

/// Authentication data source for the washer side (role = 'carwash').
class AuthRepository {
  final Dio _dio;

  const AuthRepository(this._dio);

  /// Requests an OTP code for [phoneNumber].
  Future<void> sendCode(String phoneNumber) async {
    try {
      await _dio.post(
        '/accounts/send-code/',
        data: {
          'phone_number': phoneNumber,
          'role': CommonValues.appRole,
        },
      );
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }

  /// Verifies the OTP [code] and returns tokens + user on success.
  Future<LoginResponse> verifyCode(String phoneNumber, String code) async {
    try {
      final response = await _dio.post(
        '/accounts/mobile/verify-code/',
        data: {
          'phone_number': phoneNumber,
          'code': code,
        },
      );

      return LoginResponse.fromEnvelope(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw ServerError.fromDio(error);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);
