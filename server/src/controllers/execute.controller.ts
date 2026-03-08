import { Response } from 'express'
import { AuthRequest } from '../middleware/auth.middleware'
import { getProvider, getAllProviders } from '../providers'

export async function executePrompt(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { provider, model, systemPrompt, userPrompt, temperature, maxTokens } = req.body
    const p = getProvider(provider)
    const result = await p.execute(model, { systemPrompt, userPrompt, temperature, maxTokens })
    res.json(result)
  } catch (err: any) {
    res.status(500).json({ error: err.message })
  }
}

export async function executeBatch(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { models, systemPrompt, userPrompt, temperature, maxTokens } = req.body
    const results = await Promise.allSettled(
      models.map(({ provider, model }: { provider: string; model: string }) =>
        getProvider(provider).execute(model, { systemPrompt, userPrompt, temperature, maxTokens })
      )
    )
    res.json(
      results.map((r, i) =>
        r.status === 'fulfilled'
          ? { ...r.value }
          : { error: r.reason?.message, model: models[i].model, provider: models[i].provider }
      )
    )
  } catch (err: any) {
    res.status(500).json({ error: err.message })
  }
}

export async function improvePrompt(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { prompt, systemPrompt } = req.body
    const p = getProvider('groq')
    const metaPrompt = `You are a prompt engineering expert. Improve the following prompt for clarity, specificity, and token efficiency.

Return ONLY a JSON object (no markdown, no explanation outside the JSON) in this exact format:
{
  "improvedPrompt": "the improved version",
  "improvedSystemPrompt": "improved system prompt or empty string",
  "changes": [
    { "type": "clarity|specificity|efficiency|format", "description": "what changed and why" }
  ]
}

Original System Prompt: ${systemPrompt || '(none)'}
Original User Prompt: ${prompt}`

    const result = await p.execute('llama3-70b-8192', {
      userPrompt: metaPrompt,
      temperature: 0.3,
      maxTokens: 1024,
    })

    const clean = result.output.replace(/```json|```/g, '').trim()
    const parsed = JSON.parse(clean)
    res.json({ ...parsed, latencyMs: result.latencyMs })
  } catch (err: any) {
    res.status(500).json({ error: err.message })
  }
}

export async function listProviders(_req: AuthRequest, res: Response): Promise<void> {
  res.json(getAllProviders())
}
