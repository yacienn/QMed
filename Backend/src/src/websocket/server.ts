import { WebSocketServer, WebSocket, RawData } from "ws";
import { Types, gameState } from "../models/Types.js";
import type { AuthenticatedWebSocket, ClientMessage } from "../models/Websocket.js";
import type { JwtPayload } from "../models/User.js";
import type { Room } from "../models/Room.js";
import jwt from "jsonwebtoken";
import dotenv from "dotenv";
import {
  createRoom,
  joinRoom,
  leaveRoom,
  startGame,
  setReady,
  getRoom,
  serializeRoom,
  submitAnswer,
  nextQuestion,
  configureQuiz,
  sendChatMessage,
  rematchRoom,
  kickPlayer,
  timeUpForQuestion,
  checkAllAnsweredAfterKick,
  QUESTION_TIME_LIMIT_SECONDS,
  type SubmitAnswerFailureReason,
  type NextQuestionFailureReason,
  type ConfigureQuizFailureReason,
  type RematchFailureReason,
  type KickPlayerFailureReason,
} from "./roomManager.js";
import { saveGameResults } from "../service/GameResult_service.js";
import { getAvailableSubjects, toPublicQuestion } from "../service/Question_service.js";

dotenv.config();

const JOIN_FAILURE_MESSAGES: Record<string, string> = {
  not_found: "Room not found",
  already_joined: "You are already in this room",
  room_full: "Room is full",
};

const ANSWER_FAILURE_MESSAGES: Record<SubmitAnswerFailureReason, string> = {
  not_found: "Room not found",
  not_in_room: "You are not in this room",
  not_started: "Game has not started yet",
  already_answered: "You already answered this question",
  invalid_question: "No active question to answer",
};

const NEXT_QUESTION_FAILURE_MESSAGES: Record<NextQuestionFailureReason, string> = {
  not_found: "Room not found",
  not_in_room: "You are not in this room",
  not_host: "Only the host can move to the next question",
  not_started: "Game has not started yet",
  not_all_answered: "Waiting for all players to answer",
};

const CONFIGURE_QUIZ_FAILURE_MESSAGES: Record<ConfigureQuizFailureReason, string> = {
  not_found: "Room not found",
  not_in_room: "You are not in this room",
  not_host: "Only the host can choose the subject and chapters",
  already_started: "Cannot change the quiz once the game has started",
  invalid_selection: "Please choose a subject and at least one chapter",
  not_enough_questions: "Not enough questions in the chosen chapters",
};

const REMATCH_FAILURE_MESSAGES: Record<RematchFailureReason, string> = {
  not_found: "Room not found",
  not_in_room: "You are not in this room",
  not_host: "Only the host can start a rematch",
  not_finished: "The game hasn't finished yet",
  no_quiz_configured: "Not enough questions left to start a rematch",
};

const KICK_FAILURE_MESSAGES: Record<KickPlayerFailureReason, string> = {
  not_found: "Room not found",
  not_in_room: "You are not in this room",
  not_host: "Only the host can remove players",
  target_not_found: "That player is no longer in the room",
  cannot_kick_self: "You can't remove yourself",
};

// ── per-room question timers ─────────────────────────────────────────────────
// Keyed by roomId. When a question's timer fires, any player who hasn't
// answered yet is force-marked as answered (see timeUpForQuestion) so the
// game can proceed even if someone stalls or walks away.
const questionTimers = new Map<string, ReturnType<typeof setTimeout>>();

function clearQuestionTimer(roomId: string): void {
  const timer = questionTimers.get(roomId);
  if (timer) {
    clearTimeout(timer);
    questionTimers.delete(roomId);
  }
}

function scheduleQuestionTimer(room: Room): void {
  clearQuestionTimer(room.id);
  const questionIndex = room.currentQuestion;

  const timer = setTimeout(() => {
    questionTimers.delete(room.id);

    const result = timeUpForQuestion(room.id, questionIndex);
    if (!result.success || result.alreadyRevealed) return;

    const liveRoom = getRoom(room.id);
    if (!liveRoom) return;

    broadcastToRoom(liveRoom, {
      type: Types.ALL_ANSWERED,
      correctChoiceId: result.correctChoiceId,
      explanation: result.explanation,
      timedOut: true,
    });
    broadcastToRoom(liveRoom, { type: Types.ROOM_UPDATE, ...serializeRoom(liveRoom) });
  }, QUESTION_TIME_LIMIT_SECONDS * 1000);

  questionTimers.set(room.id, timer);
}

export function setupWebSocket(wss: WebSocketServer): void {
  wss.on("connection", (client: AuthenticatedWebSocket) => {
    const secret = process.env.JWT_SECRET;

    // ── disconnect ──────────────────────────────────────────────────────────
    client.on("close", () => {
      if (client.roomId) {
        const room = getRoom(client.roomId);
        const username = client.user?.userName;
        leaveRoom(client.roomId, client);

        if (room) {
          if (room.players.length === 0) {
            // Last player left — room is now deleted.
            // No one to notify, but we log it for diagnostics.
            clearQuestionTimer(room.id);
            console.log(`Room ${client.roomId} deleted (all players left)`);
          } else {
            broadcastToRoom(room, { type: Types.PLAYER_LEFT, username });
            broadcastToRoom(room, {
              type: Types.ROOM_UPDATE,
              ...serializeRoom(room),
            });
          }
        }
      }
      console.log("Client disconnected");
    });

    // ── message ─────────────────────────────────────────────────────────────
    client.on("message", (message: RawData) => {
      let data: ClientMessage;
      try {
        data = JSON.parse(message.toString());
      } catch (err) {
        console.error("Invalid JSON received:", err);
        return;
      }

      if (data.type !== Types.AUTH && !client.user) {
        client.close();
        return;
      }

      switch (data.type) {
        // ── auth ─────────────────────────────────────────────────────────────
        case Types.AUTH: {
          const token = data.token;
          if (!secret || !token) {
            client.send(JSON.stringify({ type: Types.AUTH_FAILED, message: "No token provided" }));
            client.close();
            return;
          }
          try {
            const decoded = jwt.verify(token, secret);
            if (typeof decoded === "string") throw new Error("Unexpected token payload shape");
            client.user = decoded as JwtPayload;
            console.log(`Client authenticated: ${client.user?.userName ?? "unknown"}`);
          } catch (err) {
            const msg = err instanceof Error ? err.message : "Authentication failed";
            client.send(JSON.stringify({ type: Types.AUTH_FAILED, message: msg }));
            client.close();
          }
          break;
        }

        // ── create room ───────────────────────────────────────────────────────
        case Types.CREATE_ROOM: {
          const room = createRoom(client);
          client.roomId = room.id;
          client.send(JSON.stringify({
            type: Types.CREATE_ROOM,
            ...serializeRoom(room),
            chatMessages: room.chatMessages,
          }));
          break;
        }

        // ── subjects/chapters ────────────────────────────────────────────────
        case Types.GET_SUBJECTS: {
          client.send(JSON.stringify({ type: Types.SUBJECTS, subjects: getAvailableSubjects() }));
          break;
        }

        // ── configure quiz (host picks subject + chapters) ─────────────────────
        case Types.CONFIGURE_QUIZ: {
          if (!client.roomId) { sendError(client, "You are not in a room"); break; }

          const subject = data.subject;
          const chapters = data.chapters;
          if (typeof subject !== "string" || !Array.isArray(chapters)) {
            sendError(client, "subject and chapters are required");
            break;
          }

          const result = configureQuiz(client.roomId, client, subject, chapters);
          if (!result.success) {
            sendError(client, CONFIGURE_QUIZ_FAILURE_MESSAGES[result.reason]);
            break;
          }

          const room = getClientRoom(client);
          if (room) {
            broadcastToRoom(room, {
              type: Types.QUIZ_CONFIGURED,
              subject: room.subject,
              chapters: room.chapters,
              questionCount: result.questionCount,
            });
            broadcastToRoom(room, { type: Types.ROOM_UPDATE, ...serializeRoom(room) });
          }
          break;
        }

        // ── join ──────────────────────────────────────────────────────────────
        case Types.JOIN: {
          if (!data.roomId) { sendError(client, "roomId is required to join"); return; }
          const result = joinRoom(data.roomId, client);
          if (!result.success) {
            sendError(client, JOIN_FAILURE_MESSAGES[result.reason] ?? "Unable to join room");
            return;
          }
          client.roomId = data.roomId;
          const room = getClientRoom(client);
          if (!room) { sendError(client, "Room no longer exists"); return; }

          client.send(JSON.stringify({
            type: Types.JOIN,
            ...serializeRoom(room),
            chatMessages: room.chatMessages,
          }));
          broadcastToRoom(room, { type: Types.PLAYER_JOINED, username: client.user?.userName });
          broadcastToRoom(room, { type: Types.ROOM_UPDATE, ...serializeRoom(room) });
          break;
        }

        // ── leave ─────────────────────────────────────────────────────────────
        case Types.LEFT: {
          const room = getClientRoom(client);
          if (!room || !client.roomId) break;

          const wasLastPlayer = room.players.length === 1;
          leaveRoom(client.roomId, client);
          client.roomId = undefined;

          if (wasLastPlayer) {
            // Room is now gone — nothing to broadcast.
            clearQuestionTimer(room.id);
            console.log(`Room deleted because last player left voluntarily`);
          } else {
            broadcastToRoom(room, { type: Types.PLAYER_LEFT, username: client.user?.userName });
            broadcastToRoom(room, { type: Types.ROOM_UPDATE, ...serializeRoom(room) });

            // Same as a kick: if the player who just left was the last one
            // the room was waiting on to answer, reveal now.
            const reveal = checkAllAnsweredAfterKick(room.id);
            if (reveal.allAnswered) {
              clearQuestionTimer(room.id);
              broadcastToRoom(room, {
                type: Types.ALL_ANSWERED,
                correctChoiceId: reveal.correctChoiceId,
                explanation: reveal.explanation,
                timedOut: false,
              });
            }
          }
          break;
        }

        // ── ready ─────────────────────────────────────────────────────────────
        case Types.READY: {
          if (!client.roomId) { sendError(client, "You are not in a room"); break; }
          const readyState = data.ready ?? true;
          const ok = setReady(client.roomId, client, readyState);
          if (!ok) { sendError(client, "Unable to set ready state"); break; }
          const room = getClientRoom(client);
          if (room) {
            broadcastToRoom(room, {
              type: Types.READY,
              username: client.user?.userName,
              ready: readyState,
            });
            broadcastToRoom(room, { type: Types.ROOM_UPDATE, ...serializeRoom(room) });
          }
          break;
        }

        // ── start game ────────────────────────────────────────────────────────
        case Types.START_GAME: {
          if (!client.roomId) { sendError(client, "You are not in a room"); break; }
          const started = startGame(client.roomId, client);
          if (!started) { sendError(client, "Unable to start game"); break; }
          const room = getClientRoom(client);
          if (room) {
            const firstQuestion = room.questions[room.currentQuestion];
            broadcastToRoom(room, {
              type: Types.GAME_STARTED,
              question: firstQuestion ? toPublicQuestion(firstQuestion) : null,
              timeLimit: QUESTION_TIME_LIMIT_SECONDS,
            });
            broadcastToRoom(room, { type: Types.ROOM_UPDATE, ...serializeRoom(room) });
            scheduleQuestionTimer(room);
          }
          break;
        }

        // ── answer ────────────────────────────────────────────────────────────
        case Types.ANSWER: {
          const room = getClientRoom(client);
          if (!room) { sendError(client, "You are not in a room"); break; }
          if (room.state !== gameState.START) { sendError(client, "Game has not started yet"); break; }

          const answerId = data.answerId;
          if (typeof answerId !== "number") { sendError(client, "answerId is required"); break; }

          const result = submitAnswer(room.id, client, answerId);
          if (!result.success) {
            sendError(client, ANSWER_FAILURE_MESSAGES[result.reason]);
            break;
          }

          // Let the answering player know if they got it right, and everyone
          // else know that this player has answered (via the room update).
          client.send(JSON.stringify({
            type: Types.ANSWER_RESULT,
            correct: result.correct,
            score: result.score,
          }));
          broadcastToRoom(room, { type: Types.ANSWER, username: client.user?.userName });
          broadcastToRoom(room, { type: Types.ROOM_UPDATE, ...serializeRoom(room) });

          if (result.allAnswered) {
            // Everyone answered before the timer fired — cancel it so it
            // doesn't fire a redundant/stale reveal later.
            clearQuestionTimer(room.id);
            // This is the one moment the correct answer is allowed out — sent
            // to the whole room at once, so nobody sees it before anyone else.
            broadcastToRoom(room, {
              type: Types.ALL_ANSWERED,
              correctChoiceId: result.reveal?.correctChoiceId ?? null,
              explanation: result.reveal?.explanation ?? null,
              timedOut: false,
            });
          }
          break;
        }

        // ── next question ────────────────────────────────────────────────────
        case Types.NEXT_QUESTION: {
          const room = getClientRoom(client);
          if (!room) { sendError(client, "You are not in a room"); break; }

          const result = nextQuestion(room.id, client);
          if (!result.success) {
            sendError(client, NEXT_QUESTION_FAILURE_MESSAGES[result.reason]);
            break;
          }

          if (result.finished) {
            clearQuestionTimer(room.id);
            // Best-effort persistence — only counts players with a real
            // account id (every authenticated player has one).
            const gameResults = room.players
              .map(p => ({ userId: p.socket.user?.id, score: p.score }))
              .filter((r): r is { userId: number; score: number } => r.userId !== undefined);
            void saveGameResults(room.id, gameResults);

            broadcastToRoom(room, { type: Types.GAME_FINISHED, ...serializeRoom(room) });
          } else {
            broadcastToRoom(room, {
              type: Types.NEW_QUESTION,
              question: result.question,
              timeLimit: QUESTION_TIME_LIMIT_SECONDS,
            });
            broadcastToRoom(room, { type: Types.ROOM_UPDATE, ...serializeRoom(room) });
            scheduleQuestionTimer(room);
          }
          break;
        }

        // ── chat message ─────────────────────────────────────────────────────
        case Types.MESSAGE: {
          if (!client.roomId) { sendError(client, "You are not in a room"); break; }

          const text = data.message;
          if (typeof text !== "string") { sendError(client, "message is required"); break; }

          const result = sendChatMessage(client.roomId, client, text);
          if (!result.success) {
            // Silently drop empty/whitespace-only messages; anything else is
            // a real error worth surfacing.
            if (result.reason !== "empty_message") {
              sendError(client, "Unable to send message");
            }
            break;
          }

          const room = getClientRoom(client);
          if (room) {
            broadcastToRoom(room, {
              type: Types.MESSAGE,
              username: result.chatMessage.username,
              message: result.chatMessage.message,
              timestamp: result.chatMessage.timestamp,
            });
          }
          break;
        }

        // ── rematch (play again) ─────────────────────────────────────────────
        case Types.REMATCH: {
          if (!client.roomId) { sendError(client, "You are not in a room"); break; }

          const result = rematchRoom(client.roomId, client);
          if (!result.success) {
            sendError(client, REMATCH_FAILURE_MESSAGES[result.reason]);
            break;
          }

          clearQuestionTimer(client.roomId);

          const room = getClientRoom(client);
          if (room) {
            broadcastToRoom(room, { type: Types.ROOM_REMATCHED, questionCount: result.questionCount });
            broadcastToRoom(room, { type: Types.ROOM_UPDATE, ...serializeRoom(room) });
          }
          break;
        }

        // ── kick player (host only) ──────────────────────────────────────────
        case Types.KICK_PLAYER: {
          if (!client.roomId) { sendError(client, "You are not in a room"); break; }

          const targetUserName = data.targetUserName;
          if (typeof targetUserName !== "string" || !targetUserName) {
            sendError(client, "targetUserName is required");
            break;
          }

          const result = kickPlayer(client.roomId, client, targetUserName);
          if (!result.success) {
            sendError(client, KICK_FAILURE_MESSAGES[result.reason]);
            break;
          }

          const room = getClientRoom(client);
          const kickedSocket = result.kickedSocket;

          // Tell the removed player first, then detach them from the room so
          // their own "close" handler doesn't try to remove them again.
          kickedSocket.send(JSON.stringify({ type: Types.KICKED, message: "You were removed from the room by the host" }));
          kickedSocket.roomId = undefined;
          kickedSocket.close();

          if (room) {
            broadcastToRoom(room, { type: Types.PLAYER_KICKED, username: kickedSocket.user?.userName });
            broadcastToRoom(room, { type: Types.ROOM_UPDATE, ...serializeRoom(room) });

            // The kicked player may have been the last one the room was
            // waiting on to answer the current question — if so, reveal now
            // instead of leaving everyone else stuck until the timer fires.
            const reveal = checkAllAnsweredAfterKick(room.id);
            if (reveal.allAnswered) {
              clearQuestionTimer(room.id);
              broadcastToRoom(room, {
                type: Types.ALL_ANSWERED,
                correctChoiceId: reveal.correctChoiceId,
                explanation: reveal.explanation,
                timedOut: false,
              });
            }
          }
          break;
        }

        default:
          console.warn("Unknown message type:", (data as { type?: unknown }).type);
      }
    });
  });
}

// ── helpers ───────────────────────────────────────────────────────────────────

function getClientRoom(client: AuthenticatedWebSocket): Room | undefined {
  return client.roomId ? getRoom(client.roomId) : undefined;
}

function sendError(client: AuthenticatedWebSocket, message: string): void {
  client.send(JSON.stringify({ type: Types.ERROR, message }));
}

function broadcastToRoom(room: Room, payload: unknown): void {
  const msg = JSON.stringify(payload);
  room.players.forEach(({ socket }) => {
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(msg);
    }
  });
}
