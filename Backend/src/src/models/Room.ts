import { Player } from "./Player.js";
import { gameState } from "./Types.js";
import { Question } from "./Questions.js";

// In-memory only — never persisted. Lives exactly as long as the Room does,
// so it disappears the moment the room is deleted (last player leaves).
export interface ChatMessage {
    username: string;
    message: string;
    timestamp: number;
}

export interface Room {
    id: string ;
    players: Player[] ;  
    state: gameState ;
    questions: Question[];
    currentQuestion: number ;
    subject?: string; // 
    chapters?: number[]; 
    quizConfigured: boolean; 
    chatMessages: ChatMessage[]; // ← new: ephemeral, in-memory room chat history
}
