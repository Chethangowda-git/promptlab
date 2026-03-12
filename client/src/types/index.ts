export interface Provider {
  name: string
  models: string[]
}

export interface ModelTarget {
  provider: string
  model: string
}
const broken: number = "this is not a number"
