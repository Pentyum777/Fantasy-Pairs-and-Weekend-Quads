FROM mcr.microsoft.com/playwright:v1.58.1-jammy

WORKDIR /app

# Fix HTTPS requests
RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates

# Copy backend package.json
COPY railway-backend/package*.json ./railway-backend/

# Install backend dependencies
RUN cd railway-backend && npm install

# Copy entire project
COPY . .

# Run backend from subfolder
CMD ["node", "railway-backend/server.js"]