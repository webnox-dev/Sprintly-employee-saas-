import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';

import '../../widgets/dashboard_recreation/sidebar.dart';
import '../../widgets/dashboard_recreation/header.dart';
import '../../widgets/dashboard_recreation/stats_card.dart';
import '../../widgets/dashboard_recreation/attendance_card.dart';
import '../../widgets/dashboard_recreation/task_board.dart';
import '../leave_tracking/recreated_attendance_screen.dart';
import '../team_sync/recreated_team_sync_screen.dart';
import '../task_request/task_card_request_screen.dart';

class RecreatedDashboardScreen extends StatefulWidget {
  const RecreatedDashboardScreen({super.key});

  @override
  State<RecreatedDashboardScreen> createState() => _RecreatedDashboardScreenState();
}

class _RecreatedDashboardScreenState extends State<RecreatedDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // 1. Ambient Background Glows & Gradients
          _buildBackgroundGlows(context),

          // 2. Main Layout (Sidebar + Main Content Area)
          Row(
            children: [
              // Left Sidebar - Fixed on desktop (width 250px)
              Align(
                alignment: Alignment.topCenter,
                child: RecreatedSidebar(
                  selectedIndex: _selectedIndex,
                  onIndexChanged: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  onLogout: () {
                    Get.offAllNamed('/login');
                  },
                ),
              ),

              // Right Main Content Column
              Expanded(
                child: Column(
                  children: [
                    // Top Header
                    RecreatedHeader(
                      onSearchChanged: (val) {
                        print('Searching: $val');
                      },
                    ),

                    // Main Content Area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: _selectedIndex == 3
                            ? const RecreatedAttendanceScreen()
                            : _selectedIndex == 2
                                ? const RecreatedTeamSyncScreen()
                                : SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Page Header Info
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Performance Overview',
                                                  style: GoogleFonts.lexend(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Real-time stats and metrics tracking',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: Colors.white.withOpacity(0.4),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Grid of Stats Cards & Attendance Row
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final isWide = constraints.maxWidth > 900;
                                            return Column(
                                              children: [
                                                if (isWide)
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      // Three Stats Cards in Row
                                                      Expanded(
                                                        flex: 3,
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: RecreatedStatsCard(
                                                                title: 'TOTAL TASKS',
                                                                value: '128',
                                                                badgeText: '+12%',
                                                                isGrowth: true,
                                                                imagePath: 'assets/images/total_task.png',
                                                                backSubtitle: 'Overall tasks allocated this month',
                                                                icon: Icons.format_list_bulleted_rounded,
                                                                accentColor: const Color(0xFF3B82F6),
                                                                subtitle: 'Across 4 active projects',
                                                              ),
                                                            ),
                                                            const SizedBox(width: 12),
                                                            Expanded(
                                                              child: RecreatedStatsCard(
                                                                title: 'IN PROGRESS',
                                                                value: '42',
                                                                badgeText: 'Active now',
                                                                isGrowth: false,
                                                                imagePath: 'assets/images/inprogress.png',
                                                                backSubtitle: 'Tasks currently actively worked on',
                                                                icon: Icons.directions_run_rounded,
                                                                accentColor: const Color(0xFFF59E0B),
                                                                subtitle: '3 items near deadline',
                                                              ),
                                                            ),
                                                            const SizedBox(width: 12),
                                                            Expanded(
                                                              child: RecreatedStatsCard(
                                                                title: 'COMPLETED',
                                                                value: '86',
                                                                badgeText: '94% rate',
                                                                isGrowth: true,
                                                                imagePath: 'assets/images/completed.png',
                                                                backSubtitle: 'Finished tasks with high quality score',
                                                                icon: Icons.check_rounded,
                                                                accentColor: const Color(0xFF10B981),
                                                                subtitle: 'Target reached this week',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      // Attendance Column (Punches + Punch In Action)
                                                      const Expanded(
                                                        flex: 2,
                                                        child: RecreatedAttendanceCard(),
                                                      ),
                                                    ],
                                                  )
                                                else
                                                  Column(
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: RecreatedStatsCard(
                                                              title: 'TOTAL TASKS',
                                                              value: '128',
                                                              badgeText: '+12%',
                                                              isGrowth: true,
                                                              imagePath: 'assets/images/total_task.png',
                                                              backSubtitle: 'Overall tasks allocated this month',
                                                              icon: Icons.format_list_bulleted_rounded,
                                                              accentColor: const Color(0xFF3B82F6),
                                                              subtitle: 'Across 4 active projects',
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            child: RecreatedStatsCard(
                                                              title: 'IN PROGRESS',
                                                              value: '42',
                                                              badgeText: 'Active now',
                                                              isGrowth: false,
                                                              imagePath: 'assets/images/inprogress.png',
                                                              backSubtitle: 'Tasks currently actively worked on',
                                                              icon: Icons.directions_run_rounded,
                                                              accentColor: const Color(0xFFF59E0B),
                                                              subtitle: '3 items near deadline',
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          Expanded(
                                                            child: RecreatedStatsCard(
                                                              title: 'COMPLETED',
                                                              value: '86',
                                                              badgeText: '94% rate',
                                                              isGrowth: true,
                                                              imagePath: 'assets/images/completed.png',
                                                              backSubtitle: 'Finished tasks with high quality score',
                                                              icon: Icons.check_rounded,
                                                              accentColor: const Color(0xFF10B981),
                                                              subtitle: 'Target reached this week',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 12),
                                                      const RecreatedAttendanceCard(),
                                                    ],
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 16),

                                        // Task Board Section
                                        RecreatedTaskBoard(
                                          onRefresh: () {
                                            print('Refreshed Task Board');
                                          },
                                          onAddTask: () {
                                            final isDesktop = MediaQuery.of(context).size.width > 900;
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
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
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

  Widget _buildBackgroundGlows(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF070B14),
            Color(0xFF0D1525),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Ambient Glow 1: Top Right (rgba(30, 58, 138, 0.1))
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
                    Color(0x1A1E3A8A), // rgba(30, 58, 138, 0.1)
                    Color(0x001E3A8A), // rgba(30, 58, 138, 0)
                  ],
                ),
              ),
            ),
          ),
          // Ambient Glow 2: Bottom Left (rgba(59, 130, 246, 0.15))
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
                    Color(0x263B82F6), // rgba(59, 130, 246, 0.15)
                    Color(0x003B82F6), // rgba(59, 130, 246, 0)
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
