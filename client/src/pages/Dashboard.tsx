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
