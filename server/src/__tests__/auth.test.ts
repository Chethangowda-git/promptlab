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
    email: 'test@promptlab.com',
    name: 'Test User',
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

    it('should fail if required fields are missing', async () => {
      await request(app)
        .post('/api/auth/register')
        .send({ email: 'incomplete@test.com' })
        .expect(500)
    })
  })

  describe('POST /api/auth/login', () => {
    it('should login with correct credentials', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: testUser.email, password: testUser.password })
        .expect(200)

      expect(res.body.token).toBeDefined()
      expect(res.body.user.email).toBe(testUser.email)
      expect(res.body.defaultProjectId).toBeDefined()
    })

    it('should fail with wrong password', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: testUser.email, password: 'wrongpassword' })
        .expect(401)

      expect(res.body.error).toBe('Invalid credentials')
    })

    it('should fail with non-existent email', async () => {
      await request(app)
        .post('/api/auth/login')
        .send({ email: 'nobody@test.com', password: 'password123' })
        .expect(401)
    })
  })

  describe('GET /api/auth/me', () => {
    it('should return user info with valid token', async () => {
      const loginRes = await request(app)
        .post('/api/auth/login')
        .send({ email: testUser.email, password: testUser.password })

      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${loginRes.body.token}`)
        .expect(200)

      expect(res.body.email).toBe(testUser.email)
    })

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