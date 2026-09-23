class CommonValues {
  // :: STRINGS
  static const String baseUrl = String.fromEnvironment(
    'MASHINOW_API_BASE_URL',
    defaultValue: 'http://82.115.21.39',
  );
  static const String baseUrlApi = "$baseUrl/api";

  // :: CONSTANTS
  static const String appRole = 'carwash';
  static const String appTitle = 'کارواش ماشینو';

  // :: INTEGERS
  static const int pageTransitionDurationMS = 300;
  static const int requestTimeoutSeconds = 15;
  static const int resendCodeTimeoutSeconds = 120;
}
