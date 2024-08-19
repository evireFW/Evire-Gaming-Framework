// queries.ts

import { Pool } from 'pg';
import { Player, Game, LeaderboardEntry } from './models';

// Database connection pool
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: parseInt(process.env.DB_PORT || '5432'),
});

// Player queries
export const playerQueries = {
  async getPlayerById(id: string): Promise<Player | null> {
    const query = 'SELECT * FROM players WHERE id = $1';
    const result = await pool.query(query, [id]);
    return result.rows[0] || null;
  },

  async createPlayer(player: Omit<Player, 'id'>): Promise<Player> {
    const { username, walletAddress, createdAt } = player;
    const query = 'INSERT INTO players (username, wallet_address, created_at) VALUES ($1, $2, $3) RETURNING *';
    const result = await pool.query(query, [username, walletAddress, createdAt]);
    return result.rows[0];
  },

  async updatePlayerStats(id: string, xp: number, level: number): Promise<void> {
    const query = 'UPDATE players SET xp = $1, level = $2 WHERE id = $3';
    await pool.query(query, [xp, level, id]);
  },
};

// Game queries
export const gameQueries = {
  async getGameById(id: string): Promise<Game | null> {
    const query = 'SELECT * FROM games WHERE id = $1';
    const result = await pool.query(query, [id]);
    return result.rows[0] || null;
  },

  async createGame(game: Omit<Game, 'id'>): Promise<Game> {
    const { name, contractAddress, createdAt } = game;
    const query = 'INSERT INTO games (name, contract_address, created_at) VALUES ($1, $2, $3) RETURNING *';
    const result = await pool.query(query, [name, contractAddress, createdAt]);
    return result.rows[0];
  },

  async getActiveGames(): Promise<Game[]> {
    const query = 'SELECT * FROM games WHERE status = $1';
    const result = await pool.query(query, ['active']);
    return result.rows;
  },
};

// Leaderboard queries
export const leaderboardQueries = {
  async getTopPlayers(gameId: string, limit: number = 10): Promise<LeaderboardEntry[]> {
    const query = `
      SELECT p.id, p.username, l.score
      FROM leaderboard l
      JOIN players p ON l.player_id = p.id
      WHERE l.game_id = $1
      ORDER BY l.score DESC
      LIMIT $2
    `;
    const result = await pool.query(query, [gameId, limit]);
    return result.rows;
  },

  async updateLeaderboardEntry(gameId: string, playerId: string, score: number): Promise<void> {
    const query = `
      INSERT INTO leaderboard (game_id, player_id, score)
      VALUES ($1, $2, $3)
      ON CONFLICT (game_id, player_id)
      DO UPDATE SET score = GREATEST(leaderboard.score, EXCLUDED.score)
    `;
    await pool.query(query, [gameId, playerId, score]);
  },
};

// Transaction queries
export const transactionQueries = {
  async logTransaction(playerId: string, gameId: string, amount: string, txHash: string): Promise<void> {
    const query = `
      INSERT INTO transactions (player_id, game_id, amount, tx_hash, created_at)
      VALUES ($1, $2, $3, $4, NOW())
    `;
    await pool.query(query, [playerId, gameId, amount, txHash]);
  },

  async getPlayerTransactions(playerId: string, limit: number = 50): Promise<any[]> {
    const query = `
      SELECT * FROM transactions
      WHERE player_id = $1
      ORDER BY created_at DESC
      LIMIT $2
    `;
    const result = await pool.query(query, [playerId, limit]);
    return result.rows;
  },
};

// Asset queries
export const assetQueries = {
  async getPlayerAssets(playerId: string): Promise<any[]> {
    const query = `
      SELECT a.id, a.token_id, a.metadata, g.name as game_name
      FROM assets a
      JOIN games g ON a.game_id = g.id
      WHERE a.player_id = $1
    `;
    const result = await pool.query(query, [playerId]);
    return result.rows;
  },

  async addAssetToPlayer(playerId: string, gameId: string, tokenId: string, metadata: any): Promise<void> {
    const query = `
      INSERT INTO assets (player_id, game_id, token_id, metadata)
      VALUES ($1, $2, $3, $4)
    `;
    await pool.query(query, [playerId, gameId, tokenId, JSON.stringify(metadata)]);
  },
};

// Helper function to handle database errors
export async function withErrorHandling<T>(operation: () => Promise<T>): Promise<T> {
  try {
    return await operation();
  } catch (error) {
    console.error('Database error:', error);
    throw new Error('An error occurred while accessing the database');
  }
}

// Example usage of error handling
export async function safeGetPlayerById(id: string): Promise<Player | null> {
  return withErrorHandling(() => playerQueries.getPlayerById(id));
}

// TODO: Implement caching layer for frequently accessed data
// TODO: Add queries for analytics and reporting
// TODO: Implement proper connection pooling and transaction management