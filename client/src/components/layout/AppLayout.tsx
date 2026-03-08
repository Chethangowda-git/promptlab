import { useEffect } from 'react'
import { Outlet, useNavigate } from 'react-router-dom'
import { useAuthStore } from '../../store/auth.store'
import Sidebar from './Sidebar'

export default function AppLayout() {
  const { token, user, fetchMe } = useAuthStore()
  const navigate = useNavigate()

  useEffect(() => {
    if (!token) {
      navigate('/login')
      return
    }
    if (!user) fetchMe()
  }, [token])

  if (!token) return null

  return (
    <div className="flex min-h-screen bg-gray-950 text-white">
      <Sidebar />
      <main className="ml-56 flex-1 p-8">
        <Outlet />
      </main>
    </div>
  )
}
