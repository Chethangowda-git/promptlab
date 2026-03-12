import { Response } from 'express'
import { AuthRequest } from '../middleware/auth.middleware'
import prisma from '../lib/prisma'
import { getProvider } from '../providers'

async function scoreWithLLM(
  metric: 'relevance' | 'coherence',
  prompt: string,
  output: string
): Promise<number> {
  const p = getProvider('groq')
  const rubric = metric === 'relevance'
    ? `Does the output directly address and answer the prompt? Score 1-10 where 10 is perfectly relevant.`
    : `Is the output logically consistent, well-structured, and coherent? Score 1-10 where 10 is perfectly coherent.`

  const result = await p.execute('llama-3.1-8b-instant', {
    userPrompt: `You are an evaluator. ${rubric}

Prompt: ${prompt}
Output: ${output}

Respond ONLY with a JSON object like: {"score": 8, "reason": "brief reason"}`,
    temperature: 0.1,
    maxTokens: 128,
  })

  try {
    let clean = result.output.trim().replace(/```json|```/g, '').trim()
    const match = clean.match(/\{[\s\S]*\}/)
    if (!match) return 5
    const parsed = JSON.parse(match[0])
    return Math.min(10, Math.max(1, Number(parsed.score) || 5))
  } catch {
    return 5
  }
}

export async function runEvaluation(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { promptVersionId, models, inputs, metrics } = req.body
    // inputs: [{ userPrompt, systemPrompt }]
    // models: [{ provider, model }]
    // metrics: ['relevance', 'coherence', 'latency', 'tokenEfficiency']

    const version = await prisma.promptVersion.findUnique({
      where: { id: promptVersionId },
    })
    if (!version) {
      res.status(404).json({ error: 'Prompt version not found' })
      return
    }

    const evaluation = await prisma.evaluation.create({
      data: {
        promptVersionId,
        status: 'RUNNING',
        config: { models, metrics },
        createdById: req.userId!,
      },
    })

    // Run evaluation asynchronously
    runEvaluationAsync(evaluation.id, version, models, inputs, metrics)
      .catch(console.error)

    res.status(201).json({ evaluationId: evaluation.id, status: 'RUNNING' })
  } catch (err: any) {
    console.error(err)
    res.status(500).json({ error: err.message })
  }
}

async function runEvaluationAsync(
  evaluationId: string,
  version: any,
  models: { provider: string; model: string }[],
  inputs: { userPrompt: string; systemPrompt?: string }[],
  metrics: string[]
) {
  try {
    for (const modelTarget of models) {
      for (const input of inputs) {
        const provider = getProvider(modelTarget.provider)
        const start = Date.now()
        const result = await provider.execute(modelTarget.model, {
          systemPrompt: input.systemPrompt || version.systemPrompt || undefined,
          userPrompt: input.userPrompt,
          temperature: 0.7,
          maxTokens: 1024,
        })
        const latencyMs = Date.now() - start

        const metricScores: Record<string, number> = {
          latency: latencyMs,
          tokenEfficiency: result.outputTokens > 0
            ? Math.round((result.outputTokens / (latencyMs / 1000)) * 10) / 10
            : 0,
        }

        if (metrics.includes('relevance')) {
          metricScores.relevance = await scoreWithLLM('relevance', input.userPrompt, result.output)
        }
        if (metrics.includes('coherence')) {
          metricScores.coherence = await scoreWithLLM('coherence', input.userPrompt, result.output)
        }

        await prisma.evaluationResult.create({
          data: {
            evaluationId,
            model: modelTarget.model,
            inputVariables: input,
            output: result.output,
            metrics: metricScores,
            cost: result.cost,
          },
        })
      }
    }

    await prisma.evaluation.update({
      where: { id: evaluationId },
      data: { status: 'COMPLETED', completedAt: new Date() },
    })
  } catch (err) {
    console.error('Evaluation async error:', err)
    await prisma.evaluation.update({
      where: { id: evaluationId },
      data: { status: 'FAILED' },
    })
  }
}

export async function getEvaluation(req: AuthRequest, res: Response): Promise<void> {
  try {
    const id = String(req.params.id)
    const evaluation = await prisma.evaluation.findUnique({
      where: { id },
      include: { results: true },
    })
    if (!evaluation) {
      res.status(404).json({ error: 'Evaluation not found' })
      return
    }
    res.json(evaluation)
  } catch {
    res.status(500).json({ error: 'Failed to fetch evaluation' })
  }
}

export async function listEvaluations(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { promptVersionId } = req.query
    const evaluations = await prisma.evaluation.findMany({
      where: promptVersionId ? { promptVersionId: String(promptVersionId) } : {},
      include: { results: true },
      orderBy: { startedAt: 'desc' },
    })
    res.json(evaluations)
  } catch {
    res.status(500).json({ error: 'Failed to list evaluations' })
  }
}
