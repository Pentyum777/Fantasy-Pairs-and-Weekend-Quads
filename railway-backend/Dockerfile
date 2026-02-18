FROM mcr.microsoft.com/playwright:v1.58.1-jammy

WORKDIR /app

RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates

# Copy backend package.json from the current build context (railway-backend/)
COPY package*.json ./

RUN npm install

# Copy the rest of the backend code
COPY . .

CMD ["node", "server.js"]