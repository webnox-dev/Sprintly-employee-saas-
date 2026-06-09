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

    return Scaffold(
      backgroundColor: Colors.white, // Clean white professional background
      body: Container(
        decoration: BoxDecoration(
          // Very subtle, professional gradient
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              // Subtle tint of brand color at the bottom
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

                    // Logo Section - Clean, no effects
                    Hero(
                      tag: 'app_logo',
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Image.asset(
                              'assets/logo/logo.png', // Using existing logo
                              width: isMobile ? 80 : 100,
                              height: isMobile ? 80 : 100,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Brand Name - Strong, Professional
                    Text(
                      'Rathz',
                      style: TextStyle(
                        fontFamily: 'Inter', // Presuming Inter or system font
                        fontSize: isMobile ? 32 : 40,
                        fontWeight: FontWeight.bold, // Strong bold
                        color: Colors.black87, // High contrast
                        letterSpacing: -0.5, // Tight corporate tracking
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle - Clear hierarchy
                    Text(
                      'Employee Portal',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const Spacer(),

                    // Minimal Footer Loader
                    SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            minHeight: 2,
                            backgroundColor: Colors.grey[200],
                            valueColor:
                                AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _loadingText,
                            style: TextStyle(
                              color: Colors.grey[400],
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
