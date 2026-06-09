import 'dart:io';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:webnox_taskops/api/endpoints/auth_api.dart';
import 'package:webnox_taskops/config/fcm_config.dart';
import 'package:webnox_taskops/config/web_notification_stub.dart'
    if (dart.library.html) 'package:webnox_taskops/config/web_notification_web.dart'
    as web_notification;
import 'package:webnox_taskops/services/local_storage_service.dart';
import '../../firebase_options.dart';

/// Firebase Cloud Messaging Notification Service
class FirebaseNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static bool _initialized = false;
  static String? _fcmToken;

  // Notification channel for Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'webnox_sprintly_notifications',
    'Rathz Notifications',
    description: 'Notifications from Rathz',
    importance: Importance.high,
    playSound: true,
  );

  /// Initialize Firebase and notification services
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Firebase if not already done
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } catch (e) {
          // Fallback if options not generated yet
          await Firebase.initializeApp();
        }
      }

      // Configure local notifications
      await _configureLocalNotifications();

      // Create notification channel for Android
      if (!kIsWeb && Platform.isAndroid) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);
      }

      // Configure message handlers
      _configureMessageHandlers();

      _initialized = true;
      debugPrint('✅ Firebase Notification Service initialized');

      // Deferred setup
      Future.delayed(const Duration(seconds: 2), () {
        _initializeDeferred();
      });
    } catch (e) {
      debugPrint('❌ Failed to initialize Firebase Notification Service: $e');
    }
  }

  static Future<void> _initializeDeferred() async {
    try {
      await _requestPermissions();
      await _getToken();
    } catch (e) {
      debugPrint('❌ Failed to complete deferred notification setup: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('Notification permission: ${settings.authorizationStatus}');
  }

  static Future<void> _configureLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  static void _configureMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Terminated state
    _checkInitialMessage();
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 Foreground message: ${message.notification?.title}');

    final type = message.data['type']?.toString();
    final localStorage = LocalStorageService();

    bool shouldShow = true;
    switch (type) {
      case 'chat_message':
      case 'chat':
        shouldShow = localStorage.notifyOnMessage;
        break;
      case 'task':
      case 'task_card':
      case 'project':
        shouldShow = localStorage.notifyOnAssignment;
        break;
      case 'leave':
      case 'wfh':
      case 'permission':
      default:
        shouldShow = localStorage.notifyOnUpdate;
    }

    if (!shouldShow) {
      debugPrint(
          '🔕 Notification suppressed due to granular user settings (type: $type).');
      return;
    }

    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      if (kIsWeb) {
        web_notification.showWebNotification(
          notification.title ?? 'Rathz',
          notification.body ?? '',
          tag: message.messageId,
        );
      } else if (android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title ?? 'Rathz',
          notification.body ?? '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: android.smallIcon ?? '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
              color: const Color(0xFF6366F1),
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: message.data.toString(),
        );
      }
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 Notification tapped: ${message.data}');
    _navigateBasedOnData(message.data);
  }

  static Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    // Parse payload and navigate
    if (response.payload != null) {
      try {
        // Parse the payload map string
        final payloadStr = response.payload!;
        // Simple parsing of {key: value, key2: value2} format
        final Map<String, dynamic> data = {};
        final content = payloadStr.replaceAll('{', '').replaceAll('}', '');
        final pairs = content.split(', ');
        for (final pair in pairs) {
          final parts = pair.split(': ');
          if (parts.length == 2) {
            data[parts[0].trim()] = parts[1].trim();
          }
        }
        _navigateBasedOnData(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Navigate based on notification data
  static void _navigateBasedOnData(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString();
      final conversationId = data['conversationId']?.toString();

      debugPrint(
          '📍 Navigation data - type: $type, conversationId: $conversationId');

      // Using Future.delayed to ensure the app is fully loaded
      Future.delayed(const Duration(milliseconds: 500), () {
        _performNavigation(type, conversationId);
      });
    } catch (e) {
      debugPrint('Error navigating from notification: $e');
    }
  }

  static void _performNavigation(String? type, String? conversationId) {
    try {
      switch (type) {
        case 'chat_message':
        case 'chat':
          // Navigate to dashboard with TeamSync tab
          debugPrint('🔔 Navigating to TeamSync for chat notification');
          Get.offAllNamed('/dashboard', arguments: {
            'openChat': true,
            'conversationId': conversationId,
          });
          break;
        case 'task':
        case 'task_card':
          debugPrint('🔔 Navigating to Kanban for task notification');
          Get.offAllNamed('/kanban');
          break;
        case 'project':
          debugPrint('🔔 Navigating to Projects');
          Get.offAllNamed('/projects');
          break;
        case 'leave':
        case 'wfh':
        case 'permission':
          debugPrint('🔔 Navigating to Reports');
          Get.offAllNamed('/reports');
          break;
        default:
          debugPrint(
              '🔔 Unknown notification type: $type, navigating to dashboard');
          Get.offAllNamed('/dashboard');
      }
    } catch (e) {
      debugPrint('Error performing navigation: $e');
    }
  }

  static Future<String?> _getToken() async {
    try {
      if (kIsWeb) {
        if (FcmConfig.vapidKey.isNotEmpty) {
          _fcmToken = await _messaging.getToken(vapidKey: FcmConfig.vapidKey);
        } else {
          _fcmToken = await _messaging.getToken();
        }
      } else {
        _fcmToken = await _messaging.getToken();
      }

      if (_fcmToken != null) {
        debugPrint('📲 FCM Token: $_fcmToken');
      }
      return _fcmToken;
    } catch (e) {
      debugPrint('❌ Failed to get FCM token: $e');
      return null;
    }
  }

  static Future<String?> getToken() async {
    if (_fcmToken != null) return _fcmToken;
    return await _getToken();
  }

  /// Save FCM token to backend
  static Future<bool> saveTokenToBackend() async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final localStorage = LocalStorageService();
      final userId = localStorage.userId;

      if (userId.isEmpty) {
        debugPrint('Cannot save FCM token: User not logged in');
        return false;
      }

      final authApi = AuthApi();
      String deviceType;
      String platformName;
      String deviceName;

      if (kIsWeb) {
        deviceType = 'web';
        platformName = 'Web';
        deviceName = 'Web Browser';
      } else if (Platform.isAndroid) {
        deviceType = 'android';
        platformName = 'Android';
        try {
          final androidInfo = await _deviceInfo.androidInfo;
          deviceName =
              '${androidInfo.brand} ${androidInfo.model}'; // e.g. "Samsung SM-S928B"
        } catch (_) {
          deviceName = 'Android Device';
        }
      } else if (Platform.isIOS) {
        deviceType = 'ios';
        platformName = 'iOS';
        try {
          final iosInfo = await _deviceInfo.iosInfo;
          deviceName = iosInfo.name; // e.g. "John's iPhone 15 Pro"
        } catch (_) {
          deviceName = 'iPhone';
        }
      } else {
        deviceType = 'unknown';
        platformName = Platform.operatingSystem;
        deviceName = Platform.operatingSystem;
      }

      final response = await authApi.saveFcmToken(
        userId: userId,
        userType: 'Employee',
        fcmToken: token,
        deviceType: deviceType,
        deviceName: deviceName,
        platform: platformName,
      );

      if (response.success) {
        debugPrint('✅ FCM token saved to backend (device: $deviceName)');
        return true;
      } else {
        debugPrint('❌ Failed to save FCM token: ${response.message}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
      return false;
    }
  }

  /// Subscribe/Unsubscribe helpers
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}

/// Background handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.messageId}');
}
