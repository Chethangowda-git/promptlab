import request from 'supertest'
import { createTestApp, cleanDatabase, prisma } from './helpers'

const app = createTestApp()
let token: string
let projectId: string
let promptId: string

beforeAll(async () => {
  await cleanDatabase()

  // Register and get token
  const res = await request(app)
    .post('/api/auth/register')
    .send({ email: 'prompts@test.com', name: 'Prompt Tester', password: 'password123' })

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
      promptId = res.body.id
    })

    it('should fail without auth', async () => {
      await request(app)
        .post('/api/prompts')
        .send({ projectId, name: 'No Auth Prompt' })
        .expect(401)
    })
  })

  describe('GET /api/prompts', () => {
    it('should list all prompts', async () => {
      const res = await request(app)
        .get('/api/prompts')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)

      expect(Array.isArray(res.body)).toBe(true)
      expect(res.body.length).toBeGreaterThan(0)
    })
  })

  describe('GET /api/prompts/:id', () => {
    it('should get a prompt by id', async () => {
      const res = await request(app)
        .get(`/api/prompts/${promptId}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200)

      expect(res.body.id).toBe(promptId)
      expect(res.body.versions).toBeDefined()
    })

    it('should return 404 for non-existent prompt', async () => {
      await request(app)
        .get('/api/prompts/non-existent-id')
        .set('Authorization', `Bearer ${token}`)
        .expect(404)
    })
  })

  describe('POST /api/prompts/:id/versions', () => {
    it('should create a new version', async () => {
      const res = await request(app)
        .post(`/api/prompts/${promptId}/versions`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          systemPrompt: 'You are a helpful assistant.',
          userPromptTemplate: 'Answer this: {{question}}',
          variables: [{ name: 'question', type: 'string', defaultValue: '' }],
          modelConfig: { model: 'llama-3.3-70b-versatile', temperature: 0.7 },
        })
        .expect(201)

      expect(res.body.versionNumber).toBe(1)
      expect(res.body.userPromptTemplate).toBe('Answer this: {{question}}')
    })

    it('should increment version number on second save', async () => {
      const res = await request(app)
        .post(`/api/prompts/${promptId}/versions`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          systemPrompt: 'You are an expert assistant.',
          userPromptTemplate: 'Please answer this question: {{question}}',
        })
        .expect(201)

      expect(res.body.versionNumber).toBe(2)
    })
  })

  describe('GET /api/prompts/:id/versions', () => {
    it('should list all versions of a prompt', async () => {
      const res = await request(app)
        .get(`/api/prompts/${promptId}/versions`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200)

      expect(Array.isArray(res.body)).toBe(true)
      expect(res.body.length).toBe(2)
    })
  })
})
