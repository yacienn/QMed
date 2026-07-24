import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz/core/model/subject.dart';
import 'package:quiz/core/theme/app_theme.dart';
import 'package:quiz/feature/Host/controller/host_vm.dart';
import 'package:quiz/feature/auth/controller/auth_vm.dart';
import 'package:quiz/feature/game/game_page.dart';
import 'package:quiz/feature/home/controller/webSocket_vm.dart';
import 'package:quiz/widgets/chat_panel.dart';
import 'package:quiz/widgets/player.dart';

class HostPage extends StatefulWidget {
  final String roomId;

  const HostPage({super.key, required this.roomId});

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  late final HostVm _vm;

  @override
  void initState() {
    super.initState();
    _vm = HostVm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm.initUserName(context.read<AuthVm>().token);
      context.read<WebsocketVm>().getSubjects();
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

    // The host removed a player, and that player was... somehow us (e.g. a
    // second device signed into the same account got kicked by the other).
    // Bail out to the home screen just like any other kicked client would.
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

    // Navigate to game when game starts
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
            "HOST LOBBY",
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
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _RoomHeader(
              roomId: widget.roomId,
              playerCount: websocket.players.length,
            ),
            const SizedBox(height: 16),
            // BUG FIX: this used to be Expanded inside a Column, so once the
            // quiz config section below grew tall enough (subject + chapters
            // + confirm button + error banner), it squeezed this down to
            // near-zero height and the player list effectively disappeared.
            // A fixed height + its own internal scroll keeps players always
            // visible no matter how big the config section gets, and the
            // outer ListView lets the whole page scroll instead of fighting
            // over space.
            SizedBox(
              height: 220,
              child: _PlayerList(
                players: websocket.players,
                myUserName: _vm.myUserName,
              ),
            ),
            const SizedBox(height: 16),
            _QuizConfigSection(websocket: websocket),
            const SizedBox(height: 16),
            _HostActions(websocket: websocket, myUserName: _vm.myUserName),
            const SizedBox(height: 8),
          ],
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

    final websocket = context.read<WebsocketVm>();

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
          final isMe = player.userName == myUserName;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: PlayerTile(
              player: player,
              isMe: isMe,
              onKick: isMe || player.userName == null
                  ? null
                  : () => websocket.kickPlayer(player.userName as String),
            ),
          );
        },
      ),
    );
  }
}

class _HostActions extends StatelessWidget {
  final WebsocketVm websocket;
  final String? myUserName;

  const _HostActions({required this.websocket, required this.myUserName});

  // BUG FIX: previously there was no way to tell whether *this* player had
  // already marked themselves ready — the button always looked identical.
  // Look the local player up in the room's player list to know their real
  // ready state.
  bool get _amReady {
    for (final p in websocket.players) {
      if (p.userName == myUserName) return p.isReady == true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final allReady = websocket.allPlayersReady;
    final canStart = allReady && websocket.quizConfigured;
    final amReady = _amReady;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!websocket.quizConfigured)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Choose a subject and at least one chapter above to continue.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (!allReady)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Waiting for all players to be ready...',
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // BUG FIX: this used to be a plain Row with no wrapping, which could
        // overflow horizontally (the classic yellow/black striped render
        // error) on narrower phone widths once you add the Ready button,
        // Start Game button, and status chip together. Wrap lets the status
        // chip drop to its own line instead of pushing the layout off-screen.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            // Ready Button — BUG FIX: label/color/icon now reflect whether
            // this player has actually marked themselves ready, instead of
            // always looking identical no matter what.
            GestureDetector(
              onTap: websocket.setReady,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: amReady ? AppTheme.successGreen : AppTheme.accentTeal,
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
                      amReady ? Icons.check_circle : Icons.check_circle_outline,
                      color: AppTheme.neoBlack,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      amReady ? "READY ✓" : "READY UP",
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
            // Start Game Button
            GestureDetector(
              onTap: canStart ? websocket.startGame : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: canStart ? AppTheme.accentMagenta : AppTheme.mediumGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.neoBlack,
                    width: AppTheme.borderWidth,
                  ),
                  boxShadow: canStart
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
                      color: canStart ? AppTheme.neoBlack : Colors.white70,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "START GAME",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: canStart ? AppTheme.neoBlack : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: allReady && websocket.quizConfigured
                    ? AppTheme.successGreen.withOpacity(0.15)
                    : Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: allReady && websocket.quizConfigured
                      ? AppTheme.successGreen
                      : Colors.orange,
                  width: 2,
                ),
              ),
              child: Text(
                allReady && websocket.quizConfigured
                    ? "READY"
                    : !websocket.quizConfigured
                        ? "NO SUBJECT"
                        : "WAITING",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: allReady && websocket.quizConfigured
                      ? AppTheme.successGreen
                      : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuizConfigSection extends StatefulWidget {
  final WebsocketVm websocket;

  const _QuizConfigSection({required this.websocket});

  @override
  State<_QuizConfigSection> createState() => _QuizConfigSectionState();
}

class _QuizConfigSectionState extends State<_QuizConfigSection> {
  String? _selectedSubject;
  final Set<int> _selectedChapters = {};

  SubjectModel? get _subjectInfo {
    final subject = _selectedSubject;
    if (subject == null) return null;
    for (final s in widget.websocket.subjects) {
      if (s.subject == subject) return s;
    }
    return null;
  }

  // BUG FIX: if `subjects` reloads (e.g. getSubjects() is called again) and
  // the previously-picked subject string is no longer in the list, passing
  // the stale `_selectedSubject` straight into DropdownButtonFormField's
  // `value` crashes with "There should be exactly one item with
  // [DropdownButtonFormField]'s value". This getter falls back to null
  // instead of a value the dropdown doesn't actually have as an item.
  String? get _safeSelectedSubject {
    final subject = _selectedSubject;
    if (subject == null) return null;
    final stillExists =
        widget.websocket.subjects.any((s) => s.subject == subject);
    return stillExists ? subject : null;
  }

  void _apply() {
    final subject = _selectedSubject;
    if (subject == null || _selectedChapters.isEmpty) return;
    widget.websocket.configureQuiz(subject, _selectedChapters.toList());
  }

  @override
  Widget build(BuildContext context) {
    final subjects = widget.websocket.subjects;
    final configured = widget.websocket.quizConfigured;

    if (subjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
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
              SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.neoBlack,
                ),
              ),
              SizedBox(height: 12),
              Text(
                "LOADING SUBJECTS...",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.mediumGrey,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
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
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'QUIZ CONFIGURATION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: AppTheme.neoBlack,
                ),
              ),
              const Spacer(),
              if (configured) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.successGreen,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.successGreen,
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'CONFIGURED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Subject Dropdown
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.neoBlack,
                width: 2,
              ),
            ),
            child: DropdownButtonFormField<String>(
              value: _safeSelectedSubject,
              hint: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Choose a subject',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkGrey,
                  ),
                ),
              ),
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.neoBlack),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.neoBlack,
              ),
              items: subjects
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.subject,
                      child: Text(
                        '${s.subject} (${s.questionCount} questions)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubject = value;
                  _selectedChapters.clear();
                });
              },
            ),
          ),
          if (_subjectInfo != null) ...[
            const SizedBox(height: 10),
            const Text(
              'SELECT CHAPTERS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 6),
            // BUG FIX: chapters used to sit in an unbounded Wrap, which grew
            // as tall as it needed to fit every chapter chip. With subjects
            // that have a lot of chapters, that alone could push the config
            // section past the visible screen. Capping the height and
            // letting it scroll internally keeps the section a predictable,
            // compact size regardless of chapter count.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.lightGrey,
                    width: 2,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _subjectInfo!.chapters.map((chapter) {
                      final selected = _selectedChapters.contains(chapter);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedChapters.remove(chapter);
                            } else {
                              _selectedChapters.add(chapter);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.accentTeal
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.accentTeal
                                  : AppTheme.mediumGrey,
                              width: selected ? AppTheme.borderWidth : 2,
                            ),
                            boxShadow: selected
                                ? const [
                                    BoxShadow(
                                      color: AppTheme.neoBlack,
                                      offset: Offset(2, 2),
                                      blurRadius: 0,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            'Ch. $chapter',
                            style: TextStyle(
                              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                              fontSize: 12,
                              color: selected
                                  ? AppTheme.neoBlack
                                  : AppTheme.darkGrey,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedChapters.length} selected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: AppTheme.darkGrey,
                  ),
                ),
                GestureDetector(
                  onTap: _selectedChapters.isEmpty ? null : _apply,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedChapters.isEmpty
                          ? AppTheme.mediumGrey
                          : AppTheme.accentMagenta,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.neoBlack,
                        width: AppTheme.borderWidth,
                      ),
                      boxShadow: _selectedChapters.isEmpty
                          ? null
                          : const [
                              BoxShadow(
                                color: AppTheme.neoBlack,
                                offset: Offset(2, 2),
                                blurRadius: 0,
                              ),
                            ],
                    ),
                    child: Text(
                      configured ? 'UPDATE' : 'CONFIRM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: _selectedChapters.isEmpty
                            ? Colors.white70
                            : AppTheme.neoBlack,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (widget.websocket.quizConfigError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.errorRed,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppTheme.errorRed,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.websocket.quizConfigError!,
                      style: TextStyle(
                        color: AppTheme.errorRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
