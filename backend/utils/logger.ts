
/**
 * Logger Utility for Evire Gaming Framework
 * Provides structured logging functionalities.
 */

const levels = ['DEBUG', 'INFO', 'WARN', 'ERROR'];

class Logger {
    constructor(private context: string) {}

    log(level: string, message: string): void {
        if (!levels.includes(level.toUpperCase())) {
            throw new Error(`Invalid log level: ${level}`);
        }
        console.log(`[${new Date().toISOString()}] [${level.toUpperCase()}] [${this.context}] ${message}`);
    }

    debug(message: string): void {
        this.log('DEBUG', message);
    }

    info(message: string): void {
        this.log('INFO', message);
    }

    warn(message: string): void {
        this.log('WARN', message);
    }

    error(message: string): void {
        this.log('ERROR', message);
    }
}

export const createLogger = (context: string) => new Logger(context);
            