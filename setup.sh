#!/bin/bash
set -e

echo "🔔 Adding toast notifications and error handling..."

cd client/src

# ── TOAST COMPONENT ───────────────────────────────────────────────────────────
mkdir -p components/ui

cat > components/ui/Toast.tsx << 'EOF'
import { useEffect, useState } from 'react'
import { create } from 'zustand'

type ToastType = 'success' | 'error' | 'info' | 'warning'

interface Toast {
  id: string
  message: string
  type: ToastType
}

interface ToastState {
  toasts: Toast[]
  add: (message: string, type?: ToastType) => void
  remove: (id: string) => void
}

export const useToastStore = create<ToastState>((set) => ({
  toasts: [],
  add: (message, type = 'info') => {
    const id = Math.random().toString(36).slice(2)
    set((s) => ({ toasts: [...s.toasts, { id, message, type }] }))
    setTimeout(() => {
      set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) }))
    }, 4000)
  },
  remove: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),
}))

export const toast = {
  success: (msg: string) => useToastStore.getState().add(msg, 'success'),
  error: (msg: string) => useToastStore.getState().add(msg, 'error'),
  info: (msg: string) => useToastStore.getState().add(msg, 'info'),
  warning: (msg: string) => useToastStore.getState().add(msg, 'warning'),
}

export function ToastContainer() {
  const { toasts, remove } = useToastStore()

  return (
    <div className="fixed bottom-4 right-4 z-[100] flex flex-col gap-2">
      {toasts.map((t) => (
        <ToastItem key={t.id} toast={t} onRemove={remove} />
      ))}
    </div>
  )
}

function ToastItem({ toast: t, onRemove }: { toast: Toast; onRemove: (id: string) => void }) {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    requestAnimationFrame(() => setVisible(true))
  }, [])

  const colors = {
    success: 'bg-green-500/10 border-green-500/30 text-green-400',
    error: 'bg-red-500/10 border-red-500/30 text-red-400',
    info: 'bg-indigo-500/10 border-indigo-500/30 text-indigo-400',
    warning: 'bg-yellow-500/10 border-yellow-500/30 text-yellow-400',
  }

  const icons = {
    success: '✓',
    error: '✕',
    info: 'ℹ',
    warning: '⚠',
  }

  return (
    <div
      className={`flex items-center gap-3 px-4 py-3 rounded-lg border text-sm font-medium
        transition-all duration-300 cursor-pointer max-w-sm
        ${colors[t.type]}
        ${visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-2'}
      `}
      onClick={() => onRemove(t.id)}
    >
      <span>{icons[t.type]}</span>
      <span>{t.message}</span>
    </div>
  )
}
EOF

# ── UPDATE APP.TSX TO INCLUDE TOAST CONTAINER ─────────────────────────────────
cat > App.tsx << 'EOF'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import AppLayout from './components/layout/AppLayout'
import Login from './pages/auth/Login'
import Register from './pages/auth/Register'
import Dashboard from './pages/Dashboard'
import PromptsPage from './pages/prompts/PromptsPage'
import PromptEditor from './pages/prompts/PromptEditor'
import ExecutePage from './pages/ExecutePage'
import EvaluationPage from './pages/evaluation/EvaluationPage'
import ExportPage from './pages/export/ExportPage'
import ExperimentsPage from './pages/experiments/ExperimentsPage'
import { ToastContainer } from './components/ui/Toast'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route element={<AppLayout />}>
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/prompts" element={<PromptsPage />} />
          <Route path="/prompts/:id" element={<PromptEditor />} />
          <Route path="/execute" element={<ExecutePage />} />
          <Route path="/evaluate" element={<EvaluationPage />} />
          <Route path="/export" element={<ExportPage />} />
          <Route path="/experiments" element={<ExperimentsPage />} />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Route>
      </Routes>
      <ToastContainer />
    </BrowserRouter>
  )
}
EOF

# ── UPDATE PROMPT EDITOR WITH TOASTS ─────────────────────────────────────────
cat > pages/prompts/PromptEditor.tsx << 'EOF'
import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import Editor from '@monaco-editor/react'
import { usePromptStore } from '../../store/prompt.store'
import { toast } from '../../components/ui/Toast'

export default function PromptEditor() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { activePrompt, fetchPrompt, createVersion, improvePrompt, improveResult, improving } = usePromptStore()

  const [systemPrompt, setSystemPrompt] = useState('')
  const [userPrompt, setUserPrompt] = useState('')
  const [saving, setSaving] = useState(false)
  const [showImprove, setShowImprove] = useState(false)
  const [activeTab, setActiveTab] = useState<'editor' | 'versions'>('editor')

  useEffect(() => {
    if (id) fetchPrompt(id).catch(() => toast.error('Failed to load prompt'))
  }, [id])

  useEffect(() => {
    if (activePrompt?.versions?.[0]) {
      setSystemPrompt(activePrompt.versions[0].systemPrompt ?? '')
      setUserPrompt(activePrompt.versions[0].userPromptTemplate ?? '')
    }
  }, [activePrompt])

  const handleSave = async () => {
    if (!id || !userPrompt.trim()) {
      toast.warning('User prompt cannot be empty')
      return
    }
    setSaving(true)
    try {
      await createVersion(id, { systemPrompt, userPromptTemplate: userPrompt })
      toast.success(`Version v${(activePrompt?.versions?.length ?? 0) + 1} saved`)
    } catch {
      toast.error('Failed to save version')
    } finally {
      setSaving(false)
    }
  }

  const handleImprove = async () => {
    if (!userPrompt.trim()) {
      toast.warning('Add a user prompt before improving')
      return
    }
    try {
      await improvePrompt(userPrompt, systemPrompt)
      setShowImprove(true)
    } catch {
      toast.error('AI improvement failed — check your API key')
    }
  }

  const handleAcceptImprove = () => {
    if (!improveResult) return
    if (improveResult.improvedSystemPrompt) setSystemPrompt(improveResult.improvedSystemPrompt)
    setUserPrompt(improveResult.improvedPrompt)
    setShowImprove(false)
    toast.success('Prompt improved — click Save Version to keep changes')
  }

  if (!activePrompt) return (
    <div className="flex items-center justify-center h-64 text-gray-500">Loading...</div>
  )

  return (
    <div className="max-w-6xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <button onClick={() => navigate('/prompts')} className="text-gray-500 hover:text-white transition-colors text-sm">
            ← Prompts
          </button>
          <span className="text-gray-700">/</span>
          <h2 className="text-white font-semibold">{activePrompt.name}</h2>
          <span className="text-xs bg-gray-800 text-gray-400 px-2 py-0.5 rounded-full">
            v{activePrompt.versions?.length ?? 0}
          </span>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={handleImprove}
            disabled={improving || !userPrompt.trim()}
            className="flex items-center gap-2 bg-purple-600/20 hover:bg-purple-600/30 border border-purple-500/30 disabled:opacity-50 text-purple-400 text-sm font-medium px-4 py-2 rounded-lg transition-colors"
          >
            {improving ? '✨ Improving...' : '✨ Improve with AI'}
          </button>
          <button
            onClick={() => navigate(`/execute?promptId=${id}`)}
            className="bg-green-600/20 hover:bg-green-600/30 border border-green-500/30 text-green-400 text-sm font-medium px-4 py-2 rounded-lg transition-colors"
          >
            ▶ Execute
          </button>
          <button
            onClick={handleSave}
            disabled={saving}
            className="bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors"
          >
            {saving ? 'Saving...' : 'Save Version'}
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-4 bg-gray-900 border border-gray-800 rounded-lg p-1 w-fit">
        {(['editor', 'versions'] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-1.5 rounded-md text-sm font-medium transition-colors capitalize ${
              activeTab === tab ? 'bg-gray-700 text-white' : 'text-gray-500 hover:text-gray-300'
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      {activeTab === 'editor' && (
        <div className="grid grid-cols-2 gap-4">
          <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
            <div className="px-4 py-3 border-b border-gray-800 flex items-center justify-between">
              <span className="text-sm font-medium text-gray-300">System Prompt</span>
              <span className="text-xs text-gray-600">{systemPrompt.length} chars</span>
            </div>
            <Editor
              height="300px"
              language="markdown"
              theme="vs-dark"
              value={systemPrompt}
              onChange={(v) => setSystemPrompt(v ?? '')}
              options={{ minimap: { enabled: false }, fontSize: 13, lineNumbers: 'off', wordWrap: 'on', scrollBeyondLastLine: false, padding: { top: 12, bottom: 12 } }}
            />
          </div>

          <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
            <div className="px-4 py-3 border-b border-gray-800 flex items-center justify-between">
              <span className="text-sm font-medium text-gray-300">User Prompt</span>
              <span className="text-xs text-gray-600">{userPrompt.length} chars</span>
            </div>
            <Editor
              height="300px"
              language="markdown"
              theme="vs-dark"
              value={userPrompt}
              onChange={(v) => setUserPrompt(v ?? '')}
              options={{ minimap: { enabled: false }, fontSize: 13, lineNumbers: 'off', wordWrap: 'on', scrollBeyondLastLine: false, padding: { top: 12, bottom: 12 } }}
            />
          </div>

          <div className="col-span-2 bg-gray-900/50 border border-gray-800 rounded-lg px-4 py-3">
            <p className="text-xs text-gray-500">
              💡 Use <code className="bg-gray-800 px-1.5 py-0.5 rounded text-indigo-400">{`{{variable_name}}`}</code> syntax to define dynamic variables in your prompts.
            </p>
          </div>
        </div>
      )}

      {activeTab === 'versions' && (
        <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
          {activePrompt.versions?.length === 0 ? (
            <div className="text-center py-12 text-gray-500 text-sm">No versions yet — save a version first</div>
          ) : (
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-800">
                  <th className="text-left px-5 py-3 text-xs text-gray-500 font-medium">Version</th>
                  <th className="text-left px-5 py-3 text-xs text-gray-500 font-medium">Tag</th>
                  <th className="text-left px-5 py-3 text-xs text-gray-500 font-medium">Created</th>
                  <th className="text-left px-5 py-3 text-xs text-gray-500 font-medium">Preview</th>
                </tr>
              </thead>
              <tbody>
                {activePrompt.versions?.map((v) => (
                  <tr
                    key={v.id}
                    onClick={() => {
                      setSystemPrompt(v.systemPrompt ?? '')
                      setUserPrompt(v.userPromptTemplate)
                      setActiveTab('editor')
                      toast.info(`Loaded v${v.versionNumber}`)
                    }}
                    className="border-b border-gray-800/50 hover:bg-gray-800/30 cursor-pointer transition-colors"
                  >
                    <td className="px-5 py-3">
                      <span className="text-indigo-400 font-mono text-sm">v{v.versionNumber}</span>
                    </td>
                    <td className="px-5 py-3">
                      {v.tag ? (
                        <span className={`text-xs px-2 py-0.5 rounded-full ${
                          v.tag === 'PRODUCTION' ? 'bg-green-500/20 text-green-400' : 'bg-yellow-500/20 text-yellow-400'
                        }`}>
                          {v.tag.toLowerCase()}
                        </span>
                      ) : (
                        <span className="text-gray-600 text-xs">—</span>
                      )}
                    </td>
                    <td className="px-5 py-3 text-gray-500 text-sm">
                      {new Date(v.createdAt).toLocaleString()}
                    </td>
                    <td className="px-5 py-3 text-gray-500 text-sm truncate max-w-xs">
                      {v.userPromptTemplate.slice(0, 60)}...
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* AI Improve Modal */}
      {showImprove && improveResult && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-6">
          <div className="bg-gray-900 border border-gray-700 rounded-xl w-full max-w-2xl max-h-[80vh] overflow-y-auto">
            <div className="px-6 py-4 border-b border-gray-800 flex items-center justify-between">
              <h3 className="text-white font-semibold">✨ AI Improved Prompt</h3>
              <button onClick={() => setShowImprove(false)} className="text-gray-500 hover:text-white">✕</button>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <p className="text-xs text-gray-500 uppercase tracking-wider mb-2">Improved Prompt</p>
                <div className="bg-gray-800 rounded-lg p-4 text-gray-200 text-sm whitespace-pre-wrap">
                  {improveResult.improvedPrompt}
                </div>
              </div>
              {improveResult.changes?.length > 0 && (
                <div>
                  <p className="text-xs text-gray-500 uppercase tracking-wider mb-2">What Changed</p>
                  <div className="space-y-2">
                    {improveResult.changes.map((c, i) => (
                      <div key={i} className="flex gap-3 bg-gray-800/50 rounded-lg p-3">
                        <span className={`text-xs px-2 py-0.5 rounded-full h-fit mt-0.5 ${
                          c.type === 'clarity' ? 'bg-blue-500/20 text-blue-400' :
                          c.type === 'specificity' ? 'bg-green-500/20 text-green-400' :
                          c.type === 'efficiency' ? 'bg-yellow-500/20 text-yellow-400' :
                          'bg-purple-500/20 text-purple-400'
                        }`}>
                          {c.type}
                        </span>
                        <p className="text-gray-300 text-sm">{c.description}</p>
                      </div>
                    ))}
                  </div>
                </div>
              )}
              <div className="flex gap-3 pt-2">
                <button
                  onClick={() => setShowImprove(false)}
                  className="flex-1 bg-gray-800 hover:bg-gray-700 text-gray-300 text-sm py-2.5 rounded-lg transition-colors"
                >
                  Discard
                </button>
                <button
                  onClick={handleAcceptImprove}
                  className="flex-1 bg-indigo-600 hover:bg-indigo-500 text-white text-sm py-2.5 rounded-lg transition-colors"
                >
                  Accept & Replace
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
EOF

# ── UPDATE PROMPTS PAGE WITH TOASTS ──────────────────────────────────────────
cat > pages/prompts/PromptsPage.tsx << 'EOF'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { usePromptStore } from '../../store/prompt.store'
import { useAuthStore } from '../../store/auth.store'
import { toast } from '../../components/ui/Toast'

export default function PromptsPage() {
  const { prompts, fetchPrompts, createPrompt } = usePromptStore()
  const user = useAuthStore((s) => s.user)
  const navigate = useNavigate()
  const [showCreate, setShowCreate] = useState(false)
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    fetchPrompts().catch(() => toast.error('Failed to load prompts'))
  }, [])

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault()
    const projectId = (user as any)?.defaultProjectId
    if (!projectId) {
      toast.error('No project found — please log out and log back in')
      return
    }
    setLoading(true)
    try {
      const prompt = await createPrompt({ projectId, name, description })
      toast.success(`Prompt "${name}" created`)
      setShowCreate(false)
      setName('')
      setDescription('')
      navigate(`/prompts/${prompt.id}`)
    } catch {
      toast.error('Failed to create prompt')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-5xl mx-auto">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h2 className="text-2xl font-bold text-white">Prompts</h2>
          <p className="text-gray-500 text-sm mt-1">Manage and version your prompts</p>
        </div>
        <button
          onClick={() => setShowCreate(true)}
          className="bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors"
        >
          + New Prompt
        </button>
      </div>

      {showCreate && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50">
          <div className="bg-gray-900 border border-gray-700 rounded-xl p-6 w-full max-w-md">
            <h3 className="text-white font-semibold mb-4">New Prompt</h3>
            <form onSubmit={handleCreate} className="space-y-4">
              <div>
                <label className="block text-sm text-gray-400 mb-1">Name</label>
                <input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white text-sm focus:outline-none focus:border-indigo-500"
                  placeholder="e.g. Summarization Prompt"
                  required
                />
              </div>
              <div>
                <label className="block text-sm text-gray-400 mb-1">Description</label>
                <input
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className="w-full bg-gray-800 border border-gray-700 rounded-lg px-4 py-2.5 text-white text-sm focus:outline-none focus:border-indigo-500"
                  placeholder="Optional"
                />
              </div>
              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowCreate(false)}
                  className="flex-1 bg-gray-800 hover:bg-gray-700 text-gray-300 text-sm py-2.5 rounded-lg transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="flex-1 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-sm py-2.5 rounded-lg transition-colors"
                >
                  {loading ? 'Creating...' : 'Create'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {prompts.length === 0 ? (
        <div className="text-center py-24 bg-gray-900 border border-gray-800 rounded-xl">
          <p className="text-4xl mb-3">✦</p>
          <p className="text-white font-medium mb-1">No prompts yet</p>
          <p className="text-gray-500 text-sm mb-6">Create your first prompt to get started</p>
          <button
            onClick={() => setShowCreate(true)}
            className="bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors"
          >
            + New Prompt
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-3">
          {prompts.map((p) => (
            <div
              key={p.id}
              onClick={() => navigate(`/prompts/${p.id}`)}
              className="bg-gray-900 border border-gray-800 hover:border-gray-600 rounded-xl p-5 cursor-pointer transition-colors flex items-center justify-between group"
            >
              <div>
                <div className="flex items-center gap-3 mb-1">
                  <h3 className="text-white font-medium">{p.name}</h3>
                  <span className={`text-xs px-2 py-0.5 rounded-full ${
                    p.status === 'PRODUCTION' ? 'bg-green-500/20 text-green-400' :
                    p.status === 'TESTING' ? 'bg-yellow-500/20 text-yellow-400' :
                    'bg-gray-700 text-gray-400'
                  }`}>
                    {p.status.toLowerCase()}
                  </span>
                </div>
                {p.description && <p className="text-gray-500 text-sm">{p.description}</p>}
                <p className="text-gray-600 text-xs mt-2">
                  {p.versions?.length ?? 0} version{p.versions?.length !== 1 ? 's' : ''} · Updated {new Date(p.updatedAt).toLocaleDateString()}
                </p>
              </div>
              <span className="text-gray-600 group-hover:text-gray-400 transition-colors">→</span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
EOF

echo ""
echo "✅ Toast notifications added across the app"
echo "Dev server will hot-reload automatically"