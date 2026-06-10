import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/responsive_utils.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../model/task_card_request_model.dart';
import '../../view_model/task_card_request_view_model.dart';
import '../../view_model/attendance_view_model.dart';
import 'package:google_fonts/google_fonts.dart';

class TaskCardRequestScreen extends HookWidget {
  const TaskCardRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the view model when screen loads
    useEffect(() {
      Provider.of<TaskCardRequestViewModel>(context, listen: false);
      // The view model initializes automatically in its constructor
      return null;
    }, []);
    final taskNameController = useTextEditingController();
    final taskDescriptionController = useTextEditingController();
    final taskDurationController = useTextEditingController();
    final statusReasonController = useTextEditingController();
    final estimatedDaysController = useTextEditingController();

    final selectedProject = useState<String?>(null);
    final selectedTaskType = useState<String>('Task');
    final selectedPriority = useState<String>('Medium');
    final fromDate = useState<DateTime?>(null);
    final toDate = useState<DateTime?>(null);
    final currentTab = useState<int>(0);

    final isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                ),
              ),
              title: Text(
                'Task Requests',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
            ),
      body: DefaultTabController(
        length: 2,
        child: isDesktop
            ? _buildDesktopLayout(
                context,
                taskNameController,
                taskDescriptionController,
                taskDurationController,
                statusReasonController,
                estimatedDaysController,
                selectedProject,
                selectedTaskType,
                selectedPriority,
                fromDate,
                toDate,
                currentTab,
              )
            : _buildMobileLayout(
                context,
                taskNameController,
                taskDescriptionController,
                taskDurationController,
                statusReasonController,
                estimatedDaysController,
                selectedProject,
                selectedTaskType,
                selectedPriority,
                fromDate,
                toDate,
                currentTab,
              ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    TextEditingController taskNameController,
    TextEditingController taskDescriptionController,
    TextEditingController taskDurationController,
    TextEditingController statusReasonController,
    TextEditingController estimatedDaysController,
    ValueNotifier<String?> selectedProject,
    ValueNotifier<String> selectedTaskType,
    ValueNotifier<String> selectedPriority,
    ValueNotifier<DateTime?> fromDate,
    ValueNotifier<DateTime?> toDate,
    ValueNotifier<int> currentTab,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Sidebar
        Container(
          width: 360,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            border: const Border(
              right: BorderSide(
                color: Color(0xFF1E293B),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(4, 0),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildDesktopHeader(context),
                const Divider(height: 1, color: Color(0xFF1E293B)),
                _buildDesktopStats(context),
                const Divider(height: 1, color: Color(0xFF1E293B)),
                _buildDesktopTabs(context, currentTab),
              ],
            ),
          ),
        ),
        // Main Content
        Expanded(
          child: _buildMainContent(
            context,
            taskNameController,
            taskDescriptionController,
            taskDurationController,
            statusReasonController,
            estimatedDaysController,
            selectedProject,
            selectedTaskType,
            selectedPriority,
            fromDate,
            toDate,
            currentTab,
            true,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    TextEditingController taskNameController,
    TextEditingController taskDescriptionController,
    TextEditingController taskDurationController,
    TextEditingController statusReasonController,
    TextEditingController estimatedDaysController,
    ValueNotifier<String?> selectedProject,
    ValueNotifier<String> selectedTaskType,
    ValueNotifier<String> selectedPriority,
    ValueNotifier<DateTime?> fromDate,
    ValueNotifier<DateTime?> toDate,
    ValueNotifier<int> currentTab,
  ) {
    return Column(
      children: [
        _buildMobileHeader(context),
        _buildMobileTabs(context, currentTab),
        Expanded(
          child: _buildMainContent(
            context,
            taskNameController,
            taskDescriptionController,
            taskDurationController,
            statusReasonController,
            estimatedDaysController,
            selectedProject,
            selectedTaskType,
            selectedPriority,
            fromDate,
            toDate,
            currentTab,
            false,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF1E293B),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Back Button
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white70,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3B82F6),
                      Color(0xFF1D4ED8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_task,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Task Requests',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submit and manage your task requests',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        height: 1.4,
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

  Widget _buildMobileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF1E293B),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Requests',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submit and manage requests',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopStats(BuildContext context) {
    return Consumer<TaskCardRequestViewModel>(
      builder: (context, viewModel, child) {
        final stats = viewModel.getRequestStatistics();

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'OVERVIEW',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    color: const Color(0xFF3B82F6),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildStatCounterRow('Total', stats['total'] ?? 0, Icons.assignment_outlined, const Color(0xFF3B82F6)),
              const SizedBox(height: 16),
              _buildStatCounterRow('Pending', stats['pending'] ?? 0, Icons.pending_actions_outlined, const Color(0xFFF59E0B)),
              const SizedBox(height: 16),
              _buildStatCounterRow('Approved', stats['approved'] ?? 0, Icons.check_circle_outline, const Color(0xFF10B981)),
              const SizedBox(height: 16),
              // Rejected stat: translucent red card container with red cancel icon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.cancel,
                          size: 20,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Rejected',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFCA5A5),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      (stats['rejected'] ?? 0).toString(),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCounterRow(String label, int value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color.withOpacity(0.8)),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
          Text(
            value.toString(),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTabs(
    BuildContext context,
    ValueNotifier<int> currentTab,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              'NAVIGATION',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: const Color(0xFF3B82F6),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildTabButton(context, 'New Request', Icons.add, 0, currentTab),
          const SizedBox(height: 12),
          _buildTabButton(
            context,
            'My Requests',
            Icons.list_alt,
            1,
            currentTab,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabs(BuildContext context, ValueNotifier<int> currentTab) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF1E293B),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        onTap: (index) => currentTab.value = index,
        labelColor: const Color(0xFF3B82F6),
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        indicatorColor: const Color(0xFF3B82F6),
        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: const [
          Tab(text: 'New Request'),
          Tab(text: 'My Requests'),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    String title,
    IconData icon,
    int index,
    ValueNotifier<int> currentTab,
  ) {
    final isSelected = currentTab.value == index;

    return GestureDetector(
      onTap: () => currentTab.value = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: isSelected
              ? const Color(0xFF3B82F6).withOpacity(0.15)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6).withOpacity(0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF3B82F6)
                  : Colors.white.withOpacity(0.5),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    TextEditingController taskNameController,
    TextEditingController taskDescriptionController,
    TextEditingController taskDurationController,
    TextEditingController statusReasonController,
    TextEditingController estimatedDaysController,
    ValueNotifier<String?> selectedProject,
    ValueNotifier<String> selectedTaskType,
    ValueNotifier<String> selectedPriority,
    ValueNotifier<DateTime?> fromDate,
    ValueNotifier<DateTime?> toDate,
    ValueNotifier<int> currentTab,
    bool isDesktop,
  ) {
    return Container(
      color: const Color(0xFF0B0F19),
      child: IndexedStack(
        index: currentTab.value,
        children: [
          _buildNewRequestForm(
            context,
            taskNameController,
            taskDescriptionController,
            taskDurationController,
            statusReasonController,
            estimatedDaysController,
            selectedProject,
            selectedTaskType,
            selectedPriority,
            fromDate,
            toDate,
            isDesktop,
          ),
          _buildRequestsList(context, isDesktop),
        ],
      ),
    );
  }

  Widget _buildNewRequestForm(
    BuildContext context,
    TextEditingController taskNameController,
    TextEditingController taskDescriptionController,
    TextEditingController taskDurationController,
    TextEditingController statusReasonController,
    TextEditingController estimatedDaysController,
    ValueNotifier<String?> selectedProject,
    ValueNotifier<String> selectedTaskType,
    ValueNotifier<String> selectedPriority,
    ValueNotifier<DateTime?> fromDate,
    ValueNotifier<DateTime?> toDate,
    bool isDesktop,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Consumer<TaskCardRequestViewModel>(
        builder: (context, viewModel, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isDesktop) ...[
                Text(
                  'New Task Request',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Task Name
              _buildFormField(
                context,
                'Task Name *',
                'Enter task name',
                taskNameController,
                isDesktop,
                isRequired: true,
              ),
              const SizedBox(height: 20),

              // Task Description
              _buildFormField(
                context,
                'Task Description *',
                'Describe the task in detail',
                taskDescriptionController,
                isDesktop,
                maxLines: 4,
                isRequired: true,
              ),
              const SizedBox(height: 20),

              // Project Selection
              _buildProjectDropdown(
                context,
                selectedProject,
                viewModel,
                isDesktop,
                isRequired: true,
              ),
              const SizedBox(height: 20),

              // Task Type and Priority Row
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      context,
                      'Task Type *',
                      selectedTaskType.value,
                      viewModel.taskTypes,
                      (value) => selectedTaskType.value = value!,
                      isDesktop,
                      isRequired: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownField(
                      context,
                      'Priority *',
                      selectedPriority.value,
                      viewModel.priorityLevels,
                      (value) => selectedPriority.value = value!,
                      isDesktop,
                      isRequired: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Task Duration
              _buildFormField(
                context,
                'Estimated Duration *',
                'e.g., 2 days, 8 hours',
                taskDurationController,
                isDesktop,
                isRequired: true,
              ),
              const SizedBox(height: 20),

              // Date Range - From Date
              _buildDateField(
                context,
                'From Date *',
                fromDate.value,
                (date) {
                  fromDate.value = date;
                  _updateEstimatedDays(
                    fromDate.value,
                    toDate.value,
                    estimatedDaysController,
                  );
                },
                isDesktop,
                isRequired: true,
              ),
              const SizedBox(height: 20),

              // Date Range - To Date
              _buildDateField(
                context,
                'To Date *',
                toDate.value,
                (date) {
                  toDate.value = date;
                  _updateEstimatedDays(
                    fromDate.value,
                    toDate.value,
                    estimatedDaysController,
                  );
                },
                isDesktop,
                isRequired: true,
              ),
              const SizedBox(height: 20),

              // Estimated Days (Auto-calculated)
              _buildEstimatedDaysField(
                context,
                'Estimated Days *',
                estimatedDaysController,
                isDesktop,
                isRequired: true,
              ),
              const SizedBox(height: 20),

              // Status Reason (Optional)
              _buildFormField(
                context,
                'Additional Notes (Optional)',
                'Any additional information or requirements',
                statusReasonController,
                isDesktop,
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Submit Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: viewModel.isLoading
                        ? null
                        : () => _submitRequest(
                              context,
                              viewModel,
                              taskNameController,
                              taskDescriptionController,
                              taskDurationController,
                              statusReasonController,
                              estimatedDaysController,
                              selectedProject,
                              selectedTaskType,
                              selectedPriority,
                              fromDate,
                              toDate,
                            ),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: isDesktop ? 18 : 14,
                      ),
                      child: Center(
                        child: viewModel.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Submit Request',
                                style: GoogleFonts.outfit(
                                  fontSize: isDesktop ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              if (viewModel.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          viewModel.error!,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFFCA5A5),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildRequestsList(BuildContext context, bool isDesktop) {
    return Consumer<TaskCardRequestViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading && viewModel.requests.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
          );
        }

        if (viewModel.requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 64,
                  color: Colors.white.withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Requests Yet',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Submit your first task request to get started',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          itemCount: viewModel.requests.length,
          itemBuilder: (context, index) {
            final request = viewModel.requests[index];
            return _buildRequestCard(context, request, isDesktop);
          },
        );
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFEF4444); // Red
      case 'medium':
        return const Color(0xFFF59E0B); // Amber
      case 'low':
        return const Color(0xFF10B981); // Green
      default:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  Widget _buildRequestCard(
    BuildContext context,
    TaskCardRequest request,
    bool isDesktop,
  ) {
    final priorityColor = _getPriorityColor(request.priorityLevel ?? 'Medium');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
        ),
        border: Border(
          left: BorderSide(color: priorityColor, width: 4),
          top: const BorderSide(color: Color(0xFF1E293B)),
          right: const BorderSide(color: Color(0xFF1E293B)),
          bottom: const BorderSide(color: Color(0xFF1E293B)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.taskName ?? 'Untitled Task',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              _buildStatusChip(context, request.workflowStatus ?? 'Pending'),
            ],
          ),
          const SizedBox(height: 12),
          if (request.taskDescription != null) ...[
            Text(
              request.taskDescription!,
              style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              _buildInfoChip(
                context,
                Icons.category,
                request.taskType ?? 'Task',
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                context,
                Icons.flag,
                request.priorityLevel ?? 'Medium',
              ),
              if (request.taskDuration != null) ...[
                const SizedBox(width: 8),
                _buildInfoChip(context, Icons.schedule, request.taskDuration!),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 14,
                color: Colors.white.withOpacity(0.4),
              ),
              const SizedBox(width: 4),
              Text(
                'Requested ${_formatDate(request.requestedOn)}',
                style: GoogleFonts.outfit(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = const Color(0xFFF59E0B);
        break;
      case 'approved':
        color = const Color(0xFF10B981);
        break;
      case 'rejected':
        color = const Color(0xFFEF4444);
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        status,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(
    BuildContext context,
    String label,
    String hint,
    TextEditingController controller,
    bool isDesktop, {
    int maxLines = 1,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            errorBorder: isRequired && controller.text.trim().isEmpty
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFEF4444),
                    ),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isDesktop ? 20 : 16,
            ),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF1E293B),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectDropdown(
    BuildContext context,
    ValueNotifier<String?> selectedProject,
    TaskCardRequestViewModel viewModel,
    bool isDesktop, {
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRequired ? 'Project *' : 'Project',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedProject.value,
          dropdownColor: const Color(0xFF0F172A),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 14,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white54,
          ),
          decoration: InputDecoration(
            hintText: 'Select a project',
            hintStyle: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            errorBorder: isRequired && selectedProject.value == null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFEF4444),
                    ),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isDesktop ? 20 : 16,
            ),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF1E293B),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 1.5,
              ),
            ),
          ),
          items: viewModel.projects.map((project) {
            return DropdownMenuItem<String>(
              value: project.projectId,
              child: Text(
                project.projectName,
                style: GoogleFonts.outfit(color: Colors.white),
              ),
            );
          }).toList(),
          onChanged: (value) => selectedProject.value = value,
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    BuildContext context,
    String label,
    String value,
    List<String> options,
    void Function(String?) onChanged,
    bool isDesktop, {
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: const Color(0xFF0F172A),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 14,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white54,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            errorBorder: isRequired && value.isEmpty
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFEF4444),
                    ),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isDesktop ? 20 : 16,
            ),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF1E293B),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 1.5,
              ),
            ),
          ),
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(
                option,
                style: GoogleFonts.outfit(color: Colors.white),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDateField(
    BuildContext context,
    String label,
    DateTime? value,
    void Function(DateTime?) onChanged,
    bool isDesktop, {
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF3B82F6),
                      onPrimary: Colors.white,
                      surface: Color(0xFF0F172A),
                      onSurface: Colors.white,
                    ),
                    dialogBackgroundColor: const Color(0xFF0B0F19),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              onChanged(date);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isDesktop ? 20 : 16,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border.all(
                color: isRequired && value == null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF1E293B),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null ? _formatDate(value) : 'Select date',
                    style: GoogleFonts.outfit(
                      color: value != null
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Color(0xFF3B82F6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _updateEstimatedDays(
    DateTime? fromDate,
    DateTime? toDate,
    TextEditingController estimatedDaysController,
  ) {
    if (fromDate != null && toDate != null) {
      final days = toDate.difference(fromDate).inDays + 1;
      estimatedDaysController.text = days.toString();
    } else {
      estimatedDaysController.clear();
    }
  }

  Widget _buildEstimatedDaysField(
    BuildContext context,
    String label,
    TextEditingController controller,
    bool isDesktop, {
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Auto-calculated',
            hintStyle: GoogleFonts.outfit(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            errorBorder: isRequired && controller.text.trim().isEmpty
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFEF4444),
                    ),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isDesktop ? 20 : 16,
            ),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF1E293B),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 1.5,
              ),
            ),
            suffixIcon: const Icon(
              Icons.calculate,
              color: Color(0xFF3B82F6),
            ),
          ),
        ),
      ],
    );
  }


  Future<void> _submitRequest(
    BuildContext context,
    TaskCardRequestViewModel viewModel,
    TextEditingController taskNameController,
    TextEditingController taskDescriptionController,
    TextEditingController taskDurationController,
    TextEditingController statusReasonController,
    TextEditingController estimatedDaysController,
    ValueNotifier<String?> selectedProject,
    ValueNotifier<String> selectedTaskType,
    ValueNotifier<String> selectedPriority,
    ValueNotifier<DateTime?> fromDate,
    ValueNotifier<DateTime?> toDate,
  ) async {
    // Check if user has punched in
    final attendanceViewModel = Provider.of<AttendanceViewModel>(
      context,
      listen: false,
    );
    final attendanceStatus =
        await attendanceViewModel.getCurrentAttendanceStatus();
    final isPunchedIn = attendanceStatus?['is_clocked_in'] ?? false;

    if (!isPunchedIn) {
      // Show popup message
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Text('Punch In Required'),
              ],
            ),
            content: const Text(
              'You need to punch in before creating a task card. Please punch in to start your work.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (taskNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a task name')));
      return;
    }

    if (taskDescriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task description')),
      );
      return;
    }

    if (selectedProject.value == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a project')));
      return;
    }

    if (fromDate.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a from date')),
      );
      return;
    }

    if (toDate.value == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a to date')));
      return;
    }

    if (toDate.value!.isBefore(fromDate.value!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To date must be after from date')),
      );
      return;
    }

    final success = await viewModel.submitRequest(
      taskName: taskNameController.text.trim(),
      taskDescription: taskDescriptionController.text.trim(),
      taskDuration: taskDurationController.text.trim(),
      taskType: selectedTaskType.value,
      priorityLevel: selectedPriority.value,
      projectId: selectedProject.value!,
      fromDate: fromDate.value,
      toDate: toDate.value,
      statusReason: statusReasonController.text.trim().isEmpty
          ? null
          : statusReasonController.text.trim(),
    );

    if (success) {
      // Clear form
      taskNameController.clear();
      taskDescriptionController.clear();
      taskDurationController.clear();
      statusReasonController.clear();
      estimatedDaysController.clear();
      selectedProject.value = null;
      selectedTaskType.value = 'Task';
      selectedPriority.value = 'Medium';
      fromDate.value = null;
      toDate.value = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
