import { PrismaClient } from '@prisma/client'
import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import authRoutes from '../routes/auth.routes'
import promptRoutes from '../routes/prompts.routes'
import executeRoutes from '../routes/execute.routes'

export const prisma = new PrismaClient()

export function createTestApp() {
  const app = express()
  app.use(helmet())
  app.use(cors())
  app.use(express.json())
  app.use('/api/auth', authRoutes)
  app.use('/api/prompts', promptRoutes)
  app.use('/api/execute', executeRoutes)
  return app
}

export async function cleanDatabase() {
  // Delete in reverse FK dependency order

  // Step 1: leaf - no dependents
  await prisma.evaluationResult.deleteMany()

  // Step 2: depends on PromptVersion, TestDataset, User
  await prisma.evaluation.deleteMany()

  // Step 3: depends on PromptVersion, Project
  await prisma.experiment.deleteMany()

  // Step 4: depends on Project, User
  await prisma.promptPipeline.deleteMany()

  // Step 5: self-referencing FK — unset parentVersionId first
  await prisma.promptVersion.updateMany({ data: { parentVersionId: null } })
  await prisma.promptVersion.deleteMany()

  // Step 6: depends on Project, User
  await prisma.prompt.deleteMany()

  // Step 7: depends on Project, User
  await prisma.testDataset.deleteMany()

  // Step 8: depends on Team
  await prisma.project.deleteMany()

  // Step 9: User has teamId FK to Team — unset before deleting Team
  await prisma.user.updateMany({ data: { teamId: null } })
  await prisma.user.deleteMany()

  // Step 10: now safe
  await prisma.team.deleteMany()
}
