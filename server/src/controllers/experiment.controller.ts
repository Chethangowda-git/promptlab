import { Response } from 'express'
import { AuthRequest } from '../middleware/auth.middleware'
import prisma from '../lib/prisma'
import { getProvider } from '../providers'

export async function createExperiment(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { name, versionAId, versionBId, trafficSplit } = req.body

    const project = await prisma.project.findFirst({
      where: { team: { users: { some: { id: req.userId! } } } },
    })
    if (!project) {
      res.status(400).json({ error: 'No project found for user' })
      return
    }

    const experiment = await prisma.experiment.create({
      data: {
        projectId: project.id,
        name,
        versionAId,
        versionBId,
        trafficSplit: trafficSplit || { a: 50, b: 50 },
        status: 'RUNNING',
      },
    })
    res.status(201).json(experiment)
  } catch (err: any) {
    console.error(err)
    res.status(500).json({ error: err.message })
  }
}

export async function runExperiment(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { id } = req.params
    const { provider, model, inputs } = req.body

    const experiment = await prisma.experiment.findUnique({
      where: { id: String(id) },
      include: { versionA: true, versionB: true },
    })
    if (!experiment) { res.status(404).json({ error: 'Experiment not found' }); return }

    const p = getProvider(provider)
    const results = []

    for (const input of inputs) {
      const [resultA, resultB] = await Promise.all([
        p.execute(model, {
          systemPrompt: experiment.versionA.systemPrompt || undefined,
          userPrompt: input.userPrompt,
        }),
        p.execute(model, {
          systemPrompt: experiment.versionB.systemPrompt || undefined,
          userPrompt: input.userPrompt,
        }),
      ])

      // LLM judge to pick winner
      const judge = getProvider('groq')
      const judgeResult = await judge.execute('llama-3.1-8b-instant', {
        userPrompt: `You are a judge comparing two AI responses to the same prompt.

Prompt: ${input.userPrompt}

Response A: ${resultA.output}

Response B: ${resultB.output}

Which response is better? Respond ONLY with JSON: {"winner": "A" or "B", "reason": "brief reason", "scores": {"A": 1-10, "B": 1-10}}`,
        temperature: 0.1,
        maxTokens: 256,
      })

      let judgeData = { winner: 'A', reason: 'Default', scores: { A: 5, B: 5 } }
      try {
        const clean = judgeResult.output.replace(/```json|```/g, '').trim()
        const match = clean.match(/\{[\s\S]*\}/)
        if (match) judgeData = JSON.parse(match[0])
      } catch {}

      results.push({
        input: input.userPrompt,
        versionA: { output: resultA.output, latencyMs: resultA.latencyMs, tokens: resultA.outputTokens },
        versionB: { output: resultB.output, latencyMs: resultB.latencyMs, tokens: resultB.outputTokens },
        judge: judgeData,
      })
    }

    // Tally winner
    const aWins = results.filter((r) => r.judge.winner === 'A').length
    const bWins = results.filter((r) => r.judge.winner === 'B').length
    const overallWinner = aWins >= bWins ? 'A' : 'B'

    const updatedExperiment = await prisma.experiment.update({
      where: { id: String(id) },
      data: {
        status: 'COMPLETED',
        completedAt: new Date(),
        results: { results, summary: { aWins, bWins, winner: overallWinner } },
      },
    })

    res.json({ experiment: updatedExperiment, results, summary: { aWins, bWins, winner: overallWinner } })
  } catch (err: any) {
    console.error(err)
    res.status(500).json({ error: err.message })
  }
}

export async function getExperiment(req: AuthRequest, res: Response): Promise<void> {
  try {
    const experiment = await prisma.experiment.findUnique({
      where: { id: String(req.params.id) },
      include: { versionA: true, versionB: true },
    })
    if (!experiment) { res.status(404).json({ error: 'Not found' }); return }
    res.json(experiment)
  } catch {
    res.status(500).json({ error: 'Failed to fetch experiment' })
  }
}

export async function listExperiments(req: AuthRequest, res: Response): Promise<void> {
  try {
    const experiments = await prisma.experiment.findMany({
      include: { versionA: true, versionB: true },
      orderBy: { startedAt: 'desc' },
    })
    res.json(experiments)
  } catch {
    res.status(500).json({ error: 'Failed to list experiments' })
  }
}
