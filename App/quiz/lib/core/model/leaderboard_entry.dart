class LeaderboardEntry {
  final int userId;
  final String userName;
  final int totalScore;
  final int gamesPlayed;
  final int bestScore;

  const LeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.totalScore,
    required this.gamesPlayed,
    required this.bestScore,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['userId'] as int? ?? 0,
      userName: json['userName'] as String? ?? 'Unknown',
      totalScore: json['totalScore'] as int? ?? 0,
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      bestScore: json['bestScore'] as int? ?? 0,
    );
  }
}
