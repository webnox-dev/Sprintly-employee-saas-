
import 'package:get/get.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as provider;
import 'package:toastification/toastification.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; // For usePathUrlStrategy
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webnox_taskops/theme/app_theme.dart';
import 'package:webnox_taskops/screens/splash_screen.dart';
import 'package:webnox_taskops/services/global_provider.dart';
import 'package:webnox_taskops/providers/theme_provider.dart';
import 'package:webnox_taskops/screens/auth/login_screen.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:webnox_taskops/services/local_storage_service.dart';

import 'package:webnox_taskops/screens/dashboard/dashboard_screen.dart';
import 'package:webnox_taskops/screens/dashboard/recreated_dashboard_screen.dart';
import 'package:webnox_taskops/screens/auth/otp_verification_screen.dart';

import 'package:webnox_taskops/view_model/team_sync_view_model.dart';
import 'package:webnox_taskops/api/api_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:webnox_taskops/services/firebase_notification_service.dart';
import 'package:webnox_taskops/services/session_expiry_service.dart';

class InitApp extends StatefulWidget {
  const InitApp({super.key});

  @override
  State<InitApp> createState() => _InitAppState();
}

class _InitAppState extends State<InitApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('🔄 App lifecycle state changed: $state');

    // Handle presence based on app lifecycle
    // Note: We use a delayed callback to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePresenceLifecycle(state);
    });

    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed - triggering timer state sync');
      _handleDeepLink();
      // The actual sync will be handled by HomeScreen's lifecycle observer
    }
  }

  /// Handle presence updates based on app lifecycle (WebSocket-based)
  void _handlePresenceLifecycle(AppLifecycleState state) {
    try {
      // Get the TeamSyncViewModel from the navigation context
      final context = Get.context;
      if (context == null) return;

      final teamSyncVM =
          provider.Provider.of<TeamSyncViewModel>(context, listen: false);

      switch (state) {
        case AppLifecycleState.resumed:
          // App is in foreground - reconnect WebSocket if needed
          print('🟢 App resumed - ensuring WebSocket connection');
          if (!teamSyncVM.isConnected) {
            teamSyncVM.connect();
          }
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
          // App is in background - WebSocket will handle presence automatically
          print('⚪ App paused/hidden - WebSocket handles presence');
          break;
        case AppLifecycleState.inactive:
          // App is inactive (e.g., phone call) - keep current status
          print('🟡 App inactive - keeping current status');
          break;
      }
    } catch (e) {
      print('⚠️ Error handling presence lifecycle: $e');
    }
  }

  void _initDeepLinks() {
    // Listen for deep links when app is already running
    SystemChannels.lifecycle.setMessageHandler((message) async {
      if (message == AppLifecycleState.resumed.toString()) {
        _handleDeepLink();
      }
      return null;
    });

    // Handle deep link when app is launched
    _handleDeepLink();
  }

  void _handleDeepLink() {
    // Deep link handling relating to Supabase has been removed.
  }

  @override
  Widget build(BuildContext context) {
    return const MyApp();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL: Use path-based routing instead of hash routing
  // This removes the /#/ from URLs (e.g., /dashboard instead of /#/dashboard)
  usePathUrlStrategy();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize services before running the app
  try {
    await LocalStorageService().init();

    // Initialize custom backend API client (primary)
    await ApiClient().init();
    print('✅ API Client initialized successfully');

    // Initialize Firebase Notification Service
    await FirebaseNotificationService.initialize();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    print('Error during initialization: $e');
    // Continue anyway - the app can still work without realtime features
  }

  runApp(const InitApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Determine initial route BEFORE first build
  late final String _initialRoute = _determineInitialRoute();

  String _determineInitialRoute() {
    // Check if URL contains password reset tokens
    // If so, skip splash screen and go directly to password reset
    final currentUri = Uri.base;
    final currentUrl = currentUri.toString();
    final fragment = currentUri.fragment;
    final path = currentUri.path;
    final queryParams = currentUri.queryParameters;

    print('🔍 CHECKING URL IN MAIN.DART (before first build)');
    print('  Full URL: $currentUrl');
    print('  Path: $path');
    print('  Fragment: $fragment');
    print('  Query Params: $queryParams');

    // Check multiple conditions for password reset
    // Supabase password reset checks removed.

    // If we are on a specific route (like /login or /dashboard/...),
    // we should return that route so GetX doesn't default to / and cause a splash-then-redirect loop.
    if (path != '/' && path.isNotEmpty) {
      print('📍 CURRENT ROUTE DETECTED: $path');
      return path;
    }

    print('📱 Normal app launch - showing splash screen');
    return '/';
  }

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (buildContext, orientation, screenType) {
        return ToastificationWrapper(
          config: ToastificationConfig(
            alignment: Alignment.bottomCenter,
          ),
          child: provider.MultiProvider(
            providers: globalProviders,
            child: provider.Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                print(
                    '🏗️ Building GetMaterialApp with initialRoute: $_initialRoute');

                return GetMaterialApp(
                  navigatorKey: SessionExpiryService().navigatorKey,
                  title: 'Rathz Employee',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeProvider.themeMode,
                  initialRoute: _initialRoute,
                  defaultTransition: Transition.noTransition,
                  transitionDuration: Duration.zero,
                  routes: {
                    '/': (context) => const SplashScreen(),
                    '/dashboard': (context) => const DashboardScreen(),
                    '/dashboard-recreation': (context) => const RecreatedDashboardScreen(),
                    '/login': (context) => const LoginScreen(),
                    // All dashboard routes go through DashboardScreen to show sidebar
                    '/reports': (context) => const DashboardScreen(),
                    '/sync-board': (context) => const DashboardScreen(),
                    '/attendance': (context) => const DashboardScreen(),
                    '/calendar': (context) => const DashboardScreen(),
                    '/profile': (context) => const DashboardScreen(),
                    '/kanban': (context) => const DashboardScreen(),
                    '/projects': (context) => const DashboardScreen(),
                    '/settings': (context) => const DashboardScreen(),
                    '/change-password': (context) => const DashboardScreen(),

                    // '/forget-password': (context) => const ForgetPasswordScreen(),
                    '/otp-verification': (context) {
                      final args = ModalRoute.of(context)?.settings.arguments
                          as Map<String, dynamic>?;
                      final email = args?['email'] as String? ?? '';
                      return OtpVerificationScreen(email: email);
                    },
                  },
                  builder: (context, child) => ResponsiveBreakpoints.builder(
                    child: child!,
                    breakpoints: [
                      const Breakpoint(start: 0, end: 550, name: MOBILE),
                      const Breakpoint(start: 551, end: 900, name: TABLET),
                      const Breakpoint(start: 901, end: 1400, name: 'LAPTOP'),
                      const Breakpoint(
                          start: 1401, end: double.infinity, name: DESKTOP),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
