# Use Node.js 20 LTS version (required for Firebase packages)
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Configure npm to ignore platform-specific packages and install dependencies
RUN npm config set ignore-scripts true && \
    npm install --legacy-peer-deps --force || \
    (npm config set ignore-scripts false && npm install --legacy-peer-deps --force)

# Copy all project files
COPY . .

# Expose the port your app runs on (change if different)
EXPOSE 3000

# Start the application
CMD ["npm", "start"]