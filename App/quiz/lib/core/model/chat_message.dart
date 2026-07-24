/// A single room chat message. Entirely in-memory on both the server and
/// here — nothing is persisted, so history disappears once the room does.
class ChatMessageModel {
  final String userName;
  final String message;
  final DateTime timestamp;

  const ChatMessageModel({
    required this.userName,
    required this.message,
    required this.timestamp,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];
    return ChatMessageModel(
      userName: json['username'] as String? ?? 'Unknown',
      message: json['message'] as String? ?? '',
      timestamp: rawTimestamp is int
          ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp)
          : DateTime.now(),
    );
  }
}
