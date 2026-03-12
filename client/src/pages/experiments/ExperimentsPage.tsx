import { useEffect, useState } from 'react'
import api from '../../lib/api'

interface PromptVersion {
  id: string
  versionNumber: number
}

interface Prompt {
  id: string
  name: string
  versions: PromptVersion[]
}

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
  // Add this after the existing useEffect
useEffect(() => {
  if (!selectedPromptId) return
  api.get(`/api/prompts/${selectedPromptId}`).then((r) => {
    setPrompts((prev) =>
      prev.map((p) => (p.id === selectedPromptId ? { ...p, versions: r.data.versions } : p))
    )
  })
}, [selectedPromptId])

  const selectedPrompt = prompts.find((p) => p.id === selectedPromptId)

  const handleRun = async () => {
    if (!versionAId || !versionBId || inputs.every((i) => !i.userPrompt.trim())) return
    setRunning(true)
    setResults(null)
    setSummary(null)
    try {
      // Create experiment
      const createRes = await api.post('/api/experiments', {
        projectId: 'temp',
        name: `A/B: v${selectedPrompt?.versions.find(v => v.id === versionAId)?.versionNumber} vs v${selectedPrompt?.versions.find(v => v.id === versionBId)?.versionNumber}`,
        versionAId,
        versionBId,
      })

      // Run experiment
      const runRes = await api.post(`/api/experiments/${createRes.data.id}/run`, {
        provider,
        model,
        inputs: inputs.filter((i) => i.userPrompt.trim()),
      })

      setResults(runRes.data.results)
      setSummary(runRes.data.summary)
    } finally {
      setRunning(false)
    }
  }

  const selectedProviderModels = providers.find((p) => p.name === provider)?.models || []

  return (
    <div className="max-w-6xl mx-auto">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-white">A/B Testing</h2>
        <p className="text-gray-500 text-sm mt-1">Compare two prompt versions with LLM-as-judge scoring</p>
      </div>

      {/* Config */}
      <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 mb-6 space-y-4">
        <div className="grid grid-cols-4 gap-4">
          <div>
            <label className="block text-xs text-gray-500 mb-1.5">Prompt</label>
            <select
              value={selectedPromptId}
              onChange={(e) => { setSelectedPromptId(e.target.value); setVersionAId(''); setVersionBId('') }}
              className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500"
            >
              <option value="">Select prompt...</option>
              {prompts.map((p) => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-xs text-gray-500 mb-1.5">Version A</label>
            <select
              value={versionAId}
              onChange={(e) => setVersionAId(e.target.value)}
              disabled={!selectedPrompt}
              className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 disabled:opacity-40"
            >
              <option value="">Select...</option>
              {selectedPrompt?.versions.map((v) => (
                <option key={v.id} value={v.id}>v{v.versionNumber}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-xs text-gray-500 mb-1.5">Version B</label>
            <select
              value={versionBId}
              onChange={(e) => setVersionBId(e.target.value)}
              disabled={!selectedPrompt}
              className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 disabled:opacity-40"
            >
              <option value="">Select...</option>
              {selectedPrompt?.versions.filter((v) => v.id !== versionAId).map((v) => (
                <option key={v.id} value={v.id}>v{v.versionNumber}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-xs text-gray-500 mb-1.5">Judge Model</label>
            <select
              value={provider}
              onChange={(e) => { setProvider(e.target.value); setModel(providers.find(p => p.name === e.target.value)?.models[0] || '') }}
              className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500"
            >
              {providers.map((p) => (
                <option key={p.name} value={p.name}>{p.name}</option>
              ))}
            </select>
            <select
              value={model}
              onChange={(e) => setModel(e.target.value)}
              className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 mt-2"
            >
              {selectedProviderModels.map((m: string) => (
                <option key={m} value={m}>{m}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Test inputs */}
        <div>
          <div className="flex items-center justify-between mb-2">
            <label className="text-xs text-gray-500">Test Inputs</label>
            <button
              onClick={() => setInputs((s) => [...s, { userPrompt: '' }])}
              className="text-xs text-indigo-400 hover:text-indigo-300"
            >
              + Add
            </button>
          </div>
          <div className="space-y-2">
            {inputs.map((input, i) => (
              <div key={i} className="flex gap-2">
                <textarea
                  value={input.userPrompt}
                  onChange={(e) => setInputs((s) => s.map((inp, idx) => idx === i ? { userPrompt: e.target.value } : inp))}
                  className="flex-1 bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none focus:border-indigo-500 resize-none"
                  placeholder="Test prompt..."
                  rows={2}
                />
                {inputs.length > 1 && (
                  <button onClick={() => setInputs((s) => s.filter((_, idx) => idx !== i))} className="text-red-400 hover:text-red-300 text-xs">✕</button>
                )}
              </div>
            ))}
          </div>
        </div>

        <button
          onClick={handleRun}
          disabled={running || !versionAId || !versionBId}
          className="bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-sm font-medium px-6 py-2.5 rounded-lg transition-colors"
        >
          {running ? '⏳ Running A/B Test...' : '▶ Run A/B Test'}
        </button>
      </div>

      {/* Results */}
      {summary && (
        <div className={`mb-4 p-4 rounded-xl border ${
          summary.winner === 'A' ? 'bg-blue-500/10 border-blue-500/30' : 'bg-green-500/10 border-green-500/30'
        }`}>
          <p className="text-white font-semibold text-lg">
            🏆 Version {summary.winner} wins — {summary.winner === 'A' ? summary.aWins : summary.bWins}/{results?.length} rounds
          </p>
          <p className="text-gray-400 text-sm mt-1">
            Version A: {summary.aWins} wins · Version B: {summary.bWins} wins
          </p>
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
                      <span className={`font-medium ${isWinner ? 'text-green-400' : 'text-gray-400'}`}>
                        Score: {r.judge.scores[v]}/10
                      </span>
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
