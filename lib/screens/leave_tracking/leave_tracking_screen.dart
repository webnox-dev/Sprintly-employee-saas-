import 'dart:ui';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import 'package:webnox_taskops/view_model/attendance_view_model.dart';
import 'package:webnox_taskops/view_model/work_from_home_view_model.dart';
import 'package:webnox_taskops/view_model/permission_view_model.dart';
import 'package:webnox_taskops/view_model/task_view_model.dart';
import 'package:webnox_taskops/services/leave_service.dart';
import 'package:webnox_taskops/model/work_from_home_model.dart';
import 'package:webnox_taskops/model/permission_model.dart';
import 'package:webnox_taskops/model/employee_attendance_model.dart';
import 'package:webnox_taskops/theme/app_theme.dart';

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

class _LeaveTrackingScreenState extends State<LeaveTrackingScreen> {
  int selectedTab = 0; // Default to Leave (tab 0) matching the mockup!
  final LeaveService _leaveService = LeaveService();
  List<Map<String, dynamic>> _leaveHistory = [];
  bool _loadingLeaves = false;
  final DateTime _selectedMonth = DateTime.now();
  String _employeeName = 'Employee';
  String? _employeeId;

  // --- Permission Tab State ---
  String _filterStatus = 'All Status';
  String _filterType = 'All Types';
  String _filterPeriod = 'This Month';

  String _appliedFilterStatus = 'All Status';
  String _appliedFilterType = 'All Types';
  String _appliedFilterPeriod = 'This Month';

  int _currentPermissionPage = 1;
  static const int _permissionItemsPerPage = 5;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeState();
    });
  }

  Future<void> _initializeState() async {
    if (!mounted) return;
    setState(() => _loadingLeaves = true);
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.isAuthenticated) {
        final employeeDetails = await authViewModel.getCurrentEmployeeDetails();
        if (employeeDetails != null) {
          _employeeId = (employeeDetails['employee_id'] ?? employeeDetails['employeeId'])?.toString();
          _employeeName = employeeDetails['employee_name'] ?? employeeDetails['employeeName'] ?? 'Employee';
          if (_employeeId != null) {
            _fetchLeaveHistory();
          }
        }
      }
    } catch (e) {
      print('Error initializing LeaveTrackingScreen: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingLeaves = false);
      }
    }
  }

  Future<void> _fetchLeaveHistory() async {
    if (_employeeId == null) return;
    setState(() => _loadingLeaves = true);
    try {
      final history = await _leaveService.getLeaveHistory(_employeeId!);
      if (mounted) {
        setState(() {
          _leaveHistory = history;
        });
      }
    } catch (e) {
      print('Error fetching leave history: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingLeaves = false);
      }
    }
  }

  String _formatMonthYear(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTimeString12Hr(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.isNotEmpty) {
        int hour = int.parse(parts[0]);
        int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
        final period = hour >= 12 ? 'PM' : 'AM';
        hour = hour % 12;
        if (hour == 0) hour = 12;
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      }
    } catch (e) {
      //
    }
    return timeStr;
  }

  String _formatDateShort(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateLong(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthStr = months[date.month - 1];
    return '$monthStr ${date.day}, ${date.year}';
  }

  String _formatDateYYYYMMDD(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, String>> _getTaskStatuses(List<String> taskIds) async {
    try {
      final taskViewModel = Provider.of<TaskViewModel>(context, listen: false);
      return await taskViewModel.fetchTaskStatuses(taskIds);
    } catch (e) {
      print('Error fetching task statuses: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => WorkFromHomeViewModel()..initializeData(context),
        ),
        ChangeNotifierProvider(
          create: (context) => PermissionViewModel()..initializeData(context),
        ),
      ],
      child: Consumer3<AttendanceViewModel, WorkFromHomeViewModel, PermissionViewModel>(
        builder: (context, attendanceViewModel, wfhViewModel, permissionViewModel, child) {
          final isWide = MediaQuery.of(context).size.width > 900;
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // Ambient Glows
                _buildBackgroundGlows(context),

                // Main Content Column
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Stats row at the top
                      _buildStatsRow(context, attendanceViewModel, wfhViewModel, permissionViewModel),
                      const SizedBox(height: 24),

                      // 2. Center aligned tab bar
                      _buildTabBar(context),
                      const SizedBox(height: 24),

                      // 3. Tab Content
                      Expanded(
                        child: _buildTabContent(context, attendanceViewModel, wfhViewModel, permissionViewModel, isWide),
                      ),
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

  Widget _buildBackgroundGlows(BuildContext context) {
    return Stack(
      children: [
        // Top Right Glow
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 500,
            height: 500,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x1A1E3A8A), // Blue glow
                  Color(0x001E3A8A),
                ],
              ),
            ),
          ),
        ),
        // Bottom Left Glow
        Positioned(
          bottom: -150,
          left: -150,
          child: Container(
            width: 600,
            height: 600,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x263B82F6), // Bright blue glow
                  Color(0x003B82F6),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    AttendanceViewModel attendanceViewModel,
    WorkFromHomeViewModel wfhViewModel,
    PermissionViewModel permissionViewModel,
  ) {
    int approvedLeaves = 0;
    for (final leave in _leaveHistory) {
      final isApproved = (leave['leave_status'] ?? 0) == 1;
      if (isApproved) approvedLeaves++;
    }

    final pendingLeaves = _leaveHistory.where((l) => (l['leave_status'] ?? 0) == 0 && l['approved_by'] == null && l['rejected_by'] == null).length;
    final pendingWFH = wfhViewModel.requests.where((r) => r.isPending).length;
    final pendingPermissions = permissionViewModel.requests.where((r) => r.isPending).length;
    final totalPending = pendingLeaves + pendingWFH + pendingPermissions;

    final attendanceRate = '96.5%';
    final isWide = MediaQuery.of(context).size.width > 900;

    final cards = [
      _buildStatCard(
        title: 'TOTAL LEAVE REQUESTS',
        value: _loadingLeaves ? '...' : _leaveHistory.length.toString(),
        subtitle: 'This Year',
        icon: Icons.calendar_month_rounded,
        iconColor: const Color(0xFF3B82F6),
      ),
      _buildStatCard(
        title: 'APPROVED LEAVES',
        value: _loadingLeaves ? '...' : approvedLeaves.toString(),
        subtitle: 'Successfully taken',
        icon: Icons.check_circle_rounded,
        iconColor: const Color(0xFF10B981),
      ),
      _buildStatCard(
        title: 'PENDING REQUESTS',
        value: totalPending.toString(),
        subtitle: 'Awaiting approval',
        icon: Icons.hourglass_empty_rounded,
        iconColor: const Color(0xFFF59E0B),
      ),
      _buildStatCard(
        title: 'ATTENDANCE RATE',
        value: attendanceRate,
        subtitle: '',
        icon: Icons.insert_chart_rounded,
        iconColor: const Color(0xFF3B82F6),
        isProgressCard: true,
      ),
    ];

    if (isWide) {
      return Row(
        children: cards.map((c) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: c,
          ),
        )).toList(),
      );
    } else {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: cards,
      );
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    bool isProgressCard = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.lexend(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.lexend(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isProgressCard)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 0.965,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                          minHeight: 4,
                        ),
                      )
                    else
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.4),
                        ),
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

  Widget _buildTabBar(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _buildTabItem(context, 'Leave', Icons.calendar_month_rounded, 0),
            _buildTabItem(context, 'WFH', Icons.home_work_rounded, 1),
            _buildTabItem(context, 'Permission', Icons.person_search_rounded, 2),
            _buildTabItem(context, 'History', Icons.history_rounded, 3),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, String title, IconData icon, int index) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => selectedTab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.3) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    AttendanceViewModel attendanceViewModel,
    WorkFromHomeViewModel wfhViewModel,
    PermissionViewModel permissionViewModel,
    bool isWide,
  ) {
    if (selectedTab == 0) {
      return isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: _buildRequestLeaveCard(context),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: _buildLeaveHistoryCard(context),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildRequestLeaveCard(context),
                  const SizedBox(height: 24),
                  _buildLeaveHistoryCard(context),
                ],
              ),
            );
    } else if (selectedTab == 1) {
      return isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: _buildRequestWFHCard(context, wfhViewModel),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: _buildWFHHistoryCard(context, wfhViewModel),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildRequestWFHCard(context, wfhViewModel),
                  const SizedBox(height: 24),
                  _buildWFHHistoryCard(context, wfhViewModel),
                ],
              ),
            );
    } else if (selectedTab == 2) {
      return isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: _buildRequestPermissionCard(context, permissionViewModel),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: _buildPermissionHistoryCard(context, permissionViewModel),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildRequestPermissionCard(context, permissionViewModel),
                  const SizedBox(height: 24),
                  _buildPermissionHistoryCard(context, permissionViewModel),
                ],
              ),
            );
    } else {
      return isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _buildUnifiedRequestHistoryCard(context, wfhViewModel, permissionViewModel),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildAttendanceAnalyticsCard(context, attendanceViewModel),
                        const SizedBox(height: 24),
                        _buildAttendanceGraphsCard(context, attendanceViewModel),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildUnifiedRequestHistoryCard(context, wfhViewModel, permissionViewModel),
                  const SizedBox(height: 24),
                  _buildAttendanceAnalyticsCard(context, attendanceViewModel),
                  const SizedBox(height: 24),
                  _buildAttendanceGraphsCard(context, attendanceViewModel),
                ],
              ),
            );
    }
  }

  // --- WFH Tab Widgets ---
  Widget _buildRequestWFHCard(BuildContext context, WorkFromHomeViewModel viewModel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: _RequestWFHForm(viewModel: viewModel),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWFHHistoryCard(BuildContext context, WorkFromHomeViewModel viewModel) {
    final wfhRequests = viewModel.requests;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'WFH Requests',
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _formatMonthYear(_selectedMonth),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (viewModel.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (wfhRequests.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 12),
                          Text(
                            'No WFH requests found',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (MediaQuery.of(context).size.width > 900)
                  Expanded(
                    child: ListView.builder(
                      itemCount: wfhRequests.length,
                      itemBuilder: (context, index) {
                        final req = wfhRequests[index];
                        return _buildWFHRequestItemCard(context, req);
                      },
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: wfhRequests.length,
                    itemBuilder: (context, index) {
                      final req = wfhRequests[index];
                      return _buildWFHRequestItemCard(context, req);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWFHRequestItemCard(BuildContext context, WorkFromHomeRequest req) {
    Color statusColor;
    switch (req.status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
    }

    final String startDateStr = _formatDateShort(req.startDate);
    final String submittedDateStr = req.createdAt != null ? _formatDateShort(req.createdAt!) : 'Recent';

    final isHalfDay = req.totalDays < 1.0 || (req.reason?.toLowerCase().contains('half') ?? false);
    final title = isHalfDay ? 'Half Day WFH - Morning' : 'Full Day WFH';
    final durationText = '${req.totalDays} day${req.totalDays > 1 ? 's' : ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.home_work_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$startDateStr • $durationText',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      req.status,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (req.reason != null && req.reason!.isNotEmpty) ...[
            Text(
              req.reason!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 12, color: Colors.white.withOpacity(0.3)),
              const SizedBox(width: 4),
              Text(
                'Manager: ${req.approvedBy ?? "Ananya R."}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white.withOpacity(0.3)),
              const SizedBox(width: 4),
              Text(
                'Submitted: $submittedDateStr',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Leave Tab Widgets ---
  Widget _buildRequestLeaveCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: _RequestLeaveForm(
                leaveService: _leaveService,
                onLeaveSubmitted: () {
                  _fetchLeaveHistory();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveHistoryCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Leave Requests',
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Please fill out the Request Leave form on the left.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
                            ),
                            backgroundColor: const Color(0xFF3B82F6),
                            behavior: SnackBarBehavior.floating,
                            width: 280,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add,
                              color: Colors.white.withOpacity(0.6),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'New Request',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_loadingLeaves)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_leaveHistory.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 12),
                          Text(
                            'No leave requests found',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (MediaQuery.of(context).size.width > 900)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _leaveHistory.length,
                      itemBuilder: (context, index) {
                        return _buildLeaveRequestItemCard(context, _leaveHistory[index]);
                      },
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _leaveHistory.length,
                    itemBuilder: (context, index) {
                      return _buildLeaveRequestItemCard(context, _leaveHistory[index]);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveRequestItemCard(BuildContext context, Map<String, dynamic> req) {
    final String type = req['leave_type'] ?? 'Leave';
    final String employee = _employeeName;
    final isApproved = (req['leave_status'] ?? 0) == 1;
    final isRejected = req['approved_by'] == null && req['rejected_by'] != null;
    final String status = isApproved ? 'Approved' : (isRejected ? 'Rejected' : 'Pending');
    final DateTime startDate = DateTime.tryParse(req['leave_from_date'] ?? '') ?? DateTime.now();
    final DateTime endDate = DateTime.tryParse(req['leave_to_date'] ?? '') ?? DateTime.now();
    final int durationDays = req['total_leave_days'] ?? 1;

    Color iconColor;
    IconData iconData;
    switch (type) {
      case 'Annual Leave':
        iconColor = const Color(0xFF3B82F6);
        iconData = Icons.calendar_today_rounded;
        break;
      case 'Sick Leave':
        iconColor = const Color(0xFFF59E0B);
        iconData = Icons.history_rounded;
        break;
      case 'Maternity Leave':
        iconColor = Colors.white.withOpacity(0.5);
        iconData = Icons.event_note_rounded;
        break;
      default:
        iconColor = const Color(0xFFEC4899);
        iconData = Icons.beach_access_rounded;
    }

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        break;
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'rejected':
      default:
        statusColor = Colors.white.withOpacity(0.6);
    }

    final String startDateStr = _formatDateYYYYMMDD(startDate);
    final String endDateStr = _formatDateYYYYMMDD(endDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: iconColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        employee,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.4),
                          ),
                          children: [
                            const TextSpan(text: 'Status: '),
                            TextSpan(
                              text: status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
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
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'From: $startDateStr',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'To: $endDateStr',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Duration: $durationDays day${durationDays > 1 ? 's' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Transform(
                    transform: Matrix4.rotationY(3.14159),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.reply_rounded,
                      color: Colors.white.withOpacity(0.3),
                      size: 16,
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

  // --- Permission Tab Widgets ---
  Widget _buildRequestPermissionCard(BuildContext context, PermissionViewModel viewModel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: _RequestPermissionForm(
                viewModel: viewModel,
                onPermissionSubmitted: () {
                  if (_employeeId != null) {
                    viewModel.fetchPermissionRequests(_employeeId!);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionHistoryCard(BuildContext context, PermissionViewModel viewModel) {
    final filteredPermissions = viewModel.requests.where((req) {
      if (_appliedFilterStatus != 'All Status') {
        if (req.status != _appliedFilterStatus) return false;
      }
      
      String type = 'Permission';
      String reason = req.permissionRemarks ?? '';
      if (reason.startsWith('[') && reason.contains(']')) {
        final closeBracket = reason.indexOf(']');
        type = reason.substring(1, closeBracket);
      }
      
      if (_appliedFilterType != 'All Types') {
        if (type != _appliedFilterType) return false;
      }
      
      final DateTime reqDate = req.permissionDate;
      if (_appliedFilterPeriod == 'This Month') {
        if (reqDate.year != _selectedMonth.year || reqDate.month != _selectedMonth.month) return false;
      } else if (_appliedFilterPeriod == 'Last Month') {
        final lastMonth = _selectedMonth.month == 1 ? 12 : _selectedMonth.month - 1;
        final lastYear = _selectedMonth.month == 1 ? _selectedMonth.year - 1 : _selectedMonth.year;
        if (reqDate.year != lastYear || reqDate.month != lastMonth) return false;
      } else if (_appliedFilterPeriod == 'This Year') {
        if (reqDate.year != _selectedMonth.year) return false;
      }
      return true;
    }).toList();

    final totalRequests = filteredPermissions.length;
    final totalPages = (totalRequests / _permissionItemsPerPage).ceil() == 0 ? 1 : (totalRequests / _permissionItemsPerPage).ceil();

    if (_currentPermissionPage > totalPages) {
      _currentPermissionPage = totalPages;
    }

    final startIndex = (_currentPermissionPage - 1) * _permissionItemsPerPage;
    final endIndex = startIndex + _permissionItemsPerPage > totalRequests 
        ? totalRequests 
        : startIndex + _permissionItemsPerPage;

    final paginatedRequests = filteredPermissions.isEmpty 
        ? <PermissionRequest>[] 
        : filteredPermissions.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterRow(context),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permission Requests',
                          style: GoogleFonts.lexend(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Showing ${paginatedRequests.length} of $totalRequests requests',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.sort_rounded, color: Colors.white.withOpacity(0.4), size: 16),
                        const SizedBox(width: 12),
                        Icon(Icons.view_headline_rounded, color: Colors.white.withOpacity(0.4), size: 16),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (viewModel.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (paginatedRequests.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 12),
                          Text(
                            'No permission requests found',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (MediaQuery.of(context).size.width > 900)
                  Expanded(
                    child: ListView.builder(
                      itemCount: paginatedRequests.length,
                      itemBuilder: (context, index) {
                        return _buildPermissionItemCard(context, paginatedRequests[index]);
                      },
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: paginatedRequests.length,
                    itemBuilder: (context, index) {
                      return _buildPermissionItemCard(context, paginatedRequests[index]);
                    },
                  ),
                if (totalPages > 1) ...[
                  const Divider(color: Colors.white12, height: 24),
                  _buildPaginationRow(totalPages),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          final content = [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_alt_rounded, color: Colors.white.withOpacity(0.6), size: 16),
                const SizedBox(width: 6),
                Text(
                  'FILTERS',
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            if (!isCompact) const Spacer(),
            if (isCompact) const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildMiniDropdown(
                  value: _filterStatus,
                  items: ['All Status', 'Pending', 'Approved', 'Rejected'],
                  onChanged: (val) {
                    if (val != null) setState(() => _filterStatus = val);
                  },
                ),
                _buildMiniDropdown(
                  value: _filterType,
                  items: ['All Types', 'Early Leave', 'Late Arrival', 'Personal Errand', 'Medical Appointment', 'Mid-day Break'],
                  onChanged: (val) {
                    if (val != null) setState(() => _filterType = val);
                  },
                ),
                _buildMiniDropdown(
                  value: _filterPeriod,
                  items: ['This Month', 'Last Month', 'This Year', 'All'],
                  onChanged: (val) {
                    if (val != null) setState(() => _filterPeriod = val);
                  },
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _appliedFilterStatus = _filterStatus;
                      _appliedFilterType = _filterType;
                      _appliedFilterPeriod = _filterPeriod;
                      _currentPermissionPage = 1;
                    });
                  },
                  icon: const Icon(Icons.search_rounded, size: 12),
                  label: Text('Apply', style: GoogleFonts.lexend(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterStatus = 'All Status';
                      _filterType = 'All Types';
                      _filterPeriod = 'This Month';
                      _appliedFilterStatus = 'All Status';
                      _appliedFilterType = 'All Types';
                      _appliedFilterPeriod = 'This Month';
                      _currentPermissionPage = 1;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                  ),
                  child: Text('Reset', style: GoogleFonts.lexend(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ];

          return isCompact 
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content,
                )
              : Row(
                  children: content,
                );
        },
      ),
    );
  }

  Widget _buildMiniDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF0F172A),
          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(0.6), size: 12),
          isDense: true,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPermissionItemCard(BuildContext context, PermissionRequest req) {
    String type = 'Permission';
    String reason = req.permissionRemarks ?? '';
    if (reason.startsWith('[') && reason.contains(']')) {
      final closeBracket = reason.indexOf(']');
      type = reason.substring(1, closeBracket);
      reason = reason.substring(closeBracket + 1).trim();
    }
    final String status = req.status;
    final DateTime date = req.permissionDate;

    Color statusColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.hourglass_empty_rounded;
    }

    final String dateStr = _formatDateLong(date);
    final String timeRangeStr = '${_formatTimeString12Hr(req.permissionFromTime)} - ${_formatTimeString12Hr(req.permissionToTime)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: GoogleFonts.lexend(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason.isEmpty ? 'No reason provided' : reason,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time_rounded, size: 12, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(width: 4),
                    Text(
                      timeRangeStr,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                req.formattedDuration,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationRow(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: _currentPermissionPage > 1
              ? () => setState(() => _currentPermissionPage--)
              : null,
          icon: const Icon(Icons.arrow_back_rounded, size: 14),
          label: Text('Previous', style: GoogleFonts.inter(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withOpacity(0.2),
          ),
        ),
        Text(
          'Page $_currentPermissionPage of $totalPages',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        TextButton.icon(
          onPressed: _currentPermissionPage < totalPages
              ? () => setState(() => _currentPermissionPage++)
              : null,
          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
          label: Text('Next', style: GoogleFonts.inter(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  // --- History Tab Widgets ---
  Widget _buildUnifiedRequestHistoryCard(
    BuildContext context,
    WorkFromHomeViewModel wfhViewModel,
    PermissionViewModel permissionViewModel,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request History',
                  style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 480,
                  child: _buildUnifiedHistoryList(context, wfhViewModel, permissionViewModel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedHistoryList(
    BuildContext context,
    WorkFromHomeViewModel wfhViewModel,
    PermissionViewModel permissionViewModel,
  ) {
    List<_UnifiedHistoryItem> allItems = [];

    // 1. Add Leave History Items
    for (var leave in _leaveHistory) {
      final date = DateTime.tryParse(leave['leave_from_date'] ?? '') ?? DateTime.now();
      allItems.add(_UnifiedHistoryItem(
        date: date,
        widget: _buildUnifiedLeaveCard(context, leave),
      ));
    }

    // 2. Add WFH History Items
    for (var request in wfhViewModel.requests) {
      allItems.add(_UnifiedHistoryItem(
        date: request.startDate,
        widget: _buildUnifiedWFHCard(context, request),
      ));
    }

    // 3. Add Permission History Items
    for (var request in permissionViewModel.requests) {
      allItems.add(_UnifiedHistoryItem(
        date: request.permissionDate,
        widget: _buildUnifiedPermissionCard(context, request),
      ));
    }

    if (allItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 12),
              Text(
                'No requests found',
                style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by date descending
    allItems.sort((a, b) => b.date.compareTo(a.date));

    return ListView.builder(
      itemCount: allItems.length,
      itemBuilder: (context, index) => allItems[index].widget,
    );
  }

  Widget _buildUnifiedLeaveCard(BuildContext context, Map<String, dynamic> leave) {
    final startDate = DateTime.tryParse(leave['leave_from_date'] ?? '') ?? DateTime.now();
    final isApproved = (leave['leave_status'] ?? 0) == 1;
    final isRejected = leave['approved_by'] == null && leave['rejected_by'] != null;
    final status = isApproved ? 'Approved' : (isRejected ? 'Rejected' : 'Pending');
    final String leaveType = leave['leave_type'] ?? 'Annual Leave';
    final int duration = leave['total_leave_days'] ?? 1;

    Color statusColor;
    switch (status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF3B82F6), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leaveType,
                  style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDateShort(startDate)} • $duration day${duration > 1 ? "s" : ""}',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedWFHCard(BuildContext context, WorkFromHomeRequest req) {
    Color statusColor;
    switch (req.status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
    }

    final durationText = '${req.totalDays} day${req.totalDays > 1 ? "s" : ""}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.home_work_rounded, color: statusColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Work From Home',
                  style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDateShort(req.startDate)} • $durationText',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Text(
              req.status,
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedPermissionCard(BuildContext context, PermissionRequest req) {
    Color statusColor;
    switch (req.status.toLowerCase()) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
    }

    String type = 'Permission';
    String reason = req.permissionRemarks ?? '';
    if (reason.startsWith('[') && reason.contains(']')) {
      final closeBracket = reason.indexOf(']');
      type = reason.substring(1, closeBracket);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.person_search_rounded, color: statusColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDateShort(req.permissionDate)} • ${req.formattedDuration}',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Text(
              req.status,
              style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceAnalyticsCard(BuildContext context, AttendanceViewModel attendanceViewModel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.analytics, color: Color(0xFF3B82F6), size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Task Analytics',
                      style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FutureBuilder<Map<String, dynamic>?>(
                  future: attendanceViewModel.getDailyWorkSummary(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final summary = snapshot.data;
                    if (summary == null) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.01),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Center(
                          child: Text(
                            'No analytics data available for today',
                            style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 13),
                          ),
                        ),
                      );
                    }

                    final totalDailyHours = (summary['total_daily_hours'] as num?)?.toDouble() ?? 0.0;
                    final taskSessions = summary['tasks_for_the_day'] ?? [];
                    final uniqueTaskIds = taskSessions
                        .map((session) => session['task_id'] as String?)
                        .whereType<String>()
                        .where((String id) => id.isNotEmpty)
                        .toSet()
                        .toList();
                    final totalTasks = uniqueTaskIds.length;

                    return FutureBuilder<Map<String, String>>(
                      future: _getTaskStatuses(uniqueTaskIds),
                      builder: (context, statusSnapshot) {
                        int completedTasks = 0;
                        if (statusSnapshot.hasData) {
                          final taskStatuses = statusSnapshot.data!;
                          for (final taskId in uniqueTaskIds) {
                            final workflowStatus = (taskStatuses[taskId] ?? '').toLowerCase().trim();
                            if (workflowStatus == 'work done' || workflowStatus == 'dev completed' || workflowStatus == 'completed') {
                              completedTasks++;
                            }
                          }
                        } else {
                          final tasksByTaskId = <String, List<Map<String, dynamic>>>{};
                          for (final session in taskSessions) {
                            final taskId = session['task_id'] as String? ?? '';
                            if (taskId.isNotEmpty) {
                              tasksByTaskId.putIfAbsent(taskId, () => []).add(session);
                            }
                          }
                          for (final taskSessions in tasksByTaskId.values) {
                            final allSessionsCompleted = taskSessions.every((session) => session['clock_out_time'] != null);
                            if (allSessionsCompleted && taskSessions.isNotEmpty) {
                              completedTasks++;
                            }
                          }
                        }

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildAnalyticsCard(
                                    context,
                                    'Total Hours',
                                    '${totalDailyHours.toStringAsFixed(1)}h',
                                    const Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAnalyticsCard(
                                    context,
                                    'Total Tasks',
                                    '$totalTasks',
                                    const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAnalyticsCard(
                                    context,
                                    'Completed',
                                    '$completedTasks',
                                    const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(BuildContext context, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.lexend(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceGraphsCard(BuildContext context, AttendanceViewModel attendanceViewModel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.show_chart, color: Color(0xFF10B981), size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Attendance Trends',
                      style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildWeeklyTrendChart(context),
                const SizedBox(height: 20),
                _buildDailyHoursChart(context, attendanceViewModel),
                const SizedBox(height: 20),
                FutureBuilder<Map<String, dynamic>?>(
                  future: attendanceViewModel.getDailyWorkSummary(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || snapshot.data == null) {
                      return const SizedBox.shrink();
                    }
                    final summary = snapshot.data!;
                    final taskSessions = summary['tasks_for_the_day'] ?? [];
                    if (taskSessions.isEmpty) return const SizedBox.shrink();
                    return _buildTaskCompletionChart(context, taskSessions);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyTrendChart(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _weeklyAttendanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final weeklyData = snapshot.data ?? [];
        if (weeklyData.isEmpty) {
          return Container(
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.01),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Text(
              'No data for this week',
              style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 13),
            ),
          );
        }

        return Container(
          height: 180,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly Hours History',
                style: GoogleFonts.lexend(color: const Color(0xFF3B82F6), fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 12,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF0F172A),
                        tooltipPadding: const EdgeInsets.all(8),
                        tooltipMargin: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toStringAsFixed(1)}h',
                            GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
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
                            final index = value.toInt();
                            if (index >= 0 && index < weeklyData.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  weeklyData[index]['day'],
                                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w500),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 24,
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: List.generate(weeklyData.length, (index) {
                      final dayData = weeklyData[index];
                      final hours = (dayData['hours'] as num?)?.toDouble() ?? 0.0;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: hours,
                            color: const Color(0xFF3B82F6),
                            width: 10,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyHoursChart(BuildContext context, AttendanceViewModel attendanceViewModel) {
    return FutureBuilder<List<EmployeeAttendance>>(
      future: attendanceViewModel.getTodayAttendanceRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final attendanceRecords = snapshot.data ?? [];

        final hourDistribution = List.generate(24, (hour) {
          double fractionWorkedInThisHour = 0.0;
          final hourStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, hour, 0, 0);
          final hourEnd = hourStart.add(const Duration(hours: 1));

          for (var record in attendanceRecords) {
            if (!record.isClockedIn) continue;
            final workDate = record.workDate;
            final clockOnString = record.clockOnTime;

            try {
              final clockInTime = DateTime.parse('$workDate $clockOnString');
              final clockOutTime = record.isClockedOut
                  ? DateTime.parse('$workDate ${record.clockOffTime}')
                  : DateTime.now();

              if (clockInTime.isBefore(hourEnd) && clockOutTime.isAfter(hourStart)) {
                final overlapStart = clockInTime.isAfter(hourStart) ? clockInTime : hourStart;
                final overlapEnd = clockOutTime.isBefore(hourEnd) ? clockOutTime : hourEnd;
                final overlapDuration = overlapEnd.difference(overlapStart);
                if (overlapDuration.inSeconds > 0) {
                  fractionWorkedInThisHour += overlapDuration.inSeconds / 3600.0;
                }
              }
            } catch (e) {
              // Parse error
            }
          }

          if (fractionWorkedInThisHour > 1.0) fractionWorkedInThisHour = 1.0;
          return {'hour': hour, 'sessions': fractionWorkedInThisHour};
        });

        return Container(
          height: 180,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Hours History',
                style: GoogleFonts.lexend(color: const Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 1.0,
                    minY: 0,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => const Color(0xFF0F172A),
                        tooltipPadding: const EdgeInsets.all(8),
                        tooltipMargin: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          if (rod.toY == 0) return null;
                          final hourStr = '${group.x.toString().padLeft(2, "0")}:00';
                          final minutes = (rod.toY * 60).round();
                          final timeStr = minutes >= 60 ? '1h' : '${minutes}m';
                          return BarTooltipItem(
                            '$hourStr\nWorked: $timeStr',
                            GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
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
                                  '${hour.toString().padLeft(2, "0")}:00',
                                  style: GoogleFonts.inter(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w500),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 24,
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: hourDistribution.map((data) {
                      return BarChartGroupData(
                        x: data['hour'] as int,
                        barRods: [
                          BarChartRodData(
                            toY: (data['sessions'] as num).toDouble(),
                            color: const Color(0xFF10B981),
                            width: 6,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
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

  Widget _buildTaskCompletionChart(BuildContext context, List<dynamic> taskSessions) {
    final uniqueTaskIds = taskSessions
        .map((session) => session['task_id'] as String?)
        .whereType<String>()
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();
    final totalTasks = uniqueTaskIds.length;

    final tasksByTaskId = <String, List<Map<String, dynamic>>>{};
    for (final session in taskSessions) {
      final taskId = session['task_id'] as String? ?? '';
      if (taskId.isNotEmpty) {
        tasksByTaskId.putIfAbsent(taskId, () => []).add(session);
      }
    }

    int completedTasks = 0;
    int activeTasks = 0;

    for (final taskSessions in tasksByTaskId.values) {
      final allSessionsCompleted = taskSessions.every((session) => session['clock_out_time'] != null);
      final hasActiveSession = taskSessions.any((session) => session['clock_out_time'] == null);

      if (allSessionsCompleted && taskSessions.isNotEmpty) {
        completedTasks++;
      } else if (hasActiveSession) {
        activeTasks++;
      }
    }

    if (totalTasks == 0) return const SizedBox.shrink();

    final completedPercentage = totalTasks > 0 ? completedTasks / totalTasks : 0.0;
    final activePercentage = totalTasks > 0 ? activeTasks / totalTasks : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Completion History',
            style: GoogleFonts.lexend(color: const Color(0xFFF59E0B), fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                height: 100,
                width: 100,
                child: CustomPaint(
                  size: const Size(100, 100),
                  painter: PieChartPainter(
                    completedPercentage: completedPercentage,
                    activePercentage: activePercentage,
                    primaryColor: const Color(0xFF3B82F6),
                    onPrimaryColor: const Color(0xFF070B14),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('Completed Tasks', completedTasks, const Color(0xFF10B981)),
                    const SizedBox(height: 6),
                    _buildLegendItem('Active Tasks', activeTasks, const Color(0xFF3B82F6)),
                    const SizedBox(height: 6),
                    _buildLegendItem('Total Tasks', totalTasks, Colors.white.withOpacity(0.4)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $value',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }
}

// --- WFH Form Widget ---
class _RequestWFHForm extends StatefulWidget {
  final WorkFromHomeViewModel viewModel;
  const _RequestWFHForm({required this.viewModel});

  @override
  State<_RequestWFHForm> createState() => _RequestWFHFormState();
}

class _RequestWFHFormState extends State<_RequestWFHForm> {
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

  String _formatDateString(DateTime? dt) {
    if (dt == null) return 'mm/dd/yyyy';
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) return;

    setState(() => _isSubmitting = true);
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (!authViewModel.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final employeeRecord = await authViewModel.getCurrentEmployeeDetails();
      if (employeeRecord == null || employeeRecord['employee_id'] == null) {
        throw Exception('Employee record not found. Please contact HR.');
      }
      final String employeeId = employeeRecord['employee_id'] as String;
      final String employeeName = employeeRecord['employee_name'] ?? 'Unknown Employee';
      final String? employeeRole = employeeRecord['employee_role'];

      final success = await widget.viewModel.createWorkFromHomeRequest(
        employeeId: employeeId,
        employeeName: employeeName,
        employeeRole: employeeRole,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Work from home request submitted successfully!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            width: 250,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        );
        _reasonController.clear();
        setState(() {
          _startDate = null;
          _endDate = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          width: 250,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.home_work_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request WFH',
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Submit a work from home request',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildDateField(
            label: 'Start Date',
            value: _startDate,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _startDate = date);
              }
            },
          ),
          const SizedBox(height: 16),

          _buildDateField(
            label: 'End Date (for multi-day)',
            value: _endDate,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _endDate ?? (_startDate ?? DateTime.now()),
                firstDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _endDate = date);
              }
            },
          ),
          const SizedBox(height: 16),

          Text(
            'Reason',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _reasonController,
            maxLines: 4,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter reason for WFH...',
              hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.2), fontSize: 13),
              filled: true,
              fillColor: Colors.white.withOpacity(0.01),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.4)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit WFH Request',
                style: GoogleFonts.lexend(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF3B82F6).withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.01),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateString(value),
                  style: GoogleFonts.inter(
                    color: value == null ? Colors.white.withOpacity(0.2) : Colors.white,
                    fontSize: 13,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white.withOpacity(0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- Leave Form Widget ---
class _RequestLeaveForm extends StatefulWidget {
  final LeaveService leaveService;
  final VoidCallback onLeaveSubmitted;
  const _RequestLeaveForm({required this.leaveService, required this.onLeaveSubmitted});

  @override
  State<_RequestLeaveForm> createState() => _RequestLeaveFormState();
}

class _RequestLeaveFormState extends State<_RequestLeaveForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String _selectedType = 'Annual Leave';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _formatDateString(DateTime? dt) {
    if (dt == null) return 'mm/dd/yyyy';
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}';
  }

  int get _calculatedDurationDays {
    if (_startDate == null || _endDate == null) return 0;
    final diff = _endDate!.difference(_startDate!).inDays;
    if (diff < 0) return 0;
    return diff + 1;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select both Start and End dates',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          width: 250,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'End Date must be after Start Date',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          width: 250,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (!authViewModel.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final employeeRecord = await authViewModel.getCurrentEmployeeDetails();
      if (employeeRecord == null || employeeRecord['employee_id'] == null) {
        throw Exception('Employee record not found. Please contact HR.');
      }
      final String employeeId = employeeRecord['employee_id'] as String;

      final success = await widget.leaveService.submitLeaveRequest(
        employeeId: employeeId,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
        leaveType: _selectedType,
        isPaidLeave: true,
        isHalfDay: false,
        halfDayType: null,
        selectedDates: null,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Leave request submitted successfully!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            width: 250,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        );
        _reasonController.clear();
        setState(() {
          _startDate = null;
          _endDate = null;
        });
        widget.onLeaveSubmitted();
      } else {
        throw Exception('Failed to submit leave request');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          width: 250,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = _calculatedDurationDays;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request Leave',
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Submit a new leave request',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.more_vert_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildDropdownField(
            label: 'Leave Type',
            value: _selectedType,
            items: ['Annual Leave', 'Sick Leave', 'Maternity Leave', 'Casual Leave'],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedType = val);
              }
            },
          ),
          const SizedBox(height: 16),

          _buildDateField(
            label: 'Start Date',
            value: _startDate,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() {
                  _startDate = date;
                  if (_endDate != null && _endDate!.isBefore(date)) {
                    _endDate = null;
                  }
                });
              }
            },
          ),
          const SizedBox(height: 16),

          _buildDateField(
            label: 'End Date',
            value: _endDate,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _endDate ?? _startDate ?? DateTime.now(),
                firstDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _endDate = date);
              }
            },
          ),
          const SizedBox(height: 16),

          if (duration > 0) ...[
            _buildDisplayField(
              label: 'Duration',
              value: '$duration day${duration > 1 ? "s" : ""}',
            ),
            const SizedBox(height: 16),
          ],

          Text(
            'Reason',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter reason for leave...',
              hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.2), fontSize: 13),
              filled: true,
              fillColor: Colors.white.withOpacity(0.01),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.4)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFF3B82F6).withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSubmitting) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _isSubmitting ? 'Submitting...' : 'Submit Request',
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF0F172A),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(0.4)),
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.01),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateString(value),
                  style: GoogleFonts.inter(
                    color: value == null ? Colors.white.withOpacity(0.2) : Colors.white,
                    fontSize: 13,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white.withOpacity(0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisplayField({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// --- Permission Form Widget ---
class _RequestPermissionForm extends StatefulWidget {
  final PermissionViewModel viewModel;
  final VoidCallback onPermissionSubmitted;
  const _RequestPermissionForm({required this.viewModel, required this.onPermissionSubmitted});

  @override
  State<_RequestPermissionForm> createState() => _RequestPermissionFormState();
}

class _RequestPermissionFormState extends State<_RequestPermissionForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String _selectedType = 'Early Leave';
  DateTime? _selectedDate;
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _formatDateString(DateTime? dt) {
    if (dt == null) return 'mm/dd/yyyy';
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatTimeString(TimeOfDay? time) {
    if (time == null) return '--:-- --';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  String get _calculatedDurationText {
    if (_fromTime == null || _toTime == null) return '0 hours';
    final fromMin = _fromTime!.hour * 60 + _fromTime!.minute;
    final toMin = _toTime!.hour * 60 + _toTime!.minute;
    final diff = toMin - fromMin;
    if (diff <= 0) return '0 hours';
    final hours = diff ~/ 60;
    final mins = diff % 60;
    if (hours > 0 && mins > 0) {
      return '$hours hr $mins mins';
    } else if (hours > 0) {
      return '$hours hour${hours > 1 ? "s" : ""}';
    } else {
      return '$mins mins';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _fromTime == null || _toTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill in all date and time fields',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          width: 250,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      );
      return;
    }

    final fromMin = _fromTime!.hour * 60 + _fromTime!.minute;
    final toMin = _toTime!.hour * 60 + _toTime!.minute;
    if (fromMin >= toMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'From Time must be before To Time',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          width: 250,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (!authViewModel.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      final employeeRecord = await authViewModel.getCurrentEmployeeDetails();
      if (employeeRecord == null || employeeRecord['employee_id'] == null) {
        throw Exception('Employee record not found. Please contact HR.');
      }
      final String employeeId = employeeRecord['employee_id'] as String;
      final String employeeName = employeeRecord['employee_name'] ?? 'Unknown Employee';

      final fromDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _fromTime!.hour,
        _fromTime!.minute,
      );

      final toDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _toTime!.hour,
        _toTime!.minute,
      );

      final String remarks = _reasonController.text.trim();
      final String fullRemarks = '[$_selectedType] $remarks';

      final success = await widget.viewModel.createPermissionRequest(
        employeeId: employeeId,
        employeeName: employeeName,
        permissionDate: _selectedDate!,
        permissionFromTime: fromDateTime,
        permissionToTime: toDateTime,
        permissionRemarks: fullRemarks.trim().isEmpty ? null : fullRemarks.trim(),
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Permission request submitted successfully!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            width: 250,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        );
        _reasonController.clear();
        setState(() {
          _selectedDate = null;
          _fromTime = null;
          _toTime = null;
        });
        widget.onPermissionSubmitted();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          width: 250,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Permission',
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Submit a permission request',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.more_vert_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildDropdownField(
            label: 'Permission Type',
            value: _selectedType,
            items: ['Early Leave', 'Late Arrival', 'Personal Errand', 'Medical Appointment', 'Mid-day Break'],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedType = val);
              }
            },
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: 'Date',
                  value: _selectedDate,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDisplayField(
                  label: 'Duration',
                  value: _calculatedDurationText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTimeField(
                  label: 'From Time',
                  value: _fromTime,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _fromTime ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (time != null) {
                      setState(() => _fromTime = time);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimeField(
                  label: 'To Time',
                  value: _toTime,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _toTime ?? const TimeOfDay(hour: 17, minute: 0),
                    );
                    if (time != null) {
                      setState(() => _toTime = time);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Reason',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Briefly describe the reason...',
              hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.2), fontSize: 13),
              filled: true,
              fillColor: Colors.white.withOpacity(0.01),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.4)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFF3B82F6).withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSubmitting) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _isSubmitting ? 'Submitting...' : 'Submit Request',
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF0F172A),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(0.4)),
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.01),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateString(value),
                  style: GoogleFonts.inter(
                    color: value == null ? Colors.white.withOpacity(0.2) : Colors.white,
                    fontSize: 13,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white.withOpacity(0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.01),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTimeString(value),
                  style: GoogleFonts.inter(
                    color: value == null ? Colors.white.withOpacity(0.2) : Colors.white,
                    fontSize: 13,
                  ),
                ),
                Icon(
                  Icons.access_time_rounded,
                  color: Colors.white.withOpacity(0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisplayField({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// --- PieChartPainter ---
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
    const shadowOffset = Offset(0, 4);

    if (completedPercentage > 0) {
      final shadowPaint = Paint()
        ..color = AppTheme.successGreen.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      final shadowRect = Rect.fromCircle(center: center + shadowOffset, radius: radius);
      canvas.drawArc(shadowRect, 0, 2 * pi * completedPercentage, true, shadowPaint);
    }

    if (activePercentage > 0) {
      final shadowPaint = Paint()
        ..color = primaryColor.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      final shadowRect = Rect.fromCircle(center: center + shadowOffset, radius: radius);
      canvas.drawArc(shadowRect, 2 * pi * completedPercentage, 2 * pi * activePercentage, true, shadowPaint);
    }

    if (completedPercentage > 0) {
      final completedPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.successGreen.withOpacity(0.8),
            AppTheme.successGreen,
          ],
          center: Alignment.topLeft,
          radius: 1.5,
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;
      final completedRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(completedRect, 0, 2 * pi * completedPercentage, true, completedPaint);
    }

    if (activePercentage > 0) {
      final activePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            primaryColor.withOpacity(0.8),
            primaryColor,
          ],
          center: Alignment.topLeft,
          radius: 1.5,
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;
      final activeRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(activeRect, 2 * pi * completedPercentage, 2 * pi * activePercentage, true, activePaint);
    }

    final centerPaint = Paint()
      ..color = onPrimaryColor
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          onPrimaryColor,
          onPrimaryColor.withOpacity(0.9),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.6));

    canvas.drawCircle(center, radius * 0.6, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
