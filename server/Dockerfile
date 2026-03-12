FROM node:20-slim

WORKDIR /app

# Install OpenSSL required by Prisma
RUN apt-get update -y && apt-get install -y openssl ca-certificates && rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY package*.json ./
RUN npm install

# Copy source
COPY prisma ./prisma
COPY tsconfig.json ./
COPY src ./src

# Generate Prisma client and build TypeScript
RUN npx prisma generate
RUN npm run build

EXPOSE 4000

# Push schema and start server
CMD ["sh", "-c", "npx prisma db push --accept-data-loss && node dist/index.js"]
