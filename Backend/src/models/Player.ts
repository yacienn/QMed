import { Roles } from "./Types.js";
import { AuthenticatedWebSocket } from "./Websocket.js";

export interface Player {
    socket: AuthenticatedWebSocket;
    role: Roles;
    score: number;
    isReady: boolean;
    answeredQuestion: number;
}