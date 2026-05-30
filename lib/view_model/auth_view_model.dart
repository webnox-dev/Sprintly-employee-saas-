import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import '../helpers/common_strings.dart';
import '../screens/auth/login_screen.dart';
import '../services/local_storage_service.dart';

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import '../api/api_client.dart';
import '../api/endpoints/auth_api.dart';
import '../api/endpoints/employee_api.dart';
import '../services/firebase_notification_service.dart';
import 'dart:convert';

class AuthViewModel extends ChangeNotifier {
  final localStorage = LocalStorageService();
  final _authApi = AuthApi();
  final _apiClient = ApiClient();
  final _employeeApi = EmployeeApi();

  TextEditingController emailController = TextEditingController();
  TextEditingController pswController = TextEditingController(text: '123456');

  String _unverifiedEmail = '';
  String get unverifiedEmail => _unverifiedEmail;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Session management
  List<Map<String, dynamic>> _activeSessions = [];
  List<Map<String, dynamic>> get activeSessions => _activeSessions;
  bool _isLoadingSessions = false;
  bool get isLoadingSessions => _isLoadingSessions;

  // Workspace Discovery
  List<Map<String, dynamic>> _workspaces = [];
  List<Map<String, dynamic>> get workspaces => _workspaces;
  bool _isDiscoveringWorkspaces = false;
  bool get isDiscoveringWorkspaces => _isDiscoveringWorkspaces;
  Map<String, dynamic>? _selectedWorkspace;
  Map<String, dynamic>? get selectedWorkspace => _selectedWorkspace;

  void setSelectedWorkspace(Map<String, dynamic>? workspace) {
    _selectedWorkspace = workspace;
    notifyListeners();
  }

  // Cache user role to prevent repeated API calls
  String? _cachedUserRole;

  /// Clear the cached user role (call when user logs out or role changes)
  void clearUserRoleCache() {
    _cachedUserRole = null;
  }

  // Get current authenticated user
  // User? get currentUser => _supabaseClient?.auth.currentUser;

  // Get current session
  // Session? get currentSession => _supabaseClient?.auth.currentSession;

  /// Get detailed platform information (e.g., "Android 14", "iOS 17.2", "Web Chrome")
  Future<Map<String, String>> _getDetailedPlatformInfo() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String platformName = 'Unknown Platform';
    String deviceModel = 'Unknown Device';

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        platformName = 'Web';
        deviceModel =
            '${webInfo.browserName.name.toUpperCase()} on ${webInfo.platform}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        platformName = 'Android ${androidInfo.version.release}';
        deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        platformName = 'iOS ${iosInfo.systemVersion}';
        deviceModel = iosInfo.name;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        platformName = 'macOS ${macInfo.osRelease}';
        deviceModel = macInfo.model;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        platformName = 'Windows';
        deviceModel = windowsInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        platformName = 'Linux';
        deviceModel = linuxInfo.name;
      }
    } catch (e) {
      logger.e('Error getting platform info: $e');
      platformName = kIsWeb ? 'Web' : Platform.operatingSystem;
      deviceModel = 'Standard Device';
    }

    return {
      'platform': platformName,
      'device_name': deviceModel,
    };
  }

  // Get user display name (helper for UI)
  String? get userDisplayName => _currentUserProfile?.name;

  // Track backend auth state
  bool _isBackendAuthenticated = false;

  // Get user email
  String? get userEmail => _currentUserProfile?.email ?? localStorage.emailId;
  
  // Get organization name
  String get organizationName => _selectedWorkspace?['organization_name'] ?? localStorage.organizationName;

  // Check if user is authenticated (backend or Supabase)
  bool get isAuthenticated =>
      _isBackendAuthenticated || localStorage.userId.isNotEmpty;

  /// Get user role from profile
  Future<String?> getUserRole() async {
    if (_currentUserProfile?.role != null) {
      return _currentUserProfile!.role;
    }

    // Fallback to Supabase logic if profile not loaded
    // ... (existing Supabase logic)
    return _cachedUserRole;
  }

  /// Fetch and cache current user profile
  Future<void> fetchUserProfile() async {
    final details = await getCurrentEmployeeDetails();
    if (details != null) {
      _currentUserProfile = UserProfile(
        employeeId: details['employeeId'] ??
            details['employee_id'] ??
            localStorage.userId,
        name: details['employeeName'] ??
            details['employee_name'], // Handle camelCase from backend
        email: details['employeeCompanyEmail'] ??
            details['employee_company_email'] ??
            details['employeePersonalEmail'] ??
            details['employee_personal_email'],
        img: details['employeeImg'] ?? details['employee_img'],
        role: details['employeeRole'] ?? details['employee_role'],
        designation:
            details['employeeDesignation'] ?? details['employee_designation'],
      );

      // Update cached role
      if (_currentUserProfile?.role != null) {
        _cachedUserRole = _currentUserProfile!.role;
      }

      notifyListeners();
    } else {
      // Fallback or error handling if needed, but no Supabase fallback
    }
  }

  /// Fetch complete employee details for the current user
  Future<Map<String, dynamic>?> getCurrentEmployeeDetails() async {
    try {
      final userId = localStorage.userId; // Get stored Employee ID
      if (userId.isEmpty) {
        // Fallback to Supabase user ID if local storage empty (legacy)
        if (userId.isEmpty) return null;
        // If we only have Supabase user, we might not have employee ID easily
        // without querying Supabase 'employees' table first. Use existing logic.
        return null;
      }

      logger.i('Fetching employee details for ID: $userId');
      final response = await _employeeApi.getEmployeeById(userId);

      if (response.success && response.data != null) {
        logger.i('Employee details fetched successfully via API');
        return response.data as Map<String, dynamic>;
      } else {
        logger
            .w('Failed to fetch employee details via API: ${response.message}');
        return null;
      }
    } catch (e) {
      logger.e('Error fetching employee details: $e');
      return null;
    }
  }

  // Helper for legacy Supabase fetch
  // Helper for legacy Supabase fetch - REMOVED
  // Future<Map<String, dynamic>?> _fetchEmployeeFromSupabase() async { ... }

  Future<void> checkAuthState() async {
    try {
      // 1. Check Local Storage for Backend Token
      final token = localStorage.accessToken;
      final userId = localStorage.userId;

      if (token.isNotEmpty) {
        logger.i('Found backend token in local storage');
        _apiClient.setAuthToken(token);

        // Validate by fetching profile
        if (userId.isNotEmpty) {
          await fetchUserProfile();
          if (_currentUserProfile != null) {
            _isBackendAuthenticated = true;
            notifyListeners();
            // We are good!
          }
        }
      }

      // 2. Check Supabase Session (for Chat/Legacy) - REMOVED

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      logger.e('Error checking auth state: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Send password reset OTP (Step 1)
  /// Returns {success, message}
  Future<Map<String, dynamic>> sendPasswordResetOtp(
      String email, String phoneNumber) async {
    try {
      logger.i('Sending password reset OTP for email: $email');
      final response = await _authApi.sendPasswordResetOtp(
        email: email,
        phoneNumber: phoneNumber,
      );

      if (response.success) {
        return {'success': true, 'message': response.message};
      } else {
        return {
          'success': false,
          'message': response.error?.message ?? 'Failed to send OTP'
        };
      }
    } catch (e) {
      logger.e('Error sending password reset OTP: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Verify password reset OTP (Step 2)
  Future<Map<String, dynamic>> verifyPasswordResetOtp(
      String email, String otp) async {
    try {
      logger.i('Verifying password reset OTP for email: $email');
      final response = await _authApi.verifyPasswordResetOtp(
        email: email,
        otp: otp,
      );

      if (response.success) {
        return {'success': true, 'message': response.message};
      } else {
        return {
          'success': false,
          'message': response.error?.message ?? 'Invalid OTP'
        };
      }
    } catch (e) {
      logger.e('Error verifying password reset OTP: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Resend password reset OTP
  Future<Map<String, dynamic>> resendPasswordResetOtp(String email) async {
    try {
      logger.i('Resending OTP for email: $email');
      final response = await _authApi.resendPasswordResetOtp(email: email);

      if (response.success) {
        return {'success': true, 'message': response.message};
      } else {
        return {
          'success': false,
          'message': response.error?.message ?? 'Failed to resend OTP'
        };
      }
    } catch (e) {
      logger.e('Error resending OTP: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Reset password (Step 3 - Final)
  Future<Map<String, dynamic>> resetPassword(
      String email, String newPassword) async {
    try {
      logger.i('Resetting password for email: $email');
      final response = await _authApi.resetPassword(
        email: email,
        newPassword: newPassword,
      );

      if (response.success) {
        return {'success': true, 'message': response.message};
      } else {
        return {
          'success': false,
          'message': response.error?.message ?? 'Failed to reset password'
        };
      }
    } catch (e) {
      logger.e('Error resetting password: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Change password for authenticated user
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final email = userEmail;
      if (email == null) {
        logger.e('Cannot change password: user email is null');
        return false;
      }

      logger.i('Attempting to change password for $email');
      final response = await _authApi.changePassword(
        email: email,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (response.success) {
        logger.i('Password changed successfully');
        // Update local stored password if login succeeded with current email/password
        await localStorage.saveUserLogin(
          accessToken: localStorage.accessToken,
          userId: localStorage.userId,
          emailId: localStorage.emailId,
          password: newPassword,
        );
        return true;
      } else {
        logger.e('Failed to change password: ${response.message}');
        return false;
      }
    } catch (e) {
      logger.e('Error changing password: $e');
      return false;
    }
  }

  /// Get user avatar URL
  String? get userAvatar {
    // Return avatar from profile if available
    return _currentUserProfile?.img;
  }

  /// Get comprehensive user metadata
  // Map<String, dynamic>? get userMetadata => currentUser?.userMetadata;

  /// Get user creation date
  DateTime? get userCreatedAt {
    return null;
  }

  /// Get user last sign in date
  DateTime? get userLastSignInAt {
    return null;
  }

  /// Get user provider (authentication method)
  String? get userProvider {
    return 'email';
  }

  /// Check if user email is confirmed
  bool get isEmailConfirmed => true;

  /// Check if user phone is confirmed
  bool get isPhoneConfirmed => true;

  /// Get all available user properties for debugging
  Map<String, dynamic> getAllUserProperties() {
    return {};
  }

  /// Update user metadata with employee information
  /// Update user metadata with employee information
  Future<void> updateUserMetadataWithEmployeeData(
      Map<String, dynamic> employeeData) async {
    // Supabase metadata update removed
  }

  // Format date for display
  String formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  // Format date with time for display (Converts UTC to Local)
  String formatDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    return '$day/$month/${localDate.year} $hour:$minute';
  }

  // Update user metadata
  Future<void> updateUserMetadata(Map<String, dynamic> metadata) async {
    // Supabase metadata update removed
  }

  /// Fetch active sessions for the current user
  Future<void> fetchSessions() async {
    if (!isAuthenticated) return;

    _isLoadingSessions = true;
    notifyListeners();

    try {
      final response = await _authApi.getSessions();
      if (response.success && response.data != null) {
        final List<dynamic> data = response.data as List<dynamic>;
        _activeSessions = data.map((e) => e as Map<String, dynamic>).toList();
        logger.i('Fetched ${_activeSessions.length} active sessions');
      } else {
        logger.e('Failed to fetch sessions: ${response.message}');
      }
    } catch (e) {
      logger.e('Error fetching sessions: $e');
    } finally {
      _isLoadingSessions = false;
      notifyListeners();
    }
  }

  /// Logout from a specific device by revoking its session
  Future<bool> logoutFromDevice(String sessionId) async {
    try {
      final response = await _authApi.revokeSession(sessionId);
      if (response.success) {
        await fetchSessions(); // Refresh list
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error revoking session: $e');
      return false;
    }
  }

  /// Logout from a specific device by revoking its session using credentials
  Future<bool> logoutFromDeviceWithCredentials(String sessionId) async {
    try {
      final response = await _authApi.revokeSessionWithCredentials(
        email: emailController.text,
        password: pswController.text,
        sessionId: sessionId,
      );
      if (response.success) {
        // We cannot call fetchSessions() here because we are not fully authenticated yet.
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error revoking session with credentials: $e');
      return false;
    }
  }

  /// Request session OTP to set main device or logout from main device
  Future<Map<String, dynamic>> requestSessionOTP(String action) async {
    try {
      logger.i('Requesting session OTP for action: $action');
      final response = await _authApi.requestSessionOtp(action);

      if (response.success) {
        return {'success': true, 'message': response.message};
      } else {
        return {
          'success': false,
          'message': response.error?.message ?? 'Failed to request OTP'
        };
      }
    } catch (e) {
      logger.e('Error requesting session OTP: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Verify main device logout OTP
  Future<Map<String, dynamic>> verifyMainLogout(String otp) async {
    try {
      logger.i('Verifying main device logout OTP');
      final response = await _authApi.verifyMainLogout(otp);

      if (response.success) {
        await fetchSessions(); // Refresh list on success
        return {'success': true, 'message': response.message};
      } else {
        return {
          'success': false,
          'message': response.error?.message ?? 'Failed to verify OTP'
        };
      }
    } catch (e) {
      logger.e('Error verifying main logout OTP: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Set a session as the main device using an OTP
  Future<Map<String, dynamic>> setMainDevice({
    required String sessionId,
    required String otp,
  }) async {
    try {
      logger.i('Setting session $sessionId as main device');
      final response = await _authApi.setMainDevice(
        sessionId: sessionId,
        otp: otp,
      );

      if (response.success) {
        await fetchSessions(); // Refresh list on success
        return {'success': true, 'message': response.message};
      } else {
        return {
          'success': false,
          'message': response.error?.message ?? 'Failed to set main device'
        };
      }
    } catch (e) {
      logger.e('Error setting main device: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Logout from all other devices
  Future<bool> logoutFromAllOtherDevices() async {
    try {
      final response = await _authApi.revokeAllOtherSessions();

      if (response.success) {
        // Refresh sessions list
        await fetchSessions();
        return true;
      }
      return false;
    } catch (e) {
      logger.e('Error revoking all other sessions: $e');
      return false;
    }
  }

  // Check if user is admin/manager
  Future<bool> isAdminOrManager() async {
    try {
      final role = await getUserRole();
      if (role == null) return false;

      final roleLower = role.toLowerCase();
      return roleLower.contains('admin') ||
          roleLower.contains('manager') ||
          roleLower.contains('supervisor');
    } catch (e) {
      logger.e('Error checking admin status: $e');
      return false;
    }
  }

  // Helper class for UI binding
  UserProfile? _currentUserProfile;
  UserProfile? get currentUserProfile => _currentUserProfile;

  /// Update current employee profile fields in employees table
  Future<bool> updateEmployeeProfile(Map<String, dynamic> updates) async {
    try {
      if (!isAuthenticated) return false;

      final userId = localStorage.userId;
      if (userId.isEmpty) return false;

      // Whitelist updatable fields only
      final allowedKeys = {
        'employee_name',
        'employee_phone_num',
        'employee_personal_email',
        'employee_company_email',
        'employee_address',
        'employee_designation',
        'employee_role',
        'employee_gender',
        'employee_qualification',
        'employee_blood_group',
        'employee_emergency_contact_number',
        'employee_dob',
        'employee_img',
      };

      final Map<String, dynamic> payload = {};
      for (final entry in updates.entries) {
        if (allowedKeys.contains(entry.key)) {
          payload[entry.key] = entry.value;
        }
      }

      if (payload.isEmpty) {
        return true; // nothing to update
      }

      logger.i('Updating employee profile via API for $userId');
      final response = await _employeeApi.updateEmployee(userId, payload);

      if (response.success) {
        logger.i('Employee profile updated successfully via API');

        // Refresh local profile data
        await fetchUserProfile();
        notifyListeners();
        return true;
      } else {
        logger.e('Failed to update employee profile: ${response.message}');
        return false;
      }
    } catch (e) {
      logger.e('Error updating employee profile: $e');
      return false;
    }
  }

  Future<String> login() async {
    return loginWithBackend();
  }

  /// Verify login OTP
  Future<Map<String, dynamic>> verifyOtp(String otp) async {
    try {
      logger.i('Verifying login OTP: $otp');
      final platformInfo = await _getDetailedPlatformInfo();
      final response = await _authApi.verifyOtp(
        email: emailController.text,
        otp: otp,
        deviceName: platformInfo['device_name'],
        platform: platformInfo['platform'],
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] ?? data['data']?['token'];
        final employeeId =
            data['employeeId'] ?? data['data']?['employeeId'] ?? '';

        if (token != null) {
          // Save to local storage
          await localStorage.saveUserLogin(
            accessToken: token,
            userId: employeeId,
            emailId: emailController.text,
            password: pswController.text,
            organizationName: organizationName,
            planFeatures: data['plan_features'] != null ? jsonEncode(data['plan_features']) : null,
          );

          // Set token in API client
          _apiClient.setAuthToken(token);

          // Fetch user profile
          await fetchUserProfile();

          // Notify listeners
          notifyListeners();

          return {'success': true, 'message': 'Login successful'};
        }
      }
      return {
        'success': false,
        'message': response.error?.message ?? 'Verification failed'
      };
    } catch (e) {
      logger.e('Error verifying login OTP: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  Map<String, dynamic>? _sessionLimitData;
  Map<String, dynamic>? get sessionLimitData => _sessionLimitData;

  /// Discover workspaces associated with an email
  Future<List<Map<String, dynamic>>> discoverWorkspaces(String email) async {
    _isDiscoveringWorkspaces = true;
    _workspaces = [];
    notifyListeners();

    try {
      logger.i('Discovering workspaces for $email');
      final response = await _authApi.discoverWorkspaces(email);

      if (response.success && response.data != null) {
        if (response.data is List) {
          _workspaces = List<Map<String, dynamic>>.from(response.data);
        } else if (response.data is Map && response.data['data'] is List) {
          _workspaces = List<Map<String, dynamic>>.from(response.data['data']);
        }
        logger.i('Found ${_workspaces.length} workspaces');
        return _workspaces;
      } else {
        logger.e('Failed to discover workspaces: ${response.message}');
        return [];
      }
    } catch (e) {
      logger.e('Error discovering workspaces: $e');
      return [];
    } finally {
      _isDiscoveringWorkspaces = false;
      notifyListeners();
    }
  }

  /// Login using custom backend API
  Future<String> loginWithBackend({String? orgId}) async {
    String errorMessage = '';
    try {
      logger.i('Attempting login with backend API...');

      final platformInfo = await _getDetailedPlatformInfo();

      final response = await _authApi.login(
        email: emailController.text,
        password: pswController.text,
        orgId: orgId ?? _selectedWorkspace?['organization_id'],
        deviceName: platformInfo['device_name'],
        platform: platformInfo['platform'],
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        print('DEBUG: Login response data: $data');

        // Handle EMAIL_NOT_VERIFIED case
        if (data['code'] == 'EMAIL_NOT_VERIFIED' ||
            (data['data'] != null &&
                data['data']['code'] == 'EMAIL_NOT_VERIFIED')) {
          print('DEBUG: Detected EMAIL_NOT_VERIFIED');
          logger.i('Email not verified. Redirecting to verification...');
          _unverifiedEmail = data['details']?['email'] ??
              data['data']?['details']?['email'] ??
              emailController.text.trim();
          return 'EMAIL_NOT_VERIFIED';
        }

        // Handle SESSION_LIMIT_EXCEEDED case
        if (data['code'] == 'SESSION_LIMIT_EXCEEDED' ||
            (data['data'] != null &&
                data['data']['code'] == 'SESSION_LIMIT_EXCEEDED')) {
          logger.i('Session limit exceeded. Prompting user...');
          _sessionLimitData = data['data'] ?? data;
          return 'SESSION_LIMIT_EXCEEDED';
        }

        // Backend response structure: { success, data: { token, employeeId, email, role } }
        // The ApiResponse.fromJson extracts 'data' into response.data, so we access directly

        // Handle Maximum Sessions Reached
        if (data.containsKey('active_sessions') &&
            data['active_sessions'] is List) {
          logger.w(
              'Max sessions reached for user: ${data["current_count"]}/${data["max_sessions"]}');
          return 'Maximum active devices reached (${data["max_sessions"]}). Please log out from another device to continue.';
        }

        final token = data['token'] ?? data['data']?['token'];
        // Backend uses camelCase 'employeeId', not 'employee_id'
        final employeeId =
            data['employeeId'] ?? data['data']?['employeeId'] ?? '';

        logger.i('Login successful via backend API');
        logger.i('Employee ID from response: $employeeId');

        if (token != null) {
          // Save to local storage
          await localStorage.saveUserLogin(
            accessToken: token,
            userId: employeeId,
            emailId: emailController.text,
            password: pswController.text,
            organizationName: organizationName,
            planFeatures: data['plan_features'] != null ? jsonEncode(data['plan_features']) : null,
          );

          // Set token in API client
          _apiClient.setAuthToken(token);

          // Fetch user profile
          await fetchUserProfile();

          // Notify listeners
          notifyListeners();

          logger.i('Login complete for: ${emailController.text}');
          return ''; // Success
        } else {
          errorMessage = 'Login failed: No token received';
        }
      } else {
        // Check for EMAIL_NOT_VERIFIED in error response
        if (response.error?.code == 'EMAIL_NOT_VERIFIED') {
          logger.i('Email not verified from error code. Redirecting...');
          _unverifiedEmail =
              response.error?.details?['email'] ?? emailController.text.trim();
          return 'EMAIL_NOT_VERIFIED';
        }
        // Check for SESSION_LIMIT_EXCEEDED in error response
        if (response.error?.code == 'SESSION_LIMIT_EXCEEDED') {
          logger.i('Session limit exceeded from error code. Prompting user...');
          _sessionLimitData = response.error?.details;
          return 'SESSION_LIMIT_EXCEEDED';
        }
        errorMessage = response.error?.message ?? 'Login failed';
        logger.e('Login failed: $errorMessage');
      }
    } catch (e, st) {
      logger.e('Unexpected error during login: $e\n$st');
      errorMessage = 'An unexpected error occurred. Please try again.';
    }

    return errorMessage;
  }

  /// Verify Email OTP (Step after login if email not verified)
  Future<Map<String, dynamic>> verifyEmailOtp(String email, String otp) async {
    try {
      logger.i('Verifying email OTP for email: $email');
      final platformInfo = await _getDetailedPlatformInfo();
      final response = await _authApi.verifyEmailEmployee(
        email: email,
        otp: otp,
        deviceName: platformInfo['device_name'],
        platform: platformInfo['platform'],
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final token = data['token'] ?? data['data']?['token'];
        final employeeId =
            data['employeeId'] ?? data['data']?['employeeId'] ?? '';

        if (token != null) {
          // Save to local storage
          await localStorage.saveUserLogin(
            accessToken: token,
            userId: employeeId,
            emailId: email,
            password: pswController.text, // Store the password used for login
            planFeatures: data['plan_features'] != null ? jsonEncode(data['plan_features']) : null,
          );

          // Set token in API client
          _apiClient.setAuthToken(token);

          // Fetch user profile
          await fetchUserProfile();

          // Notify listeners
          notifyListeners();

          return {'success': true, 'message': 'Email verified successfully'};
        }
      }
      return {
        'success': false,
        'message': response.error?.message ?? 'Verification failed'
      };
    } catch (e) {
      logger.e('Error verifying email OTP: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Resend Verification OTP
  Future<Map<String, dynamic>> resendVerificationOtp(String email) async {
    try {
      logger.i('Resending verification OTP for email: $email');
      final response = await _authApi.resendVerificationOtp(email: email);

      if (response.success) {
        return {'success': true, 'message': response.message};
      } else {
        return {
          'success': false,
          'message': response.error?.message ?? 'Failed to resend OTP'
        };
      }
    } catch (e) {
      logger.e('Error resending verification OTP: $e');
      return {'success': false, 'message': 'An unexpected error occurred'};
    }
  }

  /// Logout from backend (NEW - migrated from Supabase)
  Future<void> logoutFromBackend() async {
    try {
      // Clear cached role first
      clearUserRoleCache();

      // Deactivate this device's FCM token on the backend
      try {
        final fcmToken = await FirebaseNotificationService.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          // Pass requiresAuth: false handled in AuthApi now
          await _authApi.removeFcmToken(fcmToken: fcmToken);
          logger.i('FCM token deactivated for this device');
        }
      } catch (e) {
        logger.w('Failed to deactivate FCM token: $e');
      }

      // Call backend logout
      try {
        await _authApi.logout();
      } catch (e) {
        logger.w('Backend logout call failed: $e');
      }

      // ALWAYS clear local state even if backend calls fail
      _apiClient.clearAuthToken();
      await localStorage.clearUserLogin();

      // Notify listeners to update UI immediately
      notifyListeners();

      logger.i('Logout from backend successful (local state cleared)');
    } catch (e) {
      logger.e('Logout error: $e');
      // Even if there's an error, clear local storage and notify
      _apiClient.clearAuthToken();
      await localStorage.clearUserLogin();
      clearUserRoleCache();
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      // Clear cached role first
      clearUserRoleCache();

      // Note: Presence is now handled by WebSocket disconnection
      // No need to manually set offline status

      // Sign out from Supabase - this should clear currentUser

      // Clear local storage
      await localStorage.clearUserLogin();

      // Force clear any cached user data
      // The currentUser getter will return null after signOut

      // Notify listeners to update UI immediately
      notifyListeners();

      // Additional delay to ensure Supabase state is cleared
      await Future.delayed(const Duration(milliseconds: 50));

      logger.i('Logout successful');
    } catch (e) {
      logger.e('Logout error: $e');
      // Even if there's an error, clear local storage and notify
      await localStorage.clearUserLogin();
      clearUserRoleCache();
      notifyListeners();
    }
  }

  // Method to handle logout with navigation
  Future<void> logoutWithNavigation(BuildContext context) async {
    try {
      await logout();

      // Navigate to login screen and clear all routes
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      logger.e('Logout with navigation error: $e');
      // Even if logout fails, still navigate to login
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> logoutWithAppNavigation(BuildContext context) async {
    try {
      // Deactivate this device's FCM token on the backend
      try {
        final fcmToken = await FirebaseNotificationService.getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _authApi.removeFcmToken(fcmToken: fcmToken);
          logger.i('FCM token deactivated for this device');
        }
      } catch (e) {
        logger.w('Failed to deactivate FCM token: $e');
      }

      // Clear state first before navigation
      clearUserRoleCache();
      await localStorage.clearUserLogin();

      // Notify listeners immediately to update UI
      notifyListeners();

      // Small delay to ensure state is cleared
      await Future.delayed(const Duration(milliseconds: 50));

      // Navigate directly to login screen and clear all routes
      // Use rootNavigator to ensure we navigate from the top level
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }

      logger.i('Logout and navigation successful');
    } catch (e) {
      logger.e('Logout with app navigation error: $e');
      // Even if logout fails, clear storage and navigate to login
      await localStorage.clearUserLogin();
      clearUserRoleCache();
      notifyListeners();

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // Listen to auth state changes
  void initializeAuthListener() {
    // 2. Check Supabase Session (for Chat/Legacy) - REMOVED
    // Listener removed as we are fully migrating to Backend Auth

    // Mark as initialized
    _isInitialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    pswController.dispose();
    super.dispose();
  }
}

class UserProfile {
  final String? employeeId;
  final String? name;
  final String? email;
  final String? img;
  final String? role;
  final String? designation;

  UserProfile({
    this.employeeId,
    this.name,
    this.email,
    this.img,
    this.role,
    this.designation,
  });
}
