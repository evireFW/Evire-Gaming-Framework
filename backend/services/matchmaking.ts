// matchmaking.ts

import { Player, Match, MatchStatus } from '../database/models';
import { findAvailablePlayers, createMatch, updatePlayerStatus } from '../database/queries';
import { calculateElo } from '../utils/eloCalculator';
import { EventEmitter } from 'events';
import { Redis } from 'ioredis';
import { logger } from '../utils/logger';

class MatchmakingService extends EventEmitter {
  private redis: Redis;
  private matchmakingQueue: Map<string, Player>;
  private matchCheckInterval: NodeJS.Timeout | null;

  constructor() {
    super();
    this.redis = new Redis(process.env.REDIS_URL);
    this.matchmakingQueue = new Map();
    this.matchCheckInterval = null;
  }

  public async init(): Promise<void> {
    try {
      await this.redis.connect();
      logger.info('Connected to Redis successfully');
      this.startMatchmakingLoop();
    } catch (error) {
      logger.error('Failed to connect to Redis:', error);
      throw error;
    }
  }

  public async addPlayerToQueue(player: Player): Promise<void> {
    this.matchmakingQueue.set(player.id, player);
    await this.redis.sadd('matchmaking:queue', player.id);
    logger.info(`Player ${player.id} added to matchmaking queue`);
    this.emit('playerAdded', player);
  }

  public async removePlayerFromQueue(playerId: string): Promise<void> {
    this.matchmakingQueue.delete(playerId);
    await this.redis.srem('matchmaking:queue', playerId);
    logger.info(`Player ${playerId} removed from matchmaking queue`);
    this.emit('playerRemoved', playerId);
  }

  private startMatchmakingLoop(): void {
    if (this.matchCheckInterval) {
      clearInterval(this.matchCheckInterval);
    }

    this.matchCheckInterval = setInterval(async () => {
      await this.checkForMatches();
    }, 5000); // Check for matches every 5 seconds
  }

  private async checkForMatches(): Promise<void> {
    const queueSize = await this.redis.scard('matchmaking:queue');
    if (queueSize < 2) return;

    const players = await findAvailablePlayers(queueSize);
    const matches = this.createMatches(players);

    for (const match of matches) {
      await this.initializeMatch(match);
    }
  }

  private createMatches(players: Player[]): Match[] {
    const matches: Match[] = [];
    const sortedPlayers = players.sort((a, b) => a.elo - b.elo);

    for (let i = 0; i < sortedPlayers.length; i += 2) {
      if (i + 1 < sortedPlayers.length) {
        const player1 = sortedPlayers[i];
        const player2 = sortedPlayers[i + 1];

        if (Math.abs(player1.elo - player2.elo) <= 200) { // ELO difference threshold
          matches.push({
            id: `match_${Date.now()}_${player1.id}_${player2.id}`,
            players: [player1, player2],
            status: MatchStatus.PENDING,
            createdAt: new Date(),
            updatedAt: new Date()
          });
        }
      }
    }

    return matches;
  }

  private async initializeMatch(match: Match): Promise<void> {
    try {
      const createdMatch = await createMatch(match);
      for (const player of match.players) {
        await this.removePlayerFromQueue(player.id);
        await updatePlayerStatus(player.id, 'IN_GAME');
      }

      logger.info(`Match ${createdMatch.id} created for players ${match.players.map(p => p.id).join(', ')}`);
      this.emit('matchCreated', createdMatch);

      // Notify game server or other services about the new match
      // TODO: Implement notification to game server
    } catch (error) {
      logger.error('Failed to initialize match:', error);
      // Handle error (e.g., retry logic or notifying affected players)
    }
  }

  public async endMatch(matchId: string, winnerId: string): Promise<void> {
    try {
      const match = await this.getMatchById(matchId);
      if (!match) {
        throw new Error(`Match ${matchId} not found`);
      }

      const winner = match.players.find(p => p.id === winnerId);
      const loser = match.players.find(p => p.id !== winnerId);

      if (!winner || !loser) {
        throw new Error(`Invalid winner or loser for match ${matchId}`);
      }

      const [newWinnerElo, newLoserElo] = calculateElo(winner.elo, loser.elo, 1);

      await Promise.all([
        updatePlayerStatus(winner.id, 'ONLINE'),
        updatePlayerStatus(loser.id, 'ONLINE'),
        this.updatePlayerElo(winner.id, newWinnerElo),
        this.updatePlayerElo(loser.id, newLoserElo),
        this.updateMatchStatus(matchId, MatchStatus.COMPLETED)
      ]);

      logger.info(`Match ${matchId} ended. Winner: ${winnerId}`);
      this.emit('matchEnded', { matchId, winnerId, newWinnerElo, newLoserElo });
    } catch (error) {
      logger.error('Failed to end match:', error);
      // Handle error (e.g., retry logic or manual intervention)
    }
  }

  private async getMatchById(matchId: string): Promise<Match | null> {
    // TODO: Implement database query to fetch match by ID
    throw new Error('Method not implemented');
  }

  private async updatePlayerElo(playerId: string, newElo: number): Promise<void> {
    // TODO: Implement database query to update player's ELO
    throw new Error('Method not implemented');
  }

  private async updateMatchStatus(matchId: string, status: MatchStatus): Promise<void> {
    // TODO: Implement database query to update match status
    throw new Error('Method not implemented');
  }

  public async shutdown(): Promise<void> {
    if (this.matchCheckInterval) {
      clearInterval(this.matchCheckInterval);
    }
    await this.redis.quit();
    logger.info('Matchmaking service shut down');
  }
}

export const matchmakingService = new MatchmakingService();