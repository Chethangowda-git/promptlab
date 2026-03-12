import { Router } from 'express'
import { authMiddleware } from '../middleware/auth.middleware'
import { runEvaluation, getEvaluation, listEvaluations } from '../controllers/evaluation.controller'

const router = Router()
router.use(authMiddleware)
router.post('/', runEvaluation)
router.get('/', listEvaluations)
router.get('/:id', getEvaluation)

export default router
