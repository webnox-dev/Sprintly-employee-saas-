import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import '../api/api_config.dart';

/// WebSocket events for chat
enum ChatEventType {
  connected,
  disconnected,
  newMessage,
  messageSent,
  messageStatus,
  conversationRead,
  typing,
  presence,
  messageReaction,
  messageStarred,
  messagePinned,
  messageUpdated,
  themeUpdate,
  error,
}

/// Chat event data
class ChatEvent {
  final ChatEventType type;
  final Map<String, dynamic>? data;

  ChatEvent(this.type, [this.data]);
}

/// Chat WebSocket Service for real-time messaging
class ChatWebSocketService {
  static ChatWebSocketService? _instance;
  static ChatWebSocketService get instance {
    _instance ??= ChatWebSocketService._();
    return _instance!;
  }

  ChatWebSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _intentionalDisconnect = false;
  String? _authToken;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  final _eventController = StreamController<ChatEvent>.broadcast();
  Stream<ChatEvent> get eventStream => _eventController.stream;

  bool get isConnected => _isConnected;

  /// Connect to WebSocket server
  Future<bool> connect(String token) async {
    if (_isConnected || _isConnecting) {
      print('[ChatWS] Already connected or connecting');
      return _isConnected;
    }

    _isConnecting = true;
    _intentionalDisconnect = false; // Reset on new connection attempt
    _authToken = token;

    try {
      // Get backend URL from ApiConfig
      final baseUrl = ApiConfig.baseUrl;
      final wsUrl = baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');

      // Pass token as query parameter
      final uri = Uri.parse(
        '$wsUrl/chat/ws?token=${Uri.encodeComponent(token)}',
      );

      print('[ChatWS] Connecting to $uri');

      // Connect without subprotocol (token is in query string)
      _channel = WebSocketChannel.connect(uri);

      // Listen for messages
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      // Wait for connection ack
      final completer = Completer<bool>();
      late StreamSubscription<ChatEvent> connListener;

      connListener = eventStream.listen((event) {
        if (event.type == ChatEventType.connected) {
          completer.complete(true);
          connListener.cancel();
        } else if (event.type == ChatEventType.error) {
          completer.complete(false);
          connListener.cancel();
        }
      });

      // Timeout after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete(false);
          connListener.cancel();
        }
      });

      _isConnected = await completer.future;
      _isConnecting = false;

      if (_isConnected) {
        _reconnectAttempts = 0;
        _startPingTimer();
        print('[ChatWS] Connected successfully');
      }

      return _isConnected;
    } catch (e) {
      print('[ChatWS] Connection error: $e');
      _isConnecting = false;
      _isConnected = false;
      return false;
    }
  }

  /// Disconnect from WebSocket
  void disconnect() {
    print('[ChatWS] Disconnecting...');
    _intentionalDisconnect =
        true; // Mark as intentional to prevent auto-reconnect
    _stopPingTimer();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close(ws_status.normalClosure);
    _isConnected = false;
    _isConnecting = false;
    _channel = null;
  }

  /// Send a message
  void sendMessage({
    required String conversationId,
    required String messageType,
    String? content,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? fileMimeType,
    String? thumbnailUrl,
    String? replyToId,
    String? forwardedFromId,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    String? tempId,
  }) {
    _send({
      'type': 'send_message',
      'conversationId': conversationId,
      'messageType': messageType,
      'content': content,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileMimeType': fileMimeType,
      'thumbnailUrl': thumbnailUrl,
      'replyToId': replyToId,
      'forwardedFromId': forwardedFromId,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'tempId': tempId,
    });
  }

  /// Edit a message
  void editMessage(String messageId, String content, String conversationId) {
    _send({
      'type': 'edit_message',
      'messageId': messageId,
      'content': content,
      'conversationId': conversationId,
    });
  }

  /// Start typing indicator
  void startTyping(String conversationId) {
    _send({'type': 'typing_start', 'conversationId': conversationId});
  }

  /// Stop typing indicator
  void stopTyping() {
    _send({'type': 'typing_stop'});
  }

  /// Mark message as delivered
  void markAsDelivered(String messageId) {
    _send({'type': 'message_delivered', 'messageId': messageId});
  }

  /// Mark message as read
  void markAsRead(String messageId) {
    _send({'type': 'message_read', 'messageId': messageId});
  }

  /// Mark conversation as read
  void markConversationAsRead(String conversationId) {
    _send({'type': 'conversation_read', 'conversationId': conversationId});
  }

  /// Subscribe to conversation
  void subscribeToConversation(String conversationId) {
    _send({'type': 'subscribe_conversation', 'conversationId': conversationId});
  }

  /// Unsubscribe from conversation
  void unsubscribeFromConversation(String conversationId) {
    _send({
      'type': 'unsubscribe_conversation',
      'conversationId': conversationId,
    });
  }

  /// Update user presence/status
  void updatePresence(String status) {
    _send({'type': 'update_presence', 'status': status});
  }

  /// Update conversation theme
  void updateTheme(String conversationId, String themeId) {
    _send({
      'type': 'theme_update',
      'conversationId': conversationId,
      'themeId': themeId,
    });
  }

  /// Send data through WebSocket
  void _send(Map<String, dynamic> data) {
    if (!_isConnected || _channel == null) {
      print('[ChatWS] Cannot send - not connected');
      return;
    }

    try {
      _channel!.sink.add(jsonEncode(data));
    } catch (e) {
      print('[ChatWS] Send error: $e');
    }
  }

  /// Handle incoming message
  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'connected':
          _isConnected = true;
          _eventController.add(ChatEvent(ChatEventType.connected, message));
          break;
        case 'new_message':
          _eventController.add(ChatEvent(ChatEventType.newMessage, message));
          break;
        case 'message_sent':
          _eventController.add(ChatEvent(ChatEventType.messageSent, message));
          break;
        case 'message_status':
          _eventController.add(ChatEvent(ChatEventType.messageStatus, message));
          break;
        case 'typing':
          _eventController.add(ChatEvent(ChatEventType.typing, message));
          break;
        case 'presence':
          _eventController.add(ChatEvent(ChatEventType.presence, message));
          break;
        case 'pong':
          // Heartbeat response - do nothing
          break;
        case 'conversation_read':
          _eventController
              .add(ChatEvent(ChatEventType.conversationRead, message));
          break;
        case 'message_reaction':
          _eventController
              .add(ChatEvent(ChatEventType.messageReaction, message));
          break;
        case 'message_starred':
          _eventController
              .add(ChatEvent(ChatEventType.messageStarred, message));
          break;
        case 'message_pinned':
          _eventController.add(ChatEvent(ChatEventType.messagePinned, message));
          break;
        case 'message_updated':
          _eventController
              .add(ChatEvent(ChatEventType.messageUpdated, message));
          break;
        case 'theme_update':
          _eventController.add(ChatEvent(ChatEventType.themeUpdate, message));
          break;
        case 'error':
          _eventController.add(ChatEvent(ChatEventType.error, message));
          break;
        default:
          print('[ChatWS] Unknown message type: $type');
      }
    } catch (e) {
      print('[ChatWS] Message parse error: $e');
    }
  }

  /// Handle WebSocket error
  void _handleError(dynamic error) {
    print('[ChatWS] Stream error: $error');
    _eventController.add(
      ChatEvent(ChatEventType.error, {'message': error.toString()}),
    );
    _scheduleReconnect();
  }

  /// Handle WebSocket close
  void _handleDone() {
    print('[ChatWS] Connection closed');
    _isConnected = false;
    _eventController.add(ChatEvent(ChatEventType.disconnected));

    // Don't reconnect if the disconnect was intentional
    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  /// Start ping timer to keep connection alive
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        _send({'type': 'ping'});
      }
    });
  }

  /// Stop ping timer
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Schedule reconnection
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('[ChatWS] Max reconnect attempts reached');
      return;
    }

    if (_authToken == null) return;

    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (2 << _reconnectAttempts).clamp(2, 30));

    print('[ChatWS] Scheduling reconnect in ${delay.inSeconds}s');

    _reconnectTimer = Timer(delay, () async {
      _reconnectAttempts++;
      _isConnected = false;
      _isConnecting = false;
      await connect(_authToken!);
    });
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _eventController.close();
  }
}
