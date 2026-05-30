import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webnox_taskops/helpers/common_colors.dart';
import 'package:webnox_taskops/utils/responsive_utils.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import 'package:webnox_taskops/widgets/animated_loading_states.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final success = await authViewModel.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Password changed successfully!',
                style: TextStyle(color: CommonColors.white),
              ),
              backgroundColor: CommonColors.successGreen,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pushReplacementNamed('/settings');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to change password. Please check your current password.',
                style: TextStyle(color: CommonColors.white),
              ),
              backgroundColor: CommonColors.dangerRed,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'An error occurred. Please try again.',
              style: TextStyle(color: CommonColors.white),
            ),
            backgroundColor: CommonColors.dangerRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final isMobile = ResponsiveUtils.isMobile(context);
    final isSmallMobile = MediaQuery.of(context).size.width <= 360;
    final isVerySmallMobile = MediaQuery.of(context).size.width <= 320;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: _isLoading
          ? const EnhancedLoadingIndicator(message: 'Changing password...')
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: ResponsiveUtils.getResponsivePadding(
                    context,
                    mobile: const EdgeInsets.all(16),
                    tablet: const EdgeInsets.all(20),
                    desktop: const EdgeInsets.all(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button (Left Aligned)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => Navigator.of(
                            context,
                          ).pushReplacementNamed('/settings'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back_ios,
                                  size: 18,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color, // Removed opacity for better visibility
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Back to Settings',
                                  style: TextStyle(
                                    fontSize: 16, // Increased size
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color, // Removed opacity
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Centered Content (Header + Form)
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 600 : double.infinity,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              _buildHeader(
                                context,
                                isDesktop,
                                isTablet,
                                isMobile,
                                isSmallMobile,
                                isVerySmallMobile,
                              ),

                              SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: 24,
                                  tablet: 28,
                                  desktop: 32,
                                ),
                              ),

                              // Form
                              Form(
                                key: _formKey,
                                child: _buildForm(
                                  context,
                                  isDesktop,
                                  isTablet,
                                  isMobile,
                                  isSmallMobile,
                                  isVerySmallMobile,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    bool isSmallMobile,
    bool isVerySmallMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Change Password',
          style: TextStyle(
            color: Theme.of(context).textTheme.headlineLarge?.color,
            fontSize: isVerySmallMobile
                ? 24
                : isSmallMobile
                ? 26
                : isMobile
                ? 28
                : isTablet
                ? 32
                : 36,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
          height: isVerySmallMobile
              ? 6
              : isSmallMobile
              ? 8
              : isMobile
              ? 10
              : 12,
        ),
        Text(
          'Update your password to keep your account secure',
          style: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodyLarge?.color?.withOpacity(0.7),
            fontSize: isVerySmallMobile
                ? 12
                : isSmallMobile
                ? 13
                : isMobile
                ? 14
                : isTablet
                ? 16
                : 18,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    bool isSmallMobile,
    bool isVerySmallMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(
        isDesktop
            ? 24
            : isTablet
            ? 20
            : 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Password Field
          _buildPasswordField(
            context,
            'Current Password',
            'Enter your current password',
            _currentPasswordController,
            _obscureCurrentPassword,
            (value) => setState(() {
              _obscureCurrentPassword = value;
            }),
            (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your current password';
              }
              return null;
            },
            isDesktop,
            isTablet,
            isMobile,
            isSmallMobile,
            isVerySmallMobile,
          ),

          SizedBox(
            height: ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: 16,
              tablet: 18,
              desktop: 20,
            ),
          ),

          // New Password Field
          _buildPasswordField(
            context,
            'New Password',
            'Enter your new password',
            _newPasswordController,
            _obscureNewPassword,
            (value) => setState(() {
              _obscureNewPassword = value;
            }),
            (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a new password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters long';
              }
              return null;
            },
            isDesktop,
            isTablet,
            isMobile,
            isSmallMobile,
            isVerySmallMobile,
          ),

          SizedBox(
            height: ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: 16,
              tablet: 18,
              desktop: 20,
            ),
          ),

          // Confirm Password Field
          _buildPasswordField(
            context,
            'Confirm New Password',
            'Confirm your new password',
            _confirmPasswordController,
            _obscureConfirmPassword,
            (value) => setState(() {
              _obscureConfirmPassword = value;
            }),
            (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your new password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            isDesktop,
            isTablet,
            isMobile,
            isSmallMobile,
            isVerySmallMobile,
          ),
          SizedBox(
            height: ResponsiveUtils.getResponsiveSpacing(
              context,
              mobile: 24,
              tablet: 28,
              desktop: 32,
            ),
          ),

          // Submit Button (Moved inside form)
          _buildSubmitButton(
            context,
            isDesktop,
            isTablet,
            isMobile,
            isSmallMobile,
            isVerySmallMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
    BuildContext context,
    String label,
    String hint,
    TextEditingController controller,
    bool obscureText,
    Function(bool) onToggleObscure,
    String? Function(String?) validator,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    bool isSmallMobile,
    bool isVerySmallMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).textTheme.titleMedium?.color,
            fontSize: isVerySmallMobile
                ? 12
                : isSmallMobile
                ? 13
                : isMobile
                ? 14
                : isTablet
                ? 15
                : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(
          height: isVerySmallMobile
              ? 6
              : isSmallMobile
              ? 8
              : isMobile
              ? 10
              : 12,
        ),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: isVerySmallMobile
                ? 12
                : isSmallMobile
                ? 13
                : isMobile
                ? 14
                : isTablet
                ? 15
                : 16,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withOpacity(0.5),
              fontSize: isVerySmallMobile
                  ? 12
                  : isSmallMobile
                  ? 13
                  : isMobile
                  ? 14
                  : isTablet
                  ? 15
                  : 16,
            ),
            prefixIcon: Icon(
              Icons.lock_outline,
              color: CommonColors.primary,
              size: isVerySmallMobile
                  ? 18
                  : isSmallMobile
                  ? 20
                  : isMobile
                  ? 22
                  : 24,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.5),
                size: isVerySmallMobile
                    ? 18
                    : isSmallMobile
                    ? 20
                    : isMobile
                    ? 22
                    : 24,
              ),
              onPressed: () => onToggleObscure(!obscureText),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                isVerySmallMobile
                    ? 6
                    : isSmallMobile
                    ? 8
                    : isMobile
                    ? 10
                    : 12,
              ),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                isVerySmallMobile
                    ? 6
                    : isSmallMobile
                    ? 8
                    : isMobile
                    ? 10
                    : 12,
              ),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                isVerySmallMobile
                    ? 6
                    : isSmallMobile
                    ? 8
                    : isMobile
                    ? 10
                    : 12,
              ),
              borderSide: BorderSide(color: CommonColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                isVerySmallMobile
                    ? 6
                    : isSmallMobile
                    ? 8
                    : isMobile
                    ? 10
                    : 12,
              ),
              borderSide: BorderSide(color: CommonColors.dangerRed, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                isVerySmallMobile
                    ? 6
                    : isSmallMobile
                    ? 8
                    : isMobile
                    ? 10
                    : 12,
              ),
              borderSide: BorderSide(color: CommonColors.dangerRed, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isVerySmallMobile
                  ? 12
                  : isSmallMobile
                  ? 14
                  : isMobile
                  ? 16
                  : isTablet
                  ? 18
                  : 20,
              vertical: isVerySmallMobile
                  ? 12
                  : isSmallMobile
                  ? 14
                  : isMobile
                  ? 16
                  : isTablet
                  ? 18
                  : 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    bool isSmallMobile,
    bool isVerySmallMobile,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 150,
          maxWidth: isDesktop ? 250 : double.infinity,
        ), // Increased width to prevent wrapping
        child: ElevatedButton(
          onPressed: _isLoading ? null : _changePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: CommonColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: CommonColors.primary.withOpacity(0.4),
            padding: EdgeInsets.symmetric(
              vertical: isVerySmallMobile
                  ? 12
                  : isSmallMobile
                  ? 14
                  : isMobile
                  ? 16
                  : isTablet
                  ? 18
                  : 20,
              horizontal: isVerySmallMobile
                  ? 16
                  : isSmallMobile
                  ? 18
                  : isMobile
                  ? 20
                  : 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                isVerySmallMobile
                    ? 6
                    : isSmallMobile
                    ? 8
                    : isMobile
                    ? 10
                    : 12,
              ),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  height: isVerySmallMobile
                      ? 16
                      : isSmallMobile
                      ? 18
                      : isMobile
                      ? 20
                      : 22,
                  width: isVerySmallMobile
                      ? 16
                      : isSmallMobile
                      ? 18
                      : isMobile
                      ? 20
                      : 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      CommonColors.white,
                    ),
                  ),
                )
              : Text(
                  'Change Password',
                  style: TextStyle(
                    color: CommonColors.white,
                    fontSize: isVerySmallMobile
                        ? 12
                        : isSmallMobile
                        ? 14
                        : isMobile
                        ? 16
                        : 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
