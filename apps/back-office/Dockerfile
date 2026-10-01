FROM node:22-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

FROM node:22-alpine AS development
WORKDIR /app
ENV HOST=0.0.0.0
ENV PORT=3100
COPY --from=deps /app/node_modules ./node_modules
EXPOSE 3100
CMD ["npm", "run", "dev"]

FROM node:22-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3100
COPY --from=build /app/.output ./.output
EXPOSE 3100
CMD ["node", ".output/server/index.mjs"]
