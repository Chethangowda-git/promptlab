# PromptLab — Prompt Engineering Studio

![CI](https://github.com/Chethangowda-git/promptlab/actions/workflows/ci.yml/badge.svg)
![Docker](https://img.shields.io/badge/docker-ready-blue)
![License](https://img.shields.io/badge/license-MIT-green)

A full-stack web application for designing, testing, versioning, and optimizing prompts for Large Language Models. PromptLab treats prompts as first-class engineering artifacts — with version control, automated evaluation, A/B testing, and cost tracking.

## Features

### Prompt Editor
- Monaco-based editor with syntax highlighting
- `{{variable}}` interpolation syntax for dynamic prompts
- Dual editor — system prompt + user prompt side by side
- Character counter per editor
- Version badge showing current version number

### AI Prompt Improvement ✨
- One-click "Improve with AI" powered by Groq LLaMA
- Returns improved prompt with a structured diff view
- Explains each change by type: clarity, specificity, token efficiency, format
- Accept → auto-updates editor, Discard → no changes made
- Prompts user to save as a new version after accepting

### Version Control
- Every save creates an auto-incremented version (v1, v2, v3...)
- Full version history table with timestamps and tag status
- Click any version in history to restore it in the editor
- Version tagging: production, testing

### Multi-Model Execution
- Run prompts against multiple models simultaneously with one click
- Side-by-side response comparison view
- Per-model stats: latency (ms), input/output tokens, cost ($)
- Configurable temperature and max tokens sliders
- Pre-populates from prompt editor when navigating via Execute button

### Evaluation Suite
- Select any prompt version and run it against test inputs
- LLM-as-judge scoring for Relevance and Coherence (1-10 scale)
- Latency and Token Efficiency metrics
- Visual score bars per model for quick comparison
- Async evaluation with real-time polling for results
- Summary table across all models + individual output view

### A/B Testing
- Compare two prompt versions head-to-head on the same inputs
- LLM judge evaluates both outputs and declares a winner per round
- Final tally: Version A wins X/N rounds vs Version B wins Y/N rounds
- Side-by-side output diff with per-round judge reasoning

### Export
- Export any prompt version as JSON config or Python code snippet
- Python snippet is ready-to-run with Groq or Gemini SDK
- One-click clipboard copy

### Auth
- JWT-based register and login
- Auto-creates default team and project on registration
- Token stored in localStorage with automatic refresh on 401

### UX
- Toast notifications for all key actions (success, error, warning, info)
- Required field validation with red borders before triggering features
- Unsaved changes warning when navigating away from editor

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18 + TypeScript + Tailwind CSS + Monaco Editor |
| State Management | Zustand |
| Backend | Node.js + Express + TypeScript |
| Database | PostgreSQL + Prisma ORM v5 |
| Cache | Redis + ioredis |
| Job Queue | BullMQ |
| LLM Providers | Groq (LLaMA, Mixtral, Gemma) + Google Gemini |
| Auth | JWT + bcrypt |
| Containerization | Docker + Docker Compose |
| CI/CD | GitHub Actions |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Docker Network                    │
│                                                      │
│  ┌──────────┐    ┌──────────┐    ┌──────────────┐   │
│  │  React   │    │  Nginx   │    │   Node.js    │   │
│  │  (Vite)  │───▶│  :80     │───▶│   Express    │   │
│  └──────────┘    └──────────┘    │   :4000      │   │
│                                  └──────┬───────┘   │
│                                         │            │
│                          ┌──────────────┴───────┐   │
│                          │                      │   │
│                   ┌──────▼──┐           ┌───────▼─┐ │
│                   │Postgres │           │  Redis  │ │
│                   │ :5432   │           │  :6379  │ │
│                   └─────────┘           └─────────┘ │
└─────────────────────────────────────────────────────┘
                          │
              ┌───────────▼───────────┐
              │     LLM Providers     │
              │   Groq  +  Gemini     │
              └───────────────────────┘
```

## Getting Started

### Prerequisites
- Docker + Docker Compose
- Groq API key — free at [console.groq.com](https://console.groq.com)
- Google Gemini API key — free at [aistudio.google.com](https://aistudio.google.com)

### Quick Start (Full Docker)

```bash
# Clone the repo
git clone https://github.com/Chethangowda-git/promptlab.git
cd promptlab

# Add your API keys
cp .env.example .env
# Edit .env and add GROQ_API_KEY and GEMINI_API_KEY

# Start everything
docker compose up --build

# Open the app
open http://localhost
```

### Development Mode

```bash
# Start only infra (postgres + redis)
docker compose -f docker-compose.dev.yml up -d

# Start backend
cd server && npm install && npm run dev

# Start frontend (new terminal)
cd client && npm install && npm run dev
```

### Environment Variables

```env
GROQ_API_KEY=your_groq_api_key
GEMINI_API_KEY=your_gemini_api_key
JWT_SECRET=your_secure_secret
```

## Supported Models

**Groq (Free tier)**
| Model | Best For |
|-------|----------|
| `llama-3.3-70b-versatile` | High quality, general purpose |
| `llama-3.1-8b-instant` | Fast, lightweight tasks |
| `mixtral-8x7b-32768` | Long context tasks |
| `gemma2-9b-it` | Instruction following |

**Google Gemini (Free tier)**
| Model | Best For |
|-------|----------|
| `gemini-1.5-flash` | Fast, cost-efficient |
| `gemini-1.5-pro` | Complex reasoning |

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login |
| GET | `/api/auth/me` | Get current user |
| GET | `/api/prompts` | List prompts |
| POST | `/api/prompts` | Create prompt |
| GET | `/api/prompts/:id` | Get prompt with versions |
| POST | `/api/prompts/:id/versions` | Save new version |
| GET | `/api/prompts/:id/versions` | List all versions |
| GET | `/api/execute/providers` | List available providers |
| POST | `/api/execute` | Run single model |
| POST | `/api/execute/batch` | Run multiple models |
| POST | `/api/execute/improve` | AI prompt improvement |
| POST | `/api/evaluations` | Start evaluation run |
| GET | `/api/evaluations/:id` | Get evaluation results |
| POST | `/api/experiments` | Create A/B test |
| POST | `/api/experiments/:id/run` | Run A/B test |
| GET | `/api/export/:versionId/json` | Export as JSON |
| GET | `/api/export/:versionId/python` | Export as Python |

## Testing

Integration tests are written with **Jest** and **Supertest**, running against a real PostgreSQL instance.

```bash
# Run tests locally (requires postgres running)
cd server && npm test

# Run in CI mode
cd server && npm run test:ci
```

### Test Coverage

| Suite | Tests | What's covered |
|-------|-------|----------------|
| `auth.test.ts` | 4 | Register, duplicate email, auth guards |
| `prompts.test.ts` | 4 | Create, list, auth guards |
| `execute.test.ts` | 2 | Providers list, auth guard |
| **Total** | **10** | Auth, CRUD, provider abstraction |

Tests run automatically on every push via GitHub Actions against a fresh PostgreSQL container.

## CI/CD Pipeline

GitHub Actions runs on every push to `main`:

```
Push to main
    │
    ├── Lint (ESLint + TypeScript check)
    ├── Integration Tests (real Postgres + Redis)
    ├── Client Build (Vite production build)
    └── Docker Build (server + client images)
```

## Project Structure

```
promptlab/
├── client/                   # React frontend
│   ├── src/
│   │   ├── components/       # Reusable UI (layout, toasts)
│   │   ├── pages/            # Dashboard, Prompts, Execute, Evaluate, Export, A/B Tests
│   │   ├── store/            # Zustand state (auth, prompts)
│   │   └── lib/              # Axios API client
│   ├── Dockerfile            # Multi-stage: Node build + Nginx serve
│   └── nginx.conf            # React Router + API proxy config
├── server/                   # Node.js backend
│   ├── src/
│   │   ├── controllers/      # auth, prompts, execute, evaluation, export, experiment
│   │   ├── routes/           # Express route definitions
│   │   ├── providers/        # LLM abstraction (base, groq, gemini)
│   │   ├── middleware/        # JWT auth middleware
│   │   ├── lib/              # Prisma + Redis clients
│   │   └── __tests__/        # Jest integration tests
│   ├── prisma/
│   │   └── schema.prisma     # Full database schema
│   └── Dockerfile            # node:20-slim + OpenSSL + Prisma
├── docker-compose.yml        # Full stack (postgres + redis + server + client)
├── docker-compose.dev.yml    # Infra only (for local development)
└── .github/
    └── workflows/
        └── ci.yml            # GitHub Actions CI pipeline
```
