import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:lottie/lottie.dart';
import 'package:webnox_taskops/theme/app_theme.dart';
import 'package:webnox_taskops/helpers/common_colors.dart';
import 'package:webnox_taskops/utils/responsive_utils.dart';
import 'package:webnox_taskops/services/calendar_service.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import '../../widgets/animations/silk_shader_widget.dart';

class CalendarScreen extends HookWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Styling uses standard desktop breakpoint
    final isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);
    // Layout uses a wider breakpoint to accommodate sidebar + 2 columns on small laptops
    final useSplitLayout = MediaQuery.of(context).size.width > 1100;

    final selectedDate = useState(DateTime.now());
    final focusedDay = useState(DateTime.now());
    final eventDates = useState<Set<DateTime>>({});
    final selectedDateEvents = useState<List<CalendarEvent>>([]);
    final isLoadingEvents = useState(false);
    final isLoadingEventDates = useState(false);
    final dayEvents = useState<Map<DateTime, List<CalendarEvent>>>({});

    // Filter states
    final showTasks = useState(true);
    final showHolidays = useState(true);
    final showLeave = useState(true);
    final showAttendance = useState(true);

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final calendarService = CalendarService();

    // Fetch event dates for the current month when the screen loads or month changes
    useEffect(() {
      void fetchEventDates() async {
        if (authViewModel.isAuthenticated) {
          try {
            isLoadingEventDates.value = true;
            print(
                '📅 Fetching event dates for month: ${focusedDay.value.year}-${focusedDay.value.month}');

            final eventsMap = <DateTime, List<CalendarEvent>>{};
            final filteredDates = <DateTime>{};

            final firstDay =
                DateTime(focusedDay.value.year, focusedDay.value.month, 1);
            final lastDay =
                DateTime(focusedDay.value.year, focusedDay.value.month + 1, 0);

            final monthEvents =
                await calendarService.getCalendarEventsForDateRange(
              startDate: firstDay,
              endDate: lastDay,
              authViewModel: authViewModel,
            );

            for (final event in monthEvents) {
              final eventDate =
                  DateTime(event.date.year, event.date.month, event.date.day);
              if (!eventsMap.containsKey(eventDate)) {
                eventsMap[eventDate] = [];
              }
              eventsMap[eventDate]!.add(event);
            }

            for (final entry in eventsMap.entries) {
              final date = entry.key;
              final events = entry.value;

              final hasVisibleEvents = events.any((event) {
                switch (event.type) {
                  case CalendarEventType.task:
                    return showTasks.value;
                  case CalendarEventType.holiday:
                    return showHolidays.value;
                  case CalendarEventType.leave:
                    return showLeave.value;
                  case CalendarEventType.attendance:
                    return showAttendance.value;
                  case CalendarEventType.absent:
                    return showAttendance
                        .value; // Show absent when attendance is shown
                }
              });

              if (hasVisibleEvents) {
                filteredDates.add(date);
              }
            }

            if (context.mounted) {
              dayEvents.value = eventsMap;
              eventDates.value = filteredDates;
            }

            // Add test event if empty
            if (filteredDates.isEmpty) {
              final today = DateTime.now();
              if (!eventsMap.containsKey(today)) {
                // Logic kept simple for replacement
              }
            }
          } catch (e) {
            print('❌ Error fetching event dates: $e');
            if (context.mounted) {
              eventDates.value = {};
              dayEvents.value = {};
            }
          } finally {
            if (context.mounted) {
              isLoadingEventDates.value = false;
            }
          }
        }
      }

      fetchEventDates();
      return null;
    }, [
      focusedDay.value.year,
      focusedDay.value.month,
      showTasks.value,
      showHolidays.value,
      showLeave.value
    ]);

    // Fetch events for the selected date
    useEffect(() {
      void fetchEventsForDate() async {
        if (authViewModel.isAuthenticated) {
          try {
            isLoadingEvents.value = true;
            final events = await calendarService.getCalendarEventsForDate(
              date: selectedDate.value,
              authViewModel: authViewModel,
            );

            final filteredEvents = events.where((event) {
              switch (event.type) {
                case CalendarEventType.task:
                  return showTasks.value;
                case CalendarEventType.holiday:
                  return showHolidays.value;
                case CalendarEventType.leave:
                  return showLeave.value;
                case CalendarEventType.attendance:
                  return showAttendance.value;
                case CalendarEventType.absent:
                  return showAttendance.value;
              }
            }).toList();

            if (context.mounted) {
              selectedDateEvents.value = filteredEvents;
            }
          } catch (e) {
            print('❌ Error fetching events for date: $e');
            if (context.mounted) {
              selectedDateEvents.value = [];
            }
          } finally {
            if (context.mounted) {
              isLoadingEvents.value = false;
            }
          }
        }
      }

      fetchEventsForDate();
      return null;
    }, [
      selectedDate.value,
      showTasks.value,
      showHolidays.value,
      showLeave.value,
      showAttendance.value
    ]);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header
          _buildHeader(context, isDesktop),

          // Main Content
          Expanded(
            child: useSplitLayout
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Split View
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column - Calendar
                              Expanded(
                                flex: 2,
                                child: SingleChildScrollView(
                                  child: _buildTableCalendar(
                                      context,
                                      selectedDate,
                                      focusedDay,
                                      eventDates,
                                      isLoadingEventDates,
                                      isDesktop,
                                      calendarService,
                                      authViewModel,
                                      showTasks,
                                      showHolidays,
                                      showLeave,
                                      showAttendance,
                                      dayEvents),
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Right Column - Events & Tasks
                              Expanded(
                                flex: 1,
                                child: _buildEventsAndTasks(
                                    context,
                                    selectedDate,
                                    selectedDateEvents,
                                    isLoadingEvents,
                                    showTasks,
                                    showHolidays,
                                    showLeave,
                                    showAttendance,
                                    isDesktop,
                                    useSplitLayout), // Pass layout flag
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTableCalendar(
                              context,
                              selectedDate,
                              focusedDay,
                              eventDates,
                              isLoadingEventDates,
                              isDesktop,
                              calendarService,
                              authViewModel,
                              showTasks,
                              showHolidays,
                              showLeave,
                              showAttendance,
                              dayEvents),
                          const SizedBox(height: 24),
                          // For mobile/small laptop, we don't fix height
                          _buildEventsAndTasks(
                              context,
                              selectedDate,
                              selectedDateEvents,
                              isLoadingEvents,
                              showTasks,
                              showHolidays,
                              showLeave,
                              showAttendance,
                              isDesktop,
                              useSplitLayout), // Pass layout flag
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return SilkShaderWidget(
      speed: 0.8,
      scale: 1.2,
      color: Theme.of(context).colorScheme.primary,
      noiseIntensity: 1.5,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 16,
          vertical: ResponsiveUtils.getResponsiveSize(
            context,
            mobile: 16,
            tablet: 18,
            laptop: 20, // Reduced from 28
            desktop: 28,
          ),
        ),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: CommonColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 12 : 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
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
                    'Manage Your Schedule',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveUtils.getResponsiveSize(
                        context,
                        mobile: 20,
                        tablet: 22,
                        laptop: 22, // Reduced from 28
                        desktop: 28,
                      ),
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  if (isDesktop)
                    Text(
                      'View and manage your tasks, leaves, and holidays efficiently',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _checkForContinuousLeave(
      BuildContext context,
      DateTime selectedDay,
      bool isDesktop,
      CalendarService calendarService,
      AuthViewModel authViewModel) async {
    try {
      // For demonstration, show continuous leave dialog for specific test dates
      if (selectedDay.day == DateTime.now().day + 1) {
        _showContinuousLeaveDialog(context, 'Annual Vacation', selectedDay,
            selectedDay.add(const Duration(days: 5)), 'Vacation', isDesktop);
        return;
      }

      final events = await calendarService.getCalendarEventsForDate(
        date: selectedDay,
        authViewModel: authViewModel,
      );

      // Filter for leave events only
      final leaveEvents = events
          .where((event) => event.type == CalendarEventType.leave)
          .toList();

      if (leaveEvents.isNotEmpty) {
        // Check if any leave event spans multiple days
        for (final leaveEvent in leaveEvents) {
          if (leaveEvent.data != null &&
              leaveEvent.data!['start_date'] != null &&
              leaveEvent.data!['end_date'] != null) {
            final startDate = DateTime.parse(leaveEvent.data!['start_date']);
            final endDate = DateTime.parse(leaveEvent.data!['end_date']);

            // If it's a multi-day leave, show the continuous leave dialog
            if (!isSameDay(startDate, endDate)) {
              _showContinuousLeaveDialog(
                  context,
                  leaveEvent.title,
                  startDate,
                  endDate,
                  leaveEvent.data!['leave_type'] ?? 'Leave',
                  isDesktop);
              break; // Show only the first continuous leave found
            }
          }
        }
      }
    } catch (e) {
      print('Error checking for continuous leave: $e');
    }
  }

  void _showContinuousLeaveDialog(BuildContext context, String title,
      DateTime startDate, DateTime endDate, String leaveType, bool isDesktop) {
    final daysDifference = endDate.difference(startDate).inDays + 1;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.event_available, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Continuous Leave Period',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: Container(
          width: isDesktop ? 400 : 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Leave title
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Date range
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: AppTheme.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'From: ${_formatDate(startDate)}',
                          style: TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: AppTheme.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'To: ${_formatDate(endDate)}',
                          style: TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$daysDifference ${daysDifference == 1 ? 'Day' : 'Days'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            leaveType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildEventFilterTabs(
    BuildContext context,
    ValueNotifier<bool> showTasks,
    ValueNotifier<bool> showHolidays,
    ValueNotifier<bool> showLeave,
    ValueNotifier<bool> showAttendance,
    bool isDesktop,
  ) {
    // Get responsive breakpoints

    final tabSpacing = ResponsiveUtils.getResponsiveSpacing(
      context,
      mobile: 8.0,
      tablet: 10.0,
      desktop: 12.0,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tasks Tab
          _buildFilterTab(
            context,
            'Tasks',
            Icons.task_alt,
            AppTheme.primaryBlue,
            showTasks.value,
            () => showTasks.value = !showTasks.value,
          ),
          SizedBox(width: tabSpacing),
          // Holidays Tab
          _buildFilterTab(
            context,
            'Holidays',
            Icons.celebration,
            Colors.red,
            showHolidays.value,
            () => showHolidays.value = !showHolidays.value,
          ),
          SizedBox(width: tabSpacing),
          // Leave Tab
          _buildFilterTab(
            context,
            'Leave',
            Icons.event_available,
            Colors.orange,
            showLeave.value,
            () => showLeave.value = !showLeave.value,
          ),
          SizedBox(width: tabSpacing),
          // Attendance Tab
          _buildFilterTab(
            context,
            'Attendance',
            Icons.access_time_filled,
            Colors.green,
            showAttendance.value,
            () => showAttendance.value = !showAttendance.value,
          ),
          SizedBox(width: tabSpacing * 1.5),

          // Divider
          Container(
            height: 24,
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
          SizedBox(width: tabSpacing * 1.5),

          // Quick Actions (All/None)
          _buildQuickAction(
            context,
            'All',
            () {
              showTasks.value = true;
              showHolidays.value = true;
              showLeave.value = true;
              showAttendance.value = true;
            },
          ),
          SizedBox(width: tabSpacing),
          _buildQuickAction(
            context,
            'None',
            () {
              showTasks.value = false;
              showHolidays.value = false;
              showLeave.value = false;
              showAttendance.value = false;
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
      BuildContext context, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: isDestructive
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap,
  ) {
    // Get responsive breakpoints
    final isVerySmallMobile = MediaQuery.of(context).size.width < 360;

    // Responsive sizing
    final iconSize = ResponsiveUtils.getResponsiveIconSize(
      context,
      mobile: isVerySmallMobile ? 14.0 : 16.0,
      tablet: 17.0,
      desktop: 18.0,
    );

    final fontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      mobile: isVerySmallMobile ? 12.0 : 13.0,
      tablet: 14.0,
      desktop: 15.0,
    );

    final padding = ResponsiveUtils.getResponsivePadding(
      context,
      mobile: EdgeInsets.symmetric(
        vertical: isVerySmallMobile ? 8.0 : 10.0,
        horizontal: isVerySmallMobile ? 10.0 : 12.0,
      ),
      tablet: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      desktop: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
    );

    final borderRadius = ResponsiveUtils.getResponsiveBorderRadius(
      context,
      mobile: 8.0,
      tablet: 10.0,
      desktop: 12.0,
    );

    final spacing = ResponsiveUtils.getResponsiveSpacing(
      context,
      mobile: isVerySmallMobile ? 6.0 : 8.0,
      tablet: 9.0,
      desktop: 10.0,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: EdgeInsets.symmetric(
          vertical: ResponsiveUtils.getResponsiveSpacing(
            context,
            mobile: 2.0,
            tablet: 3.0,
            desktop: 4.0,
          ),
          horizontal: ResponsiveUtils.getResponsiveSpacing(
            context,
            mobile: 1.0,
            tablet: 1.5,
            desktop: 2.0,
          ),
        ),
        padding: padding,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: isSelected ? Colors.white : color,
                ),
                SizedBox(width: spacing),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[600],
                    fontSize: fontSize,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 6.0,
                tablet: 8.0,
                desktop: 10.0,
              )),
              Container(
                height: ResponsiveUtils.getResponsiveSize(
                  context,
                  mobile: 2.0,
                  tablet: 2.5,
                  desktop: 3.0,
                ),
                width: ResponsiveUtils.getResponsiveSize(
                  context,
                  mobile: 16.0,
                  tablet: 20.0,
                  desktop: 24.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTableCalendar(
      BuildContext context,
      ValueNotifier<DateTime> selectedDate,
      ValueNotifier<DateTime> focusedDay,
      ValueNotifier<Set<DateTime>> eventDates,
      ValueNotifier<bool> isLoadingEventDates,
      bool isDesktop,
      CalendarService calendarService,
      AuthViewModel authViewModel,
      ValueNotifier<bool> showTasks,
      ValueNotifier<bool> showHolidays,
      ValueNotifier<bool> showLeave,
      ValueNotifier<bool> showAttendance,
      ValueNotifier<Map<DateTime, List<CalendarEvent>>> dayEvents) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar Header & Filters
          Row(
            children: [
              Expanded(
                child: _buildEventFilterTabs(
                  context,
                  showTasks,
                  showHolidays,
                  showLeave,
                  showAttendance,
                  isDesktop,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Table Calendar
          if (isLoadingEventDates.value)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else
            TableCalendar<CalendarEvent>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: focusedDay.value,
              selectedDayPredicate: (day) {
                return isSameDay(selectedDate.value, day);
              },
              onDaySelected: (selectedDay, focusedDayParam) {
                // Wrap in microtask to avoid setState during build
                Future.microtask(() {
                  if (context.mounted) {
                    selectedDate.value = selectedDay;
                    focusedDay.value = focusedDayParam;

                    // Check for continuous leave periods
                    _checkForContinuousLeave(context, selectedDay, isDesktop,
                        calendarService, authViewModel);
                  }
                });
              },
              onPageChanged: (focusedDayParam) {
                Future.microtask(() {
                  if (context.mounted) {
                    focusedDay.value = focusedDayParam;
                  }
                });
              },
              eventLoader: (day) {
                // Normalize the day to remove time component for consistent lookup
                final normalizedDay = DateTime(day.year, day.month, day.day);

                // Get the actual events for this day from our stored map
                final dayEventsList = dayEvents.value[normalizedDay] ?? [];

                // Debug: Print what we're looking for and what we found
                print(
                    '📅 EventLoader for ${day.toIso8601String().split('T')[0]}: Looking for normalized ${normalizedDay.toIso8601String().split('T')[0]}');
                print(
                    '📅 Found ${dayEventsList.length} events in dayEvents map');

                // Filter events based on current filter settings
                final filteredEvents = <CalendarEvent>[];

                for (final event in dayEventsList) {
                  switch (event.type) {
                    case CalendarEventType.task:
                      if (showTasks.value) filteredEvents.add(event);
                      break;
                    case CalendarEventType.holiday:
                      if (showHolidays.value) filteredEvents.add(event);
                      break;
                    case CalendarEventType.leave:
                      if (showLeave.value) filteredEvents.add(event);
                      break;
                    case CalendarEventType.attendance:
                      if (showAttendance.value) filteredEvents.add(event);
                      break;
                    case CalendarEventType.absent:
                      if (showAttendance.value) filteredEvents.add(event);
                      break;
                  }
                }

                print(
                    '📅 EventLoader returning ${filteredEvents.length} filtered events');
                return filteredEvents;
              },
              rowHeight: ResponsiveUtils.getResponsiveSize(
                context,
                mobile: 48,
                tablet: 42,
                laptop: 40,
                desktop: 52,
              ),
              daysOfWeekHeight: ResponsiveUtils.getResponsiveSize(
                context,
                mobile: 40,
                tablet: 32,
                laptop: 30,
                desktop: 40,
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.6),
                ),
                defaultTextStyle: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w500,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                markersMaxCount: 3,
                markerDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                cellPadding: const EdgeInsets.all(8),
                cellMargin: const EdgeInsets.all(2),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: Theme.of(context).textTheme.headlineSmall?.color,
                  fontSize: isDesktop ? 20 : 18,
                  fontWeight: FontWeight.bold,
                ),
                leftChevronIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_left,
                    color: Theme.of(context).colorScheme.primary,
                    size: isDesktop ? 24 : 20,
                  ),
                ),
                rightChevronIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary,
                    size: isDesktop ? 24 : 20,
                  ),
                ),
                headerPadding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 16 : 12,
                  vertical: isDesktop ? 12 : 8,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: isDesktop ? 14 : 12,
                  fontWeight: FontWeight.bold,
                ),
                weekendStyle: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontSize: isDesktop ? 14 : 12,
                  fontWeight: FontWeight.bold,
                ),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              calendarBuilders: CalendarBuilders<CalendarEvent>(
                markerBuilder: (context, day, events) {
                  // Debug: Always print marker builder calls
                  print(
                      '📅 Marker builder called for ${day.toIso8601String().split('T')[0]} with ${events.length} events');

                  // Use the events passed from eventLoader (already filtered)
                  if (events.isEmpty) {
                    print(
                        '📅 No events for ${day.toIso8601String().split('T')[0]}, returning null');
                    return null;
                  }

                  // Debug: Print what we're working with
                  print(
                      '📅 Marker builder for ${day.toIso8601String().split('T')[0]}: ${events.length} filtered events');
                  for (final event in events) {
                    print('📅 Event: ${event.type.name} - ${event.title}');
                  }

                  return Positioned(
                    bottom: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: events.take(3).map((event) {
                        return _buildEventMarker(context, event, isDesktop);
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventsAndTasks(
      BuildContext context,
      ValueNotifier<DateTime> selectedDate,
      ValueNotifier<List<CalendarEvent>> selectedDateEvents,
      ValueNotifier<bool> isLoadingEvents,
      ValueNotifier<bool> showTasks,
      ValueNotifier<bool> showHolidays,
      ValueNotifier<bool> showLeave,
      ValueNotifier<bool> showAttendance,
      bool isDesktop,
      [bool? useSplitLayout]) {
    // Add optional parameter

    // Determine if we should use Expanded (only in split layout mode)
    final useExpanded = useSplitLayout ?? isDesktop;

    return Container(
      // height removed to avoid unwanted white space at the bottom
      height: null,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Fixed)
          Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CommonColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.event_note_rounded,
                        color: CommonColors.primary,
                        size: isDesktop ? 20 : 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Events',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: isDesktop ? 20 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Selected Date Display
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        CommonColors.primary.withOpacity(0.05),
                        CommonColors.primary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: CommonColors.primary.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        color: CommonColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_getMonthName(selectedDate.value.month)} ${selectedDate.value.day}, ${selectedDate.value.year}',
                        style: TextStyle(
                          color: CommonColors.primary,
                          fontSize: isDesktop ? 16 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable List
          // Scrollable List
          if (useExpanded)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: _buildEventListContent(
                  context,
                  selectedDateEvents,
                  isLoadingEvents,
                  showTasks,
                  showHolidays,
                  showLeave,
                  showAttendance,
                  isDesktop,
                ),
              ),
            )
          else
            ListView(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(), // Let parent scroll
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: _buildEventListContent(
                context,
                selectedDateEvents,
                isLoadingEvents,
                showTasks,
                showHolidays,
                showLeave,
                showAttendance,
                isDesktop,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildEventListContent(
      BuildContext context,
      ValueNotifier<List<CalendarEvent>> selectedDateEvents,
      ValueNotifier<bool> isLoadingEvents,
      ValueNotifier<bool> showTasks,
      ValueNotifier<bool> showHolidays,
      ValueNotifier<bool> showLeave,
      ValueNotifier<bool> showAttendance,
      bool isDesktop) {
    if (isLoadingEvents.value) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        )
      ];
    } else if (selectedDateEvents.value.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/empty_box.json',
                height: 200,
                width: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 48,
                        color: Theme.of(context).disabledColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No events scheduled',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'No events scheduled',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enjoy your free time!',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        )
      ];
    }

    return [
      ...selectedDateEvents.value.map((event) {
        return _buildEventItem(
          context,
          event,
          isDesktop,
        );
      }).toList(),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CommonColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${selectedDateEvents.value.length} event${selectedDateEvents.value.length == 1 ? '' : 's'} found',
              style: TextStyle(
                color: CommonColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildEventItem(
      BuildContext context, CalendarEvent event, bool isDesktop) {
    // Determine event type styling
    Color eventColor;
    String eventTypeText;
    IconData eventIcon;

    switch (event.type) {
      case CalendarEventType.task:
        eventColor = event.color != null
            ? Color(int.parse(event.color!.replaceFirst('#', '0xff')))
            : Colors.blue;
        eventTypeText = 'Task';
        eventIcon = Icons.task_alt;
        break;
      case CalendarEventType.holiday:
        eventColor = event.color != null
            ? Color(int.parse(event.color!.replaceFirst('#', '0xff')))
            : Colors.red;
        eventTypeText = 'Holiday';
        eventIcon = Icons.celebration;
        break;
      case CalendarEventType.leave:
        eventColor = event.color != null
            ? Color(int.parse(event.color!.replaceFirst('#', '0xff')))
            : Colors.orange;
        eventTypeText = 'Leave';
        eventIcon = Icons.event_available;
        break;
      case CalendarEventType.attendance:
        eventColor = Colors.green;
        eventTypeText = 'Attendance';
        eventIcon = Icons.access_time_filled;
        break;
      case CalendarEventType.absent:
        eventColor = Colors.red;
        eventTypeText = 'Absent';
        eventIcon = Icons.cancel;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: eventColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: eventColor.withOpacity(0.1), // Softer border
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: eventColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      eventIcon,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      eventTypeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (event.data?['time'] != null)
                Text(
                  event.data!['time'],
                  style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Event title
          Text(
            event.title,
            style: TextStyle(
              color: Theme.of(context).textTheme.titleMedium?.color,
              fontSize: isDesktop ? 16 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Event description
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              event.description!,
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.8),
                fontSize: isDesktop ? 14 : 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Event details based on type
          if (event.type == CalendarEventType.task && event.data != null) ...[
            const SizedBox(height: 8),
            _buildTaskDetails(context, event.data!, isDesktop),
          ] else if (event.type == CalendarEventType.leave &&
              event.data != null) ...[
            const SizedBox(height: 8),
            _buildLeaveDetails(context, event.data!, isDesktop),
          ] else if (event.type == CalendarEventType.holiday &&
              event.data != null) ...[
            const SizedBox(height: 8),
            _buildHolidayDetails(context, event.data!, isDesktop),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskDetails(
      BuildContext context, Map<String, dynamic> taskData, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (taskData['project_name'] != null) ...[
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 14,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.6),
              ),
              const SizedBox(width: 4),
              Text(
                taskData['project_name'],
                style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Icon(
              Icons.flag_outlined,
              size: 14,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.6),
            ),
            const SizedBox(width: 4),
            Text(
              'Priority: ${taskData['priority_level'] ?? 'N/A'}',
              style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaveDetails(
      BuildContext context, Map<String, dynamic> leaveData, bool isDesktop) {
    final status = leaveData['leave_status'];
    String statusText;
    Color statusColor;

    switch (status) {
      case 0:
        statusText = 'Pending';
        statusColor = Colors.orange;
        break;
      case 1:
        statusText = 'Approved';
        statusColor = Colors.green;
        break;
      case 2:
        statusText = 'Rejected';
        statusColor = Colors.red;
        break;
      default:
        statusText = 'Unknown';
        statusColor = Colors.grey;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withOpacity(0.5)),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (leaveData['leave_type'] != null)
          Text(
            'Type: ${leaveData['leave_type']}',
            style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _buildHolidayDetails(
      BuildContext context, Map<String, dynamic> holidayData, bool isDesktop) {
    return Row(
      children: [
        if (holidayData['is_optional'] == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: const Text(
              'Optional',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (holidayData['total_days'] != null) ...[
          const SizedBox(width: 8),
          Text(
            '${holidayData['total_days']} day${holidayData['total_days'] == '1' ? '' : 's'}',
            style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  /// Build distinct event markers for different event types
  Widget _buildEventMarker(
      BuildContext context, CalendarEvent event, bool isDesktop) {
    final size = isDesktop ? 14.0 : 12.0;
    final margin = isDesktop ? 3.0 : 2.0;

    Color markerColor;
    IconData icon;
    BoxShape shape;

    switch (event.type) {
      case CalendarEventType.task:
        markerColor = Theme.of(context).colorScheme.primary;
        icon = Icons.task_alt;
        shape = BoxShape.circle;
        break;
      case CalendarEventType.holiday:
        markerColor = Colors.red[600]!;
        icon = Icons.celebration;
        shape = BoxShape.circle;
        break;
      case CalendarEventType.leave:
        markerColor = Colors.orange[600]!;
        icon = Icons.event_available;
        shape = BoxShape.circle;
        break;
      case CalendarEventType.attendance:
        markerColor = Colors.green[600]!;
        icon = Icons.access_time_filled;
        shape = BoxShape.circle;
        break;
      case CalendarEventType.absent:
        markerColor = Colors.red[600]!;
        icon = Icons.cancel;
        shape = BoxShape.circle;
        break;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: margin),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: markerColor,
        shape: shape,
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: markerColor.withOpacity(0.6),
            blurRadius: isDesktop ? 8 : 6,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: isDesktop ? 9 : 7,
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}
