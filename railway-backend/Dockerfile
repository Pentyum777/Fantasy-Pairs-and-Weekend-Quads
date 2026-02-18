FROM mcr.microsoft.com/playwright:v1.58.1-jammy

# Set working directory to backend folder
WORKDIR /app

# Fix HTTPS requests
RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates

# Copy backend package.json + lock file
COPY railway-backend/package*.json ./ 

# Install backend dependencies
RUN npm install

# Copy the rest of the backend code
COPY railway-backend/. .

# Start the backend
CMD ["node", "server.js"]