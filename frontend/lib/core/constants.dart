// lib/core/constants.dart
// ─────────────────────────────────────────────────────────────────────────────
// App-wide constants: API base URL, route names, storage keys.
// ─────────────────────────────────────────────────────────────────────────────

class ApiConstants {
  ApiConstants._();

  // Change this to your machine's IP when testing on a physical Android device.
  // For Android emulator use 10.0.2.2. For Windows desktop use localhost.
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

  // Endpoints
  static const String health  = '/health';
  static const String upload  = '/upload';
  static const String search  = '/search';
  static const String graph   = '/graph';
  static const String towers  = '/towers';

  // Auth
  static const String login    = '/auth/login';
  static const String register = '/auth/register';
  static const String me       = '/auth/me';
  static const String changePassword = '/auth/me/password';
}

class AppRoutes {
  AppRoutes._();

  static const String login  = '/login';
  static const String home   = '/';
  static const String ingest = '/ingest';
  static const String search = '/search';
  static const String graph  = '/graph';
  static const String map    = '/map';
}

class AppStrings {
  AppStrings._();

  static const String appName       = 'Telecom Analyzer';
  static const String navIngest     = 'Data Ingest';
  static const String navSearch     = 'Search';
  static const String navGraph      = 'Link Analysis';
  static const String navMap        = 'Geo Map';

  static const String uploadHint    = 'Select a CSV file to upload';
  static const String searchHint    = 'Enter phone number or IMEI…';
  static const String noResults     = 'No records found';
  static const String genericError  = 'Something went wrong. Please try again.';
}
