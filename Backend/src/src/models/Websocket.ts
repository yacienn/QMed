import { Types } from "./Types.js"; // FIX: was "../models/Types.js" — this file already lives in models/, so the path pointed one level too high
import { WebSocket } from "ws";
import type { JwtPayload } from './User.js';

export interface WebSocketMessage {
    type: Types;
    userName: string;
    message?: string;
    roomId?: string;
    token?: string | undefined;
    ready?: boolean; // ADDED: lets READY toggle on/off instead of only ever setting true
    answerId?: number; // ADDED: the choice id the player picked, sent with the ANSWER message
    subject?: string; // ADDED: sent with CONFIGURE_QUIZ, the subject the host picked
    chapters?: number[]; // ADDED: sent with CONFIGURE_QUIZ, the chapter numbers the host picked
    targetUserName?: string; // ADDED: sent with KICK_PLAYER, the userName of the player to remove
}


export type ClientMessage = WebSocketMessage;

export interface AuthenticatedWebSocket extends WebSocket {
    user?: JwtPayload;
    roomId?: string; // ADDED: needed so the message handler knows which room this client belongs to
}