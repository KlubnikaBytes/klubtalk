// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'dart:async';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  // Streams
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _deliveryStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _seenStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _callController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get onlineStatusStream => _onlineStatusController.stream;
  Stream<Map<String, dynamic>> get deliveryStatusStream => _deliveryStatusController.stream;
  Stream<Map<String, dynamic>> get seenStatusStream => _seenStatusController.stream;
  Stream<Map<String, dynamic>> get callStream => _callController.stream;
  // Fix: Expose Status Stream
  // Fix: Expose Status Stream
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statusStream => _statusController.stream;

  // Group Updates
  final _groupUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get groupUpdateStream => _groupUpdateController.stream;

  // Connection State Stream
  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;

  IO.Socket _buildSocket(String token) {
     return IO.io(ApiConfig.baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .disableAutoConnect()
      .build()
    );
  }

  void connect() {
    final token = AuthService().token;
    if (token == null) return;

    // Singleton check: If socket exists, check status
    if (_socket != null) {
       if (_socket!.connected) {
          // Already connected, emit true just in case listeners engaged late
          _connectionStateController.add(true); 
          return;
       }
       // If disconnected, try reconnecting existing instance first or checking if we need new auth
       _socket!.connect();
       return;
    }

    _socket = _buildSocket(token);
    _setupListeners();
    _socket!.connect();
  }

  void _setupListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      print('Socket Connected: ${_socket?.id}');
      _isConnected = true;
      _connectionStateController.add(true);
      final userId = AuthService().currentUserId;
      if (userId != null) {
        _socket!.emit('join-user', userId);
      }
    });

    _socket!.onDisconnect((_) {
      print('Socket Disconnected');
      _isConnected = false;
      _connectionStateController.add(false);
    });

    _socket!.onConnectError((data) {
       print('❌ Socket Connection Error: $data');
       _isConnected = false;
       _connectionStateController.add(false);
    });

    _socket!.onError((data) {
       print('❌ Socket Error: $data');
    });

    // --- Message Events ---
    _socket!.on('new_message', (data) {
      final msg = Map<String, dynamic>.from(data);
      _messageController.add(msg);
      
      // 🎯 Auto-ACK Delivery (Global)
      // Rule: If we receive it via socket, we are "delivered".
      if (msg['_id'] != null && msg['chatId'] != null) {
          // print("SocketService: Auto-ACK delivery for msg ${msg['_id']}");
          _socket!.emit('message_received', {
             'messageId': msg['_id'],
             'chatId': msg['chatId']
          });
      }
    });

    _socket!.on('message_sent', (data) {
       if (data['message'] != null) {
          final msg = Map<String, dynamic>.from(data['message']);
          if (data['tempId'] != null) {
             msg['tempId'] = data['tempId'];
          }
          _messageController.add(msg);
       }
    });
    
    _socket!.on('message_delivered', (data) {
       _deliveryStatusController.add(Map<String, dynamic>.from(data));
    });
    
    _socket!.on('messages_seen_update', (data) {
       _seenStatusController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('typing', (data) {
      _typingController.add({'isTyping': true, ...Map<String, dynamic>.from(data)});
    });

    _socket!.on('stop_typing', (data) {
        _typingController.add({'isTyping': false, ...Map<String, dynamic>.from(data)});
    });

    _socket!.on('user_status', (data) {
       _onlineStatusController.add(Map<String, dynamic>.from(data));
    });

    // --- Status Events ---
    _socket!.on('status_uploaded', (data) {
       _statusController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('group_updated', (data) {
       print("Socket: Recreived group update: $data");
       _groupUpdateController.add(Map<String, dynamic>.from(data));
    });

    // --- Call Events ---
    _socket!.on('video_call_request', (data) => _callController.add({'event': 'video_call_request', 'data': data}));
    _socket!.on('video_call_accept', (data) => _callController.add({'event': 'video_call_accept', 'data': data}));
    _socket!.on('video_call_reject', (data) => _callController.add({'event': 'video_call_reject', 'data': data}));
    _socket!.on('video_call_end', (data) => _callController.add({'event': 'video_call_end', 'data': data}));
    _socket!.on('video_call_ice', (data) => _callController.add({'event': 'video_call_ice', 'data': data}));
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
  }

  // --- Actions ---
  void markSeen(String chatId) {
    if (_socket == null) return;
    _socket!.emit('message_seen', {'chatId': chatId});
  }

  void sendMessage(String chatId, String content, String type, {String? mediaUrl, String? thumbnailUrl, String? tempId}) {
    if (_socket == null) return;
    final senderId = AuthService().currentUserId;
    _socket!.emit('send_message', {
      'chatId': chatId,
      'senderId': senderId,
      'content': content,
      'type': type,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'tempId': tempId,
      'status': 'sent'
    });
  }

  void sendTyping(String chatId, String toUserId) {
    if (_socket == null) return;
    _socket!.emit('typing', {'chatId': chatId, 'toUserId': toUserId});
  }

  void sendStopTyping(String chatId, String toUserId) {
    if (_socket == null) return;
    _socket!.emit('stop_typing', {'chatId': chatId, 'toUserId': toUserId});
  }

  void checkOnline(String userId) {
    if (_socket == null) return;
    _socket!.emit('check_user_online', userId);
  }

  // --- Call Actions ---
  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  // --- Room Actions ---
  void joinChat(String chatId) {
    if (_socket == null) return;
    _socket!.emit('join_chat', chatId);
  }

  void leaveChat(String chatId) {
    if (_socket == null) return;
    _socket!.emit('leave_chat', chatId);
  }
}
