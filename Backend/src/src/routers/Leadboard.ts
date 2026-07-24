import express from "express";
import { getLeaderboardHandler } from "../controllers/Leaderboard.js";

const router = express.Router();

router.get("/leaderboard", getLeaderboardHandler);

export default router;
