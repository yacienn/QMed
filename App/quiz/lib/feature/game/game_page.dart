import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';
import 'package:quiz/core/model/question.dart';
import 'package:quiz/core/theme/app_theme.dart';
import 'package:quiz/feature/auth/controller/auth_vm.dart';
import 'package:quiz/feature/game/results_page.dart';
import 'package:quiz/feature/home/controller/webSocket_vm.dart';
import 'package:quiz/widgets/chat_panel.dart';
import 'package:quiz/widgets/player.dart';

/// Displays the current question and answer choices.
class GamePage extends StatefulWidget {
  final String roomId;
  const GamePage({super.key, required this.roomId});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  @override
  Widget build(BuildContext context) {
    final websocket = context.watch<WebsocketVm>();
    final auth = context.watch<AuthVm>();
    final question = websocket.currentQuestion;

    String? myUserName;
    if (auth.token != null) {
      try {
        final decoded = JwtDecoder.decode(auth.token!);
        myUserName = decoded["userName"] as String?;
      } catch (_) {
        myUserName = null;
      }
    }
    final isHost = websocket.players
        .any((p) => p.userName == myUserName && p.isHost);

    // Once the host advances past the last question, everyone moves to the
    // results screen.
    if (websocket.gameFinished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ResultsPage()),
          );
        }
      });
    }

    // The host removed us from the room mid-game — bail out to the home
    // screen instead of leaving the player stuck on a dead game screen.
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmLeave(context, websocket);
      },
      child: Scaffold(
        backgroundColor: AppTheme.paperBeige,
        appBar: AppBar(
          backgroundColor: AppTheme.paperBeige,
          elevation: 0,
          title: Text(
            websocket.totalQuestions > 0
                ? 'Question ${websocket.currentQuestionIndex + 1}/${websocket.totalQuestions}'
                : 'Quiz',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppTheme.neoBlack,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppTheme.neoBlack,
              size: 28,
            ),
            tooltip: 'Leave game',
            onPressed: () => _confirmLeave(context, websocket),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.people_outline,
                color: AppTheme.neoBlack,
                size: 26,
              ),
              tooltip: 'Players',
              onPressed: () => showGamePlayersPanel(
                context,
                isHost: isHost,
                myUserName: myUserName,
              ),
            ),
            ChatButton(myUserName: myUserName),
          ],
        ),
        body: Column(
          children: [
            if (websocket.totalQuestions > 0)
              LinearProgressIndicator(
                value: (websocket.currentQuestionIndex + 1) /
                    websocket.totalQuestions,
                minHeight: 4,
                backgroundColor: AppTheme.lightGrey,
                color: AppTheme.accentTeal,
              ),
            Expanded(
              child: question == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppTheme.neoBlack,
                      ),
                    )
                  : _QuestionView(
                      key: ValueKey('${websocket.currentQuestionIndex}-${question.id}'),
                      question: question,
                      isHost: isHost,
                      timeLimit: websocket.questionTimeLimit,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLeave(BuildContext context, WebsocketVm websocket) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.paperBeige,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppTheme.neoBlack,
            width: AppTheme.borderWidth,
          ),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Leave Game?',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppTheme.neoBlack,
              ),
            ),
          ],
        ),
        content: const Text(
          'You will leave the room and lose your progress in this game.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.neoBlack,
          ),
        ),
        actions: [
          // Cancel Button
          GestureDetector(
            onTap: () {
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.neoBlack,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppTheme.neoBlack,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: AppTheme.neoBlack,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Leave Button
          GestureDetector(
            onTap: () {
              // Dismiss dialog
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
              // Use post-frame to ensure clean navigation
              WidgetsBinding.instance.addPostFrameCallback((_) {
                websocket.leaveRoom();
                Navigator.of(context).popUntil((route) => route.isFirst);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppTheme.errorRed,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.neoBlack,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppTheme.neoBlack,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Text(
                'LEAVE',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.all(16),
      ),
    );
  }
}

class _QuestionView extends StatefulWidget {
  final QuestionModel question;
  final bool isHost;
  final int timeLimit;
  const _QuestionView({
    super.key,
    required this.question,
    required this.isHost,
    required this.timeLimit,
  });

  @override
  State<_QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<_QuestionView> {
  int? _selected;
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeLimit;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
        timer.cancel();
        return;
      }
      final websocket = context.read<WebsocketVm>();
      if (_selected != null || websocket.allAnswered) {
        timer.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final websocket = context.watch<WebsocketVm>();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row with subject, timer, and score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.neoBlack,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppTheme.neoBlack,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.accentTeal,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    q.subject.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppTheme.neoBlack,
                    ),
                  ),
                ),
                _TimerBadge(secondsRemaining: _remainingSeconds),
                if (websocket.lastAnswerScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.amber,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${websocket.lastAnswerScore} pts',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.neoBlack,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Question text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.neoBlack,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppTheme.neoBlack,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              q.question,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.neoBlack,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Choices
          Expanded(
            child: ListView.separated(
              itemCount: q.choices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final choice = q.choices[index];
                final isSelected = _selected == choice.id;
                final revealed = websocket.revealedCorrectChoiceId != null;

                return _ChoiceTile(
                  label: choice.text,
                  isSelected: isSelected,
                  revealed: revealed,
                  isCorrect: choice.correct ?? false,
                  onTap: (_selected == null && _remainingSeconds > 0)
                      ? () {
                          setState(() => _selected = choice.id);
                          context.read<WebsocketVm>().submitAnswer(choice.id);
                        }
                      : null,
                );
              },
            ),
          ),

          // Bottom section: explanation + after answer bar
          if (_selected != null || _remainingSeconds <= 0) ...[
            const SizedBox(height: 16),
            if (q.explanation != null) ...[
              _ExplanationCard(text: q.explanation!),
              const SizedBox(height: 16),
            ] else if (_selected == null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red,
                    width: 2,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_off,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Time's up!",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _AfterAnswerBar(isHost: widget.isHost, allAnswered: websocket.allAnswered),
          ],
        ],
      ),
    );
  }
}

class _AfterAnswerBar extends StatelessWidget {
  final bool isHost;
  final bool allAnswered;

  const _AfterAnswerBar({required this.isHost, required this.allAnswered});

  @override
  Widget build(BuildContext context) {
    if (!isHost) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.blue,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              allAnswered ? Icons.check_circle : Icons.hourglass_empty,
              color: allAnswered ? AppTheme.successGreen : Colors.blue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              allAnswered
                  ? 'Waiting for host to continue...'
                  : 'Waiting for other players...',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: allAnswered ? AppTheme.successGreen : Colors.blue.shade800,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (!allAnswered)
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Waiting for all players to answer...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        GestureDetector(
          onTap: allAnswered
              ? () => context.read<WebsocketVm>().nextQuestion()
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              color: allAnswered ? AppTheme.accentMagenta : AppTheme.mediumGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.neoBlack,
                width: AppTheme.borderWidth,
              ),
              boxShadow: allAnswered
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
                  Icons.arrow_forward,
                  color: allAnswered ? AppTheme.neoBlack : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'NEXT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: allAnswered ? AppTheme.neoBlack : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerBadge extends StatelessWidget {
  final int secondsRemaining;
  const _TimerBadge({required this.secondsRemaining});

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (secondsRemaining <= 5) {
      color = AppTheme.errorRed;
    } else if (secondsRemaining <= 10) {
      color = Colors.orange;
    } else {
      color = AppTheme.successGreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${secondsRemaining}s',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool revealed;
  final bool isCorrect;
  final VoidCallback? onTap;

  const _ChoiceTile({
    required this.label,
    required this.isSelected,
    required this.revealed,
    required this.isCorrect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? tileColor;
    Color? borderColor = AppTheme.lightGrey;
    double borderWidth = 2;

    if (revealed) {
      if (isSelected) {
        tileColor = isCorrect 
            ? AppTheme.successGreen.withOpacity(0.2) 
            : AppTheme.errorRed.withOpacity(0.2);
        borderColor = isCorrect ? AppTheme.successGreen : AppTheme.errorRed;
        borderWidth = AppTheme.borderWidth;
      } else if (isCorrect) {
        tileColor = AppTheme.successGreen.withOpacity(0.1);
        borderColor = AppTheme.successGreen;
        borderWidth = 2;
      }
    } else if (isSelected) {
      tileColor = AppTheme.accentTeal.withOpacity(0.15);
      borderColor = AppTheme.accentTeal;
      borderWidth = AppTheme.borderWidth;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: tileColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: isSelected && !revealed
            ? const [
                BoxShadow(
                  color: AppTheme.neoBlack,
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: AppTheme.neoBlack,
                    ),
                  ),
                ),
                if (revealed && (isSelected || isCorrect))
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? AppTheme.successGreen : AppTheme.errorRed,
                    size: 24,
                  )
                else if (isSelected)
                  Icon(
                    Icons.radio_button_checked,
                    color: AppTheme.accentTeal,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final String text;
  const _ExplanationCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.neoBlack,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.neoBlack,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the live player list as a modal bottom sheet
Future<void> showGamePlayersPanel(
  BuildContext context, {
  required bool isHost,
  required String? myUserName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<WebsocketVm>(),
      child: _GamePlayersSheet(isHost: isHost, myUserName: myUserName),
    ),
  );
}

class _GamePlayersSheet extends StatelessWidget {
  final bool isHost;
  final String? myUserName;

  const _GamePlayersSheet({required this.isHost, required this.myUserName});

  @override
  Widget build(BuildContext context) {
    final websocket = context.watch<WebsocketVm>();
    final players = websocket.players;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.paperBeige,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.mediumGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'PLAYERS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppTheme.neoBlack,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.accentTeal,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '${players.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.neoBlack,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              color: AppTheme.neoBlack,
              thickness: 2,
              height: 16,
            ),
            Expanded(
              child: players.isEmpty
                  ? const Center(
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
                            'NO PLAYERS',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.mediumGrey,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
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
                              onKick: (isHost && !isMe && player.userName != null)
                                  ? () => websocket.kickPlayer(player.userName as String)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}