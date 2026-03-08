export interface ExecuteOptions {
  systemPrompt?: string
  userPrompt: string
  temperature?: number
  maxTokens?: number
}

export interface ExecuteResult {
  output: string
  model: string
  provider: string
  latencyMs: number
  inputTokens: number
  outputTokens: number
  cost: number
}

export abstract class BaseProvider {
  abstract name: string
  abstract models: string[]
  abstract execute(model: string, options: ExecuteOptions): Promise<ExecuteResult>

  protected calculateCost(
    inputTokens: number,
    outputTokens: number,
    inputPricePerMillion: number,
    outputPricePerMillion: number
  ): number {
    return (
      (inputTokens / 1_000_000) * inputPricePerMillion +
      (outputTokens / 1_000_000) * outputPricePerMillion
    )
  }
}
