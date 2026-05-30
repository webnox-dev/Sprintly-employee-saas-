import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RecreatedTeamSyncScreen extends StatefulWidget {
  const RecreatedTeamSyncScreen({super.key});

  @override
  State<RecreatedTeamSyncScreen> createState() => _RecreatedTeamSyncScreenState();
}

class _RecreatedTeamSyncScreenState extends State<RecreatedTeamSyncScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedTab = 'All'; // 'All', 'Unread', 'Groups'
  String _userStatus = 'Active'; // 'Active', 'Away', 'Do Not Disturb'
  bool _showStatusDropdown = false;

  // Mock Conversations Data
  late List<Map<String, dynamic>> _conversations;
  Map<String, dynamic>? _selectedConversation;

  @override
  void initState() {
    super.initState();

    _conversations = [
      {
        'id': 'c1',
        'name': 'Vignesh D',
        'role': 'Jr. UI/UX Designer',
        'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200',
        'isImage': true,
        'initials': 'VD',
        'color': const Color(0xFF3B82F6),
        'isOnline': true,
        'date': 'Mar 9',
        'unread': 0,
        'isGroup': false,
        'messages': [
          {
            'sender': 'Vignesh D',
            'isMe': false,
            'text': "Hey! How's the dashboard design coming along?",
            'time': '10:24 AM',
          },
          {
            'sender': 'Me',
            'isMe': true,
            'text': 'Going great! Just finishing up the glassmorphism effects.',
            'time': '10:25 AM',
          },
          {
            'sender': 'Vignesh D',
            'isMe': false,
            'text': 'Awesome! Can\'t wait to see it. Need any help with the animations?',
            'time': '10:26 AM',
          },
          {
            'sender': 'Me',
            'isMe': true,
            'text': 'Thanks! I think I\'m good for now. Will ping you if I need anything.',
            'time': '10:27 AM',
          },
        ]
      },
      {
        'id': 'c2',
        'name': 'Ranjith A',
        'role': 'SEO Analyst',
        'avatar': '',
        'isImage': false,
        'initials': 'RA',
        'color': const Color(0xFFEA580C),
        'isOnline': true,
        'date': 'Mar 9',
        'unread': 2,
        'isGroup': false,
        'messages': [
          {
            'sender': 'Ranjith A',
            'isMe': false,
            'text': 'Hi, did you look at the SEO keywords for this week?',
            'time': '9:15 AM',
          },
          {
            'sender': 'Me',
            'isMe': true,
            'text': 'Yes, I will review them after lunch.',
            'time': '9:30 AM',
          },
        ]
      },
      {
        'id': 'c3',
        'name': 'Ganesh PS',
        'role': 'Flutter Intern',
        'avatar': '',
        'isImage': false,
        'initials': 'GP',
        'color': const Color(0xFFEAB308),
        'isOnline': true,
        'date': 'Mar 9',
        'unread': 0,
        'isGroup': false,
        'messages': [
          {
            'sender': 'Ganesh PS',
            'isMe': false,
            'text': 'hi bro',
            'time': 'Yesterday',
          },
          {
            'sender': 'Me',
            'isMe': true,
            'text': 'Hey! What\'s up?',
            'time': 'Yesterday',
          },
        ]
      },
      {
        'id': 'c4',
        'name': 'Tharun A',
        'role': 'Flutter Developer',
        'avatar': '',
        'isImage': false,
        'initials': 'TA',
        'color': const Color(0xFF8B5CF6),
        'isOnline': true,
        'date': 'Mar 8',
        'unread': 0,
        'isGroup': false,
        'messages': [
          {
            'sender': 'Tharun A',
            'isMe': false,
            'text': 'Can we sync on the API integration today?',
            'time': 'Yesterday',
          },
          {
            'sender': 'Me',
            'isMe': true,
            'text': 'Sure, let\'s do 4 PM.',
            'time': 'Yesterday',
          },
        ]
      },
      {
        'id': 'c5',
        'name': 'Sarah M',
        'role': 'Project Manager',
        'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=200',
        'isImage': true,
        'initials': 'SM',
        'color': const Color(0xFFEC4899),
        'isOnline': true,
        'date': 'Mar 7',
        'unread': 0,
        'isGroup': false,
        'messages': [
          {
            'sender': 'Sarah M',
            'isMe': false,
            'text': 'Please submit the timesheets by EOD.',
            'time': '2 days ago',
          },
          {
            'sender': 'Me',
            'isMe': true,
            'text': 'Done!',
            'time': '2 days ago',
          },
        ]
      },
      {
        'id': 'c6',
        'name': 'UI/UX Design Team',
        'role': 'Group Chat',
        'avatar': '',
        'isImage': false,
        'initials': 'DT',
        'color': const Color(0xFF10B981),
        'isOnline': false,
        'date': 'Mar 5',
        'unread': 0,
        'isGroup': true,
        'messages': [
          {
            'sender': 'Vignesh D',
            'isMe': false,
            'text': 'Sharing the Figma link for the new dashboard.',
            'time': '3 days ago',
          },
        ]
      }
    ];

    // Default select Vignesh D
    _selectedConversation = _conversations.first;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedConversation == null) return;

    final now = DateTime.now();
    final timeStr = DateFormat.format(now);

    setState(() {
      final messages = List<Map<String, dynamic>>.from(_selectedConversation!['messages']);
      messages.add({
        'sender': 'Me',
        'isMe': true,
        'text': text,
        'time': timeStr,
      });
      _selectedConversation!['messages'] = messages;
      
      // Move this conversation to the top
      _conversations.removeWhere((c) => c['id'] == _selectedConversation!['id']);
      _conversations.insert(0, _selectedConversation!);
    });

    _messageController.clear();

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Map<String, dynamic>> get _filteredConversations {
    return _conversations.where((c) {
      final name = c['name'].toString().toLowerCase();
      final role = c['role'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesQuery = name.contains(query) || role.contains(query);

      if (!matchesQuery) return false;

      if (_selectedTab == 'Unread') {
        return (c['unread'] as int) > 0;
      } else if (_selectedTab == 'Groups') {
        return c['isGroup'] == true;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF070B14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isWide
            ? Row(
                children: [
                  // Left Conversations Sidebar
                  SizedBox(
                    width: 320,
                    child: _buildSidebar(context),
                  ),
                  
                  // Divider
                  Container(
                    width: 1,
                    color: Colors.white.withOpacity(0.08),
                  ),

                  // Right Chat Window
                  Expanded(
                    child: _buildChatArea(context),
                  ),
                ],
              )
            : _selectedConversation == null
                ? _buildSidebar(context)
                : _buildChatArea(context),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: const Color(0xFF0D121F).withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TeamSync',
                  style: GoogleFonts.lexend(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    // Status Badge Dropdown
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showStatusDropdown = !_showStatusDropdown;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _userStatus == 'Active'
                                        ? const Color(0xFF10B981)
                                        : (_userStatus == 'Away'
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFFEF4444)),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _userStatus,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showStatusDropdown)
                          Positioned(
                            top: 36,
                            right: 0,
                            child: Container(
                              width: 140,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Column(
                                children: ['Active', 'Away', 'Do Not Disturb'].map((status) {
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _userStatus = status;
                                        _showStatusDropdown = false;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: status == 'Active'
                                                  ? const Color(0xFF10B981)
                                                  : (status == 'Away'
                                                      ? const Color(0xFFF59E0B)
                                                      : const Color(0xFFEF4444)),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            status,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // Compose Pencil Button
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Color(0xFF3B82F6),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.01),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.2), fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.4), size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tabs Row
            Row(
              children: ['All', 'Unread', 'Groups'].map((tab) {
                final isSelected = _selectedTab == tab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedTab = tab;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.08),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        tab,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Conversations List
            Expanded(
              child: ListView.builder(
                itemCount: _filteredConversations.length,
                itemBuilder: (context, index) {
                  final conv = _filteredConversations[index];
                  final isSelected = _selectedConversation != null && _selectedConversation!['id'] == conv['id'];

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedConversation = conv;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.08) : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.2) : Colors.transparent,
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withOpacity(0.03),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Stack(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: conv['isImage'] ? Colors.transparent : conv['color'].withOpacity(0.1),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF3B82F6).withOpacity(0.4)
                                        : Colors.white.withOpacity(0.08),
                                    width: 1.5,
                                  ),
                                ),
                                child: conv['isImage']
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.network(
                                          conv['avatar'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Text(
                                              conv['initials'],
                                              style: GoogleFonts.lexend(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          conv['initials'],
                                          style: GoogleFonts.lexend(
                                            color: conv['color'],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                              ),
                              if (conv['isOnline'])
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF070B14), width: 1.5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        conv['name'],
                                        style: GoogleFonts.lexend(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      conv['date'],
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.6)
                                            : Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  conv['role'],
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isSelected
                                        ? const Color(0xFF3B82F6)
                                        : Colors.white.withOpacity(0.4),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea(BuildContext context) {
    if (_selectedConversation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white.withOpacity(0.05),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Select a conversation to start syncing',
              style: GoogleFonts.lexend(
                color: Colors.white.withOpacity(0.2),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final messages = List<Map<String, dynamic>>.from(_selectedConversation!['messages']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final chatAreaWidth = constraints.maxWidth;
        final isMobileChat = chatAreaWidth <= 550;

        return Container(
          color: const Color(0xFF080D1A),
      child: Column(
        children: [
          // Chat Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F1D).withOpacity(0.5),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Row(
              children: [
                // Display back button on narrow layouts
                if (MediaQuery.of(context).size.width <= 900) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    onPressed: () {
                      setState(() {
                        _selectedConversation = null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedConversation!['isImage']
                            ? Colors.transparent
                            : _selectedConversation!['color'].withOpacity(0.1),
                        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                      ),
                      child: _selectedConversation!['isImage']
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                _selectedConversation!['avatar'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    _selectedConversation!['initials'],
                                    style: GoogleFonts.lexend(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                _selectedConversation!['initials'],
                                style: GoogleFonts.lexend(
                                  color: _selectedConversation!['color'],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                    ),
                    if (_selectedConversation!['isOnline'])
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF080D1A), width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // User Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedConversation!['name'],
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _selectedConversation!['isOnline']
                                  ? const Color(0xFF10B981)
                                  : Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedConversation!['isOnline'] ? 'Active now' : 'Offline',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _selectedConversation!['isOnline']
                                  ? const Color(0xFF10B981)
                                  : Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Header Action Icons
                Row(
                  children: [
                    if (!isMobileChat) ...[
                      _buildHeaderAction(Icons.phone_rounded),
                      const SizedBox(width: 8),
                      _buildHeaderAction(Icons.videocam_rounded),
                      const SizedBox(width: 8),
                    ],
                    _buildHeaderAction(Icons.more_vert_rounded),
                  ],
                ),
              ],
            ),
          ),

          // Messages View
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Date separator at top
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Text(
                        'Today, March 9',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                  );
                }

                final msg = messages[index - 1];
                final isMe = msg['isMe'] == true;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe) ...[
                        // Receiver Avatar
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _selectedConversation!['isImage']
                                ? Colors.transparent
                                : _selectedConversation!['color'].withOpacity(0.1),
                            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                          ),
                          child: _selectedConversation!['isImage']
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    _selectedConversation!['avatar'],
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    _selectedConversation!['initials'],
                                    style: GoogleFonts.lexend(
                                      color: _selectedConversation!['color'],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Message Bubble + Time
                      Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: chatAreaWidth * (isMobileChat ? 0.75 : 0.6),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: isMe
                                ? BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF3B82F6).withOpacity(0.85),
                                        const Color(0xFF1D4ED8).withOpacity(0.85),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(4),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.15),
                                      width: 0.8,
                                    ),
                                  )
                                : BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(4),
                                      bottomRight: Radius.circular(16),
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.05),
                                      width: 0.8,
                                    ),
                                  ),
                            child: Text(
                              msg['text'],
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            msg['time'],
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Message Input Bar
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobileChat ? 12 : 20,
              vertical: isMobileChat ? 10 : 16,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF090E1B),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Row(
              children: [
                // Attachment Clip Icon
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Attachment feature is under construction.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
                        ),
                        backgroundColor: const Color(0xFF3B82F6),
                        behavior: SnackBarBehavior.floating,
                        width: 250,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Transform.rotate(
                      angle: 0.78,
                      child: Icon(
                        Icons.attachment_rounded,
                        color: Colors.white.withOpacity(0.5),
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // TextField Input Box
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            onSubmitted: (_) => _sendMessage(),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.2), fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        // Emoji icon on right
                        IconButton(
                          icon: Icon(
                            Icons.sentiment_satisfied_alt_rounded,
                            color: Colors.white.withOpacity(0.3),
                            size: 20,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Emoji picker coming soon.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white),
                                ),
                                backgroundColor: const Color(0xFF3B82F6),
                                behavior: SnackBarBehavior.floating,
                                width: 200,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Blue Send Airplane Button
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
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

  Widget _buildHeaderAction(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white.withOpacity(0.6),
          size: 16,
        ),
      ),
    );
  }
}

// Simple DateFormat helper since intl's DateFormat is imported
class DateFormat {
  static String format(DateTime dt) {
    // Custom formatted time representation
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $period';
  }
}
