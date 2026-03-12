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
  // Fix: improved system prompt goes to system, improved prompt goes to user
  if (improveResult.improvedSystemPrompt) setSystemPrompt(improveResult.improvedSystemPrompt)
  setUserPrompt(improveResult.improvedPrompt)
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
