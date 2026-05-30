import 'dart:ui';
import 'dart:async';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as provider;
import 'package:webnox_taskops/model/task_model.dart';
import 'package:webnox_taskops/utils/responsive_utils.dart';
import 'package:webnox_taskops/services/report_service.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import 'package:webnox_taskops/view_model/task_view_model.dart';
import 'package:webnox_taskops/widgets/animated_loading_states.dart';
import 'package:webnox_taskops/view_model/attendance_view_model.dart';
import 'package:webnox_taskops/view_model/report_view_model.dart';
import 'package:webnox_taskops/helpers/common_colors.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/animations/silk_shader_widget.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;

  // Tab Controller
  late TabController _tabController;
  late AnimationController _tabAnimationController;
  late Animation<double> _tabAnimation;

  // Metric Card Animations (for mobile view)
  final Map<String, AnimationController> _metricAnimationControllers = {};
  final Map<String, Animation<double>> _metricAnimations = {};

  // Session Management State
  Task? _selectedTask;
  bool _isClockedIn = false;
  DateTime? _sessionStartTime;
  Duration _sessionDuration = Duration.zero;
  Timer? _sessionTimer;

  // Daily Summary State
  Map<String, dynamic>? _dailySummary;

  // Task Work Today State
  List<Task> _availableTasks = [];

  // Per-task notes on the report screen (Task Work Today)
  final Map<String, TextEditingController> _taskNotesControllers = {};

  // Report History State
  // Access report history from ViewModel
  List<Map<String, dynamic>> get _reportHistory {
    try {
      return provider.Provider.of<ReportViewModel>(context).reportHistory;
    } catch (_) {
      return [];
    }
  }

  // Access loading state from ViewModel
  bool get _isLoadingHistory {
    try {
      return provider.Provider.of<ReportViewModel>(context).isLoadingHistory;
    } catch (_) {
      return false;
    }
  }

  // Access ViewModel
  ReportViewModel get _reportViewModel {
    return provider.Provider.of<ReportViewModel>(context);
  }

  // Access ViewModel (Read Only - no listen)
  ReportViewModel get _reportViewModelRead {
    return provider.Provider.of<ReportViewModel>(context, listen: false);
  }

  // Report Notes Controller
  TextEditingController? _reportNotesController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _tabAnimation = CurvedAnimation(
      parent: _tabAnimationController,
      curve: Curves.easeInOut,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _tabAnimationController.forward();
      }
    });

    _reportNotesController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTodayData();
      _loadAvailableTasks();
      _checkCurrentSessionStatus();
      _loadReportHistory();
    });
  }

  @override
  void dispose() {
    _stopSessionTimer();
    _tabController.dispose();
    _tabAnimationController.dispose();
    _reportNotesController?.dispose();

    // Dispose task-notes controllers
    for (final controller in _taskNotesControllers.values) {
      controller.dispose();
    }

    // Dispose metric animation controllers
    for (final controller in _metricAnimationControllers.values) {
      controller.dispose();
    }
    _metricAnimationControllers.clear();
    _metricAnimations.clear();

    super.dispose();
  }

  /// Load today's data for summary
  Future<void> _loadTodayData() async {
    setState(() => _isLoading = true);

    try {
      final attendanceViewModel =
          provider.Provider.of<AttendanceViewModel>(context, listen: false);
      final summary = await attendanceViewModel.getDailyWorkSummary();

      setState(() {
        _dailySummary = summary;
        _isLoading = false;
      });

      // Update clocked in status based on actual data
      _updateClockedInStatusFromSummary();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Update clocked in status based on daily summary data
  /// Active session = ANY task (excluding "Daily Attendance") with clock_out_time == null
  void _updateClockedInStatusFromSummary() {
    if (_dailySummary == null) {
      setState(() {
        _isClockedIn = false;
        _sessionStartTime = null;
        _sessionDuration = Duration.zero;
      });
      _stopSessionTimer();
      return;
    }

    final tasks = _dailySummary!['tasks_for_the_day'] as List<dynamic>? ?? [];

    // Check if ANY task (excluding "Daily Attendance") is clocked in
    // "Daily Attendance" is just attendance tracking, not a work session
    final hasActiveTask = tasks.any((task) {
      final taskName = task['task_name']?.toString() ?? '';
      final clockOutTime = task['clock_out_time'];
      // Exclude "Daily Attendance" from active session detection
      return clockOutTime == null &&
          taskName.toLowerCase() != 'daily attendance';
    });

    if (hasActiveTask) {
      // Find the active task (excluding "Daily Attendance")
      Map<String, dynamic>? activeTask;
      for (final task in tasks) {
        final taskName = task['task_name']?.toString() ?? '';
        final clockOutTime = task['clock_out_time'];
        if (clockOutTime == null &&
            taskName.toLowerCase() != 'daily attendance') {
          activeTask = task is Map ? Map<String, dynamic>.from(task) : null;
          break;
        }
      }

      // Use current_session_start from daily attendance (from the active task)
      final currentSessionStart = _dailySummary!['current_session_start'];
      String? sessionStartTime;

      // Check if current_session_start is from "Daily Attendance" - if so, use active task's time
      final activeTaskName =
          _dailySummary!['active_task_name']?.toString() ?? '';
      if (activeTaskName.toLowerCase() == 'daily attendance' &&
          activeTask != null) {
        sessionStartTime = activeTask['clock_in_time']?.toString();
      } else if (currentSessionStart != null &&
          currentSessionStart.toString().isNotEmpty) {
        sessionStartTime = currentSessionStart.toString();
      } else if (activeTask != null && activeTask['clock_in_time'] != null) {
        sessionStartTime = activeTask['clock_in_time']?.toString() ?? '';
      }

      if (sessionStartTime != null && sessionStartTime.isNotEmpty) {
        try {
          setState(() {
            _isClockedIn = true;
            _sessionStartTime = _parseUtcToLocal(sessionStartTime!);
          });

          if (_sessionTimer == null) {
            _startSessionTimer();
          }
        } catch (e) {
          debugPrint('Error parsing session start time: $e');
          setState(() {
            _isClockedIn = false;
            _sessionStartTime = null;
          });
          _stopSessionTimer();
        }
      } else {
        setState(() {
          _isClockedIn = false;
          _sessionStartTime = null;
        });
        _stopSessionTimer();
      }
    } else {
      // No active tasks (excluding Daily Attendance) - not clocked in
      setState(() {
        _isClockedIn = false;
        _sessionStartTime = null;
        _sessionDuration = Duration.zero;
      });
      _stopSessionTimer();
    }
  }

  /// Load available tasks for selection
  Future<void> _loadAvailableTasks() async {
    try {
      final taskViewModel =
          provider.Provider.of<TaskViewModel>(context, listen: false);
      final authViewModel =
          provider.Provider.of<AuthViewModel>(context, listen: false);
      final taskData = await taskViewModel.fetchTasksSmart(authViewModel);
      final tasks = taskData.map((json) => Task.fromJson(json)).toList();

      setState(() {
        _availableTasks = tasks;
        // Set default selected task if none selected and tasks available
        if (_selectedTask == null && tasks.isNotEmpty) {
          _selectedTask = tasks.first;
        }
      });
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      setState(() {
        _availableTasks = [];
      });
    }
  }

  /// Check current session status
  Future<void> _checkCurrentSessionStatus() async {
    try {
      final attendanceViewModel =
          provider.Provider.of<AttendanceViewModel>(context, listen: false);
      final status = await attendanceViewModel.getCurrentAttendanceStatus();

      // Only set as clocked in if status explicitly says so AND has session_start_time
      if (status != null &&
          status['is_clocked_in'] == true &&
          status['session_start_time'] != null &&
          status['session_start_time'].toString().isNotEmpty) {
        try {
          setState(() {
            _isClockedIn = true;
            _sessionStartTime = _parseUtcToLocal(status['session_start_time']);
          });

          if (_sessionTimer == null) {
            _startSessionTimer();
          }

          // Set selected task
          final taskId = status['current_task_id'];
          if (taskId != null && _availableTasks.isNotEmpty) {
            final currentTask = _availableTasks.firstWhere(
              (task) => task.taskId == taskId,
              orElse: () => _availableTasks.first,
            );
            setState(() {
              _selectedTask = currentTask;
            });
          }
        } catch (e) {
          debugPrint(
              'Error parsing session start time in _checkCurrentSessionStatus: $e');
          setState(() {
            _isClockedIn = false;
            _sessionStartTime = null;
            _sessionDuration = Duration.zero;
          });
          _stopSessionTimer();
        }
      } else {
        setState(() {
          _isClockedIn = false;
          _sessionStartTime = null;
          _sessionDuration = Duration.zero;
        });
        _stopSessionTimer();
      }
    } catch (e) {
      debugPrint('Error checking session status: $e');
      // On error, assume not clocked in
      setState(() {
        _isClockedIn = false;
        _sessionStartTime = null;
        _sessionDuration = Duration.zero;
      });
      _stopSessionTimer();
    }
  }

  /// Clock in to start a new session
  Future<void> _clockIn() async {
    if (_selectedTask == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a task first'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    try {
      final attendanceViewModel =
          provider.Provider.of<AttendanceViewModel>(context, listen: false);
      final success = await attendanceViewModel.clockIn(
          _selectedTask!.taskId, _selectedTask!.taskName ?? 'Untitled Task');

      if (success) {
        // Get the actual database start time after clocking in
        final status = await attendanceViewModel.getCurrentAttendanceStatus();
        if (status != null && status['is_clocked_in'] == true) {
          setState(() {
            _isClockedIn = true;
            _sessionStartTime = _parseUtcToLocal(status['session_start_time']);
            _sessionDuration = Duration.zero;
          });

          _startSessionTimer();
        } else {
          setState(() {
            _isClockedIn = true;
            _sessionStartTime =
                DateTime.now(); // Fallback if status not available
            _sessionDuration = Duration.zero;
          });
          _startSessionTimer();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🟢 Clocked in to "${_selectedTask!.taskName}"'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        _loadTodayData(); // Refresh data - this will update _isClockedIn status
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to clock in'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Clock out from current session
  Future<void> _clockOut() async {
    if (!_isClockedIn) return;

    try {
      final attendanceViewModel =
          provider.Provider.of<AttendanceViewModel>(context, listen: false);
      final success = await attendanceViewModel.clockOut();

      if (success) {
        setState(() {
          _isClockedIn = false;
          _sessionStartTime = null;
          _sessionDuration = Duration.zero;
        });

        _stopSessionTimer();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🔴 Clocked out from "${_selectedTask?.taskName ?? "task"}"'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );

        _loadTodayData(); // Refresh data - this will update _isClockedIn status
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to clock out'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Start session timer using database start time
  void _startSessionTimer() {
    if (_sessionStartTime == null) return;

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _sessionStartTime != null) {
        setState(() {
          // Calculate elapsed time from database start time (like a stopwatch)
          _sessionDuration = DateTime.now().difference(_sessionStartTime!);
        });
      }
    });
  }

  /// Stop session timer
  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
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
  String _formatTime(String timeString) {
    try {
      if (timeString.isEmpty ||
          timeString == 'Not Started' ||
          timeString == 'Ongoing') {
        return timeString == 'Ongoing'
            ? 'Active'
            : (timeString == 'Not Started' ? 'Not Started' : '--:--');
      }

      // Check if already in HH:mm format
      if (RegExp(r'^\d{2}:\d{2}$').hasMatch(timeString)) {
        return timeString;
      }

      // Try parsing as ISO format
      // Only convert to local if explicitly UTC (ends with 'Z') or has timezone offset
      var isoString = timeString;
      if (!isoString.contains('T') && isoString.contains(' ')) {
        isoString = isoString.replaceAll(' ', 'T');
      }

      DateTime time;
      if (isoString.endsWith('Z') ||
          isoString.contains('+') ||
          RegExp(r'-\d{2}:\d{2}$').hasMatch(isoString)) {
        time = DateTime.parse(isoString).toLocal();
      } else {
        time = DateTime.parse(isoString);
      }
      return DateFormat('HH:mm').format(time);
    } catch (e) {
      // If parsing fails, return as is if it looks like a time
      if (timeString.contains(':')) {
        return timeString;
      }
      return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Treat both laptop and desktop as "wide" layout (desktop-style tab bar, wider padding)
    final isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenLoadingOverlay(
        isLoading: _isLoading,
        message: 'Loading reports...',
        child: Column(
          children: [
            // Stack Header and TabBar for desktop overlap effect
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Header (with extra padding at bottom on desktop)
                Column(
                  children: [
                    _buildHeader(isDesktop),
                    if (isDesktop)
                      const SizedBox(height: 20), // Spacer for overlap
                  ],
                ),

                // Tab Bar (Floating Overlap on Desktop)
                if (isDesktop)
                  Transform.translate(
                    offset: const Offset(
                        0, 0), // Adjust if needed, currently header has padding
                    child: _buildTabBar(isDesktop),
                  ),
              ],
            ),

            // Mobile Tab Bar (Standard Layout)
            if (!isDesktop) ...[
              const SizedBox(height: 20),
              _buildTabBar(isDesktop),
            ],

            const SizedBox(height: 20),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Today's Work
                  isDesktop
                      // Remove Top Padding on Desktop Content since TabBar is integrated
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: _buildDesktopWorkSessionLayout(),
                        )
                      : SingleChildScrollView(
                          // ... mobile layout
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDailySummary(isDesktop),
                              const SizedBox(height: 20),
                              _buildTaskWorkToday(isDesktop),
                            ],
                          ),
                        ),

                  // Tab 2: Generate Report (Moved to 2nd position)
                  SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 24 : 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: _buildGenerateReportSection(isDesktop),
                      ),
                    ),
                  ),

                  // Tab 3: Report History (Moved to last position)
                  SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 24 : 12),
                    child: _buildReportHistoryTab(isDesktop),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build desktop work session layout
  Widget _buildDesktopWorkSessionLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Metrics Section (Daily Summary)
          _buildDailySummary(true),
          const SizedBox(height: 32),

          // 2. Task Work Today (Full Width)
          // 2. Task Work Today (Full Width)
          _buildTaskWorkToday(true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return SilkShaderWidget(
      speed: 0.8,
      scale: 1.2,
      color: Theme.of(context).colorScheme.primary,
      noiseIntensity: 1.5,
      child: Container(
        width: double.infinity,
        // Remove margin on desktop for full-width look
        margin: isDesktop
            ? EdgeInsets.zero
            : ResponsiveUtils.getResponsiveMargin(context),
        padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 14,
            vertical: isDesktop
                ? 28
                : 16 // More vertical padding on desktop for the "Hero" feel
            ),
        decoration: BoxDecoration(
          // Sharp corners on desktop, rounded on mobile
          borderRadius:
              isDesktop ? BorderRadius.zero : BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CommonColors.primary.withOpacity(0.3),
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
                // Icon Box
                Container(
                  padding: EdgeInsets.all(isDesktop ? 12 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.analytics_rounded,
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

                // Title Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Work Sessions \u0026 Reports',
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
                      if (!isDesktop) // Show subtitle only on mobile or if needed
                        Text(
                          'and manage work efficiently',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),

                // Refresh Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _loadTodayData,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: 'Refresh Data',
                  ),
                ),
              ],
            ),
            // On Desktop, add extra spacing at bottom to let the TabBar overlap
            if (isDesktop) const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Build tab bar ("Nano Bar")
  Widget _buildTabBar(bool isDesktop) {
    return Center(
      child: Container(
        width: isDesktop ? 600 : null, // Constrain width on desktop
        margin: ResponsiveUtils.getResponsiveMargin(
          context,
          mobile: const EdgeInsets.only(left: 16, top: 0, right: 16, bottom: 0),
          tablet: const EdgeInsets.only(left: 20, top: 0, right: 20, bottom: 0),
          desktop: const EdgeInsets.only(left: 0, top: 0, right: 0, bottom: 0),
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[850]
              : Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                  Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: AnimatedBuilder(
            animation: _tabAnimation,
            builder: (context, child) {
              return TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                indicator: BoxDecoration(
                  gradient: CommonColors.primaryGradient,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: CommonColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                overlayColor: MaterialStateProperty.all(Colors.transparent),
                labelStyle: TextStyle(
                  fontSize: isDesktop ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: isDesktop ? 14 : 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
                tabs: [
                  Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Text("Today's Work"),
                    ),
                  ),
                  Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Text('Generate Report'),
                    ),
                  ),
                  Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Text('Report History'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build session management controls
  Widget _buildSessionManagement(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Management',
            style: TextStyle(
              fontSize: isDesktop ? 20 : 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),

          // Task Selection
          if (_availableTasks.isNotEmpty) ...[
            Text(
              'Select Task',
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Task>(
                  value: _selectedTask,
                  hint: Text(
                    'Choose a task to work on',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                      fontSize: isDesktop ? 16 : 14,
                    ),
                  ),
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  items: _availableTasks.map((Task task) {
                    return DropdownMenuItem<Task>(
                      value: task,
                      child: Text(
                        (task.taskName?.isNotEmpty == true)
                            ? task.taskName!
                            : 'Unnamed Task',
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (Task? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedTask = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                'No tasks available for selection',
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Clock In/Out Controls
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      (_isClockedIn || _selectedTask == null) ? null : _clockIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isClockedIn || _selectedTask == null)
                        ? Theme.of(context).colorScheme.surfaceVariant
                        : Theme.of(context).colorScheme.primary,
                    foregroundColor: (_isClockedIn || _selectedTask == null)
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onPrimary,
                    padding:
                        EdgeInsets.symmetric(vertical: isDesktop ? 16 : 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    _isClockedIn ? 'Already Clocked In' : 'Clock In',
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isClockedIn ? _clockOut : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isClockedIn
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.surfaceVariant,
                    foregroundColor: _isClockedIn
                        ? Theme.of(context).colorScheme.onError
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    padding:
                        EdgeInsets.symmetric(vertical: isDesktop ? 14 : 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    'Clock Out',
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Active Session Display - Show if ANY task is clocked in
          if (_isClockedIn) ...[
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                // Get active task from daily summary (not from selected task)
                // Exclude "Daily Attendance" - it's just attendance, not a work session
                final tasks =
                    _dailySummary?['tasks_for_the_day'] as List<dynamic>? ?? [];
                Map<String, dynamic>? activeTask;

                // Find active task (clock_out_time is null, excluding "Daily Attendance")
                for (final task in tasks) {
                  if (task is Map) {
                    final taskName = task['task_name']?.toString() ?? '';
                    final clockOutTime = task['clock_out_time'];
                    // Exclude "Daily Attendance" from active session
                    if (clockOutTime == null &&
                        taskName.toLowerCase() != 'daily attendance') {
                      activeTask = Map<String, dynamic>.from(task);
                      break;
                    }
                  }
                }

                final activeTaskName =
                    (activeTask != null && activeTask.isNotEmpty)
                        ? (activeTask['task_name']?.toString() ?? 'Active Task')
                        : 'Active Task';

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Active Task',
                            style: TextStyle(
                              fontSize: isDesktop ? 18 : 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Task: $activeTaskName',
                        style: TextStyle(
                          fontSize: isDesktop ? 16 : 14,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Started: ${_sessionStartTime != null ? _formatTime(_sessionStartTime!.toIso8601String()) : '--:--'}',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Duration: ${_formatDurationHHMMSSFromDuration(_sessionDuration)}',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Build daily summary section
  Widget _buildDailySummary(bool isDesktop) {
    if (_dailySummary == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No data available',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    final totalTasksCount =
        (_dailySummary!['tasks_for_the_day'] as List<dynamic>?)?.where((task) {
              final taskName = task['task_name']?.toString() ?? '';
              return taskName.toLowerCase() != 'daily attendance';
            }).length ??
            0;

    final activeTasksCount =
        (_dailySummary!['tasks_for_the_day'] as List<dynamic>?)?.where((task) {
              final taskName = task['task_name']?.toString() ?? '';
              final clockOutTime = task['clock_out_time'];
              return clockOutTime == null &&
                  taskName.toLowerCase() != 'daily attendance';
            }).length ??
            0;

    final totalHoursStr =
        '${(_dailySummary!['total_daily_hours'] ?? 0.0).toStringAsFixed(1)}h';

    // Desktop: Clean Row of Cards (Floating look)
    if (isDesktop) {
      return Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Tasks',
              '$totalTasksCount',
              Icons.schedule,
              Theme.of(context).colorScheme.primary,
              isDesktop,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _buildSummaryCard(
              'Active Tasks',
              '$activeTasksCount',
              Icons.task_alt,
              Theme.of(context).colorScheme.secondary,
              isDesktop,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _buildSummaryCard(
              'Total Hours',
              totalHoursStr,
              Icons.access_time,
              Theme.of(context).colorScheme.tertiary,
              isDesktop,
            ),
          ),
        ],
      );
    }

    // Mobile: Card Container with Title
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Tasks',
                      '$totalTasksCount',
                      Icons.schedule,
                      Theme.of(context).colorScheme.primary,
                      isDesktop,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Active Tasks',
                      '$activeTasksCount',
                      Icons.task_alt,
                      Theme.of(context).colorScheme.secondary,
                      isDesktop,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(
                'Total Hours',
                totalHoursStr,
                Icons.access_time,
                Theme.of(context).colorScheme.tertiary,
                isDesktop,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build summary card
  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color, bool isDesktop) {
    // Determine gradient based on title
    LinearGradient gradient;
    if (title.contains('Total Tasks')) {
      gradient = const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Modern Blue
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (title.contains('Active Tasks')) {
      gradient = const LinearGradient(
        colors: [Color(0xFFF97316), Color(0xFFEA580C)], // Vibrant Orange
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      gradient = const LinearGradient(
        colors: [Color(0xFFA855F7), Color(0xFF7C3AED)], // Rich Purple
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    // Initialize animation controller for this metric card (only for mobile)
    if (!isDesktop && !_metricAnimationControllers.containsKey(title)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      final animation = CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      );
      _metricAnimationControllers[title] = controller;
      _metricAnimations[title] = animation;
    }

    final animation = !isDesktop && _metricAnimations.containsKey(title)
        ? _metricAnimations[title]!
        : null;
    final animationController =
        !isDesktop && _metricAnimationControllers.containsKey(title)
            ? _metricAnimationControllers[title]!
            : null;

    // Base accent color for shadows and decorations
    final Color accentColor = gradient.colors.first;

    Widget cardContent = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.4),
            blurRadius: 25,
            spreadRadius: -5,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Simplified Organic Decorative Shape
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Content Container
            Container(
              padding: EdgeInsets.all(isDesktop ? 24 : 16),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isDesktop ? 36 : 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: isDesktop ? 16 : 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: isDesktop ? 13 : 11,
                            color: Colors.white.withOpacity(0.95),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Mobile Animation Wrapper
    if (!isDesktop && animation != null && animationController != null) {
      return GestureDetector(
        onLongPress: () {
          HapticFeedback.lightImpact();
        },
        onVerticalDragEnd: (details) {
          if (details.velocity.pixelsPerSecond.dy < -500) {
            HapticFeedback.mediumImpact();
            animationController.forward().then((_) {
              animationController.reverse();
            });
          }
        },
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -10 * animation.value),
              child: child,
            );
          },
          child: cardContent,
        ),
      );
    }

    // Desktop Hover Effect Wrapper (Simple Scale)
    if (isDesktop) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: cardContent,
      );
    }

    return cardContent;
  }

  /// Build task work today section
  Widget _buildTaskWorkToday(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Work Today',
            style: TextStyle(
              fontSize: isDesktop ? 20 : 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              // Filter out "Daily Attendance" tasks
              final workTasks = _dailySummary == null
                  ? <dynamic>[]
                  : (_dailySummary!['tasks_for_the_day'] as List<dynamic>?)
                          ?.where((task) {
                        final taskName = task['task_name']?.toString() ?? '';
                        // Filter out "Daily Attendance" - it's just attendance tracking
                        return taskName.toLowerCase() != 'daily attendance';
                      }).toList() ??
                      <dynamic>[];

              if (workTasks.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.work_outline,
                          size: 32,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No work today',
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Clock in to start tracking your work',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Tasks List - Exclude "Daily Attendance" as it's not a work task
              return Column(
                children: workTasks.map((task) {
                  return _buildTaskCardFromSummary(
                    task,
                    isDesktop,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Get real task status from task assignment data
  String _getRealTaskStatusFromTask(Map<String, dynamic> task) {
    // Check if task has assignment status information
    final assignmentStatus = task['assignment_status'];
    final isAccepted = task['is_accepted'] ?? false;
    final isRejected = task['is_rejected'] ?? false;
    final isDelayed = task['is_delayed'] ?? false;

    // Map numeric status to readable status
    if (assignmentStatus != null) {
      switch (assignmentStatus) {
        case 0:
          return 'New Task';
        case 1:
          return 'Assigned';
        case 2:
          return 'Accepted';
        case 3:
          return 'In Progress';
        case 4:
          return 'Completed';
        case 5:
          return 'Rejected';
        case 6:
          return 'Delayed';
        default:
          return 'Unknown';
      }
    }

    // Fallback to boolean flags
    if (isRejected) return 'Rejected';
    if (isDelayed) return 'Delayed';
    if (isAccepted) return 'Accepted';

    // If no assignment data, fall back to attendance-based status
    final clockOutTime = task['clock_out_time'];
    final isActive = clockOutTime == null;
    return isActive ? 'In Progress' : 'Completed';
  }

  /// Get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'work done':
        return Theme.of(context).colorScheme.secondary;
      case 'in progress':
        return Theme.of(context).colorScheme.tertiary;
      case 'accepted':
        return Colors.blue;
      case 'assigned':
        return Colors.orange;
      case 'new task':
      case 'new':
        return Colors.purple;
      case 'rejected':
        return Colors.red;
      case 'delayed':
        return Colors.amber;
      case 'not started':
        return Colors.grey;
      case 'on hold':
        return Colors.brown;
      case 'cancelled':
        return Colors.red.shade800;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  /// Get status icon
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'work done':
        return Icons.check_circle;
      case 'in progress':
        return Icons.pending;
      case 'accepted':
        return Icons.thumb_up;
      case 'assigned':
        return Icons.assignment;
      case 'new task':
      case 'new':
        return Icons.new_releases;
      case 'rejected':
        return Icons.cancel;
      case 'delayed':
        return Icons.schedule;
      case 'not started':
        return Icons.play_circle_outline;
      case 'on hold':
        return Icons.pause_circle;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info;
    }
  }

  /// Build task card from daily summary data
  /// Build desktop task row
  Widget _buildDesktopTaskRow(Map<String, dynamic> task) {
    final status = _getRealTaskStatusFromTask(task);
    final statusColor = _getStatusColor(status);
    final taskName = task['task_name'] ?? 'Unknown Task';

    // Time & Duration
    final clockInTime = task['clock_in_time'];
    final clockOutTime = task['clock_out_time'];
    String timeRange = '--:--';
    String durationText = '0h 0m';

    if (clockInTime != null) {
      final start = _parseUtcToLocal(clockInTime);
      timeRange = DateFormat('hh:mm a').format(start);
      if (clockOutTime != null) {
        final end = _parseUtcToLocal(clockOutTime);
        timeRange += ' - ${DateFormat('hh:mm a').format(end)}';
        final duration = end.difference(start);
        durationText = '${duration.inHours}h ${duration.inMinutes % 60}m';
      } else {
        timeRange += ' - Ongoing';
        final duration = DateTime.now().difference(start);
        durationText = '${duration.inHours}h ${duration.inMinutes % 60}m';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Status Indicator
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(status),
              size: 20,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 16),

          // 2. Task Name & Notes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taskName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (task['notes'] != null || task['dev_notes'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      (task['notes'] ?? task['dev_notes'] ?? '').toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // 3. Time Range
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  timeRange,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // 4. Duration Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CommonColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              durationText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CommonColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 5. Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build summary card (Mobile Card or Desktop Row Wrapper)
  Widget _buildTaskCardFromSummary(
    Map<String, dynamic> task,
    bool isDesktop,
  ) {
    if (isDesktop) {
      return _buildDesktopTaskRow(task);
    }
    final taskId = task['task_id']?.toString() ?? task['id']?.toString() ?? '';
    final taskName = task['task_name'] ?? 'Unknown Task';
    final clockInTime = task['clock_in_time'];
    final clockOutTime = task['clock_out_time'];
    final workedHours = task['worked_hours'] ?? 0.0;
    final isActive = clockOutTime == null;
    final status = _getRealTaskStatusFromTask(task);

    // Controller key for notes: one per task (all cards for same task share notes)
    final notesKey = taskId.isNotEmpty ? taskId : taskName.toString();
    final notesController = _taskNotesControllers.putIfAbsent(
      notesKey,
      () => TextEditingController(
        text: (task['notes'] ?? task['dev_notes'] ?? '').toString(),
      ),
    );

    // Calculate duration: use workedHours if available, otherwise calculate from times
    double durationHours = workedHours;
    if (durationHours == 0.0 && clockInTime != null) {
      try {
        final clockIn = _parseUtcToLocal(clockInTime);
        final clockOut = clockOutTime != null
            ? _parseUtcToLocal(clockOutTime)
            : DateTime.now();
        final duration = clockOut.difference(clockIn);
        durationHours = duration.inSeconds / 3600.0;
      } catch (e) {
        // If parsing fails, use workedHours (0.0)
        durationHours = workedHours;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Task Header
          Container(
            padding: EdgeInsets.all(isDesktop ? 12 : 10),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    color: Theme.of(context).colorScheme.onPrimary,
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
                          Flexible(
                            child: Text(
                              taskName,
                              style: TextStyle(
                                fontSize: isDesktop ? 20 : 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (task['is_remote_override'] == true) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: task['remote_reason'] ?? 'Remote Work',
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          Colors.deepPurple.withOpacity(0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.wifi_tethering,
                                        size: 12, color: Colors.deepPurple),
                                    const SizedBox(width: 4),
                                    Text(
                                      'REMOTE',
                                      style: TextStyle(
                                        color: Colors.deepPurple,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (task['project_details'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Project: ${task['project_details']['project_name'] ?? 'Unknown'}',
                          style: TextStyle(
                            fontSize: isDesktop ? 14 : 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 16 : 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Task Details
          Container(
            padding: EdgeInsets.all(isDesktop ? 16 : 12),
            child: Column(
              children: [
                // Session Info
                Row(
                  children: [
                    Text(
                      'Task Details',
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _formatDurationHHMMSS(durationHours),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: isDesktop ? 16 : 14,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Session Details
                _buildSessionDetailRow(
                  'Clock In',
                  _formatTime(clockInTime),
                  Icons.login,
                  Theme.of(context).colorScheme.primary,
                  isDesktop,
                ),

                const SizedBox(height: 8),

                if (clockOutTime != null) ...[
                  _buildSessionDetailRow(
                    'Clock Out',
                    _formatTime(clockOutTime),
                    Icons.logout,
                    Theme.of(context).colorScheme.error,
                    isDesktop,
                  ),
                  const SizedBox(height: 8),
                ],

                _buildSessionDetailRow(
                  'Duration',
                  _formatDurationHHMMSS(durationHours),
                  Icons.timer,
                  Theme.of(context).colorScheme.primary,
                  isDesktop,
                ),

                if (isActive) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Active Task',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Task Notes input on the report screen
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Task Notes',
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add notes for this task (optional)...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
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

  /// Build session detail row
  Widget _buildSessionDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDesktop,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color.withOpacity(0.7)),
        SizedBox(width: isDesktop ? 12 : 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// Build generate report section
  Widget _buildGenerateReportSection(bool isDesktop) {
    if (_dailySummary == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: const EmptyStateWidget(
          title: 'No report data available yet',
          subtitle: 'Complete some tasks or attendance to generate a report.',
          size: 200,
        ),
      );
    }

    final today = DateTime.now();
    final tasks = _dailySummary!['tasks_for_the_day'] as List<dynamic>? ?? [];
    final totalHours = _dailySummary!['total_daily_hours'] ?? 0.0;

    // Attach per-task notes from the report screen into the preview tasks
    for (final record in tasks) {
      if (record is Map<String, dynamic>) {
        final taskId = record['task_id']?.toString() ?? '';
        final taskName = record['task_name']?.toString() ?? '';
        final notesKey = taskId.isNotEmpty ? taskId : taskName;

        final controller = _taskNotesControllers[notesKey];
        if (controller != null && controller.text.trim().isNotEmpty) {
          record['dev_notes'] = controller.text.trim();
        }
      }
    }

    // Group tasks by task name and consolidate sessions
    final Map<String, Map<String, dynamic>> consolidatedTasks = {};

    for (final task in tasks) {
      final taskName = task['task_name'] ?? 'Unknown Task';
      final taskDescription = task['task_description'] ?? '';
      final workedHours = task['worked_hours'] ?? 0.0;
      final clockInTime = task['clock_in_time'];
      final clockOutTime = task['clock_out_time'];
      final isActive = clockOutTime == null;
      final devNotes = task['dev_notes']?.toString();
      final notesKey = (task['task_id']?.toString() ?? '').isNotEmpty
          ? task['task_id'].toString()
          : taskName;

      if (!consolidatedTasks.containsKey(taskName)) {
        consolidatedTasks[taskName] = {
          'task_name': taskName,
          'task_description': taskDescription,
          'total_hours': 0.0,
          'sessions_count': 0,
          'first_clock_in': clockInTime,
          'last_clock_out': clockOutTime,
          'is_active': isActive,
          'dev_notes_list': <String>[],
          'notes_key': notesKey,
        };
      } else {
        // If task already exists, preserve the first non-empty description
        if (taskDescription.isNotEmpty &&
            (consolidatedTasks[taskName]!['task_description'] as String)
                .isEmpty) {
          consolidatedTasks[taskName]!['task_description'] = taskDescription;
        }
      }

      // Add hours to total
      consolidatedTasks[taskName]!['total_hours'] =
          (consolidatedTasks[taskName]!['total_hours'] as double) + workedHours;
      consolidatedTasks[taskName]!['sessions_count'] =
          (consolidatedTasks[taskName]!['sessions_count'] as int) + 1;

      // Collect dev notes per session
      if (devNotes != null && devNotes.isNotEmpty) {
        (consolidatedTasks[taskName]!['dev_notes_list'] as List<String>)
            .add(devNotes);
      }

      // Update first clock in and last clock out
      if (clockInTime != null) {
        final currentFirst = consolidatedTasks[taskName]!['first_clock_in'];
        if (currentFirst == null || clockInTime.compareTo(currentFirst) < 0) {
          consolidatedTasks[taskName]!['first_clock_in'] = clockInTime;
        }
      }

      if (clockOutTime != null) {
        final currentLast = consolidatedTasks[taskName]!['last_clock_out'];
        if (currentLast == null || clockOutTime.compareTo(currentLast) > 0) {
          consolidatedTasks[taskName]!['last_clock_out'] = clockOutTime;
        }
      }

      // If any session is active, mark task as active
      if (isActive) {
        consolidatedTasks[taskName]!['is_active'] = true;
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // "Paper" Document Container
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 1. Professional Header
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color:
                                Theme.of(context).dividerColor.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DAILY REPORT',
                                    style: TextStyle(
                                      fontSize: 12,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Work Summary',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 32 : 24,
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      letterSpacing: -0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.1),
                                  ),
                                ),
                                child: Text(
                                  'PREVIEW',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Date Row
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy').format(today),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 2. Elegant Metrics
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildPreviewStatCard(
                              'Total Time',
                              _formatDetailedTimeFromHours(totalHours),
                              Icons.access_time_filled_rounded,
                              Theme.of(context).colorScheme.primary,
                              isDesktop,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildPreviewStatCard(
                              'Tasks Completed',
                              '${consolidatedTasks.length}',
                              Icons.check_circle_rounded,
                              Theme.of(context).colorScheme.secondary,
                              isDesktop,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Consolidated Task List
                    Container(
                      padding: const EdgeInsets.only(
                          left: 32, right: 32, bottom: 32),
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withOpacity(0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'ACTIVITY LOG',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.4),
                              ),
                            ),
                          ),
                          if (consolidatedTasks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(40),
                              child: Center(
                                child: Text(
                                  'No activity recorded today',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.4),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...consolidatedTasks.values.map((task) =>
                                _buildPreviewConsolidatedTaskCard(
                                    task, isDesktop)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Action Area (Floating outside the paper)
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _dailySummary != null ? _generateAndSubmitReport : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    elevation: 4,
                    shadowColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.send_rounded, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Confirm & Submit Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Please review your report before submitting. Changes cannot be made after submission.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build preview stat card (Tile Style)
  Widget _buildPreviewStatCard(
      String title, String value, IconData icon, Color color, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build preview consolidated task card
  Widget _buildPreviewConsolidatedTaskCard(
      Map<String, dynamic> task, bool isDesktop) {
    final taskName = task['task_name'] ?? 'Unknown Task';
    final taskDescription = task['task_description'] ?? '';
    final totalHours = task['total_hours'] ?? 0.0;
    final sessionsCount = task['sessions_count'] ?? 0;
    final firstClockIn = task['first_clock_in'];
    final lastClockOut = task['last_clock_out'];
    final isActive = task['is_active'] ?? false;
    final status = _getRealTaskStatusFromTask(task);
    final statusColor = _getStatusColor(status);
    final List<dynamic>? devNotesListDynamic =
        task['dev_notes_list'] as List<dynamic>?;
    // Make notes unique and clean
    final devNotesList = devNotesListDynamic
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet() // remove duplicates
            .toList() ??
        const <String>[];

    // Convert hours to detailed time format (hours, minutes, seconds)
    final totalSeconds = (totalHours * 3600).round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    // Calculate average per session with detailed time
    final avgSeconds =
        sessionsCount > 0 ? (totalSeconds / sessionsCount).round() : 0;
    final avgHours = avgSeconds ~/ 3600;
    final avgMinutes = (avgSeconds % 3600) ~/ 60;
    final avgSecs = avgSeconds % 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
          bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      taskName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (taskDescription.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    taskDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final notesKey = task['notes_key']?.toString();
                    if (notesKey == null) return const SizedBox.shrink();

                    if (!_taskNotesControllers.containsKey(notesKey)) {
                      String initialText = '';
                      if (devNotesList.isNotEmpty) {
                        initialText = devNotesList.join('\n');
                      }
                      _taskNotesControllers[notesKey] =
                          TextEditingController(text: initialText);
                    }

                    return TextField(
                      controller: _taskNotesControllers[notesKey],
                      maxLines: null,
                      minLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        hintText: 'Add notes...',
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(
                          Icons.edit_note_rounded,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDetailedTime(hours, minutes, seconds),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Monospace',
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.login,
                      size: 12, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    firstClockIn != null ? _formatTime(firstClockIn) : '--:--',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Format detailed time with hours, minutes, and seconds
  String _formatDetailedTime(int hours, int minutes, int seconds) {
    if (hours > 0) {
      if (minutes > 0) {
        if (seconds > 0) {
          return '${hours}h ${minutes}m ${seconds}s';
        } else {
          return '${hours}h ${minutes}m';
        }
      } else if (seconds > 0) {
        return '${hours}h ${seconds}s';
      } else {
        return '${hours}h';
      }
    } else if (minutes > 0) {
      if (seconds > 0) {
        return '${minutes}m ${seconds}s';
      } else {
        return '${minutes}m';
      }
    } else if (seconds > 0) {
      return '${seconds}s';
    } else {
      return '0s';
    }
  }

  /// Format detailed time from hours (decimal)
  String _formatDetailedTimeFromHours(double totalHours) {
    final totalSeconds = (totalHours * 3600).round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return _formatDetailedTime(hours, minutes, seconds);
  }

  /// Format duration in hh:mm:ss format
  String _formatDurationHHMMSS(double hours) {
    final totalSeconds = (hours * 3600).round();
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Format duration from Duration object in hh:mm:ss format
  String _formatDurationHHMMSSFromDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final s = duration.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Generate and submit daily report
  Future<void> _generateAndSubmitReport() async {
    if (_dailySummary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data available to generate report'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // VALIDATION: Check if daily attendance is clocked out - REQUIRED before generating report
    // This check MUST happen BEFORE showing loading dialog
    final tasks = _dailySummary!['tasks_for_the_day'] as List<dynamic>? ?? [];
    bool hasDailyAttendance = false;
    bool dailyAttendanceClockedOut = false;

    debugPrint('🔍 Checking Daily Attendance status...');
    debugPrint('📊 Total tasks: ${tasks.length}');

    for (final task in tasks) {
      if (task is Map) {
        final taskName = task['task_name']?.toString() ?? '';
        debugPrint('📝 Task: $taskName');
        if (taskName.toLowerCase() == 'daily attendance') {
          hasDailyAttendance = true;
          final clockOutTime = task['clock_out_time'];
          // Check if clock_out_time is not null and not empty
          dailyAttendanceClockedOut = clockOutTime != null &&
              clockOutTime.toString().isNotEmpty &&
              clockOutTime.toString().toLowerCase() != 'null';
          debugPrint(
              '🔍 Daily Attendance found: hasDailyAttendance=$hasDailyAttendance, clockOutTime=$clockOutTime, clockedOut=$dailyAttendanceClockedOut');
          break;
        }
      }
    }

    // If Daily Attendance exists, it MUST be clocked out to generate report
    // Note: We only check the Daily Attendance task's clock_out_time directly,
    // not daily_end_time from summary, as daily_end_time can be set by other tasks
    if (hasDailyAttendance && !dailyAttendanceClockedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '⚠️ Please clock out from Daily Attendance before generating the report'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return;
    }

    BuildContext? dialogContext;
    try {
      setState(() => _isLoading = true);

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          dialogContext = context;
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Generating and submitting daily report...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        },
      );

      // Generate and submit report using task_card_time_tracking data (same as preview)
      final reportService = ReportService();
      final authViewModel =
          provider.Provider.of<AuthViewModel>(context, listen: false);

      debugPrint(
          '🔍 Generating daily report from task_card_time_tracking data...');
      debugPrint(
          '📊 Today\'s tasks: ${(_dailySummary!['tasks_for_the_day'] as List<dynamic>?)?.length ?? 0}');

      // Generate report from task_card_time_tracking data (same source as preview)
      // Attach per-task notes from the report screen into the tracking records
      final List<dynamic> trackingRecords =
          _dailySummary!['tasks_for_the_day'] as List<dynamic>? ?? [];

      for (final record in trackingRecords) {
        if (record is Map<String, dynamic>) {
          final taskId = record['task_id']?.toString() ?? '';
          final taskName = record['task_name']?.toString() ?? '';
          final notesKey = taskId.isNotEmpty ? taskId : taskName;

          final controller = _taskNotesControllers[notesKey];
          if (controller != null && controller.text.trim().isNotEmpty) {
            // store under dev_notes so ReportService can use it for TaskReport.notes
            record['dev_notes'] = controller.text.trim();
          }
        }
      }

      // Add timeout to prevent infinite loading
      final report = await reportService
          .generateDailyReportFromTaskTracking(
        authViewModel,
        trackingRecords,
        totalDailyHours: _dailySummary!['total_daily_hours'] ?? 0.0,
        additionalNotes: null, // no overall notes, only per-task notes
        dailyStartTime: _dailySummary!['daily_start_time'] as String?,
        dailyEndTime: _dailySummary!['daily_end_time'] as String?,
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('❌ Report generation timed out after 30 seconds');
          throw TimeoutException(
              'Report generation timed out. Please try again.');
        },
      );

      debugPrint(
          '📄 Report generated: ${report != null ? "SUCCESS" : "FAILED"}');
      if (report != null) {
        debugPrint(
            '📊 Report details: ${report.reportId} - ${report.reportDate}');
        debugPrint(
            '📝 Report additional notes: ${report.additionalNotes ?? "No notes"}');
      }

      if (report != null) {
        debugPrint(
            '📄 Report generated successfully, now submitting to database...');

        // Submit the report to database with timeout
        final submissionSuccess =
            await reportService.submitDailyReportToAdmin(report).timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            debugPrint('❌ Report submission timed out after 60 seconds');
            return false;
          },
        );

        // Close loading dialog
        if (dialogContext != null && Navigator.canPop(dialogContext!)) {
          Navigator.of(dialogContext!).pop();
          dialogContext = null;
        }

        if (submissionSuccess) {
          debugPrint('✅ Report submitted to database successfully');

          // Clear notes after successful submission
          _reportNotesController?.clear();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('✅ Daily report generated and submitted successfully!'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              duration: Duration(seconds: 4),
            ),
          );

          // Refresh data
          _loadTodayData();
          _loadReportHistory(); // Refresh report history
        } else {
          debugPrint('❌ Report submission to database failed');

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '⚠️ Report generated but failed to save to database. Please try again.'),
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        // Close loading dialog
        if (dialogContext != null && Navigator.canPop(dialogContext!)) {
          Navigator.of(dialogContext!).pop();
          dialogContext = null;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to generate and submit report'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } on TimeoutException catch (e) {
      // Close loading dialog if still open
      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
        Navigator.of(dialogContext!).pop();
        dialogContext = null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏱️ ${e.message}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
        Navigator.of(dialogContext!).pop();
        dialogContext = null;
      } else if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      debugPrint('❌ Error generating report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      // Ensure dialog is closed
      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
        Navigator.of(dialogContext!).pop();
      }
      setState(() => _isLoading = false);
    }
  }

  /// Load report history
  Future<void> _loadReportHistory() async {
    try {
      final reportViewModel =
          provider.Provider.of<ReportViewModel>(context, listen: false);
      await reportViewModel.loadReportHistory(refresh: true);
    } catch (e) {
      debugPrint('Error loading report history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading report history: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // ============= Date Filter Helper Methods =============

  /// Build a reusable date filter chip
  Widget _buildDateFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Theme.of(context).cardColor,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
    );
  }

  /// Check if current date range is "Today"
  bool _isDateRangeToday() {
    final range = _reportViewModel.historyDateRange;
    if (range == null) return false;
    final today = DateTime.now();
    return range.start.year == today.year &&
        range.start.month == today.month &&
        range.start.day == today.day &&
        range.end.year == today.year &&
        range.end.month == today.month &&
        range.end.day == today.day;
  }

  /// Check if current date range is "This Week"
  bool _isDateRangeThisWeek() {
    final range = _reportViewModel.historyDateRange;
    if (range == null) return false;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return range.start.year == startOfWeek.year &&
        range.start.month == startOfWeek.month &&
        range.start.day == startOfWeek.day &&
        range.duration.inDays == 6;
  }

  /// Check if current date range is "This Month"
  bool _isDateRangeThisMonth() {
    final range = _reportViewModel.historyDateRange;
    if (range == null) return false;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    return range.start.year == startOfMonth.year &&
        range.start.month == startOfMonth.month &&
        range.start.day == startOfMonth.day &&
        range.end.day == endOfMonth.day;
  }

  /// Check if current date range is a custom selection (not a preset)
  bool _isCustomDateRange() {
    final range = _reportViewModel.historyDateRange;
    if (range == null) return false;
    return !_isDateRangeToday() &&
        !_isDateRangeThisWeek() &&
        !_isDateRangeThisMonth();
  }

  /// Build report history tab
  Widget _buildReportHistoryTab(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'Report History',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // History Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // All Time
              _buildDateFilterChip(
                label: 'All Time',
                isSelected: _reportViewModel.historyDateRange == null,
                onTap: () => _reportViewModelRead.setHistoryDateRange(null),
              ),
              const SizedBox(width: 8),
              // Today
              _buildDateFilterChip(
                label: 'Today',
                isSelected: _isDateRangeToday(),
                onTap: () {
                  final today = DateTime.now();
                  final startOfDay =
                      DateTime(today.year, today.month, today.day);
                  final endOfDay =
                      DateTime(today.year, today.month, today.day, 23, 59, 59);
                  _reportViewModelRead.setHistoryDateRange(
                      DateTimeRange(start: startOfDay, end: endOfDay));
                },
              ),
              const SizedBox(width: 8),
              // This Week
              _buildDateFilterChip(
                label: 'This Week',
                isSelected: _isDateRangeThisWeek(),
                onTap: () {
                  final now = DateTime.now();
                  final startOfWeek =
                      now.subtract(Duration(days: now.weekday - 1));
                  final endOfWeek = startOfWeek.add(const Duration(days: 6));
                  _reportViewModelRead.setHistoryDateRange(DateTimeRange(
                    start: DateTime(
                        startOfWeek.year, startOfWeek.month, startOfWeek.day),
                    end: DateTime(endOfWeek.year, endOfWeek.month,
                        endOfWeek.day, 23, 59, 59),
                  ));
                },
              ),
              const SizedBox(width: 8),
              // This Month
              _buildDateFilterChip(
                label: 'This Month',
                isSelected: _isDateRangeThisMonth(),
                onTap: () {
                  final now = DateTime.now();
                  final startOfMonth = DateTime(now.year, now.month, 1);
                  final endOfMonth =
                      DateTime(now.year, now.month + 1, 0, 23, 59, 59);
                  _reportViewModelRead.setHistoryDateRange(
                      DateTimeRange(start: startOfMonth, end: endOfMonth));
                },
              ),
              const SizedBox(width: 8),
              // Custom Date Range
              ActionChip(
                label: Text(_isCustomDateRange()
                    ? '${DateFormat('MMM dd').format(_reportViewModel.historyDateRange!.start)} - ${DateFormat('MMM dd').format(_reportViewModel.historyDateRange!.end)}'
                    : 'Custom'),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now(),
                    initialDateRange: _reportViewModel.historyDateRange,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                                primary: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    final startOfDay = picked.start;
                    final endOfDay = DateTime(
                      picked.end.year,
                      picked.end.month,
                      picked.end.day,
                      23,
                      59,
                      59,
                    );
                    _reportViewModelRead.setHistoryDateRange(
                        DateTimeRange(start: startOfDay, end: endOfDay));
                  }
                },
                avatar: const Icon(Icons.date_range, size: 16),
                backgroundColor: _isCustomDateRange()
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).cardColor,
                labelStyle: TextStyle(
                  color: _isCustomDateRange()
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Reports List
        if (_isLoadingHistory && _reportHistory.isEmpty) ...[
          const Center(child: CircularProgressIndicator()),
        ] else if (_reportHistory.isEmpty) ...[
          Container(
            height: 350,
            child: const EmptyStateWidget(
              title: 'No reports found',
              subtitle: 'Try adjusting your filters or generate a new report',
            ),
          ),
        ] else ...[
          Text(
            'Recent Reports',
            style: TextStyle(
              fontSize: isDesktop ? 20 : 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // List with Pagination
          NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (!_reportViewModelRead.isLoadingMoreHistory &&
                  _reportViewModelRead.hasMoreHistory &&
                  scrollInfo.metrics.pixels ==
                      scrollInfo.metrics.maxScrollExtent) {
                _reportViewModelRead.loadMoreHistory();
              }
              return false;
            },
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reportHistory.length +
                  (_reportViewModel.hasMoreHistory ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _reportHistory.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _buildReportHistoryCard(
                    _reportHistory[index], isDesktop);
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Build report history card
  /// Build report history card
  Widget _buildReportHistoryCard(Map<String, dynamic> report, bool isDesktop) {
    final status = report['status'] as String;
    final statusColor = _getStatusColor(status);

    // Format the submitted date
    String formattedDate = 'N/A';
    try {
      if (report['submitted_at'] != null &&
          report['submitted_at'].toString().isNotEmpty) {
        final date = _parseUtcToLocal(report['submitted_at'].toString());
        formattedDate = DateFormat('MMM dd, yyyy HH:mm').format(date);
      }
    } catch (e) {
      formattedDate = 'Invalid Date';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (report['tasks'] != null) {
              _showTaskSummary(
                report['tasks'] is List
                    ? List<Map<String, dynamic>>.from(report['tasks'])
                    : [],
                report['date'],
                (report['total_hours'] is int)
                    ? (report['total_hours'] as int).toDouble()
                    : (report['total_hours'] as double),
                isDesktop,
                additionalNotes: report['additional_notes'] as String?,
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report['date'] ?? 'Unknown Date',
                            style: TextStyle(
                              fontSize: isDesktop ? 18 : 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Submitted on $formattedDate',
                            style: TextStyle(
                              fontSize: isDesktop ? 12 : 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Divider
                Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
                const SizedBox(height: 20),
                // Metrics Row
                Row(
                  children: [
                    _buildHistoryMetric(
                      context,
                      isDesktop,
                      Icons.access_time_filled_rounded,
                      '${(report['total_hours'] ?? 0).toStringAsFixed(1)}h',
                      'Total Time',
                      Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 24),
                    _buildHistoryMetric(
                      context,
                      isDesktop,
                      Icons.check_circle_rounded,
                      '${report['tasks_count'] ?? 0}',
                      'Tasks',
                      Colors.green,
                    ),
                    const Spacer(),
                    Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
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

  Widget _buildHistoryMetric(BuildContext context, bool isDesktop,
      IconData icon, String value, String label, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: color.withOpacity(0.8),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Show task summary dialog
  void _showTaskSummary(List<Map<String, dynamic>> tasks, String date,
      double totalHours, bool isDesktop,
      {String? additionalNotes}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.all(isDesktop ? 40 : 16),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 700,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // --- Header Section ---
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            size: 28,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DAILY REPORT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.8),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize: isDesktop ? 22 : 18,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),

                  // --- Scrollable Content ---
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Metrics Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailMetricCard(
                                  context,
                                  'Total Time',
                                  '${totalHours.toStringAsFixed(1)}h',
                                  Icons.access_time_filled,
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDetailMetricCard(
                                  context,
                                  'Tasks Completed',
                                  '${tasks.length}',
                                  Icons.check_circle,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          Text(
                            'TASK TIMELINE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Task List (Using existing card for detailed view)
                          if (tasks.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  'No specific tasks recorded for this report.',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5),
                                  ),
                                ),
                              ),
                            )
                          else
                            ...tasks
                                .map((task) =>
                                    _buildTaskSummaryCard(task, isDesktop))
                                .toList(),

                          // Additional Notes Section
                          if (additionalNotes != null &&
                              additionalNotes.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              'ADDITIONAL NOTES',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant
                                    .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                additionalNotes,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // --- Footer Actions ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailMetricCard(BuildContext context, String title,
      String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build task summary card for dialog
  Widget _buildTaskSummaryCard(Map<String, dynamic> task, bool isDesktop) {
    // Extract task information with better fallbacks
    final taskName = task['task_name'] as String?;
    final taskId = task['task_id'] as String?;
    final taskDescription = task['task_description'] as String?;
    final totalDuration = task['total_duration'] ?? 0.0;
    final sessionsCount = task['sessions_count'] ?? 0;

    // Get clock in/out times from task data
    final startTime = task['start_time'] as String?;
    final endTime = task['end_time'] as String?;
    final workedHours = task['worked_hours'] as double? ?? totalDuration;
    final notes = task['notes'] as String?;
    final devNotes = task['dev_notes'] as String?;

    // Determine display name with better fallback logic
    String displayName;
    bool isUnknownTask = false;

    if (taskName != null &&
        taskName.isNotEmpty &&
        taskName.toLowerCase() != 'null') {
      displayName = taskName;
    } else if (taskId != null && taskId.isNotEmpty) {
      displayName =
          'Task #${taskId.substring(0, taskId.length > 8 ? 8 : taskId.length)}';
      isUnknownTask = true;
    } else {
      displayName = 'Unnamed Task';
      isUnknownTask = true;
    }

    // Check if this is Daily Attendance
    final isDailyAttendance = displayName.toLowerCase() == 'daily attendance';

    // Determine description with fallback
    String displayDescription;
    if (taskDescription != null &&
        taskDescription.isNotEmpty &&
        taskDescription.toLowerCase() != 'null') {
      displayDescription = taskDescription;
    } else if (isUnknownTask && taskId != null) {
      displayDescription = 'Task ID: $taskId';
    } else {
      displayDescription = 'No description available';
    }

    // Calculate duration - use worked_hours if available, otherwise calculate from times
    double displayDuration = workedHours > 0 ? workedHours : totalDuration;
    if (displayDuration == 0.0 &&
        startTime != null &&
        startTime != 'Not Started' &&
        endTime != null &&
        endTime != 'Ongoing') {
      try {
        final start = _parseUtcToLocal(startTime);
        final end = _parseUtcToLocal(endTime);
        final duration = end.difference(start);
        displayDuration = duration.inSeconds / 3600.0;
      } catch (e) {
        // If parsing fails, use workedHours or totalDuration
        displayDuration = workedHours > 0 ? workedHours : totalDuration;
      }
    }

    // Determine if task was actually worked on
    final hasTimeData = startTime != null && startTime != 'Not Started';

    // Combine notes for display
    final displayNotes = devNotes ?? notes;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: isDailyAttendance
            ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3)
            : isUnknownTask
                ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.1)
                : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isDailyAttendance
            ? Border.all(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.5),
                width: 2,
              )
            : isUnknownTask
                ? Border.all(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                    width: 1.5,
                  )
                : Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
        boxShadow: [
          BoxShadow(
            color: isDailyAttendance
                ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
                : Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task Header
          Row(
            children: [
              // Icon for Daily Attendance or Unknown Task
              if (isDailyAttendance || isUnknownTask) ...[
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDailyAttendance
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDailyAttendance ? Icons.access_time : Icons.help_outline,
                    color: isDailyAttendance
                        ? Theme.of(context).colorScheme.onSecondary
                        : Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: isDailyAttendance
                            ? Theme.of(context).colorScheme.secondary
                            : isUnknownTask
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (displayDescription.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        displayDescription,
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                          fontStyle: isUnknownTask
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDailyAttendance
                      ? Theme.of(context).colorScheme.secondary
                      : isUnknownTask
                          ? Theme.of(context).colorScheme.error.withOpacity(0.8)
                          : Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  displayDuration > 0
                      ? _formatDetailedTimeFromHours(displayDuration)
                      : '0s',
                  style: TextStyle(
                    color: isDailyAttendance || isUnknownTask
                        ? Colors.white
                        : Theme.of(context).colorScheme.onPrimary,
                    fontSize: isDesktop ? 14 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Clock In/Out Times Section - Different styling for Daily Attendance
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDailyAttendance
                  ? Theme.of(context).colorScheme.secondary.withOpacity(0.1)
                  : isUnknownTask
                      ? Theme.of(context).colorScheme.error.withOpacity(0.05)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDailyAttendance
                    ? Theme.of(context).colorScheme.secondary.withOpacity(0.3)
                    : isUnknownTask
                        ? Theme.of(context).colorScheme.error.withOpacity(0.2)
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isDailyAttendance
                          ? Icons.person
                          : isUnknownTask
                              ? Icons.warning_amber_rounded
                              : Icons.task,
                      size: 16,
                      color: isDailyAttendance
                          ? Theme.of(context).colorScheme.secondary
                          : isUnknownTask
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      isDailyAttendance
                          ? 'Employee Attendance'
                          : isUnknownTask
                              ? 'Task Timing (Missing Details)'
                              : 'Task Timing',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 12,
                        fontWeight: FontWeight.w600,
                        color: isDailyAttendance
                            ? Theme.of(context).colorScheme.secondary
                            : isUnknownTask
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeDetail(
                        'Clock In',
                        hasTimeData ? _formatTime(startTime) : 'Not Started',
                        Icons.login,
                        isDailyAttendance
                            ? Theme.of(context).colorScheme.secondary
                            : isUnknownTask
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                        isDesktop,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTimeDetail(
                        'Clock Out',
                        endTime != null && endTime != 'Ongoing'
                            ? _formatTime(endTime)
                            : (endTime == 'Ongoing'
                                ? 'Active'
                                : 'Not Completed'),
                        Icons.logout,
                        endTime != null && endTime != 'Ongoing'
                            ? Theme.of(context).colorScheme.error
                            : (isDailyAttendance
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.primary),
                        isDesktop,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!isDailyAttendance) ...[],

          // Task Stats
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        displayDuration > 0
                            ? _formatDetailedTimeFromHours(displayDuration)
                            : '0s',
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Total Duration',
                        style: TextStyle(
                          fontSize: isDesktop ? 12 : 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isDailyAttendance) ...[
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$sessionsCount',
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          'Times',
                          style: TextStyle(
                            fontSize: isDesktop ? 12 : 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          sessionsCount > 0 && displayDuration > 0
                              ? _formatDetailedTimeFromHours(
                                  displayDuration / sessionsCount)
                              : '0s',
                          style: TextStyle(
                            fontSize: isDesktop ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          'Avg/Time',
                          style: TextStyle(
                            fontSize: isDesktop ? 12 : 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Notes Section
          if (displayNotes != null && displayNotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.note_alt_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayNotes,
                    style: TextStyle(
                      fontSize: isDesktop ? 13 : 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build time detail widget for clock in/out display
  Widget _buildTimeDetail(
    String label,
    String time,
    IconData icon,
    Color color,
    bool isDesktop,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: isDesktop ? 12 : 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            time,
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
