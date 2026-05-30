import 'package:cross_local_storage/cross_local_storage.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String isLoggedInKey = 'isLoggedIn';
  static const String accessTokenKey = 'accessToken';
  static const String userIdKey = 'userId';
  static const String emailIdKey = 'emailId';
  static const String passwordKey = 'passwordKey';
  static const String employeeIdKey = 'employeeId'; // Added for backend API
  static const String organizationNameKey = 'organizationName'; // Added for dynamic header
  static const String planFeaturesKey = 'planFeatures'; // Added for plan-based feature restrictions
  static const String chatThemeKey = 'chatTheme';
  static const String conversationThemesKey = 'conversationThemes';
  static const String _notifyOnAssignmentKey = 'notify_on_assignment';
  static const String notifyOnMessageKey = 'notifyOnMessage';
  static const String _notifyOnUpdateKey = 'notify_on_update';
  static const String _useGPSKey = 'use_gps_attendance';
  static const String _useIPKey = 'use_ip_attendance';

  // Timer persistence keys
  static const String timerStartTimeKey = 'timerStartTime';
  static const String clockedInTaskIdKey = 'clockedInTaskId';
  static const String isTimerRunningKey = 'isTimerRunning';

  late LocalStorageInterface storage;

  Future<void> init() async {
    storage = await LocalStorage.getInstance();
  }

  Future saveUserLogin(
      {required String accessToken,
      required String userId,
      required String emailId,
      required String password,
      String? organizationName,
      String? planFeatures}) async {
    await storage.setString(userIdKey, userId);
    await storage.setString(accessTokenKey, accessToken);
    await storage.setString(emailIdKey, emailId);
    await storage.setString(passwordKey, password);
    if (organizationName != null) {
      await storage.setString(organizationNameKey, organizationName);
    }
    if (planFeatures != null) {
      await storage.setString(planFeaturesKey, planFeatures);
    }
    await storage.setBool(isLoggedInKey, true);
  }

  Future<void> clearUserLogin() async {
    await storage.remove(userIdKey);
    await storage.remove(accessTokenKey);
    await storage.remove(emailIdKey);
    await storage.remove(passwordKey);
    await storage.remove(organizationNameKey);
    await storage.remove(planFeaturesKey);
    await storage.setBool(isLoggedInKey, false);
  }

  String get accessToken => storage.getString(accessTokenKey) ?? '';
  String get userId => storage.getString(userIdKey) ?? '';
  String get emailId => storage.getString(emailIdKey) ?? '';
  String get password => storage.getString(passwordKey) ?? '';
  String get organizationName => storage.getString(organizationNameKey) ?? '';
  String get planFeatures => storage.getString(planFeaturesKey) ?? '{}';
  bool get isLoggedIn => storage.getBool(isLoggedInKey) ?? false;

  // Employee ID for backend API calls
  String get employeeId => storage.getString(employeeIdKey) ?? '';
  Future<void> saveEmployeeId(String employeeId) async {
    await storage.setString(employeeIdKey, employeeId);
  }

  // Timer persistence methods
  Future<void> saveTimerState({
    required DateTime startTime,
    required String taskId,
    required bool isRunning,
  }) async {
    await storage.setString(timerStartTimeKey, startTime.toIso8601String());
    await storage.setString(clockedInTaskIdKey, taskId);
    await storage.setBool(isTimerRunningKey, isRunning);
  }

  Future<void> clearTimerState() async {
    await storage.remove(timerStartTimeKey);
    await storage.remove(clockedInTaskIdKey);
    await storage.remove(isTimerRunningKey);
  }

  DateTime? get timerStartTime {
    final startTimeString = storage.getString(timerStartTimeKey);
    if (startTimeString != null && startTimeString.isNotEmpty) {
      try {
        return DateTime.parse(startTimeString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String? get clockedInTaskId => storage.getString(clockedInTaskIdKey);
  bool get isTimerRunning => storage.getBool(isTimerRunningKey) ?? false;

  static const String lastNotificationCheckTimeKey =
      'lastNotificationCheckTime';

  Duration get elapsedTime {
    final startTime = timerStartTime;
    if (startTime != null && isTimerRunning) {
      return DateTime.now().difference(startTime);
    }
    return Duration.zero;
  }

  // Notification center check time persistence
  Future<void> saveLastNotificationCheckTime(DateTime time) async {
    await storage.setString(
        lastNotificationCheckTimeKey, time.toIso8601String());
  }

  DateTime? get lastNotificationCheckTime {
    final timeString = storage.getString(lastNotificationCheckTimeKey);
    if (timeString != null && timeString.isNotEmpty) {
      try {
        return DateTime.parse(timeString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Chat Theme persistence
  String get chatTheme => storage.getString(chatThemeKey) ?? 'classic_blue';
  Future<void> saveChatTheme(String themeId) async {
    await storage.setString(chatThemeKey, themeId);
  }

  String get conversationThemes =>
      storage.getString(conversationThemesKey) ?? '{}';
  Future<void> saveConversationThemes(String themesJson) async {
    await storage.setString(conversationThemesKey, themesJson);
  }

  // Push notification granular preferences (default true)
  bool get notifyOnAssignment =>
      storage.getBool(_notifyOnAssignmentKey) ?? true;
  Future<void> saveNotifyOnAssignment(bool enabled) async {
    await storage.setBool(_notifyOnAssignmentKey, enabled);
  }

  bool get notifyOnMessage => storage.getBool(notifyOnMessageKey) ?? true;
  Future<void> saveNotifyOnMessage(bool enabled) async {
    await storage.setBool(notifyOnMessageKey, enabled);
  }

  bool get notifyOnUpdate => storage.getBool(_notifyOnUpdateKey) ?? true;
  Future<void> saveNotifyOnUpdate(bool enabled) async {
    await storage.setBool(_notifyOnUpdateKey, enabled);
  }

  bool get useGPS => storage.getBool(_useGPSKey) ?? true;
  Future<void> saveUseGPS(bool enabled) async {
    await storage.setBool(_useGPSKey, enabled);
  }

  bool get useIP => storage.getBool(_useIPKey) ?? true;
  Future<void> saveUseIP(bool enabled) async {
    await storage.setBool(_useIPKey, enabled);
  }
}
