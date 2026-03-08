import { Router } from 'express'
import { authMiddleware } from '../middleware/auth.middleware'
import { executePrompt, executeBatch, improvePrompt, listProviders } from '../controllers/execute.controller'

const router = Router()

router.use(authMiddleware)

router.post('/', executePrompt)
router.post('/batch', executeBatch)
router.post('/improve', improvePrompt)
router.get('/providers', listProviders)

export default router
