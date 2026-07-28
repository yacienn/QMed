export const Types = {
  JOIN: "join",
  LEFT: "left",
  MESSAGE: "message",
  ANSWER: "answer",
  AUTH: "auth",
  AUTH_FAILED: "auth_failed",
  CREATE_ROOM: "create_room",
  ROOM_UPDATE: "room_update",
  ROOM_DELETED: "room_deleted",   
  START_GAME: "start_game",
  READY: "ready",
  PLAYER_JOINED: "player_joined",
  PLAYER_LEFT: "player_left",
  GAME_STARTED: "game_started",
  ERROR: "error",
  ANSWER_RESULT: "answer_result",   
  ALL_ANSWERED: "all_answered",     
  NEXT_QUESTION: "next_question",   
  NEW_QUESTION: "new_question",    
  GAME_FINISHED: "game_finished",  
  GET_SUBJECTS: "get_subjects",   
  SUBJECTS: "subjects",            
  CONFIGURE_QUIZ: "configure_quiz",
  QUIZ_CONFIGURED: "quiz_configured",
  REMATCH: "rematch",              
  ROOM_REMATCHED: "room_rematched", 
  KICK_PLAYER: "kick_player",       
  PLAYER_KICKED: "player_kicked", 
  KICKED: "kicked",               
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
