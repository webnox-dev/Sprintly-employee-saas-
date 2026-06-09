import 'package:flutter/material.dart';
import '../../utils/responsive_utils.dart';

class DocumentationScreen extends StatelessWidget {
  const DocumentationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'App Documentation',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: ResponsiveUtils.getResponsivePadding(
            context,
            mobile: const EdgeInsets.all(16),
            tablet: const EdgeInsets.all(24),
            desktop: const EdgeInsets.all(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntroSection(context),
              const SizedBox(height: 32),

              // --- CORE FEATURE: DASHBOARD ---
              _buildSection(
                context,
                title: 'Dashboard',
                icon: Icons.dashboard,
                content:
                    'Your central hub for daily operations. From here you can:\n\n'
                    '• **Status Overview**: Instantly check if you are clocked in, on break, or clocked out.\n'
                    '• **Announcements**: Stay updated with the latest news and directives from management.\n'
                    '• **Notifications**: Get real-time alerts for new tasks, messages, and approvals.\n'
                    '• **Quick Stats**: View your daily attendance hours and task completion progress at a glance.',
              ),

              // --- CORE FEATURE: ATTENDANCE ---
              _buildSection(
                context,
                title: 'Attendance & Time Tracking',
                icon: Icons.access_time_filled,
                content: 'Manage your work hours with precision:\n\n'
                    '• **Clock In/Out**: Start and end your day with a single tap. The system records your location and time automatically.\n'
                    '• **Break Management**: Log breaks (Lunch, Tea, etc.) to ensure accurate working hour calculations.\n'
                    '• **Session History**: View a detailed timeline of your daily sessions, including total productive hours.',
              ),

              // --- CORE FEATURE: TASKS ---
              _buildSection(
                context,
                title: 'Task Management',
                icon: Icons.check_circle_outline,
                content: 'Stay on top of your assignments:\n\n'
                    '• **My Tasks**: View a prioritized list of tasks assigned to you.\n'
                    '• **Task Details**: Access comprehensive info including deadlines, descriptions, and attachments.\n'
                    '• **Status Updates**: Move tasks through stages (In Progress, Review, Completed) and add comments.\n'
                    '• **Task Requests**: Request new tasks or report issues directly to your manager via the "Task Request" feature.',
              ),

              // --- CORE FEATURE: REPORTS ---
              _buildSection(
                context,
                title: 'Daily Reports',
                icon: Icons.summarize_outlined,
                content: 'Submit your daily progress effortlessly:\n\n'
                    '• **Report Generation**: Compile your day\'s activities into a structured report.\n'
                    '• **Task Summary**: Automatically includes completed tasks and hours spent.\n'
                    '• **History & Filters**: Access historical reports and filter them by date range (Today, This Week, Month, or Custom Range) to track performance over time.',
              ),

              // --- NEW FEATURE: TEAM SYNC ---
              _buildSection(
                context,
                title: 'Team Sync & Chat',
                icon: Icons.chat_bubble_outline,
                content: 'Collaborate effectively with your team:\n\n'
                    '• **Team Chat**: Communicate in real-time with colleagues and managers.\n'
                    '• **Project Groups**: Join specialized channels for specific projects.\n'
                    '• **File Sharing**: Share documents and images directly within the chat interface.\n'
                    '• **Status Indicators**: See who is online or busy.',
              ),

              // --- NEW FEATURE: LEAVE MANAGEMENT ---
              _buildSection(
                context,
                title: 'Leave & Calendar',
                icon: Icons.calendar_month_outlined,
                content: 'Plan your schedule and time off:\n\n'
                    '• **Leave Requests**: Apply for leave (Sick, Casual, Paid) directly from the app.\n'
                    '• **Status Tracking**: Monitor the approval status of your requests.\n'
                    '• **Calendar View**: See upcoming holidays, scheduled leaves, and important events visually.',
              ),

              // --- PROFILE & SETTINGS ---
              _buildSection(
                context,
                title: 'Profile & Settings',
                icon: Icons.settings_outlined,
                content: 'Customise your app experience:\n\n'
                    '• **Profile**: Update personal details, contact info, and profile picture.\n'
                    '• **Preferences**: Toggle between Light and Dark themes, and set language preferences.\n'
                    '• **Security**: Change your password and manage login security.\n'
                    '• **Notifications**: Enable or disable alerts for different activities.',
              ),

              const SizedBox(height: 32),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rathz Employee Guide',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A comprehensive guide to all features in the Rathz Employee App. Use this document to navigate and utilize the platform efficiently.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer
                        .withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.8),
                fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              ),
              children: _parseContent(context, content),
            ),
          ),
        ],
      ),
    );
  }

  // Parses markdown-like bold syntax (**text**) into TextSpans
  List<InlineSpan> _parseContent(BuildContext context, String content) {
    List<InlineSpan> spans = [];
    final RegExp exp = RegExp(r'\*\*(.*?)\*\*');
    int start = 0;

    for (final Match match in exp.allMatches(content)) {
      if (match.start > start) {
        spans.add(TextSpan(text: content.substring(start, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.color, // Ensure bold text is visible
        ),
      ));
      start = match.end;
    }

    if (start < content.length) {
      spans.add(TextSpan(text: content.substring(start)));
    }
    return spans;
  }

  Widget _buildFooter(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'Need more help?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact support at support@rathz.com',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'v1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.color
                  ?.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}
