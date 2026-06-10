import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../services/local_storage_service.dart';
import '../view_model/auth_view_model.dart';
// import '../helpers/common_colors.dart';

@RoutePage()
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final localStorage = LocalStorageService();
  // Simple, static loading text for stability
  final String _loadingText = 'Initializing...';

  @override
  void initState() {
    super.initState();

    // Single controller for synchronized, stable animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Smooth fade in
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));

    // Subtle slide up - NO bounce
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Very subtle slide
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutQuart),
    ));

    // Start
    _controller.forward();

    // Navigation Logic
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _navigateToNextScreen();
    });
  }

  void _navigateToNextScreen() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      await authViewModel.checkAuthState();
      final isLoggedIn = authViewModel.isAuthenticated;

      if (isLoggedIn) {
        // Preserve the current route if user is already on a dashboard route
        // This fixes the bug where refreshing from any page redirects to dashboard
        final uri = Uri.base;
        String? targetRoute;

        // Check URL path first (works with URL routing)
        // Preserve all valid routes that should be maintained on refresh
        if (uri.path.startsWith('/dashboard') ||
            uri.path.startsWith('/reports') ||
            uri.path.startsWith('/kanban') ||
            uri.path.startsWith('/projects') ||
            uri.path.startsWith('/login')) {
          targetRoute = uri.path;
        }
        // Fallback: Check hash fragment (for hash routing compatibility during transition)
        else if (uri.fragment.isNotEmpty) {
          String fragment = uri.fragment;
          if (fragment.startsWith('/')) {
            targetRoute = fragment;
          } else if (fragment.startsWith('#')) {
            targetRoute = fragment.substring(1); // Remove leading #
          } else {
            targetRoute = '/$fragment'; // Add leading /
          }
        }

        // If we found a valid route, navigate to it
        // Otherwise, default to /dashboard
        if (targetRoute != null &&
            targetRoute != '/' &&
            targetRoute != '/dashboard') {
          // Navigate to the preserved route if we aren't already there
          if (mounted && Get.currentRoute != targetRoute) {
            Get.offAllNamed(targetRoute);
          }
        } else {
          // User is on splash screen, navigate to dashboard
          if (mounted && Get.currentRoute != '/dashboard') {
            Get.offAllNamed('/dashboard');
          }
        }
      } else {
        if (authViewModel.localStorage.isLoggedIn && !isLoggedIn) {
          await authViewModel.localStorage.clearUserLogin();
        }
        if (mounted && Get.currentRoute != '/login') {
          Get.offAllNamed('/login');
        }
      }
    } catch (e) {
      try {
        await localStorage.clearUserLogin();
      } catch (_) {}
      if (mounted && Get.currentRoute != '/login') {
        Get.offAllNamed('/login');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Container(
        decoration: BoxDecoration(
          // Subtle, professional gradient that syncs with UI themes
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                  ]
                : [
                    Colors.white,
                    primaryColor.withOpacity(0.05),
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Logo Section - Clean, scaled up for better presence
                    Hero(
                      tag: 'app_logo',
                      child: Image.asset(
                        'assets/logo/rathz_joined_logo.png',
                        width: isMobile ? 220 : 285,
                        height: isMobile ? 85 : 110,
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Subtitle - Clear hierarchy, Dark mode synced
                    Text(
                      'Employee Portal',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),

                    const Spacer(),

                    // Minimal Footer Loader - Dark mode synced
                    SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            minHeight: 2,
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                            valueColor:
                                AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _loadingText,
                            style: TextStyle(
                              color: isDark ? Colors.grey[500] : Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
