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

  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;

  void connect() {
    final token = AuthService().token;
    if (token == null) return;

    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(ApiConfig.baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .disableAutoConnect()
      .build()
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Socket Connected: ${_socket!.id}');
      _isConnected = true;
      final userId = AuthService().currentUserId;
      if (userId != null) {
        _socket!.emit('join-user', userId); // Join own room for calls/private events
      }
    });

    _socket!.onDisconnect((_) {
      print('Socket Disconnected');
      _isConnected = false;
    });

    _socket!.onConnectError((data) {
       print('❌ Socket Connection Error: $data');
       _isConnected = false;
    });

    _socket!.onError((data) {
       print('❌ Socket Error: $data');
    });

    // --- Message Events ---
    _socket!.on('new_message', (data) {
      print('New Message Received: $data');
      _messageController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('message_sent', (data) {
       // Ack from backend for own message
       if (data['message'] != null) {
          final msg = Map<String, dynamic>.from(data['message']);
          if (data['tempId'] != null) {
             msg['tempId'] = data['tempId'];
          }
          _messageController.add(msg);
       }
    });
    
    _socket!.on('message_delivered', (data) {
       print("SocketService: Received message_delivered: $data");
       _deliveryStatusController.add(Map<String, dynamic>.from(data));
    });
    
    _socket!.on('messages_seen_update', (data) {
       print("SocketService: Received messages_seen_update: $data");
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

    // --- Call Events (Preserved) ---
    _socket!.on('incoming-call', (data) => _callController.add({'event': 'incoming-call', 'data': data}));
    _socket!.on('call-accepted', (data) => _callController.add({'event': 'call-accepted', 'data': data}));
    _socket!.on('call-rejected', (data) => _callController.add({'event': 'call-rejected', 'data': data}));
    _socket!.on('call-ended', (data) => _callController.add({'event': 'call-ended', 'data': data}));
    _socket!.on('ice-candidate', (data) => _callController.add({'event': 'ice-candidate', 'data': data}));
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
