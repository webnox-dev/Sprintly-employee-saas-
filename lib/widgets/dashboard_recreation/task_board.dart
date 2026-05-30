import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'empty_state.dart';

class RecreatedTaskBoard extends StatefulWidget {
  final VoidCallback onRefresh;
  final VoidCallback onAddTask;

  const RecreatedTaskBoard({
    super.key,
    required this.onRefresh,
    required this.onAddTask,
  });

  @override
  State<RecreatedTaskBoard> createState() => _RecreatedTaskBoardState();
}

class _RecreatedTaskBoardState extends State<RecreatedTaskBoard> {
  int _activeTab = 0;
  bool _isLoading = false;

  final List<String> _tabs = [
    'To Do',
    'In Progress',
    'Completed',
    'All Tasks',
    'Team Cards',
  ];

  void _handleTabChanged(int index) {
    setState(() {
      _isLoading = true;
      _activeTab = index;
    });

    // Simulate short network loading for futuristic dashboard effect
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Task Board Header containing tabs and Floating Add Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Tabs
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_tabs.length, (index) {
                            final isSelected = _activeTab == index;
                            return GestureDetector(
                              onTap: () => _handleTabChanged(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                  _tabs[index],
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? const Color(0xFF3B82F6)
                                        : Colors.white.withOpacity(0.4),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }),
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
                          onTap: widget.onAddTask,
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
                ),
              ),
              
              // Divider
              Container(
                height: 1,
                color: Colors.white.withOpacity(0.06),
              ),
              
              // Content Area (Empty state or loading spinner)
              Container(
                constraints: const BoxConstraints(minHeight: 280),
                padding: const EdgeInsets.symmetric(vertical: 40),
                alignment: Alignment.center,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF3B82F6),
                        ),
                      )
                    : RecreatedEmptyState(
                        onRefresh: () {
                          setState(() {
                            _isLoading = true;
                          });
                          Future.delayed(const Duration(milliseconds: 800), () {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                              widget.onRefresh();
                            }
                          });
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
