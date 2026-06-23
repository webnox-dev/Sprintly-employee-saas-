/// API Configuration for the custom backend
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  /// Backend base URL - Dynamically determined based on environment
  static String get baseUrl {
    final activeEnv = dotenv.env['ACTIVE_ENV'] ?? 'local';
    if (activeEnv == 'live') {
      return dotenv.env['API_BASE_URL_LIVE'] ??
          'https://api.rathz.com/api';
    }
    return dotenv.env['API_BASE_URL_LOCAL'] ?? 'https://api.rathz.com/api';
  }

  /// Request timeout duration
  static const Duration timeout = Duration(seconds: 30);

  /// Content type for JSON requests
  static const String contentType = 'application/json';
}
