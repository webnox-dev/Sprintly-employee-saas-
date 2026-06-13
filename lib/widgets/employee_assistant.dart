import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webnox_taskops/api/endpoints/ai_chat_api.dart';
import 'package:webnox_taskops/screens/task_request/task_card_request_screen.dart';
import 'package:webnox_taskops/utils/responsive_utils.dart';
import 'package:webnox_taskops/widgets/leave_request_dialog.dart';
import 'package:webnox_taskops/widgets/glass_container.dart';
import 'package:webnox_taskops/theme/app_theme.dart';

class EmployeeAssistant extends StatefulWidget {
  const EmployeeAssistant({super.key});

  @override
  State<EmployeeAssistant> createState() => _EmployeeAssistantState();
}

class _EmployeeAssistantState extends State<EmployeeAssistant>
    with TickerProviderStateMixin {
  bool _isOpen = false;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final AiChatApi _aiChatApi = AiChatApi();
  final String _sessionId = "session_${DateTime.now().millisecondsSinceEpoch}";

  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          "Hello! I'm your **Employee Assistant**. I can help you with tasks, leave requests, and reports. How can I assist you today?",
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;

  bool _isTyping = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleChat() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _focusNode.requestFocus();
        });
      } else {
        _animationController.reverse();
        _focusNode.unfocus();
      }
    });
  }

  Future<void> _sendMessage([String? text]) async {
    final msgToSend = text ?? _textController.text.trim();
    if (msgToSend.isEmpty) return;

    if (text != null) {
      _textController.clear();
    } else {
      _textController.clear();
    }

    setState(() {
      _messages.add(
        ChatMessage(text: msgToSend, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final response = await _aiChatApi.sendMessage(
        msgToSend,
        sessionId: _sessionId,
      );

      if (!mounted) return;

      String replyText;
      String? actionCode;

      if (response.success && response.data != null) {
        if (response.data is Map) {
          final dataMap = response.data as Map;
          replyText = dataMap['reply']?.toString() ??
              dataMap['message']?.toString() ??
              "I processed your request.";
          actionCode = dataMap['action']?.toString();
        } else if (response.data is String) {
          replyText = response.data;
        } else {
          replyText =
              "I received a response, but it was in an unexpected format.";
        }
      } else {
        replyText =
            "I'm having trouble connecting to the server. Please try again later. (${response.message})";
      }

      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text: replyText,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });

      _scrollToBottom();

      if (actionCode != null) {
        _handleBackendAction(actionCode);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text: "An error occurred: $e",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  void _handleBackendAction(String action) {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      switch (action.toLowerCase()) {
        case 'open_task_request':
        case 'open_task_modal':
          _showTaskRequestDialog(context);
          break;
        case 'open_leave_request':
        case 'show_leave_form':
        case 'apply_leave':
          _showLeaveRequestDialog(context);
          break;
        case 'nav_attendance':
        case 'navigate_attendance':
          Get.toNamed('/attendance');
          break;
        case 'nav_reports':
        case 'navigate_reports':
          Get.toNamed('/reports');
          break;
        case 'nav_dashboard':
        case 'navigate_dashboard':
          Get.toNamed('/dashboard');
          break;
      }
    });
  }

  void _showTaskRequestDialog(BuildContext context) {
    var isDesktop =
        ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isLaptop(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 100 : 16,
          vertical: 24,
        ),
        child: Container(
          width: isDesktop ? 800 : double.infinity,
          height: 800,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(child: TaskCardRequestScreen()),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaveRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LeaveRequestDialog(),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCirc,
        );
      }
    });
  }

  Widget _buildTypingIndicator() {
    return FadeInLeft(
      duration: const Duration(milliseconds: 300),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkCardColor
                : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox(
            width: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) => _buildTypingDot(index)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(
              0.3 + (0.7 * _pulseController.value),
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ZoomIn(
      duration: const Duration(milliseconds: 300),
      child: Align(
        alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getResponsiveSize(
              context,
              mobile: 240,
              tablet: 280,
              desktop: 320,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: msg.isUser
                ? const LinearGradient(
                    colors: [
                      Color(0xFF2563EB),
                      Color(0xFF7C3AED),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: msg.isUser
                ? null
                : (isDark ? const Color(0xFF1E293B).withOpacity(0.7) : Colors.white),
            border: msg.isUser
                ? null
                : Border.all(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(msg.isUser ? 20 : 4),
              bottomRight: Radius.circular(msg.isUser ? 4 : 20),
            ),
            boxShadow: [
              BoxShadow(
                color: msg.isUser
                    ? const Color(0xFF7C3AED).withOpacity(0.15)
                    : Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (msg.isUser)
                Text(
                  msg.text,
                  style: GoogleFonts.lexend(color: Colors.white, fontSize: 14),
                )
              else
                MarkdownBody(
                  data: msg.text,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.lexend(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    strong: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg.timestamp),
                    style: GoogleFonts.lexend(
                      fontSize: 9,
                      color: msg.isUser ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  if (msg.isUser) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all, size: 10, color: Colors.white70),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    // Smart positioning: Smaller bottom offset on shorter screens
    final bottomOffset = screenHeight < 700
        ? ResponsiveUtils.getResponsiveSize(
            context,
            mobile: 70,
            tablet: 75,
            desktop: 80,
          )
        : ResponsiveUtils.getResponsiveSize(
            context,
            mobile: 80,
            tablet: 90,
            desktop: 100,
          );

    // Smart sizing: Use percentage of screen height with caps
    final chatWidth = ResponsiveUtils.getResponsiveSize(
      context,
      mobile: MediaQuery.of(context).size.width - 32,
      tablet: 360,
      desktop: 400,
      laptop: 380,
    );

    final chatHeight = ResponsiveUtils.getResponsiveSize(
      context,
      mobile: screenHeight * 0.6,
      tablet: (screenHeight * 0.7).clamp(400.0, 500.0),
      desktop: (screenHeight * 0.7).clamp(450.0, 600.0),
      laptop: (screenHeight * 0.7).clamp(420.0, 550.0),
    );

    return Positioned(
      bottom: bottomOffset,
      right: ResponsiveUtils.getResponsiveSize(
        context,
        mobile: 16,
        tablet: 20,
        desktop: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chat Window
          if (_isOpen || _animationController.isAnimating)
            ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.bottomRight,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GlassContainer(
                  width: chatWidth,
                  height: chatHeight,
                  margin: const EdgeInsets.only(bottom: 20),
                  blur: 15,
                  opacity: isDark ? 0.8 : 0.9,
                  color: isDark ? AppTheme.darkBackground : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(isDark ? 0.1 : 0.5),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getResponsiveSize(
                            context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20,
                          ),
                          vertical: ResponsiveUtils.getResponsiveSize(
                            context,
                            mobile: 14,
                            tablet: 16,
                            desktop: 18,
                          ),
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF2563EB), // Rich Royal Blue
                              Color(0xFF7C3AED), // Deep Indigo/Purple
                              Color(0xFFDB2777), // Magenta
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.smart_toy,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _pulseController,
                                        builder: (context, child) {
                                          return Container(
                                            width: 10 + (6 * _pulseController.value),
                                            height: 10 + (6 * _pulseController.value),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.4 * (1 - _pulseController.value)),
                                              shape: BoxShape.circle,
                                            ),
                                          );
                                        },
                                      ),
                                      Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22C55E),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assistant',
                                  style: GoogleFonts.lexend(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: ResponsiveUtils.getResponsiveSize(
                                      context,
                                      mobile: 16,
                                      tablet: 17,
                                      desktop: 18,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.white70,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Active Now',
                                      style: GoogleFonts.lexend(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                              ),
                              onPressed: _toggleChat,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.2),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Messages
                      Expanded(
                        child: Container(
                          color: Colors.transparent,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                            itemCount: _messages.length + (_isTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _messages.length) {
                                return _buildTypingIndicator();
                              }
                              final msg = _messages[index];
                              return _buildMessageBubble(msg, index);
                            },
                          ),
                        ),
                      ),

                      // Quick Actions
                      if (_messages.length <= 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                QuickActionChip(
                                  label: "Task",
                                  icon: Icons.add_task,
                                  onTap: () => _sendMessage("Request a new task"),
                                ),
                                QuickActionChip(
                                  label: "Leave",
                                  icon: Icons.event_busy,
                                  onTap: () => _sendMessage("Apply for leave"),
                                ),
                                QuickActionChip(
                                  label: "Report",
                                  icon: Icons.analytics,
                                  onTap: () => _sendMessage("Show my reports"),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Input Area
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          ResponsiveUtils.getResponsiveSize(
                            context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20,
                          ),
                          0,
                          ResponsiveUtils.getResponsiveSize(
                            context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20,
                          ),
                          ResponsiveUtils.getResponsiveSize(
                            context,
                            mobile: 16,
                            tablet: 18,
                            desktop: 20,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A).withOpacity(0.4)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _focusNode.hasFocus
                                        ? const Color(0xFF7C3AED).withOpacity(0.6)
                                        : (isDark
                                            ? Colors.white.withOpacity(0.08)
                                            : Colors.grey.withOpacity(0.2)),
                                    width: 1.2,
                                  ),
                                  boxShadow: _focusNode.hasFocus
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF7C3AED).withOpacity(0.12),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : [],
                                ),
                                child: TextField(
                                  controller: _textController,
                                  focusNode: _focusNode,
                                  style: GoogleFonts.lexend(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Ask me anything...',
                                    hintStyle: GoogleFonts.lexend(
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => _sendMessage(),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF2563EB),
                                        Color(0xFF7C3AED),
                                        Color(0xFFDB2777),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF7C3AED).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 20,
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
            ),

          // Floating Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                opacity: (_isHovered && !_isOpen) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withOpacity(0.85) : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withOpacity(0.3),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFFDB2777)],
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ask Sprintly AI',
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Hero(
                tag: 'assistant-fab',
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (!_isOpen) ...[
                      // Pulse Ring 1
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 60 + (20 * _pulseController.value),
                            height: 60 + (20 * _pulseController.value),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF7C3AED).withOpacity(0.3 * (1 - _pulseController.value)),
                                width: 1.5,
                              ),
                            ),
                          );
                        },
                      ),
                      // Pulse Ring 2 (larger/different color)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final double delayValue = (_pulseController.value + 0.5) % 1.0;
                          return Container(
                            width: 60 + (32 * delayValue),
                            height: 60 + (32 * delayValue),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFDB2777).withOpacity(0.15 * (1 - delayValue)),
                                width: 1.0,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    MouseRegion(
                      onEnter: (_) => setState(() => _isHovered = true),
                      onExit: (_) => setState(() => _isHovered = false),
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _toggleChat,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF2563EB), // Rich Royal Blue
                                Color(0xFF7C3AED), // Deep Indigo/Purple
                                Color(0xFFDB2777), // Magenta
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(_isOpen ? 18 : 30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withOpacity(_isHovered ? 0.65 : 0.4),
                                blurRadius: _isHovered ? 22 : 16,
                                spreadRadius: _isHovered ? 2 : 0,
                                offset: Offset(0, _isHovered ? 8 : 6),
                              ),
                              BoxShadow(
                                color: const Color(0xFFDB2777).withOpacity(_isHovered ? 0.35 : 0.15),
                                blurRadius: _isHovered ? 14 : 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glossy top reflection for premium 3D look
                              Positioned(
                                top: 2,
                                left: 8,
                                right: 8,
                                child: Container(
                                  height: 18,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.35),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                              // Rotating, scaling transition for icon
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return RotationTransition(
                                    turns: animation,
                                    child: ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Icon(
                                  _isOpen ? Icons.close_rounded : Icons.smart_toy_rounded,
                                  key: ValueKey<bool>(_isOpen),
                                  size: 26,
                                  color: Colors.white,
                                ),
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
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class QuickActionChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const QuickActionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<QuickActionChip> createState() => _QuickActionChipState();
}

class _QuickActionChipState extends State<QuickActionChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark ? const Color(0xFF1E293B) : Colors.grey[200])
                : (isDark ? const Color(0xFF0F172A).withOpacity(0.4) : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFF7C3AED).withOpacity(0.5)
                  : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.15)),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? const Color(0xFF7C3AED).withOpacity(0.15)
                    : Colors.black.withOpacity(0.03),
                blurRadius: _isHovered ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFFDB2777)],
                ).createShader(bounds),
                child: Icon(
                  widget.icon,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
