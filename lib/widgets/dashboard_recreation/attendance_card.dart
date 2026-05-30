import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RecreatedAttendanceCard extends StatefulWidget {
  const RecreatedAttendanceCard({super.key});

  @override
  State<RecreatedAttendanceCard> createState() => _RecreatedAttendanceCardState();
}

class _RecreatedAttendanceCardState extends State<RecreatedAttendanceCard>
    with SingleTickerProviderStateMixin {
  bool _isPunchedIn = false;
  late AnimationController _pulseController;
  bool _isActionHovered = false;
  bool _isStatusHovered = false;

  DateTime? _punchInTime;
  Duration _sessionDuration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _punchInTime = DateTime.now();
    _sessionDuration = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _sessionDuration = DateTime.now().difference(_punchInTime!);
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $amPm';
  }

  void _handlePunchIn() {
    setState(() {
      _isPunchedIn = true;
      _startTimer();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Punched In Successfully!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        width: 240,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  void _handlePunchOut() {
    setState(() {
      _isPunchedIn = false;
      _stopTimer();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Punched Out Successfully!',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        width: 240,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Timings Status Card (Always visible)
        Expanded(
          flex: 5,
          child: _buildTimingsCard(),
        ),
        const SizedBox(width: 12),
        // 2. Action Card (Toggles between Fingerprint scanner and Active live timer)
        Expanded(
          flex: 4,
          child: _isPunchedIn ? _buildActiveSessionCard() : _buildFingerprintCard(),
        ),
      ],
    );
  }

  Widget _buildTimingsCard() {
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
                                      'LIVE SESSION',
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
                          '09:10:15 AM',
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
                                      'LIVE SESSION',
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
                          '06:21:52 PM',
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
        onTap: _handlePunchIn,
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

  Widget _buildActiveSessionCard() {
    final startTimeStr = _punchInTime != null ? _formatDateTime(_punchInTime!) : '09:15 AM';
    final durationStr = _formatDuration(_sessionDuration);

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
                          onTap: _handlePunchOut,
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
}
