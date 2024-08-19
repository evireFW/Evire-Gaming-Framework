// leaderboard.ts

import { Player, LeaderboardEntry, GameType } from '../database/models';
import { getTopPlayersByElo, updateLeaderboardEntry } from '../database/queries';
import { Redis } from 'ioredis';
import { logger } from '../utils/logger';
import { EventEmitter } from 'events';

class LeaderboardService extends EventEmitter {
  private redis: Redis;
  private updateInterval: NodeJS.Timeout | null;
  private readonly LEADERBOARD_SIZE = 100;
  private readonly UPDATE_INTERVAL = 5 * 60 * 1000; // 5 minutes

  constructor() {
    super();
    this.redis = new Redis(process.env.REDIS_URL);
    this.updateInterval = null;
  }

  public async init(): Promise<void> {
    try {
      await this.redis.connect();
      logger.info('Leaderboard service connected to Redis successfully');
      this.startPeriodicUpdate();
    } catch (error) {
      logger.error('Failed to initialize Leaderboard service:', error);
      throw error;
    }
  }

  private startPeriodicUpdate(): void {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
    }

    this.updateInterval = setInterval(async () => {
      await this.updateAllLeaderboards();
    }, this.UPDATE_INTERVAL);
  }

  public async updateAllLeaderboards(): Promise<void> {
    try {
      const gameTypes = Object.values(GameType);
      for (const gameType of gameTypes) {
        await this.updateLeaderboard(gameType);
      }
      logger.info('All leaderboards updated successfully');
    } catch (error) {
      logger.error('Failed to update leaderboards:', error);
    }
  }

  private async updateLeaderboard(gameType: GameType): Promise<void> {
    const topPlayers = await getTopPlayersByElo(gameType, this.LEADERBOARD_SIZE);
    const leaderboardKey = `leaderboard:${gameType}`;

    const pipeline = this.redis.pipeline();
    pipeline.del(leaderboardKey);

    topPlayers.forEach((player, index) => {
      const entry: LeaderboardEntry = {
        rank: index + 1,
        playerId: player.id,
        username: player.username,
        elo: player.elo,
        wins: player.wins,
        losses: player.losses
      };
      pipeline.zadd(leaderboardKey, player.elo, JSON.stringify(entry));
    });

    await pipeline.exec();
    this.emit('leaderboardUpdated', gameType);
  }

  public async getLeaderboard(gameType: GameType, start = 0, end = -1): Promise<LeaderboardEntry[]> {
    const leaderboardKey = `leaderboard:${gameType}`;
    const entries = await this.redis.zrevrange(leaderboardKey, start, end);
    return entries.map(entry => JSON.parse(entry));
  }

  public async getPlayerRank(gameType: GameType, playerId: string): Promise<number | null> {
    const leaderboardKey = `leaderboard:${gameType}`;
    const rank = await this.redis.zrevrank(leaderboardKey, playerId);
    return rank !== null ? rank + 1 : null; // Add 1 because Redis ranks are 0-indexed
  }

  public async updatePlayerScore(gameType: GameType, player: Player): Promise<void> {
    const leaderboardKey = `leaderboard:${gameType}`;
    const entry: LeaderboardEntry = {
      rank: 0, // Rank will be determined by Redis
      playerId: player.id,
      username: player.username,
      elo: player.elo,
      wins: player.wins,
      losses: player.losses
    };

    await this.redis.zadd(leaderboardKey, player.elo, JSON.stringify(entry));
    await updateLeaderboardEntry(gameType, entry);
    this.emit('playerScoreUpdated', { gameType, playerId: player.id });
  }

  public async getTopPlayers(gameType: GameType, count: number): Promise<LeaderboardEntry[]> {
    return this.getLeaderboard(gameType, 0, count - 1);
  }

  public async getPlayerLeaderboardPosition(gameType: GameType, playerId: string): Promise<LeaderboardEntry | null> {
    const leaderboardKey = `leaderboard:${gameType}`;
    const playerEntry = await this.redis.zscore(leaderboardKey, playerId);
    
    if (playerEntry === null) {
      return null;
    }

    const rank = await this.getPlayerRank(gameType, playerId);
    const entry = JSON.parse(playerEntry);
    entry.rank = rank;

    return entry;
  }

  public async getPlayersAroundRank(gameType: GameType, rank: number, range: number): Promise<LeaderboardEntry[]> {
    const start = Math.max(0, rank - range - 1);
    const end = rank + range - 1;
    return this.getLeaderboard(gameType, start, end);
  }

  public async searchPlayersByUsername(gameType: GameType, username: string): Promise<LeaderboardEntry[]> {
    const leaderboardKey = `leaderboard:${gameType}`;
    const allEntries = await this.redis.zrange(leaderboardKey, 0, -1);
    
    const matchingEntries = allEntries
      .map(entry => JSON.parse(entry))
      .filter(entry => entry.username.toLowerCase().includes(username.toLowerCase()));

    return matchingEntries;
  }

  public async shutdown(): Promise<void> {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
    }
    await this.redis.quit();
    logger.info('Leaderboard service shut down');
  }
}

export const leaderboardService = new LeaderboardService();