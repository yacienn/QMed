import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz/core/model/player.dart';
import 'package:quiz/core/theme/app_theme.dart';
import 'package:quiz/feature/auth/controller/auth_vm.dart';
import 'package:quiz/feature/game/game_page.dart';
import 'package:quiz/feature/home/controller/webSocket_vm.dart';
import 'package:quiz/feature/lobby/controller/lobby_vm.dart';
import 'package:quiz/widgets/chat_panel.dart';
import 'package:quiz/widgets/player.dart';

class LobbyPage extends StatefulWidget {
  final String roomId;

  const LobbyPage({super.key, required this.roomId});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  late final LobbyVm _vm;

  @override
  void initState() {
    super.initState();
    _vm = LobbyVm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm.initUserName(context.read<AuthVm>().token);
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _onBack(WebsocketVm websocket) {
    websocket.leaveRoom();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final websocket = context.watch<WebsocketVm>();

    if (websocket.kicked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          websocket.acknowledgeKicked();
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You were removed from the room by the host'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      });
    }

    // Navigate to game when host starts it
    if (websocket.gameStarted && websocket.currentQuestion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => GamePage(roomId: widget.roomId),
            ),
          );
        }
      });
    }

    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: AppTheme.paperBeige,
        appBar: AppBar(
          backgroundColor: AppTheme.paperBeige,
          elevation: 0,
          title: const Text(
            "LOBBY",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: AppTheme.neoBlack,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppTheme.neoBlack,
              size: 28,
            ),
            onPressed: () => _onBack(websocket),
          ),
          actions: [
            ChatButton(myUserName: _vm.myUserName),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RoomHeader(roomId: widget.roomId, playerCount: websocket.players.length),
              const SizedBox(height: 16),
              Expanded(
                child: _PlayerList(
                  players: websocket.players,
                  myUserName: _vm.myUserName,
                ),
              ),
              const SizedBox(height: 16),
              _LobbyActions(
                websocket: websocket,
                myUserName: _vm.myUserName,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  final String roomId;
  final int playerCount;

  const _RoomHeader({required this.roomId, required this.playerCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.neoBlack,
          width: AppTheme.borderWidth,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.neoBlack,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ROOM ID',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                roomId,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: AppTheme.neoBlack,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.accentTeal,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people,
                  color: AppTheme.accentTeal,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$playerCount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.neoBlack,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'player${playerCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerList extends StatelessWidget {
  final List players;
  final String? myUserName;

  const _PlayerList({required this.players, required this.myUserName});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.lightGrey,
            width: 2,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 48,
                color: AppTheme.mediumGrey,
              ),
              SizedBox(height: 12),
              Text(
                "WAITING FOR PLAYERS...",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.mediumGrey,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.neoBlack,
          width: 2,
        ),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: players.length,
        separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: AppTheme.lightGrey,
            thickness: 1.5,
          ),
        ),
        itemBuilder: (context, index) {
          final player = players[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: PlayerTile(
              player: player,
              isMe: player.userName == myUserName,
            ),
          );
        },
      ),
    );
  }
}

class _LobbyActions extends StatelessWidget {
  final WebsocketVm websocket;
  final String? myUserName;

  const _LobbyActions({
    required this.websocket,
    required this.myUserName,
  });

  @override
  Widget build(BuildContext context) {
    // Check if current user is the host
    PlayerModel? host;
    if (websocket.players.isNotEmpty) {
      try {
        host = websocket.players.firstWhere(
          (p) => p.isHost,
        );
      } catch (_) {
        host = null;
      }
    }
    
    final isHost = host != null && host.userName == myUserName;
    
    // Check if current player is ready
    PlayerModel? currentPlayer;
    if (websocket.players.isNotEmpty && myUserName != null) {
      try {
        currentPlayer = websocket.players.firstWhere(
          (p) => p.userName == myUserName,
        );
      } catch (_) {
        currentPlayer = null;
      }
    }
    
    final isReady = currentPlayer?.isReady ?? false;
    final allReady = websocket.allPlayersReady;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ready / Unready Button
        GestureDetector(
          onTap: websocket.setReady,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              color: isReady ? AppTheme.successGreen : AppTheme.accentTeal,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.neoBlack,
                width: AppTheme.borderWidth,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppTheme.neoBlack,
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isReady ? Icons.check_circle : Icons.check_circle_outline,
                  color: AppTheme.neoBlack,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  isReady ? "READY" : "SET READY",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppTheme.neoBlack,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Host controls
        if (isHost) ...[
          const SizedBox(width: 16),
          GestureDetector(
            onTap: allReady ? websocket.startGame : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: allReady ? AppTheme.accentMagenta : AppTheme.mediumGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.neoBlack,
                  width: AppTheme.borderWidth,
                ),
                boxShadow: allReady
                    ? const [
                        BoxShadow(
                          color: AppTheme.neoBlack,
                          offset: Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow,
                    color: allReady ? AppTheme.neoBlack : Colors.white70,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "START GAME",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: allReady ? AppTheme.neoBlack : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Ready status indicator
        if (websocket.players.isNotEmpty) ...[
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: allReady 
                  ? AppTheme.successGreen.withOpacity(0.15)
                  : Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: allReady ? AppTheme.successGreen : Colors.orange,
                width: 2,
              ),
            ),
            child: Text(
              allReady ? "ALL READY" : "WAITING...",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: allReady ? AppTheme.successGreen : Colors.orange,
              ),
            ),
          ),
        ],
      ],
    );
  }
}