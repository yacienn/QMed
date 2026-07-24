export const Types = {
  JOIN: "join",
  LEFT: "left",
  MESSAGE: "message",
  ANSWER: "answer",
  AUTH: "auth",
  AUTH_FAILED: "auth_failed",
  CREATE_ROOM: "create_room",
  ROOM_UPDATE: "room_update",
  ROOM_DELETED: "room_deleted",   // ← new: emitted when the last player leaves
  START_GAME: "start_game",
  READY: "ready",
  PLAYER_JOINED: "player_joined",
  PLAYER_LEFT: "player_left",
  GAME_STARTED: "game_started",
  ERROR: "error",
  ANSWER_RESULT: "answer_result",   // ← new: sent back to the answering player
  ALL_ANSWERED: "all_answered",     // ← new: broadcast when every player has answered the current question
  NEXT_QUESTION: "next_question",   // ← new: host -> server, advance to next question
  NEW_QUESTION: "new_question",     // ← new: server -> clients, here is the next question
  GAME_FINISHED: "game_finished",   // ← new: server -> clients, game over + final scores
  GET_SUBJECTS: "get_subjects",     // ← new: client -> server, request available subjects/chapters
  SUBJECTS: "subjects",             // ← new: server -> client, reply with available subjects/chapters
  CONFIGURE_QUIZ: "configure_quiz", // ← new: host -> server, choose subject + chapters for this room
  QUIZ_CONFIGURED: "quiz_configured", // ← new: server -> room, quiz selection was applied
  REMATCH: "rematch",               // ← new: host -> server, play again with the same subject+chapters
  ROOM_REMATCHED: "room_rematched", // ← new: server -> room, rematch accepted, everyone goes back to the lobby
  KICK_PLAYER: "kick_player",       // ← new: host -> server, remove a player from the room
  PLAYER_KICKED: "player_kicked",   // ← new: server -> room, tells everyone left who was removed
  KICKED: "kicked",                 // ← new: server -> the removed client only, right before closing them
} as const;
export type Types = typeof Types[keyof typeof Types];

export const Roles = {
  HOST: "host",
  JOINER: "joiner",
} as const;
export type Roles = typeof Roles[keyof typeof Roles];

export const gameState = {
  LOBBY: "lobby",
  START: "start",
  FINISHED: "finished", // ← new: reached once the last question has been passed
} as const;
export type gameState = typeof gameState[keyof typeof gameState];

export const PlayerState = {
  READY: "ready",
  IDLE: "idle",
} as const;
export type Player = typeof PlayerState[keyof typeof PlayerState];
