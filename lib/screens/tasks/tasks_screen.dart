import 'package:sizer/sizer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:webnox_taskops/model/task_model.dart';
import 'package:webnox_taskops/helpers/common_colors.dart';
import 'package:webnox_taskops/widgets/common_widgets.dart';
import 'package:webnox_taskops/widgets/animated_loading_states.dart';
import 'package:webnox_taskops/view_model/task_view_model.dart';
import 'package:webnox_taskops/view_model/auth_view_model.dart';
import 'package:responsive_framework/responsive_framework.dart' as responsive;

class TasksScreen extends HookWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedTab = useState(0); // Add tab selection state

    // State for tasks data
    final allTasks = useState<List<Task>>([]);
    final isLoadingTasks = useState<bool>(true);
    final taskError = useState<String?>(null);
    final userRole = useState<String?>(null);

    // Get TaskViewModel and AuthViewModel instances
    final taskViewModel = Provider.of<TaskViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);

    var isDesktop = responsive.ResponsiveValue(
      context,
      defaultValue: false,
      conditionalValues: [
        responsive.Condition.largerThan(name: responsive.MOBILE, value: true),
      ],
    ).value;

    // Fetch tasks on component mount
    useEffect(() {
      Future<void> fetchTasks() async {
        try {
          isLoadingTasks.value = true;
          taskError.value = null;

          print('TasksScreen: Starting to fetch tasks...');

          // Get user role first
          final role = await authViewModel.getUserRole();
          userRole.value = role ?? 'Employee';

          // Use smart task fetching that automatically filters based on user role
          final taskData = await taskViewModel.fetchTasksSmart(authViewModel);

          print(
              'TasksScreen: Received ${taskData.length} tasks from TaskViewModel');

          final fetchedTasks =
              taskData.map((json) => Task.fromJson(json)).toList();
          allTasks.value = fetchedTasks;
          isLoadingTasks.value = false;

          print(
              'TasksScreen: Successfully loaded ${fetchedTasks.length} tasks');
        } catch (e) {
          print('TasksScreen: Error fetching tasks: $e');
          taskError.value = 'Failed to load tasks: $e';
          isLoadingTasks.value = false;
        }
      }

      fetchTasks();
      return null;
    }, []);

    // Filter tasks based on selected tab
    List<Task> getFilteredTasks() {
      // Note: This function should be called after userRole is already determined
      // For now, we'll use a synchronous approach and get role from context
      final currentUserRole = userRole.value; // Use the state variable instead
      final isQAAnalyst = currentUserRole?.toLowerCase().trim() == 'qa analyst';

      if (isQAAnalyst) {
        // QA Analyst filtering
        switch (selectedTab.value) {
          case 0: // To Do - Show tasks that need QA work (dev completed)
            return allTasks.value.where((task) {
              final workflowStatus = task.workflowStatus?.toLowerCase();
              return workflowStatus == 'dev completed';
            }).toList();
          case 1: // Pending - Show tasks that are in QC
            return allTasks.value.where((task) {
              final workflowStatus = task.workflowStatus?.toLowerCase();
              return workflowStatus == 'in qc' ||
                  workflowStatus == 'qc' ||
                  workflowStatus == 'testing' ||
                  workflowStatus == 'in testing' ||
                  workflowStatus == 'qa testing' ||
                  workflowStatus == 'in qa';
            }).toList();
          case 2: // Completed - Show tasks that QA has finished (work done or redo)
            return allTasks.value.where((task) {
              final workflowStatus = task.workflowStatus?.toLowerCase();
              return workflowStatus == 'work done' || workflowStatus == 'redo';
            }).toList();
          case 3: // All Tasks
            return allTasks.value;
          default:
            return allTasks.value;
        }
      } else {
        // Regular employee filtering
        switch (selectedTab.value) {
          case 0: // To Do - Show tasks that are assigned, todo, or redo
            return allTasks.value.where((task) {
              final workflowStatus = task.workflowStatus?.toLowerCase();
              return workflowStatus == 'assigned' ||
                  workflowStatus == 'todo' ||
                  workflowStatus == 'redo' ||
                  workflowStatus == 'pending' ||
                  workflowStatus == 'new' ||
                  workflowStatus == 'not started';
            }).toList();
          case 1: // Pending - Show tasks that are in progress or dev completed
            return allTasks.value.where((task) {
              final workflowStatus = task.workflowStatus?.toLowerCase();
              return workflowStatus == 'in progress' ||
                  workflowStatus == 'dev completed';
            }).toList();
          case 2: // Completed - Show tasks that are work done
            return allTasks.value.where((task) {
              final workflowStatus = task.workflowStatus?.toLowerCase();
              return workflowStatus == 'work done';
            }).toList();
          case 3: // All Tasks
            return allTasks.value;
          default:
            return allTasks.value;
        }
      }
    }

    Widget buildTaskCard(Task task) {
      // Since we don't have taskStatus in the new model, we'll use assignment data
      // For now, we'll show a default status
      Color statusColor = CommonColors.orange;
      String statusText = 'Pending';

      return Container(
        margin: EdgeInsets.symmetric(
            vertical: 1.h, horizontal: isDesktop ? 2.w : 4.w),
        padding: EdgeInsets.all(isDesktop ? 2.w : 4.w),
        decoration: BoxDecoration(
          color: CommonColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CommonColors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: customTextWithClip(
                    text: task.taskName ?? 'Untitled Task',
                    textColor: CommonColors.black,
                    fontSize: isDesktop ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    textAlign: TextAlign.start,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: customTextWithClip(
                    text: statusText,
                    textColor: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            1.h.hGap,
            customTextWithClip(
              text: task.projectDetails?['project_name'] ?? 'No Project',
              textColor: CommonColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            0.5.h.hGap,
            customTextWithClip(
              text: task.taskDescription ?? 'No description available',
              textColor: CommonColors.grey,
              fontSize: 12,
              fontWeight: FontWeight.normal,
              maxLines: 2,
            ),
            1.h.hGap,
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: CommonColors.grey),
                0.5.w.wGap,
                customTextWithClip(
                  text:
                      '${_formatDateTime(task.assignedAt) ?? 'N/A'} - ${_formatDateTime(task.devCompletedAt) ?? 'N/A'}',
                  textColor: CommonColors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
                Spacer(),
                if (task.taskType == 'task')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: CommonColors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: customTextWithClip(
                      text: 'Task',
                      textColor: CommonColors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (task.taskType == 'bug')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: CommonColors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: customTextWithClip(
                      text: 'Bug',
                      textColor: CommonColors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildTaskTabs() {
      // Calculate counts for each tab
      int todoCount = 0;
      int pendingCount = 0;
      int completedCount = 0;

      final isQAAnalyst = userRole.value?.toLowerCase().trim() == 'qa analyst';

      for (final task in allTasks.value) {
        final workflowStatus = task.workflowStatus?.toLowerCase();

        if (isQAAnalyst) {
          // QA Analyst counting logic
          if (workflowStatus == 'dev completed') {
            todoCount++;
          } else if (workflowStatus == 'in qc' ||
              workflowStatus == 'qc' ||
              workflowStatus == 'testing' ||
              workflowStatus == 'in testing' ||
              workflowStatus == 'qa testing' ||
              workflowStatus == 'in qa') {
            pendingCount++;
          } else if (workflowStatus == 'work done' ||
              workflowStatus == 'redo') {
            completedCount++;
          }
        } else {
          // Regular employee counting logic
          if (workflowStatus == 'assigned' ||
              workflowStatus == 'todo' ||
              workflowStatus == 'redo' ||
              workflowStatus == 'pending' ||
              workflowStatus == 'new' ||
              workflowStatus == 'not started') {
            todoCount++;
          } else if (workflowStatus == 'in progress' ||
              workflowStatus == 'dev completed') {
            pendingCount++;
          } else if (workflowStatus == 'work done') {
            completedCount++;
          }
        }
      }

      final tabs = [
        {'label': 'To Do', 'count': '$todoCount'},
        {'label': 'Pending', 'count': '$pendingCount'},
        {'label': 'Completed', 'count': '$completedCount'},
        {'label': 'All Tasks', 'count': '${allTasks.value.length}'},
      ];

      return Container(
        margin: EdgeInsets.symmetric(horizontal: isDesktop ? 2.w : 4.w),
        child: Row(
          children: tabs.asMap().entries.map((entry) {
            final index = entry.key;
            final tab = entry.value;
            final isSelected = selectedTab.value == index;

            return Expanded(
              child: GestureDetector(
                onTap: () => selectedTab.value = index,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? CommonColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? CommonColors.primary
                          : CommonColors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${tab['label']}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : CommonColors.black,
                          fontSize: isDesktop ? 14 : 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tab['count']}',
                        style: TextStyle(
                          color:
                              isSelected ? Colors.white : CommonColors.primary,
                          fontSize: isDesktop ? 16 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    Widget _buildTabContent(String title, List<Task> tasks) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: 1.h, horizontal: isDesktop ? 2.w : 4.w),
            child: customTextWithClip(
              text: '$title (${tasks.length})',
              textColor: CommonColors.black,
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isLoadingTasks.value)
            Column(
              children: List.generate(
                3,
                (index) => TaskCardSkeleton(
                  isMobile: !isDesktop,
                ),
              ),
            )
          else if (taskError.value != null)
            Container(
              height: 20.h,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: CommonColors.red,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    customTextWithClip(
                      text: taskError.value!,
                      textColor: CommonColors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        taskError.value = null;
                        isLoadingTasks.value = true;
                        // Retry fetching tasks
                        try {
                          final taskData = await taskViewModel
                              .fetchTasksSmart(authViewModel);
                          final tasks = taskData
                              .map((json) => Task.fromJson(json))
                              .toList();
                          allTasks.value = tasks;
                          isLoadingTasks.value = false;
                        } catch (e) {
                          taskError.value = 'Failed to load tasks: $e';
                          isLoadingTasks.value = false;
                        }
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (tasks.isEmpty)
            Container(
              height: 20.h,
              child: Center(
                child: customTextWithClip(
                  text: 'No tasks found in $title',
                  textColor: CommonColors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                return buildTaskCard(tasks[index]);
              },
            ),
        ],
      );
    }

    Widget buildTasksList() {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: isDesktop ? 2.w : 4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Tabs
            buildTaskTabs(),
            SizedBox(height: 2.h),
            // Tasks content based on selected tab
            if (selectedTab.value == 0) // To Do
              _buildTabContent('To Do', getFilteredTasks())
            else if (selectedTab.value == 1) // Pending
              _buildTabContent('Pending', getFilteredTasks())
            else if (selectedTab.value == 2) // Completed
              _buildTabContent('Completed', getFilteredTasks())
            else if (selectedTab.value == 3) // All Tasks
              _buildTabContent('All Tasks', allTasks.value)
            else
              _buildTabContent('Tasks', allTasks.value),
          ],
        ),
      );
    }

    Widget buildMobileLayout() {
      return SingleChildScrollView(
        child: Column(
          children: [
            buildTasksList(),
          ],
        ),
      );
    }

    Widget buildDesktopLayout() {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: buildTasksList(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CommonColors.backgroundColor,
      appBar: null, // Removed MainAppBar
      body: isDesktop ? buildDesktopLayout() : buildMobileLayout(),
    );
  }

  String? _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return null;
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
