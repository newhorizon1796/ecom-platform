FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev

FROM node:20-alpine
WORKDIR /app

# Pick up patched OS packages (was catching HIGH CVEs in the base image's
# libcrypto3/libssl3 that already had fixed versions available).
RUN apk update && apk upgrade --no-cache

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

# npm/npx aren't needed at runtime (only `node` is) — removing them drops a
# large tree of npm's own bundled dependencies (its internal node_modules)
# that Trivy was correctly flagging, since they ship in every node:*-alpine
# image by default regardless of what your app actually uses.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

USER node

EXPOSE 4000
CMD ["node", "src/index.js"]
