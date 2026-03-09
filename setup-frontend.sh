#!/bin/bash
set -e

echo "⚛️  Building Prompts + Execute pages..."

cd client/src

# ── PROMPTS LIST PAGE ─────────────────────────────────────────────────────────
mkdir -p pages/prompts

cat > pages/prompts/PromptsPage.tsx << 'EOF'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { usePromptStore } from '../../store/prompt.store'

const DEFAULT_PROJECT_ID = 'default-project'

export default function PromptsPage() {
  const { prompts, fetchPrompts, createPrompt } = usePromptStore()
  const navigate = useNavigate()
  const [showCreate, setShowCreate] = useState(false)
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    fetchPrompts()
  }, [])

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    try {
      const prompt = await createPrompt({ projectId: DEFAULT_PROJECT_ID, name, description })
      setShowCreate(false)
      setName('')
      setDescription('')
      navigate(`/prompts/${prompt.id}`)
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

# ── PROMPT EDITOR PAGE ────────────────────────────────────────────────────────
cat > pages/prompts/PromptEditor.tsx << 'EOF'
import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import Editor from '@monaco-editor/react'
import { usePromptStore } from '../../store/prompt.store'

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
    if (id) fetchPrompt(id)
  }, [id])

  useEffect(() => {
    if (activePrompt?.versions?.[0]) {
      setSystemPrompt(activePrompt.versions[0].systemPrompt ?? '')
      setUserPrompt(activePrompt.versions[0].userPromptTemplate ?? '')
    }
  }, [activePrompt])

  const handleSave = async () => {
    if (!id || !userPrompt.trim()) return
    setSaving(true)
    try {
      await createVersion(id, { systemPrompt, userPromptTemplate: userPrompt })
    } finally {
      setSaving(false)
    }
  }

  const handleImprove = async () => {
    await improvePrompt(userPrompt, systemPrompt)
    setShowImprove(true)
  }

  const handleAcceptImprove = () => {
    if (!improveResult) return
    setUserPrompt(improveResult.improvedPrompt)
    if (improveResult.improvedSystemPrompt) setSystemPrompt(improveResult.improvedSystemPrompt)
    setShowImprove(false)
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
          {/* System Prompt */}
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
              options={{
                minimap: { enabled: false },
                fontSize: 13,
                lineNumbers: 'off',
                wordWrap: 'on',
                scrollBeyondLastLine: false,
                padding: { top: 12, bottom: 12 },
              }}
            />
          </div>

          {/* User Prompt */}
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
              options={{
                minimap: { enabled: false },
                fontSize: 13,
                lineNumbers: 'off',
                wordWrap: 'on',
                scrollBeyondLastLine: false,
                padding: { top: 12, bottom: 12 },
              }}
            />
          </div>

          {/* Variable hint */}
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

# ── EXECUTE PAGE ──────────────────────────────────────────────────────────────
cat > pages/ExecutePage.tsx << 'EOF'
import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import Editor from '@monaco-editor/react'
import api from '../lib/api'
import { usePromptStore } from '../store/prompt.store'
import { Provider, ModelTarget } from '../types'

export default function ExecutePage() {
  const [searchParams] = useSearchParams()
  const { executeResults, executeBatch, executing, clearResults } = usePromptStore()

  const [providers, setProviders] = useState<Provider[]>([])
  const [systemPrompt, setSystemPrompt] = useState('')
  const [userPrompt, setUserPrompt] = useState('')
  const [selectedModels, setSelectedModels] = useState<ModelTarget[]>([])
  const [temperature, setTemperature] = useState(0.7)
  const [maxTokens, setMaxTokens] = useState(1024)

  useEffect(() => {
    api.get('/api/execute/providers').then((r) => {
      setProviders(r.data)
      if (r.data.length > 0) {
        setSelectedModels([{ provider: r.data[0].name, model: r.data[0].models[0] }])
      }
    })
    clearResults()
  }, [])

  const toggleModel = (provider: string, model: string) => {
    const key = `${provider}:${model}`
    const exists = selectedModels.find((m) => `${m.provider}:${m.model}` === key)
    if (exists) {
      if (selectedModels.length > 1) setSelectedModels((s) => s.filter((m) => `${m.provider}:${m.model}` !== key))
    } else {
      setSelectedModels((s) => [...s, { provider, model }])
    }
  }

  const isSelected = (provider: string, model: string) =>
    !!selectedModels.find((m) => m.provider === provider && m.model === model)

  const handleExecute = () => {
    executeBatch({ models: selectedModels, systemPrompt, userPrompt, temperature, maxTokens })
  }

  return (
    <div className="max-w-7xl mx-auto">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-white">Execute</h2>
        <p className="text-gray-500 text-sm mt-1">Run prompts across multiple models simultaneously</p>
      </div>

      <div className="grid grid-cols-3 gap-6">
        {/* Left: Config */}
        <div className="col-span-1 space-y-4">
          {/* Model selection */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4">
            <p className="text-sm font-medium text-gray-300 mb-3">Models</p>
            {providers.map((p) => (
              <div key={p.name} className="mb-3">
                <p className="text-xs text-gray-500 uppercase tracking-wider mb-2">{p.name}</p>
                <div className="space-y-1">
                  {p.models.map((model) => (
                    <label
                      key={model}
                      className="flex items-center gap-2.5 cursor-pointer group"
                    >
                      <input
                        type="checkbox"
                        checked={isSelected(p.name, model)}
                        onChange={() => toggleModel(p.name, model)}
                        className="accent-indigo-500"
                      />
                      <span className={`text-sm transition-colors ${
                        isSelected(p.name, model) ? 'text-white' : 'text-gray-500 group-hover:text-gray-300'
                      }`}>
                        {model}
                      </span>
                    </label>
                  ))}
                </div>
              </div>
            ))}
          </div>

          {/* Parameters */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4 space-y-4">
            <p className="text-sm font-medium text-gray-300">Parameters</p>
            <div>
              <div className="flex justify-between mb-1">
                <label className="text-xs text-gray-500">Temperature</label>
                <span className="text-xs text-indigo-400">{temperature}</span>
              </div>
              <input
                type="range" min="0" max="1" step="0.1"
                value={temperature}
                onChange={(e) => setTemperature(Number(e.target.value))}
                className="w-full accent-indigo-500"
              />
            </div>
            <div>
              <div className="flex justify-between mb-1">
                <label className="text-xs text-gray-500">Max Tokens</label>
                <span className="text-xs text-indigo-400">{maxTokens}</span>
              </div>
              <input
                type="range" min="256" max="4096" step="256"
                value={maxTokens}
                onChange={(e) => setMaxTokens(Number(e.target.value))}
                className="w-full accent-indigo-500"
              />
            </div>
          </div>

          <button
            onClick={handleExecute}
            disabled={executing || !userPrompt.trim() || selectedModels.length === 0}
            className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-medium py-3 rounded-lg text-sm transition-colors"
          >
            {executing ? '⏳ Running...' : `▶ Run on ${selectedModels.length} model${selectedModels.length !== 1 ? 's' : ''}`}
          </button>
        </div>

        {/* Right: Prompts + Results */}
        <div className="col-span-2 space-y-4">
          {/* System prompt */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
            <div className="px-4 py-3 border-b border-gray-800">
              <span className="text-sm font-medium text-gray-300">System Prompt</span>
            </div>
            <Editor
              height="120px"
              language="markdown"
              theme="vs-dark"
              value={systemPrompt}
              onChange={(v) => setSystemPrompt(v ?? '')}
              options={{ minimap: { enabled: false }, fontSize: 13, lineNumbers: 'off', wordWrap: 'on', scrollBeyondLastLine: false, padding: { top: 10 } }}
            />
          </div>

          {/* User prompt */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
            <div className="px-4 py-3 border-b border-gray-800">
              <span className="text-sm font-medium text-gray-300">User Prompt</span>
            </div>
            <Editor
              height="160px"
              language="markdown"
              theme="vs-dark"
              value={userPrompt}
              onChange={(v) => setUserPrompt(v ?? '')}
              options={{ minimap: { enabled: false }, fontSize: 13, lineNumbers: 'off', wordWrap: 'on', scrollBeyondLastLine: false, padding: { top: 10 } }}
            />
          </div>

          {/* Results */}
          {executeResults.length > 0 && (
            <div>
              <p className="text-sm font-medium text-gray-300 mb-3">Results</p>
              <div className={`grid gap-4 ${executeResults.length > 1 ? 'grid-cols-2' : 'grid-cols-1'}`}>
                {executeResults.map((r, i) => (
                  <div key={i} className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
                    <div className="px-4 py-3 border-b border-gray-800 flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className={`text-xs px-2 py-0.5 rounded-full ${
                          r.provider === 'groq' ? 'bg-orange-500/20 text-orange-400' : 'bg-blue-500/20 text-blue-400'
                        }`}>
                          {r.provider}
                        </span>
                        <span className="text-xs text-gray-400">{r.model}</span>
                      </div>
                      <div className="flex items-center gap-3 text-xs text-gray-500">
                        <span>⏱ {r.latencyMs}ms</span>
                        <span>↑{r.inputTokens} ↓{r.outputTokens}</span>
                        <span className="text-green-400">${r.cost.toFixed(6)}</span>
                      </div>
                    </div>
                    <div className="p-4">
                      {r.error ? (
                        <p className="text-red-400 text-sm">{r.error}</p>
                      ) : (
                        <p className="text-gray-200 text-sm whitespace-pre-wrap leading-relaxed">{r.output}</p>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {executing && (
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-8 text-center">
              <div className="text-gray-500 text-sm">Running on {selectedModels.length} model{selectedModels.length !== 1 ? 's' : ''}...</div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
EOF

# ── UPDATE APP ROUTER ─────────────────────────────────────────────────────────
cat > App.tsx << 'EOF'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import AppLayout from './components/layout/AppLayout'
import Login from './pages/auth/Login'
import Register from './pages/auth/Register'
import Dashboard from './pages/Dashboard'
import PromptsPage from './pages/prompts/PromptsPage'
import PromptEditor from './pages/prompts/PromptEditor'
import ExecutePage from './pages/ExecutePage'

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
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
EOF

# ── UPDATE SIDEBAR LINKS ──────────────────────────────────────────────────────
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
          onClick={() => { logout(); navigate('/login') }}
          className="text-xs text-gray-500 hover:text-red-400 transition-colors"
        >
          Sign out
        </button>
      </div>
    </aside>
  )
}
EOF

echo ""
echo "✅ Frontend phase 2 complete!"
echo "The dev server will hot-reload automatically."