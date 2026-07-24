import type { Request, Response } from "express";
import { getLeaderboard } from "../service/GameResult_service.js";

const DEFAULT_LEADERBOARD_LIMIT = 15;
const MAX_LEADERBOARD_LIMIT = 100;

export const getLeaderboardHandler = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const rawLimit = Number(req.query.limit);
    const limit =
      Number.isFinite(rawLimit) && rawLimit > 0
        ? Math.min(Math.trunc(rawLimit), MAX_LEADERBOARD_LIMIT)
        : DEFAULT_LEADERBOARD_LIMIT;

    const leaderboard = await getLeaderboard(limit);
    res.status(200).json({ leaderboard });
  } catch (e) {
    const message = e instanceof Error ? e.message : "Unknown error";
    res.status(500).json({ message });
  }
};
