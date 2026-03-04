export type RadarConfig = {
  baseUrl: string
  token: string
}

export type Activation = {
  activationId: string
  signal: {
    signalId: string
    source: string
    title: string
    summary: string
    url: string | null
    identifier: string
    fetchedAtIso: string
  }
  clusters: { cluster: string; label: string; hits: string[]; count: number }[]
  activatedNamespaces: string[]
  cells: { cellId: string; wat: string; waar: string; wanneer: string }[]
  residue: number
  timestamp: string
}

export type Collision = {
  collisionId: string
  cells: { cellId: string }[]
  signals: { signalId: string; title: string; source: string }[]
  sources: string[]
  density: number
  isEmergence: boolean
  detectedAtIso: string
}

export type HeatmapCell = {
  cellId: string
  totalResidue: number
  activationCount: number
  sources: string[]
}

export type RadarStatus = {
  store: {
    activationCount: number
    collisionCount: number
    emergenceCount: number
    lastFetchBySource: Record<string, string>
    hotClusters: { cluster: string; count: number }[]
    topSignals: { title: string; source: string; residue: number }[]
  }
  collector: {
    isRunning: boolean
    lastRun: string | null
  }
}

export type SourceStats = {
  source: string
  signalCount: number
  avgResidue: number
  lastFetch: string
}

class RadarClient {
  private config: RadarConfig

  constructor(config: RadarConfig) {
    this.config = config
  }

  private async get<T>(path: string, params?: Record<string, string>): Promise<T> {
    const url = new URL(path, this.config.baseUrl)
    url.searchParams.set('token', this.config.token)
    if (params) {
      for (const [k, v] of Object.entries(params)) {
        url.searchParams.set(k, v)
      }
    }
    const res = await fetch(url.toString())
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}`)
    return res.json()
  }

  private async post<T>(path: string, body?: unknown): Promise<T> {
    const url = new URL(path, this.config.baseUrl)
    url.searchParams.set('token', this.config.token)
    const res = await fetch(url.toString(), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined
    })
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}`)
    return res.json()
  }

  status(): Promise<RadarStatus> {
    return this.get('/api/radar/status')
  }

  activations(opts?: { source?: string; minResidue?: number; limit?: number }): Promise<Activation[]> {
    const params: Record<string, string> = {}
    if (opts?.source) params.source = opts.source
    if (opts?.minResidue !== undefined) params.minResidue = String(opts.minResidue)
    if (opts?.limit !== undefined) params.limit = String(opts.limit)
    return this.get('/api/radar/activations', params)
  }

  heatmap(): Promise<{ heatmap: HeatmapCell[]; hotNamespaces: { id: string; cluster: string; hitCount: number }[] }> {
    return this.get('/api/radar/heatmap')
  }

  collisions(): Promise<Collision[]> {
    return this.get('/api/radar/collisions')
  }

  emergence(): Promise<Collision[]> {
    return this.get('/api/radar/emergence')
  }

  sources(): Promise<SourceStats[]> {
    return this.get('/api/radar/sources')
  }

  clusters(): Promise<{ cluster: string; label: string; count: number }[]> {
    return this.get('/api/radar/clusters')
  }

  injectSignal(signal: { title: string; summary?: string; source?: string }): Promise<Activation> {
    return this.post('/api/radar/signal', signal)
  }

  triggerFetch(sources?: string[]): Promise<{ fetched: number; matched: number; collisions: number; emergence: number }> {
    return this.post('/api/radar/fetch', sources ? { sources } : undefined)
  }
}

export function createRadarClient(config: RadarConfig): RadarClient {
  return new RadarClient(config)
}
