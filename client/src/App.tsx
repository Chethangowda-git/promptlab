import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import AppLayout from './components/layout/AppLayout'
import Login from './pages/auth/Login'
import Register from './pages/auth/Register'
import Dashboard from './pages/Dashboard'
import PromptsPage from './pages/prompts/PromptsPage'
import PromptEditor from './pages/prompts/PromptEditor'
import ExecutePage from './pages/ExecutePage'
import EvaluationPage from './pages/evaluation/EvaluationPage'
import ExportPage from './pages/export/ExportPage'
import ExperimentsPage from './pages/experiments/ExperimentsPage'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route element={<AppLayout />}>
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/prompts" element={<PromptsPage />} />
          <Route path="/prompts/:id" element={<PromptEditor />} />
          <Route path="/execute" element={<ExecutePage />} />
          <Route path="/evaluate" element={<EvaluationPage />} />
          <Route path="/export" element={<ExportPage />} />
          <Route path="/experiments" element={<ExperimentsPage />} />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
