FROM node:22-alpine

ENV NODE_ENV=production

WORKDIR /app
RUN chown node:node /app

COPY --chown=node:node frontend/package.json frontend/package-lock.json ./
USER node
RUN npm ci --omit=dev --no-audit --no-fund

COPY --chown=node:node frontend/server.js ./server.js
COPY --chown=node:node frontend/views ./views
COPY --chown=node:node frontend/public ./public

EXPOSE 3000

CMD ["npm", "start"]
