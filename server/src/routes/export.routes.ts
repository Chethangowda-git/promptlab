import { Router } from 'express'
import { authMiddleware } from '../middleware/auth.middleware'
import { exportAsJSON, exportAsPython } from '../controllers/export.controller'

const router = Router()
router.use(authMiddleware)
router.get('/:versionId/json', exportAsJSON)
router.get('/:versionId/python', exportAsPython)

export default router
