FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY src ./src

# Runs as non-root — node:alpine ships a "node" user already.
USER node

EXPOSE 4000
CMD ["node", "src/index.js"]
