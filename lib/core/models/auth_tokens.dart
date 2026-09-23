import 'package:mashinow_washer/core/models/user.dart';

class AuthTokens {
  final String access;
  final String refresh;

  const AuthTokens({required this.access, required this.refresh});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        access: json['access'] as String? ?? '',
        refresh: json['refresh'] as String? ?? '',
      );

  AuthTokens copyWith({String? access, String? refresh}) => AuthTokens(
        access: access ?? this.access,
        refresh: refresh ?? this.refresh,
      );
}

class LoginResponse {
  final AuthTokens tokens;
  final User user;

  const LoginResponse({required this.tokens, required this.user});

  factory LoginResponse.fromEnvelope(Map<String, dynamic> envelope) {
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object inside "data"');
    }
    return LoginResponse(
      tokens: AuthTokens.fromJson(data),
      user: User.fromJson(data['user'] as Map<String, dynamic>? ?? {}),
    );
  }
}
