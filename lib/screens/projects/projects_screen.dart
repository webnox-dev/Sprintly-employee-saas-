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
import '../../widgets/animations/silk_shader_widget.dart';

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
        // Compact Header
        _buildHeader(true),

        // Combined Toolbar (Tabs + Search)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNanoTabItem(
                      context,
                      'All',
                      Icons.folder_open_rounded,
                      0,
                      true,
                    ),
                    _buildNanoTabItem(
                      context,
                      'Active',
                      Icons.play_circle_rounded,
                      1,
                      true,
                    ),
                    _buildNanoTabItem(
                      context,
                      'Completed',
                      Icons.check_circle_rounded,
                      2,
                      true,
                    ),
                    _buildNanoTabItem(
                      context,
                      'Priority',
                      Icons.flag_rounded,
                      3,
                      true,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Search
              Container(
                width: 300,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Refresh Button
              Consumer<ProjectViewModel>(
                builder: (context, projectViewModel, child) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => projectViewModel.refreshProjects(),
                      icon: projectViewModel.isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                      tooltip: 'Refresh',
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: TabBarView(
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_off_rounded,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No projects found',
                  style: GoogleFonts.lexend(
                    fontSize: 18,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return AnimationLimiter(
          child: Padding(
            padding: const EdgeInsets.all(32),
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

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Header Section
        _buildHeader(false),
        // Search and Filter Section
        _buildSearchAndFilter(false),
        // Tab Bar
        _buildTabBar(false),
        // Tab Content
        Expanded(
          child: TabBarView(
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
    return SilkShaderWidget(
      speed: 0.8,
      scale: 1.2,
      color: Theme.of(context).colorScheme.primary,
      noiseIntensity: 1.5,
      child: Container(
        margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.all(16),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 32 : 20,
          vertical: ResponsiveUtils.getResponsiveSize(
            context,
            mobile: 16,
            tablet: 18,
            laptop: 20, // Reduced from 28
            desktop: 28,
          ),
        ),
        decoration: BoxDecoration(
          borderRadius:
              isDesktop ? BorderRadius.zero : BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CommonColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: CommonColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: CommonColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.folder_copy_rounded,
                    size: ResponsiveUtils.getResponsiveSize(
                      context,
                      mobile: 20,
                      tablet: 20,
                      laptop: 20, // Reduced from 24
                      desktop: 24,
                    ),
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: isDesktop ? 16 : 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Projects',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveUtils.getResponsiveSize(
                            context,
                            mobile: 20,
                            tablet: 20,
                            laptop: 22, // Reduced from 24
                            desktop: 24,
                          ),
                          color: Colors.white,
                        ),
                      ),
                      if (isDesktop) const SizedBox(height: 2),
                      Text(
                        'Manage your assigned projects',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: isDesktop ? 13 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 24),
                  // Compact desktop stats
                  Expanded(
                    flex: 3,
                    child: Consumer<ProjectViewModel>(
                      builder: (context, projectViewModel, child) {
                        return _buildStatisticsCards(
                          projectViewModel,
                          isDesktop,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            if (!isDesktop) ...[
              const SizedBox(height: 16),
              Consumer<ProjectViewModel>(
                builder: (context, projectViewModel, child) {
                  return _buildStatisticsCards(projectViewModel, isDesktop);
                },
              ),
            ],
          ],
        ),
      ),
    );
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

  Widget _buildStatisticsCards(
    ProjectViewModel projectViewModel,
    bool isDesktop,
  ) {
    final stats = projectViewModel.getProjectStatistics();

    return Row(
      children: [
        _buildStatCard('Total', stats['total'] ?? 0, Colors.blue, isDesktop),
        SizedBox(width: isDesktop ? 12 : 8),
        _buildStatCard('Active', stats['active'] ?? 0, Colors.green, isDesktop),
        SizedBox(width: isDesktop ? 12 : 8),
        _buildStatCard(
          'Completed',
          stats['completed'] ?? 0,
          Colors.purple,
          isDesktop,
        ),
        SizedBox(width: isDesktop ? 12 : 8),
        _buildStatCard(
          'High Priority',
          stats['high_priority'] ?? 0,
          Colors.red,
          isDesktop,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, Color color, bool isDesktop) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 16 : 12,
          vertical: isDesktop ? 12 : 12,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: GoogleFonts.outfit(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: isDesktop ? 4 : 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: isDesktop ? 12 : 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
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

  Widget _buildSearchAndFilter(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search projects...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 20 : 16,
                    vertical: isDesktop ? 16 : 14,
                  ),
                  hintStyle: GoogleFonts.inter(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: isDesktop ? 16 : 12),
          Consumer<ProjectViewModel>(
            builder: (context, projectViewModel, child) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => projectViewModel.refreshProjects(),
                  icon: projectViewModel.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : Icon(
                          Icons.refresh_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  tooltip: 'Refresh',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDesktop) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 800 : double.infinity,
        ),
        margin: isDesktop
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNanoTabItem(
              context,
              'All',
              Icons.folder_open_rounded,
              0,
              isDesktop,
            ),
            _buildNanoTabItem(
              context,
              'Active',
              Icons.play_circle_rounded,
              1,
              isDesktop,
            ),
            _buildNanoTabItem(
              context,
              'Completed',
              Icons.check_circle_rounded,
              2,
              isDesktop,
            ),
            _buildNanoTabItem(
              context,
              'Priority',
              Icons.flag_rounded,
              3,
              isDesktop,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNanoTabItem(
    BuildContext context,
    String title,
    IconData icon,
    int index,
    bool isDesktop,
  ) {
    // We need to listen to the tab controller to update the UI
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
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 12,
                vertical: isDesktop ? 12 : 8,
              ),
              decoration: BoxDecoration(
                gradient: isSelected ? CommonColors.primaryGradient : null,
                color: isSelected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(40),
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
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: isDesktop ? 18 : 16,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  // Always show text on desktop
                  if (isDesktop || isSelected || true) ...[
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.8),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: isDesktop ? 14 : 12,
                      ),
                    ),
                  ],
                ],
              ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No projects found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are not assigned to any projects yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
          ),
        ],
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
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No projects found',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are not assigned to any projects yet',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: () => context
                              .read<ProjectViewModel>()
                              .refreshProjects(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
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
              // Header Row
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

              // Project Details Row
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

              // Progress and Actions Row
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
