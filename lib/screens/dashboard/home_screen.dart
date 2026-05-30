import 'dart:async';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../widgets/app_bar_search_filter.dart';
import '../dashboard/modern_dashboard_screen.dart';
import '../../widgets/congratulations_overlay.dart';
import 'package:webnox_taskops/model/task_model.dart';
import 'package:webnox_taskops/helpers/common_colors.dart';
import 'package:webnox_taskops/model/team_card_model.dart';

import 'package:webnox_taskops/utils/responsive_utils.dart';
import 'package:webnox_taskops/widgets/custom_textfield.dart';
import 'package:webnox_taskops/view_model/task_view_model.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import 'package:webnox_taskops/api/api_client.dart';
import 'package:webnox_taskops/widgets/animated_task_card.dart';
import 'package:webnox_taskops/view_model/clock_view_model.dart';
import 'package:webnox_taskops/services/task_card_log_service.dart';
import 'package:webnox_taskops/view_model/team_card_view_model.dart';
import 'package:webnox_taskops/widgets/animated_loading_states.dart';
import 'package:webnox_taskops/view_model/attendance_view_model.dart';

import 'package:webnox_taskops/widgets/enhanced_animated_team_card.dart';
import 'package:webnox_taskops/widgets/dashboard_recreation/stats_card.dart';
import 'package:webnox_taskops/widgets/simple_attendance_widget.dart';
import 'package:webnox_taskops/screens/task_request/task_card_request_screen.dart';
import 'package:webnox_taskops/services/local_storage_service.dart';
import 'package:day_night_time_picker/day_night_time_picker.dart';
import '../../widgets/common/empty_state_widget.dart';

class HomeScreen extends HookWidget {
  const HomeScreen({super.key});

  // Helper function to show/hide suggestions overlay
  static OverlayEntry? _showSuggestionsOverlay(
    BuildContext context,
    GlobalKey searchBarKey,
    List<String> suggestions,
    TextEditingController searchController,
    ValueNotifier<String> searchQuery,
    ValueNotifier<bool> showSuggestions,
    FocusNode searchFocusNode,
    bool isSmallMobile,
  ) {
    final overlay = Overlay.of(context);
    final renderBox =
        searchBarKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null || suggestions.isEmpty) return null;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + size.height + 4,
        left: offset.dx,
        width: size.width,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: ClampingScrollPhysics(),
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return InkWell(
                  onTap: () {
                    searchController.text = suggestion;
                    searchQuery.value = suggestion;
                    showSuggestions.value = false;
                    searchFocusNode.unfocus();
                    overlayEntry?.remove();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallMobile ? 20 : 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          size: 18,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    return overlayEntry;
  }

  @override
  Widget build(BuildContext context) {
    // UI-specific state (not managed by ViewModel)
    final acceptedTasks = useState<Set<String>>({});
    final selectedTab = useState(0);
    final flippingTasks = useState<Set<String>>({});

    // Get TaskViewModel and AuthViewModel instances
    final taskViewModel = Provider.of<TaskViewModel>(context, listen: true);
    final authViewModel = Provider.of<AuthViewModel>(context);
    final clockViewModel = Provider.of<ClockViewModel>(context);

    // State for tasks data
    final pendingTasks = useState<List<Task>>([]);
    final isLoadingTasks = useState<bool>(true);
    final taskError = useState<String?>(null);
    final userRole = useState<String?>(null);
    final isAdmin = useState<bool>(false);

    // State for task statuses to enable proper categorization
    final taskStatuses = useState<Map<String, Map<String, dynamic>>>({});

    // Refresh trigger to force UI updates when task statuses change
    final refreshTrigger = useState<int>(0);

    // Search and filter state
    final searchQuery = useState<String>('');
    final searchController = useTextEditingController();
    final showSuggestions = useState<bool>(false);
    final searchFocusNode = useFocusNode();
    final searchBarKey = useMemoized(() => GlobalKey());
    final suggestionsOverlay = useRef<OverlayEntry?>(null);

    // Filter state
    final selectedPriorities = useState<Set<String>>({});
    final selectedStatuses = useState<Set<String>>({});
    final selectedProjects = useState<Set<String>>({});
    final hasActiveFilters = useState<bool>(false);

    // State persistence now handled by ClockViewModel.syncWithDatabase()
    // Removed saveClockInState() and restoreClockInState() functions

    // Hooks for swipeable metric cards (moved to top level to avoid conditional hook usage)
    // Hooks for swipeable metric cards (horizontal)
    final pageController = usePageController(viewportFraction: 0.9);
    final currentMetricPage = useState(0);

    // Auto-scroll timer for metric cards
    final isMobileLayout = ResponsiveUtils.isMobile(context);
    useEffect(() {
      if (!isMobileLayout) return null;

      final timer = Timer.periodic(const Duration(seconds: 40), (_) {
        if (pageController.hasClients) {
          final int nextPage = (currentMetricPage.value + 1) % 4;
          pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });

      return () => timer.cancel();
    }, [isMobileLayout]);

    // Sync with ClockViewModel on mount
    useEffect(() {
      Future.microtask(() => clockViewModel.syncWithDatabase(context));
      return null;
    }, []);

    // Fetch tasks on component mount
    useEffect(() {
      Future<void> fetchTasks() async {
        try {
          isLoadingTasks.value = true;
          taskError.value = null;

          print('HomeScreen: Starting to fetch tasks...');

          // Get user role first
          final role = await authViewModel.getUserRole();
          print('🔍 HomeScreen: Detected user role: $role');
          print('🔍 HomeScreen: Role type: ${role.runtimeType}');
          print('🔍 HomeScreen: Role length: ${role?.length}');
          print('🔍 HomeScreen: Role trimmed: "${role?.trim()}"');
          print('🔍 HomeScreen: Role toLowerCase: "${role?.toLowerCase()}"');
          userRole.value =
              role ?? 'Employee'; // Default to Employee if no role found
          isAdmin.value = await authViewModel.isAdminOrManager();
          print('🔍 HomeScreen: Is admin/manager: ${isAdmin.value}');
          print(
            '🔍 HomeScreen: Final user role (with fallback): ${userRole.value}',
          );
          print(
            '🔍 HomeScreen: Final role trimmed: "${userRole.value?.trim()}"',
          );
          print(
            '🔍 HomeScreen: Final role toLowerCase: "${userRole.value?.toLowerCase()}"',
          );
          print(
            '🔍 HomeScreen: Is QA Analyst check: ${userRole.value?.toLowerCase().trim() == 'qa analyst'}',
          );

          // Use backend API to fetch tasks (migrated from Supabase)
          final employeeId = LocalStorageService().userId;
          final taskData = await taskViewModel.fetchTasksSmartWithBackend(
            employeeId,
          );

          print(
            'HomeScreen: Received ${taskData.length} tasks from TaskViewModel',
          );

          final tasks = taskData.map((json) {
            print('HomeScreen: Converting task data: $json');
            try {
              return Task.fromJson(json);
            } catch (e, stackTrace) {
              print('❌ Error converting task data: $e');
              print('❌ Stack trace: $stackTrace');
              print('❌ Problematic JSON: $json');
              rethrow;
            }
          }).toList();

          print('HomeScreen: Successfully converted ${tasks.length} tasks');

          if (!context.mounted) return;

          pendingTasks.value = tasks;
          isLoadingTasks.value = false;
        } catch (e) {
          print('HomeScreen: Error fetching tasks: $e');
          taskError.value = 'Failed to load tasks: $e';
          isLoadingTasks.value = false;
        }
      }

      fetchTasks();
      return null;
    }, []);

    // Refresh function that can be called manually
    Future<void> refreshTasks() async {
      try {
        if (!context.mounted) return;
        isLoadingTasks.value = true;
        taskError.value = null;

        print('🏠 HomeScreen: Starting to refresh tasks...');
        print('🏠 HomeScreen: Current user role: ${userRole.value}');

        // Use backend API to fetch tasks (migrated from Supabase)
        final employeeId = LocalStorageService().userId;
        final taskData = await taskViewModel.fetchTasksSmartWithBackend(
          employeeId,
        );

        print(
          '🏠 HomeScreen: Received ${taskData.length} tasks from TaskViewModel',
        );
        print('🏠 HomeScreen: Task data: $taskData');

        final tasks = taskData.map((json) {
          try {
            return Task.fromJson(json);
          } catch (e, stackTrace) {
            print('❌ Error converting task data during refresh: $e');
            print('❌ Stack trace: $stackTrace');
            print('❌ Problematic JSON: $json');
            rethrow;
          }
        }).toList();

        print('🏠 HomeScreen: Successfully refreshed ${tasks.length} tasks');
        print(
          '🏠 HomeScreen: Task names: ${tasks.map((t) => t.taskName).toList()}',
        );
        print(
          '🏠 HomeScreen: Task statuses: ${tasks.map((t) => t.workflowStatus).toList()}',
        );

        if (!context.mounted) return;

        pendingTasks.value = tasks;
        isLoadingTasks.value = false;
      } catch (e) {
        print('HomeScreen: Error refreshing tasks: $e');
        taskError.value = 'Failed to refresh tasks: $e';
        isLoadingTasks.value = false;
      }
    }

    // Use our comprehensive responsive utilities
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final isLaptop = ResponsiveUtils.isLaptop(context);
    final isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);
    final isSmallMobile = MediaQuery.of(context).size.width < 360;

    // Check for active session on app start
    useEffect(() {
      // Check if there's an active session in the database and restore local state
      clockViewModel.checkAndRestoreActiveSession(context);
      return null;
    }, []);

    // Sync local state with global ClockViewModel state (e.g., on auto-clock out)
    useEffect(() {
      // ClockViewModel manages its own state - no sync needed
      // UI automatically updates via Provider when ViewModel state changes
      return null;
    }, []);

    // Sync with database periodically to ensure state consistency
    useEffect(() {
      Timer? syncTimer;
      syncTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        Future.microtask(() => clockViewModel.syncWithDatabase(context));
      });
      return () => syncTimer?.cancel();
    }, []);

    // Sync timer state when app resumes from background
    useEffect(() {
      final observer = AppLifecycleObserver(context, clockViewModel);
      WidgetsBinding.instance.addObserver(observer);

      return () {
        WidgetsBinding.instance.removeObserver(observer);
      };
    }, []);

    // Timer effect for clocked in task
    // Timer is now managed by ClockViewModel - no local timer needed
    // UI automatically updates when ClockViewModel notifies listeners

    // Clock in/out functionality - simplified to delegate to ViewModel
    void clockInOut(Task task) async {
      // Check if clocking out
      if (clockViewModel.clockedInTask?.taskId == task.taskId) {
        // Clock out - Show time selection dialog
        final now = DateTime.now();
        final currentTimeStr =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        final selectedOption = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Icon(Icons.timer_off, color: CommonColors.red),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Clock Out',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Clock out from "${task.taskName}"',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: CommonColors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time,
                        color: CommonColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Current Time: $currentTimeStr',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: CommonColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: CommonColors.grey),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop('pick'),
                icon: Icon(Icons.schedule, size: 18),
                label: Text('Pick Time'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CommonColors.primary,
                  side: BorderSide(color: CommonColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop('now'),
                icon: Icon(Icons.check, size: 18, color: Colors.white),
                label: Text(
                  'Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommonColors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );

        // User cancelled
        if (selectedOption == null) {
          return;
        }

        if (!context.mounted) return;

        DateTime clockOutTime = DateTime.now();

        if (selectedOption == 'pick') {
          // Show day_night_time_picker
          bool timePicked = false;
          await Navigator.of(context).push(
            showPicker(
              context: context,
              value: Time.fromTimeOfDay(TimeOfDay.now(), null),
              onChange: (Time newTime) {
                final now = DateTime.now();
                clockOutTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  newTime.hour,
                  newTime.minute,
                );
                timePicked = true;
              },
              is24HrFormat: false,
              iosStylePicker:
                  false, // Use standard wheel picker for better scrolling
              accentColor: CommonColors.primary,
              unselectedColor: CommonColors.grey,
              okText: 'Clock Out',
              cancelText: 'Cancel',
              hourLabel: 'Hour',
              minuteLabel: 'Minute',
              displayHeader: true,
              // Make it more square by using larger horizontal padding
              dialogInsetPadding: EdgeInsets.symmetric(
                horizontal: 80,
                vertical: 100,
              ),
              borderRadius: 20,
              elevation: 12,
              blurredBackground: true,
              barrierDismissible: true,
              height: 300, // Compact height
              width: 350, // Square-ish width
              sunAsset: null,
              moonAsset: null,
            ),
          );

          if (!context.mounted) return;

          if (!timePicked) {
            return; // User cancelled the time picker
          }
        }

        // Perform clock out with selected time
        final success = await clockViewModel.clockOut(
          context,
          customClockOutTime: clockOutTime,
        );

        if (!context.mounted) return;

        if (success) {
          // Log the clock out action (wrapped in try-catch to not break clock out on logging failure)
          try {
            final logService = TaskCardLogService();
            await logService.logTaskAction(
              taskId: task.taskId,
              actionName: 'Clock Out',
              actionDescription:
                  'User clocked out from task "${task.taskName}" at ${clockOutTime.hour.toString().padLeft(2, '0')}:${clockOutTime.minute.toString().padLeft(2, '0')}',
            );
          } catch (e) {
            // Logging failed, but clock out succeeded - don't show error to user
            print('Warning: Failed to log clock out action: $e');
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Clocked out from "${task.taskName}"'),
              backgroundColor: CommonColors.red,
            ),
          );
        } else {
          // Show error from ViewModel
          final errorMessage =
              clockViewModel.error ?? 'Unknown error occurred during clock out';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot clock out: $errorMessage'),
              backgroundColor: CommonColors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        // Clock in - First check if user has punched in for daily attendance
        final attendanceViewModel = Provider.of<AttendanceViewModel>(
          context,
          listen: false,
        );

        // Check if user has punched in for the day (using backend)
        final dailySummary = await attendanceViewModel.getSimpleDailySummary();

        if (!context.mounted) return;

        final isPunchedIn = dailySummary?['is_clocked_in'] ?? false;

        if (!isPunchedIn) {
          // User hasn't punched in yet - show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please punch in for daily attendance before clocking in to tasks',
              ),
              backgroundColor: CommonColors.orange,
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Punch In',
                textColor: Colors.white,
                onPressed: () {
                  // Navigate to the punch in section (metric cards area)
                  // User can scroll to the top where the punch in button is located
                },
              ),
            ),
          );
          return;
        }

        // User has punched in, proceed with task clock in
        final success = await clockViewModel.clockIn(task, context);

        if (!context.mounted) return;

        if (success) {
          // Log the clock in action
          final logService = TaskCardLogService();
          await logService.logTaskAction(
            taskId: task.taskId,
            actionName: 'Clock In',
            actionDescription: 'User clocked in to task "${task.taskName}"',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Clocked in to "${task.taskName}"'),
              backgroundColor: CommonColors.green,
            ),
          );
        } else {
          // Show error from ViewModel
          final errorMessage = clockViewModel.error ?? 'Failed to clock in';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: CommonColors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }

    // Show clock-in dialog after task acceptance
    void _showClockInDialog(Task task) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: CommonColors.green, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Task Accepted!',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleLarge?.color ??
                          Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task: ${task.taskName}',
                  style: TextStyle(
                    color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
                        Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Would you like to start working on this task now?',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Later',
                  style: TextStyle(
                    color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
                        Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  clockInOut(task); // Clock in to the task
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommonColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: 16, color: CommonColors.white),
                    SizedBox(width: 4),
                    Text(
                      'Clock In',
                      style: TextStyle(
                        color: CommonColors.white,
                        fontSize: 14,
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
    }

    // Start task functionality (only updates dev_started_at, no clock in/out)
    void startTask(Task task) async {
      try {
        print('🎯 HomeScreen: Starting task: ${task.taskName}');

        final success = await taskViewModel.startTask(
          taskId: task.taskId,
          employeeId: authViewModel.localStorage.userId,
        );

        if (!context.mounted) return;

        if (success) {
          print('✅ HomeScreen: Task started successfully');

          // Log the action
          final logService = TaskCardLogService();
          await logService.logTaskAction(
            taskId: task.taskId,
            actionName: 'Task Started',
            actionDescription: 'Task "${task.taskName}" was started by user',
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task "${task.taskName}" started'),
              backgroundColor: CommonColors.green,
            ),
          );

          // Refresh tasks to show updated status
          await refreshTasks();

          // Show clock-in dialog after successfully starting the task
          _showClockInDialog(task);
        } else {
          print('❌ HomeScreen: Task start failed');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start task "${task.taskName}"'),
              backgroundColor: CommonColors.red,
            ),
          );
        }
      } catch (e) {
        print('❌ HomeScreen: Error starting task: $e');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting task: $e'),
            backgroundColor: CommonColors.red,
          ),
        );
      }
    }

    void rejectTask(Task task) {
      print('🚫 REJECT BUTTON CLICKED!');
      print('  - Task ID: ${task.taskId}');
      print('  - Task Name: ${task.taskName}');
      print('  - Task Type: ${task.taskType}');
      print('  - About to show reject dialog...');

      // Simple test to confirm function is being called
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reject button clicked for ${task.taskName}'),
          duration: Duration(seconds: 1),
          backgroundColor: CommonColors.orange,
        ),
      );

      final notesController = TextEditingController();

      print('🎭 Calling showDialog...');

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          print('🎭 Dialog builder called - creating reject dialog...');
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(
              'Reject Task',
              style: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color ??
                    Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task: ${task.taskName}',
                  style: TextStyle(
                    color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
                        Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Reason for rejection:',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                CustomTextField(
                  controller: notesController,
                  title: 'Notes',
                  hintText: 'Enter notes...',
                  maxLines: 3,
                  isRequired: true,
                  showIcon: false,
                  showPsw: false,
                  textInputType: TextInputType.multiline,
                  readOnly: false,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a reason for rejection';
                    }
                    return null;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
                        Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (notesController.text.trim().isNotEmpty) {
                    try {
                      print('🚫 Rejecting task with remarks:');
                      print('  - Task ID: ${task.taskId}');
                      print('  - Task Name: ${task.taskName}');
                      print('  - Remarks: "${notesController.text.trim()}"');

                      // Call TaskViewModel to reject task
                      final success = await taskViewModel.rejectTask(
                        taskId: task.taskId,
                        remarks: notesController.text.trim(),
                      );

                      if (success) {
                        // Log the task rejection action
                        final logService = TaskCardLogService();
                        await logService.logTaskAction(
                          taskId: task.taskId,
                          actionName: 'Task Rejected',
                          actionDescription:
                              'Task "${task.taskName}" was rejected. Reason: ${notesController.text.trim()}',
                        );

                        // Remove from pending tasks (immediate UI update)
                        pendingTasks.value = pendingTasks.value
                            .where((t) => t.taskId != task.taskId)
                            .toList();

                        // Option: Refresh from server to ensure UI matches backend
                        // Uncomment this line if you want to always sync with backend
                        // await refreshTasks();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Task "${task.taskName}" rejected successfully with remarks saved',
                            ),
                            backgroundColor: CommonColors.orange,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to reject task "${task.taskName}"',
                            ),
                            backgroundColor: CommonColors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error rejecting task: $e'),
                          backgroundColor: CommonColors.red,
                        ),
                      );
                    }
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please enter a reason for rejecting the task',
                        ),
                        backgroundColor: CommonColors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommonColors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Reject',
                  style: TextStyle(
                    color: CommonColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    // Enhanced responsive padding and spacing for better mobile experience
    final horizontalPadding = isSmallMobile
        ? 16.0
        : isMobile
            ? 20.0
            : isTablet
                ? 24.0
                : isLaptop
                    ? 28.0
                    : isDesktop
                        ? 32.0
                        : 40.0;
    final verticalPadding = isSmallMobile
        ? 16.0
        : isMobile
            ? 20.0
            : isTablet
                ? 24.0
                : isLaptop
                    ? 28.0
                    : isDesktop
                        ? 32.0
                        : 40.0;
    final cardSpacing = isSmallMobile
        ? 12.0
        : isMobile
            ? 16.0
            : isTablet
                ? 20.0
                : isLaptop
                    ? 22.0
                    : isDesktop
                        ? 24.0
                        : 28.0;

    // Enhanced responsive font sizes optimized for readability
    final titleFontSize = isSmallMobile
        ? 22.0
        : isMobile
            ? 24.0
            : isTablet
                ? 26.0
                : isLaptop
                    ? 28.0
                    : isDesktop
                        ? 30.0
                        : 34.0;
    final subtitleFontSize = isSmallMobile
        ? 14.0
        : isMobile
            ? 15.0
            : isTablet
                ? 16.0
                : isLaptop
                    ? 16.5
                    : isDesktop
                        ? 17.0
                        : 19.0;

    final metricColumns = ResponsiveUtils.getResponsiveGridColumns(
      context,
      mobile: 2,
      tablet: 2,
      laptop: 4, // 4 columns for laptop as requested
      desktop: 4,
      fourK: 4,
    );

    // Metric card aspect ratios per breakpoint
    final metricAspectRatio = ResponsiveUtils.getResponsiveAspectRatio(
      context,
      mobile: 2.2,
      tablet: 2.6,
      laptop: 1.8, // Decreased to fix bottom overflow (makes card taller)
      desktop: 2.2, // Safety adjustment
      fourK: 2.4,
    );

    // Update completed task count in tabs
    void updateCompletedTaskCount() {
      // This will be called when tasks are completed
      // For now, it's a placeholder
    }

    // Fetch task statuses for proper categorization
    Future<void> fetchTaskStatuses() async {
      try {
        final taskViewModel = Provider.of<TaskViewModel>(
          context,
          listen: false,
        );
        final authViewModel = Provider.of<AuthViewModel>(
          context,
          listen: false,
        );

        // Get current user's employee ID
        if (!authViewModel.isAuthenticated) return;

        // Fetch all task statuses for the current user
        final statuses = <String, Map<String, dynamic>>{};

        for (final task in pendingTasks.value) {
          try {
            final assignment = await taskViewModel.fetchEmployeeAssignment(
              task.taskId,
            );
            if (assignment != null) {
              statuses[task.taskId] = assignment;
            }
          } catch (e) {
            // Only log non-disposal errors
            if (!e.toString().contains('disposed')) {
              print('Error fetching status for task ${task.taskId}: $e');
            }
          }
        }

        // Wrap value assignment in try-catch to handle disposal
        try {
          taskStatuses.value = statuses;
        } catch (e) {
          // Silently ignore disposal errors
          if (!e.toString().contains('disposed')) {
            rethrow;
          }
        }
      } catch (e) {
        // Only log if not a disposal error
        if (!e.toString().contains('disposed')) {
          print('Error fetching task statuses: $e');
        }
      }
    }

    // Get task status for a specific task
    Map<String, dynamic>? getTaskStatus(String taskId) {
      return taskStatuses.value[taskId];
    }

    // Check if a task is completed
    bool isTaskCompleted(String taskId) {
      final status = getTaskStatus(taskId);
      return status?['task_status'] == 4; // 4 = completed
    }

    // Check if a task is accepted
    bool isTaskAccepted(String taskId) {
      final status = getTaskStatus(taskId);
      return status?['is_accepted'] == true;
    }

    // Check if a task is rejected
    bool isTaskRejected(String taskId) {
      final status = getTaskStatus(taskId);
      return status?['is_rejected'] == true;
    }

    // Check if a task is delayed
    bool isTaskDelayed(String taskId) {
      final status = getTaskStatus(taskId);
      return status?['task_status'] == 6; // 6 = delayed
    }

    // Generate search suggestions based on query
    List<String> getSearchSuggestions(String query, List<Task> tasks) {
      if (query.isEmpty) return [];

      final lowerQuery = query.toLowerCase();
      final suggestions = <String>{};

      for (final task in tasks) {
        // Task name suggestions
        if (task.taskName != null &&
            task.taskName!.toLowerCase().contains(lowerQuery)) {
          suggestions.add(task.taskName!);
        }

        // Project name suggestions
        final projectName =
            task.projectDetails?['project_name']?.toString() ?? '';
        if (projectName.isNotEmpty &&
            projectName.toLowerCase().contains(lowerQuery)) {
          suggestions.add(projectName);
        }

        // Employee/assignee name suggestions
        final employeeName =
            task.employeeDetails?['employee_name']?.toString() ??
                task.employeeDetails?['full_name']?.toString() ??
                task.employeeDetails?['display_name']?.toString() ??
                '';
        if (employeeName.isNotEmpty &&
            employeeName.toLowerCase().contains(lowerQuery)) {
          suggestions.add(employeeName);
        }

        // Status suggestions
        if (task.workflowStatus != null &&
            task.workflowStatus!.toLowerCase().contains(lowerQuery)) {
          suggestions.add(task.workflowStatus!);
        }

        // Priority suggestions
        if (task.priorityLevel != null &&
            task.priorityLevel!.toLowerCase().contains(lowerQuery)) {
          suggestions.add(task.priorityLevel!);
        }
      }

      // Limit to 8 suggestions
      return suggestions.take(8).toList()..sort();
    }

    // Helper function to check if task matches search query
    bool taskMatchesSearch(Task task, String query) {
      if (query.isEmpty) return true;

      final lowerQuery = query.toLowerCase();

      // Search in task name
      if (task.taskName?.toLowerCase().contains(lowerQuery) == true) {
        return true;
      }

      // Search in task description
      if (task.taskDescription?.toLowerCase().contains(lowerQuery) == true) {
        return true;
      }

      // Search in project name
      final projectName =
          task.projectDetails?['project_name']?.toString() ?? '';
      if (projectName.toLowerCase().contains(lowerQuery)) {
        return true;
      }

      // Search in employee/assignee name
      final employeeName = task.employeeDetails?['employee_name']?.toString() ??
          task.employeeDetails?['full_name']?.toString() ??
          task.employeeDetails?['display_name']?.toString() ??
          '';
      if (employeeName.toLowerCase().contains(lowerQuery)) {
        return true;
      }

      // Search in workflow status
      if (task.workflowStatus?.toLowerCase().contains(lowerQuery) == true) {
        return true;
      }

      // Search in priority level
      if (task.priorityLevel?.toLowerCase().contains(lowerQuery) == true) {
        return true;
      }

      return false;
    }

    // Filter tasks based on selected tab and search query
    List<Task> getFilteredTasks() {
      // Different filtering logic for QA Analysts vs regular employees
      final isQAAnalyst = userRole.value?.toLowerCase().trim() ==
              'qa analyst' ||
          (userRole.value?.toLowerCase().trim().contains('quality control') ??
              false);
      List<Task> tabFilteredTasks;

      if (isQAAnalyst) {
        // QA Analyst filtering
        switch (selectedTab.value) {
          case 0: // To Do - Show tasks that need QA work (dev completed)
            tabFilteredTasks = pendingTasks.value.where((task) {
              final workflowStatus = task.workflowStatus?.toLowerCase();
              return workflowStatus == 'dev completed';
            }).toList();
            break;
          case 1: // In Progress - Show tasks that are in QC
            tabFilteredTasks = pendingTasks.value.where((task) {
              final workflowStatus = task.workflowStatus?.toLowerCase();
              // Check for various possible QC statuses
              return workflowStatus == 'in qc' ||
                  workflowStatus == 'qc' ||
                  workflowStatus == 'testing' ||
                  workflowStatus == 'in testing' ||
                  workflowStatus == 'qa testing' ||
                  workflowStatus == 'in qa';
            }).toList();
            break;
          case 2: // Completed - Show tasks that QA has finished (work done or redo)
            tabFilteredTasks = pendingTasks.value.where((task) {
              final workflowStatus = task.workflowStatus?.toLowerCase();
              return workflowStatus == 'work done' || workflowStatus == 'redo';
            }).toList();
            break;
          case 3: // All Tasks
            tabFilteredTasks = pendingTasks.value;
            break;
          default:
            tabFilteredTasks = pendingTasks.value;
        }
      } else {
        // Regular employee filtering
        switch (selectedTab.value) {
          case 0: // To Do - Show tasks that are assigned, todo, or redo
            tabFilteredTasks = pendingTasks.value.where((task) {
              final workflowStatus = task.workflowStatus?.toLowerCase();
              return workflowStatus == 'assigned' ||
                  workflowStatus == 'todo' ||
                  workflowStatus == 'redo' ||
                  workflowStatus == 'pending' ||
                  workflowStatus == 'new' ||
                  workflowStatus == 'not started';
            }).toList();
            break;
          case 1: // In Progress - Show tasks that are in progress (employees)
            tabFilteredTasks = pendingTasks.value.where((task) {
              final workflowStatus = task.workflowStatus?.toLowerCase();
              return workflowStatus == 'in progress';
            }).toList();
            break;
          case 2: // Completed - Show tasks that are work done or dev completed
            tabFilteredTasks = pendingTasks.value.where((task) {
              final workflowStatus = task.workflowStatus?.toLowerCase();
              return workflowStatus == 'work done' ||
                  workflowStatus == 'dev completed';
            }).toList();
            break;
          case 3: // All Tasks
            tabFilteredTasks = pendingTasks.value;
            break;
          default:
            tabFilteredTasks = pendingTasks.value;
        }
      }

      // Apply search filter if query is not empty
      List<Task> searchFilteredTasks = tabFilteredTasks;
      if (searchQuery.value.isNotEmpty) {
        searchFilteredTasks = tabFilteredTasks
            .where((task) => taskMatchesSearch(task, searchQuery.value))
            .toList();
      }

      // Apply filter criteria
      List<Task> filteredTasks = searchFilteredTasks;

      // Filter by priority
      if (selectedPriorities.value.isNotEmpty) {
        filteredTasks = filteredTasks.where((task) {
          final priority = task.priorityLevel?.toLowerCase() ?? '';
          return selectedPriorities.value.any(
            (selectedPriority) => priority == selectedPriority.toLowerCase(),
          );
        }).toList();
      }

      // Filter by status
      if (selectedStatuses.value.isNotEmpty) {
        filteredTasks = filteredTasks.where((task) {
          final status = task.workflowStatus?.toLowerCase() ?? '';
          return selectedStatuses.value.any(
            (selectedStatus) => status == selectedStatus.toLowerCase(),
          );
        }).toList();
      }

      // Filter by project
      if (selectedProjects.value.isNotEmpty) {
        filteredTasks = filteredTasks.where((task) {
          final projectName =
              task.projectDetails?['project_name']?.toString() ?? '';
          return selectedProjects.value.any(
            (selectedProject) =>
                projectName.toLowerCase() == selectedProject.toLowerCase(),
          );
        }).toList();
      }

      return filteredTasks;
    }

    // Get unique filter options from tasks
    Map<String, List<String>> getFilterOptions() {
      final priorities = <String>{};
      final statuses = <String>{};
      final projects = <String>{};

      for (final task in pendingTasks.value) {
        if (task.priorityLevel != null && task.priorityLevel!.isNotEmpty) {
          priorities.add(task.priorityLevel!);
        }
        if (task.workflowStatus != null && task.workflowStatus!.isNotEmpty) {
          statuses.add(task.workflowStatus!);
        }
        final projectName = task.projectDetails?['project_name']?.toString();
        if (projectName != null && projectName.isNotEmpty) {
          projects.add(projectName);
        }
      }

      return {
        'priorities': priorities.toList()..sort(),
        'statuses': statuses.toList()..sort(),
        'projects': projects.toList()..sort(),
      };
    }

    // Clear all filters
    void clearAllFilters() {
      selectedPriorities.value = {};
      selectedStatuses.value = {};
      selectedProjects.value = {};
      hasActiveFilters.value = false;
    }

    // Update hasActiveFilters based on current filter state
    void updateActiveFiltersState() {
      hasActiveFilters.value = selectedPriorities.value.isNotEmpty ||
          selectedStatuses.value.isNotEmpty ||
          selectedProjects.value.isNotEmpty;
    }

    // Get task count for completed tab - role-specific logic
    int getCompletedTaskCount() {
      final isQAAnalyst = userRole.value?.toLowerCase().trim() ==
              'qa analyst' ||
          (userRole.value?.toLowerCase().trim().contains('quality control') ??
              false);

      if (isQAAnalyst) {
        // QA Analyst: work done + redo (matches tab 2 logic)
        int completedCount = 0;
        for (final task in pendingTasks.value) {
          final workflowStatus = task.workflowStatus?.toLowerCase();
          if (workflowStatus == 'work done' || workflowStatus == 'redo') {
            completedCount++;
          }
        }
        return completedCount;
      } else {
        // Regular employee: work done + dev completed
        int completedCount = 0;
        for (final task in pendingTasks.value) {
          final s = task.workflowStatus?.toLowerCase();
          if (s == 'work done' || s == 'dev completed') {
            completedCount++;
          }
        }
        return completedCount;
      }
    }

    // QA Analyst functions
    Future<void> qaStartTask(Task task) async {
      try {
        print('🔍 QA Analyst starting task: ${task.taskName}');

        showDialog(
          context: context,
          builder: (BuildContext context) {
            final qaNotesController = TextEditingController();
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.play_arrow, color: Colors.orange, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Start Testing',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Are you ready to start testing "${task.taskName}"?',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: qaNotesController,
                    decoration: InputDecoration(
                      labelText: 'Initial QA Notes (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final success = await taskViewModel.qaStartTask(
                      taskId: task.taskId,
                      qaNotes: qaNotesController.text.trim(),
                      employeeId: authViewModel.localStorage.userId,
                    );
                    if (success) {
                      // Log the QA start action
                      final logService = TaskCardLogService();
                      await logService.logTaskAction(
                        taskId: task.taskId,
                        actionName: 'QA Testing Started',
                        actionDescription:
                            'QA Analyst started testing task "${task.taskName}"${qaNotesController.text.trim().isNotEmpty ? '. Notes: ${qaNotesController.text.trim()}' : ''}',
                      );

                      await refreshTasks();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Started testing "${task.taskName}"'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to start testing. Please try again.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Start Testing'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        print('❌ Error starting task: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    Widget _buildTeamCardItemWidget(
      BuildContext context,
      TeamCard card,
      bool isDesktop,
      int index,
    ) {
      // Use Selector to only rebuild when this specific card's status changes
      return Selector<AttendanceViewModel, bool>(
        selector: (context, attendanceVM) {
          // Only rebuild when this specific card's active status changes
          return attendanceVM.currentAttendance?.clockOffTime == null &&
              attendanceVM.currentAttendance?.taskId == card.teamCardId;
        },
        builder: (context, isActive, child) {
          final attendanceVM = Provider.of<AttendanceViewModel>(
            context,
            listen: false,
          );

          return EnhancedAnimatedTeamCard(
            key: ValueKey(card.teamCardId),
            teamCard: card,
            isCurrentlyClockedIn: isActive,
            onClockIn: () =>
                attendanceVM.clockIn(card.teamCardId, card.cardName),
            onClockOut: () async {
              // Check for active tasks before allowing clock out
              final clockVM = Provider.of<ClockViewModel>(
                context,
                listen: false,
              );
              await clockVM.syncWithDatabase(context);

              if (clockVM.isClockedIn) {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Active Task Running'),
                      content: Text(
                        'Please clock out from "${clockVM.clockedInTask?.taskName ?? 'the active task'}" before punching out.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
                return;
              }

              await attendanceVM.clockOut();
            },
            userRole: userRole.value,
            index: index,
          );
        },
      );
    }

    Widget _buildTeamCardsSidebar(BuildContext context, bool isDesktop) {
      final auth = Provider.of<AuthViewModel>(context, listen: false);
      return ChangeNotifierProvider(
        create: (_) => TeamCardViewModel()..loadCardsForUserRole(auth),
        child: Consumer<TeamCardViewModel>(
          builder: (context, vm, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Team Cards',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 10),
                if (vm.isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (vm.cards.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: EmptyStateWidget(
                      title: 'No team cards',
                      size: 150,
                      fontSize: 14,
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vm.cards.length,
                    itemBuilder: (context, index) {
                      final card = vm.cards[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildTeamCardItemWidget(
                          context,
                          card,
                          isDesktop,
                          index,
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      );
    }

    Widget _buildTeamCardsTabContent(BuildContext context, bool isDesktop) {
      final auth = Provider.of<AuthViewModel>(context, listen: false);
      return ChangeNotifierProvider(
        create: (_) => TeamCardViewModel()..loadCardsForUserRole(auth),
        child: Consumer<TeamCardViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (vm.error != null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Failed to load team cards',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              );
            }

            final all = vm.cards;

            final auth = Provider.of<AuthViewModel>(context, listen: false);
            return FutureBuilder<String?>(
              future: auth.getUserRole(),
              builder: (context, roleSnap) {
                final roleRaw = roleSnap.data ?? '';
                final role = roleRaw.toLowerCase().trim();

                List<TeamCard> filtered = all.where((card) {
                  final tRaw = card.teamType?.toLowerCase().trim() ?? '';
                  if (tRaw.isEmpty) return false;
                  if (tRaw == 'all') return true;

                  // Split on common separators and whitespace
                  final tParts = tRaw
                      .split(RegExp(r'[\s,;/]+'))
                      .where((s) => s.isNotEmpty)
                      .toList();
                  final roleParts = role
                      .split(RegExp(r'[\s,;/]+'))
                      .where((s) => s.isNotEmpty)
                      .toList();

                  // Basic contains check in both directions
                  if (role.contains(tRaw) || tRaw.contains(role)) return true;

                  // If team_type mentions domain like 'mobile' or 'qa', match against role parts
                  final domainMatches = tParts.any(
                    (tp) => roleParts.contains(tp),
                  );
                  if (domainMatches) return true;

                  // Specific mapping: 'mobile app' matches 'mobile app developer'
                  if (tRaw.contains('mobile') && role.contains('mobile'))
                    return true;
                  if (tRaw.contains('qa') && role.contains('qa')) return true;
                  if (tRaw.contains('web') && role.contains('web')) return true;

                  return false;
                }).toList();

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: EmptyStateWidget(
                      title: 'No team cards for $roleRaw',
                      subtitle: 'Team specific cards will appear here',
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final card = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTeamCardItemWidget(
                        context,
                        card,
                        isDesktop,
                        index,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      );
    }

    Future<void> qaCompleteTask(Task task) async {
      try {
        print('✅ QA Analyst completing task: ${task.taskName}');

        showDialog(
          context: context,
          builder: (BuildContext context) {
            final qaNotesController = TextEditingController();
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Complete Testing',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Are you sure you want to complete testing for "${task.taskName}"?',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: qaNotesController,
                    decoration: InputDecoration(
                      labelText: 'Final QA Notes (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final success = await taskViewModel.qaCompleteTask(
                      taskId: task.taskId,
                      qaNotes: qaNotesController.text.trim(),
                      employeeId: authViewModel.localStorage.userId,
                    );
                    if (success) {
                      // Log the QA complete action
                      final logService = TaskCardLogService();
                      await logService.logTaskAction(
                        taskId: task.taskId,
                        actionName: 'QA Testing Completed',
                        actionDescription:
                            'QA Analyst completed testing task "${task.taskName}"${qaNotesController.text.trim().isNotEmpty ? '. Notes: ${qaNotesController.text.trim()}' : ''}',
                      );

                      await refreshTasks();
                      // Show success message
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 8),
                                Text('QA Testing completed successfully! 🎉'),
                              ],
                            ),
                            backgroundColor: CommonColors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to complete testing. Please try again.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Complete Testing'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        print('❌ Error completing task: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    Future<void> qaRedoTask(Task task) async {
      try {
        print('🔄 QA Analyst sending task for redo: ${task.taskName}');

        showDialog(
          context: context,
          builder: (BuildContext context) {
            final qaNotesController = TextEditingController();
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.refresh, color: Colors.red, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Send for Redo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Are you sure you want to send "${task.taskName}" back for redo?',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: qaNotesController,
                    decoration: InputDecoration(
                      labelText: 'Redo Reason (Required)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (qaNotesController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please provide a redo reason.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    final success = await taskViewModel.qaRedoTask(
                      taskId: task.taskId,
                      qaNotes: qaNotesController.text.trim(),
                      employeeId: authViewModel.localStorage.userId,
                    );
                    if (success) {
                      // Log the QA redo action
                      final logService = TaskCardLogService();
                      await logService.logTaskAction(
                        taskId: task.taskId,
                        actionName: 'Task Sent for Redo',
                        actionDescription:
                            'QA Analyst sent task "${task.taskName}" for redo. Reason: ${qaNotesController.text.trim()}',
                      );

                      await refreshTasks();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Task "${task.taskName}" sent for redo',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to send for redo. Please try again.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Send for Redo'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        print('❌ Error sending task for redo: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending task for redo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    Future<void> qaApproveTask(Task task) async {
      try {
        print('✅ QA Analyst approving task: ${task.taskName}');

        showDialog(
          context: context,
          builder: (BuildContext context) {
            final qaNotesController = TextEditingController();
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'QA Approve Task',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Are you sure you want to approve "${task.taskName}"?',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: qaNotesController,
                    decoration: InputDecoration(
                      labelText: 'QA Notes (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final success = await taskViewModel.qaApproveTask(
                      taskId: task.taskId,
                      qaNotes: qaNotesController.text.trim(),
                      employeeId: authViewModel.localStorage.userId,
                    );
                    if (success) {
                      // Log the QA approve action
                      final logService = TaskCardLogService();
                      await logService.logTaskAction(
                        taskId: task.taskId,
                        actionName: 'QA Approved',
                        actionDescription:
                            'QA Analyst approved task "${task.taskName}"${qaNotesController.text.trim().isNotEmpty ? '. Notes: ${qaNotesController.text.trim()}' : ''}',
                      );

                      await refreshTasks();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Task "${task.taskName}" approved successfully!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to approve task. Please try again.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Approve'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        print('❌ Error approving task: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    Future<void> qaDisapproveTask(Task task) async {
      try {
        print('❌ QA Analyst disapproving task: ${task.taskName}');

        showDialog(
          context: context,
          builder: (BuildContext context) {
            final qaNotesController = TextEditingController();
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'QA Disapprove Task',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Are you sure you want to disapprove "${task.taskName}"?',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: qaNotesController,
                    decoration: InputDecoration(
                      labelText: 'QA Notes (Required)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (qaNotesController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please provide QA notes for disapproval.',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    final success = await taskViewModel.qaDisapproveTask(
                      taskId: task.taskId,
                      qaNotes: qaNotesController.text.trim(),
                      employeeId: authViewModel.localStorage.userId,
                    );
                    if (success) {
                      // Log the QA disapprove action
                      final logService = TaskCardLogService();
                      await logService.logTaskAction(
                        taskId: task.taskId,
                        actionName: 'QA Disapproved',
                        actionDescription:
                            'QA Analyst disapproved task "${task.taskName}". Notes: ${qaNotesController.text.trim()}',
                      );

                      await refreshTasks();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Task "${task.taskName}" disapproved successfully!',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to disapprove task. Please try again.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Disapprove'),
                ),
              ],
            );
          },
        );
      } catch (e) {
        print('❌ Error disapproving task: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error disapproving task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Fetch task statuses after component builds to enable proper filtering
    useEffect(() {
      if (pendingTasks.value.isNotEmpty) {
        // Use a delayed call to ensure proper execution
        bool isCancelled = false;
        Future.delayed(Duration(milliseconds: 100), () async {
          if (isCancelled) return;
          try {
            await fetchTaskStatuses();
            if (!isCancelled) {
              try {
                print(
                  '✅ Task statuses fetched: ${taskStatuses.value.length} statuses',
                );
              } catch (e) {
                // Silently ignore if ValueNotifier was disposed
                if (!e.toString().contains('disposed')) {
                  rethrow;
                }
              }
            }
          } catch (e) {
            // Only log if not a disposal error
            if (!e.toString().contains('disposed') && !isCancelled) {
              print('❌ Error fetching task statuses: $e');
            }
          }
        });
        return () {
          isCancelled = true;
        };
      }
      return null;
    }, [pendingTasks.value, refreshTrigger.value]);

    // Listen to TaskViewModel changes and refresh tasks when statuses change
    useEffect(() {
      // This effect will run whenever the TaskViewModel notifies listeners
      // (which happens when task statuses are updated in kanban board)
      Timer? debounceTimer;

      if (pendingTasks.value.isNotEmpty) {
        print(
          '🔄 HomeScreen: TaskViewModel change detected, scheduling refresh...',
        );

        // Debounce the refresh to prevent infinite loops
        debounceTimer = Timer(const Duration(milliseconds: 500), () {
          print('🔄 HomeScreen: Executing debounced task refresh...');
          refreshTasks();
        });
      }

      return () => debounceTimer?.cancel();
    }, [taskViewModel]); // Listen to TaskViewModel changes

    // Helper method to build individual task card
    Widget _buildTaskCardItem(
      BuildContext context,
      Task task,
      int index,
      ValueNotifier<String?> userRole,
      TaskViewModel taskViewModel,
    ) {
      return AnimatedTaskCard(
        task: task,
        index: index,
        showActions: true,
        // Pass clock-in state from local HomeScreen state (which is synced with global)
        isCurrentlyClockedIn:
            clockViewModel.clockedInTask?.taskId == task.taskId,
        startTime: clockViewModel.clockedInTask?.taskId == task.taskId
            ? clockViewModel.startTime
            : null,
        elapsedTime: clockViewModel.clockedInTask?.taskId == task.taskId
            ? clockViewModel.elapsedTime
            : null,
        previousDuration: clockViewModel.clockedInTask?.taskId == task.taskId
            ? clockViewModel.previousDuration
            : null,
        onClockIn: () => clockInOut(task),
        onStartTask: () => startTask(task),
        onCompleteTask: () async {
          // Check if user is QA Analyst and task is in QC
          final isQAAnalyst =
              userRole.value?.toLowerCase().trim() == 'qa analyst' ||
                  (userRole.value
                          ?.toLowerCase()
                          .trim()
                          .contains('quality control') ??
                      false);
          final isInQC = task.workflowStatus?.toLowerCase() == 'in qc';

          if (isQAAnalyst && isInQC) {
            // QA Analyst completing QC task - move to Work Done
            qaCompleteTask(task);
          } else {
            // Regular employee completion
            // Regular employee completion
            final success = await taskViewModel.completeTask(
              taskId: task.taskId,
              employeeId: authViewModel.localStorage.userId,
            );
            if (success) {
              if (context.mounted) {
                showCongratulationsOverlay(
                  context,
                  taskName: task.taskName ?? 'Task',
                  onComplete: () async {
                    await refreshTasks();
                  },
                );
              }
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to complete task "${task.taskName}"'),
                    backgroundColor: CommonColors.red,
                  ),
                );
              }
            }
          }
        },
        onQAApprove: () => qaApproveTask(task),
        onQADisapprove: () => qaDisapproveTask(task),
        onQAStartTask: () => qaStartTask(task),
        onQACompleteTask: () => qaCompleteTask(task),
        onQARedoTask: () => qaRedoTask(task),
        userRole: userRole.value,
      );
    }

    // Get global search notifier for Home screen (index 0)
    final globalSearchExpanded = getSearchNotifierForScreen(0);
    final globalHasActiveFilters = getFiltersNotifierForScreen(0);

    // Sync local hasActiveFilters with global
    useEffect(() {
      final listener = () {
        globalHasActiveFilters.value = hasActiveFilters.value;
      };
      hasActiveFilters.addListener(listener);
      return () => hasActiveFilters.removeListener(listener);
    }, [hasActiveFilters.value]);

    // Listen to global filter trigger (when filter icon is clicked in dashboard header)
    final globalFilterTrigger = getFilterTriggerForScreen(0);
    useEffect(() {
      final listener = () {
        // Trigger filter dialog when global filter is clicked
        final filterOptions = getFilterOptions();
        _showFilterDialog(
          context,
          selectedPriorities,
          selectedStatuses,
          selectedProjects,
          filterOptions,
          () {
            clearAllFilters();
            updateActiveFiltersState();
          },
          updateActiveFiltersState,
          hasActiveFilters,
        );
      };
      globalFilterTrigger.addListener(listener);
      return () => globalFilterTrigger.removeListener(listener);
    }, []);

    // Create search filter config for expandable search
    final searchFilterConfig = SearchFilterConfig(
      searchController: searchController,
      searchQuery: searchQuery,
      hasActiveFilters: hasActiveFilters,
      hintText: 'Search tasks...',
      // Use global notifier for search expanded state
      isSearchExpanded: globalSearchExpanded,
      // Home screen search: just update the searchQuery, getFilteredTasks() will use it
      onSearchChanged: (query) {
        // Developer mode Code
        if (query == 'SuNnYmIa') {
          final attendanceVM = Provider.of<AttendanceViewModel>(
            context,
            listen: false,
          );
          attendanceVM.toggleDeveloperMode(context);
          searchController.clear();
          searchQuery.value = '';
          return;
        }
        // The searchQuery.value is already updated in the widget
        // getFilteredTasks() will automatically use it to filter tasks
      },
      // Optional: For search suggestions
      getSearchSuggestions: (query) =>
          getSearchSuggestions(query, pendingTasks.value),
      showSuggestions: showSuggestions,
      searchFocusNode: searchFocusNode,
      searchBarKey: searchBarKey,
      showSuggestionsOverlay: (
        context,
        key,
        suggestions,
        controller,
        query,
        showSuggestionsVal,
        focusNode,
        isSmall,
      ) {
        return _showSuggestionsOverlay(
          context,
          key,
          suggestions,
          controller,
          query,
          showSuggestionsVal ?? showSuggestions,
          focusNode ?? searchFocusNode,
          isSmall,
        );
      },
      setSuggestionsOverlay: (overlay) {
        suggestionsOverlay.value?.remove();
        suggestionsOverlay.value = overlay;
      },
      onFilterTap: () {
        final filterOptions = getFilterOptions();
        _showFilterDialog(
          context,
          selectedPriorities,
          selectedStatuses,
          selectedProjects,
          filterOptions,
          () {
            clearAllFilters();
            updateActiveFiltersState();
          },
          updateActiveFiltersState,
          hasActiveFilters,
        );
      },
      activeFilterCount: selectedPriorities.value.length +
          selectedStatuses.value.length +
          selectedProjects.value.length,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null, // No app bar - using header in body
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                _buildHeader(
                  context,
                  isDesktop,
                  isMobile,
                  isSmallMobile,
                  titleFontSize,
                  subtitleFontSize,
                  isAdmin,
                  userRole,
                ),
                // Expandable Search Bar (if expanded from dashboard header)
                ValueListenableBuilder<bool>(
                  valueListenable: searchFilterConfig.isSearchExpanded,
                  builder: (context, isExpanded, child) {
                    if (!isExpanded) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(bottom: isSmallMobile ? 12 : 16),
                      child: AppBarSearchFilter(
                        config: searchFilterConfig,
                        isDesktop: isDesktop,
                        isMobile: isMobile,
                        isSmallMobile: isSmallMobile,
                      ),
                    );
                  },
                ),

                // Metric Cards with loading state
                isLoadingTasks.value
                    ? _buildMetricCardsLoader(
                        context,
                        isDesktop,
                        metricColumns,
                        metricAspectRatio,
                        cardSpacing,
                      )
                    : _buildMetricCards(
                        context,
                        isDesktop,
                        metricColumns,
                        metricAspectRatio,
                        cardSpacing,
                        pendingTasks,
                        acceptedTasks,
                        clockViewModel.clockedInTask,
                        clockViewModel.elapsedTime,
                        getCompletedTaskCount(),
                        userRole,
                        pageController,
                        currentMetricPage,
                      ),

                SizedBox(
                  height: isSmallMobile
                      ? 16
                      : isMobile
                          ? 20
                          : 24,
                ),

                // Task Board Glassmorphic Container
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.015),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.04),
                      width: 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: isMobile ? 12 : 20,
                          top: isMobile ? 12 : 20,
                          right: isMobile ? 12 : 20,
                          bottom: isMobile ? 120 : 140,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Task Category Tabs
                            FutureBuilder<Widget>(
                              future: _buildTaskTabs(
                                context,
                                selectedTab,
                                isDesktop,
                                pendingTasks,
                                acceptedTasks,
                                taskStatuses,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return snapshot.data!;
                                } else {
                                  return const SizedBox.shrink();
                                }
                              },
                            ),

                            const SizedBox(height: 12),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.white.withOpacity(0.06),
                            ),
                            const SizedBox(height: 16),

                            // Scrollable Task List Area
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: isMobile ? 500 : (isTablet ? 650 : 800),
                              ),
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: isMobile ? 8 : 12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (isLoadingTasks.value)
                                          Column(
                                            children: [
                                              // Task tabs skeleton
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                    left: 16,
                                                    top: 8,
                                                    bottom: 8,
                                                  ),
                                                  padding: const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                    horizontal: 20,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.02),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: Colors.white.withOpacity(0.04),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: List.generate(3, (index) {
                                                      return Container(
                                                        margin: EdgeInsets.only(
                                                          right: index < 2 ? 8 : 0,
                                                        ),
                                                        padding: const EdgeInsets.symmetric(
                                                          vertical: 8,
                                                          horizontal: 16,
                                                        ),
                                                        child: SkeletonLoader(
                                                          height: 16,
                                                          width: 80,
                                                          borderRadius: 4,
                                                        ),
                                                      );
                                                    }),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              // Task cards skeleton
                                              Column(
                                                children: List.generate(3, (index) {
                                                  return TaskCardSkeleton(
                                                    isMobile: isMobile,
                                                    isSmallMobile: isSmallMobile,
                                                  );
                                                }),
                                              ),
                                            ],
                                          )
                                        else if (taskError.value != null)
                                          Container(
                                            height: 200,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.error_outline,
                                                    color: CommonColors.red,
                                                    size: 32,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    taskError.value!,
                                                    style: TextStyle(
                                                      color: CommonColors.red,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ElevatedButton(
                                                    onPressed: () => refreshTasks(),
                                                    child: const Text('Retry'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        else ...[
                                          Builder(
                                            builder: (context) {
                                              final filteredTasks = getFilteredTasks();

                                              if (filteredTasks.isEmpty) {
                                                // Show appropriate message based on selected tab
                                                String emptyMessage;
                                                // Different empty messages for QA Analysts vs regular employees
                                                final isQAAnalyst =
                                                    userRole.value?.toLowerCase().trim() ==
                                                            'qa analyst' ||
                                                        userRole.value?.toLowerCase().trim() ==
                                                            'qa analyst' ||
                                                        (userRole.value
                                                                ?.toLowerCase()
                                                                .trim()
                                                                .contains('quality control') ??
                                                            false);

                                                if (isQAAnalyst) {
                                                  switch (selectedTab.value) {
                                                    case 0: // To Do
                                                      emptyMessage = 'No tasks ready for QA review';
                                                      break;
                                                    case 1: // In Progress
                                                      emptyMessage = 'No tasks currently in QC';
                                                      break;
                                                    case 2: // Completed
                                                      emptyMessage = 'No QA work completed yet';
                                                      break;
                                                    case 3: // All Tasks
                                                      emptyMessage = 'No tasks available';
                                                      break;
                                                    default:
                                                      emptyMessage = 'No tasks available';
                                                  }
                                                } else {
                                                  switch (selectedTab.value) {
                                                    case 0: // To Do
                                                      emptyMessage = 'No tasks assigned to you';
                                                      break;
                                                    case 1: // In Progress
                                                      emptyMessage = 'No tasks in progress';
                                                      break;
                                                    case 2: // Completed
                                                      emptyMessage = 'No completed tasks yet';
                                                      break;
                                                    case 3: // All Tasks
                                                      emptyMessage = 'No tasks available';
                                                      break;
                                                    default:
                                                      emptyMessage = 'No tasks available';
                                                  }
                                                }

                                                return Container(
                                                  height: isDesktop ? 550 : 380,
                                                  child: EmptyStateWidget(
                                                    title: emptyMessage,
                                                    subtitle: 'Check back later or refresh the page',
                                                  ),
                                                );
                                              } else {
                                                // If Team Cards tab is selected (index 4), show team cards instead of tasks
                                                if (selectedTab.value == 4) {
                                                  return _buildTeamCardsTabContent(context, isDesktop);
                                                }

                                                // Custom Masonry Layout for Tasks
                                                // Calculate columns based on width ranges matching standard breakpoints + our custom ones
                                                final columns =
                                                    ResponsiveUtils.getResponsiveGridColumns(
                                                  context,
                                                  mobile: 1,
                                                  tablet: 2,
                                                  laptop: 3,
                                                  desktop: 4,
                                                  fourK: 4,
                                                );

                                                // Spacing
                                                final spacing = isSmallMobile
                                                    ? 12.0
                                                    : isMobile
                                                        ? 16.0
                                                        : 20.0; // Increased spacing for desktop

                                                if (columns == 1) {
                                                  return ListView.separated(
                                                    shrinkWrap: true,
                                                    physics: const NeverScrollableScrollPhysics(),
                                                    itemCount: filteredTasks.length,
                                                    separatorBuilder: (context, index) =>
                                                        SizedBox(height: spacing),
                                                    itemBuilder: (context, index) {
                                                      final task = filteredTasks[index];
                                                      return _buildTaskCardItem(
                                                        context,
                                                        task,
                                                        index,
                                                        userRole,
                                                        taskViewModel,
                                                      );
                                                    },
                                                  );
                                                }

                                                // Distribute tasks into columns
                                                List<List<Task>> columnTasks = List.generate(
                                                  columns,
                                                  (_) => [],
                                                );
                                                for (int i = 0; i < filteredTasks.length; i++) {
                                                  columnTasks[i % columns].add(filteredTasks[i]);
                                                }

                                                return Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: List.generate(columns, (colIndex) {
                                                    return Expanded(
                                                      child: Padding(
                                                        padding: EdgeInsets.only(
                                                          right: colIndex == columns - 1 ? 0 : spacing,
                                                        ),
                                                        child: Column(
                                                          children: columnTasks[colIndex].map((task) {
                                                            return Padding(
                                                              padding: EdgeInsets.only(bottom: spacing),
                                                              child: _buildTaskCardItem(
                                                                context,
                                                                task,
                                                                filteredTasks.indexOf(task),
                                                                userRole,
                                                                taskViewModel,
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom padding to ensure last cards are fully visible
                SizedBox(
                  height: isMobile ? 80.0 : 100.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Header with responsive layout
  Widget _buildHeader(
    BuildContext context,
    bool isDesktop,
    bool isMobile,
    bool isSmallMobile,
    double titleFontSize,
    double subtitleFontSize,
    ValueNotifier<bool> isAdmin,
    ValueNotifier<String?> userRole,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and subtitle removed
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCards(
    BuildContext context,
    bool isDesktop,
    int metricColumns,
    double metricAspectRatio,
    double cardSpacing,
    ValueNotifier<List<Task>> pendingTasks,
    ValueNotifier<Set<String>> acceptedTasks,
    Task? clockedInTask,
    Duration elapsedTime,
    int completedTaskCount,
    ValueNotifier<String?> userRole,
    PageController pageController,
    ValueNotifier<int> currentPage,
  ) {
    // Get responsive breakpoints for this method
    final isSmallMobile = MediaQuery.of(context).size.width < 360;

    // Calculate metrics based on user role - same UI but role-specific counts
    final isQAAnalyst = userRole.value?.toLowerCase().trim() == 'qa analyst' ||
        (userRole.value?.toLowerCase().trim().contains('quality control') ??
            false);

    // Calculate counts based on role-specific tab filtering logic
    int totalTasksCount;
    int pendingTasksCount;
    int completedTasksCount;

    if (isQAAnalyst) {
      // QA Analyst counts based on their tab filtering
      totalTasksCount = pendingTasks.value.length; // All tasks they can see

      // Pending = tasks in QC (tab 1 logic)
      pendingTasksCount = pendingTasks.value.where((task) {
        final workflowStatus = task.workflowStatus?.toLowerCase();
        return workflowStatus == 'in qc' ||
            workflowStatus == 'qc' ||
            workflowStatus == 'testing' ||
            workflowStatus == 'in testing' ||
            workflowStatus == 'qa testing' ||
            workflowStatus == 'in qa';
      }).length;

      // Completed = work done + redo (tab 2 logic)
      completedTasksCount = pendingTasks.value.where((task) {
        final workflowStatus = task.workflowStatus?.toLowerCase();
        return workflowStatus == 'work done' || workflowStatus == 'redo';
      }).length;
    } else {
      // Regular employee counts
      totalTasksCount = pendingTasks.value.length;

      // In Progress = in progress tasks only
      pendingTasksCount = pendingTasks.value.where((task) {
        final workflowStatus = task.workflowStatus?.toLowerCase();
        return workflowStatus == 'in progress';
      }).length;

      // Completed = work done or dev completed tasks
      completedTasksCount = pendingTasks.value.where((task) {
        final workflowStatus = task.workflowStatus?.toLowerCase();
        return workflowStatus == 'work done' ||
            workflowStatus == 'dev completed';
      }).length;
    }

    final isMobile = ResponsiveUtils.isMobile(context);

    if (isMobile) {
      final cards = [
        RecreatedStatsCard(
          title: isQAAnalyst ? 'QA TASKS' : 'TOTAL TASKS',
          value: '$totalTasksCount',
          badgeText: 'Active',
          isGrowth: true,
          imagePath: 'assets/images/total_task.png',
          backSubtitle: isQAAnalyst ? 'Tasks needing review' : 'Overall tasks allocated this month',
          icon: isQAAnalyst ? Icons.bug_report_rounded : Icons.format_list_bulleted_rounded,
          accentColor: const Color(0xFF3B82F6),
          subtitle: isQAAnalyst ? 'Tasks needing review' : 'Assigned to you',
        ),
        RecreatedStatsCard(
          title: isQAAnalyst ? 'IN QC' : 'IN PROGRESS',
          value: '$pendingTasksCount',
          badgeText: 'Ongoing',
          isGrowth: false,
          imagePath: 'assets/images/inprogress.png',
          backSubtitle: isQAAnalyst ? 'Ready for testing' : 'Tasks currently actively worked on',
          icon: isQAAnalyst ? Icons.pending_actions_rounded : Icons.directions_run_rounded,
          accentColor: const Color(0xFFF59E0B),
          subtitle: isQAAnalyst ? 'Ready for testing' : 'Currently active',
        ),
        RecreatedStatsCard(
          title: 'COMPLETED',
          value: '$completedTasksCount',
          badgeText: 'Done',
          isGrowth: true,
          imagePath: 'assets/images/completed.png',
          backSubtitle: isQAAnalyst ? 'Tested & Verified' : 'Finished tasks with high quality score',
          icon: Icons.check_rounded,
          accentColor: const Color(0xFF10B981),
          subtitle: isQAAnalyst ? 'Tested & Verified' : 'Tasks finished',
        ),
        const SimpleAttendanceWidget(),
      ];

      return Column(
        children: [
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: pageController,
              itemCount: cards.length,
              onPageChanged: (index) {
                currentPage.value = index;
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: cards[index],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Page Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              cards.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: currentPage.value == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: currentPage.value == index
                      ? CommonColors.primary
                      : CommonColors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: RecreatedStatsCard(
                        title: isQAAnalyst ? 'QA TASKS' : 'TOTAL TASKS',
                        value: '$totalTasksCount',
                        badgeText: 'Active',
                        isGrowth: true,
                        imagePath: 'assets/images/total_task.png',
                        backSubtitle: isQAAnalyst ? 'Tasks needing review' : 'Overall tasks allocated this month',
                        icon: isQAAnalyst ? Icons.bug_report_rounded : Icons.format_list_bulleted_rounded,
                        accentColor: const Color(0xFF3B82F6),
                        subtitle: isQAAnalyst ? 'Tasks needing review' : 'Assigned to you',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RecreatedStatsCard(
                        title: isQAAnalyst ? 'IN QC' : 'IN PROGRESS',
                        value: '$pendingTasksCount',
                        badgeText: 'Ongoing',
                        isGrowth: false,
                        imagePath: 'assets/images/inprogress.png',
                        backSubtitle: isQAAnalyst ? 'Ready for testing' : 'Tasks currently actively worked on',
                        icon: isQAAnalyst ? Icons.pending_actions_rounded : Icons.directions_run_rounded,
                        accentColor: const Color(0xFFF59E0B),
                        subtitle: isQAAnalyst ? 'Ready for testing' : 'Currently active',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RecreatedStatsCard(
                        title: 'COMPLETED',
                        value: '$completedTasksCount',
                        badgeText: 'Done',
                        isGrowth: true,
                        imagePath: 'assets/images/completed.png',
                        backSubtitle: isQAAnalyst ? 'Tested & Verified' : 'Finished tasks with high quality score',
                        icon: Icons.check_rounded,
                        accentColor: const Color(0xFF10B981),
                        subtitle: isQAAnalyst ? 'Tested & Verified' : 'Tasks finished',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: const SimpleAttendanceWidget(),
              ),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RecreatedStatsCard(
                      title: isQAAnalyst ? 'QA TASKS' : 'TOTAL TASKS',
                      value: '$totalTasksCount',
                      badgeText: 'Active',
                      isGrowth: true,
                      imagePath: 'assets/images/total_task.png',
                      backSubtitle: isQAAnalyst ? 'Tasks needing review' : 'Overall tasks allocated this month',
                      icon: isQAAnalyst ? Icons.bug_report_rounded : Icons.format_list_bulleted_rounded,
                      accentColor: const Color(0xFF3B82F6),
                      subtitle: isQAAnalyst ? 'Tasks needing review' : 'Assigned to you',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RecreatedStatsCard(
                      title: isQAAnalyst ? 'IN QC' : 'IN PROGRESS',
                      value: '$pendingTasksCount',
                      badgeText: 'Ongoing',
                      isGrowth: false,
                      imagePath: 'assets/images/inprogress.png',
                      backSubtitle: isQAAnalyst ? 'Ready for testing' : 'Tasks currently actively worked on',
                      icon: isQAAnalyst ? Icons.pending_actions_rounded : Icons.directions_run_rounded,
                      accentColor: const Color(0xFFF59E0B),
                      subtitle: isQAAnalyst ? 'Ready for testing' : 'Currently active',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RecreatedStatsCard(
                      title: 'COMPLETED',
                      value: '$completedTasksCount',
                      badgeText: 'Done',
                      isGrowth: true,
                      imagePath: 'assets/images/completed.png',
                      backSubtitle: isQAAnalyst ? 'Tested & Verified' : 'Finished tasks with high quality score',
                      icon: Icons.check_rounded,
                      accentColor: const Color(0xFF10B981),
                      subtitle: isQAAnalyst ? 'Tested & Verified' : 'Tasks finished',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SimpleAttendanceWidget(),
            ],
          );
        }
      },
    );

  }

  Widget _buildMobileMetricCard({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
    required String subtitle,
    required String trend,
    required Color trendColor,
    Gradient? gradient,
    String? tag,
    IconData? waterMarkIcon,
  }) {
    final isGradient = gradient != null;
    final textColor = isGradient
        ? Colors.white
        : Theme.of(context).textTheme.titleLarge?.color;
    final subTextColor = isGradient
        ? Colors.white.withValues(alpha: 0.8)
        : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: isGradient ? null : Theme.of(context).cardColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(
          16,
        ), // Rounded corners as per design
        border: isGradient
            ? null
            : Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: (isGradient
                    ? (gradient as LinearGradient).colors.first
                    : Theme.of(context).shadowColor)
                .withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, // Clip for watermark
      child: Stack(
        children: [
          // Watermark Icon (New Style)
          if (waterMarkIcon != null)
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                waterMarkIcon,
                size: 80,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Tag+Icon (New Style) OR Icon+Trend (Old Style)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isGradient) ...[
                      // NEW STYLE: Tag on Left, Icon on Right
                      if (tag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        const SizedBox(),

                      Icon(icon, color: Colors.white70, size: 20),
                    ] else ...[
                      // OLD STYLE: Icon on Left, Trend on Right
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: trendColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: trendColor, size: 18),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: trendColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            trend,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: trendColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const Spacer(),

                // Value
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isGradient ? 28 : 18, // Larger font for new style
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.0,
                  ),
                ),

                const SizedBox(height: 4),

                // Label
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 2),

                // Subtitle
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: subTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Individual metric card with hover effects
  Widget _buildMetricCard({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
    required String subtitle,
    required String trend,
    required Color trendColor,
    required bool isDesktop,
    Gradient? gradient,
    String? tag,
    IconData? waterMarkIcon,
  }) {
    return _HoverableMetricCard(
      context: context,
      icon: icon,
      value: value,
      label: label,
      subtitle: subtitle,
      trend: trend,
      trendColor: trendColor,
      isDesktop: isDesktop,
      gradient: gradient,
      tag: tag,
      waterMarkIcon: waterMarkIcon,
    );
  }

  // Attendance metric card with clock in/out functionality and daily details
  Widget _buildAttendanceMetricCard({
    required BuildContext context,
    required Task? clockedInTask,
    required Duration elapsedTime,
    required String Function(Duration) formatDuration,
    required bool isDesktop,
  }) {
    final isMobile = ResponsiveUtils.isMobile(context);

    // For mobile, we want the attendance card to look consistent with other metric cards
    // Use a simplified mobile layout that fits in the PageView
    if (isMobile) {
      return _AttendanceMetricCardWidget(
        isDesktop: false, // Force mobile layout
        buildLoader: (context, isDesktop) =>
            _buildMetricCardLoader(context, false),
      );
    }

    return _AttendanceMetricCardWidget(
      isDesktop: isDesktop,
      buildLoader: (context, isDesktop) =>
          _buildMetricCardLoader(context, isDesktop),
    );
  }

  // Loading state for metric cards
  Widget _buildMetricCardsLoader(
    BuildContext context,
    bool isDesktop,
    int metricColumns,
    double metricAspectRatio,
    double cardSpacing,
  ) {
    final isSmallMobile = MediaQuery.of(context).size.width < 360;
    final adjustedCardSpacing = isSmallMobile ? 16.0 : cardSpacing;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: metricColumns,
      crossAxisSpacing: adjustedCardSpacing,
      mainAxisSpacing: adjustedCardSpacing,
      childAspectRatio: metricAspectRatio,
      children: List.generate(
        4,
        (index) => _buildMetricCardLoader(context, isDesktop),
      ),
    );
  }

  // Individual metric card loader
  Widget _buildMetricCardLoader(BuildContext context, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallCard = constraints.maxHeight < 100;
          final iconSize = isSmallCard ? 24.0 : 36.0; // Reduced from 28/36
          final spacing1 = isSmallCard ? 4.0 : 10.0; // Reduced from 6/10
          final spacing2 = isSmallCard ? 2.0 : 6.0; // Reduced from 3/6
          final container2Height = isSmallCard ? 14.0 : 22.0;
          final container3Height = isSmallCard ? 10.0 : 14.0;
          final container2Width = isSmallCard ? 40.0 : 70.0;
          final container3Width = isSmallCard ? 70.0 : 110.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: iconSize * 0.5,
                        height: iconSize * 0.5,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 60,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing1),
              Container(
                width: container2Width,
                height: container2Height,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              SizedBox(height: spacing2),
              Flexible(
                child: Container(
                  width: container3Width,
                  height: container3Height,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Show filter dialog
  void _showFilterDialog(
    BuildContext context,
    ValueNotifier<Set<String>> selectedPriorities,
    ValueNotifier<Set<String>> selectedStatuses,
    ValueNotifier<Set<String>> selectedProjects,
    Map<String, List<String>> filterOptions,
    VoidCallback onClearFilters,
    VoidCallback onUpdateFilters,
    ValueNotifier<bool> hasActiveFilters,
  ) {
    // Local state for dialog
    final localPriorities = Set<String>.from(selectedPriorities.value);
    final localStatuses = Set<String>.from(selectedStatuses.value);
    final localProjects = Set<String>.from(selectedProjects.value);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter Tasks'),
                  if (localPriorities.isNotEmpty ||
                      localStatuses.isNotEmpty ||
                      localProjects.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          localPriorities.clear();
                          localStatuses.clear();
                          localProjects.clear();
                        });
                        onClearFilters();
                      },
                      child: Text('Clear All', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Priority Filter
                    if (filterOptions['priorities']!.isNotEmpty) ...[
                      Text(
                        'Priority',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: filterOptions['priorities']!.map((priority) {
                          final isSelected = localPriorities.contains(priority);
                          return FilterChip(
                            label: Text(priority),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  localPriorities.add(priority);
                                } else {
                                  localPriorities.remove(priority);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),
                    ],

                    // Status Filter
                    if (filterOptions['statuses']!.isNotEmpty) ...[
                      Text(
                        'Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: filterOptions['statuses']!.map((status) {
                          final isSelected = localStatuses.contains(status);
                          return FilterChip(
                            label: Text(status),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  localStatuses.add(status);
                                } else {
                                  localStatuses.remove(status);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),
                    ],

                    // Project Filter
                    if (filterOptions['projects']!.isNotEmpty) ...[
                      Text(
                        'Project',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: filterOptions['projects']!.map((project) {
                          final isSelected = localProjects.contains(project);
                          return FilterChip(
                            label: Text(project),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  localProjects.add(project);
                                } else {
                                  localProjects.remove(project);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    selectedPriorities.value = localPriorities;
                    selectedStatuses.value = localStatuses;
                    selectedProjects.value = localProjects;
                    onUpdateFilters();
                    hasActiveFilters.value = localPriorities.isNotEmpty ||
                        localStatuses.isNotEmpty ||
                        localProjects.isNotEmpty;
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Generate search suggestions based on query
  List<String> getSearchSuggestions(String query, List<Task> tasks) {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final suggestions = <String>{};

    for (final task in tasks) {
      // Task name suggestions
      if (task.taskName != null &&
          task.taskName!.toLowerCase().contains(lowerQuery)) {
        suggestions.add(task.taskName!);
      }

      // Project name suggestions
      final projectName =
          task.projectDetails?['project_name']?.toString() ?? '';
      if (projectName.isNotEmpty &&
          projectName.toLowerCase().contains(lowerQuery)) {
        suggestions.add(projectName);
      }

      // Employee/assignee name suggestions
      final employeeName = task.employeeDetails?['employee_name']?.toString() ??
          task.employeeDetails?['full_name']?.toString() ??
          task.employeeDetails?['display_name']?.toString() ??
          '';
      if (employeeName.isNotEmpty &&
          employeeName.toLowerCase().contains(lowerQuery)) {
        suggestions.add(employeeName);
      }

      // Status suggestions
      if (task.workflowStatus != null &&
          task.workflowStatus!.toLowerCase().contains(lowerQuery)) {
        suggestions.add(task.workflowStatus!);
      }

      // Priority suggestions
      if (task.priorityLevel != null &&
          task.priorityLevel!.toLowerCase().contains(lowerQuery)) {
        suggestions.add(task.priorityLevel!);
      }
    }

    // Limit to 8 suggestions
    return suggestions.take(8).toList()..sort();
  }

  // Search and filter bar
  Widget _buildSearchAndFilterBar(
    BuildContext context,
    bool isDesktop,
    bool isMobile,
    bool isSmallMobile,
    TextEditingController searchController,
    ValueNotifier<String> searchQuery,
    ValueNotifier<Set<String>> selectedPriorities,
    ValueNotifier<Set<String>> selectedStatuses,
    ValueNotifier<Set<String>> selectedProjects,
    ValueNotifier<bool> hasActiveFilters,
    Map<String, List<String>> Function() getFilterOptions,
    VoidCallback clearAllFilters,
    VoidCallback updateActiveFiltersState,
    ValueNotifier<bool> showSuggestions,
    FocusNode searchFocusNode,
    List<Task> tasks,
    GlobalKey searchBarKey,
    ObjectRef<OverlayEntry?> suggestionsOverlayRef,
  ) {
    // Get suggestions based on current query
    final suggestions = searchQuery.value.isNotEmpty
        ? getSearchSuggestions(searchQuery.value, tasks)
        : <String>[];

    if (isSmallMobile) {
      return Column(
        children: [
          Container(
            key: searchBarKey,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ), // Increased padding for better mobile touch targets
            decoration: BoxDecoration(
              color: Theme.of(context).inputDecorationTheme.fillColor ??
                  Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.5) ??
                      Colors.white.withOpacity(0.5),
                  size: 24, // Increased icon size for better mobile visibility
                ),
                const SizedBox(
                  width: 16,
                ), // Increased spacing for better mobile layout
                Expanded(
                  child: TextField(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    onChanged: (value) {
                      searchQuery.value = value;
                      final newSuggestions = value.isNotEmpty
                          ? getSearchSuggestions(value, tasks)
                          : <String>[];
                      final shouldShow =
                          value.isNotEmpty && newSuggestions.isNotEmpty;

                      // Manage overlay
                      suggestionsOverlayRef.value?.remove();
                      suggestionsOverlayRef.value = null;

                      if (shouldShow) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (searchBarKey.currentContext != null) {
                            suggestionsOverlayRef.value =
                                _showSuggestionsOverlay(
                              context,
                              searchBarKey,
                              newSuggestions,
                              searchController,
                              searchQuery,
                              showSuggestions,
                              searchFocusNode,
                              isSmallMobile,
                            );
                          }
                        });
                      }

                      showSuggestions.value = shouldShow;
                    },
                    onTap: () {
                      final currentSuggestions = searchQuery.value.isNotEmpty
                          ? getSearchSuggestions(searchQuery.value, tasks)
                          : <String>[];
                      if (currentSuggestions.isNotEmpty) {
                        showSuggestions.value = true;
                        // Show overlay
                        suggestionsOverlayRef.value?.remove();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (searchBarKey.currentContext != null) {
                            suggestionsOverlayRef.value =
                                _showSuggestionsOverlay(
                              context,
                              searchBarKey,
                              currentSuggestions,
                              searchController,
                              searchQuery,
                              showSuggestions,
                              searchFocusNode,
                              isSmallMobile,
                            );
                          }
                        });
                      }
                    },
                    onSubmitted: (_) {
                      showSuggestions.value = false;
                      suggestionsOverlayRef.value?.remove();
                      suggestionsOverlayRef.value = null;
                    },
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      hintStyle: TextStyle(
                        color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.5) ??
                            Colors.white.withOpacity(0.5),
                        fontSize:
                            16, // Increased font size for better mobile readability
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Single Filter Button - More focused on task management
          InkWell(
            onTap: () {
              final filterOptions = getFilterOptions();
              _showFilterDialog(
                context,
                selectedPriorities,
                selectedStatuses,
                selectedProjects,
                filterOptions,
                () {
                  clearAllFilters();
                  updateActiveFiltersState();
                },
                updateActiveFiltersState,
                hasActiveFilters,
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ), // Increased padding for better mobile touch targets
              decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor ??
                    Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(
                  16,
                ), // Increased border radius for modern mobile look
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: Theme.of(
                              context,
                            )
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.7) ??
                            Colors.white.withValues(alpha: 0.7),
                        size:
                            22, // Increased icon size for better mobile visibility
                      ),
                      if (hasActiveFilters.value)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(
                    width: 8,
                  ), // Increased spacing for better mobile layout
                  Text(
                    'Filter Tasks${hasActiveFilters.value ? ' (${selectedPriorities.value.length + selectedStatuses.value.length + selectedProjects.value.length})' : ''}',
                    style: TextStyle(
                      color: Theme.of(
                            context,
                          )
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.7) ??
                          Colors.white.withValues(alpha: 0.7),
                      fontSize:
                          14, // Increased font size for better mobile readability
                      fontWeight: FontWeight
                          .w600, // Increased font weight for better mobile visibility
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  key: searchBarKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).inputDecorationTheme.fillColor ??
                        Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          Theme.of(context).dividerColor.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.5) ??
                            Colors.white.withOpacity(0.5),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          focusNode: searchFocusNode,
                          onChanged: (value) {
                            searchQuery.value = value;
                            final newSuggestions = value.isNotEmpty
                                ? getSearchSuggestions(value, tasks)
                                : <String>[];
                            final shouldShow =
                                value.isNotEmpty && newSuggestions.isNotEmpty;

                            // Manage overlay
                            suggestionsOverlayRef.value?.remove();
                            suggestionsOverlayRef.value = null;

                            if (shouldShow) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (searchBarKey.currentContext != null) {
                                  suggestionsOverlayRef.value =
                                      _showSuggestionsOverlay(
                                    context,
                                    searchBarKey,
                                    newSuggestions,
                                    searchController,
                                    searchQuery,
                                    showSuggestions,
                                    searchFocusNode,
                                    isSmallMobile,
                                  );
                                }
                              });
                            }

                            showSuggestions.value = shouldShow;
                          },
                          onTap: () {
                            final currentSuggestions = searchQuery
                                    .value.isNotEmpty
                                ? getSearchSuggestions(searchQuery.value, tasks)
                                : <String>[];
                            if (currentSuggestions.isNotEmpty) {
                              showSuggestions.value = true;
                              // Show overlay
                              suggestionsOverlayRef.value?.remove();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (searchBarKey.currentContext != null) {
                                  suggestionsOverlayRef.value =
                                      _showSuggestionsOverlay(
                                    context,
                                    searchBarKey,
                                    currentSuggestions,
                                    searchController,
                                    searchQuery,
                                    showSuggestions,
                                    searchFocusNode,
                                    isSmallMobile,
                                  );
                                }
                              });
                            }
                          },
                          onSubmitted: (_) {
                            showSuggestions.value = false;
                            suggestionsOverlayRef.value?.remove();
                            suggestionsOverlayRef.value = null;
                          },
                          style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color ??
                                    Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Search tasks, assignees, or descriptions...',
                            hintStyle: TextStyle(
                              color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withOpacity(0.5) ??
                                  Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              final filterOptions = getFilterOptions();
              _showFilterDialog(
                context,
                selectedPriorities,
                selectedStatuses,
                selectedProjects,
                filterOptions,
                () {
                  clearAllFilters();
                  updateActiveFiltersState();
                },
                updateActiveFiltersState,
                hasActiveFilters,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor ??
                    Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  Icon(
                    Icons.filter_list,
                    color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
                        Colors.white.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  if (hasActiveFilters.value)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  // Task category tabs
  Future<Widget> _buildTaskTabs(
    BuildContext context,
    ValueNotifier<int> selectedTab,
    bool isDesktop,
    ValueNotifier<List<Task>> pendingTasks,
    ValueNotifier<Set<String>> acceptedTasks,
    ValueNotifier<Map<String, Map<String, dynamic>>> taskStatuses,
  ) async {
    // Calculate counts for each tab based on actual database status
    int todoCount = 0;
    int pendingCount = 0;
    int completedCount = 0;

    // Get user role to determine counting logic
    final authViewModel = Provider.of<AuthViewModel>(context);
    final userRole = await authViewModel.getUserRole();
    final finalRole =
        userRole ?? 'Employee'; // Default to Employee if no role found
    final isQAAnalyst = finalRole.toLowerCase().trim() == 'qa analyst' ||
        (finalRole.toLowerCase().trim().contains('quality control'));
    print('🔍 Tab Logic Debug:');
    print('  - User role: $userRole');
    print('  - Final role (with fallback): $finalRole');
    print('  - Is QA Analyst: $isQAAnalyst');

    for (final task in pendingTasks.value) {
      // Use workflow_status from task_cards table directly
      final workflowStatus = task.workflowStatus?.toLowerCase();

      if (isQAAnalyst) {
        // QA Analyst counting logic
        if (workflowStatus == 'dev completed') {
          // Task needs QA work (todo tab)
          todoCount++;
        } else if (workflowStatus == 'in qc') {
          // Task is in QC (in progress tab)
          pendingCount++;
        } else if (workflowStatus == 'work done' || workflowStatus == 'redo') {
          // Task QA has finished (completed tab)
          completedCount++;
        }
      } else {
        // Regular employee counting logic
        if (workflowStatus == 'assigned' ||
            workflowStatus == 'todo' ||
            workflowStatus == 'redo' ||
            workflowStatus == 'pending' ||
            workflowStatus == 'new' ||
            workflowStatus == 'not started') {
          // Task is assigned, todo, redo, pending, new, or not started (todo tab)
          todoCount++;
        } else if (workflowStatus == 'in progress') {
          // Task is in progress (in progress tab for employees)
          pendingCount++;
        } else if (workflowStatus == 'work done' ||
            workflowStatus == 'dev completed') {
          // Task is work done or dev completed (completed tab)
          completedCount++;
        }
      }
    }

    // Fetch Team Cards count asynchronously for the tab label
    int teamCardsCount = 0;
    try {
      final apiClient = ApiClient();
      await apiClient.init();
      final response = await apiClient.get(
        '/employee/team-cards',
        requiresAuth: true,
      );

      if (response.success && response.data != null) {
        final allCards = List<Map<String, dynamic>>.from(response.data);
        final role = finalRole.toLowerCase().trim();

        teamCardsCount = allCards.where((card) {
          final tRaw = card['team_type']?.toString().toLowerCase().trim() ?? '';
          if (tRaw.isEmpty) return false;
          if (tRaw == 'all') return true;

          final tParts = tRaw
              .split(RegExp(r'[\s,;/]+'))
              .where((s) => s.isNotEmpty)
              .toList();
          final roleParts = role
              .split(RegExp(r'[\s,;/]+'))
              .where((s) => s.isNotEmpty)
              .toList();

          if (role.contains(tRaw) || tRaw.contains(role)) return true;
          if (tParts.any((tp) => roleParts.contains(tp))) return true;
          if (tRaw.contains('mobile') && role.contains('mobile')) return true;
          if (tRaw.contains('qa') && role.contains('qa')) return true;
          if (tRaw.contains('web') && role.contains('web')) return true;

          return false;
        }).length;
      }
    } catch (e) {
      print('Error calculating team cards count: $e');
    }

    // Use a FutureBuilder to get the user role asynchronously
    return FutureBuilder<String?>(
      future: authViewModel.getUserRole(),
      builder: (context, snapshot) {
        final userRole = snapshot.data;

        // Different tabs for QA Analysts vs regular employees
        final tabs = isQAAnalyst
            ? [
                {'label': 'To Do', 'count': '$todoCount'},
                {'label': 'In Progress', 'count': '$pendingCount'},
                {'label': 'Completed', 'count': '$completedCount'},
                {'label': 'All Tasks', 'count': '${pendingTasks.value.length}'},
                {'label': 'Team Cards', 'count': '$teamCardsCount'},
              ]
            : [
                {'label': 'To Do', 'count': '$todoCount'},
                {'label': 'In Progress', 'count': '$pendingCount'},
                {'label': 'Completed', 'count': '$completedCount'},
                {'label': 'All Tasks', 'count': '${pendingTasks.value.length}'},
                {'label': 'Team Cards', 'count': '$teamCardsCount'},
              ];

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: tabs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final tab = entry.value;
                    final isSelected = selectedTab.value == index;

                    final isMobile = ResponsiveUtils.isMobile(context);
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => selectedTab.value = index,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 8 : 10,
                            horizontal: isMobile ? 12 : 16,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF3B82F6).withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF3B82F6).withOpacity(0.4)
                                  : Colors.white.withOpacity(0.05),
                              width: 1.2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                                      blurRadius: 10,
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            '${tab['label']} (${tab['count']})',
                            style: GoogleFonts.inter(
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                  : Colors.white.withOpacity(0.4),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: isMobile ? 12 : 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Floating / Plus Add Button on top-right
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 40 : 16,
                          vertical: isDesktop ? 40 : 24,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 900),
                            child: const TaskCardRequestScreen(),
                          ),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Hoverable metric card widget
// Attendance metric card widget that caches data and only refreshes when needed
class _AttendanceMetricCardWidget extends StatefulWidget {
  final bool isDesktop;
  final Widget Function(BuildContext, bool) buildLoader;

  const _AttendanceMetricCardWidget({
    required this.isDesktop,
    required this.buildLoader,
  });

  @override
  State<_AttendanceMetricCardWidget> createState() =>
      _AttendanceMetricCardWidgetState();
}

class _AttendanceMetricCardWidgetState
    extends State<_AttendanceMetricCardWidget> {
  Timer? _sessionTimer;
  DateTime? _sessionStartTime;
  int _timerTick = 0; // Force rebuild counter
  int _previousSessionsSeconds =
      0; // Accumulated seconds from previous sessions today

  @override
  void initState() {
    super.initState();
    // Pre-fetch attendance data if not available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final viewModel = Provider.of<AttendanceViewModel>(
          context,
          listen: false,
        );
        viewModel.fetchCurrentAttendance();
      }
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  // Format duration for display
  String _formatSessionDuration(Duration duration) {
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

  // Start/update the stopwatch timer using start time from data
  void _startSessionTimer(String? firstClockIn) {
    if (firstClockIn != null && firstClockIn.isNotEmpty) {
      try {
        _sessionStartTime = _parseUtcToLocal(firstClockIn);
        _sessionTimer?.cancel();

        _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted && _sessionStartTime != null) {
            // Force rebuild to update the timer display
            setState(() {
              _timerTick++; // Increment to force rebuild
            });
          } else {
            timer.cancel();
          }
        });
      } catch (e) {
        // Handle error silently
        _sessionTimer?.cancel();
        _sessionStartTime = null;
      }
    } else {
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _sessionStartTime = null;
    }
  }

  // Get current session duration from stopwatch (includes previous sessions)
  String? _getCurrentSessionDuration() {
    if (_sessionStartTime != null) {
      final currentSessionElapsed = DateTime.now().difference(
        _sessionStartTime!,
      );
      // Add previous sessions' accumulated time to current session elapsed
      final totalElapsed =
          Duration(seconds: _previousSessionsSeconds) + currentSessionElapsed;
      return _formatSessionDuration(totalElapsed);
    }
    return null;
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

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--:--';
    try {
      final dateTime = _parseUtcToLocal(isoString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceViewModel>(
      builder: (context, attendanceViewModel, child) {
        if (attendanceViewModel.isLoadingAttendance &&
            attendanceViewModel.dailySummary == null) {
          return widget.buildLoader(context, widget.isDesktop);
        }

        final summary = attendanceViewModel.dailySummary;

        // If summary is null but not loading, trigger fetch (safety fallback)
        if (summary == null && !attendanceViewModel.isLoadingAttendance) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              attendanceViewModel.fetchCurrentAttendance();
            }
          });
          // Show loader while fetching
          return widget.buildLoader(context, widget.isDesktop);
        }

        // If still null after fallback (e.g. error), show error state or empty state
        if (summary == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border:
                  Border.all(color: CommonColors.red.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: CommonColors.red, size: 24),
                const SizedBox(height: 8),
                Text(
                  'Failed to load status',
                  style: TextStyle(
                    color: CommonColors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: () => attendanceViewModel.fetchCurrentAttendance(),
                  child: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: CommonColors.red,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
          );
        }

        final isClockedIn = summary['is_clocked_in'] ?? false;
        final totalHours = summary['total_hours'] ?? 0.0;
        final firstClockIn = summary['first_clock_in'];
        final lastClockOut = summary['last_clock_out'];

        final currentSessionStart = summary['current_session_start'];

        // Start timer if clocked in and we have start time
        if (isClockedIn && currentSessionStart != null) {
          // Parse the new session start time
          DateTime? newSessionStart;
          try {
            newSessionStart = _parseUtcToLocal(currentSessionStart.toString());
          } catch (e) {
            newSessionStart = null;
          }

          // Restart timer if this is a new session (different start time or first time)
          if (newSessionStart != null) {
            final shouldRestartTimer = _sessionStartTime == null ||
                _sessionStartTime!.difference(newSessionStart).inSeconds.abs() >
                    2;

            if (shouldRestartTimer) {
              // Update accumulated hours from COMPLETED sessions only (not the active one)
              // Using total_hours here would double-count the active session
              final previousHours = (summary['completed_sessions_hours'] is num)
                  ? (summary['completed_sessions_hours'] as num).toDouble()
                  : 0.0;
              _previousSessionsSeconds = (previousHours * 3600).round();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _startSessionTimer(currentSessionStart.toString());
                }
              });
            }
          }
        } else if (!isClockedIn) {
          _sessionTimer?.cancel();
          _sessionStartTime = null;
          _previousSessionsSeconds = 0; // Reset when clocked out
        }

        // Use stopwatch duration if available - this will update every second when timer is running
        // The setState in the timer will cause this builder to rebuild via Consumer
        String? sessionDuration;
        if (isClockedIn && _sessionStartTime != null) {
          sessionDuration = _getCurrentSessionDuration();
        } else if (isClockedIn) {
          sessionDuration = summary['session_duration'] ?? '0h 0m';
        }

        return _AttendanceDetailCard(
          context: context,
          isClockedIn: isClockedIn,
          totalHours: totalHours,
          firstClockIn: _formatTime(firstClockIn),
          lastClockOut: _formatTime(lastClockOut),
          currentSessionTime: isClockedIn ? (sessionDuration ?? '0h 0m') : null,
          isDesktop: widget.isDesktop,
          onTap: () async {
            if (isClockedIn) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.logout, color: CommonColors.red),
                      SizedBox(width: 12),
                      Text(
                        'Punch Out',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    'Are you sure you want to punch out for today?',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CommonColors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Punch Out'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                // Check for active tasks before allowing clock out
                final clockVM = Provider.of<ClockViewModel>(
                  context,
                  listen: false,
                );
                await clockVM.syncWithDatabase(context);

                if (clockVM.isClockedIn) {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Active Task Running'),
                        content: Text(
                          'Please clock out from "${clockVM.clockedInTask?.taskName ?? 'the active task'}" before punching out of attendance.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                  return;
                }

                await attendanceViewModel.clockOut();
                await attendanceViewModel.fetchCurrentAttendance();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        attendanceViewModel.error ?? 'Clocked out successfully',
                      ),
                      backgroundColor: attendanceViewModel.error != null
                          ? CommonColors.red
                          : CommonColors.green,
                    ),
                  );
                }
                attendanceViewModel.fetchCurrentAttendance();
              }
            } else {
              // Time-Based Check for Remote/Extra Time
              final now = DateTime.now();
              // Office Start: 9:00 AM
              final officeStart = DateTime(now.year, now.month, now.day, 9, 0);
              // Office End: 7:00 PM
              final officeEnd = DateTime(now.year, now.month, now.day, 19, 0);

              bool isOutsideOfficeHours =
                  now.isBefore(officeStart) || now.isAfter(officeEnd);

              String? remoteReason;

              if (isOutsideOfficeHours) {
                // Prompt for reason
                final reasonController = TextEditingController();
                final reason = await showDialog<String>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: const Text('Outside Office Hours'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'You are punching in outside standard office hours (9:00 AM - 7:00 PM).',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Please provide a reason (e.g., Night Shift, Extra Time) to proceed.',
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: reasonController,
                          decoration: InputDecoration(
                            labelText: 'Reason',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hintText: 'Enter reason...',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (reasonController.text.trim().isNotEmpty) {
                            Navigator.of(
                              context,
                            ).pop(reasonController.text.trim());
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reason is required'),
                              ),
                            );
                          }
                        },
                        child: const Text('Punch In'),
                      ),
                    ],
                  ),
                );

                if (reason == null) return; // User cancelled
                remoteReason = reason;
              }

              await attendanceViewModel.simpleClockIn(
                remoteReason: remoteReason,
              );
              await attendanceViewModel.fetchCurrentAttendance();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      attendanceViewModel.error ?? 'Clocked in successfully',
                    ),
                    backgroundColor: attendanceViewModel.error != null
                        ? CommonColors.red
                        : CommonColors.green,
                  ),
                );
                // Reload summary and start timer immediately after clock in
                attendanceViewModel.fetchCurrentAttendance();
              }
            }
          },
        );
      },
    );
  }
}

class _HoverableMetricCard extends StatefulWidget {
  final BuildContext context;
  final IconData icon;
  final String value;
  final String label;
  final String subtitle;
  final String trend;
  final Color trendColor;
  final bool isDesktop;
  final Gradient? gradient;
  final String? tag;
  final IconData? waterMarkIcon;

  const _HoverableMetricCard({
    required this.context,
    required this.icon,
    required this.value,
    required this.label,
    required this.subtitle,
    required this.trend,
    required this.trendColor,
    required this.isDesktop,
    this.gradient,
    this.tag,
    this.waterMarkIcon,
  });

  @override
  State<_HoverableMetricCard> createState() => _HoverableMetricCardState();
}

class _HoverableMetricCardState extends State<_HoverableMetricCard>
    with SingleTickerProviderStateMixin {
  bool isHovered = false;
  late AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallMobile = MediaQuery.of(context).size.width < 360;
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final isLaptop = ResponsiveUtils.isLaptop(context);

    // New Gradient Design Path
    if (widget.gradient != null) {
      return MouseRegion(
        onEnter: (_) {
          setState(() => isHovered = true);
          _shineController.repeat(reverse: false);
        },
        onExit: (_) {
          setState(() => isHovered = false);
          _shineController.stop();
          _shineController.reset();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          constraints: BoxConstraints(
            minHeight: ResponsiveUtils.getResponsiveSize(
              context,
              mobile: isSmallMobile ? 80 : 90,
              tablet: 100,
              desktop: isLaptop ? 105 : 110,
            ),
          ),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (widget.gradient is LinearGradient
                        ? (widget.gradient as LinearGradient).colors.first
                        : Theme.of(context).shadowColor)
                    .withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Watermark
                  if (widget.waterMarkIcon != null)
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        widget.waterMarkIcon,
                        size: 80,
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),

                  // Shine Effect
                  if (isHovered)
                    AnimatedBuilder(
                      animation: _shineController,
                      builder: (context, child) {
                        return Positioned(
                          top: 0,
                          bottom: 0,
                          left: -50 +
                              (constraints.maxWidth + 100) *
                                  _shineController.value,
                          width: 50,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(0.3),
                                  Colors.white.withOpacity(0.0),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            transform: Matrix4.skewX(-0.3),
                          ),
                        );
                      },
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (widget.tag != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  widget.tag!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(),
                            Icon(widget.icon, color: Colors.white70, size: 20),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          widget.value,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        constraints: BoxConstraints(
          minHeight: ResponsiveUtils.getResponsiveSize(
            context,
            mobile: isSmallMobile ? 80 : 90,
            tablet: 100,
            desktop: isLaptop ? 105 : 110,
          ),
        ),
        padding: ResponsiveUtils.getResponsivePadding(
          context,
          mobile: EdgeInsets.all(isSmallMobile ? 10 : 12),
          tablet: const EdgeInsets.all(14),
          desktop: EdgeInsets.all(isLaptop ? 15 : 16),
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadius(
              context,
              mobile: isSmallMobile ? 8 : 10,
              tablet: 11,
              desktop: isLaptop ? 11.5 : 12,
            ),
          ),
          border: Border.all(
            color: isHovered
                ? widget.trendColor.withOpacity(0.3)
                : Theme.of(context).dividerColor.withOpacity(0.1),
            width: isHovered ? 2 : 1,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: widget.trendColor.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate sizes based on card dimensions
              final cardHeight = constraints.maxHeight;
              final cardWidth = constraints.maxWidth;
              final isLaptopSize = ResponsiveUtils.isLaptop(context);
              final isSmallCard = cardHeight < 100 || cardWidth < 120;
              final isMediumCard = cardHeight < 140 || cardWidth < 160;

              // Scale factors based on card size
              final scaleFactor =
                  isSmallCard ? 0.75 : (isMediumCard ? 0.85 : 1.0);

              // Calculate proportional sizes
              final iconSize = (cardHeight * 0.35 * scaleFactor).clamp(
                24.0,
                48.0,
              );
              final valueFontSize = (cardHeight * 0.35 * scaleFactor).clamp(
                18.0,
                isLaptopSize ? 28.0 : 30.0,
              );
              final labelFontSize = (cardHeight * 0.19 * scaleFactor).clamp(
                11.0,
                isLaptopSize ? 14.0 : 15.0,
              );
              final subtitleFontSize = (cardHeight * 0.13 * scaleFactor).clamp(
                11.0,
                16.0,
              );
              final trendFontSize = (cardHeight * 0.10 * scaleFactor).clamp(
                10.0,
                16.0,
              );
              final spacing1 = (cardHeight * 0.08 * scaleFactor).clamp(
                4.0,
                14.0,
              );
              final spacing2 = (cardHeight * 0.03 * scaleFactor).clamp(
                2.0,
                6.0,
              );
              final spacing3 = (cardHeight * 0.02 * scaleFactor).clamp(
                1.0,
                4.0,
              );
              final trendPaddingH = (cardWidth * 0.06 * scaleFactor).clamp(
                4.0,
                12.0,
              );
              final trendPaddingV = (cardHeight * 0.03 * scaleFactor).clamp(
                2.0,
                6.0,
              );
              final borderRadius = (cardHeight * 0.06 * scaleFactor).clamp(
                4.0,
                10.0,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max, // Push to edges
                    children: [
                      Flexible(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: trendPaddingH,
                            vertical: trendPaddingV,
                          ),
                          decoration: BoxDecoration(
                            color: isHovered
                                ? widget.trendColor.withOpacity(0.3)
                                : widget.trendColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          child: Text(
                            widget.trend,
                            style: TextStyle(
                              color: widget.trendColor,
                              fontSize: trendFontSize,
                              fontWeight:
                                  isHovered ? FontWeight.w700 : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      AnimatedScale(
                        scale: isHovered ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          widget.icon,
                          color: isHovered
                              ? widget.trendColor
                              : Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withOpacity(0.7) ??
                                  Colors.white.withOpacity(0.7),
                          size: iconSize,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing1),
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: Theme.of(
                                context,
                              ).textTheme.headlineLarge?.color ??
                              Colors.white,
                          fontSize: valueFontSize,
                          fontWeight:
                              isHovered ? FontWeight.w900 : FontWeight.bold,
                        ),
                        child: Text(
                          widget.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing2),
                  Flexible(
                    flex: 2,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: isHovered
                              ? widget.trendColor
                              : Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.color ??
                                  Colors.white,
                          fontSize: labelFontSize,
                          fontWeight:
                              isHovered ? FontWeight.w700 : FontWeight.w600,
                        ),
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  if (widget.isDesktop || isTablet) ...[
                    SizedBox(height: spacing3),
                    Flexible(
                      flex: 1,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isHovered
                                ? widget.trendColor.withOpacity(0.8)
                                : Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color
                                        ?.withOpacity(0.6) ??
                                    Colors.white.withOpacity(0.6),
                            fontSize: subtitleFontSize,
                            fontWeight:
                                isHovered ? FontWeight.w600 : FontWeight.normal,
                          ),
                          child: Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Custom Attendance Detail Card showing all daily attendance information
class _AttendanceDetailCard extends StatefulWidget {
  final BuildContext context;
  final bool isClockedIn;
  final double totalHours;
  final String firstClockIn;
  final String lastClockOut;
  final String? currentSessionTime;
  final bool isDesktop;
  final VoidCallback onTap;

  const _AttendanceDetailCard({
    required this.context,
    required this.isClockedIn,
    required this.totalHours,
    required this.firstClockIn,
    required this.lastClockOut,
    required this.currentSessionTime,
    required this.isDesktop,
    required this.onTap,
  });

  @override
  State<_AttendanceDetailCard> createState() => _AttendanceDetailCardState();
}

class _AttendanceDetailCardState extends State<_AttendanceDetailCard>
    with SingleTickerProviderStateMixin {
  bool isHovered = false;
  bool _isTimerHovered = false;
  late AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  // Mobile-optimized layout - matches the design with punch in/out boxes and circular button
  Widget _buildMobileLayout(BuildContext context, bool isSmallMobile) {
    final statusColor =
        widget.isClockedIn ? CommonColors.green : CommonColors.grey;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Daily Attendance Summary
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with title and status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Daily Attendance',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.isClockedIn ? 'In' : 'Out',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // WFH Badge
                        FutureBuilder<bool>(
                          future: Provider.of<AttendanceViewModel>(
                            context,
                            listen: false,
                          ).hasApprovedWFHToday(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data == true) {
                              return Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.home_work,
                                      size: 10,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'WFH',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Punch In and Punch Out boxes side by side
                    Row(
                      children: [
                        Expanded(
                          child: _buildPunchTimeBox(
                            context,
                            'Punch In',
                            widget.firstClockIn,
                            const Color(0xFFE3F2FD), // Light blue
                            Icons.login,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildPunchTimeBox(
                            context,
                            'Punch Out',
                            widget.isClockedIn ? 'Active' : widget.lastClockOut,
                            const Color(0xFFFFE0B2), // Light orange
                            Icons.logout,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right side: Circular action button
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: widget.onTap,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: widget.isClockedIn
                            ? CommonColors.red
                            : CommonColors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (widget.isClockedIn
                                    ? CommonColors.red
                                    : CommonColors.green)
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isClockedIn
                            ? Icons.fingerprint
                            : Icons.fingerprint,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isClockedIn ? 'Punch Out' : 'Punch In',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
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

  // Helper widget for punch time boxes
  Widget _buildPunchTimeBox(
    BuildContext context,
    String label,
    String time,
    Color backgroundColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallMobile = MediaQuery.of(context).size.width < 360;
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    // Mobile-specific layout
    if (isMobile && !isTablet) {
      return _buildMobileLayout(context, isSmallMobile);
    }

    final isClockedIn = widget.isClockedIn;

    // Gradients
    final activeGradient = const LinearGradient(
      colors: [Color(0xFF06b6d4), Color(0xFF3b82f6)], // Cyan to Blue
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final inactiveGradient = const LinearGradient(
      colors: [Color(0xFF64748b), Color(0xFF475569)], // Slate/Grey
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final currentGradient = isClockedIn ? activeGradient : inactiveGradient;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => isHovered = true);
        _shineController.repeat(reverse: false);
      },
      onExit: (_) {
        setState(() => isHovered = false);
        _shineController.stop();
        _shineController.reset();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: currentGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isClockedIn ? const Color(0xFF3b82f6) : Colors.black)
                    .withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  // Watermark Icon (Clock)
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      Icons.access_time_filled,
                      size: 100,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),

                  // Shine Effect
                  if (isHovered)
                    AnimatedBuilder(
                      animation: _shineController,
                      builder: (context, child) {
                        return Positioned(
                          top: 0,
                          bottom: 0,
                          left: -50 +
                              (constraints.maxWidth + 100) *
                                  _shineController.value,
                          width: 60,
                          child: Container(
                            transform: Matrix4.skewX(-0.3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.0),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Content Row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          // Left Side: Punch In
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Punch In:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.firstClockIn != '--:--'
                                      ? widget.firstClockIn
                                      : '--:--',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Icons Row
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.history,
                                      size: 16,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Vertical Divider
                          Container(
                            width: 1,
                            color: Colors.white.withOpacity(0.2),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),

                          // Right Side: Punch Out / Status
                          // Right Side: Punch Out / Status
                          Expanded(
                            child: isClockedIn
                                ? MouseRegion(
                                    onEnter: (_) =>
                                        setState(() => _isTimerHovered = true),
                                    onExit: (_) =>
                                        setState(() => _isTimerHovered = false),
                                    child: Stack(
                                      alignment: Alignment.centerLeft,
                                      children: [
                                        // Timer View (Default)
                                        AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          opacity: _isTimerHovered ? 0.0 : 1.0,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Status:',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white
                                                      .withOpacity(0.8),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Active',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                widget.currentSessionTime ??
                                                    '00s',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontFamily: 'monospace',
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Punch Out Button (On Hover)
                                        AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          opacity: _isTimerHovered ? 1.0 : 0.0,
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.2),
                                                        blurRadius: 10,
                                                        offset: const Offset(
                                                          0,
                                                          4,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.fingerprint,
                                                    color: CommonColors.red,
                                                    size: 28,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                const Text(
                                                  'Punch Out',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.fingerprint,
                                          color: CommonColors.blue,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Punch In',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
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
}

class _TaskItemWidget extends HookWidget {
  final Task task;
  final ValueNotifier<Set<String>> acceptedTasks;
  final ValueNotifier<Task?> clockedInTask;
  final bool isDesktop;
  final bool isMobile;
  final bool isSmallMobile;
  final Function(Task) onAcceptTask;
  final Function(Task) onRejectTask;
  final Function(Task) onClockInOut;
  final String Function(int?) getTaskStatusName;
  final ValueNotifier<int> refreshTrigger;

  const _TaskItemWidget({
    required this.task,
    required this.acceptedTasks,
    required this.clockedInTask,
    required this.isDesktop,
    required this.isMobile,
    required this.isSmallMobile,
    required this.onAcceptTask,
    required this.onRejectTask,
    required this.onClockInOut,
    required this.getTaskStatusName,
    required this.refreshTrigger,
  });

  @override
  Widget build(BuildContext context) {
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 400),
    );

    final scaleAnimation = useAnimation(
      Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
      ),
    );

    // Use hooks to manage assignment status
    final assignmentStatus = useState<Map<String, dynamic>?>(null);
    final isLoadingAssignment = useState<bool>(true);

    // Fetch assignment status when widget builds
    useEffect(() {
      _fetchAssignmentStatus(context, assignmentStatus, isLoadingAssignment);
      return null;
    }, []);

    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: scaleAnimation,
          child: _buildModernTaskCard(
            context,
            task,
            acceptedTasks,
            clockedInTask,
            isDesktop,
            isMobile,
            isSmallMobile,
            onAcceptTask,
            onRejectTask,
            onClockInOut,
            getTaskStatusName,
            assignmentStatus.value,
            isLoadingAssignment.value,
            refreshTrigger,
          ),
        );
      },
    );
  }

  // Helper method to fetch assignment status
  Future<void> _fetchAssignmentStatus(
    BuildContext context,
    ValueNotifier<Map<String, dynamic>?> assignmentStatus,
    ValueNotifier<bool> isLoadingAssignment,
  ) async {
    try {
      isLoadingAssignment.value = true;

      // Get TaskViewModel instance from context
      final taskViewModel = Provider.of<TaskViewModel>(context, listen: false);

      final assignment = await taskViewModel.fetchEmployeeAssignment(
        task.taskId,
      );
      assignmentStatus.value = assignment;
    } catch (e) {
      print('Error fetching assignment status: $e');
      assignmentStatus.value = null;
    } finally {
      isLoadingAssignment.value = false;
    }
  }

  // Helper method to format expected completion date
  String _formatExpectedDate(dynamic dateValue) {
    try {
      if (dateValue is String) {
        final date = _parseUtcToLocal(dateValue);
        return '${date.day}/${date.month}/${date.year}';
      } else if (dateValue is DateTime) {
        return '${dateValue.day}/${dateValue.month}/${dateValue.year}';
      }
      return 'Date not available';
    } catch (e) {
      return 'Invalid date';
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

  // Helper method to build the task card
  Widget _buildModernTaskCard(
    BuildContext context,
    Task task,
    ValueNotifier<Set<String>> acceptedTasks,
    ValueNotifier<Task?> clockedInTask,
    bool isDesktop,
    bool isMobile,
    bool isSmallMobile,
    Function(Task) onAcceptTask,
    Function(Task) onRejectTask,
    Function(Task) onClockInOut,
    String Function(int?) getTaskStatusName,
    Map<String, dynamic>? assignmentStatus,
    bool isLoadingAssignment,
    ValueNotifier<int> refreshTrigger,
  ) {
    // Get ClockViewModel from context
    final clockViewModel = Provider.of<ClockViewModel>(context, listen: false);

    bool isCurrentlyClockedIn =
        clockViewModel.clockedInTask?.taskId == task.taskId;

    // Check if task is accepted - prioritize database status over local state
    bool isAcceptedLocally = acceptedTasks.value.contains(task.taskId);

    // Use assignment status if available, otherwise fall back to task status
    bool isAcceptedInDatabase = false;
    bool isRejectedInDatabase = false;
    bool isCompletedInDatabase = false;
    bool isDelayedInDatabase = false;
    bool isInProgressInDatabase = false;

    if (assignmentStatus != null) {
      isAcceptedInDatabase = assignmentStatus['is_accepted'] == true;
      isRejectedInDatabase = assignmentStatus['is_rejected'] == true;
      isCompletedInDatabase =
          assignmentStatus['task_status'] == 4; // 4 = completed
      isDelayedInDatabase = assignmentStatus['task_status'] == 6; // 6 = delayed
      isInProgressInDatabase =
          assignmentStatus['task_status'] == 3; // 3 = in progress
    } else {
      // Fallback to assignment status from enriched task data
      // Since we're using the new schema, we need to check assignment data
      isAcceptedInDatabase = false; // Default to false if no assignment data
      isRejectedInDatabase = false; // Default to false if no assignment data
      isCompletedInDatabase = false; // Default to false if no assignment data
      isDelayedInDatabase = false; // Default to false if no assignment data
      isInProgressInDatabase = false; // Default to false if no assignment data
    }

    // If database status indicates no assignment, remove from local accepted tasks and clock out if needed
    if (assignmentStatus == null && isAcceptedLocally) {
      final updatedAcceptedTasks = Set<String>.from(acceptedTasks.value);
      updatedAcceptedTasks.remove(task.taskId);
      acceptedTasks.value = updatedAcceptedTasks;
      print(
        '🔄 Removed task ${task.taskId} from local accepted tasks (no assignment data)',
      );
      isAcceptedLocally = false;

      // If currently clocked into this task, it will be handled by ClockViewModel
      if (clockViewModel.clockedInTask?.taskId == task.taskId) {
        print(
          '⚠️ Task ${task.taskId} has no assignment data but is clocked in - ClockViewModel will handle state',
        );
      }
    }

    // Database status takes priority - only use local state if DB status is unclear
    bool isAccepted =
        isAcceptedInDatabase || (assignmentStatus != null && isAcceptedLocally);

    // Debug logging for all tasks to check button visibility
    print('🔍 Task Card Debug for ${task.taskName}:');
    print('  - Task ID: ${task.taskId}');
    print('  - Assignment Status: $assignmentStatus');
    print('  - isAcceptedLocally: $isAcceptedLocally');
    print('  - isAcceptedInDatabase: $isAcceptedInDatabase');
    print('  - isRejectedInDatabase: $isRejectedInDatabase');
    print('  - isCompletedInDatabase: $isCompletedInDatabase');
    print('  - isDelayedInDatabase: $isDelayedInDatabase');
    print('  - isInProgressInDatabase: $isInProgressInDatabase');
    print('  - Final isAccepted: $isAccepted');
    print('  - isCurrentlyClockedIn: $isCurrentlyClockedIn');
    print(
      '  - Should show Accept/Reject buttons: ${!isAccepted && !isRejectedInDatabase && !isCompletedInDatabase}',
    );
    print(
      '  - Should show Clock In button: ${isAccepted && !isCurrentlyClockedIn && clockViewModel.clockedInTask == null && !isCompletedInDatabase}',
    );
    print(
      '  - Should show Complete button: ${isAccepted && !isCompletedInDatabase}',
    );

    return Container(
      margin: EdgeInsets.only(
        bottom: isSmallMobile
            ? 20 // Increased from 12 for better mobile separation
            : isMobile
                ? 24 // Increased from 16 for better mobile separation
                : 28,
      ), // Increased from 20 for better separation
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(
          20,
        ), // Increased from 16 for modern mobile look
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isCompletedInDatabase
              ? CommonColors.blue.withOpacity(0.4)
              : isDelayedInDatabase
                  ? CommonColors.orange.withOpacity(0.4)
                  : isInProgressInDatabase
                      ? CommonColors.purple.withOpacity(0.4)
                      : isAccepted
                          ? CommonColors.green.withOpacity(0.3)
                          : isRejectedInDatabase
                              ? CommonColors.red.withOpacity(0.3)
                              : CommonColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient background
            Container(
              width: double.infinity,
              padding: ResponsiveUtils.getResponsivePadding(
                context,
                mobile: EdgeInsets.all(
                  isSmallMobile ? 18 : 20,
                ), // Increased padding for better mobile experience
                tablet: const EdgeInsets.all(22),
                desktop: const EdgeInsets.all(24),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isCompletedInDatabase
                      ? [
                          CommonColors.blue.withOpacity(0.15),
                          CommonColors.blue.withOpacity(0.05),
                        ]
                      : isDelayedInDatabase
                          ? [
                              CommonColors.orange.withOpacity(0.15),
                              CommonColors.orange.withOpacity(0.05),
                            ]
                          : isInProgressInDatabase
                              ? [
                                  CommonColors.purple.withOpacity(0.15),
                                  CommonColors.purple.withOpacity(0.05),
                                ]
                              : isAccepted
                                  ? [
                                      CommonColors.green.withOpacity(0.1),
                                      CommonColors.green.withOpacity(0.05),
                                    ]
                                  : isRejectedInDatabase
                                      ? [
                                          CommonColors.red.withOpacity(0.1),
                                          CommonColors.red.withOpacity(0.05),
                                        ]
                                      : [
                                          CommonColors.primary.withOpacity(0.1),
                                          CommonColors.primary
                                              .withOpacity(0.05),
                                        ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task name and status badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.taskName ?? 'Untitled Task',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Theme.of(
                                          context,
                                        ).textTheme.titleLarge?.color ??
                                        Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color ??
                                        Colors.black,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: isSmallMobile
                                  ? 16
                                  : 18, // Increased font size for better mobile readability
                              tablet: 19,
                              desktop: 20,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: ResponsiveUtils.getResponsivePadding(
                          context,
                          mobile: EdgeInsets.symmetric(
                            horizontal: isSmallMobile
                                ? 12
                                : 14, // Increased horizontal padding for better mobile touch targets
                            vertical: isSmallMobile
                                ? 6
                                : 8, // Increased vertical padding for better mobile touch targets
                          ),
                          tablet: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),
                          desktop: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        decoration: BoxDecoration(
                          color: isCompletedInDatabase
                              ? CommonColors.blue
                              : isDelayedInDatabase
                                  ? CommonColors.orange
                                  : isInProgressInDatabase
                                      ? CommonColors.purple
                                      : isAccepted
                                          ? CommonColors.green
                                          : isRejectedInDatabase
                                              ? CommonColors.red
                                              : CommonColors.orange,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (isCompletedInDatabase
                                      ? CommonColors.blue
                                      : isDelayedInDatabase
                                          ? CommonColors.orange
                                          : isInProgressInDatabase
                                              ? CommonColors.purple
                                              : isAccepted
                                                  ? CommonColors.green
                                                  : isRejectedInDatabase
                                                      ? CommonColors.red
                                                      : CommonColors.orange)
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          isCompletedInDatabase
                              ? '🎯 Completed'
                              : isDelayedInDatabase
                                  ? '⏰ Delayed'
                                  : isInProgressInDatabase
                                      ? '🔄 In Progress'
                                      : isAccepted
                                          ? '✓ Accepted'
                                          : isRejectedInDatabase
                                              ? '✗ Rejected'
                                              : '⏳ Pending',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: isSmallMobile
                                  ? 11
                                  : 12, // Increased font size for better mobile readability
                              tablet: 12.5,
                              desktop: 13,
                            ),
                            fontWeight: FontWeight
                                .w700, // Increased font weight for better mobile visibility
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Project name with icon
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: ResponsiveUtils.getResponsiveIconSize(
                          context,
                          mobile: isSmallMobile
                              ? 16
                              : 18, // Increased icon size for better mobile visibility
                          tablet: 19,
                          desktop: 20,
                        ),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue[300]
                            : Theme.of(context).primaryColor,
                      ),
                      SizedBox(
                        width: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: isSmallMobile
                              ? 6
                              : 8, // Increased spacing for better mobile layout
                          tablet: 9,
                          desktop: 10,
                        ),
                      ),
                      Text(
                        task.projectDetails?['project_name'] ?? 'No Project',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue[300]
                              : Theme.of(context).primaryColor,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: isSmallMobile
                                ? 13
                                : 14, // Increased font size for better mobile readability
                            tablet: 14.5,
                            desktop: 15,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content section
            Padding(
              padding: ResponsiveUtils.getResponsivePadding(
                context,
                mobile: EdgeInsets.all(
                  isSmallMobile ? 18 : 20,
                ), // Increased padding for better mobile experience
                tablet: const EdgeInsets.all(22),
                desktop: const EdgeInsets.all(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task description
                  if (task.taskDescription != null &&
                      task.taskDescription!.isNotEmpty) ...[
                    Text(
                      task.taskDescription!,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]?.withOpacity(0.8)
                            : Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.8) ??
                                Colors.grey,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: isSmallMobile
                              ? 13
                              : 14, // Increased font size for better mobile readability
                          tablet: 14.5,
                          desktop: 15,
                        ),
                        fontWeight: FontWeight.w500,
                        height:
                            1.5, // Increased line height for better mobile readability
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: isSmallMobile ? 10 : 11,
                        tablet: 11.5,
                        desktop: 12,
                      ),
                    ),
                  ],

                  // Task details row
                  Row(
                    children: [
                      // Time info
                      Expanded(
                        child: Container(
                          padding: ResponsiveUtils.getResponsivePadding(
                            context,
                            mobile: EdgeInsets.symmetric(
                              horizontal: isSmallMobile ? 10 : 11,
                              vertical: isSmallMobile ? 6 : 7,
                            ),
                            tablet: const EdgeInsets.symmetric(
                              horizontal: 11.5,
                              vertical: 7.5,
                            ),
                            desktop: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? Colors.grey[800]?.withOpacity(0.5)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.getResponsiveBorderRadius(
                                context,
                                mobile: isSmallMobile ? 6 : 7,
                                tablet: 7.5,
                                desktop: 8,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_outlined,
                                size: ResponsiveUtils.getResponsiveIconSize(
                                  context,
                                  mobile: isSmallMobile ? 14 : 15,
                                  tablet: 15.5,
                                  desktop: 16,
                                ),
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.blue[300]
                                    : Theme.of(context).primaryColor,
                              ),
                              SizedBox(
                                width: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: isSmallMobile ? 4 : 5,
                                  tablet: 5.5,
                                  desktop: 6,
                                ),
                              ),
                              Text(
                                '${_formatDateTime(task.assignedAt) ?? 'N/A'} - ${_formatDateTime(task.devCompletedAt) ?? 'N/A'}',
                                style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[300]?.withOpacity(0.8)
                                      : Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withOpacity(0.8) ??
                                          Colors.grey,
                                  fontSize:
                                      ResponsiveUtils.getResponsiveFontSize(
                                    context,
                                    mobile: isSmallMobile ? 10 : 11,
                                    tablet: 11.5,
                                    desktop: 12,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: isSmallMobile ? 6 : 7,
                          tablet: 7.5,
                          desktop: 8,
                        ),
                      ),
                      // Duration info
                      Container(
                        padding: ResponsiveUtils.getResponsivePadding(
                          context,
                          mobile: EdgeInsets.symmetric(
                            horizontal: isSmallMobile ? 10 : 11,
                            vertical: isSmallMobile ? 6 : 7,
                          ),
                          tablet: const EdgeInsets.symmetric(
                            horizontal: 11.5,
                            vertical: 7.5,
                          ),
                          desktop: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue[900]?.withOpacity(0.3)
                              : Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getResponsiveBorderRadius(
                              context,
                              mobile: isSmallMobile ? 6 : 7,
                              tablet: 7.5,
                              desktop: 8,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: ResponsiveUtils.getResponsiveIconSize(
                                context,
                                mobile: isSmallMobile ? 14 : 15,
                                tablet: 15.5,
                                desktop: 16,
                              ),
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.blue[300]
                                  : Colors.blue[600],
                            ),
                            SizedBox(
                              width: ResponsiveUtils.getResponsiveSpacing(
                                context,
                                mobile: isSmallMobile ? 4 : 5,
                                tablet: 5.5,
                                desktop: 6,
                              ),
                            ),
                            Text(
                              task.taskDuration ?? 'N/A',
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.blue[300]
                                    : Colors.blue[600],
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: isSmallMobile ? 10 : 11,
                                  tablet: 11.5,
                                  desktop: 12,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: isSmallMobile ? 8 : 10,
                      tablet: 12,
                      desktop: 14,
                    ),
                  ),

                  // Action buttons section
                  if (isLoadingAssignment) ...[
                    Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          CommonColors.primary,
                        ),
                      ),
                    ),
                  ] else if (!isAccepted &&
                      !isRejectedInDatabase &&
                      !isCompletedInDatabase) ...[
                    // Accept/Reject buttons for pending tasks
                    isSmallMobile
                        ? Column(
                            children: [
                              // Reject button
                              SizedBox(
                                width: double.infinity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveUtils.getResponsiveBorderRadius(
                                        context,
                                        mobile: isSmallMobile
                                            ? 16
                                            : 18, // Increased border radius for modern mobile look
                                        tablet: 20,
                                        desktop: 22,
                                      ),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        CommonColors.red.withOpacity(0.1),
                                        CommonColors.red.withOpacity(0.05),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: CommonColors.red.withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => onRejectTask(task),
                                    child: Text(
                                      'Reject',
                                      style: TextStyle(
                                        fontSize: ResponsiveUtils
                                            .getResponsiveFontSize(
                                          context,
                                          mobile: isSmallMobile ? 12 : 13,
                                          tablet: 14,
                                          desktop: 15,
                                        ),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: CommonColors.red,
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(
                                        vertical: ResponsiveUtils
                                            .getResponsiveSpacing(
                                          context,
                                          mobile: isSmallMobile ? 12 : 14,
                                          tablet: 16,
                                          desktop: 18,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          ResponsiveUtils
                                              .getResponsiveBorderRadius(
                                            context,
                                            mobile: isSmallMobile ? 16 : 18,
                                            tablet: 20,
                                            desktop: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: isSmallMobile ? 8 : 10,
                                  tablet: 12,
                                  desktop: 14,
                                ),
                              ),
                              // Accept button
                              SizedBox(
                                width: double.infinity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveUtils.getResponsiveBorderRadius(
                                        context,
                                        mobile: isSmallMobile ? 16 : 18,
                                        tablet: 20,
                                        desktop: 22,
                                      ),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        CommonColors.green.withOpacity(0.15),
                                        CommonColors.green.withOpacity(0.08),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: CommonColors.green.withOpacity(
                                        0.25,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => onAcceptTask(task),
                                    child: Text(
                                      'Accept',
                                      style: TextStyle(
                                        fontSize: ResponsiveUtils
                                            .getResponsiveFontSize(
                                          context,
                                          mobile: isSmallMobile ? 12 : 13,
                                          tablet: 14,
                                          desktop: 15,
                                        ),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: CommonColors.green,
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(
                                        vertical: ResponsiveUtils
                                            .getResponsiveSpacing(
                                          context,
                                          mobile: isSmallMobile ? 12 : 14,
                                          tablet: 16,
                                          desktop: 18,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          ResponsiveUtils
                                              .getResponsiveBorderRadius(
                                            context,
                                            mobile: isSmallMobile ? 16 : 18,
                                            tablet: 20,
                                            desktop: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveUtils.getResponsiveBorderRadius(
                                        context,
                                        mobile: isSmallMobile
                                            ? 16
                                            : 18, // Increased border radius for modern mobile look
                                        tablet: 20,
                                        desktop: 22,
                                      ),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        CommonColors.red.withOpacity(0.1),
                                        CommonColors.red.withOpacity(0.05),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: CommonColors.red.withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => onRejectTask(task),
                                    child: Text(
                                      'Reject',
                                      style: TextStyle(
                                        fontSize: ResponsiveUtils
                                            .getResponsiveFontSize(
                                          context,
                                          mobile: isSmallMobile
                                              ? 14
                                              : 15, // Increased font size for better mobile readability
                                          tablet: 16,
                                          desktop: 17,
                                        ),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: CommonColors.red,
                                      padding:
                                          ResponsiveUtils.getResponsivePadding(
                                        context,
                                        mobile: EdgeInsets.symmetric(
                                          horizontal: isSmallMobile ? 12 : 16,
                                          vertical: isSmallMobile ? 10 : 12,
                                        ),
                                        tablet: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 14,
                                        ),
                                        desktop: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 16,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          ResponsiveUtils
                                              .getResponsiveBorderRadius(
                                            context,
                                            mobile: isSmallMobile ? 12 : 14,
                                            tablet: 16,
                                            desktop: 18,
                                          ),
                                        ),
                                      ),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: isSmallMobile
                                      ? 16
                                      : 18, // Increased spacing for better mobile separation
                                  tablet: 20,
                                  desktop: 22,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveUtils.getResponsiveBorderRadius(
                                        context,
                                        mobile: isSmallMobile ? 12 : 14,
                                        tablet: 16,
                                        desktop: 18,
                                      ),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        CommonColors.green.withOpacity(0.1),
                                        CommonColors.green.withOpacity(0.05),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: CommonColors.green.withOpacity(
                                        0.2,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => onAcceptTask(task),
                                    child: Text(
                                      'Accept',
                                      style: TextStyle(
                                        fontSize: ResponsiveUtils
                                            .getResponsiveFontSize(
                                          context,
                                          mobile: isSmallMobile ? 12 : 13,
                                          tablet: 14,
                                          desktop: 15,
                                        ),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: CommonColors.green,
                                      padding:
                                          ResponsiveUtils.getResponsivePadding(
                                        context,
                                        mobile: EdgeInsets.symmetric(
                                          horizontal: isSmallMobile ? 12 : 16,
                                          vertical: isSmallMobile ? 10 : 12,
                                        ),
                                        tablet: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 14,
                                        ),
                                        desktop: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 16,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          ResponsiveUtils
                                              .getResponsiveBorderRadius(
                                            context,
                                            mobile: isSmallMobile ? 12 : 14,
                                            tablet: 16,
                                            desktop: 18,
                                          ),
                                        ),
                                      ),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ] else if (isAccepted && !isCompletedInDatabase) ...[
                    // Show Clock In/Out and Complete buttons for accepted tasks
                    Column(
                      children: [
                        if (!isCurrentlyClockedIn &&
                            clockViewModel.clockedInTask == null) ...[
                          // Clock In button
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  ResponsiveUtils.getResponsiveBorderRadius(
                                    context,
                                    mobile: isSmallMobile
                                        ? 20
                                        : 22, // Increased border radius for modern mobile look
                                    tablet: 24,
                                    desktop: 26,
                                  ),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    CommonColors.primary.withOpacity(0.15),
                                    CommonColors.primary.withOpacity(0.08),
                                  ],
                                ),
                                border: Border.all(
                                  color: CommonColors.primary.withOpacity(0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: ElevatedButton(
                                onPressed: () => onClockInOut(task),
                                child: Text(
                                  'Clock In',
                                  style: TextStyle(
                                    fontSize:
                                        ResponsiveUtils.getResponsiveFontSize(
                                      context,
                                      mobile: isSmallMobile
                                          ? 15
                                          : 16, // Increased font size for better mobile readability
                                      tablet: 17,
                                      desktop: 18,
                                    ),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: CommonColors.primary,
                                  padding: ResponsiveUtils.getResponsivePadding(
                                    context,
                                    mobile: EdgeInsets.symmetric(
                                      horizontal: isSmallMobile ? 16 : 20,
                                      vertical: isSmallMobile ? 12 : 14,
                                    ),
                                    tablet: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 16,
                                    ),
                                    desktop: const EdgeInsets.symmetric(
                                      horizontal: 26,
                                      vertical: 18,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveUtils.getResponsiveBorderRadius(
                                        context,
                                        mobile: isSmallMobile ? 16 : 18,
                                        tablet: 20,
                                        desktop: 22,
                                      ),
                                    ),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        ] else if (isCurrentlyClockedIn) ...[
                          // Clock Out button
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  ResponsiveUtils.getResponsiveBorderRadius(
                                    context,
                                    mobile: isSmallMobile ? 16 : 18,
                                    tablet: 20,
                                    desktop: 22,
                                  ),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    CommonColors.red.withOpacity(0.15),
                                    CommonColors.red.withOpacity(0.08),
                                  ],
                                ),
                                border: Border.all(
                                  color: CommonColors.red.withOpacity(0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: ElevatedButton(
                                onPressed: () => onClockInOut(task),
                                child: Text(
                                  'Clock Out',
                                  style: TextStyle(
                                    fontSize:
                                        ResponsiveUtils.getResponsiveFontSize(
                                      context,
                                      mobile: isSmallMobile ? 13 : 14,
                                      tablet: 15,
                                      desktop: 16,
                                    ),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: CommonColors.red,
                                  padding: ResponsiveUtils.getResponsivePadding(
                                    context,
                                    mobile: EdgeInsets.symmetric(
                                      horizontal: isSmallMobile ? 16 : 20,
                                      vertical: isSmallMobile ? 12 : 14,
                                    ),
                                    tablet: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 16,
                                    ),
                                    desktop: const EdgeInsets.symmetric(
                                      horizontal: 26,
                                      vertical: 18,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveUtils.getResponsiveBorderRadius(
                                        context,
                                        mobile: isSmallMobile ? 16 : 18,
                                        tablet: 20,
                                        desktop: 22,
                                      ),
                                    ),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        ],

                        SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: isSmallMobile ? 6 : 8,
                            tablet: 10,
                            desktop: 12,
                          ),
                        ),

                        // Complete button
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.getResponsiveBorderRadius(
                                  context,
                                  mobile: isSmallMobile
                                      ? 20
                                      : 22, // Increased border radius for modern mobile look
                                  tablet: 24,
                                  desktop: 26,
                                ),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  CommonColors.blue.withOpacity(0.15),
                                  CommonColors.blue.withOpacity(0.08),
                                ],
                              ),
                              border: Border.all(
                                color: CommonColors.blue.withOpacity(0.25),
                                width: 1.5,
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () =>
                                  _showCompleteTaskDialog(context, task),
                              child: Text(
                                'Mark as Complete',
                                style: TextStyle(
                                  fontSize:
                                      ResponsiveUtils.getResponsiveFontSize(
                                    context,
                                    mobile: isSmallMobile
                                        ? 15
                                        : 16, // Increased font size for better mobile readability
                                    tablet: 17,
                                    desktop: 18,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: CommonColors.blue,
                                padding: ResponsiveUtils.getResponsivePadding(
                                  context,
                                  mobile: EdgeInsets.symmetric(
                                    horizontal: isSmallMobile ? 16 : 20,
                                    vertical: isSmallMobile ? 10 : 12,
                                  ),
                                  tablet: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 14,
                                  ),
                                  desktop: const EdgeInsets.symmetric(
                                    horizontal: 26,
                                    vertical: 16,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveUtils.getResponsiveBorderRadius(
                                      context,
                                      mobile: isSmallMobile ? 16 : 18,
                                      tablet: 20,
                                      desktop: 22,
                                    ),
                                  ),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: isSmallMobile ? 6 : 8,
                            tablet: 10,
                            desktop: 12,
                          ),
                        ),

                        // Delay button
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                ResponsiveUtils.getResponsiveBorderRadius(
                                  context,
                                  mobile: isSmallMobile
                                      ? 20
                                      : 22, // Increased border radius for modern mobile look
                                  tablet: 24,
                                  desktop: 26,
                                ),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  CommonColors.orange.withOpacity(0.15),
                                  CommonColors.orange.withOpacity(0.08),
                                ],
                              ),
                              border: Border.all(
                                color: CommonColors.orange.withOpacity(0.25),
                                width: 1.5,
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () =>
                                  _showDelayTaskDialog(context, task),
                              child: Text(
                                'Mark as Delayed',
                                style: TextStyle(
                                  fontSize:
                                      ResponsiveUtils.getResponsiveFontSize(
                                    context,
                                    mobile: isSmallMobile
                                        ? 15
                                        : 16, // Increased font size for better mobile readability
                                    tablet: 17,
                                    desktop: 18,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: CommonColors.orange,
                                padding: ResponsiveUtils.getResponsivePadding(
                                  context,
                                  mobile: EdgeInsets.symmetric(
                                    horizontal: isSmallMobile ? 16 : 20,
                                    vertical: isSmallMobile ? 10 : 12,
                                  ),
                                  tablet: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 14,
                                  ),
                                  desktop: const EdgeInsets.symmetric(
                                    horizontal: 26,
                                    vertical: 16,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveUtils.getResponsiveBorderRadius(
                                      context,
                                      mobile: isSmallMobile ? 16 : 18,
                                      tablet: 20,
                                      desktop: 22,
                                    ),
                                  ),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (isCompletedInDatabase) ...[
                    // Completed status with celebration
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                      ), // Increased padding for better mobile experience
                      decoration: BoxDecoration(
                        color: CommonColors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          16,
                        ), // Increased border radius for modern mobile look
                        border: Border.all(
                          color: CommonColors.blue.withOpacity(0.3),
                          width:
                              1.5, // Increased border width for better mobile visibility
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.celebration,
                                size: 20,
                                color: CommonColors.blue,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Task Completed! 🎉',
                                style: TextStyle(
                                  color: CommonColors.blue,
                                  fontSize:
                                      18, // Increased font size for better mobile readability
                                  fontWeight: FontWeight
                                      .w700, // Increased font weight for better mobile visibility
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 8,
                          ), // Increased spacing for better mobile layout
                          Text(
                            'Great job! This task has been marked as complete.',
                            style: TextStyle(
                              color: CommonColors.blue.withOpacity(0.8),
                              fontSize:
                                  14, // Increased font size for better mobile readability
                              fontWeight: FontWeight
                                  .w600, // Increased font weight for better mobile visibility
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isDelayedInDatabase) ...[
                    // Delayed status with enhanced UI
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                      ), // Increased padding for better mobile experience
                      decoration: BoxDecoration(
                        color: CommonColors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          16,
                        ), // Increased border radius for modern mobile look
                        border: Border.all(
                          color: CommonColors.orange.withOpacity(0.3),
                          width:
                              1.5, // Increased border width for better mobile visibility
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 20,
                                color: CommonColors.orange,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Task Delayed ⏰',
                                style: TextStyle(
                                  color: CommonColors.orange,
                                  fontSize:
                                      18, // Increased font size for better mobile readability
                                  fontWeight: FontWeight
                                      .w700, // Increased font weight for better mobile visibility
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 8,
                          ), // Increased spacing for better mobile layout
                          Text(
                            'This task has been marked as delayed.',
                            style: TextStyle(
                              color: CommonColors.orange.withOpacity(0.8),
                              fontSize:
                                  14, // Increased font size for better mobile readability
                              fontWeight: FontWeight
                                  .w600, // Increased font weight for better mobile visibility
                            ),
                          ),
                          SizedBox(height: 8),
                          // Show delay reason if available
                          if (assignmentStatus != null &&
                              assignmentStatus['delay_reason'] != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(
                                16,
                              ), // Increased padding for better mobile experience
                              decoration: BoxDecoration(
                                color: CommonColors.orange.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(
                                  12,
                                ), // Increased border radius for modern mobile look
                                border: Border.all(
                                  color: CommonColors.orange.withOpacity(0.2),
                                  width:
                                      1.5, // Increased border width for better mobile visibility
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: CommonColors.orange,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Delay Reason:',
                                        style: TextStyle(
                                          color: CommonColors.orange,
                                          fontSize:
                                              14, // Increased font size for better mobile readability
                                          fontWeight: FontWeight
                                              .w700, // Increased font weight for better mobile visibility
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 8,
                                  ), // Increased spacing for better mobile layout
                                  Text(
                                    assignmentStatus['delay_reason'] ??
                                        'No reason provided',
                                    style: TextStyle(
                                      color: CommonColors.orange.withOpacity(
                                        0.8,
                                      ),
                                      fontSize:
                                          13, // Increased font size for better mobile readability
                                      fontWeight: FontWeight
                                          .w600, // Increased font weight for better mobile visibility
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Show expected completion date if available
                          if (assignmentStatus != null &&
                              assignmentStatus['expected_completion_date'] !=
                                  null) ...[
                            SizedBox(
                              height: 12,
                            ), // Increased spacing for better mobile layout
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(
                                16,
                              ), // Increased padding for better mobile experience
                              decoration: BoxDecoration(
                                color: CommonColors.orange.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(
                                  12,
                                ), // Increased border radius for modern mobile look
                                border: Border.all(
                                  color: CommonColors.orange.withOpacity(0.2),
                                  width:
                                      1.5, // Increased border width for better mobile visibility
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: CommonColors.orange,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Expected Completion: ',
                                    style: TextStyle(
                                      color: CommonColors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _formatExpectedDate(
                                      assignmentStatus[
                                          'expected_completion_date'],
                                    ),
                                    style: TextStyle(
                                      color: CommonColors.orange.withOpacity(
                                        0.8,
                                      ),
                                      fontSize:
                                          13, // Increased font size for better mobile readability
                                      fontWeight: FontWeight
                                          .w600, // Increased font weight for better mobile visibility
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (isRejectedInDatabase) ...[
                    // Rejected status
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ), // Increased padding for better mobile experience
                      decoration: BoxDecoration(
                        color: CommonColors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          16,
                        ), // Increased border radius for modern mobile look
                        border: Border.all(
                          color: CommonColors.red.withOpacity(0.3),
                          width:
                              1.5, // Increased border width for better mobile visibility
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: CommonColors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Task Rejected',
                            style: TextStyle(
                              color: CommonColors.red,
                              fontSize:
                                  16, // Increased font size for better mobile readability
                              fontWeight: FontWeight
                                  .w700, // Increased font weight for better mobile visibility
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show complete task dialog
  void _showCompleteTaskDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              20,
            ), // Increased border radius for modern mobile look
          ),
          title: Row(
            children: [
              Icon(Icons.flag, color: CommonColors.blue, size: 24),
              SizedBox(width: 8),
              Text(
                'Complete Task',
                style: TextStyle(
                  color: CommonColors.blue,
                  fontSize:
                      20, // Increased font size for better mobile readability
                  fontWeight: FontWeight
                      .w700, // Enhanced font weight for better mobile visibility
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to mark this task as complete?',
                style: TextStyle(
                  fontSize:
                      18, // Increased font size for better mobile readability
                  fontWeight: FontWeight
                      .w500, // Added font weight for better mobile visibility
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(
                height: 12,
              ), // Increased spacing for better mobile layout
              Text(
                'Task: ${task.taskName}',
                style: TextStyle(
                  fontSize:
                      16, // Increased font size for better mobile readability
                  fontWeight: FontWeight
                      .w700, // Increased font weight for better mobile visibility
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(
                height: 20,
              ), // Increased spacing for better mobile layout
              Text(
                'This action cannot be undone.',
                style: TextStyle(
                  fontSize:
                      14, // Increased font size for better mobile readability
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight
                      .w500, // Added font weight for better mobile visibility
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ), // Increased padding for better mobile touch targets
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    12,
                  ), // Increased border radius for modern mobile look
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  fontSize:
                      16, // Increased font size for better mobile readability
                  fontWeight: FontWeight
                      .w600, // Added font weight for better mobile visibility
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _completeTask(context, task);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CommonColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ), // Increased padding for better mobile touch targets
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    12,
                  ), // Increased border radius for modern mobile look
                ),
              ),
              child: Text(
                'Complete Task',
                style: TextStyle(
                  fontSize:
                      16, // Increased font size for better mobile readability
                  fontWeight: FontWeight
                      .w600, // Added font weight for better mobile visibility
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Complete task function
  void _completeTask(BuildContext context, Task task) async {
    try {
      print('🎯 Completing task: ${task.taskName}');

      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Completing task...'),
              ],
            ),
            backgroundColor: CommonColors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Call the actual completion method from TaskViewModel
      final taskViewModel = Provider.of<TaskViewModel>(context, listen: false);
      final success = await taskViewModel.completeTask(taskId: task.taskId);

      if (success) {
        // Log the task completion action
        final logService = TaskCardLogService();
        await logService.logTaskAction(
          taskId: task.taskId,
          actionName: 'Task Completed',
          actionDescription: 'Task "${task.taskName}" was completed by user',
        );

        // Show congratulations animation
        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Task completed successfully! 🎉'),
                ],
              ),
              backgroundColor: CommonColors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Refresh the task statuses to show updated status in real-time
        print('✅ Task completed, triggering UI refresh');

        // Force a rebuild by calling setState on the parent widget
        // This will trigger the useEffect to fetch task statuses again
        if (context.mounted) {
          // We need to trigger a refresh of the parent widget
          // For now, we'll just print a message
          print('🔄 Task status change detected, UI should refresh');

          // TODO: Implement proper refresh mechanism
          // The task status should update automatically due to the useEffect
          // that watches pendingTasks.value changes

          // Trigger a refresh by updating the refresh trigger
          // This will cause the useEffect to run again and fetch updated statuses
          refreshTrigger.value = refreshTrigger.value + 1;
          print('🔄 Refresh trigger updated: ${refreshTrigger.value}');
        }
      } else {
        // Show error message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Failed to complete task. Please try again.'),
                ],
              ),
              backgroundColor: CommonColors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error completing task: $e');

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Error completing task: $e'),
              ],
            ),
            backgroundColor: CommonColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  // Show delay task dialog
  void _showDelayTaskDialog(BuildContext context, Task task) {
    final delayReasonController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(Duration(days: 1));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  20,
                ), // Increased border radius for modern mobile look
              ),
              title: Row(
                children: [
                  Icon(Icons.schedule, color: CommonColors.orange, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Delay Task',
                    style: TextStyle(
                      color: CommonColors.orange,
                      fontSize:
                          20, // Increased font size for better mobile readability
                      fontWeight: FontWeight
                          .w700, // Enhanced font weight for better mobile visibility
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please provide a reason for the delay and expected completion date:',
                    style: TextStyle(
                      fontSize:
                          18, // Increased font size for better mobile readability
                      fontWeight: FontWeight
                          .w500, // Added font weight for better mobile visibility
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ), // Increased spacing for better mobile layout
                  Text(
                    'Task: ${task.taskName}',
                    style: TextStyle(
                      fontSize:
                          16, // Increased font size for better mobile readability
                      fontWeight: FontWeight
                          .w700, // Increased font weight for better mobile visibility
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ), // Increased spacing for better mobile layout
                  TextField(
                    controller: delayReasonController,
                    decoration: InputDecoration(
                      labelText: 'Delay Reason',
                      hintText:
                          'e.g., Waiting for client feedback, Technical issues...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Expected Completion: ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              selectedDate = date;
                            });
                          }
                        },
                        child: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: TextStyle(
                            color: CommonColors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ), // Increased padding for better mobile touch targets
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        12,
                      ), // Increased border radius for modern mobile look
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      fontSize:
                          16, // Increased font size for better mobile readability
                      fontWeight: FontWeight
                          .w600, // Added font weight for better mobile visibility
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (delayReasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please provide a delay reason'),
                          backgroundColor: CommonColors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    _delayTask(
                      context,
                      task,
                      delayReasonController.text.trim(),
                      selectedDate,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CommonColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ), // Increased padding for better mobile touch targets
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        12,
                      ), // Increased border radius for modern mobile look
                    ),
                  ),
                  child: Text(
                    'Delay Task',
                    style: TextStyle(
                      fontSize:
                          16, // Increased font size for better mobile readability
                      fontWeight: FontWeight
                          .w600, // Added font weight for better mobile visibility
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Delay task function
  void _delayTask(
    BuildContext context,
    Task task,
    String delayReason,
    DateTime expectedDate,
  ) async {
    try {
      print('⏰ Delaying task: ${task.taskName}');

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Marking task as delayed...'),
            ],
          ),
          backgroundColor: CommonColors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );

      // Call the actual delay method from TaskViewModel
      final taskViewModel = Provider.of<TaskViewModel>(context, listen: false);
      final success = await taskViewModel.delayTask(
        taskId: task.taskId,
        delayReason: delayReason,
        expectedCompletionDate: expectedDate,
      );

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.schedule, color: Colors.white),
                SizedBox(width: 8),
                Text('Task marked as delayed successfully! ⏰'),
              ],
            ),
            backgroundColor: CommonColors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // Note: The task list will automatically refresh on next build
        // due to the database update
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Failed to mark task as delayed. Please try again.'),
              ],
            ),
            backgroundColor: CommonColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error delaying task: $e');

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Error delaying task: $e'),
            ],
          ),
          backgroundColor: CommonColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  String? _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return null;
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Helper class to observe app lifecycle changes for timer synchronization
class AppLifecycleObserver extends WidgetsBindingObserver {
  final BuildContext context;
  final ClockViewModel clockViewModel;

  AppLifecycleObserver(this.context, this.clockViewModel);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('🔄 HomeScreen: App resumed - syncing timer state');
      // Sync with database first to get accurate state
      clockViewModel.syncWithDatabase(context).then((_) {
        // Then check and restore if needed
        clockViewModel.checkAndRestoreActiveSession(context);
      });
    }
  }
}

class _ExpandableMetricCard extends StatefulWidget {
  final BuildContext context;
  final IconData icon;
  final String value;
  final String label;
  final String subtitle;
  final String trend;
  final Color trendColor;

  const _ExpandableMetricCard({
    required this.context,
    required this.icon,
    required this.value,
    required this.label,
    required this.subtitle,
    required this.trend,
    required this.trendColor,
  });

  @override
  State<_ExpandableMetricCard> createState() => _ExpandableMetricCardState();
}

class _ExpandableMetricCardState extends State<_ExpandableMetricCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.trendColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.trendColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.value,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.titleLarge?.color,
                            ),
                          ),
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withOpacity(0.5),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.1),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.trendColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.trend,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: widget.trendColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
