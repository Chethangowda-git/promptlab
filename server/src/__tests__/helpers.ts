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
  // Order matters — delete children before parents
  await prisma.evaluationResult.deleteMany()
  await prisma.evaluation.deleteMany()
  await prisma.experiment.deleteMany()
  await prisma.promptPipeline.deleteMany()
  await prisma.promptVersion.deleteMany()
  await prisma.prompt.deleteMany()
  await prisma.testDataset.deleteMany()
  await prisma.project.deleteMany()
  await prisma.user.deleteMany()
  await prisma.team.deleteMany()
}
