import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:webnox_taskops/helpers/common_colors.dart';
import 'package:webnox_taskops/utils/responsive_utils.dart';
import 'package:webnox_taskops/services/leave_service.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import 'package:webnox_taskops/view_model/leave_policy_view_model.dart';
import 'package:webnox_taskops/widgets/custom_profile_image_upload.dart';
import 'package:webnox_taskops/screens/profile/components/document_tab.dart';

class ProfileScreen extends HookWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final isLaptop = ResponsiveUtils.isLaptop(context);

    final authViewModel = Provider.of<AuthViewModel>(context);

    // State for employee details
    final employeeDetails = useState<Map<String, dynamic>?>(null);
    final isLoadingEmployee = useState<bool>(true);
    final leaveBalance = useState<Map<String, dynamic>?>(null);
    final isLoadingLeave = useState<bool>(false);
    final leaveBalancePoller = useRef<Timer?>(null);
    final selectedTab = useState<int>(0);

    // Editing states for forms
    final isEditingPersonal = useState<bool>(false);
    final isEditingProfessional = useState<bool>(false);

    // Form controllers - must be at top level to maintain hook order
    final personalFirstNameCtrl = useTextEditingController();
    final personalLastNameCtrl = useTextEditingController();
    final personalPhoneCtrl = useTextEditingController();
    final personalEmailCtrl = useTextEditingController();
    final companyEmailCtrl = useTextEditingController();
    final addressCtrl = useTextEditingController();
    final genderCtrl = useTextEditingController();
    final dobCtrl = useTextEditingController();
    final qualificationCtrl = useTextEditingController();
    final emergencyContactCtrl = useTextEditingController();
    final roleCtrl = useTextEditingController();
    final designationCtrl = useTextEditingController();
    final bloodGroupCtrl = useTextEditingController();

    // Refs to track previous values for controller updates
    final prevPersonalEmployeeDetails = useRef<Map<String, dynamic>?>(null);
    final prevProfessionalEmployeeDetails = useRef<Map<String, dynamic>?>(null);
    final prevPersonalFormEmployeeDetails = useRef<Map<String, dynamic>?>(null);

    // Fetch employee details
    useEffect(() {
      Future<void> fetchEmployeeDetails() async {
        try {
          isLoadingEmployee.value = true;
          final details = await authViewModel.getCurrentEmployeeDetails();
          if (details != null) {
            // Create a new map to trigger state update
            employeeDetails.value = Map<String, dynamic>.from(details);
          } else {
            employeeDetails.value = null;
          }
        } catch (e) {
          // Handle error silently
          employeeDetails.value = null;
        } finally {
          isLoadingEmployee.value = false;
        }
      }

      if (authViewModel.isAuthenticated) {
        fetchEmployeeDetails();
      } else {
        employeeDetails.value = null;
      }

      return null;
    }, [authViewModel.isAuthenticated, authViewModel.userEmail]);

    // Fetch leave balance
    useEffect(() {
      Future<void> fetchLeaveBalance() async {
        final empId = employeeDetails.value?['employee_id'] as String?;
        if (empId == null || empId.isEmpty) return;
        try {
          isLoadingLeave.value = true;
          final service = LeaveService();
          final balance = await service.getRemainingLeaveBalance(empId);
          leaveBalance.value = balance;
        } catch (_) {
          leaveBalance.value = null;
        } finally {
          isLoadingLeave.value = false;
        }
      }

      fetchLeaveBalance();
      leaveBalancePoller.value?.cancel();
      leaveBalancePoller.value = Timer.periodic(const Duration(seconds: 15), (
        _,
      ) {
        fetchLeaveBalance();
      });

      return () {
        leaveBalancePoller.value?.cancel();
        leaveBalancePoller.value = null;
      };
    }, [employeeDetails.value?['employee_id']]);

    // Fetch leave policy status
    useEffect(() {
      final empId = employeeDetails.value?['employee_id'] as String?;
      if (empId != null && empId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Provider.of<LeavePolicyViewModel>(
            context,
            listen: false,
          ).fetchStatus(empId);
        });
      }
      return null;
    }, [employeeDetails.value?['employee_id']]);

    // Update form controllers when employee details change
    // Use a single useEffect to update all controllers
    useEffect(() {
      final currentData = employeeDetails.value;
      if (currentData != null) {
        final prevPersonal = prevPersonalEmployeeDetails.value;
        final prevProfessional = prevProfessionalEmployeeDetails.value;

        // Only update if data actually changed
        if (prevPersonal == null ||
            prevPersonal['employee_name'] != currentData['employee_name'] ||
            prevPersonal['employee_phone_num'] !=
                currentData['employee_phone_num'] ||
            prevPersonal['employee_personal_email'] !=
                currentData['employee_personal_email'] ||
            prevPersonal['employee_company_email'] !=
                currentData['employee_company_email'] ||
            prevPersonal['employee_address'] !=
                currentData['employee_address'] ||
            prevPersonal['employee_gender'] != currentData['employee_gender'] ||
            prevPersonal['employee_dob'] != currentData['employee_dob'] ||
            prevPersonal['employee_qualification'] !=
                currentData['employee_qualification'] ||
            prevPersonal['employee_emergency_contact_number'] !=
                currentData['employee_emergency_contact_number']) {
          personalFirstNameCtrl.text = _getFirstName(
            currentData['employee_name'] ?? '',
          );
          personalLastNameCtrl.text = _getLastName(
            currentData['employee_name'] ?? '',
          );
          personalPhoneCtrl.text = currentData['employee_phone_num'] ?? '';
          personalEmailCtrl.text = currentData['employee_personal_email'] ?? '';
          companyEmailCtrl.text = currentData['employee_company_email'] ?? '';
          addressCtrl.text = currentData['employee_address'] ?? '';
          genderCtrl.text = currentData['employee_gender'] ?? '';
          dobCtrl.text = _formatDate(currentData['employee_dob']) ?? '';
          qualificationCtrl.text = currentData['employee_qualification'] ?? '';
          emergencyContactCtrl.text =
              currentData['employee_emergency_contact_number'] ?? '';
          bloodGroupCtrl.text = currentData['employee_blood_group'] ?? '';
          prevPersonalEmployeeDetails.value = Map<String, dynamic>.from(
            currentData,
          );
        }

        if (prevProfessional == null ||
            prevProfessional['employee_role'] != currentData['employee_role'] ||
            prevProfessional['employee_designation'] !=
                currentData['employee_designation']) {
          roleCtrl.text = currentData['employee_role'] ?? '';
          designationCtrl.text = currentData['employee_designation'] ?? '';
          prevProfessionalEmployeeDetails.value = Map<String, dynamic>.from(
            currentData,
          );
        }
      }
      return null;
    }, [employeeDetails.value]);

    // Listen to selectedTab changes to trigger rebuilds
    useListenable(selectedTab);

    // Pre-build cards to ensure hooks are called unconditionally
    final profileCard = _buildProfileSummaryCard(
      context,
      authViewModel,
      employeeDetails,
      leaveBalance.value,
      isLoadingLeave.value,
    );

    final settingsCard = _buildAccountSettingsCard(
      context,
      authViewModel,
      employeeDetails,
      selectedTab,
      isEditingPersonal: isEditingPersonal,
      isEditingProfessional: isEditingProfessional,
      prevPersonalFormEmployeeDetails: prevPersonalFormEmployeeDetails,
      personalFirstNameCtrl: personalFirstNameCtrl,
      personalLastNameCtrl: personalLastNameCtrl,
      personalPhoneCtrl: personalPhoneCtrl,
      personalEmailCtrl: personalEmailCtrl,
      companyEmailCtrl: companyEmailCtrl,
      addressCtrl: addressCtrl,
      genderCtrl: genderCtrl,
      dobCtrl: dobCtrl,
      qualificationCtrl: qualificationCtrl,
      emergencyContactCtrl: emergencyContactCtrl,
      roleCtrl: roleCtrl,
      designationCtrl: designationCtrl,
      bloodGroupCtrl: bloodGroupCtrl,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: SafeArea(
        child: isLoadingEmployee.value
            ? _buildLoadingState()
            : employeeDetails.value == null
            ? _buildErrorState()
            : Stack(
                children: [
                  // Cover Photo Section at the top
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _buildCoverPhotoSection(
                      context,
                      authViewModel,
                      employeeDetails,
                    ),
                  ),
                  // Scrollable content with top padding
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Spacer for cover photo (reduced to allow overlap)
                        SizedBox(
                          height: isDesktop
                              ? 160
                              : isLaptop
                              ? 170
                              : isTablet
                              ? 200
                              : 240,
                        ),
                        // Profile Content
                        Padding(
                          padding: ResponsiveUtils.getResponsivePadding(
                            context,
                            mobile: const EdgeInsets.all(16),
                            tablet: const EdgeInsets.all(20),
                            laptop: const EdgeInsets.all(22),
                            desktop: const EdgeInsets.all(24),
                          ),
                          child: isDesktop
                              ? _buildDesktopLayout(profileCard, settingsCard)
                              : isLaptop
                              ? _buildLaptopLayout(profileCard, settingsCard)
                              : isTablet
                              ? _buildTabletLayout(profileCard, settingsCard)
                              : _buildMobileLayout(profileCard, settingsCard),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCoverPhotoSection(
    BuildContext context,
    AuthViewModel authViewModel,
    ValueNotifier<Map<String, dynamic>?> employeeDetails,
  ) {
    return Container(
      height: 300,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with error handling
          Image.asset(
            'assets/images/profile_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback gradient if image fails to load
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CommonColors.primary.withOpacity(0.8),
                      CommonColors.primary.withOpacity(0.6),
                      CommonColors.primary.withOpacity(0.4),
                    ],
                  ),
                ),
              );
            },
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(Widget profileCard, Widget settingsCard) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column - Profile Card
        Expanded(flex: 1, child: profileCard),
        const SizedBox(width: 24),
        // Right Column - Account Settings
        Expanded(flex: 2, child: settingsCard),
      ],
    );
  }

  Widget _buildLaptopLayout(Widget profileCard, Widget settingsCard) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column - Profile Card (slightly wider than desktop's 1:2)
        Expanded(flex: 2, child: profileCard),
        const SizedBox(width: 20),
        // Right Column - Account Settings
        Expanded(flex: 3, child: settingsCard),
      ],
    );
  }

  Widget _buildTabletLayout(Widget profileCard, Widget settingsCard) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 1, child: profileCard),
        const SizedBox(width: 20),
        Expanded(flex: 1, child: settingsCard),
      ],
    );
  }

  Widget _buildMobileLayout(Widget profileCard, Widget settingsCard) {
    return Column(children: [profileCard, settingsCard]);
  }

  Widget _buildProfileSummaryCard(
    BuildContext context,
    AuthViewModel authViewModel,
    ValueNotifier<Map<String, dynamic>?> employeeDetails,
    Map<String, dynamic>? leaveBalance,
    bool isLoadingLeave,
  ) {
    String getInitials() {
      final name = employeeDetails.value?['employee_name'] ?? '';
      if (name.isEmpty) return 'JD';
      final parts = name.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.length == 1) {
        return parts[0][0].toUpperCase();
      }
      return 'JD';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with upload capability
          CustomProfileImageUpload(
            currentImageUrl: employeeDetails.value?['employee_img'] as String?,
            radius: 60,
            initials: getInitials(),
            primaryColor: Theme.of(context).colorScheme.primary,
            onImageUploaded: (imageUrl) async {
              // Update employee profile with new image URL
              final success = await authViewModel.updateEmployeeProfile({
                'employee_img': imageUrl,
              });
              if (success) {
                // Refresh employee details to show updated image
                final details = await authViewModel.getCurrentEmployeeDetails();
                if (details != null) {
                  employeeDetails.value = Map<String, dynamic>.from(details);
                }
              }
            },
          ),
          const SizedBox(height: 16),

          // Name and Company
          Text(
            employeeDetails.value?['employee_name'] ?? 'Employee Name',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            employeeDetails.value?['employee_designation'] ?? 'Company Name',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),

          // Statistics
          _buildStatRow(
            context,
            'Employee ID',
            employeeDetails.value?['employee_id'] ?? 'N/A',
            Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            context,
            'Age',
            '${employeeDetails.value?['employee_age'] ?? 'N/A'} years',
            Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            context,
            'Blood Group',
            employeeDetails.value?['employee_blood_group'] ?? 'N/A',
            Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            context,
            'Phone Number',
            employeeDetails.value?['employee_phone_num'] ?? 'N/A',
            Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            context,
            'Gender',
            employeeDetails.value?['employee_gender'] ?? 'N/A',
            Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            context,
            'Designation',
            employeeDetails.value?['employee_designation'] ?? 'N/A',
            Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            context,
            'Role',
            employeeDetails.value?['employee_role'] ?? 'N/A',
            Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSettingsCard(
    BuildContext context,
    AuthViewModel authViewModel,
    ValueNotifier<Map<String, dynamic>?> employeeDetails,
    ValueNotifier<int> selectedTab, {
    required ValueNotifier<bool> isEditingPersonal,
    required ValueNotifier<bool> isEditingProfessional,
    required ObjectRef<Map<String, dynamic>?> prevPersonalFormEmployeeDetails,
    required TextEditingController personalFirstNameCtrl,
    required TextEditingController personalLastNameCtrl,
    required TextEditingController personalPhoneCtrl,
    required TextEditingController personalEmailCtrl,
    required TextEditingController companyEmailCtrl,
    required TextEditingController addressCtrl,
    required TextEditingController genderCtrl,
    required TextEditingController dobCtrl,
    required TextEditingController qualificationCtrl,
    required TextEditingController emergencyContactCtrl,
    required TextEditingController roleCtrl,
    required TextEditingController designationCtrl,
    required TextEditingController bloodGroupCtrl,
  }) {
    final tabs = [
      'Personal Info',
      'Professional',
      'Leave Details',
      'Documents',
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(tabs.length, (index) {
                final isSelected = selectedTab.value == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          selectedTab.value = index;
                        },
                        borderRadius: BorderRadius.circular(10),
                        splashColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.2),
                        highlightColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            tabs[index],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 24),

          // Tab Content
          if (selectedTab.value == 0)
            _buildPersonalInfoForm(
              context,
              authViewModel,
              employeeDetails,
              selectedTab,
              isEditing: isEditingPersonal,
              prevEmployeeDetailsRef: prevPersonalFormEmployeeDetails,
              firstNameCtrl: personalFirstNameCtrl,
              lastNameCtrl: personalLastNameCtrl,
              phoneCtrl: personalPhoneCtrl,
              personalEmailCtrl: personalEmailCtrl,
              companyEmailCtrl: companyEmailCtrl,
              addressCtrl: addressCtrl,
              genderCtrl: genderCtrl,
              dobCtrl: dobCtrl,
              qualificationCtrl: qualificationCtrl,
              emergencyContactCtrl: emergencyContactCtrl,
              bloodGroupCtrl: bloodGroupCtrl,
            )
          else if (selectedTab.value == 1)
            _buildProfessionalInfoForm(
              context,
              authViewModel,
              employeeDetails,
              selectedTab,
              isEditing: isEditingProfessional,
              roleCtrl: roleCtrl,
              designationCtrl: designationCtrl,
            )
          else if (selectedTab.value == 2)
            _buildLeaveDetailsForm(context, authViewModel, employeeDetails)
          else if (selectedTab.value == 3)
            _buildDocumentsTab(context),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoForm(
    BuildContext context,
    AuthViewModel authViewModel,
    ValueNotifier<Map<String, dynamic>?> employeeDetails,
    ValueNotifier<int> selectedTab, {
    required ValueNotifier<bool> isEditing,
    required ObjectRef<Map<String, dynamic>?> prevEmployeeDetailsRef,
    required TextEditingController firstNameCtrl,
    required TextEditingController lastNameCtrl,
    required TextEditingController phoneCtrl,
    required TextEditingController personalEmailCtrl,
    required TextEditingController companyEmailCtrl,
    required TextEditingController addressCtrl,
    required TextEditingController genderCtrl,
    required TextEditingController dobCtrl,
    required TextEditingController qualificationCtrl,
    required TextEditingController emergencyContactCtrl,
    required TextEditingController bloodGroupCtrl,
  }) {
    // Update controllers when employeeDetails changes (using ref to track changes)
    final prevEmployeeDetails = prevEmployeeDetailsRef;
    if (employeeDetails.value != null &&
        employeeDetails.value != prevEmployeeDetails.value &&
        !isEditing.value) {
      firstNameCtrl.text = _getFirstName(
        employeeDetails.value?['employee_name'] ?? '',
      );
      lastNameCtrl.text = _getLastName(
        employeeDetails.value?['employee_name'] ?? '',
      );
      phoneCtrl.text = employeeDetails.value?['employee_phone_num'] ?? '';
      personalEmailCtrl.text =
          employeeDetails.value?['employee_personal_email'] ?? '';
      companyEmailCtrl.text =
          employeeDetails.value?['employee_company_email'] ?? '';
      addressCtrl.text = employeeDetails.value?['employee_address'] ?? '';
      genderCtrl.text = employeeDetails.value?['employee_gender'] ?? '';
      dobCtrl.text = _formatDate(employeeDetails.value?['employee_dob']) ?? '';
      qualificationCtrl.text =
          employeeDetails.value?['employee_qualification'] ?? '';
      emergencyContactCtrl.text =
          employeeDetails.value?['employee_emergency_contact_number'] ?? '';
      bloodGroupCtrl.text =
          employeeDetails.value?['employee_blood_group'] ?? '';
      prevEmployeeDetails.value = employeeDetails.value;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Edit Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              if (!isEditing.value)
                ElevatedButton.icon(
                  onPressed: () => isEditing.value = true,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildFormField(
                  context,
                  'First Name',
                  firstNameCtrl,
                  Icons.person,
                  enabled: isEditing.value,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  context,
                  'Last Name',
                  lastNameCtrl,
                  Icons.person,
                  enabled: isEditing.value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildFormField(
                  context,
                  'Phone Number',
                  phoneCtrl,
                  Icons.phone,
                  enabled: isEditing.value,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  context,
                  'Gender',
                  genderCtrl,
                  Icons.person_outline,
                  enabled: isEditing.value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildFormField(
                  context,
                  'Personal Email',
                  personalEmailCtrl,
                  Icons.email,
                  enabled: isEditing.value,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  context,
                  'Company Email',
                  companyEmailCtrl,
                  Icons.business,
                  enabled: isEditing.value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildFormField(
                  context,
                  'Date of Birth',
                  dobCtrl,
                  Icons.calendar_today,
                  enabled: isEditing.value,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  context,
                  'Qualification',
                  qualificationCtrl,
                  Icons.school,
                  enabled: isEditing.value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFormField(
            context,
            'Address',
            addressCtrl,
            Icons.location_on,
            maxLines: 2,
            enabled: isEditing.value,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            context,
            'Emergency Contact Number',
            emergencyContactCtrl,
            Icons.emergency,
            enabled: isEditing.value,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            context,
            'Blood Group',
            bloodGroupCtrl,
            Icons.bloodtype,
            enabled: isEditing.value,
          ),
          if (isEditing.value) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Reset to original values
                      firstNameCtrl.text = _getFirstName(
                        employeeDetails.value?['employee_name'] ?? '',
                      );
                      lastNameCtrl.text = _getLastName(
                        employeeDetails.value?['employee_name'] ?? '',
                      );
                      phoneCtrl.text =
                          employeeDetails.value?['employee_phone_num'] ?? '';
                      personalEmailCtrl.text =
                          employeeDetails.value?['employee_personal_email'] ??
                          '';
                      companyEmailCtrl.text =
                          employeeDetails.value?['employee_company_email'] ??
                          '';
                      addressCtrl.text =
                          employeeDetails.value?['employee_address'] ?? '';
                      genderCtrl.text =
                          employeeDetails.value?['employee_gender'] ?? '';
                      dobCtrl.text =
                          _formatDate(employeeDetails.value?['employee_dob']) ??
                          '';
                      qualificationCtrl.text =
                          employeeDetails.value?['employee_qualification'] ??
                          '';
                      emergencyContactCtrl.text =
                          employeeDetails
                              .value?['employee_emergency_contact_number'] ??
                          '';
                      bloodGroupCtrl.text =
                          employeeDetails.value?['employee_blood_group'] ?? '';
                      isEditing.value = false;
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Show loading indicator
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) =>
                              const Center(child: CircularProgressIndicator()),
                        );
                      }

                      try {
                        final ok = await authViewModel.updateEmployeeProfile({
                          'employee_name':
                              '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}',
                          'employee_phone_num': phoneCtrl.text.trim(),
                          'employee_personal_email': personalEmailCtrl.text
                              .trim(),
                          'employee_company_email': companyEmailCtrl.text
                              .trim(),
                          'employee_address': addressCtrl.text.trim(),
                          'employee_gender': genderCtrl.text.trim(),
                          'employee_qualification': qualificationCtrl.text
                              .trim(),
                          'employee_emergency_contact_number':
                              emergencyContactCtrl.text.trim(),
                          'employee_blood_group': bloodGroupCtrl.text.trim(),
                        });

                        // Close loading indicator
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }

                        if (ok) {
                          final refreshed = await authViewModel
                              .getCurrentEmployeeDetails();
                          if (refreshed != null) {
                            employeeDetails.value = Map<String, dynamic>.from(
                              refreshed,
                            );
                          }
                          isEditing.value = false;
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Personal information updated successfully',
                                ),
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to update profile. Please try again.',
                                ),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        // Close loading indicator
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error updating profile: ${e.toString()}',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfessionalInfoForm(
    BuildContext context,
    AuthViewModel authViewModel,
    ValueNotifier<Map<String, dynamic>?> employeeDetails,
    ValueNotifier<int> selectedTab, {
    required ValueNotifier<bool> isEditing,
    required TextEditingController roleCtrl,
    required TextEditingController designationCtrl,
  }) {
    // Read-only fields
    final employeeId = employeeDetails.value?['employee_id'] ?? 'N/A';
    final doj = _formatDate(employeeDetails.value?['employee_doj']) ?? 'N/A';
    final salary =
        employeeDetails.value?['employee_actual_salary']?.toString() ?? 'N/A';
    final lastLogin =
        _formatDateTime(employeeDetails.value?['last_login']) ?? 'N/A';
    final lastLogout =
        _formatDateTime(employeeDetails.value?['last_logout']) ?? 'N/A';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Read-only Information Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(context, 'Employee ID', employeeId, Icons.badge),
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  'Date of Joining',
                  doj,
                  Icons.calendar_today,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  'Salary',
                  '₹$salary',
                  Icons.attach_money,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(context, 'Last Login', lastLogin, Icons.login),
                const SizedBox(height: 12),
                _buildInfoRow(context, 'Last Logout', lastLogout, Icons.logout),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Editable Fields Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Professional Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              if (!isEditing.value)
                ElevatedButton.icon(
                  onPressed: () => isEditing.value = true,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildFormField(
                  context,
                  'Designation',
                  designationCtrl,
                  Icons.badge,
                  enabled: isEditing.value,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  context,
                  'Role',
                  roleCtrl,
                  Icons.work_outline,
                  enabled: isEditing.value,
                ),
              ),
            ],
          ),
          if (isEditing.value) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Reset to original values
                      roleCtrl.text =
                          employeeDetails.value?['employee_role'] ?? '';
                      designationCtrl.text =
                          employeeDetails.value?['employee_designation'] ?? '';
                      isEditing.value = false;
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Show loading indicator
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) =>
                              const Center(child: CircularProgressIndicator()),
                        );
                      }

                      try {
                        final ok = await authViewModel.updateEmployeeProfile({
                          'employee_role': roleCtrl.text.trim(),
                          'employee_designation': designationCtrl.text.trim(),
                        });

                        // Close loading indicator
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }

                        if (ok) {
                          final refreshed = await authViewModel
                              .getCurrentEmployeeDetails();
                          if (refreshed != null) {
                            employeeDetails.value = Map<String, dynamic>.from(
                              refreshed,
                            );
                          }
                          isEditing.value = false;
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Professional information updated successfully',
                                ),
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to update profile. Please try again.',
                                ),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        // Close loading indicator
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error updating profile: ${e.toString()}',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final ok = await authViewModel.updateEmployeeProfile({
                  'employee_role': roleCtrl.text.trim(),
                  'employee_designation': designationCtrl.text.trim(),
                });
                if (ok) {
                  final refreshed = await authViewModel
                      .getCurrentEmployeeDetails();
                  if (refreshed != null) {
                    employeeDetails.value = Map<String, dynamic>.from(
                      refreshed,
                    );
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Professional information updated successfully',
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Update Professional Info',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveDetailsForm(
    BuildContext context,
    AuthViewModel authViewModel,
    ValueNotifier<Map<String, dynamic>?> employeeDetails,
  ) {
    return Consumer<LeavePolicyViewModel>(
      builder: (context, leavePolicyVM, _) {
        if (leavePolicyVM.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final status = leavePolicyVM.status;
        if (status == null) {
          return Center(
            child: Column(
              children: [
                const Text('Failed to load leave policy'),
                TextButton(
                  onPressed: () {
                    final empId = employeeDetails.value?['employee_id'];
                    if (empId != null) leavePolicyVM.fetchStatus(empId);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Leave Policy & Usage (${status.monthName} ${status.year})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 16),

              _buildUsageCard(
                context,
                title: 'Casual/Sick Leaves',
                usage: status.leaves,
                unit: 'Days',
                icon: Icons.calendar_month,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),

              _buildUsageCard(
                context,
                title: 'Permissions',
                usage: status.permissions,
                unit: 'Hours',
                icon: Icons.access_time_filled,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),

              _buildUsageCard(
                context,
                title: 'Work From Home',
                usage: status.wfh,
                unit: 'Days',
                icon: Icons.home_work,
                color: Colors.green,
              ),

              const SizedBox(height: 24),
              // Original yearly balance for context
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yearly Summary',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      'Total Annual Leaves',
                      employeeDetails
                              .value?['employee_total_leave_days_in_year']
                              ?.toString() ??
                          'N/A',
                      Icons.event_available,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsageCard(
    BuildContext context, {
    required String title,
    required dynamic usage, // LeaveUsage
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    final double allowed = usage.allowed;
    final double used = usage.used;
    final double remaining = usage.remaining;
    final double progress = allowed > 0
        ? (used / allowed).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: remaining > 0
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$remaining $unit Left',
                  style: TextStyle(
                    color: remaining > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(context).dividerColor.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSimpleStat('Allowed', '$allowed', unit),
              _buildSimpleStat('Used', '$used', unit),
              _buildSimpleStat('Remaining', '$remaining', unit),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          '$value $unit',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormField(
    BuildContext context,
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          readOnly: !enabled,
          style: TextStyle(
            color: enabled
                ? Theme.of(context).textTheme.bodyLarge?.color
                : Theme.of(
                    context,
                  ).textTheme.bodyLarge?.color?.withOpacity(0.6),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: CommonColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab(BuildContext context) {
    return const DocumentTab();
  }

  String _getFirstName(String fullName) {
    if (fullName.isEmpty) return '';
    final parts = fullName.split(' ');
    return parts.isNotEmpty ? parts[0] : '';
  }

  String _getLastName(String fullName) {
    if (fullName.isEmpty) return '';
    final parts = fullName.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  String? _formatDate(dynamic dateValue) {
    if (dateValue == null) return null;
    try {
      if (dateValue is String) {
        // Handle different date formats
        if (dateValue.contains('-')) {
          final parts = dateValue.split('-');
          if (parts.length >= 3) {
            return '${parts[2]}/${parts[1]}/${parts[0]}';
          }
        }
        // Try to parse as DateTime
        final date = DateTime.tryParse(dateValue);
        if (date != null) {
          return '${date.day}/${date.month}/${date.year}';
        }
      }
      return dateValue.toString();
    } catch (e) {
      return dateValue.toString();
    }
  }

  String? _formatDateTime(dynamic dateTimeValue) {
    if (dateTimeValue == null) return null;
    try {
      DateTime? dateTime;
      if (dateTimeValue is String) {
        dateTime = DateTime.tryParse(dateTimeValue);
      } else if (dateTimeValue is DateTime) {
        dateTime = dateTimeValue;
      }

      if (dateTime != null) {
        // Format as "DD/MM/YYYY HH:MM AM/PM"
        final day = dateTime.day.toString().padLeft(2, '0');
        final month = dateTime.month.toString().padLeft(2, '0');
        final year = dateTime.year;
        final hour = dateTime.hour > 12
            ? dateTime.hour - 12
            : (dateTime.hour == 0 ? 12 : dateTime.hour);
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
        return '$day/$month/$year $hour:$minute $amPm';
      }
      return dateTimeValue.toString();
    } catch (e) {
      return dateTimeValue.toString();
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(CommonColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading profile...',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'Profile Not Available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please contact your administrator to resolve this issue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
