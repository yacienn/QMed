class WsTypes {
  WsTypes._();

  static const join = 'join';
  static const left = 'left';
  static const message = 'message';
  static const answer = 'answer';
  static const auth = 'auth';
  static const authFailed = 'auth_failed';
  static const createRoom = 'create_room';
  static const roomUpdate = 'room_update';
  static const startGame = 'start_game';
  static const ready = 'ready';
  static const playerJoined = 'player_joined';
  static const playerLeft = 'player_left';
  static const gameStarted = 'game_started';
  static const roomDeleted = 'room_deleted';
  static const error = 'error';
  static const answerResult = 'answer_result';
  static const allAnswered = 'all_answered';
  static const nextQuestion = 'next_question';
  static const newQuestion = 'new_question';
  static const gameFinished = 'game_finished';
  static const getSubjects = 'get_subjects';
  static const subjects = 'subjects';
  static const configureQuiz = 'configure_quiz';
  static const quizConfigured = 'quiz_configured';
  static const rematch = 'rematch';
  static const roomRematched = 'room_rematched';
  static const kickPlayer = 'kick_player';
  static const playerKicked = 'player_kicked';
  static const kicked = 'kicked';
}
