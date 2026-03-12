import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import morgan from 'morgan'
import dotenv from 'dotenv'
import authRoutes from './routes/auth.routes'
import promptRoutes from './routes/prompts.routes'
import executeRoutes from './routes/execute.routes'
import evaluationRoutes from './routes/evaluation.routes'
import exportRoutes from './routes/export.routes'
import experimentRoutes from './routes/experiment.routes'

dotenv.config()

const app = express()
const PORT = process.env.PORT || 4000

app.use(helmet())
app.use(cors())
app.use(morgan('dev'))
app.use(express.json())

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
})

app.use('/api/auth', authRoutes)
app.use('/api/prompts', promptRoutes)
app.use('/api/execute', executeRoutes)
app.use('/api/evaluations', evaluationRoutes)
app.use('/api/export', exportRoutes)
app.use('/api/experiments', experimentRoutes)

app.listen(PORT, () => {
  console.log(`✅ Server running on http://localhost:${PORT}`)
})

export default app
