import request from 'supertest'
import { createTestApp, cleanDatabase, prisma } from './helpers'

const app = createTestApp()
let token: string
let projectId: string

beforeAll(async () => {
  await cleanDatabase()

  const res = await request(app)
    .post('/api/auth/register')
    .send({
      email: 'prompts@promptlab.com',
      name: 'Prompt Tester',
      password: 'password123',
    })

  if (!res.body.token) {
    throw new Error(`Registration failed: ${JSON.stringify(res.body)}`)
  }

  token = res.body.token
  projectId = res.body.defaultProjectId
})

afterAll(async () => {
  await cleanDatabase()
  await prisma.$disconnect()
})

describe('Prompts', () => {
  describe('POST /api/prompts', () => {
    it('should create a new prompt', async () => {
      const res = await request(app)
        .post('/api/prompts')
        .set('Authorization', `Bearer ${token}`)
        .send({ projectId, name: 'Test Prompt', description: 'A test prompt' })
        .expect(201)

      expect(res.body.name).toBe('Test Prompt')
      expect(res.body.status).toBe('DRAFT')
    })

    it('should fail without auth', async () => {
      await request(app)
        .post('/api/prompts')
        .send({ projectId, name: 'No Auth Prompt' })
        .expect(401)
    })
  })

  describe('GET /api/prompts', () => {
    it('should list prompts for a project', async () => {
      const res = await request(app)
        .get('/api/prompts')
        .query({ projectId })
        .set('Authorization', `Bearer ${token}`)
        .expect(200)

      expect(Array.isArray(res.body)).toBe(true)
      expect(res.body.length).toBeGreaterThan(0)
    })

    it('should fail without auth', async () => {
      await request(app)
        .get('/api/prompts')
        .expect(401)
    })
  })
})
