import 'dart:async';
import 'dart:ui';
import 'common_widgets.dart';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../helpers/common_colors.dart';
import 'package:provider/provider.dart';
import '../view_model/attendance_view_model.dart';
import '../view_model/clock_view_model.dart';
import 'package:responsive_framework/responsive_framework.dart' as responsive;
import 'package:google_fonts/google_fonts.dart';

class SimpleAttendanceWidget extends StatefulWidget {
  const SimpleAttendanceWidget({super.key});

  @override
  State<SimpleAttendanceWidget> createState() => _SimpleAttendanceWidgetState();
}

class _SimpleAttendanceWidgetState extends State<SimpleAttendanceWidget> with SingleTickerProviderStateMixin {
  Timer? _sessionTimer; // Stopwatch timer for session duration
  DateTime? _sessionStartTime; // Track when session actually started
  late AnimationController _pulseController;
  bool _isActionHovered = false;
  bool _isStatusHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Trigger a fetch to ensure we have data
      Provider.of<AttendanceViewModel>(context, listen: false)
          .fetchCurrentAttendance();
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _pulseController.dispose();
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

  // Track accumulated seconds from previous sessions (not including current active session)
  int _accumulatedSeconds = 0;

  // Helper to parse timestamp string - only converts UTC (with 'Z') to local
  // Timestamps without 'Z' are assumed to already be in local time
  DateTime _parseTimestamp(String dateString) {
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
      return DateTime.tryParse(dateString) ?? DateTime.now();
    }
  }

  // Start/update the stopwatch timer using start time from data
  void _startSessionTimer(String? currentSessionStart, int accumulatedSeconds) {
    if (currentSessionStart != null && currentSessionStart.isNotEmpty) {
      try {
        print(
            '🕒 _startSessionTimer called. accumulatedSeconds: $accumulatedSeconds');
        // Parse the clock on time - this is the actual session start (convert UTC to local)
        _sessionStartTime = _parseTimestamp(currentSessionStart);
        _accumulatedSeconds = accumulatedSeconds;

        // Cancel existing timer
        _sessionTimer?.cancel();

        // Start stopwatch timer that updates every second
        _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted && _sessionStartTime != null) {
            setState(() {
              // Timer will trigger rebuild to update UI
            });
          }
        });
      } catch (e) {
        developer.log('Error starting session timer: $e');
      }
    } else {
      // Stop timer if not clocked in
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _sessionStartTime = null;
      _accumulatedSeconds = 0;
    }
  }

  // Get cumulative daily duration (accumulated seconds from DB + current session elapsed time)
  String? _getCumulativeDailyDuration() {
    if (_sessionStartTime != null) {
      // Calculate current session elapsed time
      final currentSessionElapsed =
          DateTime.now().difference(_sessionStartTime!);

      // Total = accumulated seconds from DB + current session elapsed
      final totalDuration =
          Duration(seconds: _accumulatedSeconds) + currentSessionElapsed;

      // print('⏱️ Timer Tick: Accum($_accumulatedSeconds) + Elapsed(${currentSessionElapsed.inSeconds}) = Total(${totalDuration.inSeconds})');

      return _formatSessionDuration(totalDuration);
    }
    return null;
  }

  // _loadSummary removed as we use Consumer now

  @override
  Widget build(BuildContext context) {
    final isDesktop = responsive.ResponsiveValue(
      context,
      defaultValue: false,
      conditionalValues: [
        responsive.Condition.largerThan(name: responsive.MOBILE, value: true),
      ],
    ).value;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Initialize future only once - Removed as we use Consumer now

    return Consumer<AttendanceViewModel>(
      builder: (context, attendanceViewModel, child) {
        // Use the summary directly from the view model
        final summary = attendanceViewModel.dailySummary;

        if (summary == null && attendanceViewModel.isLoadingAttendance) {
          return _buildLoadingState(context, isDesktop, isDark);
        }

        // If summary is null but not loading, allow default values (not clocked in)

        final isClockedIn = summary?['is_clocked_in'] ?? false;
        final firstClockIn = summary?['first_clock_in'];
        final lastClockOut = summary?['last_clock_out'];
        final totalHours = summary?['total_hours'] ?? 0.0;
        final currentSessionStart = summary?['current_session_start'];
        final accumulatedSecondsRaw = summary?['accumulated_duration_seconds'];
        final accumulatedSeconds =
            (accumulatedSecondsRaw as num?)?.toInt() ?? 0;

        developer.log(
            '👀 Consumer update: isClockedIn=$isClockedIn, accumRaw=$accumulatedSecondsRaw (Type: ${accumulatedSecondsRaw.runtimeType}), accumInt=$accumulatedSeconds',
            name: 'SimpleAttendanceWidget');

        // Start timer if clocked in and we have start time
        if (isClockedIn && currentSessionStart != null) {
          // Parse the new session start time
          DateTime? newSessionStart;
          try {
            newSessionStart = _parseTimestamp(currentSessionStart.toString());
          } catch (e) {
            newSessionStart = null;
          }

          // Restart timer if this is a new session (different start time or first time)
          if (newSessionStart != null) {
            final shouldRestartTimer = _sessionStartTime == null ||
                _sessionStartTime!.difference(newSessionStart).inSeconds.abs() >
                    2;

            // Also update if accumulated seconds changed (e.g. data loaded after initial render)
            final accumulatedChanged =
                accumulatedSeconds != _accumulatedSeconds;

            // IMPORTANT: Update _accumulatedSeconds IMMEDIATELY when changed
            // This ensures the timer calculation uses the latest value
            // Allow both increase AND decrease to correct inflated values
            if (accumulatedChanged) {
              _accumulatedSeconds = accumulatedSeconds;
              developer.log(
                  '✅ Updated _accumulatedSeconds to $accumulatedSeconds (was ${_accumulatedSeconds})',
                  name: 'SimpleAttendanceWidget');
            }

            // Also restart if we have no active timer but we should
            final timerActive = _sessionTimer?.isActive ?? false;

            if (shouldRestartTimer || !timerActive || accumulatedChanged) {
              // Avoid scheduling build during build, use postFrameCallback
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  print(
                      '🔄 STARTING TIMER: accumulated=$accumulatedSeconds, _local=$_accumulatedSeconds, start=$currentSessionStart');
                  _startSessionTimer(
                      currentSessionStart.toString(), accumulatedSeconds);
                }
              });
            }
          }
        } else if (!isClockedIn) {
          _sessionTimer?.cancel();
          _sessionStartTime = null;
          _accumulatedSeconds = 0;
        }

        // Use cumulative daily duration (completed hours + current session)
        String? sessionDuration;
        if (isClockedIn) {
          // Try the timer-based calculation first
          sessionDuration = _getCumulativeDailyDuration();

          // If timer hasn't started yet, calculate from summary data directly
          if (sessionDuration == null && currentSessionStart != null) {
            try {
              final sessionStart =
                  _parseTimestamp(currentSessionStart.toString());
              final currentElapsed = DateTime.now().difference(sessionStart);
              // Use accumulated seconds from summary + current session elapsed
              final totalDuration =
                  Duration(seconds: accumulatedSeconds) + currentElapsed;
              sessionDuration = _formatSessionDuration(totalDuration);
              developer.log(
                '📊 Calculated duration from summary: accum=$accumulatedSeconds + elapsed=${currentElapsed.inSeconds}s = ${totalDuration.inSeconds}s',
                name: 'SimpleAttendanceWidget',
              );
            } catch (e) {
              // Final fallback to current session only
              sessionDuration = summary?['session_duration'];
            }
          }
        }

        // Check for remote override in the current session
        final isRemoteOverride =
            summary?['is_remote_override'] as bool? ?? false;
        final remoteReason = summary?['remote_reason'] as String?;

        return _buildAttendanceCard(
          isClockedIn: isClockedIn,
          firstClockIn: firstClockIn,
          lastClockOut: lastClockOut,
          totalHours: totalHours,
          sessionDuration: sessionDuration,
          isDesktop: isDesktop,
          isDark: isDark,
          isRemoteOverride: isRemoteOverride,
          remoteReason: remoteReason,
        );
      },
    );
  }

  Widget _buildAttendanceCard({
    required bool isClockedIn,
    required String? firstClockIn,
    required String? lastClockOut,
    required double totalHours,
    String? sessionDuration,
    required bool isDesktop,
    required bool isDark,
    bool isRemoteOverride = false,
    String? remoteReason,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 320;
        return isWide
            ? Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildTimingsCard(firstClockIn, lastClockOut),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: isClockedIn
                        ? _buildActiveSessionCard(sessionDuration)
                        : _buildFingerprintCard(),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTimingsCard(firstClockIn, lastClockOut),
                  const SizedBox(height: 12),
                  isClockedIn
                      ? _buildActiveSessionCard(sessionDuration)
                      : _buildFingerprintCard(),
                ],
              );
      },
    );
  }

  Widget _buildLoadingState(BuildContext context, bool isDesktop, bool isDark) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.0,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF3B82F6),
        ),
      ),
    );
  }

  Widget _buildTimingsCard(String? firstClockIn, String? lastClockOut) {
    final displayFirstClockIn = firstClockIn != null ? _formatTime(firstClockIn) : '--:--';
    final displayLastClockOut = lastClockOut != null ? _formatTime(lastClockOut) : '--:--';

    return MouseRegion(
      onEnter: (_) => setState(() => _isStatusHovered = true),
      onExit: (_) => setState(() => _isStatusHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isStatusHovered ? 0.25 : 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isStatusHovered
                      ? const Color(0xFF3B82F6).withOpacity(0.3)
                      : Colors.white.withOpacity(0.08),
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Row 1: PUNCH IN Timings
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'PUNCH IN',
                                style: GoogleFonts.lexend(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981), // Teal/green
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'FIRST IN',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF10B981).withOpacity(0.7),
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          displayFirstClockIn,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  
                  // Row 2: PUNCH OUT Timings
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'PUNCH OUT',
                                style: GoogleFonts.lexend(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFF59E0B), // Orange/yellow
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF59E0B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'LAST OUT',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFF59E0B).withOpacity(0.7),
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          displayLastClockOut,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFingerprintCard() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isActionHovered = true),
      onExit: (_) => setState(() => _isActionHovered = false),
      child: GestureDetector(
        onTap: () => _handleClockIn(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(_isActionHovered ? 0.15 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isActionHovered
                        ? const Color(0xFF3B82F6).withOpacity(0.4)
                        : Colors.white.withOpacity(0.08),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PUNCH IN',
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3B82F6),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulseVal = _pulseController.value;
                            final baseColor = const Color(0xFF3B82F6);
                            return AnimatedScale(
                              scale: _isActionHovered ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: baseColor.withOpacity(0.3 + (pulseVal * 0.15)),
                                      blurRadius: 12 + (pulseVal * 12),
                                      spreadRadius: 1 + (pulseVal * 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.fingerprint_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard(String? sessionDuration) {
    final startTimeStr = _sessionStartTime != null ? _formatTimeFromDateTime(_sessionStartTime!) : '--:--';
    final durationStr = sessionDuration ?? '00:00:00';

    return MouseRegion(
      onEnter: (_) => setState(() => _isStatusHovered = true),
      onExit: (_) => setState(() => _isStatusHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(_isStatusHovered ? 0.15 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isStatusHovered
                      ? const Color(0xFF3B82F6).withOpacity(0.4)
                      : const Color(0xFF3B82F6).withOpacity(0.2),
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Row 1: PUNCH IN Title + LIVE SESSION & Timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PUNCH IN',
                              style: GoogleFonts.lexend(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF3B82F6),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF3B82F6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'LIVE SESSION',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF3B82F6).withOpacity(0.7),
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        durationStr,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  
                  // Divider
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withOpacity(0.08),
                  ),
                  
                  // Row 2: STARTED AT & Punch Out Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'STARTED AT',
                              style: GoogleFonts.lexend(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.4),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              startTimeStr,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _handleClockOut(context),
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final pulseVal = _pulseController.value;
                              final baseColor = const Color(0xFFEF4444);
                              return Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: baseColor.withOpacity(0.3 + (pulseVal * 0.15)),
                                      blurRadius: 8 + (pulseVal * 8),
                                      spreadRadius: 1 + (pulseVal * 1.5),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.fingerprint_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              );
                            },
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
      ),
    );
  }

  String _formatTimeFromDateTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $amPm';
  }

  Future<void> _handleClockIn(BuildContext context) async {
    final attendanceViewModel =
        Provider.of<AttendanceViewModel>(context, listen: false);

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
                  'You are punching in outside standard office hours (9:00 AM - 7:00 PM).'),
              const SizedBox(height: 12),
              const Text(
                  'Please provide a reason (e.g., Night Shift, Extra Time) to proceed.'),
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
                  Navigator.of(context).pop(reasonController.text.trim());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reason is required')),
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

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: CommonColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Punching in...',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final success =
        await attendanceViewModel.simpleClockIn(remoteReason: remoteReason);

    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: CommonColors.white,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  success
                      ? 'Successfully punched in!'
                      : attendanceViewModel.error ?? 'Failed to punch in',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: success ? CommonColors.green : CommonColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: success ? 2 : 4),
        ),
      );
    }
  }

  Future<void> _handleClockOut(BuildContext context) async {
    final attendanceViewModel =
        Provider.of<AttendanceViewModel>(context, listen: false);

    // Duration Check: Prevent clock out if session < 1 minute
    final durationString = _getCumulativeDailyDuration();
    if (durationString != null) {
      // Parse duration string back to check (simple approach: check active timer)
      if (_sessionStartTime != null) {
        final elapsed = DateTime.now().difference(_sessionStartTime!);
        if (elapsed.inSeconds < 60) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: CommonColors.orange),
                  SizedBox(width: 12),
                  const Text('Session Too Short'),
                ],
              ),
              content: const Text(
                  'Your session is less than 1 minute. Please work for at least a minute before punching out.'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: CommonColors.primary),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
      }
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.logout, color: CommonColors.red),
            SizedBox(width: 12),
            customTextWithClip(
              text: 'Punch Out',
              textColor: CommonColors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ],
        ),
        content: customTextWithClip(
          text: 'Are you sure you want to punch out?',
          textColor: CommonColors.grey,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: customTextWithClip(
              text: 'Cancel',
              textColor: CommonColors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CommonColors.red,
            ),
            child: customTextWithClip(
              text: 'Punch Out',
              textColor: CommonColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    // Check for active task and prevent clock out if running
    final clockViewModel = Provider.of<ClockViewModel>(context, listen: false);

    // 1. Force sync with ViewModel (UI State)
    await clockViewModel.syncWithDatabase(context);

    // 2. Direct check removed as syncWithDatabase now uses API which is the source of truth.
    developer.log(
        '[SimpleAttendanceWidget] Synced with backend. Local state is now up to date.');
    bool hasActiveTaskInDb =
        clockViewModel.isClockedIn; // Trust the view model after sync
    String activeTaskNameInDb =
        clockViewModel.clockedInTask?.taskName ?? 'Active Task';

    developer.log(
        '[SimpleAttendanceWidget] ========== ACTIVE TASK CHECK END ==========');

    // Block if EITHER local state OR direct database check says we are active
    if (clockViewModel.isClockedIn || hasActiveTaskInDb) {
      final taskName = clockViewModel.isClockedIn
          ? (clockViewModel.clockedInTask?.taskName ?? activeTaskNameInDb)
          : activeTaskNameInDb;

      // Show alert dialog preventing clock out
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: CommonColors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Active Task Running',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
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
                'You are currently clocked in to task "$taskName".\n\nPlease clock out from the task before punching out of attendance.',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Debug Info:\nEmployee ID: (Hidden)\nMatch Found: $hasActiveTaskInDb',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: CommonColors.primary,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return; // Stop execution
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: CommonColors.red),
              SizedBox(height: 16),
              Text(
                'Punching out...',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final success = await attendanceViewModel.clockOut();

    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: CommonColors.white,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  success
                      ? 'Punch out successfully'
                      : attendanceViewModel.error ?? 'Failed to punch out',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: success ? CommonColors.green : CommonColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: success ? 2 : 4),
        ),
      );
    }
  }

  String _formatTime(String isoString) {
    try {
      // Use the UTC to local helper to ensure proper timezone conversion
      final dateTime = _parseTimestamp(isoString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }
}
