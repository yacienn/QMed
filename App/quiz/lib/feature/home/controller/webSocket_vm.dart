import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quiz/core/model/chat_message.dart';
import 'package:quiz/core/model/player.dart';
import 'package:quiz/core/model/question.dart';
import 'package:quiz/core/model/subject.dart';
import 'package:quiz/core/service/webSocket_service.dart';
import 'package:quiz/core/websocket%20types/ws_types.dart';

class WebsocketVm extends ChangeNotifier {
  final SocketService socket = SocketService();

  String? roomId;
  String? errorMessage;
  bool connected = false;
  bool sessionExpired = false;
  bool gameStarted = false;
  bool gameFinished = false;
  QuestionModel? currentQuestion;

  // 0-based index of the current question, and how many questions this
  // game has in total (10, driven by the server).
  int currentQuestionIndex = 0;
  int totalQuestions = 0;

  // How many seconds players get to answer each question. Sent by the
  // server with GAME_STARTED/NEW_QUESTION so the countdown always matches
  // whatever the server is actually enforcing.
  int questionTimeLimit = 20;

  // True for one frame after the server tells this client it was removed
  // from the room by the host. The UI should navigate back to the home
  // screen and clear this via [acknowledgeKicked].
  bool kicked = false;

  // Result of *my* last submitted answer, and whether every player in the
  // room has now answered the current question (host uses this to enable
  // the "Next" button).
  bool? lastAnswerCorrect;
  int? lastAnswerScore;
  bool allAnswered = false;

  // Only populated once `allAnswered` is true — the correct choice id +
  // explanation, revealed to the whole room at the same moment. Nothing in
  // the UI should show which choice was correct before this is set.
  int? revealedCorrectChoiceId;
  String? revealedExplanation;

  // True for the brief window between the host starting a rematch and the
  // room landing back in the lobby — lets the UI navigate away from the
  // results screen.
  bool rematching = false;

  List<PlayerModel> players = [];
  List<ChatMessageModel> chatMessages = [];

  // ── quiz configuration (subject + chapters) ─────────────────────────────────
  List<SubjectModel> subjects = [];
  bool quizConfigured = false;
  String? selectedSubject;
  List<int> selectedChapters = [];
  String? quizConfigError;

  Completer<String?>? _pendingRoomRequest;

  // ── connection ────────────────────────────────────────────────────────────

  void connect(String token) {
    if (connected) return;
    socket.connect(token);
    connected = true;
    socket.messages.listen(_handleMessage);
  }

  void disconnectSocket() {
    socket.disconnect();
    connected = false;
    _resetRoomState();
  }

  // ── message handling ──────────────────────────────────────────────────────

  void _handleMessage(Map<String, dynamic> data) {
    switch (data['type']) {
      case WsTypes.createRoom:
      case WsTypes.join:
        roomId = data['roomId'] as String?;
        _updatePlayers(data);
        _updateProgress(data);
        _updateQuizConfig(data);
        _updateChatHistory(data);
        _pendingRoomRequest?.complete(roomId);
        _pendingRoomRequest = null;
        notifyListeners();

      case WsTypes.roomUpdate:
        _updatePlayers(data);
        _updateProgress(data);
        _updateQuizConfig(data);
        // If the room was deleted (0 players) the server won't send this, but
        // guard anyway — if roomId is gone after a leave, clear local state.
        if (players.isEmpty && roomId != null) {
          _resetRoomState();
        }
        notifyListeners();

      case WsTypes.subjects:
        final rawSubjects = data['subjects'] as List<dynamic>?;
        subjects = (rawSubjects ?? [])
            .map((s) => SubjectModel.fromJson(s as Map<String, dynamic>))
            .toList();
        notifyListeners();

      case WsTypes.quizConfigured:
        selectedSubject = data['subject'] as String?;
        selectedChapters = (data['chapters'] as List<dynamic>?)
                ?.map((c) => c as int)
                .toList() ??
            [];
        quizConfigured = true;
        quizConfigError = null;
        notifyListeners();

      case WsTypes.roomDeleted:
        // Emitted by the server when the last player leaves.
        _resetRoomState();
        notifyListeners();

      case WsTypes.gameStarted:
        gameStarted = true;
        gameFinished = false;
        rematching = false;
        currentQuestionIndex = 0;
        allAnswered = false;
        lastAnswerCorrect = null;
        lastAnswerScore = null;
        revealedCorrectChoiceId = null;
        revealedExplanation = null;
        questionTimeLimit = data['timeLimit'] as int? ?? questionTimeLimit;
        if (data['question'] != null) {
          currentQuestion =
              QuestionModel.fromJson(data['question'] as Map<String, dynamic>);
        }
        notifyListeners();

      case WsTypes.answerResult:
        // Reply to *my* answer submission — tells me if I got it right and
        // what my running score is now.
        lastAnswerCorrect = data['correct'] as bool?;
        lastAnswerScore = data['score'] as int?;
        notifyListeners();

      case WsTypes.allAnswered:
        // Every player in the room has answered the current question — the
        // host can now move on. This is also the one moment the correct
        // answer is allowed to become visible, for everyone at once.
        allAnswered = true;
        revealedCorrectChoiceId = data['correctChoiceId'] as int?;
        revealedExplanation = data['explanation'] as String?;
        if (currentQuestion != null && revealedCorrectChoiceId != null) {
          currentQuestion = currentQuestion!.revealedWith(
            correctChoiceId: revealedCorrectChoiceId!,
            explanation: revealedExplanation ?? '',
          );
        }
        notifyListeners();

      case WsTypes.newQuestion:
        currentQuestionIndex += 1;
        allAnswered = false;
        lastAnswerCorrect = null;
        lastAnswerScore = null;
        revealedCorrectChoiceId = null;
        revealedExplanation = null;
        questionTimeLimit = data['timeLimit'] as int? ?? questionTimeLimit;
        if (data['question'] != null) {
          currentQuestion =
              QuestionModel.fromJson(data['question'] as Map<String, dynamic>);
        }
        notifyListeners();

      case WsTypes.gameFinished:
        gameFinished = true;
        gameStarted = false;
        currentQuestion = null;
        _updatePlayers(data);
        _updateProgress(data);
        notifyListeners();

      case WsTypes.authFailed:
        debugPrint('Auth failed: ${data["message"]}');
        sessionExpired = true;
        connected = false;
        _pendingRoomRequest?.completeError(
          data['message'] ?? 'Authentication failed',
        );
        _pendingRoomRequest = null;
        notifyListeners();

      case WsTypes.playerJoined:
        debugPrint('${data["username"]} joined');
        notifyListeners();

      case WsTypes.playerLeft:
        debugPrint('${data["username"]} left');
        notifyListeners();

      case WsTypes.playerKicked:
        // A room_update follows immediately with the updated player list —
        // this is just for any "X was removed" toast the UI wants to show.
        debugPrint('${data["username"]} was kicked by the host');
        notifyListeners();

      case WsTypes.kicked:
        // This client was the one removed. Reset local room state and flag
        // it so the current room/game/lobby screen can navigate home.
        kicked = true;
        _resetRoomState();
        notifyListeners();

      case WsTypes.message:
        // A live chat message from the room (initial history arrives
        // separately, hydrated on create/join — see _updateChatHistory).
        chatMessages.add(ChatMessageModel.fromJson(data));
        notifyListeners();

      case WsTypes.roomRematched:
        // Host started a rematch: same subject+chapters, fresh questions,
        // scores reset — everyone heads back to the lobby. The room_update
        // that follows carries the reset player list/state.
        rematching = true;
        gameStarted = false;
        gameFinished = false;
        currentQuestion = null;
        currentQuestionIndex = 0;
        allAnswered = false;
        lastAnswerCorrect = null;
        lastAnswerScore = null;
        revealedCorrectChoiceId = null;
        revealedExplanation = null;
        notifyListeners();

      case WsTypes.error:
        errorMessage = data['message'] as String?;
        quizConfigError = errorMessage;
        _pendingRoomRequest?.completeError(errorMessage ?? 'Unknown error');
        _pendingRoomRequest = null;
        notifyListeners();

      default:
        debugPrint('Unhandled ws message: $data');
    }
  }

  void _updateChatHistory(Map<String, dynamic> data) {
    final rawMessages = data['chatMessages'] as List<dynamic>?;
    if (rawMessages == null) return;
    chatMessages = rawMessages
        .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  void _updatePlayers(Map<String, dynamic> data) {
    final rawPlayers = data['players'] as List<dynamic>?;
    if (rawPlayers == null) return;
    players = rawPlayers
        .map((p) => PlayerModel.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  void _updateProgress(Map<String, dynamic> data) {
    final current = data['currentQuestion'] as int?;
    final total = data['totalQuestions'] as int?;
    if (current != null) currentQuestionIndex = current;
    if (total != null) totalQuestions = total;
    allAnswered = players.isNotEmpty && players.every((p) => p.hasAnswered);
  }

  void _updateQuizConfig(Map<String, dynamic> data) {
    if (data.containsKey('quizConfigured')) {
      quizConfigured = data['quizConfigured'] as bool? ?? false;
    }
    if (data.containsKey('subject')) {
      selectedSubject = data['subject'] as String?;
    }
    if (data.containsKey('chapters')) {
      selectedChapters = (data['chapters'] as List<dynamic>?)
              ?.map((c) => c as int)
              .toList() ??
          [];
    }
  }

  void _resetRoomState() {
    roomId = null;
    players = [];
    gameStarted = false;
    gameFinished = false;
    currentQuestion = null;
    currentQuestionIndex = 0;
    totalQuestions = 0;
    allAnswered = false;
    lastAnswerCorrect = null;
    lastAnswerScore = null;
    revealedCorrectChoiceId = null;
    revealedExplanation = null;
    rematching = false;
    quizConfigured = false;
    selectedSubject = null;
    selectedChapters = [];
    quizConfigError = null;
    chatMessages = [];
  }

  // ── room actions ──────────────────────────────────────────────────────────

  Future<String?> createRoom() {
    _pendingRoomRequest = Completer<String?>();
    socket.send({'type': WsTypes.createRoom});
    return _pendingRoomRequest!.future;
  }

  Future<String?> joinRoom(String targetRoomId) {
    _pendingRoomRequest = Completer<String?>();
    socket.send({'type': WsTypes.join, 'roomId': targetRoomId});
    return _pendingRoomRequest!.future;
  }

  void setReady() {
    socket.send({'type': WsTypes.ready});
  }

  void startGame() {
    socket.send({'type': WsTypes.startGame});
  }

  void leaveRoom() {
    socket.send({'type': WsTypes.left});
    _resetRoomState();
    notifyListeners();
  }

  /// Ask the server for the list of available subjects/chapters. Safe to
  /// call as soon as connected — doesn't require being in a room.
  void getSubjects() {
    socket.send({'type': WsTypes.getSubjects});
  }

  /// Host-only: choose which subject + chapters this room's questions come
  /// from. Can be called again before the game starts to change the choice.
  void configureQuiz(String subject, List<int> chapters) {
    quizConfigError = null;
    socket.send({
      'type': WsTypes.configureQuiz,
      'subject': subject,
      'chapters': chapters,
    });
  }

  /// Submit an answer for the current question. [answerId] is the id of the
  /// chosen `ChoiceModel`.
  void submitAnswer(int answerId) {
    socket.send({'type': WsTypes.answer, 'answerId': answerId});
  }

  /// Host-only: move the room to the next question, or finish the game if
  /// this was the last one. The server rejects this unless every player has
  /// answered the current question.
  void nextQuestion() {
    socket.send({'type': WsTypes.nextQuestion});
  }

  /// Send a chat message to everyone currently in the room. Purely in
  /// memory on the server — never stored in a database, and gone the
  /// instant the room is (last player leaves / game ends and everyone
  /// exits).
  void sendChatMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    socket.send({'type': WsTypes.message, 'message': trimmed});
  }

  /// Host-only: play again with the same subject + chapters instead of
  /// leaving the room. Only valid once the game has finished.
  void rematch() {
    socket.send({'type': WsTypes.rematch});
  }

  /// Host-only: remove another player from the room. The server rejects
  /// this if the caller isn't the host or the target isn't in the room.
  void kickPlayer(String targetUserName) {
    socket.send({
      'type': WsTypes.kickPlayer,
      'targetUserName': targetUserName,
    });
  }

  /// Call once the "you were removed from the room" UI has been shown, so
  /// it doesn't fire again on the next rebuild.
  void acknowledgeKicked() {
    kicked = false;
  }

  // ── misc ──────────────────────────────────────────────────────────────────

  bool get allPlayersReady =>
      players.isNotEmpty && players.every((p) => p.isReady);

  void clearSessionExpired() {
    sessionExpired = false;
  }
}
