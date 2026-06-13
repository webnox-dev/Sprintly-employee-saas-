import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import 'package:webnox_taskops/view_model/notification_view_model.dart';


class RecreatedHeader extends StatefulWidget {
  final String title;
  final String breadcrumb;
  final ValueChanged<String>? onSearchChanged;
  final ValueNotifier<String>? searchQueryNotifier;

  const RecreatedHeader({
    super.key,
    this.title = 'Rathz Employee',
    this.breadcrumb = 'Workspace / Dashboard',
    this.onSearchChanged,
    this.searchQueryNotifier,
  });

  @override
  State<RecreatedHeader> createState() => _RecreatedHeaderState();
}

class _RecreatedHeaderState extends State<RecreatedHeader> {
  bool _isSearchFocused = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.searchQueryNotifier != null) {
      _searchController.text = widget.searchQueryNotifier!.value;
      widget.searchQueryNotifier!.addListener(_onQueryNotifierChanged);
    }
  }

  void _onQueryNotifierChanged() {
    if (mounted && _searchController.text != widget.searchQueryNotifier!.value) {
      _searchController.text = widget.searchQueryNotifier!.value;
    }
  }

  @override
  void didUpdateWidget(covariant RecreatedHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQueryNotifier != widget.searchQueryNotifier) {
      oldWidget.searchQueryNotifier?.removeListener(_onQueryNotifierChanged);
      if (widget.searchQueryNotifier != null) {
        _searchController.text = widget.searchQueryNotifier!.value;
        widget.searchQueryNotifier!.addListener(_onQueryNotifierChanged);
      }
    }
  }

  @override
  void dispose() {
    widget.searchQueryNotifier?.removeListener(_onQueryNotifierChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF070B14).withOpacity(0.2),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 1.2,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Side - Title and Breadcrumbs
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.lexend(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.breadcrumb,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          // Center - Search Bar
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Focus(
                  onFocusChange: (hasFocus) {
                    setState(() {
                      _isSearchFocused = hasFocus;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isSearchFocused
                            ? const Color(0xFF3B82F6).withOpacity(0.6)
                            : Colors.white.withOpacity(0.08),
                        width: 1.2,
                      ),
                      boxShadow: _isSearchFocused
                          ? [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withOpacity(0.15),
                                blurRadius: 12,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: widget.onSearchChanged,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search tasks, reports...',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: _isSearchFocused
                              ? const Color(0xFF3B82F6)
                              : Colors.white.withOpacity(0.3),
                          size: 18,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Right Side - Notifications, Theme Toggle & User Info
          Row(
            children: [


              // Notification Bell Widget
              Consumer<NotificationViewModel>(
                builder: (context, notificationVM, child) {
                  final hasUnread = notificationVM.unreadCount > 0;
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            height: 10,
                            width: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF070B14),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withOpacity(0.6),
                                  blurRadius: 4,
                                )
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 16),
              
              // Divider
              Container(
                height: 32,
                width: 1,
                color: Colors.white.withOpacity(0.08),
              ),
              const SizedBox(width: 16),
              
              // User profile info (quick view)
              Consumer<AuthViewModel>(
                builder: (context, authVM, child) {
                  final name = authVM.currentUserProfile?.name ?? 'Employee';
                  final avatarUrl = authVM.userAvatar;
                  final initials = name.isNotEmpty
                      ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                      : 'EE';

                  return Row(
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                            width: 1,
                          ),
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
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
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
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
