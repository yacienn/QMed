import  { WebSocketServer, WebSocket, RawData } from "ws";
import { Types } from "../models/Types.js";
import { WebSocketMessage } from "../models/Websocket.js";
export function setupWebSocket(wss: WebSocketServer): void {
  wss.on("connection", (socket: WebSocket) => {
    console.log("Client connected");
    socket.on("message", (message: RawData) => {
      const data = JSON.parse(message.toString());
      console.log(`${data.userName} - join`);
    });
         
    socket.on("close", () => {
      console.log("Client disconnected");
    });
    socket.on("message" , (message:RawData )=>{
      wss.clients.forEach((Client)=>{
      const data:WebSocketMessage = JSON.parse(message.toString());
      if (Client.readyState === WebSocket.OPEN && data.type === Types.ANSWER ){
        Client.send(`${data.userName} answerd` );
      }
    })
    })
  
  });
}
