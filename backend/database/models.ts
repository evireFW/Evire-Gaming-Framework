import mongoose, { Schema, Document } from 'mongoose';

// Player Model
interface IPlayer extends Document {
  walletAddress: string;
  username: string;
  email: string;
  registrationDate: Date;
  lastLogin: Date;
  totalPlayTime: number;
  level: number;
  experience: number;
  inventory: mongoose.Types.ObjectId[];
}

const PlayerSchema: Schema = new Schema({
  walletAddress: { type: String, required: true, unique: true },
  username: { type: String, required: true, unique: true },
  email: { type: String, required: true, unique: true },
  registrationDate: { type: Date, default: Date.now },
  lastLogin: { type: Date, default: Date.now },
  totalPlayTime: { type: Number, default: 0 },
  level: { type: Number, default: 1 },
  experience: { type: Number, default: 0 },
  inventory: [{ type: Schema.Types.ObjectId, ref: 'Item' }]
});

export const Player = mongoose.model<IPlayer>('Player', PlayerSchema);

// Item Model
interface IItem extends Document {
  tokenId: string;
  name: string;
  description: string;
  type: string;
  rarity: string;
  attributes: Record<string, any>;
  ownerAddress: string;
  creationDate: Date;
  lastTransferDate: Date;
}

const ItemSchema: Schema = new Schema({
  tokenId: { type: String, required: true, unique: true },
  name: { type: String, required: true },
  description: { type: String },
  type: { type: String, required: true },
  rarity: { type: String, required: true },
  attributes: { type: Schema.Types.Mixed },
  ownerAddress: { type: String, required: true },
  creationDate: { type: Date, default: Date.now },
  lastTransferDate: { type: Date, default: Date.now }
});

export const Item = mongoose.model<IItem>('Item', ItemSchema);

// Game Session Model
interface IGameSession extends Document {
  player: mongoose.Types.ObjectId;
  gameType: string;
  startTime: Date;
  endTime: Date;
  score: number;
  rewards: {
    experience: number;
    items: mongoose.Types.ObjectId[];
  };
}

const GameSessionSchema: Schema = new Schema({
  player: { type: Schema.Types.ObjectId, ref: 'Player', required: true },
  gameType: { type: String, required: true },
  startTime: { type: Date, default: Date.now },
  endTime: { type: Date },
  score: { type: Number, default: 0 },
  rewards: {
    experience: { type: Number, default: 0 },
    items: [{ type: Schema.Types.ObjectId, ref: 'Item' }]
  }
});

export const GameSession = mongoose.model<IGameSession>('GameSession', GameSessionSchema);

// Marketplace Listing Model
interface IMarketplaceListing extends Document {
  item: mongoose.Types.ObjectId;
  seller: mongoose.Types.ObjectId;
  price: number;
  currency: string;
  listingDate: Date;
  status: 'active' | 'sold' | 'cancelled';
  transactionHash?: string;
}

const MarketplaceListingSchema: Schema = new Schema({
  item: { type: Schema.Types.ObjectId, ref: 'Item', required: true },
  seller: { type: Schema.Types.ObjectId, ref: 'Player', required: true },
  price: { type: Number, required: true },
  currency: { type: String, required: true },
  listingDate: { type: Date, default: Date.now },
  status: { type: String, enum: ['active', 'sold', 'cancelled'], default: 'active' },
  transactionHash: { type: String }
});

export const MarketplaceListing = mongoose.model<IMarketplaceListing>('MarketplaceListing', MarketplaceListingSchema);

// Leaderboard Model
interface ILeaderboard extends Document {
  gameType: string;
  timeFrame: 'daily' | 'weekly' | 'monthly' | 'allTime';
  entries: Array<{
    player: mongoose.Types.ObjectId;
    score: number;
    rank: number;
  }>;
  lastUpdated: Date;
}

const LeaderboardSchema: Schema = new Schema({
  gameType: { type: String, required: true },
  timeFrame: { type: String, enum: ['daily', 'weekly', 'monthly', 'allTime'], required: true },
  entries: [{
    player: { type: Schema.Types.ObjectId, ref: 'Player' },
    score: { type: Number, required: true },
    rank: { type: Number, required: true }
  }],
  lastUpdated: { type: Date, default: Date.now }
});

export const Leaderboard = mongoose.model<ILeaderboard>('Leaderboard', LeaderboardSchema);

// Transaction Log Model
interface ITransactionLog extends Document {
  transactionHash: string;
  fromAddress: string;
  toAddress: string;
  amount: number;
  currency: string;
  timestamp: Date;
  status: 'pending' | 'completed' | 'failed';
  type: 'transfer' | 'purchase' | 'reward' | 'other';
}

const TransactionLogSchema: Schema = new Schema({
  transactionHash: { type: String, required: true, unique: true },
  fromAddress: { type: String, required: true },
  toAddress: { type: String, required: true },
  amount: { type: Number, required: true },
  currency: { type: String, required: true },
  timestamp: { type: Date, default: Date.now },
  status: { type: String, enum: ['pending', 'completed', 'failed'], required: true },
  type: { type: String, enum: ['transfer', 'purchase', 'reward', 'other'], required: true }
});

export const TransactionLog = mongoose.model<ITransactionLog>('TransactionLog', TransactionLogSchema);

// TODO: Implement additional models as needed for game-specific features
// Such as:
// - QuestLog
// - AchievementTracker
// - PlayerFriendsList
// - ChatLog
// - GameConfig

// Export all models
export {
  Player,
  Item,
  GameSession,
  MarketplaceListing,
  Leaderboard,
  TransactionLog
};