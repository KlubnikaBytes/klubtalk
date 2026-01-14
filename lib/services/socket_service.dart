import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:whatsapp_clone/services/auth_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  IO.Socket? socket;
  bool isConnected = false;

  void initSocket() {
    final currentUserId = AuthService().currentUserId;
    if (currentUserId == null) return;

    // ApiConfig.baseUrl usually is http://localhost:5000/api or just base
    // We need the root domain for socket
    // Assuming ApiConfig.baseUrl is like 'http://localhost:5000/api' or just 'http://localhost:5000'
    // Let's strip '/api' if present or use hardcoded base if complex.
    // For now assuming baseUrl is usable or we parse it.
    // Actually ApiConfig.baseUrl usually is 'http://localhost:5000/api'.
    // We want 'http://localhost:5000'.
    
    String socketUrl = ApiConfig.baseUrl.replaceAll('/api', '');

    socket = IO.io(socketUrl, IO.OptionBuilder()
        .setTransports(['websocket']) // for Flutter or Dart VM
        .enableAutoConnect() 
        .build()
    );

    socket!.onConnect((_) {
      print('Socket Connected: ${socket!.id}');
      isConnected = true;
      // Join User Room
      socket!.emit('join-user', currentUserId);
    });

    socket!.onDisconnect((_) {
      print('Socket Disconnected');
      isConnected = false;
    });
    
    socket!.onConnectError((data) => print("Socket Error: $data"));
  }

  void emit(String event, dynamic data) {
    if (socket != null && isConnected) {
      socket!.emit(event, data);
    }
  }

  void on(String event, Function(dynamic) handler) {
    if (socket != null) {
      socket!.on(event, handler);
    }
  }

  void off(String event) {
    if (socket != null) {
      socket!.off(event);
    }
  }

  void dispose() {
    socket?.disconnect();
    socket = null;
  }
}
