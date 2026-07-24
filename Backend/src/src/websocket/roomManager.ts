import { Player } from "../models/Player.js";
import { Room, ChatMessage } from "../models/Room.js";
import { gameState, Roles } from "../models/Types.js";
import { AuthenticatedWebSocket } from "../models/Websocket.js";
import {
    getQuestionsBySelection,
    MIN_QUESTIONS_PER_GAME,
    toPublicQuestion,
    type PublicQuestion,
} from "../service/Question_service.js";


const ROOM_ID_LENGTH = 6;
const DEFAULT_SCORE_INCREMENT = 5;
const MAX_PLAYERS = 6; 
const MAX_CHAT_MESSAGES = 50; // ring buffer — oldest messages drop off, nothing is ever persisted
const MAX_CHAT_MESSAGE_LENGTH = 300;

// How long players get to answer each question before the server forces a
// reveal on their behalf. Sent to clients (as `timeLimit`) alongside
// GAME_STARTED/NEW_QUESTION so the UI can render a matching countdown.
export const QUESTION_TIME_LIMIT_SECONDS = 20;

const rooms = new Map<string, Room>();


export function getRoom(roomId: string): Room | undefined {
    return rooms.get(roomId);
}


export function getPlayer(room: Room, client: AuthenticatedWebSocket): Player | undefined {
    return room.players.find(player => player.socket === client);
}

export const generateId = (): string => {
    const characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    let id = "";

    for (let i = 0; i < ROOM_ID_LENGTH; i++) {
        const randomIndex = Math.floor(Math.random() * characters.length);
        id += characters[randomIndex];
    }
    return id;
};

// Plain, JSON-safe representation of a player. Room.players holds live
// `socket` references which can't (and shouldn't) be sent to clients.
export interface PlayerSnapshot {
    userName: string | undefined;
    role: Roles;
    isReady: boolean;
    score: number;
    hasAnswered: boolean; // ← new: has this player answered the *current* question
}

export interface RoomSnapshot {
    roomId: string;
    state: gameState;
    players: PlayerSnapshot[];
    currentQuestion: number;  // ← new: 0-based index of the current question
    totalQuestions: number;   // ← new: how many questions this game has in total
    subject?: string;         // ← new: subject the host picked for this room's quiz
    chapters?: number[];      // ← new: chapters the host picked
    quizConfigured: boolean;  // ← new: true once the host has picked subject + chapters
}

export function serializeRoom(room: Room): RoomSnapshot {
    return {
        roomId: room.id,
        state: room.state,
        players: room.players.map(p => ({
            userName: p.socket.user?.userName,
            role: p.role,
            isReady: p.isReady,
            score: p.score,
            hasAnswered: p.answeredQuestion === room.currentQuestion,
        })),
        currentQuestion: room.currentQuestion,
        totalQuestions: room.questions.length,
        subject: room.subject,
        chapters: room.chapters,
        quizConfigured: room.quizConfigured,
    };
}

export function createRoom(client: AuthenticatedWebSocket): Room {
    let roomId = generateId();

    while (rooms.has(roomId)) {
        roomId = generateId();
    }

    const host: Player = {
        socket: client,
        role: Roles.HOST,
        score: 0,
        isReady: false,
        answeredQuestion: -1,
    };

    const room: Room = {
        id: roomId,
        players: [host],
        state: gameState.LOBBY,
        questions: [], // populated once the host configures a subject + chapters
        currentQuestion: 0,
        quizConfigured: false,
        chatMessages: [],
    };

    rooms.set(roomId, room);

    return room;
}

export type JoinRoomFailureReason = "not_found" | "already_joined" | "room_full";

export type JoinRoomResult =
    | { success: true }
    | { success: false; reason: JoinRoomFailureReason };

export function joinRoom(
    roomId: string,
    client: AuthenticatedWebSocket
): JoinRoomResult {
    const room = rooms.get(roomId);
    if (!room) {
        return { success: false, reason: "not_found" };
    }

    const alreadyJoined = getPlayer(room, client);
    if (alreadyJoined) {
        return { success: false, reason: "already_joined" };
    }

    if (room.players.length >= MAX_PLAYERS) {
        return { success: false, reason: "room_full" };
    }

    const player: Player = {
        socket: client,
        role: Roles.JOINER,
        score: 0,
        isReady: false,
        answeredQuestion: -1,
    };
    room.players.push(player);
    return { success: true };
}

export function leaveRoom(
    roomId: string,
    client: AuthenticatedWebSocket
): void {
    const room = rooms.get(roomId);
    if (!room) {
        return;
    }
    const index = room.players.findIndex(
        player => player.socket === client
    );
    if (index === -1) {
        return;
    }

    const leavingPlayer = room.players[index];
    room.players.splice(index, 1);

    if (room.players.length === 0) {
        rooms.delete(roomId);
        return;
    }

    if (leavingPlayer && leavingPlayer.role === Roles.HOST) {
        const newHost = room.players[0];
        if (newHost) {
            newHost.role = Roles.HOST;
        }
    }
}

export type KickPlayerFailureReason =
    | "not_found"
    | "not_in_room"
    | "not_host"
    | "target_not_found"
    | "cannot_kick_self";

export type KickPlayerResult =
    | { success: true; kickedSocket: AuthenticatedWebSocket }
    | { success: false; reason: KickPlayerFailureReason };

// Host-only: forcibly remove another player from the room. Returns the
// removed player's socket so the caller (websocket/server.ts) can notify
// them and close their connection — closing sockets isn't roomManager's job.
export function kickPlayer(
    roomId: string,
    client: AuthenticatedWebSocket,
    targetUserName: string
): KickPlayerResult {
    const room = rooms.get(roomId);
    if (!room) {
        return { success: false, reason: "not_found" };
    }

    const host = getPlayer(room, client);
    if (!host) {
        return { success: false, reason: "not_in_room" };
    }
    if (host.role !== Roles.HOST) {
        return { success: false, reason: "not_host" };
    }

    const targetIndex = room.players.findIndex(
        p => p.socket.user?.userName === targetUserName
    );
    if (targetIndex === -1) {
        return { success: false, reason: "target_not_found" };
    }

    const target = room.players[targetIndex]!;
    if (target === host) {
        return { success: false, reason: "cannot_kick_self" };
    }

    room.players.splice(targetIndex, 1);

    return { success: true, kickedSocket: target.socket };
}

export type PostKickRevealResult =
    // Room wasn't mid-question (lobby/finished, or no players left), or not
    // every remaining player has answered yet — caller has nothing to reveal.
    | { allAnswered: false }
    // The kicked player was the only one still holding up the reveal —
    // everyone left has now answered, so the caller should broadcast the
    // reveal exactly like it would if the last player had answered normally.
    | { allAnswered: true; correctChoiceId: number | null; explanation: string | null };

// Called right after a successful kick, while the game is running. Removing
// a player can complete the "has everyone answered?" gate for whoever is
// left — e.g. a room of 3 where 2 have answered and the 3rd (unanswered)
// player gets kicked should immediately reveal, not leave the survivors
// waiting on a timer for someone who is no longer in the room.
export function checkAllAnsweredAfterKick(roomId: string): PostKickRevealResult {
    const room = rooms.get(roomId);
    if (!room || room.state !== gameState.START || room.players.length === 0) {
        return { allAnswered: false };
    }

    const allAnswered = room.players.every(
        p => p.answeredQuestion === room.currentQuestion
    );
    if (!allAnswered) {
        return { allAnswered: false };
    }

    const question = room.questions[room.currentQuestion];
    const correctChoice = question?.choices.find(choice => choice.correct);

    return {
        allAnswered: true,
        correctChoiceId: correctChoice?.id ?? null,
        explanation: question?.explanation ?? null,
    };
}

export type ConfigureQuizFailureReason =
    | "not_found"
    | "not_in_room"
    | "not_host"
    | "already_started"
    | "invalid_selection"
    | "not_enough_questions";

export type ConfigureQuizResult =
    | { success: true; questionCount: number }
    | { success: false; reason: ConfigureQuizFailureReason };

// Host-only: pick which subject + chapters this room's questions come from.
// Can be called again (e.g. to change the choice) as long as the game
// hasn't started yet.
export function configureQuiz(
    roomId: string,
    client: AuthenticatedWebSocket,
    subject: string,
    chapters: number[]
): ConfigureQuizResult {
    const room = rooms.get(roomId);
    if (!room) {
        return { success: false, reason: "not_found" };
    }

    const player = getPlayer(room, client);
    if (!player) {
        return { success: false, reason: "not_in_room" };
    }
    if (player.role !== Roles.HOST) {
        return { success: false, reason: "not_host" };
    }
    if (room.state !== gameState.LOBBY) {
        return { success: false, reason: "already_started" };
    }
    if (!subject || !Array.isArray(chapters) || chapters.length === 0) {
        return { success: false, reason: "invalid_selection" };
    }

    const questions = getQuestionsBySelection(subject, chapters);
    if (questions.length < MIN_QUESTIONS_PER_GAME) {
        return { success: false, reason: "not_enough_questions" };
    }

    room.subject = subject;
    room.chapters = [...chapters].sort((a, b) => a - b);
    room.questions = questions;
    room.quizConfigured = true;
    room.currentQuestion = 0;

    return { success: true, questionCount: questions.length };
}

export function startGame(roomId: string, client: AuthenticatedWebSocket): boolean {
    const room = rooms.get(roomId);

    if (!room || room.state === gameState.START) {
        return false;
    }

    if (room.players.length < 2) {
        return false;
    }

    if (!room.quizConfigured || room.questions.length === 0) {
        return false;
    }

    const player = getPlayer(room, client);
    const allIsReady = room.players.every(p => p.isReady);

    if (!player || player.role !== Roles.HOST || !allIsReady) {
        return false;
    }

    room.state = gameState.START;
    room.currentQuestion = 0;
    room.players.forEach(p => {
        p.isReady = false;
        p.answeredQuestion = -1;
    });
    return true;
}

export function setReady(
    roomId: string,
    client: AuthenticatedWebSocket,
    ready: boolean = true
): boolean {
    const room = rooms.get(roomId);
    if (!room) {
        return false;
    }
    const player = getPlayer(room, client);
    if (!player) {
        return false;
    }
    player.isReady = ready;
    return true;
}

export function increaseScore(
    roomId: string,
    client: AuthenticatedWebSocket,
    points: number = DEFAULT_SCORE_INCREMENT
): number | undefined {
    const room = rooms.get(roomId);
    if (!room) {
        return;
    }
    const player = getPlayer(room, client);
    if (!player) {
        return;
    }
    player.score += points;
    return player.score;
}

export type SubmitAnswerFailureReason =
    | "not_found"
    | "not_in_room"
    | "not_started"
    | "already_answered"
    | "invalid_question";

export type SubmitAnswerResult =
    | {
          success: true;
          correct: boolean;
          score: number;
          allAnswered: boolean;
          // Only populated once `allAnswered` is true — this is the moment the
          // correct answer is allowed to be revealed to the whole room.
          reveal?: { correctChoiceId: number; explanation: string };
      }
    | { success: false; reason: SubmitAnswerFailureReason };

// Records a player's answer for the room's current question, awards points
// on a correct answer, and reports whether every player has now answered.
export function submitAnswer(
    roomId: string,
    client: AuthenticatedWebSocket,
    answerId: number
): SubmitAnswerResult {
    const room = rooms.get(roomId);
    if (!room) {
        return { success: false, reason: "not_found" };
    }
    if (room.state !== gameState.START) {
        return { success: false, reason: "not_started" };
    }

    const player = getPlayer(room, client);
    if (!player) {
        return { success: false, reason: "not_in_room" };
    }

    if (player.answeredQuestion === room.currentQuestion) {
        return { success: false, reason: "already_answered" };
    }

    const question = room.questions[room.currentQuestion];
    if (!question) {
        return { success: false, reason: "invalid_question" };
    }

    const correct = question.choices.some(
        choice => choice.id === answerId && choice.correct
    );

    player.answeredQuestion = room.currentQuestion;
    if (correct) {
        player.score += DEFAULT_SCORE_INCREMENT;
    }

    const allAnswered = room.players.every(
        p => p.answeredQuestion === room.currentQuestion
    );

    if (!allAnswered) {
        return { success: true, correct, score: player.score, allAnswered };
    }

    const correctChoice = question.choices.find(choice => choice.correct);
    return {
        success: true,
        correct,
        score: player.score,
        allAnswered,
        reveal: correctChoice
            ? { correctChoiceId: correctChoice.id, explanation: question.explanation }
            : undefined,
    };
}

export type TimeUpResult =
    | { success: false }
    // Every player had already answered by the time the timer fired — the
    // normal reveal already happened, so the caller has nothing to do.
    | { success: true; alreadyRevealed: true }
    | {
          success: true;
          alreadyRevealed: false;
          correctChoiceId: number | null;
          explanation: string | null;
      };

// Called by websocket/server.ts when a question's timer expires. Any player
// who hasn't answered yet is marked as answered (no points awarded) so the
// "waiting for all players" gate opens and the reveal can happen exactly
// like it would if everyone had answered in time.
export function timeUpForQuestion(roomId: string, questionIndex: number): TimeUpResult {
    const room = rooms.get(roomId);
    if (!room || room.state !== gameState.START) {
        return { success: false };
    }
    // A stale timer firing for a question the room has already moved past.
    if (room.currentQuestion !== questionIndex) {
        return { success: false };
    }

    const alreadyAllAnswered = room.players.every(
        p => p.answeredQuestion === room.currentQuestion
    );
    if (alreadyAllAnswered) {
        return { success: true, alreadyRevealed: true };
    }

    room.players.forEach(p => {
        if (p.answeredQuestion !== room.currentQuestion) {
            p.answeredQuestion = room.currentQuestion;
        }
    });

    const question = room.questions[room.currentQuestion];
    const correctChoice = question?.choices.find(choice => choice.correct);

    return {
        success: true,
        alreadyRevealed: false,
        correctChoiceId: correctChoice?.id ?? null,
        explanation: question?.explanation ?? null,
    };
}

export type NextQuestionFailureReason =
    | "not_found"
    | "not_in_room"
    | "not_host"
    | "not_started"
    | "not_all_answered";

export type NextQuestionResult =
    | { success: true; finished: true }
    | { success: true; finished: false; question: PublicQuestion }
    | { success: false; reason: NextQuestionFailureReason };

// Advances the room to the next question (host-only, and only once every
// player has answered the current one). Marks the room FINISHED once the
// last question has been passed.
export function nextQuestion(
    roomId: string,
    client: AuthenticatedWebSocket
): NextQuestionResult {
    const room = rooms.get(roomId);
    if (!room) {
        return { success: false, reason: "not_found" };
    }
    if (room.state !== gameState.START) {
        return { success: false, reason: "not_started" };
    }

    const player = getPlayer(room, client);
    if (!player) {
        return { success: false, reason: "not_in_room" };
    }
    if (player.role !== Roles.HOST) {
        return { success: false, reason: "not_host" };
    }

    const allAnswered = room.players.every(
        p => p.answeredQuestion === room.currentQuestion
    );
    if (!allAnswered) {
        return { success: false, reason: "not_all_answered" };
    }

    room.currentQuestion += 1;

    if (room.currentQuestion >= room.questions.length) {
        room.state = gameState.FINISHED;
        return { success: true, finished: true };
    }

    room.players.forEach(p => {
        p.answeredQuestion = -1;
    });

    return { success: true, finished: false, question: toPublicQuestion(room.questions[room.currentQuestion]!) };
}

// ── chat ─────────────────────────────────────────────────────────────────────
// Entirely in-memory: lives on the Room object, so it's gone the instant the
// room is deleted. Never touches a database.

export type SendChatFailureReason = "not_found" | "not_in_room" | "empty_message";

export type SendChatResult =
    | { success: true; chatMessage: ChatMessage }
    | { success: false; reason: SendChatFailureReason };

export function sendChatMessage(
    roomId: string,
    client: AuthenticatedWebSocket,
    message: string
): SendChatResult {
    const room = rooms.get(roomId);
    if (!room) {
        return { success: false, reason: "not_found" };
    }
    const player = getPlayer(room, client);
    if (!player) {
        return { success: false, reason: "not_in_room" };
    }

    const trimmed = message.trim().slice(0, MAX_CHAT_MESSAGE_LENGTH);
    if (!trimmed) {
        return { success: false, reason: "empty_message" };
    }

    const chatMessage: ChatMessage = {
        username: client.user?.userName ?? "Unknown",
        message: trimmed,
        timestamp: Date.now(),
    };

    room.chatMessages.push(chatMessage);
    if (room.chatMessages.length > MAX_CHAT_MESSAGES) {
        room.chatMessages.shift();
    }

    return { success: true, chatMessage };
}

// ── rematch ──────────────────────────────────────────────────────────────────

export type RematchFailureReason =
    | "not_found"
    | "not_in_room"
    | "not_host"
    | "not_finished"
    | "no_quiz_configured";

export type RematchResult =
    | { success: true; questionCount: number }
    | { success: false; reason: RematchFailureReason };

// Host-only: replay the same subject + chapters with a freshly shuffled
// question set, everyone's score reset to 0, back in the lobby waiting for
// ready-up — instead of everyone having to leave and re-join a new room.
export function rematchRoom(roomId: string, client: AuthenticatedWebSocket): RematchResult {
    const room = rooms.get(roomId);
    if (!room) {
        return { success: false, reason: "not_found" };
    }

    const player = getPlayer(room, client);
    if (!player) {
        return { success: false, reason: "not_in_room" };
    }
    if (player.role !== Roles.HOST) {
        return { success: false, reason: "not_host" };
    }
    if (room.state !== gameState.FINISHED) {
        return { success: false, reason: "not_finished" };
    }
    if (!room.subject || !room.chapters || room.chapters.length === 0) {
        return { success: false, reason: "no_quiz_configured" };
    }

    const questions = getQuestionsBySelection(room.subject, room.chapters);
    if (questions.length < MIN_QUESTIONS_PER_GAME) {
        return { success: false, reason: "no_quiz_configured" };
    }

    room.questions = questions;
    room.currentQuestion = 0;
    room.state = gameState.LOBBY;
    room.players.forEach(p => {
        p.score = 0;
        p.isReady = false;
        p.answeredQuestion = -1;
    });

    return { success: true, questionCount: questions.length };
}