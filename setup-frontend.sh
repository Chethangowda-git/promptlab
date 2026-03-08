#!/bin/bash
set -e

echo "⚛️  Setting up PromptLab frontend..."

cd client/src

# ── CLEAN DEFAULT FILES ───────────────────────────────────────────────────────
rm -f App.css assets/react.svg

# ── API CLIENT ────────────────────────────────────────────────────────────────
mkdir -p lib

cat > lib/api.ts << 'EOF'
import axios from 'axios'

const api = axios.create({
  baseURL: 'http://localhost:4000',
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

# ── STORE ─────────────────────────────────────────────────────────────────────
mkdir -p store

cat > store/auth.store.ts << 'EOF'
import { create } from 'zustand'
import api from '../lib/api'

interface User {
  id: string
  email: string
  name: string
  role: string
}

interface AuthState {
  user: User | null
  token: string | null
  loading: boolean
  login: (email: string, password: string) => Promise<void>
  register: (email: string, name: string, password: string) => Promise<void>
  logout: () => void
  fetchMe: () => Promise<void>
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: localStorage.getItem('token'),
  loading: false,

  login: async (email, password) => {
    const res = await api.post('/api/auth/login', { email, password })
    localStorage.setItem('token', res.data.token)
    set({ user: res.data.user, token: res.data.token })
  },

  register: async (email, name, password) => {
    const res = await api.post('/api/auth/register', { email, name, password })
    localStorage.setItem('token', res.data.token)
    set({ user: res.data.user, token: res.data.token })
  },

  logout: () => {
    localStorage.removeItem('token')
    set({ user: null, token: null })
  },

  fetchMe: async () => {
    try {
      const res = await api.get('/api/auth/me')
      set({ user: res.data })
    } catch {
      localStorage.removeItem('token')
      set({ user: null, token: null })
    }
  },
}))
EOF

cat > store/prompt.store.ts << 'EOF'
import { create } from 'zustand'
import api from '../lib/api'

interface PromptVersion {
  id: string
  versionNumber: number
  systemPrompt: string | null
  userPromptTemplate: string
  variables: any[]
  modelConfig: any
  tag: string | null
  createdAt: string
}

interface Prompt {
  id: string
  name: string
  description: string | null
  status: string
  currentVersionId: string | null
  versions: PromptVersion[]
  createdAt: string
  updatedAt: string
}

interface ExecuteResult {
  output: string
  model: string
  provider: string
  latencyMs: number
  inputTokens: number
  outputTokens: number
  cost: number
  error?: string
}

interface ImproveResult {
  improvedPrompt: string
  improvedSystemPrompt: string
  changes: { type: string; description: string }[]
  latencyMs: number
}

interface PromptState {
  prompts: Prompt[]
  activePrompt: Prompt | null
  executeResults: ExecuteResult[]
  improveResult: ImproveResult | null
  executing: boolean
  improving: boolean
  fetchPrompts: (projectId?: string) => Promise<void>
  fetchPrompt: (id: string) => Promise<void>
  createPrompt: (data: { projectId: string; name: string; description?: string }) => Promise<Prompt>
  createVersion: (promptId: string, data: any) => Promise<void>
  executePrompt: (data: any) => Promise<void>
  executeBatch: (data: any) => Promise<void>
  improvePrompt: (prompt: string, systemPrompt?: string) => Promise<void>
  clearResults: () => void
}

export const usePromptStore = create<PromptState>((set) => ({
  prompts: [],
  activePrompt: null,
  executeResults: [],
  improveResult: null,
  executing: false,
  improving: false,

  fetchPrompts: async (projectId) => {
    const res = await api.get('/api/prompts', { params: projectId ? { projectId } : {} })
    set({ prompts: res.data })
  },

  fetchPrompt: async (id) => {
    const res = await api.get(`/api/prompts/${id}`)
    set({ activePrompt: res.data })
  },

  createPrompt: async (data) => {
    const res = await api.post('/api/prompts', data)
    set((s) => ({ prompts: [res.data, ...s.prompts] }))
    return res.data
  },

  createVersion: async (promptId, data) => {
    await api.post(`/api/prompts/${promptId}/versions`, data)
    const res = await api.get(`/api/prompts/${promptId}`)
    set({ activePrompt: res.data })
  },

  executePrompt: async (data) => {
    set({ executing: true, executeResults: [] })
    try {
      const res = await api.post('/api/execute', data)
      set({ executeResults: [res.data] })
    } finally {
      set({ executing: false })
    }
  },

  executeBatch: async (data) => {
    set({ executing: true, executeResults: [] })
    try {
      const res = await api.post('/api/execute/batch', data)
      set({ executeResults: res.data })
    } finally {
      set({ executing: false })
    }
  },

  improvePrompt: async (prompt, systemPrompt) => {
    set({ improving: true, improveResult: null })
    try {
      const res = await api.post('/api/execute/improve', { prompt, systemPrompt })
      set({ improveResult: res.data })
    } finally {
      set({ improving: false })
    }
  },

  clearResults: () => set({ executeResults: [], improveResult: null }),
}))
EOF

# ── TYPES ─────────────────────────────────────────────────────────────────────
mkdir -p types

cat > types/index.ts << 'EOF'
export interface Provider {
  name: string
  models: string[]
}

export interface ModelTarget {
  provider: string
  model: string
}
EOF

# ── AUTH PAGES ────────────────────────────────────────────────────────────────
mkdir -p pages/auth

cat > pages/auth/Login.tsx << 'EOF'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuthStore } from '../../store/auth.store'

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const login = useAuthStore((s) => s.login)
  const navigate = useNavigate()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await login(email, password)
      navigate('/dashboard')
    } catch {
      setError('Invalid email or password')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center px-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-indigo-400">PromptLab</h1>
          <p className="text-gray-500 mt-1 text-sm">Prompt Engineering Studio</p>
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-8">
          <h2 className="text-xl font-semibold text-white mb-6">Sign in</h2>
          {error && (
            <div className="mb-4 px-4 py-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-400 text-sm">
              {error}
            </div>
          )}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm text-gray-400 mb-1">Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white text-sm focus:outline-none focus:border-indigo-500"
                placeholder="you@example.com"
                required
              />
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-1">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white text-sm focus:outline-none focus:border-indigo-500"
                placeholder="••••••••"
                required
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-medium py-2.5 rounded-lg text-sm transition-colors"
            >
              {loading ? 'Signing in...' : 'Sign in'}
            </button>
          </form>
          <p className="text-center text-gray-500 text-sm mt-6">
            No account?{' '}
            <Link to="/register" className="text-indigo-400 hover:text-indigo-300">
              Register
            </Link>
          </p>
        </div>
      </div>
    </div>
  )
}
EOF

cat > pages/auth/Register.tsx << 'EOF'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuthStore } from '../../store/auth.store'

export default function Register() {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const register = useAuthStore((s) => s.register)
  const navigate = useNavigate()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await register(email, name, password)
      navigate('/dashboard')
    } catch {
      setError('Registration failed. Email may already be in use.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center px-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <h1 className="text-3xl font-bold text-indigo-400">PromptLab</h1>
          <p className="text-gray-500 mt-1 text-sm">Prompt Engineering Studio</p>
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-8">
          <h2 className="text-xl font-semibold text-white mb-6">Create account</h2>
          {error && (
            <div className="mb-4 px-4 py-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-400 text-sm">
              {error}
            </div>
          )}
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm text-gray-400 mb-1">Name</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white text-sm focus:outline-none focus:border-indigo-500"
                placeholder="Your name"
                required
              />
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-1">Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white text-sm focus:outline-none focus:border-indigo-500"
                placeholder="you@example.com"
                required
              />
            </div>
            <div>
              <label className="block text-sm text-gray-400 mb-1">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white text-sm focus:outline-none focus:border-indigo-500"
                placeholder="••••••••"
                required
                minLength={6}
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-medium py-2.5 rounded-lg text-sm transition-colors"
            >
              {loading ? 'Creating account...' : 'Create account'}
            </button>
          </form>
          <p className="text-center text-gray-500 text-sm mt-6">
            Already have an account?{' '}
            <Link to="/login" className="text-indigo-400 hover:text-indigo-300">
              Sign in
            </Link>
          </p>
        </div>
      </div>
    </div>
  )
}
EOF

# ── LAYOUT ────────────────────────────────────────────────────────────────────
mkdir -p components/layout

cat > components/layout/Sidebar.tsx << 'EOF'
import { NavLink, useNavigate } from 'react-router-dom'
import { useAuthStore } from '../../store/auth.store'

const links = [
  { to: '/dashboard', label: 'Dashboard', icon: '⊞' },
  { to: '/prompts', label: 'Prompts', icon: '✦' },
  { to: '/execute', label: 'Execute', icon: '▶' },
]

export default function Sidebar() {
  const { user, logout } = useAuthStore()
  const navigate = useNavigate()

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  return (
    <aside className="w-56 bg-gray-900 border-r border-gray-800 flex flex-col h-screen fixed left-0 top-0">
      <div className="px-5 py-5 border-b border-gray-800">
        <h1 className="text-lg font-bold text-indigo-400">PromptLab</h1>
        <p className="text-xs text-gray-500 mt-0.5">Prompt Engineering Studio</p>
      </div>
      <nav className="flex-1 px-3 py-4 space-y-1">
        {links.map((link) => (
          <NavLink
            key={link.to}
            to={link.to}
            className={({ isActive }) =>
              `flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors ${
                isActive
                  ? 'bg-indigo-600/20 text-indigo-400'
                  : 'text-gray-400 hover:text-white hover:bg-gray-800'
              }`
            }
          >
            <span>{link.icon}</span>
            {link.label}
          </NavLink>
        ))}
      </nav>
      <div className="px-4 py-4 border-t border-gray-800">
        <p className="text-xs text-gray-400 truncate mb-2">{user?.name}</p>
        <button
          onClick={handleLogout}
          className="text-xs text-gray-500 hover:text-red-400 transition-colors"
        >
          Sign out
        </button>
      </div>
    </aside>
  )
}
EOF

cat > components/layout/AppLayout.tsx << 'EOF'
import { useEffect } from 'react'
import { Outlet, useNavigate } from 'react-router-dom'
import { useAuthStore } from '../../store/auth.store'
import Sidebar from './Sidebar'

export default function AppLayout() {
  const { token, user, fetchMe } = useAuthStore()
  const navigate = useNavigate()

  useEffect(() => {
    if (!token) {
      navigate('/login')
      return
    }
    if (!user) fetchMe()
  }, [token])

  if (!token) return null

  return (
    <div className="flex min-h-screen bg-gray-950 text-white">
      <Sidebar />
      <main className="ml-56 flex-1 p-8">
        <Outlet />
      </main>
    </div>
  )
}
EOF

# ── DASHBOARD PAGE ────────────────────────────────────────────────────────────
mkdir -p pages

cat > pages/Dashboard.tsx << 'EOF'
import { useAuthStore } from '../store/auth.store'

export default function Dashboard() {
  const user = useAuthStore((s) => s.user)

  return (
    <div>
      <h2 className="text-2xl font-bold text-white mb-1">
        Welcome back, {user?.name} 👋
      </h2>
      <p className="text-gray-500 text-sm mb-8">Here's what you can do in PromptLab</p>

      <div className="grid grid-cols-3 gap-4">
        {[
          { label: 'Prompts', desc: 'Create and manage prompt versions', icon: '✦', color: 'indigo' },
          { label: 'Execute', desc: 'Run prompts across multiple models', icon: '▶', color: 'green' },
          { label: 'Improve', desc: 'AI-powered prompt optimization', icon: '✨', color: 'purple' },
        ].map((card) => (
          <div
            key={card.label}
            className="bg-gray-900 border border-gray-800 rounded-xl p-6 hover:border-gray-700 transition-colors"
          >
            <div className="text-2xl mb-3">{card.icon}</div>
            <h3 className="text-white font-semibold mb-1">{card.label}</h3>
            <p className="text-gray-500 text-sm">{card.desc}</p>
          </div>
        ))}
      </div>

      <div className="mt-8 bg-gray-900 border border-gray-800 rounded-xl p-6">
        <h3 className="text-white font-semibold mb-4">Supported Models</h3>
        <div className="grid grid-cols-2 gap-3">
          {[
            { provider: 'Groq', models: ['llama3-8b-8192', 'llama3-70b-8192', 'mixtral-8x7b-32768', 'gemma2-9b-it'], color: 'orange' },
            { provider: 'Gemini', models: ['gemini-1.5-flash', 'gemini-1.5-pro'], color: 'blue' },
          ].map((p) => (
            <div key={p.provider} className="bg-gray-800 rounded-lg p-4">
              <p className="text-sm font-medium text-white mb-2">{p.provider}</p>
              <div className="space-y-1">
                {p.models.map((m) => (
                  <span key={m} className="block text-xs text-gray-400">{m}</span>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
EOF

# ── APP ROUTER ────────────────────────────────────────────────────────────────
cat > App.tsx << 'EOF'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import AppLayout from './components/layout/AppLayout'
import Login from './pages/auth/Login'
import Register from './pages/auth/Register'
import Dashboard from './pages/Dashboard'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route element={<AppLayout />}>
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
EOF

echo ""
echo "✅ Frontend phase 1 complete!"
echo "Run: cd client && npm run dev"