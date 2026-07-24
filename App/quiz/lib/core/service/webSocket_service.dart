import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:quiz/core/api/api_config.dart';
import 'package:quiz/core/websocket%20types/ws_types.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  WebSocketChannel? channel;


  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  bool get isConnected => channel != null;

  void connect(String token) {
    if (channel != null) return; // already connected, avoid double-connect

    channel = WebSocketChannel.connect(
      Uri.parse(ApiConfig.wsBase),
    );

    channel!.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller.add(data);
        } catch (e) {
          debugPrint("Failed to decode socket message: $e");
        }
      },
      onDone: () {
        debugPrint("Disconnected");
        channel = null;
      },
      onError: (e) {
        debugPrint("Socket error: $e");
      },
    );

    // Authenticate immediately after connecting.
    authenticate(token);
  }

  void authenticate(String token) {
    send({
      "type": WsTypes.auth,
      "token": token,
    });
  }

  void send(Map<String, dynamic> data) {
    channel?.sink.add(jsonEncode(data));
  }

  void disconnect() {
    channel?.sink.close();
    channel = null;
  }
}