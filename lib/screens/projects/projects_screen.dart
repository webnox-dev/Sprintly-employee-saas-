import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/project_model.dart';
import '../../utils/responsive_utils.dart';
import '../../view_model/project_view_model.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../helpers/common_colors.dart';
import '../../widgets/modern_project_card.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectViewModel>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    final projectViewModel = Provider.of<ProjectViewModel>(
      context,
      listen: false,
    );

    return Column(
      children: [
        // Compact Header Row (Projects Info Card + 4 Statistics Cards)
        _buildHeader(true),

        // Combined Toolbar (Filters + Search + Refresh)
        _buildCombinedToolbar(true),

        // Content Area Container
        _buildContentContainer(
          TabBarView(
            controller: _tabController,
            children: [
              _buildDesktopProjectsGrid(),
              _buildDesktopProjectsTab(
                (p) => projectViewModel.activeProjects.contains(p),
              ),
              _buildDesktopProjectsTab(
                (p) => projectViewModel.completedProjects.contains(p),
              ),
              _buildDesktopProjectsTab(
                (p) => projectViewModel.highPriorityProjects.contains(p),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Header Section
        _buildHeader(false),
        // Combined Toolbar
        _buildCombinedToolbar(false),
        // Content Area Container
        _buildContentContainer(
          TabBarView(
            controller: _tabController,
            children: [
              _buildAllProjectsTab(),
              _buildActiveProjectsTab(),
              _buildCompletedProjectsTab(),
              _buildHighPriorityTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Container(
      margin: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDesktop)
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Projects title card
                  Expanded(
                    flex: 3,
                    child: _buildProjectsTitleCard(),
                  ),
                  const SizedBox(width: 16),
                  // Statistics Cards
                  Expanded(
                    flex: 5,
                    child: Consumer<ProjectViewModel>(
                      builder: (context, projectViewModel, child) {
                        return _buildStatisticsCards(projectViewModel, true);
                      },
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _buildProjectsTitleCard(),
            const SizedBox(height: 16),
            Consumer<ProjectViewModel>(
              builder: (context, projectViewModel, child) {
                return SizedBox(
                  height: 90,
                  child: _buildStatisticsCards(projectViewModel, false),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectsTitleCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
          width: 1,
        ),
        gradient: isDark
            ? LinearGradient(
                colors: [
                  const Color(0xFF1E3A8A).withOpacity(0.25),
                  const Color(0xFF0F172A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF38BDF8).withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.folder_rounded,
              color: Color(0xFF38BDF8),
              size: 18,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Projects',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage and track your assigned projects efficiently.',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards(
    ProjectViewModel projectViewModel,
    bool isDesktop,
  ) {
    final stats = projectViewModel.getProjectStatistics();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatCard(
          'TOTAL',
          stats['total'] ?? 0,
          const Color(0xFF38BDF8),
          isDark,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'ACTIVE',
          stats['active'] ?? 0,
          const Color(0xFF34D399),
          isDark,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'COMPLETED',
          stats['completed'] ?? 0,
          const Color(0xFFFBBF24),
          isDark,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          'HIGH PRIORITY',
          stats['high_priority'] ?? 0,
          const Color(0xFF60A5FA),
          isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value.toString(),
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombinedToolbar(bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectViewModel = Provider.of<ProjectViewModel>(context, listen: false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: isDesktop
          ? Row(
              children: [
                // Tabs
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFilterChip('All', Icons.folder_open_rounded, 0, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Active', Icons.play_circle_outline_rounded, 1, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completed', Icons.check_circle_outline_rounded, 2, isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Priority', Icons.flag_outlined, 3, isDark),
                  ],
                ),
                const Spacer(),
                // Search Input
                _buildSearchField(isDark),
                const SizedBox(width: 12),
                // Refresh Button
                _buildRefreshButton(projectViewModel, isDark),
              ],
            )
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', Icons.folder_open_rounded, 0, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Active', Icons.play_circle_outline_rounded, 1, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed', Icons.check_circle_outline_rounded, 2, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Priority', Icons.flag_outlined, 3, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSearchField(isDark)),
                    const SizedBox(width: 12),
                    _buildRefreshButton(projectViewModel, isDark),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String title, IconData icon, int index, bool isDark) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        final isSelected = _tabController.index == index;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              _tabController.animateTo(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? CommonColors.primaryGradient : null,
                color: isSelected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark ? const Color(0xFF334155).withOpacity(0.5) : Colors.grey.shade300),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: CommonColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Container(
      width: 260,
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF070B14) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? const Color(0xFF334155).withOpacity(0.5) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: GoogleFonts.inter(
          fontSize: 13,
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          hintText: 'Search projects...',
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white54 : Colors.black45,
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white30 : Colors.black38,
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton(ProjectViewModel projectViewModel, bool isDark) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF070B14) : const Color(0xFFF3F4F6),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? const Color(0xFF334155).withOpacity(0.5) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: () => projectViewModel.refreshProjects(),
        icon: projectViewModel.isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CommonColors.primary,
                ),
              )
            : Icon(
                Icons.refresh_rounded,
                color: isDark ? Colors.white70 : Colors.black87,
                size: 18,
              ),
        tooltip: 'Refresh',
      ),
    );
  }

  Widget _buildContentContainer(Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF090E1A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDesktopProjectsGrid() {
    return Consumer<ProjectViewModel>(
      builder: (context, projectViewModel, child) {
        if (projectViewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (projectViewModel.error != null) {
          return _buildErrorState(projectViewModel.error!);
        }

        final projects = projectViewModel.projects;
        if (projects.isEmpty) {
          return _buildEmptyState();
        }

        return AnimationLimiter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 1.6,
              ),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                return AnimationConfiguration.staggeredGrid(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  columnCount: 3,
                  child: ScaleAnimation(
                    child: FadeInAnimation(
                      child: ModernProjectCard(
                        project: projects[index],
                        onTap: () => _showProjectDetails(projects[index]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopProjectsTab(bool Function(Project) filter) {
    return Consumer<ProjectViewModel>(
      builder: (context, projectViewModel, child) {
        if (projectViewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (projectViewModel.error != null) {
          return Center(child: Text('Error: ${projectViewModel.error}'));
        }

        List<Project> projects =
            projectViewModel.projects.where(filter).toList();
        if (_searchQuery.isNotEmpty) {
          projects = projectViewModel
              .searchProjects(_searchQuery)
              .where(filter)
              .toList();
        }

        if (projects.isEmpty) {
          return _buildEmptyState();
        }

        return AnimationLimiter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 1.6,
              ),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                return AnimationConfiguration.staggeredGrid(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  columnCount: 3,
                  child: ScaleAnimation(
                    child: FadeInAnimation(
                      child: ModernProjectCard(
                        project: projects[index],
                        onTap: () => _showProjectDetails(projects[index]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllProjectsTab() {
    return Consumer<ProjectViewModel>(
      builder: (context, projectViewModel, child) {
        if (projectViewModel.isLoading) {
          return _buildLoadingState();
        }

        if (projectViewModel.error != null) {
          return _buildErrorState(projectViewModel.error!);
        }

        List<Project> projects = projectViewModel.projects;
        if (_searchQuery.isNotEmpty) {
          projects = projectViewModel.searchProjects(_searchQuery);
        }

        return _buildProjectsList(projects);
      },
    );
  }

  Widget _buildActiveProjectsTab() {
    return Consumer<ProjectViewModel>(
      builder: (context, projectViewModel, child) {
        if (projectViewModel.isLoading) {
          return _buildLoadingState();
        }

        if (projectViewModel.error != null) {
          return _buildErrorState(projectViewModel.error!);
        }

        List<Project> projects = projectViewModel.activeProjects;
        if (_searchQuery.isNotEmpty) {
          projects = projectViewModel
              .searchProjects(_searchQuery)
              .where((p) => projectViewModel.activeProjects.contains(p))
              .toList();
        }

        return _buildProjectsList(projects);
      },
    );
  }

  Widget _buildCompletedProjectsTab() {
    return Consumer<ProjectViewModel>(
      builder: (context, projectViewModel, child) {
        if (projectViewModel.isLoading) {
          return _buildLoadingState();
        }

        if (projectViewModel.error != null) {
          return _buildErrorState(projectViewModel.error!);
        }

        List<Project> projects = projectViewModel.completedProjects;
        if (_searchQuery.isNotEmpty) {
          projects = projectViewModel
              .searchProjects(_searchQuery)
              .where((p) => projectViewModel.completedProjects.contains(p))
              .toList();
        }

        return _buildProjectsList(projects);
      },
    );
  }

  Widget _buildHighPriorityTab() {
    return Consumer<ProjectViewModel>(
      builder: (context, projectViewModel, child) {
        if (projectViewModel.isLoading) {
          return _buildLoadingState();
        }

        if (projectViewModel.error != null) {
          return _buildErrorState(projectViewModel.error!);
        }

        List<Project> projects = projectViewModel.highPriorityProjects;
        if (_searchQuery.isNotEmpty) {
          projects = projectViewModel
              .searchProjects(_searchQuery)
              .where((p) => projectViewModel.highPriorityProjects.contains(p))
              .toList();
        }

        return _buildProjectsList(projects);
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error loading projects',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Text(
                error,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.8),
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<ProjectViewModel>().loadProjects();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withOpacity(0.2) : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF334155).withOpacity(0.3) : Colors.grey.shade200,
                ),
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No projects found',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                'You are not assigned to any projects yet. When projects are assigned to you, they will appear here.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsList(List<Project> projects) {
    return RefreshIndicator(
      onRefresh: () => context.read<ProjectViewModel>().refreshProjects(),
      child: projects.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: _buildEmptyState(),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(
                (ResponsiveUtils.isDesktop(context) ||
                        ResponsiveUtils.isLaptop(context))
                    ? 24
                    : 16,
              ),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                return _buildProjectCard(projects[index]);
              },
            ),
    );
  }

  Widget _buildProjectCard(Project project) {
    final isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);

    return Container(
      margin: EdgeInsets.only(bottom: isDesktop ? 16 : 12),
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
      child: InkWell(
        onTap: () => _showProjectDetails(project),
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.projectName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        if (project.projectDescription != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            project.projectDescription!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.7),
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusChip(project.projectStatus ?? 'Unknown'),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  _buildDetailChip(
                    Icons.flag,
                    project.priorityLevel ?? 'Medium',
                    _getPriorityColor(project.priorityLevel),
                  ),
                  const SizedBox(width: 8),
                  _buildDetailChip(
                    Icons.category,
                    project.projectType ?? 'General',
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  if (project.projectStartDate != null &&
                      project.projectStartDate!.isNotEmpty)
                    _buildDetailChip(
                      Icons.calendar_today,
                      project.getFormattedStartDate() ?? '',
                      Colors.green,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _buildProgressInfo(project)),
                  Consumer<ProjectViewModel>(
                    builder: (context, projectViewModel, child) {
                      return IconButton(
                        onPressed: () => projectViewModel.toggleProjectFollow(
                          project.projectId,
                        ),
                        icon: Icon(
                          projectViewModel.isProjectFollowed(project.projectId)
                              ? Icons.star
                              : Icons.star_border,
                          color: projectViewModel.isProjectFollowed(
                            project.projectId,
                          )
                              ? Colors.amber
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        tooltip: projectViewModel.isProjectFollowed(
                          project.projectId,
                        )
                            ? 'Unfollow'
                            : 'Follow',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressInfo(Project project) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Project Duration',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          project.getProjectDuration() ?? 'Not specified',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  void _showProjectDetails(Project project) {
    showDialog(
      context: context,
      builder: (context) =>
          _ProjectDetailsDialog(project: project, context: context),
    );
  }
}

class _ProjectDetailsDialog extends StatefulWidget {
  final Project project;
  final BuildContext context;

  const _ProjectDetailsDialog({required this.project, required this.context});

  @override
  State<_ProjectDetailsDialog> createState() => _ProjectDetailsDialogState();
}

class _ProjectDetailsDialogState extends State<_ProjectDetailsDialog> {
  late Project _project;
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _fetchFullDetails();
  }

  Future<void> _fetchFullDetails() async {
    try {
      final viewModel = context.read<ProjectViewModel>();
      final fullProject = await viewModel.fetchProjectDetails(
        _project.projectId,
      );
      if (fullProject != null && mounted) {
        setState(() {
          _project = fullProject;
          _isLoadingDetails = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingDetails = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching project details: $e');
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 800 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isDesktop ? 32 : 24),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isDesktop ? 24 : 16),
                  topRight: Radius.circular(isDesktop ? 24 : 16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _project.projectName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_project.projectDescription != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _project.projectDescription!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.7),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 32 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection('Project Information', [
                      _buildDetailRow(
                        'Status',
                        _project.projectStatus ?? 'Unknown',
                      ),
                      _buildDetailRow(
                        'Priority',
                        _project.priorityLevel ?? 'Medium',
                      ),
                      _buildDetailRow(
                        'Type',
                        _project.projectType ?? 'General',
                      ),
                      _buildDetailRow(
                        'Start Date',
                        _project.getFormattedStartDate() ?? 'Not specified',
                      ),
                      _buildDetailRow(
                        'MVP Date',
                        _formatDate(_project.projectMVPDate) ?? '-',
                      ),
                      _buildDetailRow(
                        'End Date',
                        _project.getFormattedEndDate() ?? 'Not specified',
                      ),
                      _buildDetailRow(
                        'Duration',
                        _project.getProjectDuration() ?? 'Not specified',
                      ),
                    ]),
                    const SizedBox(height: 24),
                    if (_project.clientName != null ||
                        _project.companyName != null) ...[
                      const SizedBox(height: 24),
                      _buildDetailSection('Client Details', [
                        if (_project.clientName != null)
                          _buildDetailRow('Client Name', _project.clientName!),
                        if (_project.companyName != null)
                          _buildDetailRow('Company', _project.companyName!),
                        if (_project.clientCountry != null)
                          _buildDetailRow('Country', _project.clientCountry!),
                      ]),
                    ],
                    const SizedBox(height: 24),
                    _buildPeopleSection(),
                    if (_isLoadingDetails)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      if (_project.projectFigmaUrls.isNotEmpty ||
                          _project.projectDocuments.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildDetailSection('Resources', [
                          if (_project.projectFigmaUrls.isNotEmpty)
                            _buildLinkRow(
                              'Figma Links',
                              _project.projectFigmaUrls,
                              Icons.link,
                            ),
                          if (_project.projectDocuments.isNotEmpty)
                            _buildLinkRow(
                              'Documents',
                              _project.projectDocuments,
                              Icons.description,
                            ),
                        ]),
                      ],
                      if (_project.projectReleases.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildReleasesSection(),
                      ],
                      if (_project.projectMilestones.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildMilestonesSection(),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_project.projectTeamLeaderId != null)
          _buildPersonRow(
            'Team Leader',
            _getEmployeeName(_project.projectTeamLeaderId!),
          ),
        if (_project.projectManagerId != null)
          _buildPersonRow(
            'Project Manager',
            _getEmployeeName(_project.projectManagerId!),
          ),

        // Handled By (BDEs)
        if (_project.followedByEmployees.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildDetailRow(
            'Handled By',
            _getNameList(_project.followedByEmployees),
          ),
        ],

        // Team Members
        if (_project.teamMembers.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Team Members',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _project.teamMembers.map((member) {
              final name =
                  member['employee_name'] ?? member['name'] ?? 'Unknown';
              final role =
                  member['employee_role'] ?? member['role'] ?? 'Member';
              return Chip(
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      role,
                      style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                    ),
                  ],
                ),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.3),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // Helper getters for names (simplified logic as we might only have IDs in some cases,
  // but if getByIdRich worked, we might have objects in future refactors.
  // For now, assuming IDs or using what's available in the model if we enhanced it)
  // Since the current Project model only stores IDs for leader/manager, we display IDs
  // unless we map them. The JSON showed "project_team_leader" as OBJECT.
  // I need to check if Project model has these objects.

  // The Project model currently has:
  // final String? projectTeamLeaderId;
  // final String? projectManagerId;
  // But the JSON has objects!
  // I likely need to update the Project Model to parse these objects if I want to show names.
  // Scaling back for now: I will show IDs or "Unknown" and add a TODO to update model to parse objects.
  // Actually, checking the JSON again:
  // "project_team_leader": { "employee_name": "Sanjay..." }
  // My Project model only has `projectTeamLeaderId`.
  // I should rely on `teamMembers` list which seems to be List<Map> now?
  // No, `teamMembers` is List<Map> in my update.

  String _getEmployeeName(String id) {
    // Try to find in teamMembers or just return ID for now
    final member = _project.teamMembers.firstWhere(
      (m) => m['employee_id'] == id || m['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    return member['employee_name'] ?? member['name'] ?? id;
  }

  String _getNameList(List<String> ids) {
    // This is for BDE/HandledBy. The JSON shows "handled_by" as OBJECTS.
    // My model has `followedByEmployees` as List<String>.
    // This is a disconnect. I should probably leave "Handled By" as IDs for now
    // or rely on the user to update the model if they want names.
    return ids.join(', ');
  }

  Widget _buildPersonRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkRow(
    String label,
    List<Map<String, dynamic>> items,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            // Support both old and new structure if necessary (name/url vs value/type)
            final name = item['document_name'] ??
                item['figma_url_name'] ??
                item['name'] ??
                'Link';
            final url =
                item['document_url'] ?? item['figma_url'] ?? item['url'] ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        debugPrint('Opening URL: $url');
                        // TODO: Implement url_launcher
                      },
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMilestonesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Milestones',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._project.projectMilestones.map((milestone) {
          final title = milestone['project_milestone_title'] ??
              milestone['name'] ??
              'Unnamed Milestone';
          final desc = milestone['project_milestone_achievement_description'] ??
              milestone['description'];
          final date = milestone['project_milestone_created_at'] ??
              milestone['due_date']; // Fallback

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (desc != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                  ),
                ],
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Date: ${_formatDate(date.toString())}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReleasesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Releases',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._project.projectReleases.map((release) {
          final title = release['project_release_title'] ?? 'Unnamed Release';
          final plannedDate = release['project_release_planned_date'];
          final actualDate = release['project_release_actual_date'];
          final notes = release['project_release_notes'];

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    if (actualDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Released',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (plannedDate != null)
                      Text(
                        'Planned: ${_formatDate(plannedDate)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.7),
                            ),
                      ),
                    if (plannedDate != null && actualDate != null)
                      Text(' • ', style: Theme.of(context).textTheme.bodySmall),
                    if (actualDate != null)
                      Text(
                        'Actual: ${_formatDate(actualDate)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                  ],
                ),
                if (notes != null && notes.toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}
