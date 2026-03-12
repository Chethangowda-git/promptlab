process.env.JWT_SECRET = 'test_jwt_secret_for_ci'
process.env.DATABASE_URL =
  process.env.DATABASE_URL ||
  'postgresql://promptlab:promptlab_pass@localhost:5432/promptlab_test'
process.env.GROQ_API_KEY = 'test_key'
process.env.GEMINI_API_KEY = 'test_key'
process.env.PORT = '4001'