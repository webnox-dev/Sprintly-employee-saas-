import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'api_config.dart';
import 'api_response.dart';
import '../services/local_storage_service.dart';
import '../services/session_expiry_service.dart';
import '../services/feature_guard_service.dart';

/// HTTP Client for communicating with the custom backend
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _client = http.Client();
  final LocalStorageService _localStorage = LocalStorageService();
  final Logger _logger = Logger();

  String? _authToken;

  /// Initialize the API client
  Future<void> init() async {
    await _localStorage.init();
    _authToken = _localStorage.accessToken;
    if (_authToken != null && _authToken!.isNotEmpty) {
      _logger.i('API Client initialized with existing token');
    } else {
      _logger.i('API Client initialized without token');
    }
  }

  /// Set the authentication token
  void setAuthToken(String token) {
    _authToken = token;
    _logger.i('Auth token set');
  }

  /// Clear the authentication token
  void clearAuthToken() {
    _authToken = null;
    _logger.i('Auth token cleared');
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  /// Get current auth token
  String? get authToken => _authToken;

  /// Build headers with auth token
  Map<String, String> _buildHeaders({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': ApiConfig.contentType,
      'Accept': ApiConfig.contentType,
    };

    if (includeAuth && _authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
      // _logger.d('Added Auth Token to headers: ${_authToken!.substring(0, 10)}...');
    } else {
      if (includeAuth) {
        _logger.w('Auth Token missing or empty when required!');
      }
    }

    return headers;
  }

  /// Build full URL with query parameters
  Uri _buildUri(String endpoint, {Map<String, dynamic>? queryParams}) {
    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';

    Map<String, String>? stringParams;
    if (queryParams != null) {
      stringParams =
          queryParams.map((key, value) => MapEntry(key, value.toString()));
    }

    return Uri(
      scheme: baseUri.scheme,
      host: baseUri.host,
      port: baseUri.port,
      path: '${baseUri.path}$path',
      queryParameters: stringParams,
    );
  }

  /// GET request
  Future<ApiResponse> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParams: queryParams);
      _logger.d('GET: $uri');

      final response = await _client
          .get(uri, headers: _buildHeaders(includeAuth: requiresAuth))
          .timeout(ApiConfig.timeout);

      return _handleResponse(response, requiresAuth: requiresAuth);
    } catch (e, stackTrace) {
      _logger.e('GET Error: $e', error: e, stackTrace: stackTrace);
      return _handleError(e);
    }
  }

  /// POST request
  Future<ApiResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      _logger.d('POST: $uri');

      final response = await _client
          .post(
            uri,
            headers: _buildHeaders(includeAuth: requiresAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);

      return _handleResponse(response, requiresAuth: requiresAuth);
    } catch (e, stackTrace) {
      _logger.e('POST Error: $e', error: e, stackTrace: stackTrace);
      return _handleError(e);
    }
  }

  /// PUT request
  Future<ApiResponse> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      _logger.d('PUT: $uri');

      final response = await _client
          .put(
            uri,
            headers: _buildHeaders(includeAuth: requiresAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);

      return _handleResponse(response, requiresAuth: requiresAuth);
    } catch (e, stackTrace) {
      _logger.e('PUT Error: $e', error: e, stackTrace: stackTrace);
      return _handleError(e);
    }
  }

  /// PATCH request
  Future<ApiResponse> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      _logger.d('PATCH: $uri');

      final response = await _client
          .patch(
            uri,
            headers: _buildHeaders(includeAuth: requiresAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);

      return _handleResponse(response, requiresAuth: requiresAuth);
    } catch (e, stackTrace) {
      _logger.e('PATCH Error: $e', error: e, stackTrace: stackTrace);
      return _handleError(e);
    }
  }

  /// DELETE request
  Future<ApiResponse> delete(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParams: queryParams);
      _logger.d('DELETE: $uri');

      final response = await _client
          .delete(
            uri,
            headers: _buildHeaders(includeAuth: requiresAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConfig.timeout);

      return _handleResponse(response, requiresAuth: requiresAuth);
    } catch (e, stackTrace) {
      _logger.e('DELETE Error: $e', error: e, stackTrace: stackTrace);
      return _handleError(e);
    }
  }

  /// Handle HTTP response
  ApiResponse _handleResponse(http.Response response,
      {bool requiresAuth = true}) {
    _logger.d('Response Status: ${response.statusCode}');

    Map<String, dynamic>? jsonBody;
    try {
      if (response.body.isNotEmpty) {
        jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      _logger.w('Failed to decode response body as JSON: $e');
    }

    // Intercept 401 Unauthorized — session/token expired
    if (response.statusCode == 401) {
      // Check if this 401 should trigger session expiry
      // We only trigger it if:
      // 1. The request required authentication (not a login attempt)
      // 2. The error is NOT a business logic error like INVALID_CREDENTIALS or WRONG_PASSWORD
      final errorCode = jsonBody?['error']?['code'] ?? jsonBody?['code'];
      final businessErrors = {
        'INVALID_CREDENTIALS',
        'WRONG_PASSWORD',
        'EMAIL_NOT_VERIFIED',
        'USER_NOT_FOUND',
        'INACTIVE_USER',
      };

      if (requiresAuth && !businessErrors.contains(errorCode)) {
        _logger.w('⏰ Received 401 — session expired, triggering logout');
        SessionExpiryService().handleSessionExpired();
        return ApiResponse(
          success: false,
          error: ApiError(
            code: 'SESSION_EXPIRED',
            message: 'Your session has expired. Please log in again.',
          ),
        );
      } else {
        _logger.i(
            'Received 401 — Business logic error or non-auth request: $errorCode');
      }
    }

    // Intercept 403 SaaS Feature Limitations
    if (response.statusCode == 403) {
      final errorCode = jsonBody?['error']?['code'] ?? jsonBody?['code'];
      if (errorCode == 'FEATURE_NOT_AVAILABLE') {
        final errMessage = jsonBody?['error']?['message']?.toString() ?? jsonBody?['message']?.toString();
        _logger.w('🔒 Received 403 — FEATURE_NOT_AVAILABLE');
        FeatureGuardService().handleFeatureLocked(errMessage);
      }
    }

    if (jsonBody != null) {
      return ApiResponse.fromJson(jsonBody, null);
    } else {
      // If response is not JSON, create a basic response
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(success: true, message: response.body);
      } else {
        return ApiResponse(
          success: false,
          error: ApiError(
            code: 'HTTP_${response.statusCode}',
            message: response.body.isNotEmpty
                ? response.body
                : 'Request failed with status ${response.statusCode}',
          ),
        );
      }
    }
  }

  /// Handle errors
  ApiResponse _handleError(dynamic error) {
    String message = 'An unexpected error occurred';
    String code = 'UNKNOWN_ERROR';

    if (error.toString().contains('SocketException') ||
        error.toString().contains('Connection refused')) {
      message = 'Cannot connect to server. Please check your connection.';
      code = 'CONNECTION_ERROR';
    } else if (error.toString().contains('TimeoutException')) {
      message = 'Request timed out. Please try again.';
      code = 'TIMEOUT_ERROR';
    }

    return ApiResponse(
      success: false,
      error: ApiError(code: code, message: message),
    );
  }

  /// Dispose the client
  void dispose() {
    _client.close();
  }
}
