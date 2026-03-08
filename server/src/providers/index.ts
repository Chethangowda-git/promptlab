import { BaseProvider } from './base.provider'
import { GroqProvider } from './groq.provider'
import { GeminiProvider } from './gemini.provider'

const providers: Record<string, BaseProvider> = {
  groq: new GroqProvider(),
  gemini: new GeminiProvider(),
}

export function getProvider(name: string): BaseProvider {
  const provider = providers[name]
  if (!provider) throw new Error(`Provider "${name}" not found`)
  return provider
}

export function getAllProviders() {
  return Object.values(providers).map((p) => ({
    name: p.name,
    models: p.models,
  }))
}

export { BaseProvider }
