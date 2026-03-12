// This file runs before any test file imports
// This is the ONLY place env vars should be set for tests
process.env.JWT_SECRET = 'test_jwt_secret_for_ci'
process.env.GROQ_API_KEY = 'test_key'
process.env.GEMINI_API_KEY = 'test_key'
process.env.PORT = '4001'
process.env.REDIS_URL = process.env.REDIS_URL ?? 'redis://localhost:6379'
process.env.DATABASE_URL =
  process.env.DATABASE_URL ??
  'postgresql://promptlab:promptlab_pass@localhost:5432/promptlab_test'
