FROM mcr.microsoft.com/playwright:v1.58.1-jammy

WORKDIR /app

# Fix HTTPS requests (Squiggle, AFL, etc.)
RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates

COPY package*.json ./
RUN npm install

COPY . .

CMD ["node", "server.js"]