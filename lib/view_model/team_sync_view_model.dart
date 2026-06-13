import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../model/team_sync_message.dart';
import '../model/team_sync_conversation.dart';
import '../services/chat_repository.dart';
import '../services/chat_websocket_service.dart';
import '../services/file_upload_service.dart';

/// ViewModel for TeamSync chat using WebSocket
/// Uses ChangeNotifier for Provider compatibility
class TeamSyncViewModel extends ChangeNotifier {
  final ChatRepository _repository;
  final ChatWebSocketService _wsService = ChatWebSocketService.instance;
  final FileUploadService _fileUploadService = FileUploadService();
  final _uuid = const Uuid();

  String? _token;
  String? _currentUserId;
  String? _currentUserType;
  String? _currentUserName;
  String? _currentUserImage;

  StreamSubscription? _wsSubscription;

  // Typing indicator state: conversationId -> {userId_userType: userName}
  final Map<String, Map<String, String>> _typingUsers = {};
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();

  // Stream for new messages to update the chat area in real-time
  final _newMessageController = StreamController<TeamSyncMessage>.broadcast();

  // Stream for message status updates (delivered/read) so UI can update icons in real-time
  final _messageStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream for message reaction updates
  final _messageReactionController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream for message starred updates
  final _messageStarredController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream for message pinned updates
  final _messagePinnedController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream for message updated (edited) events
  final _messageUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream for theme updates: {conversationId, themeId}
  final _themeUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream for chess multiplayer events
  final _chessEventController = StreamController<ChatEvent>.broadcast();

  // State
  bool _isLoading = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  bool _isInitialized = false;
  String? _error;
  List<TeamSyncConversation> _conversations = [];
  List<TeamSyncUser> _chatUsers = [];
  bool _isConnected = false;

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSending => _isSending;
  String? get error => _error;
  List<TeamSyncConversation> get conversations => _conversations;
  List<TeamSyncUser> get chatUsers => _chatUsers;
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  String? get currentUserId => _currentUserId;
  String? get currentUserType => _currentUserType;

  /// Stream of typing events for UI to listen to
  Stream<Map<String, dynamic>> get typingEventsStream =>
      _typingController.stream;

  /// Stream of new messages for UI to add to chat area
  Stream<TeamSyncMessage> get newMessagesStream => _newMessageController.stream;

  /// Stream of message status updates: {messageId, status ('delivered'|'read')}
  /// UI should subscribe and update the matching message's status in the list.
  Stream<Map<String, dynamic>> get messageStatusUpdatesStream =>
      _messageStatusController.stream;

  /// Stream of message reaction updates
  Stream<Map<String, dynamic>> get messageReactionStream =>
      _messageReactionController.stream;

  /// Stream of message starred updates
  Stream<Map<String, dynamic>> get messageStarredStream =>
      _messageStarredController.stream;

  /// Stream of message pinned updates
  Stream<Map<String, dynamic>> get messagePinnedStream =>
      _messagePinnedController.stream;

  /// Stream of message updated (edited) events
  Stream<Map<String, dynamic>> get messageUpdatedStream =>
      _messageUpdatedController.stream;

  /// Stream of theme updates: {conversationId, themeId}
  Stream<Map<String, dynamic>> get themeUpdateStream =>
      _themeUpdateController.stream;

  /// Stream of chess multiplayer events
  Stream<ChatEvent> get chessEventsStream => _chessEventController.stream;

  /// Get typing users for a specific conversation
  Map<String, String> getTypingUsers(String conversationId) {
    return Map.unmodifiable(_typingUsers[conversationId] ?? {});
  }

  /// Total unread count across all conversations
  int get totalUnreadCount =>
      _conversations.fold<int>(0, (sum, conv) => sum + conv.unreadCount);

  TeamSyncViewModel({ChatRepository? repository})
      : _repository = repository ?? ChatRepository();

  /// Check if a message was sent by the current user
  bool isMe(String? senderId, String? senderType) {
    if (senderId == null || senderType == null) return false;
    if (_currentUserId == null || _currentUserType == null) return false;

    final normalizedSenderId = senderId.trim().toLowerCase();
    final normalizedCurrentId = _currentUserId!.trim().toLowerCase();

    if (normalizedSenderId != normalizedCurrentId) return false;

    final normalizedSenderType = senderType.trim().toLowerCase();
    final normalizedCurrentUserType = _currentUserType!.trim().toLowerCase();

    if (normalizedSenderType == normalizedCurrentUserType) return true;

    // Relaxed match for Employee roles
    if (normalizedSenderType.contains('employee') &&
        normalizedCurrentUserType.contains('employee')) {
      return true;
    }

    // UUID match safeguard
    if (normalizedSenderId.length > 10 && normalizedCurrentId.length > 10) {
      return true;
    }

    return false;
  }

  /// Initialize with auth token and user info
  Future<void> initialize({
    required String token,
    required String userId,
    required String userType,
    String? userName,
    String? userImage,
  }) async {
    _token = token;
    _currentUserId = userId;
    _currentUserType = userType;
    _currentUserName = userName;
    _currentUserImage = userImage;

    // Prevent duplicate connection if already initialized
    if (_isInitialized && _wsService.isConnected) {
      print('[TeamSyncVM] Already initialized, user info updated');
      notifyListeners();
      return;
    }

    // Connect to WebSocket
    await connect();

    // Load initial data
    await Future.wait([
      loadChatUsers(),
      loadConversations(),
    ]);

    _isInitialized = true;
  }

  // ============================================
  // WEBSOCKET CONNECTION
  // ============================================

  /// Connect to WebSocket
  Future<void> connect() async {
    if (_token == null) return;

    _wsSubscription?.cancel();
    _wsSubscription = _wsService.eventStream.listen(_handleWebSocketEvent);

    final connected = await _wsService.connect(_token!);
    _isConnected = connected;
    notifyListeners();
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _wsSubscription?.cancel();
    _wsService.disconnect();
    _isConnected = false;
    notifyListeners();
  }

  /// Handle WebSocket events
  void _handleWebSocketEvent(ChatEvent event) {
    switch (event.type) {
      case ChatEventType.connected:
        _isConnected = true;
        notifyListeners();
        break;

      case ChatEventType.disconnected:
        _isConnected = false;
        notifyListeners();
        break;

      case ChatEventType.newMessage:
        _handleNewMessage(event.data);
        break;

      case ChatEventType.messageSent:
        _handleMessageSent(event.data);
        break;

      case ChatEventType.messageStatus:
        _handleMessageStatus(event.data);
        break;

      case ChatEventType.typing:
        _handleTypingEvent(event.data);
        break;

      case ChatEventType.presence:
        _handlePresenceEvent(event.data);
        break;
      case ChatEventType.conversationRead:
        _handleConversationRead(event.data);
        break;
      case ChatEventType.messageReaction:
        _handleMessageReaction(event.data);
        break;
      case ChatEventType.messageStarred:
        _handleMessageStarred(event.data);
        break;
      case ChatEventType.messagePinned:
        _handleMessagePinned(event.data);
        break;
      case ChatEventType.messageUpdated:
        _handleMessageUpdated(event.data);
        break;
      case ChatEventType.themeUpdate:
        _handleThemeUpdate(event.data);
        break;
      case ChatEventType.chessChallengeReceived:
      case ChatEventType.chessGameStarted:
      case ChatEventType.chessChallengeDeclined:
      case ChatEventType.chessMoveReceived:
      case ChatEventType.chessGameOverReceived:
        _chessEventController.add(event);
        break;
      case ChatEventType.error:
        print('[TeamSyncVM] WebSocket error: ${event.data}');
        break;
    }
  }

  // ============================================
  // CONVERSATIONS
  // ============================================

  /// Load all conversations
  Future<void> loadConversations() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final data = await _repository.getConversations();
      var convList = data.map((e) => TeamSyncConversation.fromJson(e)).toList();

      // Enrich conversations with user info
      if (_chatUsers.isNotEmpty) {
        convList = convList.map((conv) {
          if (conv.isDirectMessage &&
              (conv.displayName == null || conv.displayName == 'Unknown')) {
            final otherUserId = conv.otherUserId;
            final otherUserType = conv.otherUserType;
            if (otherUserId != null && otherUserType != null) {
              final user = _chatUsers.firstWhere(
                (u) =>
                    u.id == otherUserId &&
                    u.userType.toLowerCase() == otherUserType.toLowerCase(),
                orElse: () =>
                    TeamSyncUser(id: '', userType: '', name: 'Unknown'),
              );
              if (user.name != 'Unknown') {
                return conv.copyWith(
                  displayName: user.name,
                  displayImage: user.image,
                  otherUserDesignation: user.designation,
                  otherUserOnline: user.isOnline,
                );
              }
            }
            // Try from participants
            for (final p in conv.participants) {
              if (p.userId != _currentUserId ||
                  p.userType != _currentUserType) {
                if (p.userName != null && p.userName!.isNotEmpty) {
                  return conv.copyWith(
                    displayName: p.userName,
                    displayImage: p.userImage,
                    otherUserId: p.userId,
                    otherUserType: p.userType,
                    otherUserDesignation: p.userDesignation,
                    otherUserOnline: p.isOnline,
                  );
                }
              }
            }
          }

          // Auto-pin self chat
          final isSelfChat = conv.participants.length == 1 &&
              conv.participants.first.userId == _currentUserId &&
              conv.participants.first.userType == _currentUserType;

          if (isSelfChat) {
            return conv.copyWith(isPinned: true);
          }

          return conv;
        }).toList();
      }

      // Sort: pinned first, then by last message time
      convList.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      _conversations = convList;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('[TeamSyncVM] Error loading conversations: $e');
      _error = 'Failed to load conversations';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      final success = await _repository.deleteConversation(conversationId);
      if (success) {
        _conversations =
            _conversations.where((c) => c.id != conversationId).toList();
        notifyListeners();
      }
    } catch (e) {
      print('[TeamSyncVM] Error deleting conversation: $e');
      rethrow;
    }
  }

  /// Pin a conversation
  void pinConversation(String conversationId) {
    final updatedConversations = _conversations.map((c) {
      if (c.id == conversationId) {
        return c.copyWith(isPinned: true);
      }
      return c;
    }).toList();

    updatedConversations.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    _conversations = updatedConversations;
    notifyListeners();
  }

  /// Unpin a conversation
  void unpinConversation(String conversationId) {
    final updatedConversations = _conversations.map((c) {
      if (c.id == conversationId) {
        return c.copyWith(isPinned: false);
      }
      return c;
    }).toList();

    updatedConversations.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    _conversations = updatedConversations;
    notifyListeners();
  }

  /// Create or get existing conversation
  Future<TeamSyncConversation?> getOrCreateConversation({
    required String userId,
    required String userType,
  }) async {
    try {
      final data = await _repository.getOrCreateDirectConversation(
        userId: userId,
        userType: userType,
      );

      if (data != null) {
        var conversation = TeamSyncConversation.fromJson(data);

        // Enrich with user info
        if (conversation.displayName == null ||
            conversation.displayName == 'Unknown') {
          final user = _chatUsers.firstWhere(
            (u) =>
                u.id == userId &&
                u.userType.toLowerCase() == userType.toLowerCase(),
            orElse: () =>
                TeamSyncUser(id: userId, userType: userType, name: 'Unknown'),
          );

          conversation = conversation.copyWith(
            displayName: user.name,
            displayImage: user.image,
            otherUserId: userId,
            otherUserType: userType,
            otherUserDesignation: user.designation,
            otherUserOnline: user.isOnline,
          );
        }

        // Add to conversations list if not exists
        final existingIndex = _conversations.indexWhere(
          (c) => c.id == conversation.id,
        );
        if (existingIndex == -1) {
          _conversations = [conversation, ..._conversations];
        } else {
          final updatedConversations = List<TeamSyncConversation>.from(
            _conversations,
          );
          updatedConversations[existingIndex] = conversation;
          _conversations = updatedConversations;
        }

        notifyListeners();
        return conversation;
      }

      return null;
    } catch (e) {
      print('[TeamSyncVM] Error creating conversation: $e');
      return null;
    }
  }

  /// Create a group conversation
  Future<TeamSyncConversation?> createGroupConversation({
    required String name,
    String? description,
    String? avatarUrl,
    required List<Map<String, String>> participants,
    bool isPublic = false,
  }) async {
    try {
      final data = await _repository.createConversation(
        type: 'group',
        name: name,
        description: description,
        avatarUrl: avatarUrl,
        participants: participants,
        isPublic: isPublic,
      );

      if (data != null) {
        final conversation = TeamSyncConversation.fromJson(data);
        _conversations = [conversation, ..._conversations];
        notifyListeners();
        return conversation;
      }

      return null;
    } catch (e) {
      print('[TeamSyncVM] Error creating group: $e');
      return null;
    }
  }

  // ============================================
  // MESSAGES
  // ============================================

  /// Load messages for a conversation
  Future<List<TeamSyncMessage>> loadMessages(
    String conversationId, {
    int limit = 20,
  }) async {
    try {
      _isLoadingMessages = true;
      notifyListeners();

      final data = await _repository.getMessages(conversationId, limit: limit);
      final messages = data.map((e) => TeamSyncMessage.fromJson(e)).toList();

      _isLoadingMessages = false;
      notifyListeners();

      // Subscribe to conversation for real-time updates
      _wsService.subscribeToConversation(conversationId);

      return messages;
    } catch (e) {
      print('[TeamSyncVM] Error loading messages: $e');
      _isLoadingMessages = false;
      notifyListeners();
      return [];
    }
  }

  /// Load more messages (pagination)
  Future<List<TeamSyncMessage>> loadMoreMessages(
    String conversationId,
    String beforeMessageId,
  ) async {
    try {
      final data = await _repository.getMessages(
        conversationId,
        beforeMessageId: beforeMessageId,
      );
      return data.map((e) => TeamSyncMessage.fromJson(e)).toList();
    } catch (e) {
      print('[TeamSyncVM] Error loading more messages: $e');
      return [];
    }
  }

  /// Send a text message
  Future<TeamSyncMessage?> sendTextMessage(
    String conversationId,
    String content, {
    String? replyToId,
    String? forwardedFromId,
  }) async {
    final tempId = _uuid.v4();

    // Create optimistic message
    final optimisticMessage = TeamSyncMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: _currentUserId ?? '',
      senderType: _currentUserType ?? 'Employee',
      senderName: _currentUserName ?? 'You',
      senderImage: _currentUserImage,
      messageType: 'text',
      content: content,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      tempId: tempId,
      replyToId: replyToId,
    );

    // Try WebSocket first, fallback to REST API
    if (_wsService.isConnected) {
      _wsService.sendMessage(
        conversationId: conversationId,
        messageType: 'text',
        content: content,
        replyToId: replyToId,
        forwardedFromId: forwardedFromId,
        tempId: tempId,
      );
    } else {
      print('[TeamSyncVM] WebSocket not connected, using REST API');
      try {
        final response = await _repository.sendMessage(
          conversationId: conversationId,
          messageType: 'text',
          content: content,
          replyToId: replyToId,
        );

        if (response != null) {
          final confirmedMessage = TeamSyncMessage.fromJson(response);
          _updateConversationWithMessage(confirmedMessage);
          return confirmedMessage.copyWith(status: MessageStatus.sent);
        }
      } catch (e) {
        print('[TeamSyncVM] Failed to send message via REST: $e');
        return optimisticMessage.copyWith(status: MessageStatus.failed);
      }
    }

    return optimisticMessage;
  }

  /// Update conversation list when a message is sent
  void _updateConversationWithMessage(TeamSyncMessage message) {
    final updatedConversations = _conversations.map((c) {
      if (c.id == message.conversationId) {
        return c.copyWith(
          lastMessage: message,
          lastMessageAt: message.createdAt,
        );
      }
      return c;
    }).toList();

    updatedConversations.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    _conversations = updatedConversations;
    notifyListeners();
  }

  /// Send a file message
  Future<TeamSyncMessage?> sendFileMessage(
    String conversationId, {
    required String fileUrl,
    required String fileName,
    required int fileSize,
    required String messageType,
    String? fileMimeType,
    String? thumbnailUrl,
    String? content,
  }) async {
    final tempId = _uuid.v4();

    final optimisticMessage = TeamSyncMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: _currentUserId ?? '',
      senderType: _currentUserType ?? 'Employee',
      senderName: _currentUserName ?? 'You',
      senderImage: _currentUserImage,
      messageType: messageType,
      content: content,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      fileMimeType: fileMimeType,
      thumbnailUrl: thumbnailUrl,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      tempId: tempId,
    );

    _wsService.sendMessage(
      conversationId: conversationId,
      messageType: messageType,
      content: content,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      fileMimeType: fileMimeType,
      thumbnailUrl: thumbnailUrl,
      tempId: tempId,
    );

    return optimisticMessage;
  }

  /// Upload a file and return the URL
  Future<Map<String, dynamic>?> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      final url = await _fileUploadService.uploadFile(
        bytes: fileBytes,
        fileName: fileName,
        fileType: mimeType ?? 'application/octet-stream',
      );

      if (url != null) {
        return {
          'url': url,
          'fileName': fileName,
          'fileSize': fileBytes.length,
        };
      }
      return null;
    } catch (e) {
      print('[TeamSyncVM] Error uploading file: $e');
      return null;
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      await _repository.deleteMessage(conversationId, messageId);
    } catch (e) {
      print('[TeamSyncVM] Error deleting message: $e');
      rethrow;
    }
  }

  /// Send a contact message
  Future<TeamSyncMessage?> sendContactMessage(
    String conversationId, {
    required String contactName,
    String? contactPhone,
    String? contactEmail,
  }) async {
    final tempId = _uuid.v4();

    final optimisticMessage = TeamSyncMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: _currentUserId ?? '',
      senderType: _currentUserType ?? 'Employee',
      senderName: _currentUserName ?? 'You',
      senderImage: _currentUserImage,
      messageType: 'contact',
      contactName: contactName,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      tempId: tempId,
    );

    _wsService.sendMessage(
      conversationId: conversationId,
      messageType: 'contact',
      contactName: contactName,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      tempId: tempId,
    );

    return optimisticMessage;
  }

  /// Edit a message
  void editMessage(String messageId, String content, String conversationId) {
    _wsService.editMessage(messageId, content, conversationId);
  }

  /// Forward a message
  Future<void> forwardMessage(
      String messageId, List<String> targetUserIds) async {
    await _repository.forwardMessage(messageId, targetUserIds);
  }

  /// Pin message in conversation
  Future<void> pinMessage(String conversationId, String messageId) async {
    try {
      await _repository.pinMessage(conversationId, messageId);
    } catch (e) {
      print('[TeamSyncVM] Error pinning message: $e');
      rethrow;
    }
  }

  /// Unpin message in conversation
  Future<void> unpinMessage(String conversationId) async {
    try {
      await _repository.unpinMessage(conversationId);
    } catch (e) {
      print('[TeamSyncVM] Error unpinning message: $e');
      rethrow;
    }
  }

  /// Star message
  Future<void> starMessage(String messageId) async {
    try {
      await _repository.starMessage(messageId);
    } catch (e) {
      print('[TeamSyncVM] Error starring message: $e');
      rethrow;
    }
  }

  /// Unstar message
  Future<void> unstarMessage(String messageId) async {
    try {
      await _repository.unstarMessage(messageId);
    } catch (e) {
      print('[TeamSyncVM] Error unstarring message: $e');
      rethrow;
    }
  }

  /// Update user status (Active/Away/In Break/In Meeting/In Lunch)
  Future<void> updateUserStatus(String status) async {
    try {
      _wsService.updatePresence(status);
    } catch (e) {
      print('[TeamSyncVM] Error updating status: $e');
    }
  }

  /// Update conversation last message (for optimistic UI)
  void updateConversationLastMessage(TeamSyncMessage message) {
    _updateConversationWithMessage(message);
  }

  /// Get public groups
  Future<List<TeamSyncConversation>> getPublicGroups() async {
    try {
      final data = await _repository.getPublicGroups();
      return data.map((json) => TeamSyncConversation.fromJson(json)).toList();
    } catch (e) {
      print('[TeamSyncVM] Error getting public groups: $e');
      return [];
    }
  }

  /// Join a group via invite code
  Future<TeamSyncConversation?> joinGroupByInviteCode(String inviteCode) async {
    try {
      final data = await _repository.joinGroupByInviteCode(inviteCode);
      if (data != null) {
        final conversation = TeamSyncConversation.fromJson(data);
        _conversations = [conversation, ..._conversations];
        notifyListeners();
        return conversation;
      }
      return null;
    } catch (e) {
      print('[TeamSyncVM] Error joining group: $e');
      return null;
    }
  }

  /// Add a reaction to a message
  Future<bool> addReaction(String messageId, String reaction) async {
    try {
      final success = await _repository.addReaction(messageId, reaction);
      return success;
    } catch (e) {
      print('[TeamSyncVM] Error adding reaction: $e');
      return false;
    }
  }

  /// Remove a reaction from a message
  Future<bool> removeReaction(String messageId, String reaction) async {
    try {
      final success = await _repository.removeReaction(messageId, reaction);
      return success;
    } catch (e) {
      print('[TeamSyncVM] Error removing reaction: $e');
      return false;
    }
  }

  // ============================================
  // TYPING & READ STATUS
  // ============================================

  /// Start typing indicator
  void startTyping(String conversationId) {
    _wsService.startTyping(conversationId);
  }

  /// Stop typing indicator
  void stopTyping() {
    _wsService.stopTyping();
  }

  /// Mark message as read
  void markMessageAsRead(String messageId) {
    _wsService.markAsRead(messageId);
  }

  /// Mark conversation as read
  void markConversationAsRead(String conversationId) {
    _wsService.markConversationAsRead(conversationId);

    // Update conversation in state
    final updatedConversations = _conversations.map((c) {
      if (c.id == conversationId) {
        return c.copyWith(unreadCount: 0);
      }
      return c;
    }).toList();

    _conversations = updatedConversations;
    notifyListeners();
  }

  /// Update conversation theme (sends to peer)
  void updateTheme(String conversationId, String themeId) {
    if (_wsService.isConnected) {
      _wsService.updateTheme(conversationId, themeId);
    }
  }

  void _handleThemeUpdate(Map<String, dynamic>? data) {
    if (data == null) return;
    final conversationId = data['conversationId']?.toString();
    final themeId = data['themeId']?.toString();

    if (conversationId != null && themeId != null) {
      _themeUpdateController
          .add({'conversationId': conversationId, 'themeId': themeId});
    }
  }

  // ============================================
  // USERS LIST
  // ============================================

  /// Load chat users
  Future<void> loadChatUsers() async {
    try {
      print('[TeamSyncVM] Loading chat users...');
      final data = await _repository.getChatUsers();
      print('[TeamSyncVM] Received ${data.length} users from API');
      final users = data.map((e) => TeamSyncUser.fromJson(e)).toList();
      print('[TeamSyncVM] Parsed ${users.length} TeamSyncUser objects');
      _chatUsers = users;
      notifyListeners();
    } catch (e) {
      print('[TeamSyncVM] Error loading chat users: $e');
    }
  }

  // ============================================
  // WEBSOCKET EVENT HANDLERS
  // ============================================

  void _handleNewMessage(Map<String, dynamic>? data) {
    if (data == null) return;

    final messageData = data['message'];
    if (messageData != null) {
      var message = TeamSyncMessage.fromJson(
        messageData as Map<String, dynamic>,
      );

      // Enrich sender info
      message = _enrichMessageWithSenderInfo(message);

      final convId =
          data['conversationId']?.toString() ?? message.conversationId;

      // Update conversation's last message
      _updateConversationWithMessage(message);

      // Emit the new message for the chat area to update
      _newMessageController.add(message);

      // Increment unread count if not from current user
      if (message.senderId != _currentUserId ||
          message.senderType != _currentUserType) {
        final updatedConversations = _conversations.map((c) {
          if (c.id == convId) {
            return c.copyWith(unreadCount: c.unreadCount + 1);
          }
          return c;
        }).toList();
        _conversations = updatedConversations;
        notifyListeners();
      }
    }
  }

  void _handleMessageSent(Map<String, dynamic>? data) {
    if (data == null) return;

    final messageData = data['message'];
    if (messageData != null) {
      var confirmedMessage = TeamSyncMessage.fromJson(
        messageData as Map<String, dynamic>,
      );
      confirmedMessage = _enrichMessageWithSenderInfo(confirmedMessage);
      _updateConversationWithMessage(confirmedMessage);

      // Emit status update so the UI updates the optimistic message
      // from sending (clock icon) to sent (single check)
      final tempId = data['tempId']?.toString();
      final messageId = confirmedMessage.id;

      // Update by tempId (optimistic message) or by actual messageId
      if (tempId != null && tempId.isNotEmpty) {
        _messageStatusController.add(
            {'messageId': tempId, 'status': 'sent', 'confirmedId': messageId});
      }
      _messageStatusController.add({'messageId': messageId, 'status': 'sent'});
    }
  }

  void _handleMessageStatus(Map<String, dynamic>? data) {
    if (data == null) return;
    final messageId = data['messageId']?.toString();
    final status = data['status']?.toString();
    if (messageId != null && status != null) {
      _messageStatusController.add({'messageId': messageId, 'status': status});
    }
    notifyListeners();
  }

  void _handleTypingEvent(Map<String, dynamic>? data) {
    if (data == null) return;

    final userId = data['userId']?.toString();
    final userType = data['userType']?.toString();
    final conversationId = data['conversationId']?.toString();
    final isTyping = data['isTyping'] == true;

    if (userId == null || conversationId == null) return;

    // Skip if it's the current user
    if (userId == _currentUserId && userType == _currentUserType) return;

    final userKey = '${userId}_$userType';

    if (isTyping) {
      // Find user name from chat users
      String userName = 'Someone';
      final user = _chatUsers.firstWhere(
        (u) =>
            u.id == userId &&
            u.userType.toLowerCase() == userType?.toLowerCase(),
        orElse: () => TeamSyncUser(id: '', userType: '', name: 'Someone'),
      );
      if (user.name.isNotEmpty && user.name != 'Someone') {
        userName = user.name;
      }

      // Add to typing users
      _typingUsers.putIfAbsent(conversationId, () => {});
      _typingUsers[conversationId]![userKey] = userName;
    } else {
      // Remove from typing users
      _typingUsers[conversationId]?.remove(userKey);
      if (_typingUsers[conversationId]?.isEmpty ?? false) {
        _typingUsers.remove(conversationId);
      }
    }

    // Emit typing event for UI to update
    _typingController.add({
      'conversationId': conversationId,
      'userId': userId,
      'userType': userType,
      'isTyping': isTyping,
      'typingUsers':
          Map<String, String>.from(_typingUsers[conversationId] ?? {}),
    });

    notifyListeners();
  }

  void _handlePresenceEvent(Map<String, dynamic>? data) {
    if (data == null) return;

    final userId = data['userId']?.toString();
    final userType = data['userType']?.toString();
    final isOnline = data['isOnline'] == true;

    if (userId != null) {
      // Update user in chat users list
      _chatUsers = _chatUsers.map((u) {
        if (u.id == userId && u.userType == userType) {
          return TeamSyncUser(
            id: u.id,
            userType: u.userType,
            name: u.name,
            image: u.image,
            designation: u.designation,
            role: u.role,
            isOnline: isOnline,
            lastSeenAt: isOnline ? null : DateTime.now(),
          );
        }
        return u;
      }).toList();

      // Update conversations
      _conversations = _conversations.map((c) {
        if (c.otherUserId == userId && c.otherUserType == userType) {
          return c.copyWith(otherUserOnline: isOnline);
        }
        return c;
      }).toList();

      notifyListeners();
    }
  }

  void _handleConversationRead(Map<String, dynamic>? data) {
    if (data == null) return;

    final conversationId = data['conversationId']?.toString();
    if (conversationId == null) return;

    final updatedConversations = _conversations.map((c) {
      if (c.id == conversationId) {
        return c.copyWith(unreadCount: 0);
      }
      return c;
    }).toList();

    _conversations = updatedConversations;
    notifyListeners();
  }

  void _handleMessageReaction(Map<String, dynamic>? data) {
    if (data == null) return;
    _messageReactionController.add(data);
  }

  void _handleMessageStarred(Map<String, dynamic>? data) {
    if (data == null) return;
    _messageStarredController.add(data);
  }

  void _handleMessagePinned(Map<String, dynamic>? data) {
    if (data == null) return;
    _messagePinnedController.add(data);
  }

  void _handleMessageUpdated(Map<String, dynamic>? data) {
    if (data == null) return;

    final messageData = data['message'];
    if (messageData == null) {
      _messageUpdatedController.add(data);
      return;
    }

    var message = TeamSyncMessage.fromJson(messageData as Map<String, dynamic>);
    message = _enrichMessageWithSenderInfo(message);

    // Update conversation last message if it matches
    final updatedConversations = _conversations.map((c) {
      if (c.id == message.conversationId) {
        if (c.lastMessage?.id == message.id) {
          return c.copyWith(lastMessage: message);
        }
      }
      return c;
    }).toList();

    _conversations = updatedConversations;
    _messageUpdatedController.add(data);
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Enrich message with sender info if missing
  TeamSyncMessage _enrichMessageWithSenderInfo(TeamSyncMessage message) {
    // If it's from current user
    if (message.senderId == _currentUserId &&
        message.senderType == _currentUserType) {
      return message.copyWith(
        senderName: message.senderName ?? _currentUserName ?? 'You',
        senderImage: message.senderImage ?? _currentUserImage,
      );
    }

    // Otherwise find user from chat users
    final user = _chatUsers.firstWhere(
      (u) =>
          u.id == message.senderId &&
          u.userType.toLowerCase() == message.senderType.toLowerCase(),
      orElse: () => TeamSyncUser(id: '', userType: '', name: 'Unknown'),
    );

    if (user.name != 'Unknown') {
      return message.copyWith(
        senderName: message.senderName ?? user.name,
        senderImage: message.senderImage ?? user.image,
      );
    }

    return message;
  }

  @override
  void dispose() {
    disconnect();
    _typingController.close();
    _newMessageController.close();
    _messageStatusController.close();
    _messageReactionController.close();
    _messageStarredController.close();
    _messagePinnedController.close();
    _messageUpdatedController.close();
    _themeUpdateController.close();
    _chessEventController.close();
    super.dispose();
  }
}
