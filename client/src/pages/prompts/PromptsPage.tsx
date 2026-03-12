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
