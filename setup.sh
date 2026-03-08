#!/bin/bash
set -e

echo "🚀 Setting up PromptLab..."

# ── ROOT FILES ──────────────────────────────────────────────────────────────

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

cat > .gitignore << 'EOF'
node_modules/
dist/
.env
.env.local
*.log
EOF

echo "✅ Root files created"

# ── SERVER SETUP ─────────────────────────────────────────────────────────────

mkdir -p server/src/{lib,providers,routes,controllers,services,middleware}
mkdir -p server/prisma

cat > server/package.json << 'EOF'
{
  "name": "promptlab-server",
  "version": "1.0.0",
  "scripts": {
    "dev": "nodemon --watch src --ext ts --exec ts-node src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "db:migrate": "prisma migrate dev",
    "db:generate": "prisma generate",
    "db:studio": "prisma studio"
  }
}
EOF

cat > server/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

cat > server/.env << 'EOF'
DATABASE_URL="postgresql://promptlab:promptlab_pass@localhost:5432/promptlab_db"
REDIS_URL="redis://localhost:6379"
GROQ_API_KEY=your_groq_key_here
GEMINI_API_KEY=your_gemini_key_here
JWT_SECRET=supersecretjwtkey_changeme
PORT=4000
EOF

cat > server/prisma/schema.prisma << 'EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id             String          @id @default(uuid())
  email          String          @unique
  name           String
  password       String
  role           Role            @default(MEMBER)
  teamId         String?
  team           Team?           @relation(fields: [teamId], references: [id])
  createdAt      DateTime        @default(now())
  prompts        Prompt[]
  promptVersions PromptVersion[]
  evaluations    Evaluation[]
  datasets       TestDataset[]
}

model Team {
  id        String    @id @default(uuid())
  name      String
  plan      Plan      @default(FREE)
  createdAt DateTime  @default(now())
  users     User[]
  projects  Project[]
}

model Project {
  id          String           @id @default(uuid())
  teamId      String
  team        Team             @relation(fields: [teamId], references: [id])
  name        String
  description String?
  createdAt   DateTime         @default(now())
  prompts     Prompt[]
  datasets    TestDataset[]
  experiments Experiment[]
  pipelines   PromptPipeline[]
}

model Prompt {
  id               String          @id @default(uuid())
  projectId        String
  project          Project         @relation(fields: [projectId], references: [id])
  name             String
  description      String?
  createdById      String
  createdBy        User            @relation(fields: [createdById], references: [id])
  currentVersionId String?
  status           PromptStatus    @default(DRAFT)
  createdAt        DateTime        @default(now())
  updatedAt        DateTime        @updatedAt
  versions         PromptVersion[]
}

model PromptVersion {
  id                 String          @id @default(uuid())
  promptId           String
  prompt             Prompt          @relation(fields: [promptId], references: [id])
  versionNumber      Int
  systemPrompt       String?
  userPromptTemplate String
  variables          Json            @default("[]")
  modelConfig        Json            @default("{}")
  tag                VersionTag?
  createdById        String
  createdBy          User            @relation(fields: [createdById], references: [id])
  parentVersionId    String?
  parentVersion      PromptVersion?  @relation("VersionBranch", fields: [parentVersionId], references: [id])
  childVersions      PromptVersion[] @relation("VersionBranch")
  createdAt          DateTime        @default(now())
  evaluations        Evaluation[]
  experimentsAsA     Experiment[]    @relation("ExperimentVersionA")
  experimentsAsB     Experiment[]    @relation("ExperimentVersionB")
}

model TestDataset {
  id          String       @id @default(uuid())
  projectId   String
  project     Project      @relation(fields: [projectId], references: [id])
  name        String
  description String?
  entries     Json         @default("[]")
  createdById String
  createdBy   User         @relation(fields: [createdById], references: [id])
  createdAt   DateTime     @default(now())
  updatedAt   DateTime     @updatedAt
  evaluations Evaluation[]
}

model Evaluation {
  id              String             @id @default(uuid())
  promptVersionId String
  promptVersion   PromptVersion      @relation(fields: [promptVersionId], references: [id])
  datasetId       String?
  dataset         TestDataset?       @relation(fields: [datasetId], references: [id])
  status          EvaluationStatus   @default(RUNNING)
  config          Json               @default("{}")
  createdById     String
  createdBy       User               @relation(fields: [createdById], references: [id])
  startedAt       DateTime           @default(now())
  completedAt     DateTime?
  results         EvaluationResult[]
}

model EvaluationResult {
  id             String     @id @default(uuid())
  evaluationId   String
  evaluation     Evaluation @relation(fields: [evaluationId], references: [id])
  model          String
  inputVariables Json       @default("{}")
  output         String
  metrics        Json       @default("{}")
  cost           Decimal    @default(0)
  createdAt      DateTime   @default(now())
}

model Experiment {
  id           String           @id @default(uuid())
  projectId    String
  project      Project          @relation(fields: [projectId], references: [id])
  name         String
  versionAId   String
  versionA     PromptVersion    @relation("ExperimentVersionA", fields: [versionAId], references: [id])
  versionBId   String
  versionB     PromptVersion    @relation("ExperimentVersionB", fields: [versionBId], references: [id])
  trafficSplit Json             @default("{\"a\": 50, \"b\": 50}")
  status       ExperimentStatus @default(RUNNING)
  sampleSize   Int              @default(100)
  results      Json?
  startedAt    DateTime         @default(now())
  completedAt  DateTime?
}

model PromptPipeline {
  id          String   @id @default(uuid())
  projectId   String
  project     Project  @relation(fields: [projectId], references: [id])
  name        String
  steps       Json     @default("[]")
  createdById String
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}

enum Role {
  ADMIN
  MEMBER
}

enum Plan {
  FREE
  PRO
  ENTERPRISE
}

enum PromptStatus {
  DRAFT
  TESTING
  PRODUCTION
  DEPRECATED
}

enum VersionTag {
  PRODUCTION
  TESTING
}

enum EvaluationStatus {
  RUNNING
  COMPLETED
  FAILED
}

enum ExperimentStatus {
  RUNNING
  COMPLETED
}
EOF

# ── SERVER SOURCE FILES ───────────────────────────────────────────────────────

cat > server/src/index.ts << 'EOF'
import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import morgan from 'morgan'
import dotenv from 'dotenv'
import authRoutes from './routes/auth.routes'
import promptRoutes from './routes/prompts.routes'
import executeRoutes from './routes/execute.routes'

dotenv.config()

const app = express()
const PORT = process.env.PORT || 4000

app.use(helmet())
app.use(cors())
app.use(morgan('dev'))
app.use(express.json())

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
})

app.use('/api/auth', authRoutes)
app.use('/api/prompts', promptRoutes)
app.use('/api/execute', executeRoutes)

app.listen(PORT, () => {
  console.log(`✅ Server running on http://localhost:${PORT}`)
})

export default app
EOF

cat > server/src/lib/prisma.ts << 'EOF'
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

export default prisma
EOF

cat > server/src/lib/redis.ts << 'EOF'
import Redis from 'ioredis'

const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379')

redis.on('connect', () => console.log('✅ Redis connected'))
redis.on('error', (err) => console.error('Redis error:', err))

export default redis
EOF

cat > server/src/providers/base.provider.ts << 'EOF'
export interface ExecuteOptions {
  systemPrompt?: string
  userPrompt: string
  temperature?: number
  maxTokens?: number
}

export interface ExecuteResult {
  output: string
  model: string
  provider: string
  latencyMs: number
  inputTokens: number
  outputTokens: number
  cost: number
}

export abstract class BaseProvider {
  abstract name: string
  abstract models: string[]
  abstract execute(model: string, options: ExecuteOptions): Promise<ExecuteResult>

  protected calculateCost(
    inputTokens: number,
    outputTokens: number,
    inputPricePerMillion: number,
    outputPricePerMillion: number
  ): number {
    return (
      (inputTokens / 1_000_000) * inputPricePerMillion +
      (outputTokens / 1_000_000) * outputPricePerMillion
    )
  }
}
EOF

cat > server/src/providers/groq.provider.ts << 'EOF'
import Groq from 'groq-sdk'
import { BaseProvider, ExecuteOptions, ExecuteResult } from './base.provider'

export class GroqProvider extends BaseProvider {
  name = 'groq'
  models = ['llama3-8b-8192', 'llama3-70b-8192', 'mixtral-8x7b-32768', 'gemma2-9b-it']
  private client: Groq

  constructor() {
    super()
    this.client = new Groq({ apiKey: process.env.GROQ_API_KEY })
  }

  async execute(model: string, options: ExecuteOptions): Promise<ExecuteResult> {
    const start = Date.now()
    const messages: Groq.Chat.ChatCompletionMessageParam[] = []

    if (options.systemPrompt) {
      messages.push({ role: 'system', content: options.systemPrompt })
    }
    messages.push({ role: 'user', content: options.userPrompt })

    const response = await this.client.chat.completions.create({
      model,
      messages,
      temperature: options.temperature ?? 0.7,
      max_tokens: options.maxTokens ?? 1024,
    })

    const latencyMs = Date.now() - start
    const inputTokens = response.usage?.prompt_tokens ?? 0
    const outputTokens = response.usage?.completion_tokens ?? 0

    return {
      output: response.choices[0]?.message?.content ?? '',
      model,
      provider: this.name,
      latencyMs,
      inputTokens,
      outputTokens,
      cost: this.calculateCost(inputTokens, outputTokens, 0.05, 0.10),
    }
  }
}
EOF

cat > server/src/providers/gemini.provider.ts << 'EOF'
import { GoogleGenerativeAI } from '@google/generative-ai'
import { BaseProvider, ExecuteOptions, ExecuteResult } from './base.provider'

export class GeminiProvider extends BaseProvider {
  name = 'gemini'
  models = ['gemini-1.5-flash', 'gemini-1.5-pro']
  private client: GoogleGenerativeAI

  constructor() {
    super()
    this.client = new GoogleGenerativeAI(process.env.GEMINI_API_KEY ?? '')
  }

  async execute(model: string, options: ExecuteOptions): Promise<ExecuteResult> {
    const start = Date.now()

    const genModel = this.client.getGenerativeModel({
      model,
      systemInstruction: options.systemPrompt,
    })

    const result = await genModel.generateContent({
      contents: [{ role: 'user', parts: [{ text: options.userPrompt }] }],
      generationConfig: {
        temperature: options.temperature ?? 0.7,
        maxOutputTokens: options.maxTokens ?? 1024,
      },
    })

    const latencyMs = Date.now() - start
    const inputTokens = result.response.usageMetadata?.promptTokenCount ?? 0
    const outputTokens = result.response.usageMetadata?.candidatesTokenCount ?? 0

    return {
      output: result.response.text(),
      model,
      provider: this.name,
      latencyMs,
      inputTokens,
      outputTokens,
      cost: this.calculateCost(inputTokens, outputTokens, 0.075, 0.30),
    }
  }
}
EOF

cat > server/src/providers/index.ts << 'EOF'
import { BaseProvider } from './base.provider'
import { GroqProvider } from './groq.provider'
import { GeminiProvider } from './gemini.provider'

const providers: Record<string, BaseProvider> = {
  groq: new GroqProvider(),
  gemini: new GeminiProvider(),
}

export function getProvider(name: string): BaseProvider {
  const provider = providers[name]
  if (!provider) throw new Error(`Provider "${name}" not found`)
  return provider
}

export function getAllProviders() {
  return Object.values(providers).map((p) => ({
    name: p.name,
    models: p.models,
  }))
}

export { BaseProvider }
EOF

cat > server/src/middleware/auth.middleware.ts << 'EOF'
import { Request, Response, NextFunction } from 'express'
import jwt from 'jsonwebtoken'

export interface AuthRequest extends Request {
  userId?: string
  userRole?: string
}

export function authMiddleware(req: AuthRequest, res: Response, next: NextFunction): void {
  const token = req.headers.authorization?.split(' ')[1]
  if (!token) {
    res.status(401).json({ error: 'No token provided' })
    return
  }
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!) as { userId: string; role: string }
    req.userId = decoded.userId
    req.userRole = decoded.role
    next()
  } catch {
    res.status(401).json({ error: 'Invalid token' })
  }
}
EOF

cat > server/src/controllers/auth.controller.ts << 'EOF'
import { Request, Response } from 'express'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import prisma from '../lib/prisma'

export async function register(req: Request, res: Response): Promise<void> {
  try {
    const { email, name, password } = req.body
    const existing = await prisma.user.findUnique({ where: { email } })
    if (existing) {
      res.status(400).json({ error: 'Email already in use' })
      return
    }
    const hashed = await bcrypt.hash(password, 10)
    const user = await prisma.user.create({
      data: { email, name, password: hashed },
      select: { id: true, email: true, name: true, role: true },
    })
    const token = jwt.sign({ userId: user.id, role: user.role }, process.env.JWT_SECRET!, { expiresIn: '7d' })
    res.status(201).json({ user, token })
  } catch (err) {
    res.status(500).json({ error: 'Registration failed' })
  }
}

export async function login(req: Request, res: Response): Promise<void> {
  try {
    const { email, password } = req.body
    const user = await prisma.user.findUnique({ where: { email } })
    if (!user || !(await bcrypt.compare(password, user.password))) {
      res.status(401).json({ error: 'Invalid credentials' })
      return
    }
    const token = jwt.sign({ userId: user.id, role: user.role }, process.env.JWT_SECRET!, { expiresIn: '7d' })
    res.json({ user: { id: user.id, email: user.email, name: user.name, role: user.role }, token })
  } catch (err) {
    res.status(500).json({ error: 'Login failed' })
  }
}

export async function me(req: Request, res: Response): Promise<void> {
  try {
    const userId = (req as any).userId
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, name: true, role: true },
    })
    res.json(user)
  } catch {
    res.status(500).json({ error: 'Failed to fetch user' })
  }
}
EOF

cat > server/src/controllers/prompts.controller.ts << 'EOF'
import { Response } from 'express'
import { AuthRequest } from '../middleware/auth.middleware'
import prisma from '../lib/prisma'

export async function createPrompt(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { projectId, name, description } = req.body
    const prompt = await prisma.prompt.create({
      data: { projectId, name, description, createdById: req.userId! },
    })
    res.status(201).json(prompt)
  } catch {
    res.status(500).json({ error: 'Failed to create prompt' })
  }
}

export async function listPrompts(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { projectId } = req.query
    const prompts = await prisma.prompt.findMany({
      where: projectId ? { projectId: String(projectId) } : {},
      include: { versions: { orderBy: { versionNumber: 'desc' }, take: 1 } },
      orderBy: { updatedAt: 'desc' },
    })
    res.json(prompts)
  } catch {
    res.status(500).json({ error: 'Failed to list prompts' })
  }
}

export async function getPrompt(req: AuthRequest, res: Response): Promise<void> {
  try {
    const prompt = await prisma.prompt.findUnique({
      where: { id: req.params.id },
      include: { versions: { orderBy: { versionNumber: 'desc' } } },
    })
    if (!prompt) { res.status(404).json({ error: 'Prompt not found' }); return }
    res.json(prompt)
  } catch {
    res.status(500).json({ error: 'Failed to get prompt' })
  }
}

export async function createVersion(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { systemPrompt, userPromptTemplate, variables, modelConfig, parentVersionId } = req.body
    const latest = await prisma.promptVersion.findFirst({
      where: { promptId: req.params.id },
      orderBy: { versionNumber: 'desc' },
    })
    const versionNumber = (latest?.versionNumber ?? 0) + 1
    const version = await prisma.promptVersion.create({
      data: {
        promptId: req.params.id,
        versionNumber,
        systemPrompt,
        userPromptTemplate,
        variables: variables ?? [],
        modelConfig: modelConfig ?? {},
        createdById: req.userId!,
        parentVersionId: parentVersionId ?? null,
      },
    })
    await prisma.prompt.update({
      where: { id: req.params.id },
      data: { currentVersionId: version.id },
    })
    res.status(201).json(version)
  } catch {
    res.status(500).json({ error: 'Failed to create version' })
  }
}

export async function listVersions(req: AuthRequest, res: Response): Promise<void> {
  try {
    const versions = await prisma.promptVersion.findMany({
      where: { promptId: req.params.id },
      orderBy: { versionNumber: 'desc' },
    })
    res.json(versions)
  } catch {
    res.status(500).json({ error: 'Failed to list versions' })
  }
}
EOF

cat > server/src/controllers/execute.controller.ts << 'EOF'
import { Response } from 'express'
import { AuthRequest } from '../middleware/auth.middleware'
import { getProvider, getAllProviders } from '../providers'

export async function executePrompt(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { provider, model, systemPrompt, userPrompt, temperature, maxTokens } = req.body
    const p = getProvider(provider)
    const result = await p.execute(model, { systemPrompt, userPrompt, temperature, maxTokens })
    res.json(result)
  } catch (err: any) {
    res.status(500).json({ error: err.message })
  }
}

export async function executeBatch(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { models, systemPrompt, userPrompt, temperature, maxTokens } = req.body
    const results = await Promise.allSettled(
      models.map(({ provider, model }: { provider: string; model: string }) =>
        getProvider(provider).execute(model, { systemPrompt, userPrompt, temperature, maxTokens })
      )
    )
    res.json(
      results.map((r, i) =>
        r.status === 'fulfilled'
          ? { ...r.value }
          : { error: r.reason?.message, model: models[i].model, provider: models[i].provider }
      )
    )
  } catch (err: any) {
    res.status(500).json({ error: err.message })
  }
}

export async function improvePrompt(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { prompt, systemPrompt } = req.body
    const p = getProvider('groq')
    const metaPrompt = `You are a prompt engineering expert. Improve the following prompt for clarity, specificity, and token efficiency.

Return ONLY a JSON object (no markdown, no explanation outside the JSON) in this exact format:
{
  "improvedPrompt": "the improved version",
  "improvedSystemPrompt": "improved system prompt or empty string",
  "changes": [
    { "type": "clarity|specificity|efficiency|format", "description": "what changed and why" }
  ]
}

Original System Prompt: ${systemPrompt || '(none)'}
Original User Prompt: ${prompt}`

    const result = await p.execute('llama3-70b-8192', {
      userPrompt: metaPrompt,
      temperature: 0.3,
      maxTokens: 1024,
    })

    const clean = result.output.replace(/```json|```/g, '').trim()
    const parsed = JSON.parse(clean)
    res.json({ ...parsed, latencyMs: result.latencyMs })
  } catch (err: any) {
    res.status(500).json({ error: err.message })
  }
}

export async function listProviders(_req: AuthRequest, res: Response): Promise<void> {
  res.json(getAllProviders())
}
EOF

cat > server/src/routes/auth.routes.ts << 'EOF'
import { Router } from 'express'
import { register, login, me } from '../controllers/auth.controller'
import { authMiddleware } from '../middleware/auth.middleware'

const router = Router()

router.post('/register', register)
router.post('/login', login)
router.get('/me', authMiddleware, me)

export default router
EOF

cat > server/src/routes/prompts.routes.ts << 'EOF'
import { Router } from 'express'
import { authMiddleware } from '../middleware/auth.middleware'
import {
  createPrompt, listPrompts, getPrompt,
  createVersion, listVersions,
} from '../controllers/prompts.controller'

const router = Router()

router.use(authMiddleware)

router.post('/', createPrompt)
router.get('/', listPrompts)
router.get('/:id', getPrompt)
router.post('/:id/versions', createVersion)
router.get('/:id/versions', listVersions)

export default router
EOF

cat > server/src/routes/execute.routes.ts << 'EOF'
import { Router } from 'express'
import { authMiddleware } from '../middleware/auth.middleware'
import { executePrompt, executeBatch, improvePrompt, listProviders } from '../controllers/execute.controller'

const router = Router()

router.use(authMiddleware)

router.post('/', executePrompt)
router.post('/batch', executeBatch)
router.post('/improve', improvePrompt)
router.get('/providers', listProviders)

export default router
EOF

echo "✅ Server source files created"

# ── SERVER DEPENDENCIES ───────────────────────────────────────────────────────

cd server
echo "📦 Installing server dependencies..."
npm install express cors dotenv helmet morgan bcryptjs jsonwebtoken
npm install prisma@5 @prisma/client@5
npm install bullmq ioredis
npm install groq-sdk @google/generative-ai
npm install -D typescript ts-node nodemon \
  @types/express @types/cors @types/morgan \
  @types/node @types/bcryptjs @types/jsonwebtoken

echo "🗄️  Running Prisma migrate..."
npx prisma migrate dev --name init
npx prisma generate

cd ..

# ── FRONTEND SETUP ────────────────────────────────────────────────────────────

echo "⚛️  Setting up frontend..."
npm create vite@latest client -- --template react-ts

cd client
npm install
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
npm install axios zustand react-router-dom @monaco-editor/react
npm install -D @types/node

cat > tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF

cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

cat > src/main.tsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
EOF

cat > src/App.tsx << 'EOF'
function App() {
  return (
    <div className="min-h-screen bg-gray-950 text-white flex items-center justify-center">
      <div className="text-center">
        <h1 className="text-4xl font-bold text-indigo-400 mb-2">PromptLab</h1>
        <p className="text-gray-400">Prompt Engineering Studio</p>
        <div className="mt-4 px-4 py-2 bg-green-500/10 border border-green-500/30 rounded-lg text-green-400 text-sm">
          ✅ Setup complete — ready to build
        </div>
      </div>
    </div>
  )
}

export default App
EOF

cd ..

# ── DOCKER ────────────────────────────────────────────────────────────────────

echo "🐳 Starting Docker containers..."
docker compose up -d

echo ""
echo "✅ PromptLab setup complete!"
echo ""
echo "Next steps:"
echo "  1. Add your API keys to server/.env (GROQ_API_KEY, GEMINI_API_KEY)"
echo "  2. Start backend:  cd server && npm run dev"
echo "  3. Start frontend: cd client && npm run dev"
echo "  4. Backend runs on http://localhost:4000"
echo "  5. Frontend runs on http://localhost:5173"