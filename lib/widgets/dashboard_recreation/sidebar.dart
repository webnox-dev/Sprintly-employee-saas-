import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';

class RecreatedSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final VoidCallback? onLogout;

  const RecreatedSidebar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    this.onLogout,
  });

  @override
  State<RecreatedSidebar> createState() => _RecreatedSidebarState();
}

class _RecreatedSidebarState extends State<RecreatedSidebar> {
  int? _hoveredIndex;

  final List<Map<String, dynamic>> _menuItems = [
    {'title': 'Dashboard', 'icon': Icons.space_dashboard_rounded},
    {'title': 'Report', 'icon': Icons.folder_rounded},
    {'title': 'Sync Board', 'icon': Icons.chat_bubble_rounded},
    {'title': 'Attendance', 'icon': Icons.date_range_rounded},
    {'title': 'Calendar', 'icon': Icons.calendar_month_rounded},
    {'title': 'Profile', 'icon': Icons.person_rounded},
    {'title': 'Kanban Board', 'icon': Icons.view_kanban_rounded},
    {'title': 'Projects', 'icon': Icons.workspaces_rounded},
    {'title': 'Settings', 'icon': Icons.settings_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(left: 16, top: 16, bottom: 16),
      constraints: const BoxConstraints(maxHeight: 1080),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.0,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Logo Section
                  Container(
                    height: 80,
                    padding: const EdgeInsets.only(left: 28, right: 24),
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      'assets/logo/rathz_joined_logo.png',
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Divider
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.white.withOpacity(0.06),
                  ),

                  const SizedBox(height: 16),

                  // Navigation Menu List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                          left: 12, right: 12, top: 12, bottom: 12),
                      itemCount: _menuItems.length,
                      itemBuilder: (context, index) {
                        final item = _menuItems[index];
                        final isSelected = widget.selectedIndex == index;
                        final isHovered = _hoveredIndex == index;

                        return MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = index),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: GestureDetector(
                            onTap: () => widget.onIndexChanged(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: isSelected
                                    ? const Color(0xFF3B82F6)
                                    : (isHovered
                                        ? Colors.white.withOpacity(0.04)
                                        : Colors.transparent),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF3B82F6)
                                              .withOpacity(0.4),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.white.withOpacity(0.15),
                                        width: 1,
                                      )
                                    : Border.all(
                                        color: Colors.transparent,
                                        width: 1,
                                      ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item['icon'] as IconData,
                                    color: isSelected
                                        ? Colors.white
                                        : (isHovered
                                            ? Colors.white.withOpacity(0.9)
                                            : Colors.white.withOpacity(0.4)),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    item['title'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : (isHovered
                                              ? Colors.white.withOpacity(0.9)
                                              : Colors.white.withOpacity(0.5)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // User Profile Card at Bottom
                  Consumer<AuthViewModel>(
                    builder: (context, authVM, child) {
                      final name = authVM.currentUserProfile?.name ?? 'Employee';
                      final designation = authVM.currentUserProfile?.designation ?? 'Team Member';
                      final avatarUrl = authVM.userAvatar;
                      final initials = name.isNotEmpty
                          ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                          : 'EE';

                      return Container(
                        padding: const EdgeInsets.only(
                            left: 24, right: 16, top: 20, bottom: 20),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.08),
                              width: 1.2,
                            ),
                          ),
                          color: Colors.white.withOpacity(0.01),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  height: 40,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF3B82F6).withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                                        blurRadius: 6,
                                      )
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: avatarUrl != null && avatarUrl.isNotEmpty
                                        ? Image.network(
                                            avatarUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: const Color(0xFF1E293B),
                                              child: Center(
                                                child: Text(
                                                  initials,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: const Color(0xFF1E293B),
                                            child: Center(
                                              child: Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    height: 10,
                                    width: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF070B14),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    designation,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white.withOpacity(0.4),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: widget.onLogout,
                              icon: Icon(
                                Icons.logout_rounded,
                                color: Colors.white.withOpacity(0.4),
                                size: 18,
                              ),
                              tooltip: 'Sign Out',
                            ),
                          ],
                        ),
                      );
                    },
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
