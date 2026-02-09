FROM mcr.microsoft.com/playwright:v1.58.1-jammy

WORKDIR /app

COPY railway-backend/package*.json ./
RUN npm install

COPY railway-backend/. .

EXPOSE 8080

CMD ["node", "server.js"]