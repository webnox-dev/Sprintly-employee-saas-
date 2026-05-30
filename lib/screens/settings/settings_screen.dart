import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webnox_taskops/helpers/common_colors.dart';
import 'package:webnox_taskops/utils/responsive_utils.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import 'package:webnox_taskops/services/local_storage_service.dart';
import 'package:webnox_taskops/providers/theme_provider.dart';
import 'package:webnox_taskops/screens/settings/documentation_screen.dart';
import 'package:webnox_taskops/screens/settings/widgets/active_sessions_card.dart';

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
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column - General Settings
                          Expanded(
                            flex: 1,
                            child: _buildGeneralSettings(
                              context,
                              isDesktop,
                              isTablet,
                              isMobile,
                              isSmallMobile,
                              isVerySmallMobile,
                            ),
                          ),
                          SizedBox(width: 24),
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
                      ),
                      SizedBox(height: 24),
                      // Version Info Section
                      _buildVersionInfo(
                        context,
                        isDesktop,
                        isTablet,
                        isMobile,
                        isSmallMobile,
                        isVerySmallMobile,
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
                      SizedBox(height: 20),
                      _buildAccountSettings(
                        context,
                        isDesktop,
                        isTablet,
                        isMobile,
                        isSmallMobile,
                        isVerySmallMobile,
                      ),
                      SizedBox(height: 20),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
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
          'Manage your account settings and preferences',
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

  Widget _buildGeneralSettings(
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
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General Settings',
            style: TextStyle(
              color: Theme.of(context).textTheme.titleLarge?.color,
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
          SizedBox(height: 20),
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
            Icons.menu_book,
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
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Settings',
            style: TextStyle(
              color: Theme.of(context).textTheme.titleLarge?.color,
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
          SizedBox(height: 20),
          _buildSettingItem(
            context,
            'Profile',
            'Edit your profile information',
            Icons.person,
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
            Icons.security,
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
          SizedBox(height: 20),
          const ActiveSessionsCard(),
          SizedBox(height: 20),
          Consumer<AuthViewModel>(
            builder: (context, authViewModel, child) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await authViewModel.logoutWithAppNavigation(context);
                  },
                  icon: Icon(
                    Icons.logout,
                    color: CommonColors.dangerRed,
                    size: isVerySmallMobile
                        ? 16
                        : isSmallMobile
                            ? 18
                            : isMobile
                                ? 20
                                : 22,
                  ),
                  label: Text(
                    'Sign Out',
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CommonColors.dangerRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      vertical: isVerySmallMobile
                          ? 12
                          : isSmallMobile
                              ? 14
                              : isMobile
                                  ? 16
                                  : 18,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        horizontalTitleGap: 16,
        leading: Container(
          padding: EdgeInsets.all(
            isVerySmallMobile
                ? 6
                : isSmallMobile
                    ? 8
                    : isMobile
                        ? 10
                        : 12,
          ),
          decoration: BoxDecoration(
            color: CommonColors.primary.withOpacity(0.1),
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
          child: Icon(
            icon,
            color: CommonColors.primary,
            size: isVerySmallMobile
                ? 16
                : isSmallMobile
                    ? 18
                    : isMobile
                        ? 20
                        : 22,
          ),
        ),
        title: Text(
          title,
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
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withOpacity(0.7),
            fontSize: isVerySmallMobile
                ? 10
                : isSmallMobile
                    ? 11
                    : isMobile
                        ? 12
                        : isTablet
                            ? 13
                            : 14,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
          size: isVerySmallMobile
              ? 12
              : isSmallMobile
                  ? 14
                  : isMobile
                      ? 16
                      : isTablet
                          ? 18
                          : 20,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Version & Build Information',
            style: TextStyle(
              color: Theme.of(context).textTheme.titleLarge?.color,
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
          SizedBox(height: 20),
          // TODO: Update version information manually
          // Update the values below when releasing new versions
          _buildVersionItem(
            context,
            'App Version',
            '1.0.0 (Build 1)', // Update this version number
            Icons.info_outline,
            isDesktop,
            isTablet,
            isMobile,
            isSmallMobile,
            isVerySmallMobile,
          ),
          _buildVersionItem(
            context,
            'Commit Hash',
            'a1b2c3d4e5f6', // Update this commit hash
            Icons.code,
            isDesktop,
            isTablet,
            isMobile,
            isSmallMobile,
            isVerySmallMobile,
          ),
          _buildVersionItem(
            context,
            'Last Commit',
            'Task status fixes and improvements', // Update this commit message
            Icons.message,
            isDesktop,
            isTablet,
            isMobile,
            isSmallMobile,
            isVerySmallMobile,
          ),
          _buildVersionItem(
            context,
            'Build Date',
            'December 15, 2024', // Update this build date
            Icons.calendar_today,
            isDesktop,
            isTablet,
            isMobile,
            isSmallMobile,
            isVerySmallMobile,
          ),
          _buildVersionItem(
            context,
            'Environment',
            'Production', // Update this environment (Development/Staging/Production)
            Icons.security,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(
              isVerySmallMobile
                  ? 6
                  : isSmallMobile
                      ? 8
                      : isMobile
                          ? 10
                          : 12,
            ),
            decoration: BoxDecoration(
              color: CommonColors.primary.withOpacity(0.1),
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
            child: Icon(
              icon,
              color: CommonColors.primary,
              size: isVerySmallMobile
                  ? 16
                  : isSmallMobile
                      ? 18
                      : isMobile
                          ? 20
                          : 22,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withOpacity(0.7),
                    fontSize: isVerySmallMobile
                        ? 10
                        : isSmallMobile
                            ? 11
                            : isMobile
                                ? 12
                                : isTablet
                                    ? 13
                                    : 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  widget.isVerySmallMobile
                      ? 6
                      : widget.isSmallMobile
                          ? 8
                          : widget.isMobile
                              ? 10
                              : 12,
                ),
                decoration: BoxDecoration(
                  color: CommonColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    widget.isVerySmallMobile
                        ? 6
                        : widget.isSmallMobile
                            ? 8
                            : widget.isMobile
                                ? 10
                                : 12,
                  ),
                ),
                child: Icon(
                  Icons.notifications,
                  color: CommonColors.primary,
                  size: widget.isVerySmallMobile
                      ? 16
                      : widget.isSmallMobile
                          ? 18
                          : widget.isMobile
                              ? 20
                              : 22,
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
                        color: Theme.of(context).textTheme.titleMedium?.color,
                        fontSize: widget.isVerySmallMobile
                            ? 12
                            : widget.isSmallMobile
                                ? 13
                                : widget.isMobile
                                    ? 14
                                    : widget.isTablet
                                        ? 15
                                        : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Manage notification preferences',
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.7),
                        fontSize: widget.isVerySmallMobile
                            ? 10
                            : widget.isSmallMobile
                                ? 11
                                : widget.isMobile
                                    ? 12
                                    : widget.isTablet
                                        ? 13
                                        : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding:
                  const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Messages & Chat',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    value: _notifyOnMessage,
                    onChanged: _toggleMessage,
                    activeColor: CommonColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Task & Project Assignments',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    value: _notifyOnAssignment,
                    onChanged: _toggleAssignment,
                    activeColor: CommonColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Attendance and Report',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    value: _notifyOnUpdate,
                    onChanged: _toggleUpdate,
                    activeColor: CommonColors.primary,
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

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthViewModel>().fetchSessions();
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
        return "Last active ${diff.inMinutes} minutes ago";
      }
      if (diff.inHours < 24) {
        return "Last active ${diff.inHours} hours ago";
      }
      if (diff.inDays < 30) {
        return "Last active ${diff.inDays} days ago";
      }

      return "Last active ${lastActive.day}/${lastActive.month}/${lastActive.year}";
    } catch (e) {
      return "Just now";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.isMobile ? 8 : 12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  widget.isVerySmallMobile
                      ? 6
                      : widget.isSmallMobile
                          ? 8
                          : widget.isMobile
                              ? 10
                              : 12,
                ),
                decoration: BoxDecoration(
                  color: CommonColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    widget.isVerySmallMobile
                        ? 6
                        : widget.isSmallMobile
                            ? 8
                            : widget.isMobile
                                ? 10
                                : 12,
                  ),
                ),
                child: Icon(
                  Icons.privacy_tip,
                  color: CommonColors.primary,
                  size: widget.isVerySmallMobile
                      ? 16
                      : widget.isSmallMobile
                          ? 18
                          : widget.isMobile
                              ? 20
                              : 22,
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
                        color: Theme.of(context).textTheme.titleMedium?.color,
                        fontSize: widget.isVerySmallMobile
                            ? 12
                            : widget.isSmallMobile
                                ? 13
                                : widget.isMobile
                                    ? 14
                                    : widget.isTablet
                                        ? 15
                                        : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Manage tracking and account security',
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.7),
                        fontSize: widget.isVerySmallMobile
                            ? 10
                            : widget.isSmallMobile
                                ? 11
                                : widget.isMobile
                                    ? 12
                                    : widget.isTablet
                                        ? 13
                                        : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 8, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location & Tracking',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Use GPS for Attendance',
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                        'Validate location via GPS coordinates',
                        style: TextStyle(fontSize: 12)),
                    value: _useGPS,
                    onChanged: (value) async {
                      await _storage.saveUseGPS(value);
                      setState(() => _useGPS = value);
                    },
                    contentPadding: EdgeInsets.zero,
                    activeColor: CommonColors.primary,
                  ),
                  SwitchListTile(
                    title: const Text('Use IP for Attendance',
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Validate location via office network',
                        style: TextStyle(fontSize: 12)),
                    value: _useIP,
                    onChanged: (value) async {
                      await _storage.saveUseIP(value);
                      setState(() => _useIP = value);
                    },
                    contentPadding: EdgeInsets.zero,
                    activeColor: CommonColors.primary,
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Account Security',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Consumer<AuthViewModel>(
                    builder: (context, authVM, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (authVM.isLoadingSessions)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          else if (authVM.activeSessions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No other active sessions found.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: authVM.activeSessions.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final session = authVM.activeSessions[index];
                                String deviceName =
                                    session['device_name'] ?? 'Unknown Device';
                                String platform =
                                    session['platform'] ?? 'Unknown Platform';

                                // Improved fallback if literally "Unknown"
                                if (deviceName == 'Unknown') {
                                  deviceName = 'Unknown Device';
                                }
                                if (platform == 'Unknown') {
                                  platform = 'Connected Device';
                                }
                                final isCurrentDevice = session['jwt_token'] ==
                                    authVM.localStorage.accessToken;

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Device Icon Container
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .dividerColor
                                              .withOpacity(0.05),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          _getDeviceIcon(platform, session),
                                          size: 22,
                                          color: isCurrentDevice
                                              ? CommonColors.primary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.6),
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Session Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    session['browser'] != null
                                                        ? "${session['browser']} on $platform"
                                                        : deviceName,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isCurrentDevice) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: CommonColors
                                                          .primary
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                      border: Border.all(
                                                          color: CommonColors
                                                              .primary
                                                              .withOpacity(
                                                                  0.2)),
                                                    ),
                                                    child: const Text(
                                                      'CURRENT',
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: CommonColors
                                                            .primary,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 6),

                                            // Location
                                            _buildSessionSubtitle(
                                              context,
                                              Icons.location_on_outlined,
                                              _getLocationString(session),
                                            ),

                                            // Browser
                                            _buildSessionSubtitle(
                                              context,
                                              Icons.language_rounded,
                                              session['browser'] ??
                                                  'Unknown Browser',
                                            ),

                                            // Last Active
                                            _buildSessionSubtitle(
                                              context,
                                              Icons.access_time_rounded,
                                              _getTimeAgo(
                                                  session['updated_at']),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Logout Button
                                      if (!isCurrentDevice)
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 20,
                                              color: Colors.grey),
                                          onPressed: () {
                                            _showLogoutSpecificDeviceDialog(
                                                context, session);
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: authVM.activeSessions.isEmpty
                                  ? null
                                  : () {
                                      _showLogoutDevicesDialog(context);
                                    },
                              icon: const Icon(Icons.devices, size: 18),
                              label: const Text('Logout from other devices'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: CommonColors.dangerRed,
                                side: BorderSide(
                                    color: authVM.activeSessions.isEmpty
                                        ? Colors.grey.withOpacity(0.3)
                                        : CommonColors.dangerRed),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
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

  Widget _buildSessionSubtitle(
      BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDevicesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Check'),
        content: const Text(
            'This will sign you out from all other active devices. Continue?'),
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
                  .logoutFromAllOtherDevices();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(success
                          ? 'Logged out from other devices successfully'
                          : 'Failed to logout from other devices')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CommonColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
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
                          : 'Failed to remove device')),
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(
                      isVerySmallMobile
                          ? 6
                          : isSmallMobile
                              ? 8
                              : isMobile
                                  ? 10
                                  : 12,
                    ),
                    decoration: BoxDecoration(
                      color: CommonColors.primary.withOpacity(0.1),
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
                    child: Icon(
                      themeProvider.isDarkMode
                          ? Icons.dark_mode
                          : Icons.light_mode,
                      color: CommonColors.primary,
                      size: isVerySmallMobile
                          ? 16
                          : isSmallMobile
                              ? 18
                              : isMobile
                                  ? 20
                                  : 22,
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
                            color:
                                Theme.of(context).textTheme.titleMedium?.color,
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
                        Text(
                          'Choose light or dark theme',
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.7),
                            fontSize: isVerySmallMobile
                                ? 10
                                : isSmallMobile
                                    ? 11
                                    : isMobile
                                        ? 12
                                        : isTablet
                                            ? 13
                                            : 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 8, bottom: 8),
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: const Text('Light Mode',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        value: ThemeMode.light,
                        groupValue: themeProvider.themeMode,
                        onChanged: (value) {
                          if (value != null) themeProvider.setTheme(value);
                        },
                        activeColor: CommonColors.primary,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('Dark Mode',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        value: ThemeMode.dark,
                        groupValue: themeProvider.themeMode,
                        onChanged: (value) {
                          if (value != null) themeProvider.setTheme(value);
                        },
                        activeColor: CommonColors.primary,
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<ThemeMode>(
                        title: const Text('System Default',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        value: ThemeMode.system,
                        groupValue: themeProvider.themeMode,
                        onChanged: (value) {
                          if (value != null) themeProvider.setTheme(value);
                        },
                        activeColor: CommonColors.primary,
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
