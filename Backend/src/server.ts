import express from "express";
import AuthRouters from "./routers/Auth.js";
import LeaderboardRouters from "./routers/Leadboard.js"
import dotenv from "dotenv";
import http from "http";
import { WebSocketServer } from "ws";
import { setupWebSocket } from "./websocket/server.js";

dotenv.config();

const app = express();
const server = http.createServer(app);
const wss = new WebSocketServer({ server });
const port = process.env.PORT ?? 3000;

setupWebSocket(wss);
app.use(express.json());
app.use("/", AuthRouters);
app.use("/", LeaderboardRouters);

server.listen(port, () => {
  console.log(`server run in port ${port}`);
});
