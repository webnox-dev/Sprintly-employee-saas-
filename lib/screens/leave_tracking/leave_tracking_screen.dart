import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:webnox_taskops/theme/app_theme.dart';
import 'package:webnox_taskops/helpers/common_colors.dart';
import 'package:webnox_taskops/model/task_model.dart';
import 'package:webnox_taskops/services/leave_service.dart';
import 'package:webnox_taskops/utils/responsive_utils.dart';
import 'package:webnox_taskops/model/permission_model.dart';
import 'package:webnox_taskops/services/holiday_service.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import 'package:webnox_taskops/view_model/task_view_model.dart';
import 'package:webnox_taskops/model/work_from_home_model.dart';
import 'package:webnox_taskops/model/employee_attendance_model.dart';

import 'package:webnox_taskops/view_model/attendance_view_model.dart';
import 'package:webnox_taskops/view_model/permission_view_model.dart';
import 'package:webnox_taskops/view_model/work_from_home_view_model.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/animations/silk_shader_widget.dart';

class _UnifiedHistoryItem {
  final DateTime date;
  final Widget widget;
  _UnifiedHistoryItem({required this.date, required this.widget});
}

class LeaveTrackingScreen extends StatefulWidget {
  const LeaveTrackingScreen({super.key});

  @override
  State<LeaveTrackingScreen> createState() => _LeaveTrackingScreenState();
}

class _LeaveTrackingScreenState extends State<LeaveTrackingScreen>
    with TickerProviderStateMixin {
  int selectedTab = 0; // Will be updated in initState based on leave status
  DateTime selectedDate = DateTime.now();
  DateTime selectedMonth = DateTime.now();

  // Animation controllers for enhanced UI
  late AnimationController _pulseController;

  // Leave management
  final LeaveService _leaveService = LeaveService();
  final ValueNotifier<List<Map<String, dynamic>>> _leaveHistory =
      ValueNotifier([]);

  // Form controllers for leave request
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  String? _selectedLeaveType; // Make nullable to require explicit selection
  String? _selectedDurationType; // Make nullable to require explicit selection
  String? _halfDayType; // 'first' or 'second' for half-day
  DateTime? _startDate;
  DateTime? _endDate;
  Set<DateTime> _selectedMultipleDates =
      {}; // For multiple non-consecutive day selection
  bool _isPaidLeave = true;
  bool _submitAttempted = false;

  // Calendar state
  DateTime _calendarFocusedDay = DateTime.now();
  Set<DateTime> _holidayDates = {};
  bool _isLoadingHolidays = false;
  final HolidayService _holidayService = HolidayService();
  DateTime? _lastLoadedMonth; // Track last loaded month to avoid reloading
  bool _showCalendar = false; // Control calendar visibility

  // Use a separate method to change tabs to avoid rebuild issues
  void _changeTab(int newTab) {
    setState(() {
      selectedTab = newTab;
    });
  }

  /// Check if there are rejected leaves that need attention
  bool _hasRejectedLeaves() {
    final leaveHistory = _leaveHistory.value;
    return leaveHistory.any((leave) {
      final isRejected =
          leave['approved_by'] == null && leave['rejected_by'] != null;
      final hasRejectionNotes =
          leave['leave_approval_rejection_remarks'] != null &&
              leave['leave_approval_rejection_remarks'].toString().isNotEmpty;
      return isRejected && hasRejectionNotes;
    });
  }

  /// Get the initial tab based on leave status
  int _getInitialTab() {
    if (_hasRejectedLeaves()) {
      return 0; // Show leave request tab first if there are rejected leaves
    }
    return 3; // Default to attendance history tab (now last tab)
  }

  Future<List<Map<String, dynamic>>>? _weeklyAttendanceFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_weeklyAttendanceFuture == null) {
      _weeklyAttendanceFuture =
          Provider.of<AttendanceViewModel>(context, listen: false)
              .getWeeklyAttendanceData();
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Initialize calendar focused day
    _calendarFocusedDay = DateTime.now();

    // Start animations
    _pulseController.repeat(reverse: true);

    // Fetch current attendance when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.isAuthenticated) {
        // The new enhanced attendance system will handle data fetching automatically
        // through the Consumer widgets and FutureBuilder

        // Fetch leave data
        _fetchLeaveData().then((_) {
          // Set initial tab based on leave status after data is fetched
          if (mounted) {
            setState(() {
              selectedTab = _getInitialTab();
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _reasonController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLaptop = ResponsiveUtils.isLaptop(context);
    final isDesktop = ResponsiveUtils.isDesktop(context) || isLaptop;
    final attendanceViewModel =
        Provider.of<AttendanceViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Stack Header and TabBar for desktop overlap effect
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Header (with extra padding at bottom on desktop)
              Column(
                children: [
                  _buildHeader(context, isDesktop),
                  if (isDesktop)
                    SizedBox(height: isLaptop ? 15 : 20), // Spacer for overlap
                ],
              ),

              // Tab Bar (Floating Overlap on Desktop)
              if (isDesktop)
                Transform.translate(
                  offset: Offset(
                      0, isLaptop ? -15 : -20), // Reduced overlap for laptop
                  child: _buildTabBar(context, isDesktop),
                ),
            ],
          ),

          // Mobile Tab Bar (Standard Layout)
          if (!isDesktop) ...[
            const SizedBox(height: 20),
            _buildTabBar(context, isDesktop),
          ],

          const SizedBox(height: 20),

          // Tab Content
          Expanded(
            child: Padding(
              padding: isDesktop
                  ? const EdgeInsets.symmetric(horizontal: 24.0)
                  : const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildTabContent(context, isDesktop, attendanceViewModel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, bool isDesktop,
      AttendanceViewModel attendanceViewModel) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => WorkFromHomeViewModel()..initializeData(context),
        ),
        ChangeNotifierProvider(
          create: (context) => PermissionViewModel()..initializeData(context),
        ),
      ],
      child: Builder(
        builder: (context) {
          if (selectedTab == 0) {
            return isDesktop
                ? _buildDesktopLeaveRequestLayout(context)
                : _buildLeaveRequestTab(context, isDesktop);
          } else if (selectedTab == 1) {
            return isDesktop
                ? _buildDesktopWorkFromHomeLayout(context)
                : _buildWorkFromHomeTab(context, isDesktop);
          } else if (selectedTab == 2) {
            return isDesktop
                ? _buildDesktopPermissionLayout(context)
                : _buildPermissionTab(context, isDesktop);
          } else {
            return isDesktop
                ? _buildDesktopAttendanceLayout(
                    context, attendanceViewModel, selectedDate, selectedMonth)
                : _buildAttendanceTab(context, attendanceViewModel,
                    selectedDate, selectedMonth, isDesktop);
          }
        },
      ),
    );
  }

  /// Build desktop attendance layout
  Widget _buildDesktopAttendanceLayout(
      BuildContext context,
      AttendanceViewModel attendanceViewModel,
      DateTime selectedDate,
      DateTime selectedMonth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column - History & Current Requests
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Unified Request History
                _buildUnifiedHistorySection(context, true),
                const SizedBox(height: 24),

                _buildCurrentLeaveRequests(context, true),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right Column - Analytics & Charts
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildAttendanceAnalytics(context, attendanceViewModel, true),
                const SizedBox(height: 24),
                _buildAttendanceGraphs(context, attendanceViewModel, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build desktop leave request layout
  Widget _buildDesktopLeaveRequestLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column - Leave Request Form
          Expanded(
            flex: 2,
            child: _buildLeaveRequestForm(context, true),
          ),
          const SizedBox(width: 24),
          // Right Column - Leave Status Chart and Current Leave Requests
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildLeaveStatusPieChart(context, true),
                const SizedBox(height: 24),
                _buildCurrentLeaveRequests(context, true),
                const SizedBox(height: 24),
                _buildRejectedLeavesSummary(context, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    final bool isLaptop = ResponsiveUtils.isLaptop(context);

    return SilkShaderWidget(
      speed: 0.8,
      scale: 1.2,
      color: Theme.of(context).colorScheme.primary,
      noiseIntensity: 1.5,
      child: Container(
        width: double.infinity,
        margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.all(16),
        padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 20,
            vertical: ResponsiveUtils.getResponsiveSize(
              context,
              mobile: 16,
              tablet: 18,
              laptop: 20, // Reduced from 28
              desktop: 28,
            )).copyWith(bottom: isLaptop ? 25 : 35),
        decoration: BoxDecoration(
          borderRadius:
              isDesktop ? BorderRadius.zero : BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CommonColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isDesktop ? 12 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.calendar_month,
                    color: Colors.white,
                    size: ResponsiveUtils.getResponsiveSize(
                      context,
                      mobile: 22,
                      tablet: 22,
                      laptop: 20, // Reduced from 24
                      desktop: 24,
                    ),
                  ),
                ),
                SizedBox(width: isDesktop ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance & Leave Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveUtils.getResponsiveSize(
                            context,
                            mobile: 18,
                            tablet: 20,
                            laptop: 22, // Reduced from 28
                            desktop: 28,
                          ),
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track time, request leaves, and manage permissions',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: isDesktop ? 14 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isDesktop) const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Nano Tab Bar
  Widget _buildTabBar(BuildContext context, bool isDesktop) {
    return Center(
      child: Container(
        constraints:
            BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
        margin: isDesktop
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNanoTabItem(
                context, 'Leave', Icons.calendar_month_rounded, 0, isDesktop),
            _buildNanoTabItem(
                context, 'WFH', Icons.home_work_rounded, 1, isDesktop),
            _buildNanoTabItem(
                context, 'Permission', Icons.hourglass_bottom, 2, isDesktop),
            _buildNanoTabItem(
                context, 'History', Icons.history_rounded, 3, isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildNanoTabItem(BuildContext context, String title, IconData icon,
      int index, bool isDesktop) {
    final isSelected = selectedTab == index;
    return Flexible(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _changeTab(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 12,
              vertical: isDesktop ? 12 : 8,
            ),
            decoration: BoxDecoration(
              gradient: isSelected ? CommonColors.primaryGradient : null,
              color: isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(40),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: CommonColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: isDesktop ? 18 : 16,
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                ),
                if (isDesktop || isSelected) ...[
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                      fontSize: isDesktop ? 14 : 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTab(
    BuildContext context,
    AttendanceViewModel attendanceViewModel,
    DateTime selectedDate,
    DateTime selectedMonth,
    bool isDesktop,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unified Request History Section
          _buildUnifiedHistorySection(context, isDesktop),
        ],
      ),
    );
  }

  Widget _buildEnhancedAttendanceSection(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.work_history,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session History',
                      style: TextStyle(
                        fontSize: isDesktop ? 20 : 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your daily work sessions and task assignments',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 12,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Current Status Display
          Consumer<AttendanceViewModel>(
            builder: (context, attendanceViewModel, child) {
              return FutureBuilder<Map<String, dynamic>?>(
                future: attendanceViewModel.getCurrentAttendanceStatus(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final status = snapshot.data;
                  final isClockedIn = status?['is_clocked_in'] ?? false;
                  final currentTaskName = status?['current_task_name'];
                  final sessionDuration = status?['session_duration'];

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context)
                            .dividerColor
                            .withValues(alpha: 0.1),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isClockedIn
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.1)
                                : Theme.of(context)
                                    .dividerColor
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isClockedIn
                                ? Icons.play_circle
                                : Icons.pause_circle,
                            color: isClockedIn
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).disabledColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isClockedIn
                                    ? 'CURRENT SESSION'
                                    : 'NO ACTIVE SESSION',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isClockedIn
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).disabledColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (isClockedIn && currentTaskName != null) ...[
                                Text(
                                  currentTaskName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (sessionDuration != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      sessionDuration,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ),
                              ] else ...[
                                Text(
                                  'Ready to start work',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          // Daily Summary Display
          Consumer<AttendanceViewModel>(
            builder: (context, attendanceViewModel, child) {
              return FutureBuilder<Map<String, dynamic>?>(
                future: attendanceViewModel.getDailyWorkSummary(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final summary = snapshot.data;
                  if (summary == null) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: const EmptyStateWidget(
                        title: 'No attendance data for today',
                        subtitle: 'Clock in to see your daily summary',
                        size: 150,
                      ),
                    );
                  }

                  final totalDailyHours = summary['total_daily_hours'] ?? 0.0;
                  final firstClockIn = summary['daily_start_time'];
                  final lastClockOut = summary['daily_end_time'];
                  final taskSessions = summary['tasks_for_the_day'] ?? [];

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onPrimary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attendance Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Summary Stats
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${totalDailyHours.toStringAsFixed(1)}h',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    const Text(
                                      'Total Hours',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _formatTime(firstClockIn),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.successGreen,
                                      ),
                                    ),
                                    const Text(
                                      'First In',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _formatTime(lastClockOut),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                    const Text(
                                      'Last Out',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Task Sessions
                        if (taskSessions.isNotEmpty) ...[
                          const Text(
                            'Recent Tasks',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...taskSessions
                              .map((session) => _buildTaskSessionCard(session)),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClockControls(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.touch_app,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Text(
                'Session Controls',
                style: TextStyle(
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontSize: isDesktop ? 20 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Status-aware clock controls
          Consumer<AttendanceViewModel>(
            builder: (context, attendanceViewModel, child) {
              return FutureBuilder<Map<String, dynamic>?>(
                future: attendanceViewModel.getCurrentAttendanceStatus(),
                builder: (context, snapshot) {
                  final isClockedIn = snapshot.data?['is_clocked_in'] ?? false;

                  return Column(
                    children: [
                      // Main action buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildClockButton(
                              context,
                              isClockedIn ? 'Switch Task' : 'Punch In',
                              isClockedIn ? Icons.swap_horiz : Icons.login,
                              isClockedIn
                                  ? Colors.blue.shade500
                                  : AppTheme.successGreen,
                              false,
                              () => isClockedIn
                                  ? _showTaskSwitchDialog(context)
                                  : _handleClockInEnhanced(context),
                              isDesktop,
                            ),
                          ),
                          if (isDesktop) const SizedBox(width: 16),
                          Expanded(
                            child: _buildClockButton(
                              context,
                              'Punch Out',
                              Icons.logout,
                              AppTheme.highPriority,
                              false,
                              () => _handleClockOutEnhanced(context),
                              isDesktop,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Secondary actions
                      Row(
                        children: [
                          Expanded(
                            child: _buildClockButton(
                              context,
                              'Break',
                              Icons.coffee,
                              Colors.brown.shade400,
                              false,
                              () => _handleBreakAction(context),
                              isDesktop,
                            ),
                          ),
                          if (isDesktop) const SizedBox(width: 16),
                          Expanded(
                            child: _buildClockButton(
                              context,
                              'Refresh',
                              Icons.refresh,
                              AppTheme.mediumPriority,
                              false,
                              () => _refreshAttendanceData(context),
                              isDesktop,
                            ),
                          ),
                        ],
                      ),

                      // Current status indicator
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isClockedIn
                              ? AppTheme.successGreen.withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isClockedIn
                                ? AppTheme.successGreen.withValues(alpha: 0.3)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isClockedIn
                                  ? Icons.play_circle_filled
                                  : Icons.pause_circle_outline,
                              color: isClockedIn
                                  ? AppTheme.successGreen
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isClockedIn
                                  ? 'Currently Working'
                                  : 'Not Clocked In',
                              style: TextStyle(
                                fontSize: isDesktop ? 14 : 12,
                                fontWeight: FontWeight.w600,
                                color: isClockedIn
                                    ? AppTheme.successGreen
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClockButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    bool isLoading,
    VoidCallback onPressed,
    bool isDesktop,
  ) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 28 : 20,
          vertical: isDesktop ? 18 : 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        shadowColor: color.withValues(alpha: 0.3),
      ),
      child: isLoading
          ? SizedBox(
              width: isDesktop ? 20 : 16,
              height: isDesktop ? 20 : 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimary),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isDesktop ? 20 : 18),
                SizedBox(width: isDesktop ? 12 : 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLeaveManagementTab(BuildContext context, bool isDesktop) {
    return Column(
      children: [],
    );
  }

  Widget _buildLeaveRequestTab(BuildContext context, bool isDesktop) {
    return Column(
      children: [
        // Leave Request Form Section
        _buildLeaveRequestForm(context, isDesktop),

        const SizedBox(height: 24),

        // Leave Status Pie Chart
        _buildLeaveStatusPieChart(context, isDesktop),

        const SizedBox(height: 24),

        // Current/Processing Leave Requests Section
        _buildCurrentLeaveRequests(context, isDesktop),
      ],
    );
  }

  // Helper methods
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'working':
      case 'in progress':
        return AppTheme.successGreen;
      case 'completed':
        return Theme.of(context).colorScheme.primary;
      case 'not started':
        return AppTheme.mediumPriority;
      default:
        return AppTheme.successGreen; // Default to "In Progress" color
    }
  }

  // Event handlers - Updated to use enhanced methods
  Future<void> _handleClockIn(BuildContext context) async {
    await _handleClockInEnhanced(context);
  }

  Future<void> _handleClockOut(BuildContext context) async {
    await _handleClockOutEnhanced(context);
  }

  Future<void> _refreshAttendance(
      BuildContext context, AttendanceViewModel attendanceViewModel) async {
    try {
      // Use the new enhanced refresh method
      _refreshAttendanceData(context);
    } catch (e) {
      _showSnackBar(context, 'Error refreshing attendance: $e');
    }
  }

  void _showSnackBar(BuildContext context, String message,
      {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isSuccess ? AppTheme.successGreen : AppTheme.highPriority,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Build leave request form
  Widget _buildLeaveRequestForm(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  gradient: CommonColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CommonColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: isDesktop ? 24 : 20,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request Leave',
                      style: TextStyle(
                        fontSize: isDesktop ? 20 : 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submit a new leave request',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              // Refresh button simplified
              IconButton(
                onPressed: () {
                  _clearForm();
                  _fetchLeaveData();
                },
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Form',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 32 : 24),

          // Leave Request Form
          _buildLeaveRequestFormFields(context, isDesktop),

          SizedBox(height: isDesktop ? 32 : 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _submitAttempted = true);
                print('🔘 SUBMIT BUTTON CLICKED!');
                print('🔘 _canSubmitLeave() = ${_canSubmitLeave()}');
                if (_canSubmitLeave()) {
                  _submitLeaveRequest(context);
                } else {
                  print('🔘 Validation failed, not submitting');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSubmitLeave()
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 40 : 32,
                  vertical: isDesktop ? 20 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
                ),
                elevation: _canSubmitLeave() ? 8 : 0,
                shadowColor: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.4),
              ),
              icon: Icon(Icons.send_rounded),
              label: Text(
                'Submit Leave Request',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Form validation hint
          if (_submitAttempted && !_canSubmitLeave())
            Container(
              margin: EdgeInsets.only(top: isDesktop ? 16 : 12),
              padding: EdgeInsets.all(isDesktop ? 16 : 12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info,
                    color: Theme.of(context).colorScheme.error,
                    size: isDesktop ? 20 : 18,
                  ),
                  SizedBox(width: isDesktop ? 12 : 8),
                  Expanded(
                    child: Text(
                      'Please fill in all required fields to submit your leave request',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: isDesktop ? 14 : 12,
                          ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Build leave request form fields
  Widget _buildLeaveRequestFormFields(BuildContext context, bool isDesktop) {
    return Column(
      children: [
        // Leave Type Dropdown
        _buildLeaveTypeDropdown(context, isDesktop),

        const SizedBox(height: 20),

        // Duration Type Dropdown
        _buildDurationTypeDropdown(context, isDesktop),

        const SizedBox(height: 20),

        // Half Day Type Selector (only show for Half Day Leave)
        if (_selectedDurationType == 'Half Day Leave')
          _buildHalfDayTypeSelector(context, isDesktop),

        if (_selectedDurationType == 'Half Day Leave')
          const SizedBox(height: 20),

        // Calendar Date Picker
        _buildCalendarDatePicker(context, isDesktop),

        const SizedBox(height: 20),

        // Reason Field
        _buildReasonField(context, isDesktop),

        const SizedBox(height: 20),

        // Paid Leave Toggle
        _buildPaidLeaveToggle(context, isDesktop),

        const SizedBox(height: 20),

        // Leave Summary
        if (_startDate != null) _buildLeaveSummary(context, isDesktop),
      ],
    );
  }

  /// Build leave type dropdown
  Widget _buildLeaveTypeDropdown(BuildContext context, bool isDesktop) {
    final leaveTypes = [
      'Annual Leave',
      'Sick Leave',
      'Personal Leave',
      'Maternity Leave',
      'Other'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leave Type *',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedLeaveType,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: isDesktop ? 14 : 12,
          ),
          dropdownColor: Theme.of(context).cardColor,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.category,
                color: Theme.of(context).colorScheme.primary),
            hintText: 'Select Leave Type',
          ),
          items: leaveTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedLeaveType = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a leave type';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Build duration type dropdown
  Widget _buildDurationTypeDropdown(BuildContext context, bool isDesktop) {
    final durationTypes = [
      'Half Day Leave',
      'Single Day Leave',
      'Multiple Day Leave'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duration Type *',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDurationType,
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: isDesktop ? 14 : 12,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.access_time,
                color: Theme.of(context).colorScheme.primary),
            hintText: 'Select Duration Type',
          ),
          items: durationTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedDurationType = value;
              // Reset dates when duration type changes
              _startDate = null;
              _endDate = null;
              _selectedMultipleDates.clear();
              _startDateController.clear();
              _endDateController.clear();
              // Reset half-day type
              if (value != 'Half Day Leave') {
                _halfDayType = null;
              }
              // Hide calendar when duration type changes
              _showCalendar = false;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a duration type';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Build half-day type selector
  Widget _buildHalfDayTypeSelector(BuildContext context, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Half Day Type *',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _halfDayType,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: isDesktop ? 14 : 12,
          ),
          dropdownColor: Theme.of(context).cardColor,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.hourglass_bottom,
                color: Theme.of(context).colorScheme.primary),
            hintText: 'Select half day type',
          ),
          items: [
            DropdownMenuItem(
              value: 'first',
              child: Text('First Half (Morning)'),
            ),
            DropdownMenuItem(
              value: 'second',
              child: Text('Second Half (Afternoon)'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _halfDayType = value;
            });
          },
        ),
      ],
    );
  }

  /// Build date field
  Widget _buildDateField(
    BuildContext context,
    String label,
    TextEditingController controller,
    IconData icon,
    bool isDesktop,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label *',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: 'Select $label',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build reason field
  Widget _buildReasonField(BuildContext context, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reason for Leave *',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reasonController,
          onChanged: (value) => setState(() {}),
          maxLines: 3,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: isDesktop ? 14 : 12,
          ),
          decoration: const InputDecoration(
            hintText: 'Please provide a reason for your leave request...',
            contentPadding: EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  /// Build paid leave toggle
  Widget _buildPaidLeaveToggle(BuildContext context, bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor ??
            Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: isDesktop ? 1 : 0.5,
        ),
      ),
      child: SwitchListTile(
        value: _isPaidLeave,
        onChanged: (value) {
          setState(() {
            _isPaidLeave = value;
          });
        },
        title: Text(
          'Paid Leave',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        subtitle: Text(
          'Mark this as a paid leave request',
          style: TextStyle(
            fontSize: isDesktop ? 12 : 10,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        activeColor: Theme.of(context).colorScheme.primary,
        contentPadding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Build calendar date picker
  Widget _buildCalendarDatePicker(BuildContext context, bool isDesktop) {
    // Load holidays only if not already loaded for this month
    final currentMonth =
        DateTime(_calendarFocusedDay.year, _calendarFocusedDay.month);
    if (_lastLoadedMonth == null ||
        _lastLoadedMonth!.year != currentMonth.year ||
        _lastLoadedMonth!.month != currentMonth.month) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadHolidays(_calendarFocusedDay);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with date field/button
        Row(
          children: [
            Icon(
              Icons.calendar_month,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showCalendar = !_showCalendar;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 16 : 12,
                    vertical: isDesktop ? 14 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).inputDecorationTheme.fillColor ??
                        Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      width: isDesktop ? 1 : 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getSelectedDateDisplayText(),
                          style: TextStyle(
                            fontSize: isDesktop ? 15 : 14,
                            fontWeight: FontWeight.w500,
                            color: _hasSelectedDates()
                                ? Theme.of(context).textTheme.titleLarge?.color
                                : Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Icon(
                        _showCalendar ? Icons.expand_less : Icons.expand_more,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_hasSelectedDates()) const SizedBox(width: 8),
            if (_hasSelectedDates())
              IconButton(
                onPressed: () {
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                    _selectedMultipleDates.clear();
                    _startDateController.clear();
                    _endDateController.clear();
                    _showCalendar = false;
                  });
                },
                icon: const Icon(Icons.clear, size: 20),
                tooltip: 'Clear Dates',
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Show calendar only when _showCalendar is true
        if (_showCalendar) ...[
          const SizedBox(height: 12),
          // Legend
          _buildCalendarLegend(context, isDesktop),
          const SizedBox(height: 16),

          // Calendar - Show loading overlay instead of replacing calendar
          Stack(
            children: [
              TableCalendar(
                key: ValueKey(
                    'calendar_${_calendarFocusedDay.year}_${_calendarFocusedDay.month}'),
                firstDay: DateTime.now(),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _calendarFocusedDay,
                selectedDayPredicate: (day) {
                  if (_selectedDurationType == 'Multiple Day Leave') {
                    // Check if day is in the multiple selected dates set
                    return _selectedMultipleDates
                        .any((selectedDate) => isSameDay(selectedDate, day));
                  }
                  return isSameDay(_startDate, day) || isSameDay(_endDate, day);
                },
                rangeStartDay:
                    null, // Disable range selection for multiple day leave
                rangeEndDay: null,
                rangeSelectionMode: RangeSelectionMode
                    .disabled, // Always disabled to allow individual selection
                onDaySelected: (selectedDay, focusedDay) {
                  _handleDateSelection(selectedDay, focusedDay, context);
                },
                onPageChanged: (focusedDay) {
                  // Only update if month changed to avoid unnecessary rebuilds
                  final newMonth = DateTime(focusedDay.year, focusedDay.month);
                  final currentMonth = DateTime(
                      _calendarFocusedDay.year, _calendarFocusedDay.month);

                  if (newMonth.year != currentMonth.year ||
                      newMonth.month != currentMonth.month) {
                    // Month changed, load holidays
                    _loadHolidays(focusedDay);
                  }

                  // Update focused day without setState if it's just a day change within same month
                  if (_calendarFocusedDay.year != focusedDay.year ||
                      _calendarFocusedDay.month != focusedDay.month ||
                      _calendarFocusedDay.day != focusedDay.day) {
                    setState(() {
                      _calendarFocusedDay = focusedDay;
                    });
                  }
                },
                eventLoader: (day) {
                  // Only return holidays - no tasks should be shown in leave calendar
                  if (_isHoliday(day)) {
                    return ['holiday'];
                  }
                  return [];
                },
                enabledDayPredicate: (day) {
                  return !_isDateDisabled(day);
                },
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.4),
                  ),
                  disabledTextStyle: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.3),
                  ),
                  defaultTextStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  rangeStartDecoration: const BoxDecoration(),
                  rangeEndDecoration: const BoxDecoration(),
                  withinRangeDecoration: const BoxDecoration(),
                  markersMaxCount: 1,
                  // Only holidays are shown as markers (controlled by eventLoader)
                  // No tasks are displayed in the leave calendar
                  markerDecoration: BoxDecoration(
                    color: Colors.red.shade300,
                    shape: BoxShape.circle,
                  ),
                  cellPadding: const EdgeInsets.all(8),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  weekendStyle: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.5),
                  ),
                ),
              ),
              // Loading overlay
              if (_isLoadingHolidays)
                Positioned.fill(
                  child: Container(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.7),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),

          // Selected date info
          if (_startDate != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getSelectedDateInfo(),
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// Build leave summary
  Widget _buildLeaveSummary(BuildContext context, bool isDesktop) {
    final isHalfDay = _selectedDurationType == 'Half Day Leave';
    final isSingleDay = _selectedDurationType == 'Single Day Leave';
    final days = isHalfDay
        ? 0.5
        : isSingleDay
            ? 1.0
            : _selectedMultipleDates.length.toDouble();

    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Leave Summary',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  isHalfDay ? 'Half Day' : 'Total Days',
                  isHalfDay
                      ? '0.5 day'
                      : days == 1.0
                          ? '1 day'
                          : '${days.toInt()} days',
                  Icons.calendar_today,
                  isDesktop,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Leave Type',
                  _selectedLeaveType ?? 'Not selected',
                  Icons.category,
                  isDesktop,
                ),
              ),
            ],
          ),
          if (isHalfDay && _halfDayType != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Half Day Type: ${_halfDayType == 'first' ? 'First Half (Morning)' : 'Second Half (Afternoon)'}',
                    style: TextStyle(
                      fontSize: isDesktop ? 12 : 10,
                      color: Theme.of(context).colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Build summary item
  Widget _buildSummaryItem(
      String label, String value, IconData icon, bool isDesktop) {
    return Column(
      children: [
        Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: isDesktop ? 20 : 16,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 10 : 8,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isDesktop ? 12 : 10,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
      ],
    );
  }

  /// Load holidays for calendar
  Future<void> _loadHolidays(DateTime month) async {
    // Check if already loading or already loaded for this month
    final monthKey = DateTime(month.year, month.month);
    if (_isLoadingHolidays || _lastLoadedMonth == monthKey) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoadingHolidays = true;
    });

    try {
      final holidays = await _holidayService.getHolidaysForMonth(
        year: month.year,
        month: month.month,
      );

      if (!mounted) return;

      // Batch all state updates in a single setState
      setState(() {
        _holidayDates = holidays.map((holiday) {
          final date = _parseUtcToLocal(holiday['from_date']);
          return DateTime(date.year, date.month, date.day);
        }).toSet();
        _isLoadingHolidays = false;
        _lastLoadedMonth = monthKey;
      });
    } catch (e) {
      if (!mounted) return;
      print('Error loading holidays: $e');
      setState(() {
        _isLoadingHolidays = false;
      });
    }
  }

  /// Check if date is a holiday
  bool _isHoliday(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return _holidayDates.contains(normalized);
  }

  /// Check if date should be disabled
  bool _isDateDisabled(DateTime date) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // Always disable past dates
    if (normalizedDate.isBefore(normalizedToday)) {
      return true;
    }

    // Always disable Sundays (always weekend)
    if (date.weekday == DateTime.sunday) {
      return true;
    }

    // Disable Saturdays only if they are marked as holidays
    if (date.weekday == DateTime.saturday) {
      return _isHoliday(date);
    }

    // Disable dates that are marked as holidays
    if (_isHoliday(date)) {
      return true;
    }

    // Allow all other dates (including working Saturdays)
    return false;
  }

  /// Get calendar title based on duration type
  String _getCalendarTitle() {
    switch (_selectedDurationType) {
      case 'Half Day Leave':
        return 'Select Date for Half Day Leave *';
      case 'Single Day Leave':
        return 'Select Date for Single Day Leave *';
      case 'Multiple Day Leave':
        return 'Select Multiple Dates (Click to toggle) *';
      default:
        return 'Select Leave Dates *';
    }
  }

  /// Get selected date info text
  String _getSelectedDateInfo() {
    if (_selectedDurationType == null) {
      return 'Select duration type and dates';
    }
    if (_selectedDurationType == 'Half Day Leave') {
      final halfDayText = _halfDayType == 'first'
          ? 'First Half (Morning)'
          : _halfDayType == 'second'
              ? 'Second Half (Afternoon)'
              : 'Half Day (Select half day type)';
      return 'Selected: ${_formatDate(_startDate!)} - $halfDayText';
    } else if (_selectedDurationType == 'Single Day Leave') {
      return 'Selected: ${_formatDate(_startDate!)} (Single Day)';
    } else {
      // Multiple Day Leave
      if (_selectedMultipleDates.isEmpty) {
        return 'Select multiple dates (click to toggle)';
      }
      final sortedDates = _selectedMultipleDates.toList()..sort();
      if (sortedDates.length == 1) {
        return 'Selected: ${_formatDate(sortedDates.first)} (1 day)';
      } else {
        final dateList = sortedDates.map((d) => _formatDate(d)).join(', ');
        return 'Selected: $dateList (${sortedDates.length} days)';
      }
    }
  }

  /// Check if any dates are selected
  bool _hasSelectedDates() {
    return _startDate != null ||
        _endDate != null ||
        _selectedMultipleDates.isNotEmpty;
  }

  /// Get display text for selected dates
  String _getSelectedDateDisplayText() {
    if (_selectedDurationType == null) {
      return 'Select Leave Dates *';
    }

    if (!_hasSelectedDates()) {
      return _getCalendarTitle();
    }

    if (_selectedDurationType == 'Half Day Leave') {
      final halfDayText = _halfDayType == 'first'
          ? 'First Half'
          : _halfDayType == 'second'
              ? 'Second Half'
              : 'Half Day';
      return '${_formatDate(_startDate!)} - $halfDayText';
    } else if (_selectedDurationType == 'Single Day Leave') {
      return _formatDate(_startDate!);
    } else {
      // Multiple Day Leave
      if (_selectedMultipleDates.isEmpty) {
        return 'Select Multiple Dates (Click to toggle) *';
      }
      final sortedDates = _selectedMultipleDates.toList()..sort();
      if (sortedDates.length == 1) {
        return _formatDate(sortedDates.first);
      } else {
        return '${sortedDates.length} dates selected';
      }
    }
  }

  /// Handle date selection based on duration type
  void _handleDateSelection(
      DateTime selectedDay, DateTime focusedDay, BuildContext context) {
    // Check if duration type is selected
    if (_selectedDurationType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a duration type first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_isDateDisabled(selectedDay)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isHoliday(selectedDay)
              ? 'Cannot select holidays'
              : 'Cannot select past dates or Sundays'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      if (_selectedDurationType == 'Half Day Leave') {
        // Half Day: Only one date, no range
        _startDate = selectedDay;
        _endDate = null;
        _selectedMultipleDates.clear();
        _startDateController.text =
            '${selectedDay.day}/${selectedDay.month}/${selectedDay.year}';
        _endDateController.clear();
        // Hide calendar after selection for half day
        _showCalendar = false;
      } else if (_selectedDurationType == 'Single Day Leave') {
        // Single Day: Only one date, no range
        _startDate = selectedDay;
        _endDate = null;
        _selectedMultipleDates.clear();
        _startDateController.text =
            '${selectedDay.day}/${selectedDay.month}/${selectedDay.year}';
        _endDateController.clear();
        // Hide calendar after selection for single day
        _showCalendar = false;
      } else if (_selectedDurationType == 'Multiple Day Leave') {
        // Multiple Day: Individual day selection (non-consecutive)
        final normalizedDay =
            DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

        // Toggle selection: if already selected, deselect it
        if (_selectedMultipleDates.contains(normalizedDay)) {
          _selectedMultipleDates.remove(normalizedDay);
        } else {
          // Add to selection
          _selectedMultipleDates.add(normalizedDay);
        }

        // Update controllers with sorted dates
        final sortedDates = _selectedMultipleDates.toList()..sort();
        if (sortedDates.isNotEmpty) {
          _startDate = sortedDates.first;
          _endDate = sortedDates.last;
          _startDateController.text =
              '${sortedDates.first.day}/${sortedDates.first.month}/${sortedDates.first.year}';
          if (sortedDates.length > 1) {
            _endDateController.text =
                '${sortedDates.last.day}/${sortedDates.last.month}/${sortedDates.last.year}';
          } else {
            _endDateController.clear();
          }
        } else {
          _startDate = null;
          _endDate = null;
          _startDateController.clear();
          _endDateController.clear();
        }
        // Keep calendar open for multiple day selection
        // User can manually close it or it will close when they're done
      }
      _calendarFocusedDay = focusedDay;
    });
  }

  /// Build calendar legend
  Widget _buildCalendarLegend(BuildContext context, bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildCalendarLegendItem(
            context, Colors.grey.shade300, 'Disabled', isDesktop),
        _buildCalendarLegendItem(
            context, Colors.red.shade300, 'Holiday', isDesktop),
        _buildCalendarLegendItem(
          context,
          Theme.of(context).colorScheme.primary,
          'Selected',
          isDesktop,
        ),
      ],
    );
  }

  Widget _buildCalendarLegendItem(
    BuildContext context,
    Color color,
    String label,
    bool isDesktop,
  ) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 12 : 10,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Submit leave request
  Future<void> _submitLeaveRequest(BuildContext context) async {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

    // Use getCurrentEmployeeDetails instead of currentUser to ensure we get the correct employee ID
    // similar to how WorkFromHomeViewModel handles it
    final employeeRecord = await authViewModel.getCurrentEmployeeDetails();
    if (employeeRecord == null || employeeRecord['employee_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not found')),
      );
      return;
    }
    final String employeeId = employeeRecord['employee_id'] as String;

    // Calculate start and end dates based on duration type
    DateTime start = _startDate ?? DateTime.now();
    DateTime end = _endDate ?? start;
    List<DateTime>? selectedDatesList;

    if (_selectedDurationType == 'Multiple Day Leave') {
      if (_selectedMultipleDates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one date')),
        );
        return;
      }
      final sorted = _selectedMultipleDates.toList()..sort();
      start = sorted.first;
      end = sorted.last;
      selectedDatesList = sorted;
    }

    // Show Loading
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await _leaveService.submitLeaveRequest(
        employeeId: employeeId,
        startDate: start,
        endDate: end,
        reason: _reasonController.text,
        leaveType: _selectedLeaveType,
        isPaidLeave: _isPaidLeave,
        isHalfDay: _selectedDurationType == 'Half Day Leave',
        halfDayType: _halfDayType,
        selectedDates: selectedDatesList,
      );

      if (context.mounted) {
        Navigator.pop(context); // Hide loading

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave request submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _clearForm();
          _fetchLeaveData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit leave request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Check if form can be submitted
  bool _canSubmitLeave() {
    print('🔍 _canSubmitLeave check:');
    print('   - _selectedLeaveType: $_selectedLeaveType');
    print('   - _selectedDurationType: $_selectedDurationType');
    print('   - _startDate: $_startDate');
    print('   - _reasonController.text: "${_reasonController.text.trim()}"');
    print('   - _halfDayType: $_halfDayType');
    print('   - _selectedMultipleDates: $_selectedMultipleDates');

    // Require leave type selection
    if (_selectedLeaveType == null || _selectedLeaveType!.isEmpty) {
      print('   ❌ FAILED: Leave type not selected');
      return false;
    }

    // Require duration type selection
    if (_selectedDurationType == null || _selectedDurationType!.isEmpty) {
      print('   ❌ FAILED: Duration type not selected');
      return false;
    }

    // Require dates to be selected based on duration type
    bool datesSelected = false;
    if (_selectedDurationType == 'Multiple Day Leave') {
      datesSelected = _selectedMultipleDates.isNotEmpty;
    } else {
      datesSelected = _startDate != null;
    }

    if (!datesSelected || _reasonController.text.trim().isEmpty) {
      print('   ❌ FAILED: Dates or reason missing');
      return false;
    }

    // For half-day leave, require half-day type selection
    if (_selectedDurationType == 'Half Day Leave' && _halfDayType == null) {
      print('   ❌ FAILED: Half day type not selected');
      return false;
    }

    // For multiple day leave, require at least one date selected
    if (_selectedDurationType == 'Multiple Day Leave' &&
        _selectedMultipleDates.isEmpty) {
      print('   ❌ FAILED: No dates selected for multiple day leave');
      return false;
    }

    print('   ✅ All validations passed!');
    return true;
  }

  /// Clear form after successful submission
  void _clearForm() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedMultipleDates.clear();
      _selectedLeaveType = null;
      _selectedDurationType = null;
      _halfDayType = null;
      _isPaidLeave = false;
      _submitAttempted = false;
      _reasonController.clear();
      _startDateController.clear();
      _endDateController.clear();
    });
  }

  /// Select end date

  /// Build current/processing leave requests
  Widget _buildCurrentLeaveRequests(BuildContext context, bool isDesktop) {
    final now = DateTime.now();
    final currentLeaves = _leaveHistory.value.where((leave) {
      final isPending =
          leave['approved_by'] == null && leave['rejected_by'] == null;
      final isApproved = (leave['leave_status'] ?? 0) == 1;

      // Check if leave dates are still current (not expired)
      // A leave is considered expired if its end date is before today
      final endDate =
          DateTime.tryParse(leave['leave_to_date'] ?? '') ?? DateTime.now();
      final isDateValid = endDate.isAfter(now) || endDate.isAtSameMomentAs(now);

      // Only show leaves that are:
      // 1. Pending or approved (not rejected)
      // 2. Have valid dates (not expired)
      return (isPending || isApproved) && isDateValid;
    }).toList();

    if (currentLeaves.isEmpty) {
      return Container(
        padding: EdgeInsets.all(isDesktop ? 32 : 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: isDesktop ? 20 : 15,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 20 : 16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                ),
                child: Icon(
                  Icons.hourglass_bottom,
                  size: isDesktop ? 48 : 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(height: isDesktop ? 20 : 16),
              Text(
                'No Active Leave Requests',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: isDesktop ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              SizedBox(height: isDesktop ? 8 : 6),
              Text(
                'Submit a leave request or check history for past requests',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: isDesktop ? 14 : 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: isDesktop ? 25 : 20,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.hourglass_bottom,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: isDesktop ? 24 : 20,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Leave Requests',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: isDesktop ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${currentLeaves.length} request${currentLeaves.length != 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: isDesktop ? 14 : 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 24 : 20),
          ...currentLeaves
              .map((leave) => _buildCurrentLeaveItem(leave, isDesktop))
              .toList(),
        ],
      ),
    );
  }

  /// Build current leave item
  Widget _buildCurrentLeaveItem(Map<String, dynamic> leave, bool isDesktop) {
    final startDate =
        DateTime.tryParse(leave['leave_from_date'] ?? '') ?? DateTime.now();
    final endDate =
        DateTime.tryParse(leave['leave_to_date'] ?? '') ?? DateTime.now();
    final isApproved = (leave['leave_status'] ?? 0) == 1;
    final status = isApproved ? 'Approved' : 'Pending';
    final statusColor =
        isApproved ? AppTheme.successGreen : AppTheme.mediumPriority;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isDesktop ? 12 : 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isApproved ? Icons.check_circle_rounded : Icons.hourglass_bottom,
              color: statusColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}',
                  style: TextStyle(
                    fontSize: isDesktop ? 14 : 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Leave: ${leave['total_leave_days'] ?? 0} days',
                      style: TextStyle(
                        fontSize: isDesktop ? 12 : 10,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        leave['leave_type'] ?? 'General',
                        style: TextStyle(
                          fontSize: isDesktop ? 10 : 8,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (leave['leave_remarks'] != null &&
                    leave['leave_remarks'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    leave['leave_remarks'],
                    style: TextStyle(
                      fontSize: isDesktop ? 11 : 10,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: isDesktop ? 10 : 8,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build rejected leaves summary
  Widget _buildRejectedLeavesSummary(BuildContext context, bool isDesktop) {
    final rejectedLeaves = _leaveHistory.value.where((leave) {
      final isRejected =
          leave['approved_by'] == null && leave['rejected_by'] != null;
      final hasRejectionNotes =
          leave['leave_approval_rejection_remarks'] != null &&
              leave['leave_approval_rejection_remarks'].toString().isNotEmpty;
      return isRejected && hasRejectionNotes;
    }).toList();

    if (rejectedLeaves.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: isDesktop ? 25 : 20,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.error,
                      Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.cancel_rounded,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: isDesktop ? 24 : 20,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rejected Leave Requests',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: isDesktop ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rejectedLeaves.length} request${rejectedLeaves.length != 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: isDesktop ? 14 : 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 24 : 20),
          ...rejectedLeaves
              .take(3)
              .map((leave) => _buildRejectedLeaveItem(leave, isDesktop))
              .toList(),
        ],
      ),
    );
  }

  /// Build rejected leave item for summary
  Widget _buildRejectedLeaveItem(Map<String, dynamic> leave, bool isDesktop) {
    final startDate =
        DateTime.tryParse(leave['leave_from_date'] ?? '') ?? DateTime.now();
    final endDate =
        DateTime.tryParse(leave['leave_to_date'] ?? '') ?? DateTime.now();
    final rejectionNotes =
        leave['leave_approval_rejection_remarks'] ?? 'No reason provided';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: isDesktop ? 16 : 14,
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(width: isDesktop ? 8 : 6),
              Expanded(
                child: Text(
                  '${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: isDesktop ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 8 : 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info,
                size: isDesktop ? 16 : 14,
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(width: isDesktop ? 8 : 6),
              Expanded(
                child: Text(
                  rejectionNotes,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: isDesktop ? 13 : 11,
                        color: Theme.of(context).colorScheme.error,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build leave status pie chart
  Widget _buildLeaveStatusPieChart(BuildContext context, bool isDesktop) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _leaveHistory,
      builder: (context, leaveHistory, child) {
        // Calculate leave status distribution
        int approvedCount = 0;
        int pendingCount = 0;
        int rejectedCount = 0;

        for (final leave in leaveHistory) {
          final isApproved = (leave['leave_status'] ?? 0) == 1;
          final isRejected =
              leave['approved_by'] == null && leave['rejected_by'] != null;
          final isPending =
              leave['approved_by'] == null && leave['rejected_by'] == null;

          if (isApproved) {
            approvedCount++;
          } else if (isRejected) {
            rejectedCount++;
          } else if (isPending) {
            pendingCount++;
          }
        }

        final total = approvedCount + pendingCount + rejectedCount;

        if (total == 0) {
          return Container(
            padding: EdgeInsets.all(isDesktop ? 24 : 20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.pie_chart_outline,
                    size: isDesktop ? 48 : 40,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No leave data available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        final slices = <_DonutSlice>[
          if (approvedCount > 0)
            _DonutSlice(
              label: 'Approved',
              value: approvedCount.toDouble(),
              color: AppTheme.successGreen,
            ),
          if (pendingCount > 0)
            _DonutSlice(
              label: 'Pending',
              value: pendingCount.toDouble(),
              color: AppTheme.mediumPriority,
            ),
          if (rejectedCount > 0)
            _DonutSlice(
              label: 'Rejected',
              value: rejectedCount.toDouble(),
              color: Theme.of(context).colorScheme.error,
            ),
        ];

        return Container(
          padding: EdgeInsets.all(isDesktop ? 24 : 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context)
                    .colorScheme
                    .shadow
                    .withValues(alpha: 0.05),
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
                    padding: EdgeInsets.all(isDesktop ? 12 : 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                    ),
                    child: Icon(
                      Icons.pie_chart_rounded,
                      color: Colors.white,
                      size: isDesktop ? 24 : 20,
                    ),
                  ),
                  SizedBox(width: isDesktop ? 12 : 10),
                  Expanded(
                    child: Text(
                      'Leave Status Distribution',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isDesktop ? 24 : 20),
              Row(
                children: [
                  // Pie Chart
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: isDesktop ? 180 : 150,
                      child: _DonutChart(slices: slices),
                    ),
                  ),
                  SizedBox(width: isDesktop ? 24 : 16),
                  // Legend
                  Expanded(
                    flex: 3,
                    child: _DonutLegend(
                      title: '',
                      slices: slices,
                      titleStyle: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build unified history section
  Widget _buildUnifiedHistorySection(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: isDesktop ? 25 : 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Text(
                'Request History',
                style: TextStyle(
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontSize: isDesktop ? 20 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Unified history list
          Consumer2<WorkFromHomeViewModel, PermissionViewModel>(
            builder: (context, wfhViewModel, permissionViewModel, _) {
              return ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: _leaveHistory,
                builder: (context, leaveHistory, child) {
                  List<_UnifiedHistoryItem> allItems = [];

                  // 1. Add Leave History Items
                  for (var leave in leaveHistory) {
                    final date =
                        DateTime.tryParse(leave['leave_from_date'] ?? '') ??
                            DateTime.now();
                    allItems.add(_UnifiedHistoryItem(
                      date: date,
                      widget: _buildLeaveHistoryItem(leave, isDesktop),
                    ));
                  }

                  // 2. Add WFH History Items
                  for (var request in wfhViewModel.requests) {
                    allItems.add(_UnifiedHistoryItem(
                      date: request.startDate,
                      widget: _buildWorkFromHomeRequestCard(context, request),
                    ));
                  }

                  // 3. Add Permission History Items
                  for (var request in permissionViewModel.requests) {
                    allItems.add(_UnifiedHistoryItem(
                      date: request.permissionDate,
                      widget: _buildPermissionRequestCard(context, request),
                    ));
                  }

                  if (allItems.isEmpty) {
                    return const Center(
                      child: EmptyStateWidget(
                        title: 'No requests yet',
                        subtitle:
                            'Submit your first leave, WFH, or permission request to see it here',
                      ),
                    );
                  }

                  // Sort by date descending
                  allItems.sort((a, b) => b.date.compareTo(a.date));

                  return Column(
                    children: allItems.map((item) => item.widget).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Fetch leave data
  Future<void> _fetchLeaveData() async {
    try {
      print('🔍 Fetching leave data...');
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.isAuthenticated) {
        final employeeDetails = await authViewModel.getCurrentEmployeeDetails();
        print('Employee details: $employeeDetails');
        if (employeeDetails != null) {
          final employeeId =
              employeeDetails['employee_id'] ?? employeeDetails['employeeId'];

          if (employeeId == null) {
            print('Warning: No employee_id found in details: $employeeDetails');
            return;
          }

          // Fetch leave history
          print('📅 Fetching history for employee: $employeeId');
          final history = await _leaveService.getLeaveHistory(employeeId);
          print('📊 History fetched: ${history.length} items');

          if (history.isEmpty) {
            print(
                '⚠️ No leave history found for this employee in the backend.');
          } else {
            print('✅ Samples: ${history.take(1).toList()}');
          }

          _leaveHistory.value = history;

          // Note: Leave balance functionality removed as per user request

          // Update tab selection if there are rejected leaves that need attention
          if (mounted && _hasRejectedLeaves() && selectedTab == 3) {
            setState(() {
              selectedTab = 0; // Switch to leave request tab
            });
          }
        } else {
          print('❌ Employee details or ID is null!');
        }
      } else {
        print('❌ No current user found in AuthViewModel');
      }
    } catch (e, stack) {
      print('❌ Error fetching leave data: $e');
      print(stack);
    }
  }

  /// Build leave history item
  Widget _buildLeaveHistoryItem(Map<String, dynamic> leave, bool isDesktop) {
    final startDate =
        DateTime.tryParse(leave['leave_from_date'] ?? '') ?? DateTime.now();
    final endDate =
        DateTime.tryParse(leave['leave_to_date'] ?? '') ?? DateTime.now();
    final isApproved = (leave['leave_status'] ?? 0) == 1;
    final isRejected =
        leave['approved_by'] == null && leave['rejected_by'] != null;
    final status =
        isApproved ? 'Approved' : (isRejected ? 'Rejected' : 'Pending');
    final statusColor = isApproved
        ? AppTheme.successGreen
        : (isRejected
            ? Theme.of(context).colorScheme.error
            : AppTheme.mediumPriority);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRejected
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.4)
              : statusColor.withValues(alpha: 0.2),
          width: isRejected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isRejected
                ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isApproved
                  ? Icons.check_circle
                  : (isRejected ? Icons.cancel : Icons.hourglass_bottom),
              color: statusColor,
              size: 20,
            ),
          ),
          SizedBox(width: isDesktop ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRejected
                            ? Theme.of(context)
                                .colorScheme
                                .error
                                .withOpacity(0.15)
                            : statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isRejected
                              ? Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withValues(alpha: 0.3)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: isDesktop ? 10 : 8,
                          fontWeight: FontWeight.w600,
                          color: isRejected
                              ? Theme.of(context).colorScheme.error
                              : statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Leave: ${leave['total_leave_days'] ?? 0} days',
                      style: TextStyle(
                        fontSize: isDesktop ? 12 : 10,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        leave['leave_type'] ?? 'General',
                        style: TextStyle(
                          fontSize: isDesktop ? 10 : 8,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (leave['leave_remarks'] != null &&
                    leave['leave_remarks'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    leave['leave_remarks'],
                    style: TextStyle(
                      fontSize: isDesktop ? 12 : 10,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Display rejection notes if leave was rejected
                if (isRejected &&
                    leave['leave_approval_rejection_remarks'] != null &&
                    leave['leave_approval_rejection_remarks']
                        .toString()
                        .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Rejection: ${leave['leave_approval_rejection_remarks']}',
                    style: TextStyle(
                      fontSize: isDesktop ? 11 : 10,
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build task session card
  Widget _buildTaskSessionCard(Map<String, dynamic> session) {
    final isActive = session['clock_out_time'] == null;
    final taskName = session['task_name'] ?? 'Unknown Task';

    // Extract project name and description from project_details field
    final projectDetails = session['project_details'];
    String projectName = 'General Work';
    String? projectDescription;

    if (projectDetails != null && projectDetails is Map<String, dynamic>) {
      projectName = projectDetails['project_name']?.toString() ??
          projectDetails['name']?.toString() ??
          projectDetails['title']?.toString() ??
          'General Work';
      projectDescription = projectDetails['project_description']?.toString() ??
          projectDetails['description']?.toString() ??
          projectDetails['desc']?.toString();
    } else if (session['project_name'] != null) {
      // Fallback to direct project_name field if project_details is not available
      projectName = session['project_name'].toString();
    }

    // Extract task description with additional safety
    String? taskDescription = session['task_description']?.toString();
    // Ensure taskDescription is not null and is a valid string
    if (taskDescription != null && taskDescription.trim().isEmpty) {
      taskDescription = null;
    }

    // Enhanced task status logic
    final taskStatus = _getEnhancedTaskStatus(session);

    final clockInTime = _formatTime(session['clock_in_time']);
    final clockOutTime = _formatTime(session['clock_out_time']);
    final workedHours = session['worked_hours']?.toStringAsFixed(1) ?? '--';
    final sessionDuration = session['session_duration'] ?? '--';
    final workDate =
        session['work_date'] ?? DateTime.now().toString().split(' ')[0];

    // Optional developer notes associated with this task/session
    final String? devNotes =
        (session['dev_task_notes'] ?? session['devNotes'] ?? session['notes'])
            ?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Colors.grey[200]!,
          width: isActive ? 1 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status indicator
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isActive ? Colors.blue : Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      taskName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black87,
                      ),
                    ),
                    if (taskDescription != null &&
                        taskDescription.isNotEmpty &&
                        taskDescription.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        taskDescription.trim(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Project: $projectName',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (projectDescription != null &&
                        projectDescription.isNotEmpty &&
                        projectDescription.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        projectDescription.trim(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(taskStatus).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(taskStatus),
                  ),
                ),
                child: Text(
                  taskStatus,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(taskStatus),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Detailed information
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: $workDate',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Time: $clockInTime → $clockOutTime',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${workedHours}h',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : AppTheme.successGreen,
                    ),
                  ),
                  if (sessionDuration != '--')
                    Text(
                      sessionDuration,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Optional Developer Notes section
          if (devNotes != null && devNotes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.grey[200]),
            const SizedBox(height: 8),
            Text(
              'Notes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              devNotes.trim(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Get enhanced task status based on clock in/out data
  String _getEnhancedTaskStatus(Map<String, dynamic> session) {
    final clockOutTime = session['clock_out_time'];
    final clockInTime = session['clock_in_time'];

    // If no clock in time, task hasn't started
    if (clockInTime == null) {
      return 'Not Started';
    }

    // If no clock out time, task is in progress
    if (clockOutTime == null) {
      return 'In Progress';
    }

    // If clocked out, task is completed (regardless of hours)
    return 'Completed';
  }

  // Helper to parse timestamp string - only converts UTC (with 'Z') to local
  // Timestamps without 'Z' are assumed to already be in local time
  DateTime _parseUtcToLocal(String dateString) {
    if (dateString.isEmpty) return DateTime.now();
    try {
      var isoString = dateString;
      // Handle formats like '2026-01-20 06:23:33' -> '2026-01-20T06:23:33'
      if (!isoString.contains('T') && isoString.contains(' ')) {
        isoString = isoString.replaceAll(' ', 'T');
      }

      // Only convert to local if it's explicitly UTC (ends with 'Z')
      if (isoString.endsWith('Z')) {
        return DateTime.parse(isoString).toLocal();
      }

      // If it has timezone offset like +05:30, parse and convert to local
      if (isoString.contains('+') ||
          RegExp(r'-\d{2}:\d{2}$').hasMatch(isoString)) {
        return DateTime.parse(isoString).toLocal();
      }

      // Otherwise, it's already local time - parse directly without conversion
      return DateTime.parse(isoString);
    } catch (e) {
      // Fallback
      return DateTime.tryParse(dateString) ?? DateTime.now();
    }
  }

  /// Format time for display
  String _formatTime(String? isoTime) {
    if (isoTime == null) return '--:--';
    try {
      final time = _parseUtcToLocal(isoTime);
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  /// Get task statuses from backend via TaskViewModel
  Future<Map<String, String>> _getTaskStatuses(List<String> taskIds) async {
    try {
      final taskViewModel = Provider.of<TaskViewModel>(context, listen: false);
      return await taskViewModel.fetchTaskStatuses(taskIds);
    } catch (e) {
      print('Error fetching task statuses: $e');
      return {};
    }
  }

  /// Enhanced clock in with task selection
  Future<void> _handleClockInEnhanced(BuildContext context) async {
    try {
      // Get available tasks for clock in
      final taskViewModel = Provider.of<TaskViewModel>(context, listen: false);
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final availableTasksData =
          await taskViewModel.fetchUserTasks(authViewModel);

      if (availableTasksData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No available tasks to clock in to')),
        );
        return;
      }

      // Convert Map data to Task objects
      final availableTasks = availableTasksData
          .map((taskData) => Task.fromJson(taskData))
          .toList();

      // Show task selection dialog
      final selectedTask =
          await _showTaskSelectionDialog(context, availableTasks);
      if (selectedTask == null) return;

      // Clock in to selected task
      final attendanceViewModel =
          Provider.of<AttendanceViewModel>(context, listen: false);
      final success = await attendanceViewModel.clockIn(
          selectedTask.taskId, selectedTask.taskName ?? 'Untitled Task');

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '✅ Clocked in to ${selectedTask.taskName ?? 'Untitled Task'}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to clock in')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  /// Enhanced clock out
  Future<void> _handleClockOutEnhanced(BuildContext context) async {
    try {
      final attendanceViewModel =
          Provider.of<AttendanceViewModel>(context, listen: false);
      final success = await attendanceViewModel.clockOut();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Clocked out successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to clock out')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  /// Show task selection dialog
  Future<Task?> _showTaskSelectionDialog(
      BuildContext context, List<Task> tasks) async {
    return showDialog<Task>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Task to Punch In'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                title: Text(task.taskName ?? 'Untitled Task'),
                subtitle: Text((task.taskDescription?.trim().isNotEmpty == true)
                    ? task.taskDescription!.trim()
                    : 'No description'),
                onTap: () => Navigator.of(context).pop(task),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Refresh attendance data
  void _refreshAttendanceData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔄 Attendance data refreshed')),
    );
  }

  /// Show task switch dialog
  void _showTaskSwitchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.blue.shade500),
            const SizedBox(width: 12),
            const Text('Switch Task'),
          ],
        ),
        content: const Text(
            'This feature will allow you to switch between different tasks while maintaining your clock-in status. Coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Handle break action
  void _handleBreakAction(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.coffee, color: Colors.brown.shade400),
            const SizedBox(width: 12),
            const Text('Break Management'),
          ],
        ),
        content: const Text(
            'Break tracking feature will be implemented soon. For now, you can manually clock out and back in for breaks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Build attendance analytics dashboard
  Widget _buildAttendanceAnalytics(BuildContext context,
      AttendanceViewModel attendanceViewModel, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: isDesktop ? 25 : 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Text(
                'Task Analytics',
                style: TextStyle(
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontSize: isDesktop ? 20 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Analytics grid
          Consumer<AttendanceViewModel>(
            builder: (context, attendanceViewModel, child) {
              return FutureBuilder<Map<String, dynamic>?>(
                future: attendanceViewModel.getDailyWorkSummary(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final summary = snapshot.data;
                  if (summary == null) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.1)),
                      ),
                      child: const Center(
                        child: Text(
                          'No analytics data available for today',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }

                  final totalDailyHours = summary['total_daily_hours'] ?? 0.0;
                  final taskSessions = summary['tasks_for_the_day'] ?? [];

                  // Get unique task IDs from sessions
                  final uniqueTaskIds = taskSessions
                      .map((session) => session['task_id'] as String?)
                      .whereType<String>()
                      .where((String id) => id.isNotEmpty)
                      .toSet()
                      .toList();

                  // Count unique tasks, not sessions
                  final totalTasks = uniqueTaskIds.length;

                  // Calculate completed tasks by checking workflow_status from task_cards table
                  return FutureBuilder<Map<String, String>>(
                    future: _getTaskStatuses(uniqueTaskIds),
                    builder: (context, statusSnapshot) {
                      int completedTasks = 0;

                      if (statusSnapshot.hasData) {
                        final taskStatuses = statusSnapshot.data!;
                        for (final taskId in uniqueTaskIds) {
                          final workflowStatus =
                              (taskStatuses[taskId] ?? '').toLowerCase().trim();
                          // A task is completed if workflow_status indicates completion
                          if (workflowStatus == 'work done' ||
                              workflowStatus == 'dev completed' ||
                              workflowStatus == 'completed') {
                            completedTasks++;
                          }
                        }
                      } else {
                        // Fallback: count tasks where ALL sessions have clock_out_time
                        final tasksByTaskId =
                            <String, List<Map<String, dynamic>>>{};
                        for (final session in taskSessions) {
                          final taskId = session['task_id'] as String? ?? '';
                          if (taskId.isNotEmpty) {
                            tasksByTaskId
                                .putIfAbsent(taskId, () => [])
                                .add(session);
                          }
                        }

                        for (final taskSessions in tasksByTaskId.values) {
                          // A task is completed if ALL its sessions have clock_out_time
                          final allSessionsCompleted = taskSessions.every(
                            (session) => session['clock_out_time'] != null,
                          );
                          if (allSessionsCompleted && taskSessions.isNotEmpty) {
                            completedTasks++;
                          }
                        }
                      }

                      return Column(
                        children: [
                          // Key metrics row
                          if (isDesktop)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildAnalyticsCard(
                                    context,
                                    'Total Hours',
                                    '${totalDailyHours.toStringAsFixed(1)}h',
                                    Theme.of(context).colorScheme.primary,
                                    isDesktop,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildAnalyticsCard(
                                    context,
                                    'Total Tasks',
                                    '$totalTasks',
                                    AppTheme.successGreen,
                                    isDesktop,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildAnalyticsCard(
                                    context,
                                    'Completed',
                                    '$completedTasks',
                                    AppTheme.mediumPriority,
                                    isDesktop,
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildAnalyticsCard(
                                        context,
                                        'Total Hours',
                                        '${totalDailyHours.toStringAsFixed(1)}h',
                                        Theme.of(context).colorScheme.primary,
                                        isDesktop,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildAnalyticsCard(
                                        context,
                                        'Total Tasks',
                                        '$totalTasks',
                                        AppTheme.successGreen,
                                        isDesktop,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildAnalyticsCard(
                                  context,
                                  'Completed',
                                  '$completedTasks',
                                  AppTheme.mediumPriority,
                                  isDesktop,
                                ),
                              ],
                            ),

                          const SizedBox(height: 20),

                          // Progress indicator
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Today\'s Task Progress',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 16 : 14,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: totalTasks > 0
                                      ? completedTasks / totalTasks
                                      : 0.0,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary),
                                  minHeight: 8,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${((totalTasks > 0 ? completedTasks / totalTasks : 0.0) * 100).toStringAsFixed(0)}% Complete',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 14 : 12,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build attendance graphs and charts section
  Widget _buildAttendanceGraphs(BuildContext context,
      AttendanceViewModel attendanceViewModel, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.show_chart,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Text(
                'Attendance Trends',
                style: TextStyle(
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  fontSize: isDesktop ? 20 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Charts grid
          Consumer<AttendanceViewModel>(
            builder: (context, attendanceViewModel, child) {
              return FutureBuilder<Map<String, dynamic>?>(
                future: attendanceViewModel.getDailyWorkSummary(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final summary = snapshot.data;
                  if (summary == null) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.1)),
                      ),
                      child: const Center(
                        child: Text(
                          'No chart data available for today',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }

                  final taskSessions = summary['tasks_for_the_day'] ?? [];

                  return Column(
                    children: [
                      // Weekly attendance trend chart
                      _buildWeeklyTrendChart(context, isDesktop),

                      const SizedBox(height: 20),

                      // Daily hours distribution chart
                      _buildDailyHoursChart(
                          context, attendanceViewModel, isDesktop),

                      const SizedBox(height: 20),

                      // Task completion pie chart
                      _buildTaskCompletionChart(
                          context, taskSessions, isDesktop),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build weekly attendance trend chart
  Widget _buildWeeklyTrendChart(BuildContext context, bool isDesktop) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _weeklyAttendanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final weeklyData = snapshot.data ?? [];
        if (weeklyData.isEmpty) {
          return Container(
            height: 200,
            alignment: Alignment.center,
            child: Text(
              'No data for this week',
              style: TextStyle(
                color: Theme.of(context).hintColor,
              ),
            ),
          );
        }

        return Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly Attendance History',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 12, // Assuming 12 hours max work day for scaling
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) =>
                            Theme.of(context).colorScheme.surface,
                        tooltipPadding: const EdgeInsets.all(8),
                        tooltipMargin: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toStringAsFixed(1)}h',
                            TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < weeklyData.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  weeklyData[index]['day'],
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 30,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                            showTitles:
                                false), // Hide left axis numbers for cleaner look
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: false,
                    ),
                    borderData: FlBorderData(
                      show: false,
                    ),
                    barGroups: weeklyData.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      final hours = (data['hours'] as num).toDouble();

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: hours,
                            color: hours > 0
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2),
                            width: 16,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: 12, // Max hours background
                              color: Colors.grey.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build daily hours distribution chart
  Widget _buildDailyHoursChart(BuildContext context,
      AttendanceViewModel attendanceViewModel, bool isDesktop) {
    return FutureBuilder<List<EmployeeAttendance>>(
      future: attendanceViewModel.getTodayAttendanceRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final attendanceRecords = snapshot.data ?? [];

        // Distribute worked hours explicitly into 0..23 hour buckets
        final hourDistribution = List.generate(24, (hour) {
          double fractionWorkedInThisHour = 0.0;
          final hourStart = DateTime(DateTime.now().year, DateTime.now().month,
              DateTime.now().day, hour, 0, 0);
          final hourEnd = hourStart.add(const Duration(hours: 1));

          for (var record in attendanceRecords) {
            if (!record.isClockedIn) continue;

            final workDate = record.workDate;
            final clockOnString = record.clockOnTime;

            try {
              final clockInTime = DateTime.parse('$workDate $clockOnString');
              final clockOutTime = record.isClockedOut
                  ? DateTime.parse('$workDate ${record.clockOffTime}')
                  : DateTime
                      .now(); // If currently working, consider 'now' as clock out for chart

              // Check if overlap exists
              if (clockInTime.isBefore(hourEnd) &&
                  clockOutTime.isAfter(hourStart)) {
                // Calculate exact overlap
                final overlapStart =
                    clockInTime.isAfter(hourStart) ? clockInTime : hourStart;
                final overlapEnd =
                    clockOutTime.isBefore(hourEnd) ? clockOutTime : hourEnd;

                final overlapDuration = overlapEnd.difference(overlapStart);
                if (overlapDuration.inSeconds > 0) {
                  fractionWorkedInThisHour +=
                      overlapDuration.inSeconds / 3600.0;
                }
              }
            } catch (e) {
              // Ignore parse errors for badly formatted fallback records
            }
          }

          // Cap at 1.0 (an hour cannot have more than 1 hour of work)
          if (fractionWorkedInThisHour > 1.0) fractionWorkedInThisHour = 1.0;

          return {'hour': hour, 'sessions': fractionWorkedInThisHour};
        });

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Hours History',
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Bar chart
              SizedBox(
                height: isDesktop ? 150 : 120,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 1.0,
                    minY: 0,
                    barGroups: hourDistribution.map((data) {
                      return BarChartGroupData(
                        x: data['hour'] as int,
                        barRods: [
                          BarChartRodData(
                            toY: (data['sessions'] as num).toDouble(),
                            color: Theme.of(context).colorScheme.primary,
                            width: isDesktop ? 12 : 8,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            Theme.of(context).colorScheme.surface,
                        tooltipPadding: const EdgeInsets.all(8),
                        tooltipMargin: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          if (rod.toY == 0) return null;
                          final hourStr =
                              '${group.x.toString().padLeft(2, '0')}:00';
                          final minutes = (rod.toY * 60).round();
                          final timeStr = minutes >= 60 ? '1h' : '${minutes}m';
                          return BarTooltipItem(
                            '$hourStr\n',
                            TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: 'Worked: $timeStr',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final hour = value.toInt();
                            if (hour % 6 == 0 || hour == 23) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${hour.toString().padLeft(2, '0')}:00',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 24,
                        ),
                      ),
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build task completion pie chart
  Widget _buildTaskCompletionChart(
      BuildContext context, List<dynamic> taskSessions, bool isDesktop) {
    // Get unique task IDs from sessions
    final uniqueTaskIds = taskSessions
        .map((session) => session['task_id'] as String?)
        .whereType<String>()
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();

    // Count unique tasks, not sessions
    final totalTasks = uniqueTaskIds.length;

    // Group sessions by task_id
    final tasksByTaskId = <String, List<Map<String, dynamic>>>{};
    for (final session in taskSessions) {
      final taskId = session['task_id'] as String? ?? '';
      if (taskId.isNotEmpty) {
        tasksByTaskId.putIfAbsent(taskId, () => []).add(session);
      }
    }

    // Count completed tasks (all sessions for a task must have clock_out_time)
    int completedTasks = 0;
    int activeTasks = 0;

    for (final taskSessions in tasksByTaskId.values) {
      // A task is completed if ALL its sessions have clock_out_time
      final allSessionsCompleted = taskSessions.every(
        (session) => session['clock_out_time'] != null,
      );
      // A task is active if ANY session has clock_out_time == null
      final hasActiveSession = taskSessions.any(
        (session) => session['clock_out_time'] == null,
      );

      if (allSessionsCompleted && taskSessions.isNotEmpty) {
        completedTasks++;
      } else if (hasActiveSession) {
        activeTasks++;
      }
    }

    if (totalTasks == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        ),
        child: const Center(
          child: Text(
            'No tasks to display',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    final completedPercentage =
        totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    final activePercentage = totalTasks > 0 ? activeTasks / totalTasks : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Completion History',
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Pie chart
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: isDesktop ? 120 : 100,
                  child: CustomPaint(
                    size: Size(isDesktop ? 120 : 100, isDesktop ? 120 : 100),
                    painter: PieChartPainter(
                      completedPercentage: completedPercentage,
                      activePercentage: activePercentage,
                      primaryColor: Theme.of(context).colorScheme.primary,
                      onPrimaryColor: Theme.of(context).scaffoldBackgroundColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Legend
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(
                      'Completed Tasks',
                      completedTasks,
                      AppTheme.successGreen,
                      isDesktop,
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      'Active Tasks',
                      activeTasks,
                      Theme.of(context).colorScheme.primary,
                      isDesktop,
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      'Total Tasks',
                      totalTasks,
                      Colors.grey,
                      isDesktop,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build legend item for pie chart
  Widget _buildLegendItem(
      String label, int value, Color color, bool isDesktop) {
    return Row(
      children: [
        Container(
          width: isDesktop ? 16 : 12,
          height: isDesktop ? 16 : 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $value',
            style: TextStyle(
              fontSize: isDesktop ? 14 : 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Build analytics card
  Widget _buildAnalyticsCard(BuildContext context, String title, String value,
      Color color, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: isDesktop ? 15 : 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isDesktop ? 14 : 10,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isDesktop ? 12 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isDesktop ? 24 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Work From Home Tab Methods
  Widget _buildDesktopWorkFromHomeLayout(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WorkFromHomeViewModel()..initializeData(context),
      child: Consumer<WorkFromHomeViewModel>(
        builder: (context, wfhViewModel, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                // Left side - Request Form
                Expanded(
                  flex: 2,
                  child: _buildWorkFromHomeRequestForm(context, wfhViewModel),
                ),
                const SizedBox(width: 20),
                // Right side - Statistics and History
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildWorkFromHomeStatistics(context, wfhViewModel),
                      const SizedBox(height: 20),
                      _buildWorkFromHomeHistory(context, wfhViewModel),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkFromHomeTab(BuildContext context, bool isDesktop) {
    return ChangeNotifierProvider(
      create: (context) => WorkFromHomeViewModel()..initializeData(context),
      child: Consumer<WorkFromHomeViewModel>(
        builder: (context, wfhViewModel, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildWorkFromHomeRequestForm(context, wfhViewModel),
                const SizedBox(height: 20),
                _buildWorkFromHomeStatistics(context, wfhViewModel),
                const SizedBox(height: 20),
                _buildWorkFromHomeHistory(context, wfhViewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  // Permission Tab Methods
  Widget _buildDesktopPermissionLayout(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PermissionViewModel()..initializeData(context),
      child: Consumer<PermissionViewModel>(
        builder: (context, permissionViewModel, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                // Left side - Request Form
                Expanded(
                  flex: 2,
                  child:
                      _buildPermissionRequestForm(context, permissionViewModel),
                ),
                const SizedBox(width: 20),
                // Right side - Statistics and History
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildPermissionStatistics(context, permissionViewModel),
                      const SizedBox(height: 20),
                      _buildPermissionHistory(context, permissionViewModel),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPermissionTab(BuildContext context, bool isDesktop) {
    return ChangeNotifierProvider(
      create: (context) => PermissionViewModel()..initializeData(context),
      child: Consumer<PermissionViewModel>(
        builder: (context, permissionViewModel, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPermissionRequestForm(context, permissionViewModel),
                const SizedBox(height: 20),
                _buildPermissionStatistics(context, permissionViewModel),
                const SizedBox(height: 20),
                _buildPermissionHistory(context, permissionViewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  // Work From Home UI Components
  Widget _buildWorkFromHomeStatistics(
      BuildContext context, WorkFromHomeViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
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
              Icon(
                Icons.home_work,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Work From Home Stats',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (viewModel.isLoading) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
          ] else if (viewModel.error != null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      viewModel.error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else if (viewModel.statistics != null) ...[
            Builder(
              builder: (context) {
                final stats = viewModel.statistics!;
                final int approved = (stats['approved_requests'] ?? 0) as int;
                final int pending = (stats['pending_requests'] ?? 0) as int;
                final int rejected = (stats['rejected_requests'] ?? 0) as int;
                final int total = (stats['total_requests'] ?? 0) as int;

                final List<_DonutSlice> slices = [
                  _DonutSlice(
                    label: 'Approved',
                    value: approved.toDouble(),
                    color: AppTheme.successGreen,
                  ),
                  _DonutSlice(
                    label: 'Pending',
                    value: pending.toDouble(),
                    color: AppTheme.mediumPriority,
                  ),
                  _DonutSlice(
                    label: 'Rejected',
                    value: rejected.toDouble(),
                    color: Theme.of(context).colorScheme.error,
                  ),
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1.6,
                            child: _DonutChart(slices: slices),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _DonutLegend(
                            title: 'Requests ($total)',
                            slices: slices,
                            titleStyle: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildWFHStatCard(
                      context,
                      'Total Days',
                      stats['total_days'].toString(),
                      Icons.calendar_today,
                      Theme.of(context).colorScheme.primary,
                    ),
                  ],
                );
              },
            ),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkFromHomeRequestForm(
      BuildContext context, WorkFromHomeViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _WorkFromHomeForm(viewModel: viewModel),
    );
  }

  Widget _buildWorkFromHomeHistory(
      BuildContext context, WorkFromHomeViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Work From Home History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          if (viewModel.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (viewModel.requests.isEmpty)
            const Center(
              child: EmptyStateWidget(
                title: 'No work from home requests',
                subtitle: 'Your WFH request history will appear here',
                size: 150,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: viewModel.requests.length,
              itemBuilder: (context, index) {
                final request = viewModel.requests[index];
                return _buildWorkFromHomeRequestCard(context, request);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWorkFromHomeRequestCard(
      BuildContext context, WorkFromHomeRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getWFHStatusColor(request.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getWFHStatusIcon(request.status),
            color: _getWFHStatusColor(request.status),
            size: 20,
          ),
        ),
        title: Text(
          '${request.startDate.day}/${request.startDate.month} - ${request.endDate.day}/${request.endDate.month}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      _getWFHStatusColor(request.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  request.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getWFHStatusColor(request.status),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${request.totalDays} day${request.totalDays > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: (request.reason != null && request.reason!.isNotEmpty)
            ? Tooltip(
                message: request.reason!,
                child: Icon(Icons.info,
                    size: 18, color: Theme.of(context).colorScheme.outline),
              )
            : null,
      ),
    );
  }

  // Permission UI Components
  Widget _buildPermissionStatistics(
      BuildContext context, PermissionViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
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
              Icon(
                Icons.hourglass_bottom,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Permission Stats',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (viewModel.statistics != null) ...[
            Builder(
              builder: (context) {
                final stats = viewModel.statistics!;
                final int approved = (stats['approved_requests'] ?? 0) as int;
                final int pending = (stats['pending_requests'] ?? 0) as int;
                final int rejected = (stats['rejected_requests'] ?? 0) as int;
                final int total = (stats['total_requests'] ?? 0) as int;

                final List<_DonutSlice> slices = [
                  _DonutSlice(
                    label: 'Approved',
                    value: approved.toDouble(),
                    color: AppTheme.successGreen,
                  ),
                  _DonutSlice(
                    label: 'Pending',
                    value: pending.toDouble(),
                    color: AppTheme.mediumPriority,
                  ),
                  _DonutSlice(
                    label: 'Rejected',
                    value: rejected.toDouble(),
                    color: Theme.of(context).colorScheme.error,
                  ),
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1.6,
                            child: _DonutChart(slices: slices),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _DonutLegend(
                            title: 'Requests ($total)',
                            slices: slices,
                            titleStyle: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPermissionStatCard(
                      context,
                      'Total Hours',
                      stats['total_hours'].toStringAsFixed(1),
                      Icons.access_time,
                      Theme.of(context).colorScheme.primary,
                    ),
                  ],
                );
              },
            ),
          ] else
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionRequestForm(
      BuildContext context, PermissionViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _PermissionForm(viewModel: viewModel),
    );
  }

  Widget _buildPermissionHistory(
      BuildContext context, PermissionViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Permission History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          if (viewModel.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (viewModel.requests.isEmpty)
            const Center(
              child: EmptyStateWidget(
                title: 'No permission requests',
                subtitle: 'Your permission request history will appear here',
                size: 150,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: viewModel.requests.length,
              itemBuilder: (context, index) {
                final request = viewModel.requests[index];
                return _buildPermissionRequestCard(context, request);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionRequestCard(
      BuildContext context, PermissionRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getWFHStatusColor(request.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getWFHStatusIcon(request.status),
            color: _getWFHStatusColor(request.status),
            size: 20,
          ),
        ),
        title: Text(
          request.formattedTimeRange,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      _getWFHStatusColor(request.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  request.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getWFHStatusColor(request.status),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${request.permissionDate.day}/${request.permissionDate.month} • ${request.formattedDuration}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: (request.permissionRemarks != null &&
                request.permissionRemarks!.isNotEmpty)
            ? Tooltip(
                message: request.permissionRemarks!,
                child: Icon(Icons.info,
                    size: 18, color: Theme.of(context).colorScheme.outline),
              )
            : null,
      ),
    );
  }

  // Helper methods
  Widget _buildWFHStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color.withValues(alpha: 0.8),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionStatCard(BuildContext context, String title,
      String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.8),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getWFHStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Theme.of(context).colorScheme.primary;
      case 'rejected':
        return Theme.of(context).colorScheme.error;
      case 'pending':
        return Theme.of(context).colorScheme.primary.withValues(alpha: 0.6);
      default:
        return Colors.grey;
    }
  }

  IconData _getWFHStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.hourglass_bottom;
      default:
        return Icons.help;
    }
  }
}

/// Work From Home Request Form
class _WorkFromHomeForm extends StatefulWidget {
  final WorkFromHomeViewModel viewModel;

  const _WorkFromHomeForm({required this.viewModel});

  @override
  State<_WorkFromHomeForm> createState() => _WorkFromHomeFormState();
}

class _WorkFromHomeFormState extends State<_WorkFromHomeForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Work From Home',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 20),

          // Start Date
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Start Date',
              hintText: 'Select start date',
              prefixIcon: Icon(
                Icons.calendar_today,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() {
                  _startDate = date;
                });
              }
            },
            validator: (value) {
              if (_startDate == null) {
                return 'Please select a start date';
              }
              return null;
            },
            controller: TextEditingController(
              text: _startDate != null
                  ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                  : '',
            ),
          ),
          const SizedBox(height: 16),

          // End Date
          TextFormField(
            decoration: InputDecoration(
              labelText: 'End Date',
              hintText: 'Select end date',
              prefixIcon: Icon(
                Icons.calendar_today,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _endDate ?? (_startDate ?? DateTime.now()),
                firstDate: _startDate ?? DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() {
                  _endDate = date;
                });
              }
            },
            validator: (value) {
              if (_endDate == null) {
                return 'Please select an end date';
              }
              if (_startDate != null && _endDate!.isBefore(_startDate!)) {
                return 'End date must be after start date';
              }
              return null;
            },
            controller: TextEditingController(
              text: _endDate != null
                  ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                  : '',
            ),
          ),
          const SizedBox(height: 16),

          // Reason
          TextFormField(
            controller: _reasonController,
            decoration: InputDecoration(
              labelText: 'Reason (Optional)',
              hintText: 'Enter reason for work from home',
              prefixIcon: Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            maxLines: 3,
            validator: (value) {
              if (value != null && value.length > 500) {
                return 'Reason must be less than 500 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Duration Display
          if (_startDate != null && _endDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Duration: ${_endDate!.difference(_startDate!).inDays + 1} days',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Submit Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current user info and resolve employee_id from employees table
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

      // Check authentication using backend auth check (not Supabase currentUser)
      if (!authViewModel.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final employeeRecord = await authViewModel.getCurrentEmployeeDetails();
      if (employeeRecord == null || employeeRecord['employee_id'] == null) {
        throw Exception('Employee record not found. Please contact HR.');
      }
      final String employeeTableId = employeeRecord['employee_id'] as String;

      // Get name from employee record, not from Supabase currentUser
      final String employeeName = employeeRecord['employee_name'] ??
          employeeRecord['employeeName'] ??
          'Unknown Employee';
      final String? employeeRole =
          employeeRecord['employee_role'] ?? employeeRecord['employeeRole'];

      final success = await widget.viewModel.createWorkFromHomeRequest(
        employeeId: employeeTableId,
        employeeName: employeeName,
        employeeRole: employeeRole,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Work from home request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form
        _reasonController.clear();
        setState(() {
          _startDate = null;
          _endDate = null;
        });
      } else {
        throw Exception('Failed to submit request');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

/// Permission Request Form
class _PermissionForm extends StatefulWidget {
  final PermissionViewModel viewModel;

  const _PermissionForm({required this.viewModel});

  @override
  State<_PermissionForm> createState() => _PermissionFormState();
}

class _PermissionFormState extends State<_PermissionForm> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  DateTime? _permissionDate;
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request Permission',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 20),

          // Permission Date
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Permission Date',
              hintText: 'Select date for permission',
              prefixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _permissionDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (date != null) {
                setState(() {
                  _permissionDate = date;
                });
              }
            },
            validator: (value) {
              if (_permissionDate == null) {
                return 'Please select a permission date';
              }
              return null;
            },
            controller: TextEditingController(
              text: _permissionDate != null
                  ? '${_permissionDate!.day}/${_permissionDate!.month}/${_permissionDate!.year}'
                  : '',
            ),
          ),
          const SizedBox(height: 16),

          // From Time
          TextFormField(
            decoration: InputDecoration(
              labelText: 'From Time',
              hintText: 'Select start time',
              prefixIcon: Icon(Icons.access_time),
            ),
            readOnly: true,
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _fromTime ?? TimeOfDay.now(),
              );
              if (time != null) {
                setState(() {
                  _fromTime = time;
                });
              }
            },
            validator: (value) {
              if (_fromTime == null) {
                return 'Please select start time';
              }
              return null;
            },
            controller: TextEditingController(
              text: _fromTime != null ? _fromTime!.format(context) : '',
            ),
          ),
          const SizedBox(height: 16),

          // To Time
          TextFormField(
            decoration: InputDecoration(
              labelText: 'To Time',
              hintText: 'Select end time',
              prefixIcon: Icon(Icons.access_time),
            ),
            readOnly: true,
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _toTime ?? TimeOfDay.now(),
              );
              if (time != null) {
                setState(() {
                  _toTime = time;
                });
              }
            },
            validator: (value) {
              if (_toTime == null) {
                return 'Please select end time';
              }
              if (_fromTime != null && _toTime != null) {
                final fromMinutes = _fromTime!.hour * 60 + _fromTime!.minute;
                final toMinutes = _toTime!.hour * 60 + _toTime!.minute;
                if (toMinutes <= fromMinutes) {
                  return 'End time must be after start time';
                }
              }
              return null;
            },
            controller: TextEditingController(
              text: _toTime != null ? _toTime!.format(context) : '',
            ),
          ),
          const SizedBox(height: 16),

          // Remarks
          TextFormField(
            controller: _remarksController,
            decoration: InputDecoration(
              labelText: 'Remarks (Optional)',
              hintText: 'Enter reason for permission',
              prefixIcon: Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            maxLines: 3,
            validator: (value) {
              if (value != null && value.length > 500) {
                return 'Remarks must be less than 500 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Duration Display
          if (_fromTime != null && _toTime != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Duration: ${_calculateDuration()}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Submit Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateDuration() {
    if (_fromTime == null || _toTime == null) return '';

    final fromMinutes = _fromTime!.hour * 60 + _fromTime!.minute;
    final toMinutes = _toTime!.hour * 60 + _toTime!.minute;
    final durationMinutes = toMinutes - fromMinutes;

    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current user info
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);

      // Check authentication using backend auth check (not Supabase currentUser)
      if (!authViewModel.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      // Resolve employees.employee_id (text) for FK constraint
      final employeeRecord = await authViewModel.getCurrentEmployeeDetails();
      if (employeeRecord == null || employeeRecord['employee_id'] == null) {
        throw Exception('Employee record not found. Please contact HR.');
      }
      final String employeeTableId = employeeRecord['employee_id'] as String;

      // Get name from employee record, not from Supabase currentUser
      final String employeeName = employeeRecord['employee_name'] ??
          employeeRecord['employeeName'] ??
          'Unknown Employee';

      // Convert TimeOfDay to DateTime
      final fromDateTime = DateTime(
        _permissionDate!.year,
        _permissionDate!.month,
        _permissionDate!.day,
        _fromTime!.hour,
        _fromTime!.minute,
      );

      final toDateTime = DateTime(
        _permissionDate!.year,
        _permissionDate!.month,
        _permissionDate!.day,
        _toTime!.hour,
        _toTime!.minute,
      );

      final success = await widget.viewModel.createPermissionRequest(
        employeeId: employeeTableId,
        employeeName: employeeName,
        permissionDate: _permissionDate!,
        permissionFromTime: fromDateTime,
        permissionToTime: toDateTime,
        permissionRemarks: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text.trim(),
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Permission request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form
        _remarksController.clear();
        setState(() {
          _permissionDate = null;
          _fromTime = null;
          _toTime = null;
        });
      } else {
        throw Exception('Failed to submit request');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}

/// Custom painter for line chart
class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double maxValue;
  final Color color;

  LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxValue == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final width = size.width / (data.length - 1);
    final height = size.height;

    for (int i = 0; i < data.length; i++) {
      final x = i * width;
      final normalizedValue = maxValue > 0
          ? (data[i]['sessions'] as num).toDouble() / maxValue
          : 0.0;
      final y = height - (normalizedValue * height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Close the fill path
    fillPath.lineTo(size.width, height);
    fillPath.close();

    // Draw fill
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    canvas.drawPath(path, paint);

    // Draw data points
    for (int i = 0; i < data.length; i++) {
      final x = i * width;
      final normalizedValue = maxValue > 0
          ? (data[i]['sessions'] as num).toDouble() / maxValue
          : 0.0;
      final y = height - (normalizedValue * height);

      final pointPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for pie chart
class PieChartPainter extends CustomPainter {
  final double completedPercentage;
  final double activePercentage;
  final Color primaryColor;
  final Color onPrimaryColor;

  PieChartPainter({
    required this.completedPercentage,
    required this.activePercentage,
    required this.primaryColor,
    required this.onPrimaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width < size.height ? size.width / 2 : size.height / 2;

    // Draw shadow/depth
    final shadowOffset = Offset(0, 4);

    if (completedPercentage > 0) {
      final shadowPaint = Paint()
        ..color = AppTheme.successGreen.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;

      final shadowRect =
          Rect.fromCircle(center: center + shadowOffset, radius: radius);
      canvas.drawArc(
        shadowRect,
        0,
        2 * pi * completedPercentage,
        true,
        shadowPaint,
      );
    }

    if (activePercentage > 0) {
      final shadowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;

      final shadowRect =
          Rect.fromCircle(center: center + shadowOffset, radius: radius);
      canvas.drawArc(
        shadowRect,
        2 * pi * completedPercentage,
        2 * pi * activePercentage,
        true,
        shadowPaint,
      );
    }

    // Draw completed tasks slice
    if (completedPercentage > 0) {
      final completedPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.successGreen.withValues(alpha: 0.8),
            AppTheme.successGreen,
          ],
          center: Alignment.topLeft,
          radius: 1.5,
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      final completedRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        completedRect,
        0,
        2 * pi * completedPercentage,
        true,
        completedPaint,
      );
    }

    // Draw active tasks slice
    if (activePercentage > 0) {
      final activePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            primaryColor.withValues(alpha: 0.8),
            primaryColor,
          ],
          center: Alignment.topLeft,
          radius: 1.5,
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      final activeRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        activeRect,
        2 * pi * completedPercentage,
        2 * pi * activePercentage,
        true,
        activePaint,
      );
    }

    // Draw center circle for donut effect
    final centerPaint = Paint()
      ..color = onPrimaryColor
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          onPrimaryColor,
          onPrimaryColor.withValues(alpha: 0.9),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.6));

    canvas.drawCircle(center, radius * 0.6, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Generic donut chart data and widgets
class _DonutSlice {
  final String label;
  final double value;
  final Color color;

  const _DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _DonutChart extends StatelessWidget {
  final List<_DonutSlice> slices;

  const _DonutChart({required this.slices});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    final innerColor = Theme.of(context).cardColor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxWidth);
        return CustomPaint(
          size: size,
          painter: _DonutPainter(
              slices: slices, total: total, innerColor: innerColor),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSlice> slices;
  final double total;
  final Color innerColor;

  _DonutPainter(
      {required this.slices, required this.total, required this.innerColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    double startAngle = -pi / 2;
    for (final slice in slices) {
      final sweep = total > 0 ? (slice.value / total) * 2 * pi : 0.0;
      if (sweep <= 0) continue;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, sweep, true, paint);
      startAngle += sweep;
    }

    // Inner hole
    final innerPaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.6, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.total != total;
  }
}

class _DonutLegend extends StatelessWidget {
  final String title;
  final List<_DonutSlice> slices;
  final TextStyle? titleStyle;

  const _DonutLegend({
    required this.title,
    required this.slices,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: 12),
        ...slices.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    s.value.toStringAsFixed(0),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
