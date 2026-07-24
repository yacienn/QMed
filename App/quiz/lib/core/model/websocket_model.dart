class WebSocketMessage {
  final String type;
  final String userName;
  final String? message;
  final String? roomId;
  final String? token;

  WebSocketMessage({
    required this.type,
    required this.userName,
    this.message,
    this.roomId,
    this.token,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String,
      userName: json['userName'] as String,
      message: json['message'] as String?,
      roomId: json['roomId'] as String?,
      token: json['token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'userName': userName,
      'message': message,
      'roomId': roomId,
      'token': token,
    };
  }
}