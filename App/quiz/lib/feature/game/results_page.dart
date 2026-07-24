import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';
import 'package:quiz/core/model/player.dart';
import 'package:quiz/feature/Host/view/host_page.dart';
import 'package:quiz/feature/auth/controller/auth_vm.dart';
import 'package:quiz/feature/home/controller/webSocket_vm.dart';
import 'package:quiz/feature/leaderboard/view/leaderboard_page.dart';
import 'package:quiz/feature/lobby/view/lobby_page.dart';

/// Final scoreboard, shown to every player once the host advances past the
/// last question.
class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  // A rematch triggers two back-to-back server messages (`room_rematched`
  // then `room_update`), each of which calls notifyListeners(). Without this
  // guard, both rebuilds would see `rematching == true` and each would
  // schedule its own Navigator.pushReplacement — firing it twice on the same
  // route crashes the app. This flag makes the navigation fire exactly once.
  bool _navigatedToRematch = false;

  @override
  Widget build(BuildContext context) {
    final websocket = context.watch<WebsocketVm>();
    final auth = context.watch<AuthVm>();

    String? myUserName;
    if (auth.token != null) {
      final decoded = JwtDecoder.decode(auth.token!);
      myUserName = decoded["userName"] as String?;
    }

    final isHost = websocket.players
        .any((p) => p.userName == myUserName && p.isHost);
    final roomId = websocket.roomId;

    // The host started a rematch (or another player did, and it landed us
    // back in the lobby) — head back to the lobby/host screen instead of
    // making everyone leave and re-join a fresh room.
    if (websocket.rematching && roomId != null && !_navigatedToRematch) {
      _navigatedToRematch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => isHost
                  ? HostPage(roomId: roomId)
                  : LobbyPage(roomId: roomId),
            ),
          );
        }
      });
    }

    // The host removed us from the room while we were looking at results.
    if (websocket.kicked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          websocket.acknowledgeKicked();
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You were removed from the room by the host'),
            ),
          );
        }
      });
    }

    final ranked = [...websocket.players]
      ..sort((a, b) => b.score.compareTo(a.score));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Scores'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ranked.isNotEmpty)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
                    const SizedBox(height: 8),
                    Text(
                      ranked.first.userName ?? 'Unknown',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${ranked.first.score} points',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: ranked.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final player = ranked[index];
                  return _RankTile(
                    rank: index + 1,
                    player: player,
                    isMe: player.userName == myUserName,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (isHost) ...[
              ElevatedButton.icon(
                onPressed: websocket.rematch,
                icon: const Icon(Icons.replay),
                label: const Text('Play Again (same subject)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Waiting to see if the host wants a rematch...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () {
                websocket.leaveRoom();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.home),
              label: const Text('Back to Home'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaderboardPage()),
                );
              },
              icon: const Icon(Icons.leaderboard),
              label: const Text('View Top 15 Leaderboard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final int rank;
  final PlayerModel player;
  final bool isMe;

  const _RankTile({required this.rank, required this.player, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: rank == 1 ? Colors.amber : Colors.grey.shade300,
        child: Text('$rank'),
      ),
      title: Row(
        children: [
          Text(player.userName ?? 'Unknown'),
          if (isMe) ...[
            const SizedBox(width: 6),
            const Text('(You)', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ],
      ),
      trailing: Text(
        '${player.score} pts',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}