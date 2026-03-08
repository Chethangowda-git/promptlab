import { GoogleGenerativeAI } from '@google/generative-ai'
import { BaseProvider, ExecuteOptions, ExecuteResult } from './base.provider'

export class GeminiProvider extends BaseProvider {
  name = 'gemini'
  models = ['gemini-1.5-flash', 'gemini-1.5-pro']
  private client: GoogleGenerativeAI

  constructor() {
    super()
    this.client = new GoogleGenerativeAI(process.env.GEMINI_API_KEY ?? '')
  }

  async execute(model: string, options: ExecuteOptions): Promise<ExecuteResult> {
    const start = Date.now()

    const genModel = this.client.getGenerativeModel({
      model,
      systemInstruction: options.systemPrompt,
    })

    const result = await genModel.generateContent({
      contents: [{ role: 'user', parts: [{ text: options.userPrompt }] }],
      generationConfig: {
        temperature: options.temperature ?? 0.7,
        maxOutputTokens: options.maxTokens ?? 1024,
      },
    })

    const latencyMs = Date.now() - start
    const inputTokens = result.response.usageMetadata?.promptTokenCount ?? 0
    const outputTokens = result.response.usageMetadata?.candidatesTokenCount ?? 0

    return {
      output: result.response.text(),
      model,
      provider: this.name,
      latencyMs,
      inputTokens,
      outputTokens,
      cost: this.calculateCost(inputTokens, outputTokens, 0.075, 0.30),
    }
  }
}
