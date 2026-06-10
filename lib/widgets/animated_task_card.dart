import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import '../model/task_model.dart';
import 'qc_completion_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

class AnimatedTaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onClockIn;
  final VoidCallback? onStartTask;
  final VoidCallback? onCompleteTask;
  final VoidCallback? onQAApprove;
  final VoidCallback? onQADisapprove;
  final VoidCallback? onQAStartTask;
  final VoidCallback? onQACompleteTask;
  final VoidCallback? onQARedoTask;
  final bool showActions;
  final int index;
  final bool isCurrentlyClockedIn;
  final Duration? elapsedTime;
  final Duration? previousDuration;
  final DateTime? startTime;
  final String? userRole;

  const AnimatedTaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onClockIn,
    this.onStartTask,
    this.onCompleteTask,
    this.onQAApprove,
    this.onQADisapprove,
    this.onQAStartTask,
    this.onQACompleteTask,
    this.onQARedoTask,
    this.showActions = false,
    this.index = 0,
    this.isCurrentlyClockedIn = false,
    this.elapsedTime,
    this.previousDuration,
    this.startTime,
    this.userRole,
  });

  @override
  State<AnimatedTaskCard> createState() => _AnimatedTaskCardState();
}

class _AnimatedTaskCardState extends State<AnimatedTaskCard>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  Timer? _timer; // elapsed-time ticker (runs when clocked in)
  Timer? _uiTicker; // lightweight UI ticker to refresh countdowns
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();

    // Initialize flip animation controller
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    // Start timer if currently clocked in
    if (widget.isCurrentlyClockedIn && widget.startTime != null) {
      _startTimer();
    }

    // Always start a lightweight UI ticker so "Task Duration" updates live
    _startUiTicker();
  }

  @override
  void didUpdateWidget(AnimatedTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle clock in/out state changes
    if (widget.isCurrentlyClockedIn != oldWidget.isCurrentlyClockedIn) {
      if (widget.isCurrentlyClockedIn) {
        _startTimer();
        // Auto-flip to timer view when clocking in
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isFlipped) {
            _flipCard();
          }
        });
      } else {
        _stopTimer();
        // Force flip back to front when clocking out
        if (_isFlipped) {
          _flipCard(); // Flip back immediately without delay to reflect change instantly
        }
      }
    } else if (!widget.isCurrentlyClockedIn && _isFlipped) {
      // Safety check: If not clocked in but card is flipped (stuck state), flip it back
      _stopTimer();
      _flipCard();
    }

    // Update elapsed time if provided
    if (widget.elapsedTime != null &&
        widget.elapsedTime != oldWidget.elapsedTime) {}

    // Restart timer if startTime changed (e.g., on app reload)
    if (widget.isCurrentlyClockedIn &&
        widget.startTime != null &&
        (oldWidget.startTime != widget.startTime ||
            (oldWidget.startTime == null && widget.startTime != null))) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (widget.startTime != null && mounted) {
        setState(() {
          // Force rebuild to update timer display
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _startUiTicker() {
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Trigger rebuild so _getTimeRemaining() reflects the current time
      setState(() {});
    });
  }

  void _flipCard() {
    if (_flipController.isCompleted) {
      _flipController.reverse();
      setState(() {
        _isFlipped = false;
      });
    } else {
      _flipController.forward();
      setState(() {
        _isFlipped = true;
      });
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _timer?.cancel();
    _uiTicker?.cancel();
    super.dispose();
  }

  void _showQCCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return QCCompletionDialog(
          taskName: widget.task.taskName ?? 'Untitled Task',
          onWorkDone: () {
            // Handle work done - call QA complete task callback
            if (widget.onQACompleteTask != null) {
              widget.onQACompleteTask!();
            } else if (widget.onCompleteTask != null) {
              widget.onCompleteTask!();
            }
          },
          onRedo: () {
            // Handle redo - call QA redo task callback
            if (widget.onQARedoTask != null) {
              widget.onQARedoTask!();
            }
          },
          onComplete: (String notes, List<String> attachments) {
            // Handle completion with notes and attachments
            print('QC Completion - Notes: $notes, Attachments: $attachments');
            // The actual API calls will be handled by the onWorkDone/onRedo callbacks
          },
        );
      },
    );
  }

  // Helper methods for styling based on task status
  Color _getStatusColor() {
    switch (widget.task.workflowStatus?.toLowerCase()) {
      case 'pending':
        return Colors.orange[700]!;
      case 'in_progress':
        return Colors.blue[700]!;
      case 'completed':
      case 'dev completed':
        return Colors.green[700]!;
      case 'delayed':
        return Colors.red[700]!;
      case 'cancelled':
        return Colors.grey[700]!;
      default:
        return Colors.blue[700]!;
    }
  }

  Color _getStatusBgColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (widget.task.workflowStatus?.toLowerCase()) {
      case 'pending':
        return isDark
            ? const Color(0xFF4D3800) // Darker orange for dark mode
            : const Color(0xFFFFF3E0); // Soft orange
      case 'in_progress':
        return isDark
            ? const Color(0xFF0D47A1).withOpacity(0.3) // Darker blue
            : const Color(0xFFE3F2FD); // Soft blue
      case 'completed':
      case 'dev completed':
        return isDark
            ? const Color(0xFF1B5E20).withOpacity(0.3) // Darker green
            : const Color(0xFFE8F5E9); // Soft green
      case 'delayed':
        return isDark
            ? const Color(0xFFB71C1C).withOpacity(0.3) // Darker red
            : const Color(0xFFFFEBEE); // Soft red
      case 'cancelled':
        return isDark
            ? const Color(0xFF424242).withOpacity(0.3) // Darker grey
            : const Color(0xFFF5F5F5); // Soft grey
      default:
        return isDark
            ? const Color(0xFF0D47A1).withOpacity(0.3)
            : const Color(0xFFE3F2FD);
    }
  }

  String _getStatusText() {
    final status = widget.task.workflowStatus?.toLowerCase() ?? '';

    // Map status values to display text
    switch (status) {
      case 'assigned':
      case 'todo':
      case 'pending':
        return 'Pending';
      case 'in progress':
      case 'in_progress':
        return 'In Progress';
      case 'dev completed':
      case 'dev_completed':
      case 'completed':
        return 'Dev Completed';
      case 'in qc':
      case 'in_qc':
        return 'In QC';
      case 'work done':
      case 'work_done':
        return 'Work Done';
      case 'redo':
        return 'Redo';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      case 'delayed':
        return 'Delayed';
      default:
        // If status exists but doesn't match, capitalize first letter of each word
        if (widget.task.workflowStatus != null &&
            widget.task.workflowStatus!.isNotEmpty) {
          return widget.task.workflowStatus!
              .split('_')
              .map(
                (word) => word.isEmpty
                    ? ''
                    : word[0].toUpperCase() + word.substring(1).toLowerCase(),
              )
              .join(' ');
        }
        return 'Task';
    }
  }

  Color _getPriorityColor() {
    final priorityLevel =
        widget.task.priorityLevel?.toString().toLowerCase() ?? '';
    switch (priorityLevel) {
      case 'high':
      case '1':
      case 'urgent':
      case 'critical':
        return Colors.red[700]!;
      case 'medium':
      case '2':
      case 'normal':
      case 'standard':
        return Colors.orange[700]!;
      case 'low':
      case '3':
      case 'minor':
      case 'lowest':
        return Colors.green[700]!;
      default:
        return Colors.green[700]!;
    }
  }



  String _getPriorityText() {
    final priorityLevel =
        widget.task.priorityLevel?.toString().toLowerCase() ?? '';
    switch (priorityLevel) {
      case 'high':
      case '1':
      case 'urgent':
      case 'critical':
        return 'High';
      case 'medium':
      case '2':
      case 'normal':
      case 'standard':
        return 'Medium';
      case 'low':
      case '3':
      case 'minor':
      case 'lowest':
        return 'Low';
      default:
        return 'Low';
    }
  }



  String _getElapsedTimeDisplay() {
    if (widget.isCurrentlyClockedIn && widget.startTime != null) {
      // Calculate elapsed time from start time + previous accumulated duration
      final now = DateTime.now();
      final currentSession = now.difference(widget.startTime!);
      final total = currentSession + (widget.previousDuration ?? Duration.zero);
      return _formatDuration(total);
    } else if (widget.elapsedTime != null) {
      // Use provided elapsed time
      return _formatDuration(widget.elapsedTime!);
    } else {
      return '00:00:00';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildBackSide() {
    final accentColor = _getStatusColor();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.06),
            Colors.white.withOpacity(0.015),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveBorderRadius(
            context,
            mobile: 16.0,
            tablet: 20.0,
            desktop: 24.0,
          ),
        ),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(
          context,
          mobile: const EdgeInsets.all(24),
          tablet: const EdgeInsets.all(28),
          desktop: const EdgeInsets.all(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Currently Working indicator
            _buildCurrentlyWorkingIndicator(),
            SizedBox(
              height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 16.0,
                tablet: 20.0,
                desktop: 24.0,
              ),
            ),

            // Timer display card (Circular)
            _buildTimerCard(),
            SizedBox(
              height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 24.0,
                tablet: 28.0,
                desktop: 32.0,
              ),
            ),

            Row(
              children: [
                Expanded(child: _buildClockOutButton()),
                SizedBox(
                  width: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 12.0,
                    tablet: 14.0,
                    desktop: 16.0,
                  ),
                ),
                Expanded(child: _buildViewDetailsButton()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentlyWorkingIndicator() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(seconds: 1),
      tween: Tween(begin: 0.95, end: 1.05),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: Colors.green[600],
              borderRadius: BorderRadius.circular(24.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'CURRENTLY WORKING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildTaskName() {
    return Text(
      widget.task.taskName ?? 'Untitled Task',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.grey[800],
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTimerCard() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulsing circle effect
        TweenAnimationBuilder<double>(
          duration: const Duration(seconds: 2),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(
                    (1 - value) * 0.5,
                  ), // Fade out as it expands
                  width: 2,
                ),
              ),
            );
          },
          onEnd: () {
            if (mounted) setState(() {}); // Loop animation
          },
        ),
        // Main circular timer
        SizedBox(
          width: 160,
          height: 160,
          child: CircularProgressIndicator(
            value:
                null, // Indeterminate for now, or calculate progress if needed
            strokeWidth: 8,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        // Timer text
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              _getElapsedTimeDisplay(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Elapsed',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClockOutButton() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(seconds: 1),
      tween: Tween(begin: 0.98, end: 1.02),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: SizedBox(
            width: double.infinity,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onClockIn ?? () {},
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 4.0,
                      tablet: 6.0,
                      desktop: 8.0,
                    ),
                    horizontal: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getResponsiveBorderRadius(
                        context,
                        mobile: 8.0,
                        tablet: 9.0,
                        desktop: 10.0,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red[600]!.withOpacity(0.3),
                        blurRadius: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 4.0,
                          tablet: 5.0,
                          desktop: 6.0,
                        ),
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    'Clock Out',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 11.0,
                        tablet: 12.0,
                        desktop: 13.0,
                      ),
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildViewDetailsButton() {
    return SizedBox(
      width: double.infinity,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _flipCard,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 4.0,
                tablet: 6.0,
                desktop: 8.0,
              ),
              horizontal: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              ),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.getResponsiveBorderRadius(
                  context,
                  mobile: 8.0,
                  tablet: 9.0,
                  desktop: 10.0,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 4.0,
                    tablet: 5.0,
                    desktop: 6.0,
                  ),
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              'View Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 11.0,
                  tablet: 12.0,
                  desktop: 13.0,
                ),
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      delay: Duration(milliseconds: 100 * widget.index),
      duration: const Duration(milliseconds: 600),
      child: Container(
        margin: ResponsiveUtils.getResponsiveMargin(
          context,
          mobile: const EdgeInsets.all(6),
          tablet: const EdgeInsets.all(8),
          desktop: const EdgeInsets.all(12),
        ),
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final isShowingFront = _flipAnimation.value < 0.5;
            final flipValue = isShowingFront
                ? _flipAnimation.value
                : 1 - _flipAnimation.value;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(flipValue * 3.14159),
              child: isShowingFront ? _buildFrontSide() : _buildBackSide(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFrontSide() {
    final statusText = _getStatusText();
    final statusBgColor = _getStatusBgColor(context);
    final statusColor = _getStatusColor();
    final priorityColor = _getPriorityColor();
    final priorityText = _getPriorityText();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showTaskDetailsDialog(),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF1E293B),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Icon Box + Title/Due Date + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Box
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.code_rounded,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title and Due Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.task.taskName ?? 'Untitled Task',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDueDate(widget.task.devCompletedAt),
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),

                // Description section
                if (widget.task.taskDescription != null &&
                    widget.task.taskDescription!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    widget.task.taskDescription!,
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 20),

                // Bottom Row: Priority on Left, Action Button on Right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Priority Level
                    Row(
                      children: [
                        Text(
                          'Priority:',
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: priorityColor.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            priorityText,
                            style: GoogleFonts.inter(
                              color: priorityColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Action controls
                    _buildModernActionSection(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDueDate(DateTime? date) {
    if (date == null) return 'Due: N/A';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return 'Due: ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildCapsuleButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernActionSection() {
    if (widget.isCurrentlyClockedIn) {
      return _buildCapsuleButton(
        label: 'View Timer',
        icon: Icons.timer_outlined,
        color: const Color(0xFF3B82F6),
        onTap: _flipCard,
      );
    }

    String status = widget.task.workflowStatus?.toLowerCase() ?? 'assigned';
    bool isQAAnalyst =
        widget.userRole?.toLowerCase().trim().contains('qa analyst') ?? false;

    if (isQAAnalyst) {
      switch (status) {
        case 'dev completed':
        case 'dev_completed':
          return _buildCapsuleButton(
            label: 'Start Testing',
            icon: Icons.science_outlined,
            color: Colors.orange[600]!,
            onTap: widget.onQAStartTask ?? () {},
          );
        case 'in qc':
        case 'in_qc':
          return _buildModernEmployeeActions();
        case 'work done':
        case 'work_done':
        case 'completed':
          return const SizedBox.shrink();
        case 'redo':
          return _buildModernEmployeeActions();
        default:
          return _buildModernEmployeeActions();
      }
    }

    // Regular employee actions
    switch (status) {
      case 'assigned':
        return _buildCapsuleButton(
          label: 'Start Task',
          icon: Icons.play_arrow_rounded,
          color: const Color(0xFF3B82F6),
          onTap: widget.onStartTask ?? () {},
        );
      case 'in progress':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCapsuleButton(
              label: 'Clock In',
              icon: Icons.access_time_rounded,
              color: const Color(0xFF3B82F6),
              onTap: () {
                if (widget.onClockIn != null) {
                  widget.onClockIn!();
                }
              },
            ),
            const SizedBox(width: 8),
            _buildCapsuleButton(
              label: 'Complete',
              icon: Icons.check_circle_outline_rounded,
              color: Colors.green[700]!,
              onTap: () {
                if (widget.onCompleteTask != null) {
                  widget.onCompleteTask!();
                }
              },
            ),
          ],
        );
      case 'completed':
      case 'dev completed':
      case 'work done':
      case 'workdone':
      case 'work_done':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.green[600]!.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[600]!.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Colors.green[600],
              ),
              const SizedBox(width: 6),
              Text(
                'Completed',
                style: GoogleFonts.inter(
                  color: Colors.green[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      default:
        return _buildCapsuleButton(
          label: 'Start Task',
          icon: Icons.play_arrow_rounded,
          color: const Color(0xFF3B82F6),
          onTap: widget.onStartTask ?? () {},
        );
    }
  }

  Widget _buildModernEmployeeActions() {
    final status = widget.task.workflowStatus?.toLowerCase() ?? '';
    final isInQC = status == 'in qc';
    final isWorkDone = status == 'work done';

    if (isWorkDone) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCapsuleButton(
          label: 'Clock In',
          icon: Icons.access_time_rounded,
          color: const Color(0xFF3B82F6),
          onTap: () {
            if (widget.onClockIn != null) {
              widget.onClockIn!();
            }
          },
        ),
        if (isInQC) ...[
          const SizedBox(width: 8),
          _buildCapsuleButton(
            label: 'Complete Task',
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green[700]!,
            onTap: () => _showQCCompletionDialog(),
          ),
        ],
      ],
    );
  }

  /// Show task details dialog
  void _showTaskDetailsDialog() {
    final isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isDesktop
                  ? 900
                  : isTablet
                  ? 600
                  : double.infinity,
              maxHeight: MediaQuery.of(context).size.height * 0.95,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildDialogHeader(isDesktop),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(
                      isDesktop
                          ? 32
                          : isTablet
                          ? 24
                          : 20,
                    ),
                    child: _buildTaskDetailsContent(isDesktop),
                  ),
                ),
                // Footer
                _buildDialogFooter(isDesktop),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build dialog header
  Widget _buildDialogHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isDesktop ? 24 : 20),
          topRight: Radius.circular(isDesktop ? 24 : 20),
        ),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w300,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: isDesktop ? 8 : 6),
                Text(
                  widget.task.taskName ?? 'Untitled Task',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                SizedBox(height: isDesktop ? 8 : 6),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 16 : 12,
                    vertical: isDesktop ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                    border: Border.all(
                      color: _getStatusColor().withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: EdgeInsets.all(isDesktop ? 12 : 10),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                'Close',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build task details content - Employee User View
  Widget _buildTaskDetailsContent(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Task Overview Section
        _buildTaskOverviewSection(isDesktop),

        const SizedBox(height: 20),

        // Description Section
        if (widget.task.taskDescription?.isNotEmpty == true) ...[
          _buildInfoSection('Task Description', Icons.description, [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
              child: Text(
                widget.task.taskDescription!,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  height: 1.5,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),
        ],

        // Progress Timeline Section
        _buildProgressTimelineSection(),

        const SizedBox(height: 20),

        // Work Progress Section
        _buildWorkProgressSection(),

        const SizedBox(height: 20),

        // Quality Control Section
        if (widget.task.qcStartedAt != null ||
            widget.task.qcNotes?.isNotEmpty == true) ...[
          _buildQualityControlSection(),
          const SizedBox(height: 20),
        ],

        // Resources & Attachments Section
        if (widget.task.taskAttachments?.isNotEmpty == true ||
            widget.task.devCompletedAttachments?.isNotEmpty == true ||
            widget.task.qcCompletedAttachments?.isNotEmpty == true) ...[
          _buildResourcesSection(isDesktop),
        ],
      ],
    );
  }

  /// Build task overview section
  Widget _buildTaskOverviewSection(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w300,
              color: Theme.of(context).textTheme.titleLarge?.color,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: isDesktop ? 20 : 16),
          // Project Name - Full width card
          _buildOverviewCard(
            'Project',
            widget.task.projectDetails?['project_name'] ??
                'No Project Assigned',
            Colors.purple,
            Icons.business,
            isDesktop: isDesktop,
            isFullWidth: true,
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'Priority',
                  _getPriorityText(),
                  _getPriorityColor(),
                  Icons.flag,
                  isDesktop: isDesktop,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: _buildOverviewCard(
                  'Type',
                  widget.task.taskType ?? 'General',
                  Colors.blue,
                  Icons.category,
                  isDesktop: isDesktop,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'Duration',
                  widget.task.taskDuration ?? 'Not specified',
                  Colors.orange,
                  Icons.schedule,
                  isDesktop: isDesktop,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: _buildOverviewCard(
                  'Status',
                  _getStatusText(),
                  _getStatusColor(),
                  _getStatusIcon(),
                  isDesktop: isDesktop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build overview card
  Widget _buildOverviewCard(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool isDesktop = false,
    bool isFullWidth = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodySmall?.color,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: isDesktop ? 12 : 8),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleMedium?.color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Build progress timeline section
  Widget _buildProgressTimelineSection() {
    // Get current workflow status to determine which steps are completed
    final status = widget.task.workflowStatus?.toLowerCase() ?? '';

    // Determine completion status based on workflow status, not just date fields
    bool isDevStarted = widget.task.devStartedAt != null;
    bool isDevCompleted = false;
    bool isQCStarted = false;
    bool isQCCompleted = false;

    // Check workflow status to determine actual completion state
    if (status == 'dev completed' ||
        status == 'dev_completed' ||
        status == 'in qc' ||
        status == 'in_qc' ||
        status == 'work done' ||
        status == 'work_done' ||
        status == 'completed') {
      isDevCompleted = true;
    }

    if (status == 'in qc' ||
        status == 'in_qc' ||
        status == 'work done' ||
        status == 'work_done' ||
        status == 'completed') {
      isQCStarted = true;
    }

    if (status == 'work done' ||
        status == 'work_done' ||
        status == 'completed') {
      isQCCompleted = true;
    }

    final steps = [
      {
        'title': 'Task Assigned',
        'date': widget.task.assignedAt,
        'icon': Icons.assignment_ind_rounded,
        'color': Colors.blue,
        'isCompleted': true, // Always completed if task exists
      },
      {
        'title': 'Development Started',
        'date': widget.task.devStartedAt,
        'icon': Icons.code_rounded,
        'color': Colors.orange,
        'isCompleted': isDevStarted,
      },
      {
        'title': 'Development Completed',
        'date': widget.task.devCompletedAt,
        'icon': Icons.check_circle_outline_rounded,
        'color': Colors.green,
        'isCompleted': isDevCompleted,
      },
      {
        'title': 'QC Started',
        'date': widget.task.qcStartedAt,
        'icon': Icons.bug_report_rounded,
        'color': Colors.purple,
        'isCompleted': isQCStarted,
      },
      {
        'title': 'QC Completed',
        'date': widget.task.qcCompletedAt,
        'icon': Icons.verified_rounded,
        'color': Colors.teal,
        'isCompleted': isQCCompleted,
      },
    ];

    return _buildInfoSection('Progress Timeline', Icons.timeline_rounded, [
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: steps.length,
        itemBuilder: (context, index) {
          final step = steps[index];
          return _buildTimelineItem(
            step['title'] as String,
            step['date'] as DateTime?,
            step['icon'] as IconData,
            step['color'] as Color,
            step['isCompleted'] as bool,
            isLast: index == steps.length - 1,
          );
        },
      ),
    ]);
  }

  /// Build timeline item
  Widget _buildTimelineItem(
    String title,
    DateTime? date,
    IconData icon,
    Color color,
    bool isCompleted, {
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line and icon
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? color.withOpacity(0.1)
                      : Colors.grey[100],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? color : Colors.grey[300]!,
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isCompleted ? color : Colors.grey[400],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? color.withOpacity(0.5)
                        : Colors.grey[300],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isCompleted
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isCompleted
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87)
                          : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (date != null)
                    Text(
                      _formatDateTime(date),
                      style: TextStyle(
                        fontSize: 13,
                        color: isCompleted
                            ? color
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[400],
                        fontStyle: FontStyle.italic,
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

  /// Build work progress section
  Widget _buildWorkProgressSection() {
    return _buildInfoSection('Work Progress', Icons.work, [
      if (widget.task.totalDevHours != null) ...[
        _buildProgressCard(
          'Development Hours',
          '${widget.task.totalDevHours} hours',
          Colors.blue,
          Icons.code,
        ),
      ],
      if (widget.task.devNotes?.isNotEmpty == true) ...[
        const SizedBox(height: 12),
        _buildNotesCard(
          'Development Notes',
          widget.task.devNotes!,
          Colors.blue,
          Icons.note,
        ),
      ],
    ]);
  }

  /// Build quality control section
  Widget _buildQualityControlSection() {
    return _buildInfoSection('Quality Control', Icons.verified_user, [
      // QC Timeline
      if (widget.task.qcStartedAt != null ||
          widget.task.qcCompletedAt != null) ...[
        _buildQCTimelineCard(),
        const SizedBox(height: 12),
      ],

      // QC Hours
      if (widget.task.qcTotalHours != null) ...[
        _buildProgressCard(
          'QC Hours',
          '${widget.task.qcTotalHours} hours',
          Colors.green,
          Icons.verified,
        ),
        const SizedBox(height: 12),
      ],

      // QC Notes
      if (widget.task.qcNotes?.isNotEmpty == true) ...[
        _buildNotesCard(
          'QC Notes',
          widget.task.qcNotes!,
          Colors.green,
          Icons.note,
        ),
        const SizedBox(height: 12),
      ],

      // QC Attachments
      if (widget.task.qcCompletedAttachments?.isNotEmpty == true) ...[
        _buildQCAttachmentsCard(),
        const SizedBox(height: 12),
      ],

      // Status Reason (for rejected tasks)
      if (widget.task.statusReason?.isNotEmpty == true) ...[
        _buildStatusReasonCard(),
      ],
    ]);
  }

  /// Build QC timeline card
  Widget _buildQCTimelineCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QC Timeline',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.green[700],
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.task.qcStartedAt != null) ...[
            _buildTimelineRow(
              'QC Started',
              widget.task.qcStartedAt!,
              Icons.play_circle,
              Colors.orange,
            ),
            const SizedBox(height: 6),
          ],
          if (widget.task.qcCompletedAt != null) ...[
            _buildTimelineRow(
              'QC Completed',
              widget.task.qcCompletedAt!,
              Icons.check_circle,
              Colors.green[700]!,
            ),
          ],
        ],
      ),
    );
  }

  /// Build timeline row
  Widget _buildTimelineRow(
    String label,
    DateTime date,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          Text(
            _formatDateTime(date),
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Build QC attachments card
  Widget _buildQCAttachmentsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'QC Attachments',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.task.qcCompletedAttachments!
              .map(
                (attachment) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getFileIcon(attachment),
                        size: 16,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getFileName(attachment),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Opening: ${_getFileName(attachment)}',
                              ),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.download,
                          size: 16,
                          color: Colors.blue[600],
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        onPressed: () => _copyAttachmentLink(attachment),
                        icon: Icon(
                          Icons.link_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Copy link',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  /// Build status reason card
  Widget _buildStatusReasonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text(
                'Rejection Reason',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[100]!, width: 1),
            ),
            child: Text(
              widget.task.statusReason!,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get file icon based on extension
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.attach_file;
    }
  }

  /// Get file name from full path
  String _getFileName(String filePath) {
    return filePath.split('/').last;
  }

  /// Copy link to clipboard with feedback
  Future<void> _copyAttachmentLink(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Link copied to clipboard'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy link: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Format date time for display
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Build resources section
  Widget _buildResourcesSection(bool isDesktop) {
    return _buildInfoSection('Resources & Attachments', Icons.attach_file, [
      if (widget.task.taskAttachments?.isNotEmpty == true) ...[
        _buildAttachmentsSection(
          'Task Resources',
          widget.task.taskAttachments!,
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 12),
      ],
      if (widget.task.devCompletedAttachments?.isNotEmpty == true) ...[
        _buildAttachmentsSection(
          'Development Files',
          widget.task.devCompletedAttachments!,
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 12),
      ],
      if (widget.task.qcCompletedAttachments?.isNotEmpty == true) ...[
        _buildAttachmentsSection(
          'QC Files',
          widget.task.qcCompletedAttachments!,
          isDesktop: isDesktop,
        ),
      ],
    ]);
  }

  /// Build individual attachment item
  Widget _buildAttachmentItem(String attachment, bool isDesktop) {
    final fileType = _getFileType(attachment);
    final fileName = _getFileName(attachment);

    return Container(
      margin: EdgeInsets.only(bottom: isDesktop ? 12 : 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleAttachmentTap(attachment, fileType),
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
          child: Container(
            padding: EdgeInsets.all(isDesktop ? 20 : 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // File type icon with premium styling
                Container(
                  width: isDesktop ? 48 : 40,
                  height: isDesktop ? 48 : 40,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                  ),
                  child: Center(child: _buildFileTypeIcon(fileType, isDesktop)),
                ),
                SizedBox(width: isDesktop ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      SizedBox(height: isDesktop ? 6 : 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 8 : 6,
                          vertical: isDesktop ? 3 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            isDesktop ? 6 : 4,
                          ),
                        ),
                        child: Text(
                          fileType.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: isDesktop ? 10 : 9,
                                letterSpacing: 0.5,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isDesktop ? 12 : 8),
                // Download button with premium styling
                Container(
                  width: isDesktop ? 40 : 36,
                  height: isDesktop ? 40 : 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                      onTap: () => _handleAttachmentTap(attachment, fileType),
                      child: Center(
                        child: Icon(
                          Icons.download_rounded,
                          size: isDesktop ? 20 : 18,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isDesktop ? 8 : 6),
                // Copy link button
                Tooltip(
                  message: 'Copy link',
                  child: Container(
                    width: isDesktop ? 40 : 36,
                    height: isDesktop ? 40 : 36,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                        onTap: () => _copyAttachmentLink(attachment),
                        child: Center(
                          child: Icon(
                            Icons.link_rounded,
                            size: isDesktop ? 20 : 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
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
    );
  }

  /// Get file type from URL
  String _getFileType(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'unknown';

    final path = uri.path.toLowerCase();
    if (path.endsWith('.pdf')) return 'pdf';
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp') ||
        path.endsWith('.bmp'))
      return 'image';
    if (path.endsWith('.doc') || path.endsWith('.docx')) return 'document';
    if (path.endsWith('.xls') || path.endsWith('.xlsx')) return 'spreadsheet';
    if (path.endsWith('.ppt') || path.endsWith('.pptx')) return 'presentation';
    if (path.endsWith('.txt')) return 'text';
    if (path.endsWith('.zip') || path.endsWith('.rar') || path.endsWith('.7z'))
      return 'archive';
    return 'file';
  }

  /// Get file type icon
  Widget _buildFileTypeIcon(String fileType, bool isDesktop) {
    IconData iconData;
    Color iconColor;

    switch (fileType) {
      case 'pdf':
        iconData = Icons.picture_as_pdf_rounded;
        break;
      case 'image':
        iconData = Icons.image_rounded;
        break;
      case 'document':
        iconData = Icons.description_rounded;
        break;
      case 'spreadsheet':
        iconData = Icons.table_chart_rounded;
        break;
      case 'presentation':
        iconData = Icons.slideshow_rounded;
        break;
      case 'text':
        iconData = Icons.text_snippet_rounded;
        break;
      case 'archive':
        iconData = Icons.archive_rounded;
        break;
      default:
        iconData = Icons.attach_file_rounded;
    }

    // Use theme primary color for consistency
    iconColor = Theme.of(context).colorScheme.primary;

    return Container(
      width: isDesktop ? 48 : 40,
      height: isDesktop ? 48 : 40,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isDesktop ? 12 : 8),
        border: Border.all(color: iconColor.withOpacity(0.3), width: 1),
      ),
      child: Icon(iconData, color: iconColor, size: isDesktop ? 24 : 20),
    );
  }

  /// Handle attachment tap - now downloads all file types
  void _handleAttachmentTap(String url, String fileType) {
    // Download all file types instead of viewing
    _downloadFileWithFallback(url);
  }

  /// Build progress card
  Widget _buildProgressCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Build notes card
  Widget _buildNotesCard(
    String title,
    String notes,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            notes,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              height: 1.5,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Build info section
  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w300,
            color: Theme.of(context).textTheme.titleMedium?.color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  /// Build attachments section
  Widget _buildAttachmentsSection(
    String title,
    List<String> attachments, {
    bool isDesktop = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.02),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isDesktop ? 36 : 32,
                height: isDesktop ? 36 : 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isDesktop ? 8 : 6),
                ),
                child: Icon(
                  Icons.attach_file_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: isDesktop ? 18 : 16,
                ),
              ),
              SizedBox(width: isDesktop ? 12 : 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 8 : 6,
                  vertical: isDesktop ? 4 : 3,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isDesktop ? 6 : 4),
                ),
                child: Text(
                  '${attachments.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: isDesktop ? 11 : 10,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          ...attachments
              .map(
                (attachment) => Padding(
                  padding: EdgeInsets.symmetric(vertical: isDesktop ? 6 : 4),
                  child: _buildAttachmentItem(attachment, isDesktop),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  /// Build dialog footer
  Widget _buildDialogFooter(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(isDesktop ? 24 : 20),
          bottomRight: Radius.circular(isDesktop ? 24 : 20),
        ),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 24,
                vertical: isDesktop ? 16 : 12,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(isDesktop ? 12 : 8),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                'Close',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get status icon
  IconData _getStatusIcon() {
    switch (widget.task.workflowStatus?.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'in_progress':
        return Icons.play_circle;
      case 'completed':
      case 'dev completed':
        return Icons.check_circle;
      case 'delayed':
        return Icons.schedule;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  /// Download file with platform-specific handling
  Future<void> _downloadFileWithFallback(String url) async {
    try {
      print('Starting download for URL: $url'); // Debug log
      print('kIsWeb: $kIsWeb'); // Debug log

      if (kIsWeb) {
        // For web platform, use web download directly
        print('Using web download method'); // Debug log
        await _downloadViaBrowser(url);
      } else {
        // For native platforms, use native download
        print('Using native download method'); // Debug log
        try {
          await _downloadFileNative(url);
        } catch (nativeError) {
          print(
            'Native download failed, trying browser fallback: $nativeError',
          ); // Debug log
          // Fallback to browser for native platforms
          await _downloadViaBrowser(url);
        }
      }
    } catch (e) {
      print('All download methods failed: $e'); // Debug log

      // Final fallback: Show error with manual download option
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed. Please try manually: $url'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Copy URL',
              textColor: Colors.white,
              onPressed: () {
                // Copy URL to clipboard
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('URL copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  /// Download method for web platform using browser
  Future<void> _downloadViaBrowser(String url) async {
    try {
      print('Using browser download for web platform'); // Debug log

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Downloading file...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // For web, try to force download by using a different approach
      if (kIsWeb) {
        // Create a temporary anchor element to force download
        await _downloadFileWeb(url);
      } else {
        // For native platforms, open in browser
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Download started in browser'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Cannot launch URL');
        }
      }
    } catch (e) {
      throw Exception('Browser download failed: $e');
    }
  }

  /// Web-specific download method
  Future<void> _downloadFileWeb(String url) async {
    try {
      print('Using web-specific download method'); // Debug log

      // Use Dio to download the file and then create a blob for download
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'User-Agent': 'Mozilla/5.0 (compatible; Flutter App)'},
        ),
      );

      // Get file name from URL
      final fileName = _getFileName(url);
      print(
        'Downloaded file: $fileName, size: ${response.data.length} bytes',
      ); // Debug log

      // Create a blob URL and trigger download
      await _triggerWebDownload(response.data, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Downloaded: $fileName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Web download failed: $e'); // Debug log
      throw Exception('Web download failed: $e');
    }
  }

  /// Trigger download in web browser using HTML5 Blob API
  Future<void> _triggerWebDownload(List<int> bytes, String fileName) async {
    try {
      if (kIsWeb) {
        // Create a blob from the bytes
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        // Create a temporary anchor element to trigger download
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..style.display = 'none';

        // Add to DOM, click, and remove
        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);

        // Clean up the object URL
        html.Url.revokeObjectUrl(url);

        print('Web download triggered for: $fileName'); // Debug log
      } else {
        throw Exception('Not running on web platform');
      }
    } catch (e) {
      print('Failed to trigger web download: $e'); // Debug log
      throw Exception('Failed to trigger web download: $e');
    }
  }

  /// Download method for native platforms (mobile/desktop)
  Future<void> _downloadFileNative(String url) async {
    try {
      print('Using native download for mobile/desktop platform'); // Debug log

      // Check if we're on web platform (Platform checks will fail on web)
      if (kIsWeb) {
        throw Exception('Web platform detected, cannot use native download');
      }

      // Check and request permissions for Android
      if (Platform.isAndroid) {
        print('Checking Android permissions...'); // Debug log

        // Check storage permission
        var storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          print('Requesting storage permission...'); // Debug log
          storageStatus = await Permission.storage.request();
        }

        // For Android 13+ (API 33+), also check for media permissions
        var mediaStatus = await Permission.photos.status;
        if (!mediaStatus.isGranted) {
          print('Requesting media permission...'); // Debug log
          mediaStatus = await Permission.photos.request();
        }

        if (!storageStatus.isGranted) {
          throw Exception(
            'Storage permission denied. Please grant storage permission to download files.',
          );
        }
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Downloading file...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final dio = Dio();
      final fileName = _getFileName(url);
      print('File name: $fileName'); // Debug log

      // Get download directory
      Directory? downloadDir;
      if (Platform.isAndroid) {
        // Try external storage first, fallback to app directory
        try {
          downloadDir = Directory('/storage/emulated/0/Download');
          if (!await downloadDir.exists()) {
            downloadDir = await getExternalStorageDirectory();
            if (downloadDir != null) {
              downloadDir = Directory('${downloadDir.path}/Downloads');
            }
          }
        } catch (e) {
          print('External storage failed, using app directory: $e');
          downloadDir = await getApplicationDocumentsDirectory();
        }
        print('Android platform detected'); // Debug log
      } else if (Platform.isIOS) {
        downloadDir = await getApplicationDocumentsDirectory();
        print('iOS platform detected'); // Debug log
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        downloadDir = await getDownloadsDirectory();
        print('Desktop platform detected'); // Debug log
      }

      if (downloadDir == null) {
        throw Exception('Could not access download directory');
      }

      print('Download directory: ${downloadDir.path}'); // Debug log

      // Check if directory exists, create if not
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
        print('Created download directory'); // Debug log
      }

      final filePath = '${downloadDir.path}/$fileName';
      print('Full file path: $filePath'); // Debug log

      // Download the file with timeout and progress
      await dio.download(
        url,
        filePath,
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
          headers: {'User-Agent': 'Mozilla/5.0 (compatible; Flutter App)'},
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            print(
              'Download progress: ${(received / total * 100).toStringAsFixed(0)}%',
            );
          }
        },
      );

      print('Download completed successfully'); // Debug log

      // Show success message with option to open
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Downloaded: $fileName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => _openDownloadedFile(filePath),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Download error: $e'); // Debug log
      print('Stack trace: $stackTrace'); // Debug log

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.error_rounded, size: 16, color: Colors.red),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Download failed: ${e.toString().length > 50 ? e.toString().substring(0, 50) + '...' : e.toString()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Open downloaded file
  Future<void> _openDownloadedFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
