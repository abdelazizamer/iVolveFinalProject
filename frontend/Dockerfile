FROM node:22-alpine

ENV NODE_ENV=production

WORKDIR /app
RUN chown node:node /app

COPY --chown=node:node frontend/package.json frontend/package-lock.json ./
USER node
RUN npm ci --omit=dev --no-audit --no-fund \
    && npm cache clean --force

# npm is a build-time tool; the running app only needs Node.js.
USER root
RUN rm -rf /usr/local/lib/node_modules/npm \
    /usr/local/bin/npm \
    /usr/local/bin/npx \
    /home/node/.npm
USER node

COPY --chown=node:node frontend/server.js ./server.js
COPY --chown=node:node frontend/views ./views
COPY --chown=node:node frontend/public ./public

EXPOSE 3000

CMD ["node", "server.js"]
