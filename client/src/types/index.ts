export interface Provider {
  name: string
  models: string[]
}

export interface ModelTarget {
  provider: string
  model: string
}

