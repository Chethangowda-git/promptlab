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

    const metaPrompt = `You are a prompt engineering expert. Improve the following prompt.

IMPORTANT: Respond ONLY with a valid JSON object. No markdown, no backticks, no explanation outside the JSON.

Return exactly this structure:
{
  "improvedPrompt": "the full improved prompt text here",
  "improvedSystemPrompt": "improved system prompt or empty string",
  "changes": [
    { "type": "clarity", "description": "what changed and why" }
  ]
}

Types must be one of: clarity, specificity, efficiency, format

Original System Prompt: ${systemPrompt || '(none)'}
Original User Prompt: ${prompt}`

    const result = await p.execute('llama-3.1-8b-instant', {
      userPrompt: metaPrompt,
      temperature: 0.3,
      maxTokens: 1024,
    })

    // Strip any markdown fences if present
    let clean = result.output.trim()
    clean = clean.replace(/^```json\s*/i, '').replace(/^```\s*/i, '').replace(/```\s*$/i, '').trim()

    // Extract JSON object if there's surrounding text
    const jsonMatch = clean.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      res.status(500).json({ error: 'Could not parse AI response', raw: clean })
      return
    }

    const parsed = JSON.parse(jsonMatch[0])
    res.json({ ...parsed, latencyMs: result.latencyMs })
  } catch (err: any) {
    console.error('Improve error:', err)
    res.status(500).json({ error: err.message })
  }
}

export async function listProviders(_req: AuthRequest, res: Response): Promise<void> {
  res.json(getAllProviders())
}
