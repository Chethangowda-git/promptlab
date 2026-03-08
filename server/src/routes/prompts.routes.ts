import { Router } from 'express'
import { authMiddleware } from '../middleware/auth.middleware'
import {
  createPrompt, listPrompts, getPrompt,
  createVersion, listVersions,
} from '../controllers/prompts.controller'

const router = Router()

router.use(authMiddleware)

router.post('/', createPrompt)
router.get('/', listPrompts)
router.get('/:id', getPrompt)
router.post('/:id/versions', createVersion)
router.get('/:id/versions', listVersions)

export default router
