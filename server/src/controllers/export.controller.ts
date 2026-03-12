import { Response } from 'express'
import { AuthRequest } from '../middleware/auth.middleware'
import prisma from '../lib/prisma'

export async function exportAsJSON(req: AuthRequest, res: Response): Promise<void> {
  try {
    const versionId = String(req.params.versionId)
    const version = await prisma.promptVersion.findUnique({
      where: { id: versionId },
      include: { prompt: true },
    })
    if (!version) { res.status(404).json({ error: 'Version not found' }); return }

    res.json({
      name: version.prompt.name,
      version: version.versionNumber,
      systemPrompt: version.systemPrompt,
      userPromptTemplate: version.userPromptTemplate,
      variables: version.variables,
      modelConfig: version.modelConfig,
      exportedAt: new Date().toISOString(),
    })
  } catch {
    res.status(500).json({ error: 'Export failed' })
  }
}

export async function exportAsPython(req: AuthRequest, res: Response): Promise<void> {
  try {
    const versionId = String(req.params.versionId)
    const version = await prisma.promptVersion.findUnique({
      where: { id: versionId },
      include: { prompt: true },
    })
    if (!version) { res.status(404).json({ error: 'Version not found' }); return }

    const modelConfig: any = version.modelConfig || {}
    const model = modelConfig.model || 'llama-3.3-70b-versatile'
    const provider = modelConfig.provider || 'groq'

    let code = ''

    if (provider === 'groq') {
      code = `from groq import Groq

client = Groq(api_key="YOUR_GROQ_API_KEY")

system_prompt = """${version.systemPrompt || ''}"""

user_prompt = """${version.userPromptTemplate}"""

# Replace template variables before sending
# user_prompt = user_prompt.replace("{{variable}}", actual_value)

response = client.chat.completions.create(
    model="${model}",
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ],
    temperature=${modelConfig.temperature || 0.7},
    max_tokens=${modelConfig.maxTokens || 1024},
)

print(response.choices[0].message.content)
`
    } else {
      code = `import google.generativeai as genai

genai.configure(api_key="YOUR_GEMINI_API_KEY")

model = genai.GenerativeModel(
    model_name="${model}",
    system_instruction="""${version.systemPrompt || ''}"""
)

user_prompt = """${version.userPromptTemplate}"""

# Replace template variables before sending
# user_prompt = user_prompt.replace("{{variable}}", actual_value)

response = model.generate_content(user_prompt)
print(response.text)
`
    }

    res.json({
      code,
      language: 'python',
      promptName: version.prompt.name,
      version: version.versionNumber,
    })
  } catch {
    res.status(500).json({ error: 'Export failed' })
  }
}