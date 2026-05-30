import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import 'package:webnox_taskops/view_model/attendance_view_model.dart';
import 'package:webnox_taskops/view_model/work_from_home_view_model.dart';
import 'package:webnox_taskops/view_model/permission_view_model.dart';
import 'package:webnox_taskops/services/leave_service.dart';
import 'package:webnox_taskops/model/work_from_home_model.dart';

class RecreatedAttendanceScreen extends StatefulWidget {
  const RecreatedAttendanceScreen({super.key});

  @override
  State<RecreatedAttendanceScreen> createState() => _RecreatedAttendanceScreenState();
}

class _RecreatedAttendanceScreenState extends State<RecreatedAttendanceScreen> {
  int selectedTab = 1; // Default to WFH (tab 1) matching the screenshot!
  final LeaveService _leaveService = LeaveService();
  List<Map<String, dynamic>> _leaveHistory = [];
  bool _loadingLeaves = false;
  final DateTime _selectedMonth = DateTime(2025, 5); // Default matching May 2025

  // --- Leave Tab State ---
  // List of mock leave requests matching the mockup
  final List<Map<String, dynamic>> _mockLeaves = [
    {
      'id': 'l1',
      'type': 'Annual Leave',
      'employee': 'Pudhinraj HB',
      'status': 'Approved',
      
      'start_date': DateTime(2024, 1, 15),
      'end_date': DateTime(2024, 1, 22),
      'duration_days': 8,
    },
    {
      'id': 'l2',
      'type': 'Sick Leave',
      'employee': 'Pudhinraj HB',
      'status': 'Pending',
      'start_date': DateTime(2024, 2, 3),
      'end_date': DateTime(2024, 2, 5),
      'duration_days': 3,
    },
    {
      'id': 'l3',
      'type': 'Maternity Leave',
      'employee': 'Pudhinraj HB',
      'status': 'Rejected',
      'start_date': DateTime(2024, 3, 10),
      'end_date': DateTime(2024, 3, 17),
      'duration_days': 8,
    },
  ];

  // --- Permission Tab State ---
  // List of mock permission requests matching the mockup
  final List<Map<String, dynamic>> _mockPermissions = [
    {
      'id': 'p1',
      'type': 'Early Leave',
      'status': 'Pending',
      'reason': 'Medical appointment — 2h early',
      'date': DateTime(2025, 5, 28),
      'from_time': const TimeOfDay(hour: 15, minute: 0),
      'to_time': const TimeOfDay(hour: 17, minute: 0),
      'approver': 'Arjun Menon',
    },
    {
      'id': 'p2',
      'type': 'Late Arrival',
      'status': 'Approved',
      'reason': 'Traffic delay — 1h late',
      'date': DateTime(2025, 5, 25),
      'from_time': const TimeOfDay(hour: 9, minute: 0),
      'to_time': const TimeOfDay(hour: 10, minute: 0),
      'approver': 'Arjun Menon',
    },
    {
      'id': 'p3',
      'type': 'Personal Errand',
      'status': 'Rejected',
      'reason': 'Bank work — 2h break',
      'date': DateTime(2025, 5, 22),
      'from_time': const TimeOfDay(hour: 12, minute: 0),
      'to_time': const TimeOfDay(hour: 14, minute: 0),
      'approver': 'Arjun Menon',
    },
    {
      'id': 'p4',
      'type': 'Medical Appointment',
      'status': 'Approved',
      'reason': 'Routine checkup — half day',
      'date': DateTime(2025, 5, 20),
      'from_time': const TimeOfDay(hour: 13, minute: 0),
      'to_time': const TimeOfDay(hour: 17, minute: 0),
      'approver': 'Arjun Menon',
    },
    {
      'id': 'p5',
      'type': 'Mid-day Break',
      'status': 'Pending',
      'reason': 'Government office visit — 1.5h',
      'date': DateTime(2025, 5, 18),
      'from_time': const TimeOfDay(hour: 11, minute: 0),
      'to_time': const TimeOfDay(hour: 12, minute: 30),
      'approver': 'Arjun Menon',
    },
  ];

  // Filtering state
  String _filterStatus = 'All Status';
  String _filterType = 'All Types';
  String _filterPeriod = 'This Month';

  // Applied filter state
  String _appliedFilterStatus = 'All Status';
  String _appliedFilterType = 'All Types';
  String _appliedFilterPeriod = 'This Month';

  // Pagination state
  int _currentPermissionPage = 1;
  static const int _permissionItemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _fetchLeaveHistory();
  }

  Future<void> _fetchLeaveHistory() async {
    if (!mounted) return;
    setState(() => _loadingLeaves = true);
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.isAuthenticated) {
        final employeeDetails = await authViewModel.getCurrentEmployeeDetails();
        if (employeeDetails != null) {
          final employeeId = employeeDetails['employee_id'] ?? employeeDetails['employeeId'];
          if (employeeId != null) {
            final history = await _leaveService.getLeaveHistory(employeeId.toString());
            if (mounted) {
              setState(() {
                _leaveHistory = history;
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching leave history in RecreatedAttendanceScreen: $e');
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
            backgroundColor: const Color(0xFF070B14),
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
                      _buildStatsRow(context, attendanceViewModel, wfhViewModel),
                      const SizedBox(height: 24),

                      // 2. Center aligned tab bar
                      _buildTabBar(context),
                      const SizedBox(height: 24),

                      // 3. Tab Content
                      Expanded(
                        child: _buildTabContent(context, wfhViewModel, permissionViewModel, isWide),
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
  ) {
    int approvedLeaves = 0;
    for (final leave in _leaveHistory) {
      final isApproved = (leave['leave_status'] ?? 0) == 1;
      if (isApproved) approvedLeaves++;
    }

    final totalWFH = wfhViewModel.requests.length;
    final pendingWFH = wfhViewModel.requests.where((r) => r.isPending).length;
    final attendanceRate = '96.5%';

    final isWide = MediaQuery.of(context).size.width > 900;

    final cards = [
      _buildStatCard(
        title: 'TOTAL WFH REQUESTS',
        value: totalWFH.toString(),
        subtitle: 'This Year',
        icon: Icons.home_work_rounded,
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
        value: pendingWFH.toString(),
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
                  child: _buildRequestPermissionCard(context),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 6,
                  child: _buildPermissionHistoryCard(context),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildRequestPermissionCard(context),
                  const SizedBox(height: 24),
                  _buildPermissionHistoryCard(context),
                ],
              ),
            );
    } else {
      return Center(
        child: Text(
          'Tab $selectedTab Content Coming Soon',
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.4),
          ),
        ),
      );
    }
  }

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

  String _formatDateShort(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateYYYYMMDD(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // --- Leave Tab Widgets & Helpers ---
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
                onLeaveSubmitted: (newLeave) {
                  setState(() {
                    _mockLeaves.insert(0, newLeave);
                  });
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
                // Header with title and "+ New Request" action
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
                
                // History List
                if (_mockLeaves.isEmpty)
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
                      itemCount: _mockLeaves.length,
                      itemBuilder: (context, index) {
                        return _buildLeaveRequestItemCard(context, _mockLeaves[index]);
                      },
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _mockLeaves.length,
                    itemBuilder: (context, index) {
                      return _buildLeaveRequestItemCard(context, _mockLeaves[index]);
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
    final String type = req['type'] ?? 'Leave';
    final String employee = req['employee'] ?? 'Pudhinraj HB';
    final String status = req['status'] ?? 'Pending';
    final DateTime startDate = req['start_date'] as DateTime;
    final DateTime endDate = req['end_date'] as DateTime;
    final int durationDays = req['duration_days'] ?? 1;

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
          // Left side icon + text
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
          // Right side details + actions
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

  // --- Permission Tab Widgets & Helpers ---
  Widget _buildRequestPermissionCard(BuildContext context) {
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
                onPermissionSubmitted: (newPermission) {
                  setState(() {
                    _mockPermissions.insert(0, newPermission);
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionHistoryCard(BuildContext context) {
    // Filter requests client-side
    final filteredPermissions = _mockPermissions.where((req) {
      if (_appliedFilterStatus != 'All Status') {
        if (req['status'] != _appliedFilterStatus) return false;
      }
      if (_appliedFilterType != 'All Types') {
        if (req['type'] != _appliedFilterType) return false;
      }
      final DateTime reqDate = req['date'] as DateTime;
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
        ? <Map<String, dynamic>>[] 
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
                // 1. Filter Bar
                _buildFilterRow(context),
                const SizedBox(height: 24),

                // 2. Header
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

                // 3. List
                if (paginatedRequests.isEmpty)
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

                // 4. Pagination Footer
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

  Widget _buildPermissionItemCard(BuildContext context, Map<String, dynamic> req) {
    final String type = req['type'] ?? 'Permission';
    final String status = req['status'] ?? 'Pending';
    final String reason = req['reason'] ?? '';
    final DateTime date = req['date'] as DateTime;
    final TimeOfDay fromTime = req['from_time'] as TimeOfDay;
    final TimeOfDay toTime = req['to_time'] as TimeOfDay;

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
    final String timeRangeStr = '${_formatTimeOfDay12Hr(fromTime)} - ${_formatTimeOfDay12Hr(toTime)}';

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
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      type,
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.2), width: 0.5),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dateStr,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeRangeStr,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=100'),
              ),
              const SizedBox(width: 8),
              Text(
                'Arjun M.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Icon(
              Icons.visibility_outlined,
              color: Colors.white.withOpacity(0.3),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Icon(
              Icons.more_vert_rounded,
              color: Colors.white.withOpacity(0.3),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationRow(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildPaginationArrowButton(
          icon: Icons.keyboard_arrow_left_rounded,
          enabled: _currentPermissionPage > 1,
          onTap: () {
            if (_currentPermissionPage > 1) {
              setState(() => _currentPermissionPage--);
            }
          },
        ),
        const SizedBox(width: 8),
        for (int i = 1; i <= totalPages; i++) ...[
          _buildPaginationNumberButton(
            pageNumber: i,
            isActive: _currentPermissionPage == i,
            onTap: () {
              setState(() => _currentPermissionPage = i);
            },
          ),
          const SizedBox(width: 6),
        ],
        _buildPaginationArrowButton(
          icon: Icons.keyboard_arrow_right_rounded,
          enabled: _currentPermissionPage < totalPages,
          onTap: () {
            if (_currentPermissionPage < totalPages) {
              setState(() => _currentPermissionPage++);
            }
          },
        ),
      ],
    );
  }

  Widget _buildPaginationArrowButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(enabled ? 0.08 : 0.03)),
        ),
        child: Icon(
          icon,
          size: 14,
          color: Colors.white.withOpacity(enabled ? 0.8 : 0.2),
        ),
      ),
    );
  }

  Widget _buildPaginationNumberButton({
    required int pageNumber,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF3B82F6).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? const Color(0xFF3B82F6).withOpacity(0.4) : Colors.transparent),
        ),
        child: Text(
          pageNumber.toString(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  String _formatTimeOfDay12Hr(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  String _formatDateLong(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthStr = months[date.month - 1];
    return '$monthStr ${date.day}, ${date.year}';
  }
}

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

          // Start Date Input
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

          // End Date Input
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

          // Reason Input
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

          // Submit Button
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

class _RequestPermissionForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onPermissionSubmitted;
  const _RequestPermissionForm({required this.onPermissionSubmitted});

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

  void _submit() {
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

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      widget.onPermissionSubmitted({
        'id': 'p${DateTime.now().millisecondsSinceEpoch}',
        'type': _selectedType,
        'status': 'Pending',
        'reason': _reasonController.text.trim().isEmpty ? 'No reason provided' : _reasonController.text.trim(),
        'date': _selectedDate!,
        'from_time': _fromTime!,
        'to_time': _toTime!,
        'approver': 'Arjun Menon',
      });

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
        _isSubmitting = false;
      });
    });
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
          const SizedBox(height: 16),

          _buildApproverField(),
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
                _isSubmitting ? 'Submitting...' : 'Submit Request',
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

  Widget _buildApproverField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Approver',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.01),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=100'),
              ),
              const SizedBox(width: 10),
              Text(
                'Arjun Menon (Team Lead)',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestLeaveForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onLeaveSubmitted;
  const _RequestLeaveForm({required this.onLeaveSubmitted});

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

  void _submit() {
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

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      widget.onLeaveSubmitted({
        'id': 'l${DateTime.now().millisecondsSinceEpoch}',
        'type': _selectedType,
        'employee': 'Pudhinraj HB',
        'status': 'Pending',
        'start_date': _startDate!,
        'end_date': _endDate!,
        'duration_days': _calculatedDurationDays,
      });

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
        _isSubmitting = false;
      });
    });
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

          // Submit Request button is right-aligned
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
