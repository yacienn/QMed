import WebSocket from "ws";
import { Types } from "../models/Types.js";
import { WebSocketMessage } from "../models/Websocket.js";
const socket = new WebSocket("ws://localhost:3000");
//npx tsx src/websocket/client.ts
const message:WebSocketMessage = {
  userName: "yacine",
  message: "hello server",
  type : Types.ANSWER ,
};

socket.on("open", () => {
  console.log("Connected!");
  socket.send(JSON.stringify(message));
});

socket.on("message", (data) => {
  console.log("Server:", data.toString());
});

socket.on("error", (err: Error) => {
  console.error("Error:", err.message);
});

socket.on("close", () => {
  console.log("Connection closed");
});
