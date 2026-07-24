import { pool } from "../config/db.js";

export interface GameResultRow {
    userId: number;
    score: number;
}

// Persists the final score of every (authenticated) player in a finished
// game: one history row in game_results, plus a running-total bump on
// users.score — done in a single transaction per player so the two never
// drift apart. Best-effort: logs and swallows DB errors so a persistence
// hiccup never breaks the live game for connected players.
export async function saveGameResults(
    roomId: string,
    results: GameResultRow[]
): Promise<void> {
    if (results.length === 0) return;

    const client = await pool.connect();
    try {
        await client.query("BEGIN");
        for (const { userId, score } of results) {
            await client.query(
                "INSERT INTO game_results (room_id, user_id, score) VALUES ($1, $2, $3)",
                [roomId, userId, score]
            );
            await client.query(
                "UPDATE users SET score = score + $1 WHERE id = $2",
                [score, userId]
            );
        }
        await client.query("COMMIT");
    } catch (e) {
        await client.query("ROLLBACK");
        console.error(`Failed to save game results for room ${roomId}:`, e);
    } finally {
        client.release();
    }
}

export interface LeaderboardEntry {
    userId: number;
    userName: string;
    totalScore: number;
    gamesPlayed: number;
    bestScore: number;
}

interface LeaderboardRow {
    user_id: number;
    userName: string;
    total_score: string;
    games_played: string;
    best_score: string;
}

// All-time leaderboard, ranked by each player's cumulative score
// (users.score — kept up to date by saveGameResults above).
export async function getLeaderboard(limit = 20): Promise<LeaderboardEntry[]> {
    const result = await pool.query<LeaderboardRow>(
        `SELECT
            u.id AS user_id,
            u.username AS "userName",
            u.score AS total_score,
            COUNT(gr.id) AS games_played,
            COALESCE(MAX(gr.score), 0) AS best_score
         FROM users u
         LEFT JOIN game_results gr ON gr.user_id = u.id
         GROUP BY u.id, u.username, u.score
         ORDER BY u.score DESC
         LIMIT $1`,
        [limit]
    );

    return result.rows.map(row => ({
        userId: row.user_id,
        userName: row.userName,
        totalScore: Number(row.total_score),
        gamesPlayed: Number(row.games_played),
        bestScore: Number(row.best_score),
    }));
}
