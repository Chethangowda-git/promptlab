import Groq from 'groq-sdk'
import { BaseProvider, ExecuteOptions, ExecuteResult } from './base.provider'

export class GroqProvider extends BaseProvider {
  name = 'groq'
  // models = ['llama3-8b-8192', 'llama3-70b-8192', 'mixtral-8x7b-32768', 'gemma2-9b-it']
  models = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant', 'mixtral-8x7b-32768', 'gemma2-9b-it']
  private client: Groq

  constructor() {
    super()
    this.client = new Groq({ apiKey: process.env.GROQ_API_KEY })
  }

  async execute(model: string, options: ExecuteOptions): Promise<ExecuteResult> {
    const start = Date.now()
    const messages: Groq.Chat.ChatCompletionMessageParam[] = []

    if (options.systemPrompt) {
      messages.push({ role: 'system', content: options.systemPrompt })
    }
    messages.push({ role: 'user', content: options.userPrompt })

    const response = await this.client.chat.completions.create({
      model,
      messages,
      temperature: options.temperature ?? 0.7,
      max_tokens: options.maxTokens ?? 1024,
    })

    const latencyMs = Date.now() - start
    const inputTokens = response.usage?.prompt_tokens ?? 0
    const outputTokens = response.usage?.completion_tokens ?? 0

    return {
      output: response.choices[0]?.message?.content ?? '',
      model,
      provider: this.name,
      latencyMs,
      inputTokens,
      outputTokens,
      cost: this.calculateCost(inputTokens, outputTokens, 0.05, 0.10),
    }
  }
}
