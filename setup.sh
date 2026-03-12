#!/bin/bash
set -e

echo "🐳 Dockerizing PromptLab frontend (fully verified)..."

docker compose down 2>/dev/null || true

# ── CLIENT DOCKERFILE ─────────────────────────────────────────────────────────
cat > client/Dockerfile << 'EOF'
FROM node:20-slim AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

# ── CLIENT .DOCKERIGNORE ──────────────────────────────────────────────────────
cat > client/.dockerignore << 'EOF'
node_modules
dist
.env
*.log
EOF

# ── NGINX CONFIG ──────────────────────────────────────────────────────────────
cat > client/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Handle React Router
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API calls to backend container
    location /api/ {
        proxy_pass http://server:4000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
    }

    # Proxy health endpoint
    location /health {
        proxy_pass http://server:4000/health;
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;
}
EOF

# ── VITE CONFIG (preserve React plugin) ──────────────────────────────────────
cat > client/vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:4000',
        changeOrigin: true,
      },
    },
  },
})
EOF

# ── API CLIENT (relative URLs in prod, full URL in dev) ───────────────────────
cat > client/src/lib/api.ts << 'EOF'
import axios from 'axios'

// In Docker production: nginx proxies /api → server:4000 (relative URLs work)
// In local dev: Vite proxies /api → localhost:4000 (relative URLs work too)
const api = axios.create({
  baseURL: '',
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('token')
      window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)

export default api
EOF

# ── FULL DOCKER COMPOSE (all services) ───────────────────────────────────────
cat > docker-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:16-alpine
    container_name: promptlab_postgres
    environment:
      POSTGRES_USER: promptlab
      POSTGRES_PASSWORD: promptlab_pass
      POSTGRES_DB: promptlab_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U promptlab -d promptlab_db"]
      interval: 3s
      timeout: 5s
      retries: 10
      start_period: 10s

  redis:
    image: redis:7-alpine
    container_name: promptlab_redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 3s
      timeout: 5s
      retries: 10
      start_period: 5s

  server:
    build:
      context: ./server
      dockerfile: Dockerfile
    container_name: promptlab_server
    ports:
      - "4000:4000"
    environment:
      DATABASE_URL: postgresql://promptlab:promptlab_pass@postgres:5432/promptlab_db
      REDIS_URL: redis://redis:6379
      JWT_SECRET: ${JWT_SECRET:-supersecretjwtkey_changeme}
      GROQ_API_KEY: ${GROQ_API_KEY}
      GEMINI_API_KEY: ${GEMINI_API_KEY}
      PORT: 4000
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: on-failure

  client:
    build:
      context: ./client
      dockerfile: Dockerfile
    container_name: promptlab_client
    ports:
      - "80:80"
    depends_on:
      - server
    restart: on-failure

volumes:
  postgres_data:
  redis_data:
EOF

# ── DEV DOCKER COMPOSE (infra only) ──────────────────────────────────────────
cat > docker-compose.dev.yml << 'EOF'
services:
  postgres:
    image: postgres:16-alpine
    container_name: promptlab_postgres
    environment:
      POSTGRES_USER: promptlab
      POSTGRES_PASSWORD: promptlab_pass
      POSTGRES_DB: promptlab_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    container_name: promptlab_redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
EOF

# ── ROOT .ENV (if not exists) ─────────────────────────────────────────────────
if [ ! -f .env ]; then
cat > .env << 'EOF'
GROQ_API_KEY=your_groq_key_here
GEMINI_API_KEY=your_gemini_key_here
JWT_SECRET=supersecretjwtkey_changeme
EOF
echo "⚠️  Created root .env — add your real API keys"
else
  # Make sure JWT_SECRET is in .env
  if ! grep -q "JWT_SECRET" .env; then
    echo "JWT_SECRET=supersecretjwtkey_changeme" >> .env
  fi
fi

echo ""
echo "✅ Full stack Docker setup complete!"
echo ""
echo "Key changes:"
echo "  - api.ts uses baseURL='' (works in both dev via Vite proxy and prod via nginx)"
echo "  - nginx proxies /api/ → server:4000 inside Docker network"
echo "  - vite.config.ts preserved with React plugin"
echo "  - JWT_SECRET moved to .env"
echo "  - client depends_on server (started)"
echo "  - server depends_on postgres+redis (healthy)"
echo ""
echo "Run full stack:"
echo "  docker compose up --build"
echo ""
echo "  Frontend → http://localhost:80"
echo "  Backend  → http://localhost:4000"
echo ""
echo "Run dev mode:"
echo "  docker compose -f docker-compose.dev.yml up -d"
echo "  cd server && npm run dev"
echo "  cd client && npm run dev"