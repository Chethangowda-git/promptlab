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
