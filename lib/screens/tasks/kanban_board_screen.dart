import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/task_details_dialog.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../widgets/app_bar_search_filter.dart';
import '../dashboard/modern_dashboard_screen.dart';
import '../../widgets/congratulations_overlay.dart';
import 'package:webnox_taskops/model/task_model.dart';
import 'package:webnox_taskops/helpers/app_theme.dart';
import 'package:webnox_taskops/widgets/common_widgets.dart';
import 'package:webnox_taskops/view_model/task_view_model.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import 'package:webnox_taskops/view_model/kanban_view_model.dart';
import 'package:webnox_taskops/services/task_card_log_service.dart';
import 'package:webnox_taskops/services/local_storage_service.dart';
import 'package:webnox_taskops/utils/responsive_utils.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

// Task status enum for kanban columns
enum KanbanTaskStatus {
  todo,
  inProgress,
  devcompleted,
  inQc,
  workDone,
  redo,
}

class KanbanBoardScreen extends HookWidget {
  const KanbanBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get ViewModels
    final kanbanViewModel = Provider.of<KanbanViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final taskViewModel = Provider.of<TaskViewModel>(context, listen: false);
    final isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);

    // Track user role for QA-specific flow
    final userRole = useState<String?>(null);

    // Helper: load tasks based on role (QA uses smart fetch, others use backend)
    Future<void> _loadTasksForRole() async {
      final role = userRole.value?.toLowerCase().trim() ?? '';
      final isQA = role == 'qa analyst' || role.contains('quality control');
      if (isQA) {
        // QA Analysts need ALL dev-completed/in-qc/work-done/redo tasks
        await kanbanViewModel.loadTasks(authViewModel);
      } else {
        final employeeId = LocalStorageService().userId;
        await kanbanViewModel.loadTasksWithBackend(employeeId);
      }
    }

    // Fetch user role on mount and reload tasks with correct method
    useEffect(() {
      Future.microtask(() async {
        final role = await authViewModel.getUserRole();
        userRole.value = role;
        print('🔍 KanbanBoard: User role detected: $role');
        // After role is known, reload tasks with the correct method
        await _loadTasksForRole();
      });
      return null;
    }, []);

    // UI-specific state only (not managed by ViewModel)
    final searchController = useTextEditingController();
    final searchQuery = useState<String>(''); // For UI widgets
    final hasActiveFilters = useState<bool>(false); // For UI widgets
    final showSuggestions = useState<bool>(false);
    final searchFocusNode = useFocusNode();
    final searchBarKey = useMemoized(() => GlobalKey());
    final suggestionsOverlay = useRef<OverlayEntry?>(null);
    final isSearchVisible = useState<bool>(false);

    // Sync local state with ViewModel
    useEffect(() {
      hasActiveFilters.value = kanbanViewModel.hasActiveFilters;
      return null;
    }, [kanbanViewModel.hasActiveFilters]);

    // Auto-scroll state for drag operations (UI-specific)
    final verticalScrollController = useState<ScrollController?>(null);
    final horizontalScrollController = useState<ScrollController?>(null);
    final isDragging = useState<bool>(false);
    final dragPosition = useState<Offset?>(null);
    final autoScrollTimer = useState<Timer?>(null);

    // Initialize and load tasks on mount
    useEffect(() {
      // Initialize scroll controllers
      verticalScrollController.value = ScrollController();
      horizontalScrollController.value = ScrollController();

      // Load tasks immediately (non-QA fallback; QA tasks reload after role is fetched above)
      final employeeId = LocalStorageService().userId;
      Future.microtask(() => kanbanViewModel.loadTasksWithBackend(employeeId));

      return () {
        // Cleanup
        autoScrollTimer.value?.cancel();
        verticalScrollController.value?.dispose();
        horizontalScrollController.value?.dispose();
        verticalScrollController.value = null;
        horizontalScrollController.value = null;
      };
    }, []);

    // Refresh function for pull-to-refresh (role-aware)
    Future<void> refreshTasks() async {
      await _loadTasksForRole();
    }

    // Helper function to show/hide suggestions overlay
    OverlayEntry? _showSuggestionsOverlay(
      BuildContext context,
      GlobalKey searchBarKey,
      List<String> suggestions,
      TextEditingController searchController,
      ValueNotifier<String> searchQuery,
      ValueNotifier<bool> showSuggestions,
      FocusNode searchFocusNode,
      bool isSmallMobile,
    ) {
      final overlay = Overlay.of(context);
      final renderBox =
          searchBarKey.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox == null || suggestions.isEmpty) return null;

      final size = renderBox.size;
      final offset = renderBox.localToGlobal(Offset.zero);

      OverlayEntry? overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: offset.dy + size.height + 4,
          left: offset.dx,
          width: size.width,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: 200,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: ClampingScrollPhysics(),
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return InkWell(
                    onTap: () {
                      searchController.text = suggestion;
                      searchQuery.value = suggestion;
                      showSuggestions.value = false;
                      searchFocusNode.unfocus();
                      overlayEntry?.remove();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallMobile ? 20 : 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 18,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.6),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      overlay.insert(overlayEntry);
      return overlayEntry;
    }

    // Auto-scroll logic for drag operations
    void _startAutoScroll() {
      autoScrollTimer.value?.cancel();
      autoScrollTimer.value =
          Timer.periodic(const Duration(milliseconds: 8), (timer) {
        if (!isDragging.value || horizontalScrollController.value == null) {
          timer.cancel();
          return;
        }

        final position = dragPosition.value;
        if (position == null) return;

        final screenWidth = MediaQuery.of(context).size.width;
        final scrollController = horizontalScrollController.value!;
        final scrollOffset = scrollController.offset;
        final maxScroll = scrollController.position.maxScrollExtent;

        // Define edge zones for auto-scroll (15% of screen width from edges for more responsive feel)
        final edgeZone = screenWidth * 0.15;

        // Calculate dynamic scroll speed based on distance from edge
        double scrollSpeed;
        if (position.dx < edgeZone) {
          // Closer to left edge = faster scroll
          final distanceFromEdge = edgeZone - position.dx;
          scrollSpeed = (distanceFromEdge / edgeZone) * 25.0 +
              10.0; // 10-35 pixels per frame
        } else if (position.dx > screenWidth - edgeZone) {
          // Closer to right edge = faster scroll
          final distanceFromEdge = position.dx - (screenWidth - edgeZone);
          scrollSpeed = (distanceFromEdge / edgeZone) * 25.0 +
              10.0; // 10-35 pixels per frame
        } else {
          return; // Not in edge zone
        }

        if (position.dx < edgeZone && scrollOffset > 0) {
          // Scroll left
          final newOffset = (scrollOffset - scrollSpeed).clamp(0.0, maxScroll);
          scrollController
              .jumpTo(newOffset); // Use jumpTo for immediate response
        } else if (position.dx > screenWidth - edgeZone &&
            scrollOffset < maxScroll) {
          // Scroll right
          final newOffset = (scrollOffset + scrollSpeed).clamp(0.0, maxScroll);
          scrollController
              .jumpTo(newOffset); // Use jumpTo for immediate response
        }
      });
    }

    void _stopAutoScroll() {
      autoScrollTimer.value?.cancel();
      autoScrollTimer.value = null;
    }

    void _updateDragPosition(Offset position) {
      dragPosition.value = position;
    }

    void _onDragStarted() {
      isDragging.value = true;
      _startAutoScroll();
    }

    void _onDragEnd() {
      isDragging.value = false;
      dragPosition.value = null;
      _stopAutoScroll();
    }

    // Show filter dialog/sheet based on screen size
    void _showFilterDialog(
        BuildContext context,
        Map<String, List<String>> filterOptions,
        VoidCallback onClearFilters,
        VoidCallback onUpdateFilters) {
      
      final isDesktop = ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);
      
      if (isDesktop) {
        // Show Side Sheet for Desktop/Laptop
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Dismiss',
          barrierColor: Colors.black.withOpacity(0.5),
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) {
            return Align(
              alignment: Alignment.centerRight,
              child: TaskFilterSheet(
                filterOptions: filterOptions,
                kanbanViewModel: kanbanViewModel,
                onClearFilters: onClearFilters,
                onUpdateFilters: onUpdateFilters,
                isSideSheet: true,
              ),
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        );
      } else {
        // Show Bottom Sheet for Mobile/Tablet
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => TaskFilterSheet(
            filterOptions: filterOptions,
            kanbanViewModel: kanbanViewModel,
            onClearFilters: onClearFilters,
            onUpdateFilters: onUpdateFilters,
            isSideSheet: false,
          ),
        );
      }
    }

    // Build search and filter bar (matching home screen)
    Widget _buildSearchAndFilterBar(
        BuildContext context,
        bool isDesktop,
        bool isMobile,
        bool isSmallMobile,
        ObjectRef<OverlayEntry?> suggestionsOverlayRef,
        ValueNotifier<bool> isSearchVisible) {
      // Get suggestions based on current query
      final suggestions = kanbanViewModel.searchQuery.isNotEmpty
          ? kanbanViewModel.getSearchSuggestions(searchController.text)
          : <String>[];

      if (isSmallMobile) {
        return AnimatedCrossFade(
          crossFadeState: isSearchVisible.value
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          firstChild: Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => isSearchVisible.value = true,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.search,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ),
          secondChild: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      key: searchBarKey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).inputDecorationTheme.fillColor ??
                                Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.5) ??
                                Colors.white.withOpacity(0.5),
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              focusNode: searchFocusNode,
                              onChanged: (value) {
                                kanbanViewModel.setSearchQuery(value);
                                final newSuggestions = value.isNotEmpty
                                    ? kanbanViewModel
                                        .getSearchSuggestions(value)
                                    : <String>[];
                                final shouldShow = value.isNotEmpty &&
                                    newSuggestions.isNotEmpty;

                                // Manage overlay
                                suggestionsOverlayRef.value?.remove();
                                suggestionsOverlayRef.value = null;

                                if (shouldShow) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (searchBarKey.currentContext != null) {
                                      suggestionsOverlayRef.value =
                                          _showSuggestionsOverlay(
                                        context,
                                        searchBarKey,
                                        newSuggestions,
                                        searchController,
                                        searchQuery,
                                        showSuggestions,
                                        searchFocusNode,
                                        isSmallMobile,
                                      );
                                    }
                                  });
                                }

                                showSuggestions.value = shouldShow;
                              },
                              onTap: () {
                                final currentSuggestions =
                                    kanbanViewModel.searchQuery.isNotEmpty
                                        ? kanbanViewModel.getSearchSuggestions(
                                            searchController.text)
                                        : <String>[];
                                if (currentSuggestions.isNotEmpty) {
                                  showSuggestions.value = true;
                                  // Show overlay
                                  suggestionsOverlayRef.value?.remove();
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (searchBarKey.currentContext != null) {
                                      suggestionsOverlayRef.value =
                                          _showSuggestionsOverlay(
                                        context,
                                        searchBarKey,
                                        currentSuggestions,
                                        searchController,
                                        searchQuery,
                                        showSuggestions,
                                        searchFocusNode,
                                        isSmallMobile,
                                      );
                                    }
                                  });
                                }
                              },
                              onSubmitted: (_) {
                                showSuggestions.value = false;
                                suggestionsOverlayRef.value?.remove();
                                suggestionsOverlayRef.value = null;
                              },
                              style: TextStyle(
                                  color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color ??
                                      Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search tasks...',
                                hintStyle: TextStyle(
                                  color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.5) ??
                                      Colors.white.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      isSearchVisible.value = false;
                      searchFocusNode.unfocus();
                      suggestionsOverlayRef.value?.remove();
                      suggestionsOverlayRef.value = null;
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.close,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
              // Suggestions dropdown for small mobile
              if (showSuggestions.value && suggestions.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: 4),
                  constraints: BoxConstraints(
                    maxHeight: 200,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = suggestions[index];
                      return InkWell(
                        onTap: () {
                          searchController.text = suggestion;
                          searchQuery.value = suggestion;
                          showSuggestions.value = false;
                          searchFocusNode.unfocus();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                size: 18,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.6),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  suggestion,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  final filterOptions = kanbanViewModel.getFilterOptions();
                  _showFilterDialog(
                    context,
                    filterOptions,
                    () => kanbanViewModel.clearFilters(),
                    () {}, // Update callback
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).inputDecorationTheme.fillColor ??
                        Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          Icon(
                            Icons.filter_list,
                            color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.7) ??
                                Colors.white.withOpacity(0.7),
                            size: 22,
                          ),
                          if (kanbanViewModel.hasActiveFilters)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Filter Tasks${kanbanViewModel.hasActiveFilters ? ' (${kanbanViewModel.selectedPriorities.length + kanbanViewModel.selectedStatuses.length + kanbanViewModel.selectedProjects.length})' : ''}',
                        style: TextStyle(
                          color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.7) ??
                              Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        return AnimatedCrossFade(
          crossFadeState: isSearchVisible.value
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          firstChild: Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => isSearchVisible.value = true,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.search,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ),
          secondChild: Row(
            children: [
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      key: searchBarKey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).inputDecorationTheme.fillColor ??
                                Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.5) ??
                                Colors.white.withOpacity(0.5),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              focusNode: searchFocusNode,
                              onChanged: (value) {
                                kanbanViewModel.setSearchQuery(value);
                                final newSuggestions = value.isNotEmpty
                                    ? kanbanViewModel
                                        .getSearchSuggestions(value)
                                    : <String>[];
                                final shouldShow = value.isNotEmpty &&
                                    newSuggestions.isNotEmpty;

                                // Manage overlay
                                suggestionsOverlayRef.value?.remove();
                                suggestionsOverlayRef.value = null;

                                if (shouldShow) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (searchBarKey.currentContext != null) {
                                      suggestionsOverlayRef.value =
                                          _showSuggestionsOverlay(
                                        context,
                                        searchBarKey,
                                        newSuggestions,
                                        searchController,
                                        searchQuery,
                                        showSuggestions,
                                        searchFocusNode,
                                        isSmallMobile,
                                      );
                                    }
                                  });
                                }

                                showSuggestions.value = shouldShow;
                              },
                              onTap: () {
                                final currentSuggestions =
                                    kanbanViewModel.searchQuery.isNotEmpty
                                        ? kanbanViewModel.getSearchSuggestions(
                                            searchController.text)
                                        : <String>[];
                                if (currentSuggestions.isNotEmpty) {
                                  showSuggestions.value = true;
                                  // Show overlay
                                  suggestionsOverlayRef.value?.remove();
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (searchBarKey.currentContext != null) {
                                      suggestionsOverlayRef.value =
                                          _showSuggestionsOverlay(
                                        context,
                                        searchBarKey,
                                        currentSuggestions,
                                        searchController,
                                        searchQuery,
                                        showSuggestions,
                                        searchFocusNode,
                                        isSmallMobile,
                                      );
                                    }
                                  });
                                }
                              },
                              onSubmitted: (_) {
                                showSuggestions.value = false;
                                suggestionsOverlayRef.value?.remove();
                                suggestionsOverlayRef.value = null;
                              },
                              style: TextStyle(
                                  color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color ??
                                      Colors.white),
                              decoration: InputDecoration(
                                hintText:
                                    'Search tasks, assignees, or descriptions...',
                                hintStyle: TextStyle(
                                  color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.5) ??
                                      Colors.white.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  final filterOptions = kanbanViewModel.getFilterOptions();
                  _showFilterDialog(
                    context,
                    filterOptions,
                    () => kanbanViewModel.clearFilters(),
                    () {}, // Update callback
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).inputDecorationTheme.fillColor ??
                        Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.7) ??
                            Colors.white.withOpacity(0.7),
                        size: 20,
                      ),
                      if (kanbanViewModel.hasActiveFilters)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  isSearchVisible.value = false;
                  searchFocusNode.unfocus();
                  suggestionsOverlayRef.value?.remove();
                  suggestionsOverlayRef.value = null;
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.close,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    // Helper methods for date and time formatting
    String _formatDate(DateTime date) {
      return '${date.day}/${date.month}/${date.year}';
    }

    String _getDateRange(Task task) {
      if (task.assignedAt != null && task.devCompletedAt != null) {
        return '${_formatDate(task.assignedAt!)} - ${_formatDate(task.devCompletedAt!)}';
      } else if (task.assignedAt != null) {
        return 'Assigned: ${_formatDate(task.assignedAt!)}';
      } else if (task.devCompletedAt != null) {
        return 'Due: ${_formatDate(task.devCompletedAt!)}';
      } else {
        return 'N/A';
      }
    }

    String _getTaskDuration(Task task) {
      // Use task_duration field from the task
      if (task.taskDuration != null && task.taskDuration!.isNotEmpty) {
        return task.taskDuration!;
      }

      // Fallback: calculate duration from total dev hours if available
      if (task.totalDevHours != null && task.totalDevHours! > 0) {
        final hours = task.totalDevHours!;
        if (hours >= 24) {
          final days = hours ~/ 24;
          final remainingHours = hours % 24;
          return remainingHours > 0
              ? '$days days $remainingHours hours'
              : '$days days';
        } else {
          return '$hours hours';
        }
      }

      return 'N/A';
    }

    // Helper function to get status description
    String _getStatusDescription(KanbanTaskStatus status) {
      switch (status) {
        case KanbanTaskStatus.todo:
          return 'To Do';
        case KanbanTaskStatus.inProgress:
          return 'In Progress';
        case KanbanTaskStatus.devcompleted:
          return 'Dev Completed';
        case KanbanTaskStatus.inQc:
          return 'In QC';
        case KanbanTaskStatus.workDone:
          return 'Work Done';
        case KanbanTaskStatus.redo:
          return 'Redo';
      }
    }

    // Check if the current user is a QA Analyst
    bool _isQAAnalyst() {
      final role = userRole.value?.toLowerCase().trim() ?? '';
      return role == 'qa analyst' || role.contains('quality control');
    }

    // QA Approve Task dialog (drag to Work Done)
    Future<void> _showQAApproveDialog(Task task) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          final qaNotesController = TextEditingController();
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QA Approve Task',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Are you sure you want to approve "${task.taskName}"?',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: qaNotesController,
                  decoration: InputDecoration(
                    labelText: 'QA Notes (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final success = await taskViewModel.qaApproveTask(
                    taskId: task.taskId,
                    qaNotes: qaNotesController.text.trim(),
                    employeeId: authViewModel.localStorage.userId,
                  );
                  if (success) {
                    final logService = TaskCardLogService();
                    await logService.logTaskAction(
                      taskId: task.taskId,
                      actionName: 'QA Approved (Kanban)',
                      actionDescription:
                          'QA Analyst approved task "${task.taskName}" via Kanban board${qaNotesController.text.trim().isNotEmpty ? '. Notes: ${qaNotesController.text.trim()}' : ''}',
                    );
                    await _loadTasksForRole();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      'Task "${task.taskName}" approved! ✅')),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Failed to approve task. Please try again.'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text('Approve'),
              ),
            ],
          );
        },
      );
    }

    // QA Disapprove Task dialog (drag to Redo)
    Future<void> _showQADisapproveDialog(Task task) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          final qaNotesController = TextEditingController();
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.cancel, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QA Disapprove Task',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Are you sure you want to send "${task.taskName}" back for redo?',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: qaNotesController,
                  decoration: InputDecoration(
                    labelText: 'QA Notes (Required)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (qaNotesController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content:
                            Text('Please provide QA notes for disapproval.'),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  final success = await taskViewModel.qaDisapproveTask(
                    taskId: task.taskId,
                    qaNotes: qaNotesController.text.trim(),
                    employeeId: authViewModel.localStorage.userId,
                  );
                  if (success) {
                    final logService = TaskCardLogService();
                    await logService.logTaskAction(
                      taskId: task.taskId,
                      actionName: 'QA Disapproved (Kanban)',
                      actionDescription:
                          'QA Analyst disapproved task "${task.taskName}" via Kanban board. Notes: ${qaNotesController.text.trim()}',
                    );
                    await _loadTasksForRole();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.white),
                              SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      'Task "${task.taskName}" sent for redo 🔄')),
                            ],
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Failed to disapprove task. Please try again.'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Disapprove'),
              ),
            ],
          );
        },
      );
    }

    // QA Start Task (drag to In QC)
    Future<void> _qaStartTask(Task task) async {
      try {
        print('🔍 QA Analyst starting to test task: ${task.taskName}');
        final success = await taskViewModel.qaStartTask(
          taskId: task.taskId,
          employeeId: authViewModel.localStorage.userId,
        );
        if (success) {
          final logService = TaskCardLogService();
          await logService.logTaskAction(
            taskId: task.taskId,
            actionName: 'QA Started Testing (Kanban)',
            actionDescription:
                'QA Analyst started testing task "${task.taskName}" via Kanban board',
          );
          await _loadTasksForRole();
          print('✅ QA started testing task: ${task.taskName}');
        } else {
          print('❌ Failed to start QA testing for task: ${task.taskName}');
        }
      } catch (e) {
        print('❌ Error in QA start task: $e');
      }
    }

    // Update task status when moved between columns
    Future<void> updateTaskStatus(Task task, KanbanTaskStatus newStatus) async {
      try {
        // Convert KanbanTaskStatus to TaskViewModel TaskStatus
        TaskStatus taskViewModelStatus;
        String newWorkflowStatus;

        switch (newStatus) {
          case KanbanTaskStatus.todo:
            taskViewModelStatus = TaskStatus.assigned;
            newWorkflowStatus = 'Assigned';
            break;
          case KanbanTaskStatus.inProgress:
            taskViewModelStatus = TaskStatus.inProgress;
            newWorkflowStatus = 'In Progress';
            break;
          case KanbanTaskStatus.devcompleted:
            taskViewModelStatus = TaskStatus.devCompleted;
            newWorkflowStatus = 'Dev Completed';
            break;
          case KanbanTaskStatus.inQc:
            taskViewModelStatus = TaskStatus.inQc;
            newWorkflowStatus = 'In QC';
            break;
          case KanbanTaskStatus.workDone:
            taskViewModelStatus = TaskStatus.workDone;
            newWorkflowStatus = 'Work Done';
            break;
          case KanbanTaskStatus.redo:
            taskViewModelStatus = TaskStatus.redo;
            newWorkflowStatus = 'Redo';
            break;
        }

        // Update task status using TaskViewModel
        final success = await Provider.of<TaskViewModel>(context, listen: false)
            .updateTaskStatus(
          taskId: task.taskId,
          status: taskViewModelStatus,
        );

        if (success) {
          // Log the task status change action
          final logService = TaskCardLogService();
          final statusDescription = _getStatusDescription(newStatus);
          await logService.logTaskAction(
            taskId: task.taskId,
            actionName: 'Status Changed',
            actionDescription:
                'Task "${task.taskName}" status changed to "$statusDescription" via Kanban board',
          );

          // Refresh tasks using backend API
          await _loadTasksForRole();

          print('✅ Task ${task.taskName} moved to ${newStatus.name}');
        } else {
          print('❌ Failed to update task status in database');
        }
      } catch (e) {
        print('❌ Error updating task status: $e');
      }
    }

    // Action methods
    Future<void> _startTask(Task task) async {
      try {
        print('🚀 Auto-starting task: ${task.taskName}');
        // Use TaskViewModel to start the task
        final success = await Provider.of<TaskViewModel>(context, listen: false)
            .startTask(taskId: task.taskId);
        if (success) {
          // Refresh tasks after starting (using backend API)
          await _loadTasksForRole();
          print(
              '✅ Task ${task.taskName} started successfully via drag-and-drop');
        } else {
          print('❌ Failed to start task ${task.taskName}');
        }
      } catch (e) {
        print('❌ Error starting task: $e');
      }
    }

    // Build action button based on task status
    Widget _buildActionButton(Task task, KanbanTaskStatus status) {
      switch (status) {
        case KanbanTaskStatus.todo:
          // No action button for TODO - drag to In Progress to start
          return const SizedBox.shrink();
        case KanbanTaskStatus.inProgress:
          // No action button for In Progress - just drag to move
          return const SizedBox.shrink();
        case KanbanTaskStatus.devcompleted:
          // No action button for Completed - just drag to move
          return const SizedBox.shrink();
        case KanbanTaskStatus.inQc:
          // No action button for In QC - just drag to move
          return const SizedBox.shrink();
        case KanbanTaskStatus.workDone:
          // No action button for Work Done - just drag to move
          return const SizedBox.shrink();
        case KanbanTaskStatus.redo:
          // No action button for Redo - just drag to move
          return const SizedBox.shrink();
      }
    }

    // Build task card content matching existing design
    Widget _buildTaskCardContent(Task task, KanbanTaskStatus status,
        {bool isDragging = false}) {
      // Get status color and text
      Color statusColor;
      String statusText;

      switch (status) {
        case KanbanTaskStatus.todo:
          statusColor = ThemeColors.warning;
          statusText = 'Pending';
          break;
        case KanbanTaskStatus.inProgress:
          statusColor = ThemeColors.info;
          statusText = 'In Progress';
          break;
        case KanbanTaskStatus.devcompleted:
          statusColor = ThemeColors.success;
          statusText = 'Dev Completed';
          break;
        case KanbanTaskStatus.inQc:
          statusColor = const Color(0xFF8B5CF6); // Purple
          statusText = 'In QC';
          break;
        case KanbanTaskStatus.workDone:
          statusColor = const Color(0xFF10B981); // Green
          statusText = 'Work Done';
          break;
        case KanbanTaskStatus.redo:
          statusColor = Theme.of(context).colorScheme.error; // Red
          statusText = 'Redo';
          break;
      }

      // Get priority color and text
      Color priorityColor;
      String priorityText;

      // Handle different priority level formats (string, number, etc.)
      final priorityLevel = task.priorityLevel?.toString().toLowerCase() ?? '';

      // Debug logging to see actual priority level values
      print(
          '🔍 Priority Level Debug - Task: ${task.taskName}, Raw: ${task.priorityLevel}, Processed: $priorityLevel');

      switch (priorityLevel) {
        case 'high':
        case '1':
        case 'urgent':
        case 'critical':
          priorityColor = Theme.of(context).colorScheme.error;
          priorityText = 'High';
          break;
        case 'medium':
        case '2':
        case 'normal':
        case 'standard':
          priorityColor = ThemeColors.warning;
          priorityText = 'Medium';
          break;
        case 'low':
        case '3':
        case 'minor':
        case 'lowest':
          priorityColor = ThemeColors.success;
          priorityText = 'Low';
          break;
        default:
          priorityColor = ThemeColors.success;
          priorityText = 'Low';
          break;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Task title
          Text(
            task.taskName ?? 'Untitled Task',
            style: TextStyle(
              fontSize: isDesktop ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: isDragging
                  ? Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey
                  : Theme.of(context).textTheme.titleMedium?.color ??
                      Colors.black,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // Tags row - using Wrap for responsive badge layout
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Status tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
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
              // Priority tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  priorityText,
                  style: TextStyle(
                    color: priorityColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Task description
          if (task.taskDescription?.isNotEmpty == true) ...[
            Text(
              task.taskDescription!,
              style: TextStyle(
                color:
                    Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],

          // Date row (separate from duration to prevent overlap)
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 12,
                color:
                    Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _getDateRange(task),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color ??
                        Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Duration row (separate for clarity)
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 12,
                color: ThemeColors.info,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _getTaskDuration(task),
                  style: TextStyle(
                    color: ThemeColors.info,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // View Details button - small and premium
          if (!isDragging)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: InkWell(
                onTap: () => showTaskDetailsDialog(context, task),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).primaryColor.withOpacity(0.2)
                        : Theme.of(context).primaryColor.withOpacity(0.1),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.25),
                        Theme.of(context).primaryColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Action button based on status
          if (!isDragging) _buildActionButton(task, status),

          // Show drag hint for TODO tasks
          if (!isDragging && status == KanbanTaskStatus.todo) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.drag_indicator,
                  size: 16,
                  color: Theme.of(context).textTheme.bodySmall?.color ??
                      Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Drag to In Progress to start',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color ??
                        Colors.grey,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    // Build task card matching existing design
    Widget buildTaskCard(Task task, KanbanTaskStatus status) {
      return Draggable<Task>(
        data: task,
        onDragStarted: _onDragStarted,
        onDragEnd: (details) => _onDragEnd(),
        onDragUpdate: (details) => _updateDragPosition(details.globalPosition),
        feedback: Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: Transform.rotate(
            angle: 0.05, // Slight rotation (approx 3 degrees)
            child: Transform.scale(
              scale: 1.05,
              child: Container(
                width: MediaQuery.of(context).size.width < 600
                    ? 200
                    : (MediaQuery.of(context).size.width < 900 ? 250 : 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeColors.shadowColor(context).withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: _buildTaskCardContent(task, status, isDragging: true),
              ),
            ),
          ),
        ),
        childWhenDragging: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildTaskCardContent(task, status, isDragging: true),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            key: ValueKey(task.taskId),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: ThemeColors.shadowColor(context).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: ThemeColors.shadowColor(context).withOpacity(0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
              ],
              // Add subtle border when auto-scrolling is active
              border: isDragging.value
                  ? Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: _buildTaskCardContent(task, status),
          ),
        ),
      );
    }

    // Build column with drop functionality and locked visual positions
    Widget buildColumn(KanbanTaskStatus status, String title, Color color) {
      print('🏗️ Building column: $title (${status.name})');

      // Get filtered tasks
      final allTasks = kanbanViewModel.filteredTasks;

      // Filter tasks that belong to this column only
      final columnTasks = allTasks.where((task) {
        final workflowStatus = task.workflowStatus?.toLowerCase() ?? '';

        switch (status) {
          case KanbanTaskStatus.todo:
            return workflowStatus == 'assigned' ||
                workflowStatus == 'pending' ||
                workflowStatus == 'todo';
          case KanbanTaskStatus.inProgress:
            return workflowStatus == 'in progress' ||
                workflowStatus == 'in_progress' ||
                workflowStatus == 'inprogress';
          case KanbanTaskStatus.devcompleted:
            return workflowStatus == 'dev completed' ||
                workflowStatus == 'devcompleted';
          case KanbanTaskStatus.inQc:
            return workflowStatus == 'in qc' ||
                workflowStatus == 'in_qc' ||
                workflowStatus == 'inqc';
          case KanbanTaskStatus.workDone:
            return workflowStatus == 'work done' ||
                workflowStatus == 'workdone' ||
                workflowStatus == 'work_done';
          case KanbanTaskStatus.redo:
            return workflowStatus == 'redo';
        }
      }).toList();

      print('📋 Column $title: ${columnTasks.length} tasks');

      // Build task widgets (no placeholders)
      final taskWidgets = columnTasks
          .map((task) => Container(
                key: ValueKey(task.taskId),
                child: buildTaskCard(task, status),
              ))
          .toList();

      return DragTarget<Task>(
        onWillAccept: (data) {
          // Allow dropping if the task is not already in this column
          if (data == null) return false;

          // Check if task is already in this column
          final workflowStatus = data.workflowStatus?.toLowerCase() ?? '';
          bool alreadyInColumn = false;
          switch (status) {
            case KanbanTaskStatus.todo:
              alreadyInColumn = workflowStatus == 'assigned' ||
                  workflowStatus == 'pending' ||
                  workflowStatus == 'todo';
              break;
            case KanbanTaskStatus.inProgress:
              alreadyInColumn = workflowStatus == 'in progress' ||
                  workflowStatus == 'in_progress' ||
                  workflowStatus == 'inprogress';
              break;
            case KanbanTaskStatus.devcompleted:
              alreadyInColumn = workflowStatus == 'dev completed' ||
                  workflowStatus == 'devcompleted';
              break;
            case KanbanTaskStatus.inQc:
              alreadyInColumn = workflowStatus == 'in qc' ||
                  workflowStatus == 'in_qc' ||
                  workflowStatus == 'inqc';
              break;
            case KanbanTaskStatus.workDone:
              alreadyInColumn = workflowStatus == 'work done' ||
                  workflowStatus == 'workdone' ||
                  workflowStatus == 'work_done';
              break;
            case KanbanTaskStatus.redo:
              alreadyInColumn = workflowStatus == 'redo';
              break;
          }

          return !alreadyInColumn;
        },
        onAccept: (data) async {
          // === QA Analyst-specific flow ===
          if (_isQAAnalyst()) {
            // QA dragging to In QC → call qaStartTask
            if (status == KanbanTaskStatus.inQc) {
              await _qaStartTask(data);
              return;
            }
            // QA dragging to Work Done → show approve dialog
            if (status == KanbanTaskStatus.workDone) {
              await _showQAApproveDialog(data);
              return;
            }
            // QA dragging to Redo → show disapprove dialog
            if (status == KanbanTaskStatus.redo) {
              await _showQADisapproveDialog(data);
              return;
            }
          }

          // === Standard flow for non-QA users ===
          // Update task status when dropped
          await updateTaskStatus(data, status);

          // Show celebration for Dev Completed and Work Done
          if (status == KanbanTaskStatus.devcompleted ||
              status == KanbanTaskStatus.workDone) {
            if (context.mounted) {
              showCongratulationsOverlay(
                context,
                taskName: data.taskName ?? 'Task',
                onComplete: () {
                  // Refresh tasks after celebration (using backend API)
                  final employeeId = LocalStorageService().userId;
                  kanbanViewModel.loadTasksWithBackend(employeeId);
                },
              );
            }
          }

          // If moving to In Progress, automatically start the task
          if (status == KanbanTaskStatus.inProgress) {
            _startTask(data);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isAccepting = candidateData.isNotEmpty;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            margin: EdgeInsets.symmetric(horizontal: isDesktop ? 8 : 4),
            decoration: BoxDecoration(
              color: isAccepting ? color.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isAccepting
                  ? Border.all(color: color.withOpacity(0.5), width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
              boxShadow: isAccepting
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Column(
              children: [
                // Column header with premium design
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        color.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: color.withOpacity(0.15),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      customTextWithClip(
                        text: title,
                        textColor: Colors.white,
                        fontSize: isDesktop ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: customTextWithClip(
                          text:
                              '${kanbanViewModel.getTaskCountForStatus(status.name.toLowerCase())}',
                          textColor: Colors.white,
                          fontSize: isDesktop ? 14 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tasks list with proper height constraint for vertical scrolling
                SizedBox(
                  height: MediaQuery.of(context).size.height *
                      0.7, // 70% of screen height
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: kanbanViewModel.getTaskCountForStatus(
                                status.name.toLowerCase()) ==
                            0
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: color.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.inbox_outlined,
                                    color: color.withOpacity(0.4),
                                    size: isDesktop ? 48 : 36,
                                  ),
                                ),
                                8.hGap,
                                customTextWithClip(
                                  text: isAccepting
                                      ? 'Drop task here'
                                      : 'No tasks here',
                                  textColor: isAccepting
                                      ? color
                                      : Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color ??
                                          Colors.grey,
                                  fontSize: isDesktop ? 14 : 12,
                                  fontWeight: FontWeight.w500,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: AnimationLimiter(
                              child: Column(
                                children:
                                    AnimationConfiguration.toStaggeredList(
                                  duration: const Duration(milliseconds: 375),
                                  childAnimationBuilder: (widget) =>
                                      SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                      child: widget,
                                    ),
                                  ),
                                  children: taskWidgets
                                      .map((widget) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 16),
                                            child: widget,
                                          ))
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Build loading state
    Widget buildLoadingState() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary),
            ),
            16.hGap,
            customTextWithClip(
              text: 'Loading tasks...',
              textColor:
                  Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ],
        ),
      );
    }

    // Build error state
    Widget buildErrorState() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            16.hGap,
            customTextWithClip(
              text: 'Error loading tasks',
              textColor: Theme.of(context).colorScheme.error,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            8.hGap,
            customTextWithClip(
              text: kanbanViewModel.error ?? 'Unknown error',
              textColor:
                  Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.normal,
              textAlign: TextAlign.center,
            ),
            16.hGap,
            ElevatedButton(
              onPressed: refreshTasks,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Debug: Show final task distribution
    if (kanbanViewModel.filteredTasks.isNotEmpty) {
      print('🎯 FINAL TASK DISTRIBUTION:');
      print('📊 Total tasks: ${kanbanViewModel.filteredTasks.length}');
      print(
          '📋 TODO: ${kanbanViewModel.getTaskCountForStatus('todo')} | IN PROGRESS: ${kanbanViewModel.getTaskCountForStatus('inprogress')} | DEV COMPLETED: ${kanbanViewModel.getTaskCountForStatus('devcompleted')}');
    }

    // Get global search notifier for Kanban screen (index 6)
    final globalSearchExpanded = getSearchNotifierForScreen(6);
    final globalHasActiveFilters = getFiltersNotifierForScreen(6);
    final globalFilterTrigger = getFilterTriggerForScreen(6);

    // Sync local hasActiveFilters with global
    useEffect(() {
      final listener = () {
        globalHasActiveFilters.value = kanbanViewModel.hasActiveFilters;
      };
      hasActiveFilters.addListener(listener);
      return () => hasActiveFilters.removeListener(listener);
    }, [kanbanViewModel.hasActiveFilters]);

    // Listen to global filter trigger
    useEffect(() {
      final listener = () {
        final filterOptions = kanbanViewModel.getFilterOptions();
        _showFilterDialog(
          context,
          filterOptions,
          () => kanbanViewModel.clearFilters(),
          () {}, // Update callback
        );
      };
      globalFilterTrigger.addListener(listener);
      return () => globalFilterTrigger.removeListener(listener);
    }, []);

    // Create search filter config for expandable search
    final searchFilterConfig = SearchFilterConfig(
      searchController: searchController,
      searchQuery: searchQuery,
      hasActiveFilters: hasActiveFilters,
      hintText: 'Search tasks...',
      // Use global notifier for search expanded state
      isSearchExpanded: globalSearchExpanded,
      // Kanban screen search: just update the searchQuery, kanbanViewModel.filteredTasks will use it
      onSearchChanged: (query) {
        // The searchQuery.value is already updated in the widget
        // kanbanViewModel.filteredTasks will automatically use it to filter tasks
      },
      // Optional: For search suggestions
      getSearchSuggestions: (query) =>
          kanbanViewModel.getSearchSuggestions(query),
      showSuggestions: showSuggestions,
      searchFocusNode: searchFocusNode,
      searchBarKey: searchBarKey,
      showSuggestionsOverlay: (context, key, suggestions, controller, query,
          showSuggestionsVal, focusNode, isSmall) {
        return _showSuggestionsOverlay(
          context,
          key,
          suggestions,
          controller,
          query,
          showSuggestionsVal ?? showSuggestions,
          focusNode ?? searchFocusNode,
          isSmall,
        );
      },
      setSuggestionsOverlay: (overlay) {
        suggestionsOverlay.value?.remove();
        suggestionsOverlay.value = overlay;
      },
      onFilterTap: () {
        final filterOptions = kanbanViewModel.getFilterOptions();
        _showFilterDialog(
          context,
          filterOptions,
          () => kanbanViewModel.clearFilters(),
          () {}, // Update callback
        );
      },
      activeFilterCount: kanbanViewModel.selectedPriorities.length +
          kanbanViewModel.selectedStatuses.length +
          kanbanViewModel.selectedProjects.length,
    );

    final isSmallMobile = MediaQuery.of(context).size.width < 360;
    final isMobile = MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1200;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: null, // No app bar - using header in body
      floatingActionButton: null,
      body: kanbanViewModel.isLoading
          ? buildLoadingState()
          : kanbanViewModel.error != null
              ? buildErrorState()
              : Column(
                  children: [
                    // Expandable Search Bar (if expanded)
                    ValueListenableBuilder<bool>(
                      valueListenable: searchFilterConfig.isSearchExpanded,
                      builder: (context, isExpanded, child) {
                        if (isExpanded) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: AppBarSearchFilter(
                              config: searchFilterConfig,
                              isDesktop: isDesktop,
                              isMobile: isMobile,
                              isSmallMobile: isSmallMobile,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    // Kanban Board
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final minHeight = constraints.maxHeight;
                          final screenWidth = MediaQuery.of(context).size.width;
                          final availableWidth = screenWidth - 32;

                          // Calculate responsive column width for 6 columns
                          // Account for sidebar and column spacing (5 gaps between 6 columns)
                          const columnSpacingConst = 16.0;
                          const totalGaps = 5; // 6 columns = 5 gaps
                          const sidebarWidth =
                              200.0; // Approximate sidebar width
                          double columnWidth;

                          if (screenWidth < 600) {
                            // Mobile: Smaller columns for horizontal scroll
                            columnWidth =
                                (availableWidth * 0.85).clamp(180.0, 220.0);
                          } else if (screenWidth < 900) {
                            // Tablet: Medium columns
                            columnWidth =
                                (availableWidth * 0.65).clamp(200.0, 250.0);
                          } else if (screenWidth < 1200) {
                            // Small desktop: Fit 6 columns with scroll
                            columnWidth =
                                (availableWidth * 0.55).clamp(200.0, 260.0);
                          } else if (screenWidth < 1600) {
                            // Medium desktop (e.g., 1920x1080 at 125% = 1536 effective)
                            // Fit 5 columns (up to Work Done) without scrolling
                            const laptopSidebarWidth = 180.0;
                            const visibleColumns = 5; // To Do -> Work Done
                            const gaps = visibleColumns - 1;

                            final contentWidth = screenWidth -
                                laptopSidebarWidth -
                                32; // minimal padding

                            columnWidth =
                                ((contentWidth - (gaps * columnSpacingConst)) /
                                        visibleColumns)
                                    .clamp(240.0, 350.0);
                          } else {
                            // Large desktop: Fit 6 columns comfortably
                            final contentWidth =
                                screenWidth - sidebarWidth - 48;
                            columnWidth = ((contentWidth -
                                        (totalGaps * columnSpacingConst)) /
                                    6)
                                .clamp(220.0, 350.0);
                          }

                          final padding = screenWidth < 600 ? 8.0 : 16.0;
                          final columnSpacing = screenWidth < 600 ? 12.0 : 16.0;

                          // Create all columns in a single row with horizontal scroll and scroll bar
                          // Scroll controller is initialized in useEffect
                          if (horizontalScrollController.value == null) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          return Scrollbar(
                            controller: verticalScrollController.value,
                            thumbVisibility:
                                false, // Hover-based for cleaner UI
                            trackVisibility: false,
                            thickness: 10, // Easier to grab
                            scrollbarOrientation: ScrollbarOrientation.right,
                            child: SingleChildScrollView(
                              controller: verticalScrollController.value,
                              physics: const BouncingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints:
                                    BoxConstraints(minHeight: minHeight),
                                child: Listener(
                                  onPointerSignal: (pointerSignal) {
                                    if (pointerSignal is PointerScrollEvent) {
                                      final controller =
                                          horizontalScrollController.value;
                                      if (controller != null) {
                                        // Shift+Scroll for horizontal scrolling
                                        if (HardwareKeyboard
                                            .instance.isShiftPressed) {
                                          final newOffset = controller.offset +
                                              pointerSignal.scrollDelta.dy;
                                          controller.jumpTo(
                                            newOffset.clamp(
                                                0.0,
                                                controller
                                                    .position.maxScrollExtent),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  child: Scrollbar(
                                    controller:
                                        horizontalScrollController.value!,
                                    thumbVisibility: true, // Always visible
                                    trackVisibility: true, // Always visible
                                    thickness: 10, // Easier to grab
                                    scrollbarOrientation:
                                        ScrollbarOrientation.bottom,
                                    child: SingleChildScrollView(
                                      controller:
                                          horizontalScrollController.value!,
                                      scrollDirection: Axis.horizontal,
                                      physics: const ClampingScrollPhysics(),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: padding,
                                          vertical: isDesktop ? 24.0 : 16.0,
                                        ),
                                        child: AnimationLimiter(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: AnimationConfiguration
                                                .toStaggeredList(
                                              duration: const Duration(
                                                  milliseconds: 375),
                                              childAnimationBuilder: (widget) =>
                                                  SlideAnimation(
                                                horizontalOffset: 50.0,
                                                child: FadeInAnimation(
                                                  child: widget,
                                                ),
                                              ),
                                              children: [
                                                SizedBox(
                                                  width: columnWidth,
                                                  child: buildColumn(
                                                      KanbanTaskStatus.todo,
                                                      'To Do',
                                                      const Color(0xFF6366F1)),
                                                ),
                                                SizedBox(width: columnSpacing),
                                                SizedBox(
                                                  width: columnWidth,
                                                  child: buildColumn(
                                                      KanbanTaskStatus
                                                          .inProgress,
                                                      'In Progress',
                                                      const Color(0xFFF59E0B)),
                                                ),
                                                SizedBox(width: columnSpacing),
                                                SizedBox(
                                                  width: columnWidth,
                                                  child: buildColumn(
                                                      KanbanTaskStatus
                                                          .devcompleted,
                                                      'Dev Completed',
                                                      const Color(0xFF10B981)),
                                                ),
                                                SizedBox(width: columnSpacing),
                                                SizedBox(
                                                  width: columnWidth,
                                                  child: buildColumn(
                                                      KanbanTaskStatus.inQc,
                                                      'In QC',
                                                      const Color(0xFF8B5CF6)),
                                                ),
                                                SizedBox(width: columnSpacing),
                                                SizedBox(
                                                  width: columnWidth,
                                                  child: buildColumn(
                                                      KanbanTaskStatus.workDone,
                                                      'Work Done',
                                                      const Color(0xFF059669)),
                                                ),
                                                SizedBox(width: columnSpacing),
                                                SizedBox(
                                                  width: columnWidth,
                                                  child: buildColumn(
                                                      KanbanTaskStatus.redo,
                                                      'Redo',
                                                      const Color(0xFFEF4444)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// A responsive filter sheet for Kanban tasks
class TaskFilterSheet extends StatefulWidget {
  final Map<String, List<String>> filterOptions;
  final KanbanViewModel kanbanViewModel;
  final VoidCallback onClearFilters;
  final VoidCallback onUpdateFilters;
  final bool isSideSheet;

  const TaskFilterSheet({
    super.key,
    required this.filterOptions,
    required this.kanbanViewModel,
    required this.onClearFilters,
    required this.onUpdateFilters,
    this.isSideSheet = false,
  });

  @override
  State<TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<TaskFilterSheet> {
  late Set<String> localPriorities;
  late Set<String> localStatuses;
  late Set<String> localProjects;
  late Set<String> localEmployees;

  @override
  void initState() {
    super.initState();
    localPriorities = Set<String>.from(widget.kanbanViewModel.selectedPriorities);
    localStatuses = Set<String>.from(widget.kanbanViewModel.selectedStatuses);
    localProjects = Set<String>.from(widget.kanbanViewModel.selectedProjects);
    localEmployees = Set<String>.from(widget.kanbanViewModel.selectedEmployees);
    
    // Fetch all employees for testing dropdown
    widget.kanbanViewModel.fetchAllEmployees();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.isSideSheet ? 400 : double.infinity,
        height: widget.isSideSheet ? double.infinity : null,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: widget.isSideSheet
              ? const BorderRadius.horizontal(left: Radius.circular(24))
              : const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: widget.isSideSheet ? const Offset(-5, 0) : const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false, // Don't add extra top padding
          bottom: !widget.isSideSheet,
          left: false,
          right: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle for bottom sheet
              if (!widget.isSideSheet)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(24, widget.isSideSheet ? 24 : 16, 16, 8),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Tasks',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                        fontSize: 20,
                      ),
                    ),
                    Row(
                      children: [
                        if (localPriorities.isNotEmpty ||
                            localStatuses.isNotEmpty ||
                            localProjects.isNotEmpty ||
                            localEmployees.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                localPriorities.clear();
                                localStatuses.clear();
                                localProjects.clear();
                                localEmployees.clear();
                              });
                            },
                            child: Text(
                              'Clear All',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 20),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Priority
                      _buildSectionHeader('Priority'),
                      const SizedBox(height: 12),
                      _buildChips(
                        // Always show standard priorities
                        ['Low', 'Medium', 'High', 'Critical'],
                        localPriorities,
                      ),
                      const SizedBox(height: 28),
                      
                      // Status
                      if (widget.filterOptions['statuses']!.isNotEmpty) ...[
                        _buildSectionHeader('Status'),
                        const SizedBox(height: 12),
                        _buildChips(
                          widget.filterOptions['statuses']!,
                          localStatuses,
                        ),
                        const SizedBox(height: 28),
                      ],
                      
                      // Project
                      if (widget.filterOptions['projects']!.isNotEmpty) ...[
                        _buildSectionHeader('Project'),
                        const SizedBox(height: 12),
                        _buildChips(
                          widget.filterOptions['projects']!,
                          localProjects,
                        ),
                        const SizedBox(height: 28),
                      ],

                      // Employee (Dropdown for testing)
                      _buildSectionHeader('Employee'),
                      const SizedBox(height: 12),
                      ListenableBuilder(
                        listenable: widget.kanbanViewModel,
                        builder: (context, _) => _buildEmployeeDropdown(),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Footer
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(
                    top: BorderSide(
                      color: theme.dividerColor.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          widget.kanbanViewModel.setFilters(
                            priorities: localPriorities,
                            statuses: localStatuses,
                            projects: localProjects,
                            employees: localEmployees,
                          );
                          widget.onUpdateFilters();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
    );
  }

  Widget _buildEmployeeDropdown() {
    final theme = Theme.of(context);
    final allEmployees = widget.kanbanViewModel.allEmployees;
    final isNoEmployees = allEmployees.isEmpty;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          hint: Text(
            isNoEmployees ? 'Fetching employees...' : 'Select Employee',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          value: localEmployees.isNotEmpty && allEmployees.any((e) => e.employeeName == localEmployees.first) 
              ? localEmployees.first 
              : null,
          dropdownColor: theme.cardColor,
          icon: isNoEmployees 
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : Icon(Icons.keyboard_arrow_down, color: theme.colorScheme.primary),
          borderRadius: BorderRadius.circular(12),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'All Employees',
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            ...allEmployees.map((emp) {
              final name = emp.employeeName ?? 'Unknown';
              return DropdownMenuItem<String?>(
                value: name,
                child: Text(name, style: const TextStyle(fontSize: 14)),
              );
            }).toList(),
          ],
          onChanged: (value) {
            setState(() {
              localEmployees.clear();
              if (value != null) {
                localEmployees.add(value);
              }
            });
          },
        ),

      ),
    );
  }

  Widget _buildChips(List<String> options, Set<String> selection) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = selection.contains(option);

        // Priority specific colors
        Color? activeColor;
        if (isSelected) {
          final opt = option.toLowerCase();
          if (opt == 'low') {
            activeColor = ThemeColors.success;
          } else if (opt == 'medium') {
            activeColor = ThemeColors.warning;
          } else if (opt == 'high' || opt == 'critical' || opt == 'urgent') {
            activeColor = theme.colorScheme.error;
          }
        }

        final color = activeColor ?? theme.colorScheme.primary;

        return InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                selection.remove(option);
              } else {
                selection.add(option);
              }
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(0.15)
                  : theme.dividerColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? color : theme.dividerColor.withOpacity(0.1),
                width: 1.5,
              ),
            ),
            child: Text(
              option,
              style: TextStyle(
                color: isSelected ? color : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
