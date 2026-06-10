import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webnox_taskops/helpers/common_colors.dart';
import 'package:webnox_taskops/utils/responsive_utils.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import 'package:webnox_taskops/services/local_storage_service.dart';
import 'package:webnox_taskops/providers/theme_provider.dart';
import 'package:webnox_taskops/screens/settings/documentation_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
      body: SafeArea(
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
                    mobile: 20,
                    tablet: 24,
                    desktop: 32,
                  ),
                ),

                // Settings Content
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column - General Settings & Version Info
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            _buildGeneralSettings(
                              context,
                              isDesktop,
                              isTablet,
                              isMobile,
                              isSmallMobile,
                              isVerySmallMobile,
                            ),
                            const SizedBox(height: 24),
                            _buildVersionInfo(
                              context,
                              isDesktop,
                              isTablet,
                              isMobile,
                              isSmallMobile,
                              isVerySmallMobile,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column - Account Settings
                      Expanded(
                        flex: 1,
                        child: _buildAccountSettings(
                          context,
                          isDesktop,
                          isTablet,
                          isMobile,
                          isSmallMobile,
                          isVerySmallMobile,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildGeneralSettings(
                        context,
                        isDesktop,
                        isTablet,
                        isMobile,
                        isSmallMobile,
                        isVerySmallMobile,
                      ),
                      const SizedBox(height: 20),
                      _buildAccountSettings(
                        context,
                        isDesktop,
                        isTablet,
                        isMobile,
                        isSmallMobile,
                        isVerySmallMobile,
                      ),
                      const SizedBox(height: 20),
                      _buildVersionInfo(
                        context,
                        isDesktop,
                        isTablet,
                        isMobile,
                        isSmallMobile,
                        isVerySmallMobile,
                      ),
                    ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
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
          'Manage your account settings and preferences',
          style: TextStyle(
            color: isDark
                ? Colors.white.withOpacity(0.5)
                : Colors.black54,
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

  Widget _buildGeneralSettings(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    bool isSmallMobile,
    bool isVerySmallMobile,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(
        isDesktop
            ? 24
            : isTablet
                ? 20
                : 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_outlined,
                color: Color(0xFF38BDF8),
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'General Settings',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: isVerySmallMobile
                      ? 16
                      : isSmallMobile
                          ? 17
                          : isMobile
                              ? 18
                              : isTablet
                                  ? 20
                                  : 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _GranularNotificationSettings(
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
            isSmallMobile: isSmallMobile,
            isVerySmallMobile: isVerySmallMobile,
          ),
          _ThemeSettings(
            isDesktop: isDesktop,
            isTablet: isTablet,
            isMobile: isMobile,
            isSmallMobile: isSmallMobile,
            isVerySmallMobile: isVerySmallMobile,
          ),
          _buildSettingItem(
            context,
            'Documentation',
            'Learn how to use the app',
            Icons.description_outlined,
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DocumentationScreen(),
                ),
              );
            },
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

  Widget _buildAccountSettings(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    bool isSmallMobile,
    bool isVerySmallMobile,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(
        isDesktop
            ? 24
            : isTablet
                ? 20
                : 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.manage_accounts_outlined,
                color: Color(0xFF38BDF8),
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'Account Settings',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: isVerySmallMobile
                      ? 16
                      : isSmallMobile
                          ? 17
                          : isMobile
                              ? 18
                              : isTablet
                                  ? 20
                                  : 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSettingItem(
            context,
            'Profile',
            'Edit your profile information',
            Icons.person_outline_rounded,
            () {
              Navigator.of(context).pushReplacementNamed('/profile');
            },
            isDesktop,
            isTablet,
            isMobile,
            isSmallMobile,
            isVerySmallMobile,
          ),
          _buildSettingItem(
            context,
            'Security',
            'Change password and security settings',
            Icons.shield_outlined,
            () {
              Navigator.of(context).pushReplacementNamed('/change-password');
            },
            isDesktop,
            isTablet,
            isMobile,
            isSmallMobile,
            isVerySmallMobile,
          ),
          _PrivacySettings(
            isDesktop,
            isTablet,
            isMobile,
            isSmallMobile,
            isVerySmallMobile,
          ),
          const SizedBox(height: 24),
          Consumer<AuthViewModel>(
            builder: (context, authViewModel, child) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Navigate through the ViewModel's confirm logout dialog
                    await authViewModel.logoutWithAppNavigation(context);
                  },
                  icon: const Icon(
                    Icons.logout,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFFEF4444).withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    bool isSmallMobile,
    bool isVerySmallMobile,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        horizontalTitleGap: 16,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF38BDF8).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF38BDF8),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: isVerySmallMobile
                ? 13
                : isSmallMobile
                    ? 14
                    : 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
            fontSize: isVerySmallMobile
                ? 11
                : isSmallMobile
                    ? 12
                    : 13,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isDark ? Colors.white.withOpacity(0.3) : Colors.black38,
          size: 14,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildVersionInfo(
    BuildContext context,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    bool isSmallMobile,
    bool isVerySmallMobile,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(
        isDesktop
            ? 24
            : isTablet
                ? 20
                : 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Version & Build Information',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: isVerySmallMobile
                  ? 16
                  : isSmallMobile
                      ? 17
                      : isMobile
                          ? 18
                          : isTablet
                              ? 20
                              : 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _buildVersionItem(
            context,
            'App Version',
            '1.0.0 (Build 124) • Last updated: Oct 24, 2023',
            Icons.info_outline,
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

  Widget _buildVersionItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    bool isSmallMobile,
    bool isVerySmallMobile,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isDark ? Colors.white70 : Colors.black54,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GranularNotificationSettings extends StatefulWidget {
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;
  final bool isSmallMobile;
  final bool isVerySmallMobile;

  const _GranularNotificationSettings({
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
    required this.isSmallMobile,
    required this.isVerySmallMobile,
  });

  @override
  State<_GranularNotificationSettings> createState() =>
      _GranularNotificationSettingsState();
}

class _GranularNotificationSettingsState
    extends State<_GranularNotificationSettings> {
  final LocalStorageService _storageService = LocalStorageService();
  bool _notifyOnMessage = true;
  bool _notifyOnAssignment = true;
  bool _notifyOnUpdate = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _notifyOnMessage = _storageService.notifyOnMessage;
    _notifyOnAssignment = _storageService.notifyOnAssignment;
    _notifyOnUpdate = _storageService.notifyOnUpdate;
  }

  Future<void> _toggleMessage(bool value) async {
    setState(() => _notifyOnMessage = value);
    await _storageService.saveNotifyOnMessage(value);
  }

  Future<void> _toggleAssignment(bool value) async {
    setState(() => _notifyOnAssignment = value);
    await _storageService.saveNotifyOnAssignment(value);
  }

  Future<void> _toggleUpdate(bool value) async {
    setState(() => _notifyOnUpdate = value);
    await _storageService.saveNotifyOnUpdate(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          tilePadding: EdgeInsets.zero,
          trailing: Icon(
            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: isDark ? Colors.white.withOpacity(0.4) : Colors.black38,
            size: 20,
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.notifications_none_outlined,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Manage notification preferences',
                      style: TextStyle(
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 48, right: 8, top: 4, bottom: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Messages & Chat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                      ),
                    ),
                    value: _notifyOnMessage,
                    onChanged: _toggleMessage,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF3B82F6),
                    inactiveThumbColor: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                    inactiveTrackColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: Text(
                      'Task & Project Assignments',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                      ),
                    ),
                    value: _notifyOnAssignment,
                    onChanged: _toggleAssignment,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF3B82F6),
                    inactiveThumbColor: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                    inactiveTrackColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: Text(
                      'Attendance and Report',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                      ),
                    ),
                    value: _notifyOnUpdate,
                    onChanged: _toggleUpdate,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF3B82F6),
                    inactiveThumbColor: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                    inactiveTrackColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacySettings extends StatefulWidget {
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;
  final bool isSmallMobile;
  final bool isVerySmallMobile;

  const _PrivacySettings(
    this.isDesktop,
    this.isTablet,
    this.isMobile,
    this.isSmallMobile,
    this.isVerySmallMobile,
  );

  @override
  State<_PrivacySettings> createState() => _PrivacySettingsState();
}

class _PrivacySettingsState extends State<_PrivacySettings> {
  final LocalStorageService _storage = LocalStorageService();
  bool _useGPS = true;
  bool _useIP = true;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthViewModel>().fetchSessions();
      }
    });
  }

  void _loadPrivacySettings() {
    setState(() {
      _useGPS = _storage.useGPS;
      _useIP = _storage.useIP;
    });
  }

  IconData _getDeviceIcon(String platform, Map<String, dynamic> session) {
    final p = platform.toLowerCase();
    if (p.contains('android')) return Icons.android_rounded;
    if (p.contains('ios') || p.contains('macos')) return Icons.apple_rounded;
    if (p.contains('windows')) return Icons.desktop_windows_rounded;
    if (p.contains('web') || session['browser'] != null) {
      return Icons.language_rounded;
    }
    return Icons.devices_rounded;
  }

  String _getLocationString(Map<String, dynamic> session) {
    final city = session['city']?.toString();
    final country = session['country']?.toString();
    List<String> parts = [];
    if (city != null && city.isNotEmpty && city != 'Unknown') parts.add(city);
    if (country != null && country.isNotEmpty && country != 'Unknown') {
      parts.add(country);
    }

    if (parts.isEmpty) {
      return session['location'] ?? session['ip_address'] ?? 'Unknown Location';
    }
    return parts.join(', ');
  }

  String _getTimeAgo(dynamic updatedAt) {
    if (updatedAt == null) return "Just now";
    try {
      DateTime lastActive = DateTime.parse(updatedAt.toString()).toLocal();
      Duration diff = DateTime.now().difference(lastActive);

      if (diff.isNegative) return "Just now";
      if (diff.inSeconds < 60) return "Just now";
      if (diff.inMinutes < 60) {
        return "Last active ${diff.inMinutes}m ago";
      }
      if (diff.inHours < 24) {
        return "Last active ${diff.inHours}h ago";
      }
      if (diff.inDays < 30) {
        return "Last active ${diff.inDays}d ago";
      }

      return "Last active ${lastActive.day}/${lastActive.month}/${lastActive.year}";
    } catch (e) {
      return "Just now";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _isExpanded
            ? (isDark ? const Color(0xFF162032) : const Color(0xFFF8FAFC))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded
              ? (isDark ? const Color(0xFF38BDF8).withOpacity(0.3) : const Color(0xFF38BDF8).withOpacity(0.5))
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _isExpanded ? 16 : 0,
        vertical: _isExpanded ? 8 : 0,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          tilePadding: EdgeInsets.zero,
          trailing: Icon(
            _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: isDark ? Colors.white.withOpacity(0.4) : Colors.black38,
            size: 20,
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFF38BDF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy & Security',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Manage privacy and data settings',
                      style: TextStyle(
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location & Tracking',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    title: Text(
                      'Use GPS for Attendance',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'Validate location via GPS coordinates',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                      ),
                    ),
                    value: _useGPS,
                    onChanged: (value) async {
                      await _storage.saveUseGPS(value);
                      setState(() => _useGPS = value);
                    },
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF3B82F6),
                    inactiveThumbColor: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                    inactiveTrackColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: Text(
                      'Use IP for Attendance',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'Validate location via office network',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                      ),
                    ),
                    value: _useIP,
                    onChanged: (value) async {
                      await _storage.saveUseIP(value);
                      setState(() => _useIP = value);
                    },
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF3B82F6),
                    inactiveThumbColor: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
                    inactiveTrackColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 24),
                  Text(
                    'Active Sessions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white.withOpacity(0.6) : Colors.black54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer<AuthViewModel>(
                    builder: (context, authVM, child) {
                      if (authVM.isLoadingSessions) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      } else if (authVM.activeSessions.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No other active sessions found.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white30 : Colors.black38,
                            ),
                          ),
                        );
                      } else {
                        return Column(
                          children: authVM.activeSessions.map((session) {
                            String deviceName =
                                session['device_name'] ?? 'Unknown Device';
                            String platform =
                                session['platform'] ?? 'Unknown Platform';

                            if (deviceName == 'Unknown') {
                              deviceName = 'Unknown Device';
                            }
                            if (platform == 'Unknown') {
                              platform = 'Connected Device';
                            }
                            final isCurrentDevice = session['jwt_token'] ==
                                authVM.localStorage.accessToken;

                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF090E1A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Device Icon Container
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0D1527) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      _getDeviceIcon(platform, session),
                                      size: 20,
                                      color: const Color(0xFF38BDF8),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Session Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                session['browser'] != null
                                                    ? "${session['browser']} on $platform"
                                                    : deviceName,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isCurrentDevice) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF38BDF8).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: const Color(0xFF38BDF8).withOpacity(0.2),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'ACTIVE NOW',
                                                  style: TextStyle(
                                                    fontSize: 7,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF38BDF8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${_getLocationString(session)} • ${isCurrentDevice ? 'Active now' : _getTimeAgo(session['updated_at'])}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Refresh Button
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: isDark ? null : Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                        color: Color(0xFF38BDF8),
                                      ),
                                      onPressed: () {
                                        authVM.fetchSessions();
                                      },
                                    ),
                                  ),
                                  if (!isCurrentDevice) ...[
                                    const SizedBox(width: 8),
                                    // Revoke Button
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: isDark ? null : Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: Color(0xFFEF4444),
                                        ),
                                        onPressed: () {
                                          _showLogoutSpecificDeviceDialog(context, session);
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutSpecificDeviceDialog(
      BuildContext context, Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: Text(
            'Are you sure you want to log out from "${session['device_name'] ?? 'this device'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await context
                  .read<AuthViewModel>()
                  .logoutFromDevice(session['id']?.toString() ?? '');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Device removed successfully'
                        : 'Failed to remove device'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CommonColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _ThemeSettings extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;
  final bool isSmallMobile;
  final bool isVerySmallMobile;

  const _ThemeSettings({
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
    required this.isSmallMobile,
    required this.isVerySmallMobile,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFF38BDF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Theme',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Choose light or dark theme',
                          style: TextStyle(
                            color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 48, right: 8, top: 4, bottom: 8),
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: Text(
                          'Light Mode',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                          ),
                        ),
                        value: ThemeMode.light,
                        groupValue: themeProvider.themeMode,
                        onChanged: (value) {
                          if (value != null) themeProvider.setTheme(value);
                        },
                        activeColor: const Color(0xFF3B82F6),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<ThemeMode>(
                        title: Text(
                          'Dark Mode',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                          ),
                        ),
                        value: ThemeMode.dark,
                        groupValue: themeProvider.themeMode,
                        onChanged: (value) {
                          if (value != null) themeProvider.setTheme(value);
                        },
                        activeColor: const Color(0xFF3B82F6),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<ThemeMode>(
                        title: Text(
                          'System Default',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
                          ),
                        ),
                        value: ThemeMode.system,
                        groupValue: themeProvider.themeMode,
                        onChanged: (value) {
                          if (value != null) themeProvider.setTheme(value);
                        },
                        activeColor: const Color(0xFF3B82F6),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
