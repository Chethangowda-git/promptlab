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
