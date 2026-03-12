import request from 'supertest'
import { createTestApp, cleanDatabase, prisma } from './helpers'



const app = createTestApp()
let token: string

beforeAll(async () => {
  await cleanDatabase()

  const res = await request(app)
    .post('/api/auth/register')
    .send({ email: 'execute@test.com', name: 'Execute Tester', password: 'password123' })

  token = res.body.token
})

afterAll(async () => {
  await cleanDatabase()
  await prisma.$disconnect()
})

describe('Execute', () => {
  describe('GET /api/execute/providers', () => {
    it('should return available providers', async () => {
      const res = await request(app)
        .get('/api/execute/providers')
        .set('Authorization', `Bearer ${token}`)
        .expect(200)

      expect(Array.isArray(res.body)).toBe(true)
      expect(res.body.length).toBeGreaterThan(0)

      const providerNames = res.body.map((p: { name: string }) => p.name)
      expect(providerNames).toContain('groq')
      expect(providerNames).toContain('gemini')

      res.body.forEach((p: { name: string; models: string[] }) => {
        expect(p.name).toBeDefined()
        expect(Array.isArray(p.models)).toBe(true)
        expect(p.models.length).toBeGreaterThan(0)
      })
    })

    it('should fail without auth', async () => {
      await request(app)
        .get('/api/execute/providers')
        .expect(401)
    })
  })
})