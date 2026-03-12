import request from 'supertest'
import { createTestApp, cleanDatabase, prisma } from './helpers'

const app = createTestApp()

beforeAll(async () => {
  await cleanDatabase()
})

afterAll(async () => {
  await cleanDatabase()
  await prisma.$disconnect()
})

describe('Auth', () => {
  const testUser = {
    email: 'auth@promptlab.com',
    name: 'Auth Tester',
    password: 'password123',
  }

  describe('POST /api/auth/register', () => {
    it('should register a new user and return token', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send(testUser)
        .expect(201)

      expect(res.body.user.email).toBe(testUser.email)
      expect(res.body.user.name).toBe(testUser.name)
      expect(res.body.token).toBeDefined()
      expect(res.body.defaultProjectId).toBeDefined()
      expect(res.body.user.password).toBeUndefined()
    })

    it('should fail if email already exists', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send(testUser)
        .expect(400)

      expect(res.body.error).toBe('Email already in use')
    })
  })

  describe('GET /api/auth/me', () => {
    it('should fail without token', async () => {
      await request(app)
        .get('/api/auth/me')
        .expect(401)
    })

    it('should fail with invalid token', async () => {
      await request(app)
        .get('/api/auth/me')
        .set('Authorization', 'Bearer invalidtoken')
        .expect(401)
    })
  })
})
