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
import '../../widgets/common/empty_state_widget.dart';

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
    final isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenLoadingOverlay(
        isLoading: _isLoading,
        message: 'Loading reports...',
        child: Column(
          children: [
            _buildHeader(isDesktop),
            const SizedBox(height: 24),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Today's Work
                  isDesktop
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: _buildDesktopWorkSessionLayout(),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDailySummary(isDesktop),
                              const SizedBox(height: 20),
                              _buildTaskWorkToday(isDesktop),
                            ],
                          ),
                        ),

                  // Tab 2: Generate Report
                  SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 24 : 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: _buildGenerateReportSection(isDesktop),
                      ),
                    ),
                  ),

                  // Tab 3: Report History
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
          _buildDailySummary(true),
          const SizedBox(height: 32),
          _buildTaskWorkToday(true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 20,
        vertical: isDesktop ? 24 : 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111321),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E2135),
          width: 1,
        ),
      ),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Work Sessions & Reports',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Manage your daily productivity and generate performance insights.',
                        style: TextStyle(
                          color: Color(0xFF8F93A4),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                _buildTabButtonsRow(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Work Sessions & Reports',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Manage your daily productivity and generate performance insights.',
                  style: TextStyle(
                    color: Color(0xFF8F93A4),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTabButtonsRow(),
              ],
            ),
    );
  }

  Widget _buildTabButtonsRow() {
    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (context, child) {
        final selectedIndex = _tabController.index;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabButton("Today's Work", 0, selectedIndex == 0),
            const SizedBox(width: 8),
            _buildTabButton("Generate Report", 1, selectedIndex == 1),
            const SizedBox(width: 8),
            _buildTabButton("History", 2, selectedIndex == 2),
          ],
        );
      },
    );
  }

  Widget _buildTabButton(String label, int index, bool isActive) {
    return Material(
      color: isActive ? const Color(0xFF3B62FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () {
          setState(() {
            _tabController.animateTo(index);
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF8F93A4),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
        color: const Color(0xFF111321),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E2135),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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
    // Determine colors and border based on title
    Color iconColor;
    Color iconBgColor;
    Color borderColor;
    LinearGradient gradientBg;

    if (title.contains('Total Tasks')) {
      iconColor = const Color(0xFF3A62FF);
      iconBgColor = const Color(0xFF1F2B5E);
      borderColor = const Color(0xFF1E2B5C);
      gradientBg = LinearGradient(
        colors: [
          const Color(0xFF141A33),
          const Color(0xFF13192F).withOpacity(0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (title.contains('Active Tasks')) {
      iconColor = const Color(0xFFF97316);
      iconBgColor = const Color(0xFF4E2C18);
      borderColor = const Color(0xFF5C381E);
      gradientBg = LinearGradient(
        colors: [
          const Color(0xFF281810),
          const Color(0xFF24160F).withOpacity(0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      iconColor = const Color(0xFF8C5CF6);
      iconBgColor = const Color(0xFF351F4E);
      borderColor = const Color(0xFF3E235F);
      gradientBg = LinearGradient(
        colors: [
          const Color(0xFF201430),
          const Color(0xFF1F142E).withOpacity(0.8),
        ],
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

    Widget cardContent = Container(
      decoration: BoxDecoration(
        gradient: gradientBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8F93A4),
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
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111321),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E2135),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Task Work Today',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
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
        color: const Color(0xFF171926),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1E2135),
        ),
      ),
      child: Row(
        children: [
          // 1. Status Indicator
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (task['notes'] != null || task['dev_notes'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      (task['notes'] ?? task['dev_notes'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8F93A4),
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
              color: const Color(0xFF111321),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E2135)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time,
                    size: 14,
                    color: Color(0xFF8F93A4)),
                const SizedBox(width: 8),
                Text(
                  timeRange,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8F93A4),
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
              color: const Color(0xFF3B62FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3B62FF).withOpacity(0.3)),
            ),
            child: Text(
              durationText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3B62FF),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 5. Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: statusColor,
                letterSpacing: 0.5,
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
    final statusColor = _getStatusColor(status);

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
        color: const Color(0xFF171926),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E2135),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Task Header
          Container(
            padding: EdgeInsets.all(isDesktop ? 12 : 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E2135),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getStatusIcon(status),
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
                          Flexible(
                            child: Text(
                              taskName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                                  color: Colors.deepPurple.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          Colors.deepPurple.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.wifi_tethering,
                                        size: 12, color: Colors.deepPurple),
                                    SizedBox(width: 4),
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8F93A4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.5,
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
                    const Text(
                      'Task Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B62FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF3B62FF).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _formatDurationHHMMSS(durationHours),
                        style: const TextStyle(
                          color: Color(0xFF3B62FF),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
                  const Color(0xFF3B62FF),
                  isDesktop,
                ),

                const SizedBox(height: 8),

                if (clockOutTime != null) ...[
                  _buildSessionDetailRow(
                    'Clock Out',
                    _formatTime(clockOutTime),
                    Icons.logout,
                    const Color(0xFFEF4444),
                    isDesktop,
                  ),
                  const SizedBox(height: 8),
                ],

                _buildSessionDetailRow(
                  'Duration',
                  _formatDurationHHMMSS(durationHours),
                  Icons.timer,
                  const Color(0xFF3B62FF),
                  isDesktop,
                ),

                if (isActive) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B62FF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF3B62FF).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B62FF),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Active Task',
                          style: TextStyle(
                            color: Color(0xFF3B62FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Task Notes input on the report screen
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'TASK NOTES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8F93A4),
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_box_outline_blank_rounded,
                        size: 16,
                        color: Color(0xFF8F93A4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: notesController,
                        maxLines: null,
                        minLines: 1,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8F93A4),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Add notes for this task (optional)...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A4E61),
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
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
          color: const Color(0xFF111321),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF1E2135),
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
          'workflow_status': task['workflow_status'],
          'task_id': task['task_id'],
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
              // 1. Daily Report Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111321),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1E2135),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header of the card
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DAILY REPORT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3A62FF),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Work Summary',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: Color(0xFF8F93A4),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('EEEE, MMMM d, yyyy').format(today),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF8F93A4),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Preview Button
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF2C2F48),
                                width: 1.5,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  // Preview action: could open a preview dialog or trigger existing preview logic
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.visibility_outlined,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Preview',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Metrics Grid (Row of 2)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        children: [
                          // Total Time
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF141A33),
                                    const Color(0xFF13192F).withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF1E2B5C),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1F2B5E),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.access_time,
                                      color: Color(0xFF3A62FF),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _formatDetailedTimeFromHours(totalHours),
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Total Time',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8F93A4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Tasks Completed
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF201430),
                                    const Color(0xFF1F142E).withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF3E235F),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF351F4E),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.done,
                                      color: Color(0xFF8C5CF6),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    '${consolidatedTasks.length}',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Tasks Completed',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8F93A4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Activity Log Header
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'ACTIVITY LOG',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8F93A4),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Timeline + Task Log List
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: consolidatedTasks.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  'No activity recorded today',
                                  style: TextStyle(
                                    color: Color(0xFF8F93A4),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: consolidatedTasks.length,
                              itemBuilder: (context, index) {
                                final task = consolidatedTasks.values.elementAt(index);
                                return _buildTimelineItem(task, index == consolidatedTasks.length - 1);
                              },
                            ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Confirm & Submit Button
              Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B62FF), Color(0xFF615EFC)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B62FF).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed:
                      _dailySummary != null ? _generateAndSubmitReport : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
              const Center(
                child: Text(
                  'Please review your report before submitting. Changes cannot be made after submission.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8F93A4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> task, bool isLast) {
    final taskName = task['task_name'] ?? 'Unknown Task';
    final totalHours = task['total_hours'] ?? 0.0;
    final firstClockIn = task['first_clock_in'];
    final status = _getRealTaskStatusFromTask(task);
    
    // Status colors
    Color statusColor;
    if (status.toLowerCase().contains('progress')) {
      statusColor = const Color(0xFF3A62FF);
    } else if (status.toLowerCase().contains('completed') || status.toLowerCase().contains('done')) {
      statusColor = const Color(0xFF22C55E);
    } else {
      statusColor = const Color(0xFFE0E0E0);
    }

    final totalSeconds = (totalHours * 3600).round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final durationStr = _formatDetailedTime(hours, minutes, seconds);

    final notesKey = task['notes_key']?.toString() ?? taskName;
    if (!_taskNotesControllers.containsKey(notesKey)) {
      final List<dynamic>? devNotesListDynamic = task['dev_notes_list'] as List<dynamic>?;
      final devNotesList = devNotesListDynamic
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList() ??
          const <String>[];
      _taskNotesControllers[notesKey] = TextEditingController(text: devNotesList.join('\n'));
    }
    final controller = _taskNotesControllers[notesKey]!;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line + dot
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A62FF),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3A62FF).withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFF1E2B5C),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          // Task Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF171926),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1E2135),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Task Title & Status Tag
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                taskName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Worked time + Clock-in Time
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              durationStr,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_filled_rounded,
                                  size: 12,
                                  color: Color(0xFF8F93A4),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  firstClockIn != null ? _formatTime(firstClockIn) : '--:--',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8F93A4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Checkbox icon + editable description
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.check_box_outline_blank_rounded,
                            size: 16,
                            color: Color(0xFF8F93A4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            maxLines: null,
                            minLines: 1,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8F93A4),
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              hintText: 'Enter developer notes here...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF4A4E61),
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
    return Material(
      color: isSelected ? const Color(0xFF3B62FF) : const Color(0xFF171926),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B62FF) : const Color(0xFF1E2135),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF8F93A4),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
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
                fontSize: isDesktop ? 22 : 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
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
              Material(
                color: _isCustomDateRange() ? const Color(0xFF3B62FF) : const Color(0xFF171926),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                      initialDateRange: _reportViewModel.historyDateRange,
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF3B62FF),
                              onPrimary: Colors.white,
                              surface: Color(0xFF111321),
                              onSurface: Colors.white,
                            ),
                            dialogBackgroundColor: const Color(0xFF111321),
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
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isCustomDateRange() ? const Color(0xFF3B62FF) : const Color(0xFF1E2135),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 16,
                          color: _isCustomDateRange() ? Colors.white : const Color(0xFF8F93A4),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isCustomDateRange()
                              ? '${DateFormat('MMM dd').format(_reportViewModel.historyDateRange!.start)} - ${DateFormat('MMM dd').format(_reportViewModel.historyDateRange!.end)}'
                              : 'Custom',
                          style: TextStyle(
                            color: _isCustomDateRange() ? Colors.white : const Color(0xFF8F93A4),
                            fontSize: 13,
                            fontWeight: _isCustomDateRange() ? FontWeight.w600 : FontWeight.w500,
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
          const Text(
            'Recent Reports',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
        color: const Color(0xFF111321),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E2135),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                        color: const Color(0xFF3B62FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Color(0xFF3B62FF),
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
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Submitted on $formattedDate',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8F93A4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
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
                const Divider(
                  height: 1,
                  color: Color(0xFF1E2135),
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
                      const Color(0xFF3B62FF),
                    ),
                    const SizedBox(width: 24),
                    _buildHistoryMetric(
                      context,
                      isDesktop,
                      Icons.check_circle_rounded,
                      '${report['tasks_count'] ?? 0}',
                      'Tasks',
                      const Color(0xFF22C55E),
                    ),
                    const Spacer(),
                    const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B62FF),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Color(0xFF3B62FF),
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
          color: color,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8F93A4),
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
                color: const Color(0xFF111321),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF1E2135),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // --- Header Section ---
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFF1E2135),
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
                            color: const Color(0xFF3B62FF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            size: 28,
                            color: Color(0xFF3B62FF),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DAILY REPORT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3B62FF),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize: isDesktop ? 22 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
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
                                  const Color(0xFF3B62FF),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDetailMetricCard(
                                  context,
                                  'Tasks Completed',
                                  '${tasks.length}',
                                  Icons.check_circle,
                                  const Color(0xFF22C55E),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'TASK TIMELINE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8F93A4),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Task List (Using existing card for detailed view)
                          if (tasks.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text(
                                  'No specific tasks recorded for this report.',
                                  style: TextStyle(
                                    color: Color(0xFF8F93A4),
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
                            const Text(
                              'ADDITIONAL NOTES',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8F93A4),
                                  letterSpacing: 0.8,
                                ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF171926),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF1E2135),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                  additionalNotes,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Color(0xFF8F93A4),
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
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Color(0xFF1E2135),
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
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              color: Color(0xFF8F93A4),
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
    Color iconColor;
    Color iconBgColor;
    Color borderColor;
    LinearGradient gradientBg;

    if (title.contains('Time')) {
      iconColor = const Color(0xFF3A62FF);
      iconBgColor = const Color(0xFF1F2B5E);
      borderColor = const Color(0xFF1E2B5C);
      gradientBg = LinearGradient(
        colors: [
          const Color(0xFF141A33),
          const Color(0xFF13192F).withOpacity(0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      iconColor = const Color(0xFF8C5CF6);
      iconBgColor = const Color(0xFF351F4E);
      borderColor = const Color(0xFF3E235F);
      gradientBg = LinearGradient(
        colors: [
          const Color(0xFF201430),
          const Color(0xFF1F142E).withOpacity(0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradientBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8F93A4),
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
        color: const Color(0xFF171926),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDailyAttendance
              ? const Color(0xFF10B981).withOpacity(0.5)
              : isUnknownTask
                  ? const Color(0xFFEF4444).withOpacity(0.3)
                  : const Color(0xFF1E2135),
          width: isDailyAttendance ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task Header
          Row(
            children: [
              // Icon for Daily Attendance or Unknown Task
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDailyAttendance
                      ? const Color(0xFF102A24)
                      : isUnknownTask
                          ? const Color(0xFF3C181E)
                          : const Color(0xFF1F2B5E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDailyAttendance ? Icons.access_time : (isUnknownTask ? Icons.help_outline : Icons.task),
                  color: isDailyAttendance
                      ? const Color(0xFF10B981)
                      : isUnknownTask
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF3B62FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
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
                            ? const Color(0xFF10B981)
                            : isUnknownTask
                                ? const Color(0xFFEF4444)
                                : Colors.white,
                      ),
                    ),
                    if (displayDescription.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        displayDescription,
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF8F93A4),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDailyAttendance
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : isUnknownTask
                          ? const Color(0xFFEF4444).withOpacity(0.12)
                          : const Color(0xFF3B62FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDailyAttendance
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : isUnknownTask
                            ? const Color(0xFFEF4444).withOpacity(0.3)
                            : const Color(0xFF3B62FF).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  displayDuration > 0
                      ? _formatDetailedTimeFromHours(displayDuration)
                      : '0s',
                  style: TextStyle(
                    color: isDailyAttendance
                        ? const Color(0xFF10B981)
                        : isUnknownTask
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF3B62FF),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111321),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDailyAttendance
                    ? const Color(0xFF10B981).withOpacity(0.3)
                    : isUnknownTask
                        ? const Color(0xFFEF4444).withOpacity(0.3)
                        : const Color(0xFF3B62FF).withOpacity(0.3),
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
                          ? const Color(0xFF10B981)
                          : isUnknownTask
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF3B62FF),
                    ),
                    const SizedBox(width: 8),
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
                            ? const Color(0xFF10B981)
                            : isUnknownTask
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF3B62FF),
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
                            ? const Color(0xFF10B981)
                            : isUnknownTask
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF3B62FF),
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
                            ? const Color(0xFFEF4444)
                            : (isDailyAttendance
                                ? const Color(0xFF10B981)
                                : const Color(0xFF3B62FF)),
                        isDesktop,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Task Stats
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111321),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1E2135),
                width: 1,
              ),
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
                          fontSize: isDesktop ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF3B62FF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Duration',
                        style: TextStyle(
                          fontSize: isDesktop ? 11 : 10,
                          color: const Color(0xFF8F93A4),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isDailyAttendance) ...[
                  Container(
                    height: 32,
                    width: 1,
                    color: const Color(0xFF1E2135),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$sessionsCount',
                          style: TextStyle(
                            fontSize: isDesktop ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8C5CF6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sessions',
                          style: TextStyle(
                            fontSize: isDesktop ? 11 : 10,
                            color: const Color(0xFF8F93A4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 32,
                    width: 1,
                    color: const Color(0xFF1E2135),
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
                            fontSize: isDesktop ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Avg/Session',
                          style: TextStyle(
                            fontSize: isDesktop ? 11 : 10,
                            color: const Color(0xFF8F93A4),
                            fontWeight: FontWeight.w500,
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111321),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1E2135),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.note_alt_outlined,
                        size: 16,
                        color: Color(0xFF3B62FF),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Notes',
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3B62FF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    displayNotes,
                    style: TextStyle(
                      fontSize: isDesktop ? 13 : 12,
                      color: const Color(0xFFE2E8F0),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171926),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
