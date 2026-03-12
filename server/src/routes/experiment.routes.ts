import { Router } from 'express'
import { authMiddleware } from '../middleware/auth.middleware'
import { createExperiment, runExperiment, getExperiment, listExperiments } from '../controllers/experiment.controller'

const router = Router()
router.use(authMiddleware)
router.post('/', createExperiment)
router.get('/', listExperiments)
router.get('/:id', getExperiment)
router.post('/:id/run', runExperiment)

export default router
