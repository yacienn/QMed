class PlayerModel {
  final String? userName;
  final String role;
  final bool isReady;
  final int score;
  final bool hasAnswered;

  const PlayerModel({
    required this.userName,
    required this.role,
    required this.isReady,
    required this.score,
    this.hasAnswered = false,
  });

  bool get isHost => role == "host";

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      userName: json["userName"] as String?,
      role: json["role"] as String? ?? "joiner",
      isReady: json["isReady"] as bool? ?? false,
      score: json["score"] as int? ?? 0,
      hasAnswered: json["hasAnswered"] as bool? ?? false,
    );
  }
}