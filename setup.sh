#!/bin/bash
set -e

echo "🔧 Fixing validation across all pages..."

cd client/src

# ── EXECUTE PAGE ──────────────────────────────────────────────────────────────
cat > pages/ExecutePage.tsx << 'EOF'
import { useEffect, useState } from 'react'
import { useSearchParams, useNavigate } from 'react-router-dom'
import Editor from '@monaco-editor/react'
import api from '../lib/api'
import { usePromptStore } from '../store/prompt.store'
import { toast } from '../components/ui/Toast'

interface Provider { name: string; models: string[] }
interface ModelTarget { provider: string; model: string }

export default function ExecutePage() {
  const [searchParams] = useSearchParams()
  const navigate = useNavigate()
  const { executeResults, executeBatch, executing, clearResults } = usePromptStore()

  const [providers, setProviders] = useState<Provider[]>([])
  const [systemPrompt, setSystemPrompt] = useState('')
  const [userPrompt, setUserPrompt] = useState('')
  const [selectedModels, setSelectedModels] = useState<ModelTarget[]>([])
  const [temperature, setTemperature] = useState(0.7)
  const [maxTokens, setMaxTokens] = useState(1024)
  const [unsavedPrompt, setUnsavedPrompt] = useState(false)

  useEffect(() => {
    api.get('/api/execute/providers').then((r) => {
      setProviders(r.data)
      if (r.data.length > 0) {
        setSelectedModels([{ provider: r.data[0].name, model: r.data[0].models[0] }])
      }
    })
    clearResults()

    const promptId = searchParams.get('promptId')
    const unsaved = searchParams.get('unsaved')
    if (unsaved === 'true') setUnsavedPrompt(true)

    if (promptId) {
      api.get(`/api/prompts/${promptId}`).then((r) => {
        const latest = r.data.versions?.[0]
        if (latest) {
          setSystemPrompt(latest.systemPrompt ?? '')
          setUserPrompt(latest.userPromptTemplate ?? '')
        }
      })
    }
  }, [])

  const toggleModel = (provider: string, model: string) => {
    const key = `${provider}:${model}`
    const exists = selectedModels.find((m) => `${m.provider}:${m.model}` === key)
    if (exists) {
      if (selectedModels.length > 1) setSelectedModels((s) => s.filter((m) => `${m.provider}:${m.model}` !== key))
      else toast.warning('At least one model must be selected')
    } else {
      setSelectedModels((s) => [...s, { provider, model }])
    }
  }

  const isSelected = (provider: string, model: string) =>
    !!selectedModels.find((m) => m.provider === provider && m.model === model)

  const handleExecute = () => {
    if (!userPrompt.trim()) {
      toast.error('User prompt cannot be empty')
      return
    }
    if (selectedModels.length === 0) {
      toast.error('Select at least one model')
      return
    }
    executeBatch({ models: selectedModels, systemPrompt, userPrompt, temperature, maxTokens })
  }

  return (
    <div className="max-w-7xl mx-auto">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-white">Execute</h2>
        <p className="text-gray-500 text-sm mt-1">Run prompts across multiple models simultaneously</p>
      </div>

      {/* Unsaved warning banner */}
      {unsavedPrompt && (
        <div className="mb-4 px-4 py-3 bg-yellow-500/10 border border-yellow-500/30 rounded-lg flex items-center justify-between">
          <p className="text-yellow-400 text-sm">⚠️ You have unsaved changes — go back and save your version first to preserve your work</p>
          <button onClick={() => navigate(-1)} className="text-yellow-400 text-xs underline ml-4">Go back</button>
        </div>
      )}

      <div className="grid grid-cols-3 gap-6">
        {/* Left: Config */}
        <div className="col-span-1 space-y-4">
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4">
            <p className="text-sm font-medium text-gray-300 mb-3">Models <span className="text-red-400">*</span></p>
            {providers.map((p) => (
              <div key={p.name} className="mb-3">
                <p className="text-xs text-gray-500 uppercase tracking-wider mb-2">{p.name}</p>
                <div className="space-y-1">
                  {p.models.map((model) => (
                    <label key={model} className="flex items-center gap-2.5 cursor-pointer group">
                      <input
                        type="checkbox"
                        checked={isSelected(p.name, model)}
                        onChange={() => toggleModel(p.name, model)}
                        className="accent-indigo-500"
                      />
                      <span className={`text-sm transition-colors ${isSelected(p.name, model) ? 'text-white' : 'text-gray-500 group-hover:text-gray-300'}`}>
                        {model}
                      </span>
                    </label>
                  ))}
                </div>
              </div>
            ))}
            {selectedModels.length === 0 && (
              <p className="text-xs text-red-400 mt-1">Select at least one model</p>
            )}
          </div>

          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4 space-y-4">
            <p className="text-sm font-medium text-gray-300">Parameters</p>
            <div>
              <div className="flex justify-between mb-1">
                <label className="text-xs text-gray-500">Temperature</label>
                <span className="text-xs text-indigo-400">{temperature}</span>
              </div>
              <input type="range" min="0" max="1" step="0.1" value={temperature}
                onChange={(e) => setTemperature(Number(e.target.value))}
                className="w-full accent-indigo-500" />
            </div>
            <div>
              <div className="flex justify-between mb-1">
                <label className="text-xs text-gray-500">Max Tokens</label>
                <span className="text-xs text-indigo-400">{maxTokens}</span>
              </div>
              <input type="range" min="256" max="4096" step="256" value={maxTokens}
                onChange={(e) => setMaxTokens(Number(e.target.value))}
                className="w-full accent-indigo-500" />
            </div>
          </div>

          <button
            onClick={handleExecute}
            disabled={executing}
            className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-medium py-3 rounded-lg text-sm transition-colors"
          >
            {executing ? '⏳ Running...' : `▶ Run on ${selectedModels.length} model${selectedModels.length !== 1 ? 's' : ''}`}
          </button>
        </div>

        {/* Right: Prompts + Results */}
        <div className="col-span-2 space-y-4">
          <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
            <div className="px-4 py-3 border-b border-gray-800">
              <span className="text-sm font-medium text-gray-300">System Prompt <span className="text-gray-600 text-xs">(optional)</span></span>
            </div>
            <Editor height="120px" language="markdown" theme="vs-dark" value={systemPrompt}
              onChange={(v) => setSystemPrompt(v ?? '')}
              options={{ minimap: { enabled: false }, fontSize: 13, lineNumbers: 'off', wordWrap: 'on', scrollBeyondLastLine: false, padding: { top: 10 } }} />
          </div>

          <div className={`bg-gray-900 border rounded-xl overflow-hidden ${!userPrompt.trim() ? 'border-red-500/30' : 'border-gray-800'}`}>
            <div className="px-4 py-3 border-b border-gray-800 flex items-center justify-between">
              <span className="text-sm font-medium text-gray-300">User Prompt <span className="text-red-400">*</span></span>
              {!userPrompt.trim() && <span className="text-xs text-red-400">Required</span>}
            </div>
            <Editor height="160px" language="markdown" theme="vs-dark" value={userPrompt}
              onChange={(v) => setUserPrompt(v ?? '')}
              options={{ minimap: { enabled: false }, fontSize: 13, lineNumbers: 'off', wordWrap: 'on', scrollBeyondLastLine: false, padding: { top: 10 } }} />
          </div>

          {executeResults.length > 0 && (
            <div>
              <p className="text-sm font-medium text-gray-300 mb-3">Results</p>
              <div className={`grid gap-4 ${executeResults.length > 1 ? 'grid-cols-2' : 'grid-cols-1'}`}>
                {executeResults.map((r, i) => (
                  <div key={i} className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
                    <div className="px-4 py-3 border-b border-gray-800 flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className={`text-xs px-2 py-0.5 rounded-full ${r.provider === 'groq' ? 'bg-orange-500/20 text-orange-400' : 'bg-blue-500/20 text-blue-400'}`}>
                          {r.provider}
                        </span>
                        <span className="text-xs text-gray-400">{r.model}</span>
                      </div>
                      <div className="flex items-center gap-3 text-xs text-gray-500">
                        <span>⏱ {r.latencyMs}ms</span>
                        <span>↑{r.inputTokens} ↓{r.outputTokens}</span>
                        <span className="text-green-400">${Number(r.cost).toFixed(6)}</span>
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

# ── EVALUATION PAGE ───────────────────────────────────────────────────────────
cat > pages/evaluation/EvaluationPage.tsx << 'EOF'
import { useEffect, useState } from 'react'
import api from '../../lib/api'
import { toast } from '../../components/ui/Toast'

interface EvaluationResult {
  id: string
  model: string
  output: string
  metrics: { relevance?: number; coherence?: number; latency?: number; tokenEfficiency?: number }
  cost: number
}

interface Evaluation {
  id: string
  status: string
  config: any
  startedAt: string
  completedAt?: string
  results: EvaluationResult[]
}

interface PromptVersion { id: string; versionNumber: number; userPromptTemplate: string }
interface Prompt { id: string; name: string; versions: PromptVersion[] }

export default function EvaluationPage() {
  const [prompts, setPrompts] = useState<Prompt[]>([])
  const [selectedPromptId, setSelectedPromptId] = useState('')
  const [selectedVersionId, setSelectedVersionId] = useState('')
  const [inputs, setInputs] = useState([{ userPrompt: '', systemPrompt: '' }])
  const [selectedModels, setSelectedModels] = useState([{ provider: 'groq', model: 'llama-3.3-70b-versatile' }])
  const [metrics] = useState(['relevance', 'coherence', 'latency', 'tokenEfficiency'])
  const [evaluation, setEvaluation] = useState<Evaluation | null>(null)
  const [polling, setPolling] = useState(false)
  const [running, setRunning] = useState(false)
  const [providers, setProviders] = useState<any[]>([])

  useEffect(() => {
    api.get('/api/prompts').then((r) => setPrompts(r.data))
    api.get('/api/execute/providers').then((r) => setProviders(r.data))
  }, [])

  // Fetch all versions when prompt is selected
  useEffect(() => {
    if (!selectedPromptId) return
    setSelectedVersionId('')
    api.get(`/api/prompts/${selectedPromptId}`).then((r) => {
      setPrompts((prev) =>
        prev.map((p) => p.id === selectedPromptId ? { ...p, versions: r.data.versions } : p)
      )
    })
  }, [selectedPromptId])

  const selectedPrompt = prompts.find((p) => p.id === selectedPromptId)

  const handleRun = async () => {
    if (!selectedPromptId) { toast.error('Select a prompt first'); return }
    if (!selectedVersionId) { toast.error('Select a prompt version'); return }
    if (inputs.every((i) => !i.userPrompt.trim())) { toast.error('Add at least one test input'); return }
    if (selectedModels.length === 0) { toast.error('Select at least one model'); return }

    setRunning(true)
    setEvaluation(null)
    try {
      const res = await api.post('/api/evaluations', {
        promptVersionId: selectedVersionId,
        models: selectedModels,
        inputs: inputs.filter((i) => i.userPrompt.trim()),
        metrics,
      })
      const evalId = res.data.evaluationId
      toast.info('Evaluation started — results in ~30 seconds')
      setPolling(true)
      const interval = setInterval(async () => {
        const r = await api.get(`/api/evaluations/${evalId}`)
        setEvaluation(r.data)
        if (r.data.status === 'COMPLETED') {
          clearInterval(interval)
          setPolling(false)
          toast.success('Evaluation complete!')
        } else if (r.data.status === 'FAILED') {
          clearInterval(interval)
          setPolling(false)
          toast.error('Evaluation failed')
        }
      }, 2000)
    } catch {
      toast.error('Failed to start evaluation')
    } finally {
      setRunning(false)
    }
  }

  const toggleModel = (provider: string, model: string) => {
    const key = `${provider}:${model}`
    const exists = selectedModels.find((m) => `${m.provider}:${m.model}` === key)
    if (exists) {
      if (selectedModels.length > 1) setSelectedModels((s) => s.filter((m) => `${m.provider}:${m.model}` !== key))
      else toast.warning('Select at least one model')
    } else {
      setSelectedModels((s) => [...s, { provider, model }])
    }
  }

  const isSelected = (provider: string, model: string) =>
    !!selectedModels.find((m) => m.provider === provider && m.model === model)

  const avgScore = (results: EvaluationResult[], key: keyof EvaluationResult['metrics']) => {
    const vals = results.map((r) => r.metrics[key]).filter((v) => v !== undefined) as number[]
    if (!vals.length) return '-'
    return (vals.reduce((a, b) => a + b, 0) / vals.length).toFixed(1)
  }

  return (
    <div className="max-w-6xl mx-auto">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-white">Evaluation Suite</h2>
        <p className="text-gray-500 text-sm mt-1">Score your prompts with LLM-as-judge metrics</p>
      </div>

      <div className="grid grid-cols-3 gap-6">
        <div className="col-span-1 space-y-4">
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4 space-y-3">
            <p className="text-sm font-medium text-gray-300">Select Prompt <span className="text-red-400">*</span></p>
            <select
              value={selectedPromptId}
              onChange={(e) => setSelectedPromptId(e.target.value)}
              className={`w-full bg-gray-800 border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 ${!selectedPromptId ? 'border-red-500/40' : 'border-gray-700'}`}
            >
              <option value="">Choose a prompt...</option>
              {prompts.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select>

            {selectedPrompt && (
              <>
                <p className="text-sm font-medium text-gray-300">Version <span className="text-red-400">*</span></p>
                <select
                  value={selectedVersionId}
                  onChange={(e) => setSelectedVersionId(e.target.value)}
                  className={`w-full bg-gray-800 border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 ${!selectedVersionId ? 'border-red-500/40' : 'border-gray-700'}`}
                >
                  <option value="">Choose a version...</option>
                  {selectedPrompt.versions.map((v) => (
                    <option key={v.id} value={v.id}>v{v.versionNumber}</option>
                  ))}
                </select>
              </>
            )}
          </div>

          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4">
            <p className="text-sm font-medium text-gray-300 mb-3">Models <span className="text-red-400">*</span></p>
            {providers.map((p) => (
              <div key={p.name} className="mb-3">
                <p className="text-xs text-gray-500 uppercase tracking-wider mb-2">{p.name}</p>
                {p.models.map((model: string) => (
                  <label key={model} className="flex items-center gap-2.5 cursor-pointer mb-1">
                    <input type="checkbox" checked={isSelected(p.name, model)}
                      onChange={() => toggleModel(p.name, model)} className="accent-indigo-500" />
                    <span className={`text-sm ${isSelected(p.name, model) ? 'text-white' : 'text-gray-500'}`}>{model}</span>
                  </label>
                ))}
              </div>
            ))}
          </div>

          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4">
            <p className="text-sm font-medium text-gray-300 mb-3">Metrics</p>
            {metrics.map((m) => (
              <div key={m} className="flex items-center gap-2 mb-2">
                <div className="w-2 h-2 rounded-full bg-indigo-500" />
                <span className="text-sm text-gray-400 capitalize">{m === 'tokenEfficiency' ? 'Token Efficiency' : m}</span>
                {(m === 'relevance' || m === 'coherence') && <span className="text-xs text-purple-400 ml-auto">LLM judge</span>}
              </div>
            ))}
          </div>

          <button
            onClick={handleRun}
            disabled={running || polling}
            className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-medium py-3 rounded-lg text-sm transition-colors"
          >
            {polling ? '⏳ Evaluating...' : running ? 'Starting...' : '▶ Run Evaluation'}
          </button>
        </div>

        <div className="col-span-2 space-y-4">
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm font-medium text-gray-300">Test Inputs <span className="text-red-400">*</span></p>
              <button onClick={() => setInputs((s) => [...s, { userPrompt: '', systemPrompt: '' }])}
                className="text-xs text-indigo-400 hover:text-indigo-300">+ Add Input</button>
            </div>
            <div className="space-y-3">
              {inputs.map((input, i) => (
                <div key={i} className="bg-gray-800 rounded-lg p-3 space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-gray-500">Input {i + 1}</span>
                    {inputs.length > 1 && (
                      <button onClick={() => setInputs((s) => s.filter((_, idx) => idx !== i))}
                        className="text-xs text-red-400 hover:text-red-300">Remove</button>
                    )}
                  </div>
                  <textarea
                    value={input.userPrompt}
                    onChange={(e) => setInputs((s) => s.map((inp, idx) => idx === i ? { ...inp, userPrompt: e.target.value } : inp))}
                    className={`w-full bg-gray-700 border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 resize-none ${!input.userPrompt.trim() ? 'border-red-500/30' : 'border-gray-600'}`}
                    placeholder="Enter test prompt..."
                    rows={2}
                  />
                  {!input.userPrompt.trim() && <p className="text-xs text-red-400">This input is empty</p>}
                </div>
              ))}
            </div>
          </div>

          {evaluation && (
            <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
              <div className="px-5 py-4 border-b border-gray-800 flex items-center justify-between">
                <p className="text-sm font-medium text-gray-300">Results</p>
                <span className={`text-xs px-2 py-0.5 rounded-full ${
                  evaluation.status === 'COMPLETED' ? 'bg-green-500/20 text-green-400' :
                  evaluation.status === 'FAILED' ? 'bg-red-500/20 text-red-400' :
                  'bg-yellow-500/20 text-yellow-400'
                }`}>{evaluation.status.toLowerCase()}</span>
              </div>

              {evaluation.results.length > 0 && (
                <>
                  <div className="p-4">
                    <p className="text-xs text-gray-500 uppercase tracking-wider mb-3">Model Summary</p>
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="text-left">
                          <th className="pb-2 text-xs text-gray-500 font-medium">Model</th>
                          <th className="pb-2 text-xs text-gray-500 font-medium">Relevance</th>
                          <th className="pb-2 text-xs text-gray-500 font-medium">Coherence</th>
                          <th className="pb-2 text-xs text-gray-500 font-medium">Latency</th>
                          <th className="pb-2 text-xs text-gray-500 font-medium">Cost</th>
                        </tr>
                      </thead>
                      <tbody>
                        {Array.from(new Set(evaluation.results.map((r) => r.model))).map((model) => {
                          const modelResults = evaluation.results.filter((r) => r.model === model)
                          const totalCost = modelResults.reduce((a, r) => a + Number(r.cost), 0)
                          return (
                            <tr key={model} className="border-t border-gray-800">
                              <td className="py-2 text-gray-300 font-mono text-xs">{model}</td>
                              <td className="py-2"><ScoreBar value={Number(avgScore(modelResults, 'relevance'))} max={10} /></td>
                              <td className="py-2"><ScoreBar value={Number(avgScore(modelResults, 'coherence'))} max={10} /></td>
                              <td className="py-2 text-gray-400 text-xs">{avgScore(modelResults, 'latency')}ms</td>
                              <td className="py-2 text-green-400 text-xs">${totalCost.toFixed(6)}</td>
                            </tr>
                          )
                        })}
                      </tbody>
                    </table>
                  </div>
                  <div className="border-t border-gray-800 p-4 space-y-3">
                    <p className="text-xs text-gray-500 uppercase tracking-wider">Individual Outputs</p>
                    {evaluation.results.map((r, i) => (
                      <div key={i} className="bg-gray-800 rounded-lg p-4">
                        <div className="flex items-center justify-between mb-2">
                          <span className="text-xs text-indigo-400 font-mono">{r.model}</span>
                          <div className="flex gap-3 text-xs text-gray-500">
                            {r.metrics.relevance !== undefined && <span>Relevance: <span className="text-white">{r.metrics.relevance}/10</span></span>}
                            {r.metrics.coherence !== undefined && <span>Coherence: <span className="text-white">{r.metrics.coherence}/10</span></span>}
                            <span>⏱ {r.metrics.latency}ms</span>
                          </div>
                        </div>
                        <p className="text-gray-300 text-sm leading-relaxed">{r.output}</p>
                      </div>
                    ))}
                  </div>
                </>
              )}

              {polling && evaluation.results.length === 0 && (
                <div className="p-8 text-center text-gray-500 text-sm">
                  Running evaluation... this may take 30-60 seconds
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

function ScoreBar({ value, max }: { value: number; max: number }) {
  if (isNaN(value)) return <span className="text-gray-600 text-xs">-</span>
  const pct = (value / max) * 100
  const color = pct >= 70 ? 'bg-green-500' : pct >= 40 ? 'bg-yellow-500' : 'bg-red-500'
  return (
    <div className="flex items-center gap-2">
      <div className="w-16 h-1.5 bg-gray-700 rounded-full overflow-hidden">
        <div className={`h-full ${color} rounded-full`} style={{ width: `${pct}%` }} />
      </div>
      <span className="text-xs text-gray-400">{value}/{max}</span>
    </div>
  )
}
EOF

# ── EXPERIMENTS PAGE ──────────────────────────────────────────────────────────
cat > pages/experiments/ExperimentsPage.tsx << 'EOF'
import { useEffect, useState } from 'react'
import api from '../../lib/api'
import { toast } from '../../components/ui/Toast'

interface PromptVersion { id: string; versionNumber: number }
interface Prompt { id: string; name: string; versions: PromptVersion[] }

interface ExperimentResult {
  input: string
  versionA: { output: string; latencyMs: number; tokens: number }
  versionB: { output: string; latencyMs: number; tokens: number }
  judge: { winner: string; reason: string; scores: { A: number; B: number } }
}

export default function ExperimentsPage() {
  const [prompts, setPrompts] = useState<Prompt[]>([])
  const [selectedPromptId, setSelectedPromptId] = useState('')
  const [versionAId, setVersionAId] = useState('')
  const [versionBId, setVersionBId] = useState('')
  const [provider, setProvider] = useState('groq')
  const [model, setModel] = useState('llama-3.3-70b-versatile')
  const [inputs, setInputs] = useState([{ userPrompt: '' }])
  const [providers, setProviders] = useState<any[]>([])
  const [running, setRunning] = useState(false)
  const [results, setResults] = useState<ExperimentResult[] | null>(null)
  const [summary, setSummary] = useState<any>(null)

  useEffect(() => {
    api.get('/api/prompts').then((r) => setPrompts(r.data))
    api.get('/api/execute/providers').then((r) => setProviders(r.data))
  }, [])

  useEffect(() => {
    if (!selectedPromptId) return
    setVersionAId('')
    setVersionBId('')
    api.get(`/api/prompts/${selectedPromptId}`).then((r) => {
      setPrompts((prev) =>
        prev.map((p) => p.id === selectedPromptId ? { ...p, versions: r.data.versions } : p)
      )
    })
  }, [selectedPromptId])

  const selectedPrompt = prompts.find((p) => p.id === selectedPromptId)
  const selectedProviderModels = providers.find((p) => p.name === provider)?.models || []

  const handleRun = async () => {
    if (!selectedPromptId) { toast.error('Select a prompt first'); return }
    if (!versionAId) { toast.error('Select Version A'); return }
    if (!versionBId) { toast.error('Select Version B'); return }
    if (versionAId === versionBId) { toast.error('Version A and B must be different'); return }
    if (inputs.every((i) => !i.userPrompt.trim())) { toast.error('Add at least one test input'); return }
    if (!model) { toast.error('Select a judge model'); return }

    setRunning(true)
    setResults(null)
    setSummary(null)
    try {
      const vA = selectedPrompt?.versions.find((v) => v.id === versionAId)
      const vB = selectedPrompt?.versions.find((v) => v.id === versionBId)
      const createRes = await api.post('/api/experiments', {
        name: `A/B: v${vA?.versionNumber} vs v${vB?.versionNumber}`,
        versionAId,
        versionBId,
      })
      const runRes = await api.post(`/api/experiments/${createRes.data.id}/run`, {
        provider,
        model,
        inputs: inputs.filter((i) => i.userPrompt.trim()),
      })
      setResults(runRes.data.results)
      setSummary(runRes.data.summary)
      toast.success(`A/B Test complete — Version ${runRes.data.summary.winner} wins!`)
    } catch {
      toast.error('A/B test failed — check server logs')
    } finally {
      setRunning(false)
    }
  }

  return (
    <div className="max-w-6xl mx-auto">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-white">A/B Testing</h2>
        <p className="text-gray-500 text-sm mt-1">Compare two prompt versions with LLM-as-judge scoring</p>
      </div>

      <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 mb-6 space-y-4">
        <div className="grid grid-cols-4 gap-4">
          <div>
            <label className="block text-xs text-gray-500 mb-1.5">Prompt <span className="text-red-400">*</span></label>
            <select value={selectedPromptId} onChange={(e) => setSelectedPromptId(e.target.value)}
              className={`w-full bg-gray-800 border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 ${!selectedPromptId ? 'border-red-500/40' : 'border-gray-700'}`}>
              <option value="">Select prompt...</option>
              {prompts.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select>
          </div>

          <div>
            <label className="block text-xs text-gray-500 mb-1.5">Version A <span className="text-red-400">*</span></label>
            <select value={versionAId} onChange={(e) => setVersionAId(e.target.value)} disabled={!selectedPrompt}
              className={`w-full bg-gray-800 border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 disabled:opacity-40 ${!versionAId && selectedPrompt ? 'border-red-500/40' : 'border-gray-700'}`}>
              <option value="">Select...</option>
              {selectedPrompt?.versions.map((v) => <option key={v.id} value={v.id}>v{v.versionNumber}</option>)}
            </select>
          </div>

          <div>
            <label className="block text-xs text-gray-500 mb-1.5">Version B <span className="text-red-400">*</span></label>
            <select value={versionBId} onChange={(e) => setVersionBId(e.target.value)} disabled={!selectedPrompt}
              className={`w-full bg-gray-800 border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 disabled:opacity-40 ${!versionBId && selectedPrompt ? 'border-red-500/40' : 'border-gray-700'}`}>
              <option value="">Select...</option>
              {selectedPrompt?.versions.filter((v) => v.id !== versionAId).map((v) => (
                <option key={v.id} value={v.id}>v{v.versionNumber}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-xs text-gray-500 mb-1.5">Judge Model <span className="text-red-400">*</span></label>
            <select value={provider} onChange={(e) => { setProvider(e.target.value); setModel(providers.find((p) => p.name === e.target.value)?.models[0] || '') }}
              className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 mb-2">
              {providers.map((p) => <option key={p.name} value={p.name}>{p.name}</option>)}
            </select>
            <select value={model} onChange={(e) => setModel(e.target.value)}
              className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500">
              {selectedProviderModels.map((m: string) => <option key={m} value={m}>{m}</option>)}
            </select>
          </div>
        </div>

        <div>
          <div className="flex items-center justify-between mb-2">
            <label className="text-xs text-gray-500">Test Inputs <span className="text-red-400">*</span></label>
            <button onClick={() => setInputs((s) => [...s, { userPrompt: '' }])}
              className="text-xs text-indigo-400 hover:text-indigo-300">+ Add</button>
          </div>
          <div className="space-y-2">
            {inputs.map((input, i) => (
              <div key={i} className="flex gap-2 items-start">
                <textarea value={input.userPrompt}
                  onChange={(e) => setInputs((s) => s.map((inp, idx) => idx === i ? { userPrompt: e.target.value } : inp))}
                  className={`flex-1 bg-gray-800 border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 resize-none ${!input.userPrompt.trim() ? 'border-red-500/30' : 'border-gray-700'}`}
                  placeholder="Test prompt..." rows={2} />
                {inputs.length > 1 && (
                  <button onClick={() => setInputs((s) => s.filter((_, idx) => idx !== i))}
                    className="text-red-400 hover:text-red-300 text-xs mt-2">✕</button>
                )}
              </div>
            ))}
          </div>
        </div>

        <button onClick={handleRun} disabled={running}
          className="bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-sm font-medium px-6 py-2.5 rounded-lg transition-colors">
          {running ? '⏳ Running A/B Test...' : '▶ Run A/B Test'}
        </button>
      </div>

      {summary && (
        <div className={`mb-4 p-4 rounded-xl border ${summary.winner === 'A' ? 'bg-blue-500/10 border-blue-500/30' : 'bg-green-500/10 border-green-500/30'}`}>
          <p className="text-white font-semibold text-lg">
            🏆 Version {summary.winner} wins — {summary.winner === 'A' ? summary.aWins : summary.bWins}/{results?.length} rounds
          </p>
          <p className="text-gray-400 text-sm mt-1">Version A: {summary.aWins} wins · Version B: {summary.bWins} wins</p>
        </div>
      )}

      {results && results.map((r, i) => (
        <div key={i} className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden mb-4">
          <div className="px-5 py-3 border-b border-gray-800">
            <p className="text-xs text-gray-500">Input: <span className="text-gray-300">{r.input}</span></p>
          </div>
          <div className="grid grid-cols-2 divide-x divide-gray-800">
            {(['A', 'B'] as const).map((v) => {
              const data = v === 'A' ? r.versionA : r.versionB
              const isWinner = r.judge.winner === v
              return (
                <div key={v} className={`p-4 ${isWinner ? 'bg-green-500/5' : ''}`}>
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium text-white">Version {v}</span>
                      {isWinner && <span className="text-xs bg-green-500/20 text-green-400 px-2 py-0.5 rounded-full">Winner</span>}
                    </div>
                    <div className="flex gap-2 text-xs text-gray-500">
                      <span>⏱ {data.latencyMs}ms</span>
                      <span className={`font-medium ${isWinner ? 'text-green-400' : 'text-gray-400'}`}>Score: {r.judge.scores[v]}/10</span>
                    </div>
                  </div>
                  <p className="text-gray-300 text-sm leading-relaxed">{data.output}</p>
                </div>
              )
            })}
          </div>
          <div className="px-5 py-3 border-t border-gray-800 bg-gray-800/30">
            <p className="text-xs text-gray-500">Judge: <span className="text-gray-300">{r.judge.reason}</span></p>
          </div>
        </div>
      ))}
    </div>
  )
}
EOF

# ── EXPORT PAGE ───────────────────────────────────────────────────────────────
cat > pages/export/ExportPage.tsx << 'EOF'
import { useEffect, useState } from 'react'
import api from '../../lib/api'
import { toast } from '../../components/ui/Toast'

interface PromptVersion { id: string; versionNumber: number }
interface Prompt { id: string; name: string; versions: PromptVersion[] }

export default function ExportPage() {
  const [prompts, setPrompts] = useState<Prompt[]>([])
  const [selectedPromptId, setSelectedPromptId] = useState('')
  const [selectedVersionId, setSelectedVersionId] = useState('')
  const [format, setFormat] = useState<'json' | 'python'>('json')
  const [result, setResult] = useState<any>(null)
  const [loading, setLoading] = useState(false)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    api.get('/api/prompts').then((r) => setPrompts(r.data))
  }, [])

  // Fetch all versions when prompt changes
  useEffect(() => {
    if (!selectedPromptId) return
    setSelectedVersionId('')
    setResult(null)
    api.get(`/api/prompts/${selectedPromptId}`).then((r) => {
      setPrompts((prev) =>
        prev.map((p) => p.id === selectedPromptId ? { ...p, versions: r.data.versions } : p)
      )
    })
  }, [selectedPromptId])

  const selectedPrompt = prompts.find((p) => p.id === selectedPromptId)

  const handleExport = async () => {
    if (!selectedPromptId) { toast.error('Select a prompt first'); return }
    if (!selectedVersionId) { toast.error('Select a version to export'); return }
    setLoading(true)
    try {
      const res = await api.get(`/api/export/${selectedVersionId}/${format}`)
      setResult(res.data)
      toast.success('Export generated successfully')
    } catch {
      toast.error('Export failed')
    } finally {
      setLoading(false)
    }
  }

  const handleCopy = () => {
    const text = format === 'python' ? result.code : JSON.stringify(result, null, 2)
    navigator.clipboard.writeText(text)
    setCopied(true)
    toast.success('Copied to clipboard!')
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-white">Export</h2>
        <p className="text-gray-500 text-sm mt-1">Export your prompts as production-ready code</p>
      </div>

      <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 space-y-4 mb-6">
        <div className="grid grid-cols-3 gap-4">
          <div>
            <label className="block text-xs text-gray-500 mb-1.5">Prompt <span className="text-red-400">*</span></label>
            <select value={selectedPromptId} onChange={(e) => setSelectedPromptId(e.target.value)}
              className={`w-full bg-gray-800 border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 ${!selectedPromptId ? 'border-red-500/40' : 'border-gray-700'}`}>
              <option value="">Select prompt...</option>
              {prompts.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select>
          </div>

          <div>
            <label className="block text-xs text-gray-500 mb-1.5">Version <span className="text-red-400">*</span></label>
            <select value={selectedVersionId} onChange={(e) => { setSelectedVersionId(e.target.value); setResult(null) }}
              disabled={!selectedPrompt}
              className={`w-full bg-gray-800 border rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 disabled:opacity-40 ${!selectedVersionId && selectedPrompt ? 'border-red-500/40' : 'border-gray-700'}`}>
              <option value="">Select version...</option>
              {selectedPrompt?.versions.map((v) => <option key={v.id} value={v.id}>v{v.versionNumber}</option>)}
            </select>
          </div>

          <div>
            <label className="block text-xs text-gray-500 mb-1.5">Format <span className="text-red-400">*</span></label>
            <div className="flex gap-2">
              {(['json', 'python'] as const).map((f) => (
                <button key={f} onClick={() => { setFormat(f); setResult(null) }}
                  className={`flex-1 py-2 rounded-lg text-sm font-medium transition-colors ${format === f ? 'bg-indigo-600 text-white' : 'bg-gray-800 text-gray-400 hover:text-white'}`}>
                  {f === 'json' ? 'JSON' : 'Python'}
                </button>
              ))}
            </div>
          </div>
        </div>

        <button onClick={handleExport} disabled={loading || !selectedVersionId}
          className="bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-sm font-medium px-6 py-2.5 rounded-lg transition-colors">
          {loading ? 'Generating...' : 'Generate Export'}
        </button>
      </div>

      {result && (
        <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
          <div className="px-5 py-3 border-b border-gray-800 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="text-sm font-medium text-gray-300">
                {selectedPrompt?.name} — v{selectedPrompt?.versions.find((v) => v.id === selectedVersionId)?.versionNumber}
              </span>
              <span className="text-xs bg-gray-800 text-gray-400 px-2 py-0.5 rounded">{format.toUpperCase()}</span>
            </div>
            <button onClick={handleCopy} className="text-xs text-indigo-400 hover:text-indigo-300 transition-colors">
              {copied ? '✓ Copied!' : 'Copy'}
            </button>
          </div>
          <pre className="p-5 text-sm text-gray-300 overflow-x-auto leading-relaxed">
            <code>{format === 'python' ? result.code : JSON.stringify(result, null, 2)}</code>
          </pre>
        </div>
      )}
    </div>
  )
}
EOF

echo ""
echo "✅ Validation fixes applied to all pages"
echo "Dev server will hot-reload automatically"