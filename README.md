# PromptLab — Prompt Engineering Studio

A full-stack web application for designing, testing, versioning, and optimizing prompts for Large Language Models. PromptLab treats prompts as first-class engineering artifacts — with version control, automated evaluation, A/B testing, and cost tracking.

![PromptLab Dashboard](https://via.placeholder.com/1200x600/1a1a2e/6366f1?text=PromptLab+Screenshot)

## Features

### Prompt Editor
- Monaco-based editor with syntax highlighting and `{{variable}}` interpolation
- System prompt + user prompt dual-editor layout
- Character counter and version badge

### AI Prompt Improvement ✨
- One-click "Improve with AI" powered by Groq LLaMA
- Diff view showing exactly what changed and why (clarity, specificity, token efficiency)
- Accept, tweak, or discard improvements
- Auto-saves as a new version on accept

### Version Control
- Every save creates an auto-incremented version (v1, v2, v3...)
- Full version history table with timestamps
- Click any version to restore it in the editor

### Multi-Model Execution
- Run prompts against multiple models simultaneously
- Side-by-side response comparison
- Real-time latency, token count, and cost per model
- Configurable temperature and max tokens

### Evaluation Suite
- LLM-as-judge scoring for Relevance and Coherence (1-10)
- Latency and Token Efficiency metrics
- Multi-model scoring with visual score bars
- Async evaluation with polling

### A/B Testing
- Compare two prompt versions on the same inputs
- LLM judge declares a winner per round
- Final tally with confidence summary
- Side-by-side output diff

### Export
- Export any prompt version as JSON config or Python code snippet
- Ready-to-run code with your API provider of choice
- One-click clipboard copy

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React 18 + TypeScript + Tailwind CSS + Monaco Editor |
| Backend | Node.js + Express + TypeScript |
| Database | PostgreSQL + Prisma ORM |
| Cache | Redis + ioredis |
| Job Queue | BullMQ |
| LLM Providers | Groq (LLaMA, Mixtral, Gemma) + Google Gemini |
| Auth | JWT with bcrypt |
| Containerization | Docker + Docker Compose |
| CI/CD | GitHub Actions |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Docker Network                    │
│                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────────┐  │
│  │  React   │    │  Nginx   │    │   Node.js    │  │
│  │  (Vite)  │───▶│ :80      │───▶│   Express    │  │
│  └──────────┘    └──────────┘    │   :4000      │  │
│                                  └──────┬───────┘  │
│                                         │           │
│                          ┌──────────────┼───────┐  │
│                          │              │       │   │
│                   ┌──────▼──┐   ┌───────▼──┐   │   │
│                   │PostgreSQL│   │  Redis   │   │   │
│                   │ :5432   │   │  :6379   │   │   │
│                   └─────────┘   └──────────┘   │   │
│                                                │   │
└────────────────────────────────────────────────┴───┘
                              │
                    ┌─────────▼──────────┐
                    │   LLM Providers    │
                    │  Groq + Gemini     │
                    └────────────────────┘
```

## Getting Started

### Prerequisites
- Docker + Docker Compose
- Groq API key (free at [console.groq.com](https://console.groq.com))
- Google Gemini API key (free at [aistudio.google.com](https://aistudio.google.com))

### Quick Start (Full Docker)

```bash
# Clone the repo
git clone https://github.com/Chethangowda-git/promptlab.git
cd promptlab

# Add your API keys
cp .env.example .env
# Edit .env with your keys

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

Create a `.env` file in the root:

```env
GROQ_API_KEY=your_groq_api_key
GEMINI_API_KEY=your_gemini_api_key
JWT_SECRET=your_secure_secret
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login |
| GET | `/api/prompts` | List prompts |
| POST | `/api/prompts` | Create prompt |
| POST | `/api/prompts/:id/versions` | Save new version |
| POST | `/api/execute` | Run single model |
| POST | `/api/execute/batch` | Run multiple models |
| POST | `/api/execute/improve` | AI prompt improvement |
| POST | `/api/evaluations` | Start evaluation |
| POST | `/api/experiments` | Create A/B test |
| POST | `/api/experiments/:id/run` | Run A/B test |
| GET | `/api/export/:versionId/json` | Export as JSON |
| GET | `/api/export/:versionId/python` | Export as Python |

## CI/CD

GitHub Actions runs on every push to `main`:
- ✅ TypeScript type check (server)
- ✅ Production build check (client)
- ✅ Docker image build verification (server + client)

## Supported Models

**Groq (Free)**
- `llama-3.3-70b-versatile`
- `llama-3.1-8b-instant`
- `mixtral-8x7b-32768`
- `gemma2-9b-it`

**Google Gemini (Free tier)**
- `gemini-1.5-flash`
- `gemini-1.5-pro`

## Project Structure

```
promptlab/
├── client/                  # React frontend
│   ├── src/
│   │   ├── components/      # Reusable UI components
│   │   ├── pages/           # Page components
│   │   ├── store/           # Zustand state management
│   │   └── lib/             # API client
│   ├── Dockerfile
│   └── nginx.conf
├── server/                  # Node.js backend
│   ├── src/
│   │   ├── controllers/     # Request handlers
│   │   ├── routes/          # Express routes
│   │   ├── providers/       # LLM provider abstraction
│   │   ├── middleware/      # Auth middleware
│   │   └── lib/             # Prisma + Redis clients
│   ├── prisma/
│   │   └── schema.prisma    # Database schema
│   └── Dockerfile
├── docker-compose.yml       # Full stack
├── docker-compose.dev.yml   # Infra only (dev)
└── .github/
    └── workflows/
        └── ci.yml           # GitHub Actions
```

## License

MIT
