import { Response } from 'express'
import { AuthRequest } from '../middleware/auth.middleware'
import prisma from '../lib/prisma'

export async function createPrompt(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { projectId, name, description } = req.body
    const prompt = await prisma.prompt.create({
      data: { projectId, name, description, createdById: req.userId! },
    })
    res.status(201).json(prompt)
  } catch {
    res.status(500).json({ error: 'Failed to create prompt' })
  }
}

export async function listPrompts(req: AuthRequest, res: Response): Promise<void> {
  try {
    const { projectId } = req.query
    const prompts = await prisma.prompt.findMany({
      where: projectId ? { projectId: String(projectId) } : {},
      include: { versions: { orderBy: { versionNumber: 'desc' }, take: 1 } },
      orderBy: { updatedAt: 'desc' },
    })
    res.json(prompts)
  } catch {
    res.status(500).json({ error: 'Failed to list prompts' })
  }
}

export async function getPrompt(req: AuthRequest, res: Response): Promise<void> {
  try {
    const id = String(req.params.id)
    const prompt = await prisma.prompt.findUnique({
      where: { id },
      include: { versions: { orderBy: { versionNumber: 'desc' } } },
    })
    if (!prompt) { res.status(404).json({ error: 'Prompt not found' }); return }
    res.json(prompt)
  } catch {
    res.status(500).json({ error: 'Failed to get prompt' })
  }
}

export async function createVersion(req: AuthRequest, res: Response): Promise<void> {
  try {
    const promptId = String(req.params.id)
    const { systemPrompt, userPromptTemplate, variables, modelConfig, parentVersionId } = req.body
    const latest = await prisma.promptVersion.findFirst({
      where: { promptId },
      orderBy: { versionNumber: 'desc' },
    })
    const versionNumber = (latest?.versionNumber ?? 0) + 1
    const version = await prisma.promptVersion.create({
      data: {
        promptId,
        versionNumber,
        systemPrompt,
        userPromptTemplate,
        variables: variables ?? [],
        modelConfig: modelConfig ?? {},
        createdById: req.userId!,
        parentVersionId: parentVersionId ?? null,
      },
    })
    await prisma.prompt.update({
      where: { id: promptId },
      data: { currentVersionId: version.id },
    })
    res.status(201).json(version)
  } catch {
    res.status(500).json({ error: 'Failed to create version' })
  }
}

export async function listVersions(req: AuthRequest, res: Response): Promise<void> {
  try {
    const promptId = String(req.params.id)
    const versions = await prisma.promptVersion.findMany({
      where: { promptId },
      orderBy: { versionNumber: 'desc' },
    })
    res.json(versions)
  } catch {
    res.status(500).json({ error: 'Failed to list versions' })
  }
}