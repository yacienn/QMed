import { Types } from "../models/Types.js";

export interface WebSocketMessage {
    type: Types;
    userName: string;
    message?: string;
    roomId?: string;
}