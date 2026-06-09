import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:auto_route/auto_route.dart';
import 'package:form_validator/form_validator.dart';
import 'package:sizer/sizer.dart'; // Added for responsive layout
import '../../helpers/common_colors.dart';
import '../../view_model/auth_view_model.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_loader_button.dart';

@RoutePage()
class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Step 1 Controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _step1FormKey = GlobalKey<FormState>();

  // Step 2 Controllers
  final _otpController = TextEditingController();
  final _step2FormKey = GlobalKey<FormState>();

  // Step 3 Controllers
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _step3FormKey = GlobalKey<FormState>();

  bool _isLoading =
      false; // Still needed for non-CustomLoaderButton logic (like Resend)
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      if (isError) {
        _errorMessage = message;
        _successMessage = null;
      } else {
        _successMessage = message;
        _errorMessage = null;
      }
    });

    if (!isError) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    }
  }

  Future<void> _handleStep1Submit() async {
    if (!_step1FormKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      final authViewModel = context.read<AuthViewModel>();
      final result = await authViewModel.sendPasswordResetOtp(
        _emailController.text.trim(),
        _phoneController.text.trim(),
      );

      if (result['success'] == true) {
        _showMessage(result['message'] ?? 'OTP sent successfully');
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() => _currentStep = 1);
      } else {
        _showMessage(result['message'] ?? 'Failed to send OTP', isError: true);
      }
    } catch (e) {
      _showMessage('An error occurred: $e', isError: true);
    }
  }

  // ... (Step 2 and 3 submit handlers remain unchanged) ...

  // ... (build method remains unchanged except for potentially removing phone from UI) ...

  // To properly update the UI, we need to replace the entire _buildStep1 method or specific blocks within it.
  // Since I am replacing a larger chunk to catch the controller definitions, I will just continue with the rest of the file structure or specific method updates.
  // Wait, I can't replace the whole file easily. I should target specific blocks.

  // I'll split this into smaller chunks.

  // Chunk 1: Remove phone controller and update dispose
  // Chunk 2: Update _handleStep1Submit
  // Chunk 3: Update _buildStep1 UI

  Future<void> _handleStep2Submit() async {
    if (!_step2FormKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      final authViewModel = context.read<AuthViewModel>();
      final result = await authViewModel.verifyPasswordResetOtp(
        _emailController.text.trim(),
        _otpController.text.trim(),
      );

      if (result['success'] == true) {
        _showMessage(result['message'] ?? 'OTP verified successfully');
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() => _currentStep = 2);
      } else {
        _showMessage(result['message'] ?? 'Invalid OTP', isError: true);
      }
    } catch (e) {
      _showMessage('An error occurred: $e', isError: true);
    }
  }

  Future<void> _handleResendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authViewModel = context.read<AuthViewModel>();
      final result = await authViewModel.resendPasswordResetOtp(
        _emailController.text.trim(),
      );

      if (result['success'] == true) {
        _showMessage(result['message'] ?? 'OTP resent successfully');
      } else {
        _showMessage(result['message'] ?? 'Failed to resend OTP',
            isError: true);
      }
    } catch (e) {
      _showMessage('An error occurred: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleStep3Submit() async {
    if (!_step3FormKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      final authViewModel = context.read<AuthViewModel>();
      final result = await authViewModel.resetPassword(
        _emailController.text.trim(),
        _newPasswordController.text,
      );

      if (result['success'] == true) {
        _showMessage(result['message'] ?? 'Password changed successfully');
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showMessage(result['message'] ?? 'Failed to reset password',
            isError: true);
      }
    } catch (e) {
      _showMessage('An error occurred: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Removed AppBar to use custom header or split view
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget buildContent() {
              return Column(
                children: [
                  // Mobile Header / Back Button
                  if (constraints.maxWidth < 600)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              if (_currentStep > 0) {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                                setState(() => _currentStep--);
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                          Text(
                            'Back',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),

                  // Progress Indicator
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth < 600 ? 5.w : 0),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 3,
                      backgroundColor: Colors.grey[200],
                      valueColor:
                          AlwaysStoppedAnimation<Color>(CommonColors.primary),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 6,
                    ),
                  ),
                  SizedBox(height: 2.h),

                  // Title Section
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth < 600 ? 5.w : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStepTitle(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: constraints.maxWidth < 600 ? 24 : 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getStepDescription(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),

                  // Message Containers
                  if (_errorMessage != null)
                    Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 600 ? 5.w : 0,
                          vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_successMessage != null)
                    Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 600 ? 5.w : 0,
                          vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: TextStyle(color: Colors.green[700]),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Page View
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStep1(constraints),
                        _buildStep2(constraints),
                        _buildStep3(constraints),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Responsive Layout
            if (constraints.maxWidth < 600) {
              // Mobile Layout
              return Column(
                children: [
                  // Decorative Top Header
                  Container(
                    height: 20.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Icon(
                            Icons.lock_reset,
                            size: 150,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        // Center Icon
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getStepIcon(),
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(30.0),
                          topLeft: Radius.circular(30.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: buildContent(),
                    ),
                  ),
                ],
              );
            } else {
              // Desktop/Tablet Split Layout
              return Center(
                child: Container(
                  width: 85.w,
                  height: 85.h,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // ... (Left section unchanged)
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24.0),
                              bottomLeft: Radius.circular(24.0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: () {
                                      if (_currentStep > 0) {
                                        _pageController.previousPage(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                        setState(() => _currentStep--);
                                      } else {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                  ),
                                  // Logo small
                                  Text('Rathz',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: CommonColors.primary)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Expanded(child: buildContent()),
                            ],
                          ),
                        ),
                      ),
                      // ... (Right section unchanged)
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.8),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(24.0),
                              bottomRight: Radius.circular(24.0),
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getStepIcon(),
                                  size: 120,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _getStepTitle(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 48),
                                  child: Text(
                                    _getStepDescription(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Verify Identity';
      case 1:
        return 'Enter OTP';
      case 2:
        return 'Reset Password';
      default:
        return 'Forget Password';
    }
  }

  String _getStepDescription() {
    switch (_currentStep) {
      case 0:
        return 'Enter your credentials to receive a verification code.';
      case 1:
        return 'We sent a code to your email. Please enter it below.';
      case 2:
        return 'Your identity is verified. Set your new strong password.';
      default:
        return '';
    }
  }

  IconData _getStepIcon() {
    switch (_currentStep) {
      case 0:
        return Icons.person_search_outlined;
      case 1:
        return Icons.mark_email_read_outlined;
      case 2:
        return Icons.lock_reset_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildStep1(BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: constraints.maxWidth < 600 ? 5.w : 0, vertical: 24),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _emailController,
              title: 'Email Address',
              hintText: 'Enter your email',
              showIcon: false,
              showPsw: false,
              textInputType: TextInputType.emailAddress,
              readOnly: false,
              validator: ValidationBuilder().email().required().build(),
              isRequired: true,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _phoneController,
              title: 'Phone Number',
              hintText: 'Enter your phone number',
              showIcon: false,
              showPsw: false,
              textInputType: TextInputType.phone,
              readOnly: false,
              validator: ValidationBuilder()
                  .phone('Invalid phone number')
                  .minLength(10, 'Phone must be at least 10 digits')
                  .required()
                  .build(),
              isRequired: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 32),
            CustomLoaderButton(
              onTap: _handleStep1Submit,
              buttonText: 'Send Verification Code',
              buttonColor: CommonColors.primary,
              buttonTextColor: Colors.white,
              buttonTextSize: 16,
              loaderColor: Colors.white,
              height: 50,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2(BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: constraints.maxWidth < 600 ? 5.w : 0, vertical: 24),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sent to ${_emailController.text}',
              style: TextStyle(
                  color: CommonColors.primary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CustomTextField(
              controller: _otpController,
              title: 'OTP Code',
              hintText: 'Enter 6-digit OTP',
              showIcon: false, // Icon handled by component logic if needed
              showPsw: false,
              textInputType: TextInputType.number,
              readOnly: false,
              validator: ValidationBuilder()
                  .minLength(6, 'OTP must be 6 digits')
                  .maxLength(6, 'OTP must be 6 digits')
                  .required()
                  .build(),
              isRequired: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Didn't receive code? "),
                TextButton(
                  onPressed: _isLoading ? null : _handleResendOtp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Resend'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            CustomLoaderButton(
              onTap: _handleStep2Submit,
              buttonText: 'Verify OTP',
              buttonColor: CommonColors.primary,
              buttonTextColor: Colors.white,
              buttonTextSize: 16,
              loaderColor: Colors.white,
              height: 50,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3(BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
          horizontal: constraints.maxWidth < 600 ? 5.w : 0, vertical: 24),
      child: Form(
        key: _step3FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _newPasswordController,
              title: 'New Password',
              hintText: 'Enter new password',
              showIcon: true,
              showPsw: true,
              textInputType: TextInputType.text,
              readOnly: false,
              validator: ValidationBuilder()
                  .minLength(6, 'Password must be at least 6 characters')
                  .required()
                  .build(),
              isRequired: true,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _confirmPasswordController,
              title: 'Confirm Password',
              hintText: 'Re-enter new password',
              showIcon: true,
              showPsw: true,
              textInputType: TextInputType.text,
              readOnly: false,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
              isRequired: true,
            ),
            const SizedBox(height: 32),
            CustomLoaderButton(
              onTap: _handleStep3Submit,
              buttonText: 'Set New Password',
              buttonColor: CommonColors.primary,
              buttonTextColor: Colors.white,
              buttonTextSize: 16,
              loaderColor: Colors.white,
              height: 50,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}
