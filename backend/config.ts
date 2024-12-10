
// config.ts - Configuration file for the Evire Gaming Framework Backend

/**
 * Configuration constants and environment settings.
 * This file provides configuration details essential for server operations
 * within the Evire Gaming Framework backend.
 */

export const Config = {
    server: {
        port: process.env.PORT || 3000, // Default server port
        host: process.env.HOST || 'localhost', // Server host
    },
    database: {
        url: process.env.DB_URL || 'mongodb://localhost:27017/evire', // MongoDB URL
    },
    blockchain: {
        rpcUrl: process.env.RPC_URL || 'https://evire-node.network', // RPC node URL
        networkId: process.env.NETWORK_ID || 1, // Default blockchain network ID
    },
    security: {
        jwtSecret: process.env.JWT_SECRET || 'your-secure-jwt-secret', // JWT Secret for authentication
        encryptionSaltRounds: parseInt(process.env.SALT_ROUNDS) || 10, // Salt rounds for password hashing
    },
    gameMechanics: {
        defaultCurrency: 'EVR', // Default in-game currency
    },
    logging: {
        level: process.env.LOG_LEVEL || 'info', // Logging level
    },
};

/**
 * Validate essential environment variables and provide fallbacks.
 */
function validateConfig() {
    if (!Config.security.jwtSecret) {
        console.error('JWT_SECRET is not set! Exiting.');
        process.exit(1);
    }
    if (!Config.database.url) {
        console.error('Database URL is not configured! Exiting.');
        process.exit(1);
    }
}

validateConfig();

export default Config;
