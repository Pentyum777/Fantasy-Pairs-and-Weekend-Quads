FROM mcr.microsoft.com/playwright:v1.58.1-jammy

WORKDIR /app

RUN apt-get update && apt-get install -y ca-certificates && update-ca-certificates

COPY railway-backend/package*.json ./railway-backend/
RUN cd railway-backend && npm install

COPY railway-backend ./railway-backend

CMD ["node", "railway-backend/server.js"]