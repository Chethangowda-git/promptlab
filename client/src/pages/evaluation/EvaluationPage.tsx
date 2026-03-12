import { useEffect, useState } from 'react'
import api from '../../lib/api'

interface EvaluationResult {
  id: string
  model: string
  output: string
  metrics: {
    relevance?: number
    coherence?: number
    latency?: number
    tokenEfficiency?: number
  }
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

interface PromptVersion {
  id: string
  versionNumber: number
  userPromptTemplate: string
}

interface Prompt {
  id: string
  name: string
  versions: PromptVersion[]
}

export default function EvaluationPage() {
  const [prompts, setPrompts] = useState<Prompt[]>([])
  const [selectedVersionId, setSelectedVersionId] = useState('')
  const [selectedPromptId, setSelectedPromptId] = useState('')
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

  const selectedPrompt = prompts.find((p) => p.id === selectedPromptId)

  const handleRun = async () => {
    if (!selectedVersionId || inputs.every((i) => !i.userPrompt.trim())) return
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
      setPolling(true)
      // Poll for results
      const interval = setInterval(async () => {
        const r = await api.get(`/api/evaluations/${evalId}`)
        setEvaluation(r.data)
        if (r.data.status === 'COMPLETED' || r.data.status === 'FAILED') {
          clearInterval(interval)
          setPolling(false)
        }
      }, 2000)
    } finally {
      setRunning(false)
    }
  }

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
        {/* Config Panel */}
        <div className="col-span-1 space-y-4">
          {/* Prompt + Version selector */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4 space-y-3">
            <p className="text-sm font-medium text-gray-300">Select Prompt</p>
            <select
              value={selectedPromptId}
              onChange={(e) => { setSelectedPromptId(e.target.value); setSelectedVersionId('') }}
              className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500"
            >
              <option value="">Choose a prompt...</option>
              {prompts.map((p) => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </select>
            {selectedPrompt && (
              <select
                value={selectedVersionId}
                onChange={(e) => setSelectedVersionId(e.target.value)}
                className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500"
              >
                <option value="">Choose a version...</option>
                {selectedPrompt.versions.map((v) => (
                  <option key={v.id} value={v.id}>v{v.versionNumber}</option>
                ))}
              </select>
            )}
          </div>

          {/* Model selector */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4">
            <p className="text-sm font-medium text-gray-300 mb-3">Models</p>
            {providers.map((p) => (
              <div key={p.name} className="mb-3">
                <p className="text-xs text-gray-500 uppercase tracking-wider mb-2">{p.name}</p>
                {p.models.map((model: string) => (
                  <label key={model} className="flex items-center gap-2.5 cursor-pointer mb-1">
                    <input
                      type="checkbox"
                      checked={isSelected(p.name, model)}
                      onChange={() => toggleModel(p.name, model)}
                      className="accent-indigo-500"
                    />
                    <span className={`text-sm ${isSelected(p.name, model) ? 'text-white' : 'text-gray-500'}`}>
                      {model}
                    </span>
                  </label>
                ))}
              </div>
            ))}
          </div>

          {/* Metrics */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4">
            <p className="text-sm font-medium text-gray-300 mb-3">Metrics</p>
            {metrics.map((m) => (
              <div key={m} className="flex items-center gap-2 mb-2">
                <div className="w-2 h-2 rounded-full bg-indigo-500" />
                <span className="text-sm text-gray-400 capitalize">{m === 'tokenEfficiency' ? 'Token Efficiency' : m}</span>
                {(m === 'relevance' || m === 'coherence') && (
                  <span className="text-xs text-purple-400 ml-auto">LLM judge</span>
                )}
              </div>
            ))}
          </div>

          <button
            onClick={handleRun}
            disabled={running || polling || !selectedVersionId}
            className="w-full bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-medium py-3 rounded-lg text-sm transition-colors"
          >
            {polling ? '⏳ Evaluating...' : running ? 'Starting...' : '▶ Run Evaluation'}
          </button>
        </div>

        {/* Right: Inputs + Results */}
        <div className="col-span-2 space-y-4">
          {/* Test Inputs */}
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-4">
            <div className="flex items-center justify-between mb-3">
              <p className="text-sm font-medium text-gray-300">Test Inputs</p>
              <button
                onClick={() => setInputs((s) => [...s, { userPrompt: '', systemPrompt: '' }])}
                className="text-xs text-indigo-400 hover:text-indigo-300 transition-colors"
              >
                + Add Input
              </button>
            </div>
            <div className="space-y-3">
              {inputs.map((input, i) => (
                <div key={i} className="bg-gray-800 rounded-lg p-3 space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-gray-500">Input {i + 1}</span>
                    {inputs.length > 1 && (
                      <button
                        onClick={() => setInputs((s) => s.filter((_, idx) => idx !== i))}
                        className="text-xs text-red-400 hover:text-red-300"
                      >
                        Remove
                      </button>
                    )}
                  </div>
                  <textarea
                    value={input.userPrompt}
                    onChange={(e) => setInputs((s) => s.map((inp, idx) => idx === i ? { ...inp, userPrompt: e.target.value } : inp))}
                    className="w-full bg-gray-700 border border-gray-600 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 resize-none"
                    placeholder="User prompt to evaluate..."
                    rows={2}
                  />
                </div>
              ))}
            </div>
          </div>

          {/* Results */}
          {evaluation && (
            <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
              <div className="px-5 py-4 border-b border-gray-800 flex items-center justify-between">
                <p className="text-sm font-medium text-gray-300">Results</p>
                <span className={`text-xs px-2 py-0.5 rounded-full ${
                  evaluation.status === 'COMPLETED' ? 'bg-green-500/20 text-green-400' :
                  evaluation.status === 'FAILED' ? 'bg-red-500/20 text-red-400' :
                  'bg-yellow-500/20 text-yellow-400'
                }`}>
                  {evaluation.status.toLowerCase()}
                </span>
              </div>

              {evaluation.results.length > 0 && (
                <>
                  {/* Summary Table */}
                  <div className="p-4">
                    <p className="text-xs text-gray-500 uppercase tracking-wider mb-3">Model Summary</p>
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="text-left">
                          <th className="pb-2 text-xs text-gray-500 font-medium">Model</th>
                          <th className="pb-2 text-xs text-gray-500 font-medium">Relevance</th>
                          <th className="pb-2 text-xs text-gray-500 font-medium">Coherence</th>
                          <th className="pb-2 text-xs text-gray-500 font-medium">Latency</th>
                          <th className="pb-2 text-xs text-gray-500 font-medium">Tokens/s</th>
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
                              <td className="py-2">
                                <ScoreBar value={Number(avgScore(modelResults, 'relevance'))} max={10} />
                              </td>
                              <td className="py-2">
                                <ScoreBar value={Number(avgScore(modelResults, 'coherence'))} max={10} />
                              </td>
                              <td className="py-2 text-gray-400 text-xs">{avgScore(modelResults, 'latency')}ms</td>
                              <td className="py-2 text-gray-400 text-xs">{avgScore(modelResults, 'tokenEfficiency')}</td>
                              <td className="py-2 text-green-400 text-xs">${totalCost.toFixed(6)}</td>
                            </tr>
                          )
                        })}
                      </tbody>
                    </table>
                  </div>

                  {/* Individual Results */}
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
