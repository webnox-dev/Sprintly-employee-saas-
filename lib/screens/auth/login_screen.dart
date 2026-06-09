import 'package:sizer/sizer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routes/custom_routes.dart';
import '../../widgets/common_widgets.dart';
import 'package:auto_route/auto_route.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_loader_button.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../view_model/auth_view_model.dart';
import '../dashboard/modern_dashboard_screen.dart';
import 'package:form_validator/form_validator.dart';
import '../../widgets/otp_verification_dialog.dart';
import '../../widgets/session_limit_dialog.dart';

@RoutePage()
class LoginScreen extends HookWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    // Pre-cache login images for instant display
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        precacheImage(const AssetImage('assets/images/login.png'), context);
        precacheImage(const AssetImage('assets/images/login_img.png'), context);
      });
      return null;
    }, []);

    final screenHeight = MediaQuery.of(context).size.height;
    final isShortViewport = screenHeight < 750;

    final currentStep = useState(0); // 0: Email, 1: Workspace Selection, 2: Password
    final isDiscovering = useState(false);

    Future<void> handleLogin() async {
      String loginErrorMsg = await authViewModel.loginWithBackend();
      if (loginErrorMsg.isEmpty) {
        showSuccess(text: "Login successful");
        CustomRoutes().routeToWithGuardReplacement(
            screen: ModernDashboardScreen(), routeName: '/dashboard');
      } else if (loginErrorMsg == 'EMAIL_NOT_VERIFIED') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => OtpVerificationDialog(
            email: authViewModel.unverifiedEmail,
          ),
        );
      } else if (loginErrorMsg == 'SESSION_LIMIT_EXCEEDED') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => SessionLimitDialog(
            data: authViewModel.sessionLimitData ?? {},
            authViewModel: authViewModel,
          ),
        );
      } else {
        showError(text: loginErrorMsg);
      }
    }

    Widget buildLoginForm(BoxConstraints constraints) {
      final isMobile = constraints.maxWidth < 600;
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 3.h : (isShortViewport ? 24 : 40),
          horizontal: isMobile ? 5.w : (isShortViewport ? 60 : 80),
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo at top left
              Row(
                children: [
                  Image.asset(
                    'assets/logo/logo.png',
                    width: isMobile ? 48 : (isShortViewport ? 42 : 56),
                    height: isMobile ? 48 : (isShortViewport ? 42 : 56),
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Rathz',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: isMobile ? 26 : (isShortViewport ? 28 : 34),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Employee',
                        style: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.6),
                          fontSize: isMobile ? 14 : (isShortViewport ? 13 : 16),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 3.h : (isShortViewport ? 20 : 40)),

              // Title
              Text(
                currentStep.value == 0 
                  ? 'Welcome to Rathz' 
                  : (currentStep.value == 1 ? 'Select Workspace' : 'Log in to your Account'),
                style: TextStyle(
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontSize: isMobile ? 30 : (isShortViewport ? 34 : 40),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  height: 1.1,
                ),
              ),
              SizedBox(height: isMobile ? 2.h : (isShortViewport ? 10 : 16)),

              // Subtitle
              Text(
                currentStep.value == 0 
                  ? 'Enter your work email to find your workspaces.' 
                  : (currentStep.value == 1 ? 'Choose the workspace you want to sign in to.' : 'Welcome back! Please enter your password.'),
                style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.65),
                  fontSize: isMobile ? 15 : (isShortViewport ? 15 : 17),
                  height: 1.5,
                ),
              ),
              SizedBox(height: isMobile ? 3.h : (isShortViewport ? 24 : 36)),

              if (currentStep.value == 0) ...[
                // Email Field
                CustomTextField(
                  controller: authViewModel.emailController,
                  title: 'Email',
                  showIcon: false,
                  showPsw: false,
                  textInputType: TextInputType.emailAddress,
                  readOnly: isDiscovering.value,
                  validator: ValidationBuilder(
                    requiredMessage: 'Email id should not be blank.',
                  ).email().build(),
                  hintText: 'Enter your email',
                  isRequired: true,
                  textInputAction: TextInputAction.next,
                ),
                SizedBox(height: isMobile ? 3.h : (isShortViewport ? 24 : 36)),
                
                Container(
                  width: double.infinity,
                  height: isMobile ? 52 : (isShortViewport ? 52 : 58),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.85),
                      ],
                    ),
                  ),
                  child: CustomLoaderButton(
                    buttonText: 'Next',
                    buttonTextColor: Colors.white,
                    buttonColor: Colors.transparent,
                    buttonTextSize: isMobile ? 16.5 : (isShortViewport ? 16.5 : 18.0),
                    loaderColor: Colors.white,
                    width: double.infinity,
                    onTap: () async {
                      if (formKey.currentState!.validate()) {
                        isDiscovering.value = true;
                        final workspaces = await authViewModel.discoverWorkspaces(
                          authViewModel.emailController.text.trim()
                        );
                        isDiscovering.value = false;

                        if (workspaces.isEmpty) {
                          showError(text: 'No workspaces found for this email.');
                        } else if (workspaces.length == 1) {
                          authViewModel.setSelectedWorkspace(workspaces.first);
                          currentStep.value = 2; // Skip selection
                        } else {
                          currentStep.value = 1; // Show selection
                        }
                      }
                    },
                  ),
                ),
              ] else if (currentStep.value == 1) ...[
                // Workspace Selection List
                Container(
                  constraints: BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: authViewModel.workspaces.length,
                    itemBuilder: (context, index) {
                      final workspace = authViewModel.workspaces[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            child: Text(workspace['organization_name'][0].toUpperCase()),
                          ),
                          title: Text(workspace['organization_name']),
                          subtitle: Text(workspace['organization_slug'] ?? ''),
                          onTap: () {
                            authViewModel.setSelectedWorkspace(workspace);
                            currentStep.value = 2;
                          },
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        ),
                      );
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => currentStep.value = 0,
                  child: const Text('Back to email'),
                ),
              ] else if (currentStep.value == 2) ...[
                // Selected Workspace Chip
                if (authViewModel.selectedWorkspace != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            child: Text(
                              authViewModel.selectedWorkspace!['organization_name'][0].toUpperCase(),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authViewModel.selectedWorkspace!['organization_name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Signing in as ${authViewModel.emailController.text}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => currentStep.value = authViewModel.workspaces.length > 1 ? 1 : 0,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Password Field
                CustomTextField(
                  controller: authViewModel.pswController,
                  title: 'Password',
                  showIcon: true,
                  showPsw: true,
                  textInputType: TextInputType.visiblePassword,
                  readOnly: false,
                  maxLines: 1,
                  validator: ValidationBuilder(
                    requiredMessage: 'Password should not be blank.',
                  ).build(),
                  hintText: 'Enter your password',
                  isRequired: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (value) async {
                    if (formKey.currentState!.validate()) {
                      await handleLogin();
                    }
                  },
                ),
                SizedBox(height: isMobile ? 3.h : (isShortViewport ? 24 : 36)),

                Container(
                  width: double.infinity,
                  height: isMobile ? 52 : (isShortViewport ? 52 : 58),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.85),
                      ],
                    ),
                  ),
                  child: CustomLoaderButton(
                    buttonText: 'Log In',
                    buttonTextColor: Colors.white,
                    buttonColor: Colors.transparent,
                    buttonTextSize: isMobile ? 16.5 : (isShortViewport ? 16.5 : 18.0),
                    loaderColor: Colors.white,
                    width: double.infinity,
                    onTap: () async {
                      if (formKey.currentState!.validate()) {
                        await handleLogin();
                      }
                    },
                  ),
                ),
                SizedBox(height: isMobile ? 2.h : 2.5.h),
                Center(
                  child: TextButton(
                    onPressed: () => currentStep.value = authViewModel.workspaces.length > 1 ? 1 : 0,
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              // Mobile layout - Premium, layered design
              return Column(
                children: [
                  // Illustration Header with subtle background depth
                  Container(
                    height: 32.h,
                    width: double.infinity,
                    color: Colors.transparent,
                    child: SafeArea(
                      bottom: false,
                      child: Center(
                        child: Hero(
                          tag: 'login_illustration',
                          child: Image.asset(
                            'assets/images/login.png',
                            height: 25.h,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/login_img.png',
                                height: 25.h,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(32.0),
                          topLeft: Radius.circular(32.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 30,
                            offset: const Offset(0, -10),
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: buildLoginForm(constraints),
                    ),
                  ),
                ],
              );
            } else {
              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).scaffoldBackgroundColor,
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 1150,
                      maxHeight: isShortViewport ? 680 : 750,
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(28.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 40,
                            offset: const Offset(0, 15),
                            spreadRadius: -5,
                          ),
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Left Section - Login Form
                          Expanded(
                            flex: 6, // 6 out of 13
                            child: Container(
                              alignment: Alignment.center,
                              child: buildLoginForm(constraints),
                            ),
                          ),
                          // Right Section - Image with sophisticated fit
                          Expanded(
                            flex:
                                7, // 7 out of 13 - More breathing room for illustration
                            child: Container(
                              alignment: Alignment.center,
                              color: Colors.transparent,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20.0),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.asset(
                                        'assets/images/login.png',
                                        fit: BoxFit.contain,
                                        gaplessPlayback: true,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Image.asset(
                                            'assets/images/login_img.png',
                                            fit: BoxFit.contain,
                                            gaplessPlayback: true,
                                          );
                                        },
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
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
