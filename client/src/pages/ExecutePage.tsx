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
