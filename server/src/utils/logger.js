const fs = require('fs');
const path = require('path');

// Ensure logs directory exists
const logsDir = path.join(__dirname, '../../logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

const logFile = path.join(logsDir, 'combined.log');
const errorLogFile = path.join(logsDir, 'error.log');

class Logger {
  formatMessage(level, message, ...args) {
    const timestamp = new Date().toISOString();
    const formattedArgs = args
      .map(arg => (typeof arg === 'object' ? JSON.stringify(arg) : arg))
      .join(' ');

    return `[${timestamp}] [${level}] ${message} ${formattedArgs}`.trim();
  }

  writeToFile(message, isError = false) {
    const logMessage = message + '\n';
    fs.appendFileSync(logFile, logMessage);

    if (isError) {
      fs.appendFileSync(errorLogFile, logMessage);
    }
  }

  info(message, ...args) {
    const logMessage = this.formatMessage('INFO', message, ...args);
    console.log('\x1b[36m%s\x1b[0m', logMessage);
    this.writeToFile(logMessage);
  }

  error(message, ...args) {
    const logMessage = this.formatMessage('ERROR', message, ...args);
    console.error('\x1b[31m%s\x1b[0m', logMessage);
    this.writeToFile(logMessage, true);
  }

  debug(message, ...args) {
    const logMessage = this.formatMessage('DEBUG', message, ...args);
    console.debug('\x1b[35m%s\x1b[0m', logMessage);
    this.writeToFile(logMessage);
  }

  http(message, ...args) {
    const logMessage = this.formatMessage('HTTP', message, ...args);
    console.log('\x1b[34m%s\x1b[0m', logMessage);
    this.writeToFile(logMessage);
  }

  warn(message, ...args) {
    const logMessage = this.formatMessage('WARN', message, ...args);
    console.warn('\x1b[33m%s\x1b[0m', logMessage);
    this.writeToFile(logMessage);
  }

  success(message, ...args) {
    const logMessage = this.formatMessage('SUCCESS', message, ...args);
    console.log('\x1b[32m%s\x1b[0m', logMessage);
    this.writeToFile(logMessage);
  }
}

module.exports = new Logger();
