import { create } from 'zustand'
import api from '../lib/api'

interface PromptVersion {
  id: string
  versionNumber: number
  systemPrompt: string | null
  userPromptTemplate: string
  variables: any[]
  modelConfig: any
  tag: string | null
  createdAt: string
}

interface Prompt {
  id: string
  name: string
  description: string | null
  status: string
  currentVersionId: string | null
  versions: PromptVersion[]
  createdAt: string
  updatedAt: string
}

interface ExecuteResult {
  output: string
  model: string
  provider: string
  latencyMs: number
  inputTokens: number
  outputTokens: number
  cost: number
  error?: string
}

interface ImproveResult {
  improvedPrompt: string
  improvedSystemPrompt: string
  changes: { type: string; description: string }[]
  latencyMs: number
}

interface PromptState {
  prompts: Prompt[]
  activePrompt: Prompt | null
  executeResults: ExecuteResult[]
  improveResult: ImproveResult | null
  executing: boolean
  improving: boolean
  fetchPrompts: (projectId?: string) => Promise<void>
  fetchPrompt: (id: string) => Promise<void>
  createPrompt: (data: { projectId: string; name: string; description?: string }) => Promise<Prompt>
  createVersion: (promptId: string, data: any) => Promise<void>
  executePrompt: (data: any) => Promise<void>
  executeBatch: (data: any) => Promise<void>
  improvePrompt: (prompt: string, systemPrompt?: string) => Promise<void>
  clearResults: () => void
}

export const usePromptStore = create<PromptState>((set) => ({
  prompts: [],
  activePrompt: null,
  executeResults: [],
  improveResult: null,
  executing: false,
  improving: false,

  fetchPrompts: async (projectId) => {
    const res = await api.get('/api/prompts', { params: projectId ? { projectId } : {} })
    set({ prompts: res.data })
  },

  fetchPrompt: async (id) => {
    const res = await api.get(`/api/prompts/${id}`)
    set({ activePrompt: res.data })
  },

  createPrompt: async (data) => {
    const res = await api.post('/api/prompts', data)
    set((s) => ({ prompts: [res.data, ...s.prompts] }))
    return res.data
  },

  createVersion: async (promptId, data) => {
    await api.post(`/api/prompts/${promptId}/versions`, data)
    const res = await api.get(`/api/prompts/${promptId}`)
    set({ activePrompt: res.data })
  },

  executePrompt: async (data) => {
    set({ executing: true, executeResults: [] })
    try {
      const res = await api.post('/api/execute', data)
      set({ executeResults: [res.data] })
    } finally {
      set({ executing: false })
    }
  },

  executeBatch: async (data) => {
    set({ executing: true, executeResults: [] })
    try {
      const res = await api.post('/api/execute/batch', data)
      set({ executeResults: res.data })
    } finally {
      set({ executing: false })
    }
  },

  improvePrompt: async (prompt, systemPrompt) => {
    set({ improving: true, improveResult: null })
    try {
      const res = await api.post('/api/execute/improve', { prompt, systemPrompt })
      set({ improveResult: res.data })
    } finally {
      set({ improving: false })
    }
  },

  clearResults: () => set({ executeResults: [], improveResult: null }),
}))
