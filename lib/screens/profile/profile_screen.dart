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
import 'package:google_fonts/google_fonts.dart';

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
    final joinDateCtrl = useTextEditingController();

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
          joinDateCtrl.text = _formatDate(currentData['employee_doj']) ?? '';
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
      joinDateCtrl: joinDateCtrl,
    );

    final tabBar = _buildTabBar(context, selectedTab);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null,
      body: SafeArea(
        child: isLoadingEmployee.value
            ? _buildLoadingState()
            : employeeDetails.value == null
            ? _buildErrorState()
            : SingleChildScrollView(
                child: Padding(
                  padding: ResponsiveUtils.getResponsivePadding(
                    context,
                    mobile: const EdgeInsets.all(16),
                    tablet: const EdgeInsets.all(20),
                    laptop: const EdgeInsets.all(22),
                    desktop: const EdgeInsets.all(24),
                  ),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 1, child: profileCard),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  tabBar,
                                  const SizedBox(height: 20),
                                  settingsCard,
                                ],
                              ),
                            ),
                          ],
                        )
                      : isLaptop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: profileCard),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      tabBar,
                                      const SizedBox(height: 20),
                                      settingsCard,
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : isTablet
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 1, child: profileCard),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          tabBar,
                                          const SizedBox(height: 20),
                                          settingsCard,
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    profileCard,
                                    const SizedBox(height: 20),
                                    tabBar,
                                    const SizedBox(height: 20),
                                    settingsCard,
                                  ],
                                ),
                ),
              ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, ValueNotifier<int> selectedTab) {
    final tabs = [
      'Personal Info',
      'Professional',
      'Leave Details',
      'Documents',
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 1.2,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(tabs.length, (index) {
            final isSelected = selectedTab.value == index;
            return Padding(
              padding: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 8),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    selectedTab.value = index;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      tabs[index],
                      style: GoogleFonts.outfit(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white60 : Colors.black54),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
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

    final statusVal = employeeDetails.value?['employee_status'] ?? 'Active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          // Avatar with glowing ring
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CustomProfileImageUpload(
              currentImageUrl: employeeDetails.value?['employee_img'] as String?,
              radius: 64,
              initials: getInitials(),
              primaryColor: const Color(0xFF3B82F6),
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
          ),
          const SizedBox(height: 20),

          // Name and Designation
          Text(
            employeeDetails.value?['employee_name'] ?? 'Employee Name',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            employeeDetails.value?['employee_designation'] ?? 'Visual Designer',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          const Divider(
            color: Color(0xFF1E293B),
            height: 32,
            thickness: 1.2,
          ),

          // Statistics rows
          _buildStatRow(
            context,
            'Employee ID',
            employeeDetails.value?['employee_id'] ?? 'N/A',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 18),
          _buildStatRow(
            context,
            'Age',
            employeeDetails.value?['employee_age'] != null
                ? '${employeeDetails.value!['employee_age']} years'
                : 'N/A',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 18),
          _buildStatRow(
            context,
            'Blood Group',
            employeeDetails.value?['employee_blood_group'] ?? '-',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 18),
          _buildStatRow(
            context,
            'Phone Number',
            employeeDetails.value?['employee_phone_num'] ?? 'N/A',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 18),
          _buildStatRow(
            context,
            'Gender',
            employeeDetails.value?['employee_gender'] ?? 'N/A',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 18),
          _buildStatRow(
            context,
            'Designation',
            employeeDetails.value?['employee_designation'] ?? 'N/A',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 18),
          _buildStatRow(
            context,
            'Role',
            employeeDetails.value?['employee_role'] ?? 'N/A',
            const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 18),
          _buildStatRow(
            context,
            'Status',
            '',
            const Color(0xFF3B82F6),
            customValueWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.4),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusVal,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF34D399),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    Color color, {
    Widget? customValueWidget,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
        customValueWidget ??
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
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
    required TextEditingController joinDateCtrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              joinDateCtrl: joinDateCtrl,
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
    required TextEditingController joinDateCtrl,
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
      joinDateCtrl.text =
          _formatDate(employeeDetails.value?['employee_doj']) ?? '';
      prevEmployeeDetails.value = employeeDetails.value;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with inline Edit Profile button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Information',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Update your personal details and contact information.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isEditing.value)
                ElevatedButton.icon(
                  onPressed: () => isEditing.value = true,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(
                    'Edit Profile',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          // Fields Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildFormField(
                  context,
                  'First Name',
                  firstNameCtrl,
                  Icons.person_outline,
                  enabled: isEditing.value,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  context,
                  'Last Name',
                  lastNameCtrl,
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
                  'Phone Number',
                  phoneCtrl,
                  Icons.phone_outlined,
                  enabled: isEditing.value,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  context,
                  'Gender',
                  genderCtrl,
                  Icons.wc_outlined,
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
                  Icons.email_outlined,
                  enabled: isEditing.value,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  context,
                  'Company Email',
                  companyEmailCtrl,
                  Icons.business_outlined,
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
                  Icons.calendar_today_outlined,
                  enabled: isEditing.value,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  context,
                  'Qualification',
                  qualificationCtrl,
                  Icons.school_outlined,
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
                  'Emergency Contact',
                  emergencyContactCtrl,
                  Icons.phone_iphone_outlined,
                  enabled: isEditing.value,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  context,
                  'Join Date',
                  joinDateCtrl,
                  Icons.calendar_month_outlined,
                  enabled: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFormField(
            context,
            'Address',
            addressCtrl,
            Icons.location_on_outlined,
            maxLines: 2,
            enabled: isEditing.value,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            context,
            'Blood Group',
            bloodGroupCtrl,
            Icons.bloodtype_outlined,
            enabled: isEditing.value,
          ),
          
          if (isEditing.value) ...[
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ElevatedButton.icon(
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
                        'employee_personal_email': personalEmailCtrl.text.trim(),
                        'employee_company_email': companyEmailCtrl.text.trim(),
                        'employee_address': addressCtrl.text.trim(),
                        'employee_gender': genderCtrl.text.trim(),
                        'employee_qualification': qualificationCtrl.text.trim(),
                        'employee_emergency_contact_number':
                            emergencyContactCtrl.text.trim(),
                        'employee_blood_group': bloodGroupCtrl.text.trim(),
                      });

                      // Close loading indicator
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }

                      if (ok) {
                        final refreshed = await authViewModel.getCurrentEmployeeDetails();
                        if (refreshed != null) {
                          employeeDetails.value = Map<String, dynamic>.from(refreshed);
                        }
                        isEditing.value = false;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Personal information updated successfully'),
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to update profile. Please try again.'),
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
                            content: Text('Error updating profile: ${e.toString()}'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    'Save Changes',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
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
                        employeeDetails.value?['employee_personal_email'] ?? '';
                    companyEmailCtrl.text =
                        employeeDetails.value?['employee_company_email'] ?? '';
                    addressCtrl.text =
                        employeeDetails.value?['employee_address'] ?? '';
                    genderCtrl.text =
                        employeeDetails.value?['employee_gender'] ?? '';
                    dobCtrl.text =
                        _formatDate(employeeDetails.value?['employee_dob']) ?? '';
                    qualificationCtrl.text =
                        employeeDetails.value?['employee_qualification'] ?? '';
                    emergencyContactCtrl.text =
                        employeeDetails.value?['employee_emergency_contact_number'] ?? '';
                    bloodGroupCtrl.text =
                        employeeDetails.value?['employee_blood_group'] ?? '';
                    isEditing.value = false;
                  },
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                  label: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    side: const BorderSide(color: Color(0xFF1E293B), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
          // Header Row with inline Edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Professional Details',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Update your professional role and designation.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isEditing.value)
                ElevatedButton.icon(
                  onPressed: () => isEditing.value = true,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(
                    'Edit Details',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          // Read-only Information Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F19),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1E293B),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee Information',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(context, 'Employee ID', employeeId, Icons.badge_outlined),
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  'Date of Joining',
                  doj,
                  Icons.calendar_today_outlined,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  'Salary',
                  '₹$salary',
                  Icons.currency_rupee_rounded,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(context, 'Last Login', lastLogin, Icons.login_rounded),
                const SizedBox(height: 12),
                _buildInfoRow(context, 'Last Logout', lastLogout, Icons.logout_rounded),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Editable Fields Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildFormField(
                  context,
                  'Designation',
                  designationCtrl,
                  Icons.badge_outlined,
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
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ElevatedButton.icon(
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
                        final refreshed = await authViewModel.getCurrentEmployeeDetails();
                        if (refreshed != null) {
                          employeeDetails.value = Map<String, dynamic>.from(refreshed);
                        }
                        isEditing.value = false;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Professional information updated successfully'),
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to update profile. Please try again.'),
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
                            content: Text('Error updating profile: ${e.toString()}'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    'Save Changes',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    // Reset to original values
                    roleCtrl.text =
                        employeeDetails.value?['employee_role'] ?? '';
                    designationCtrl.text =
                        employeeDetails.value?['employee_designation'] ?? '';
                    isEditing.value = false;
                  },
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                  label: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    side: const BorderSide(color: Color(0xFF1E293B), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),

              _buildUsageCard(
                context,
                title: 'Casual/Sick Leaves',
                usage: status.leaves,
                unit: 'Days',
                icon: Icons.calendar_month_outlined,
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 16),

              _buildUsageCard(
                context,
                title: 'Permissions',
                usage: status.permissions,
                unit: 'Hours',
                icon: Icons.access_time_filled_outlined,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 16),

              _buildUsageCard(
                context,
                title: 'Work From Home',
                usage: status.wfh,
                unit: 'Days',
                icon: Icons.home_work_outlined,
                color: const Color(0xFF10B981),
              ),

              const SizedBox(height: 24),
              // Original yearly balance for context
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0F19),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1E293B),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yearly Summary',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      context,
                      'Total Annual Leaves',
                      employeeDetails
                              .value?['employee_total_leave_days_in_year']
                              ?.toString() ??
                          'N/A',
                      Icons.event_available_outlined,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 1.2,
        ),
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
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: remaining > 0
                      ? const Color(0xFF064E3B).withOpacity(0.2)
                      : const Color(0xFF7F1D1D).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: remaining > 0 
                        ? const Color(0xFF10B981).withOpacity(0.4) 
                        : const Color(0xFFEF4444).withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$remaining $unit Left',
                  style: GoogleFonts.inter(
                    color: remaining > 0 ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF1E293B),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
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
          style: GoogleFonts.outfit(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 4),
        Text(
          '$value $unit',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.white,
          ),
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
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF3B82F6),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          readOnly: !enabled,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: enabled ? Colors.white : Colors.white60,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              size: 18,
              color: enabled ? Colors.white54 : Colors.white30,
            ),
            filled: true,
            fillColor: const Color(0xFF0B0F19),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF1E293B),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF1E293B),
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF1E293B),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
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
