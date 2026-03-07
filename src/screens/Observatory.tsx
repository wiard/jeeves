import { useCallback, useEffect, useMemo, useReducer, useRef, useState, type TouchEventHandler } from 'react'
import {
  createRadarClient,
  type Activation,
  type Collision,
  type DiscoveryCandidate,
  type GravityHotspot,
  type HeatmapCell,
  type PaperSignal,
  type RadarStatus,
  type SourceStats
} from '../api/radar'
import { ClusterTags } from '../components/ClusterTags'
import { CubeHeatmap } from '../components/CubeHeatmap'
import { DiscoveryCandidateCard } from '../components/DiscoveryCandidateCard'
import { EmergenceCard } from '../components/EmergenceCard'
import { GravityHotspotCard } from '../components/GravityHotspotCard'
import { JeevesVoice } from '../components/JeevesVoice'
import { PaperSignalCard } from '../components/PaperSignalCard'
import { SignalCard } from '../components/SignalCard'
import { SignalInject } from '../components/SignalInject'
import { SourceBar } from '../components/SourceBar'

type ClusterCount = {
  cluster: string
  label: string
  count: number
}

type ObservatoryState = {
  status: RadarStatus | null
  emergence: Collision[]
  activations: Activation[]
  heatmap: HeatmapCell[]
  hotClusters: ClusterCount[]
  sourceStats: SourceStats[]
  gravityHotspots: GravityHotspot[]
  discoveryCandidates: DiscoveryCandidate[]
  papers: PaperSignal[]
  lastRefresh: string | null
  isLoading: boolean
  isConnected: boolean
  error: string | null
}

type DataPayload = {
  status: RadarStatus | null
  emergence: Collision[]
  activations: Activation[]
  heatmap: HeatmapCell[]
  hotClusters: ClusterCount[]
  sourceStats: SourceStats[]
  gravityHotspots: GravityHotspot[]
  discoveryCandidates: DiscoveryCandidate[]
  papers: PaperSignal[]
  lastRefresh: string | null
}

type ObservatoryAction =
  | { type: 'loading' }
  | { type: 'success'; payload: DataPayload }
  | { type: 'cache'; payload: DataPayload; error: string }
  | { type: 'failure'; error: string }

const CACHE_KEY = 'radar-observatory-cache-v1'
const EMERGENCE_LOG_KEY = 'radar-emergence-log-v1'

const initialState: ObservatoryState = {
  status: null,
  emergence: [],
  activations: [],
  heatmap: [],
  hotClusters: [],
  sourceStats: [],
  gravityHotspots: [],
  discoveryCandidates: [],
  papers: [],
  lastRefresh: null,
  isLoading: true,
  isConnected: true,
  error: null
}

function reducer(state: ObservatoryState, action: ObservatoryAction): ObservatoryState {
  switch (action.type) {
    case 'loading':
      return { ...state, isLoading: true }
    case 'success':
      return {
        ...state,
        ...action.payload,
        isLoading: false,
        isConnected: true,
        error: null
      }
    case 'cache':
      return {
        ...state,
        ...action.payload,
        isLoading: false,
        isConnected: false,
        error: action.error
      }
    case 'failure':
      return {
        ...state,
        isLoading: false,
        isConnected: false,
        error: action.error
      }
    default:
      return state
  }
}

function sortEmergence(collisions: Collision[]): Collision[] {
  return [...collisions].sort((a, b) => {
    const aTime = Date.parse(a.detectedAtIso)
    const bTime = Date.parse(b.detectedAtIso)
    if (aTime !== bTime) return bTime - aTime
    return a.collisionId.localeCompare(b.collisionId)
  })
}

function sortActivations(activations: Activation[]): Activation[] {
  return [...activations].sort((a, b) => {
    const aTime = Date.parse(a.timestamp)
    const bTime = Date.parse(b.timestamp)
    if (aTime !== bTime) return bTime - aTime
    return a.activationId.localeCompare(b.activationId)
  })
}

function deriveClusters(
  clusterApi: { cluster: string; label: string; count: number }[] | null,
  status: RadarStatus | null
): ClusterCount[] {
  if (clusterApi && clusterApi.length > 0) {
    return [...clusterApi]
      .sort((a, b) => {
        if (a.count !== b.count) return b.count - a.count
        return a.label.localeCompare(b.label)
      })
      .map((cluster) => ({
        cluster: cluster.cluster,
        label: cluster.label || cluster.cluster,
        count: cluster.count
      }))
  }

  const fallback = status?.store.hotClusters ?? []
  return [...fallback]
    .sort((a, b) => {
      if (a.count !== b.count) return b.count - a.count
      return a.cluster.localeCompare(b.cluster)
    })
    .map((cluster) => ({
      cluster: cluster.cluster,
      label: cluster.cluster,
      count: cluster.count
    }))
}

function getJeevesMessage(state: ObservatoryState): string {
  if (!state.isConnected) return 'De verbinding is verbroken, meneer. Ik probeer het opnieuw.'
  if (state.emergence.length > 0) return 'Meneer, er is iets dat uw aandacht verdient.'
  if (state.status?.store.activationCount === 0) return 'Het huis is stil. Geen signalen.'
  if (state.hotClusters.length > 0) {
    const top = state.hotClusters[0]
    return `De ${top.label} cluster is het meest actief, meneer. ${top.count} signalen.`
  }
  return 'Het huis luistert, meneer.'
}

function formatTime(iso: string | null): string {
  if (!iso) return 'n.v.t.'
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return 'n.v.t.'
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}

function readCache(): DataPayload | null {
  try {
    const raw = localStorage.getItem(CACHE_KEY)
    if (!raw) return null
    return JSON.parse(raw) as DataPayload
  } catch {
    return null
  }
}

function writeCache(payload: DataPayload) {
  localStorage.setItem(CACHE_KEY, JSON.stringify(payload))
}

function logEmergenceAction(kind: 'acknowledge' | 'dismiss', collisionId: string) {
  try {
    const raw = localStorage.getItem(EMERGENCE_LOG_KEY)
    const current = raw ? (JSON.parse(raw) as Array<{ kind: string; collisionId: string; timestamp: string }>) : []
    current.push({ kind, collisionId, timestamp: new Date().toISOString() })
    localStorage.setItem(EMERGENCE_LOG_KEY, JSON.stringify(current.slice(-300)))
  } catch {
    return
  }
}

type ObservatoryProps = {
  token: string
  baseUrl: string
  onDisconnect: () => void
}

export function Observatory({ token, baseUrl, onDisconnect }: ObservatoryProps) {
  const [state, dispatch] = useReducer(reducer, initialState)
  const [dismissedEmergence, setDismissedEmergence] = useState<Set<string>>(new Set())
  const [acknowledgedEmergence, setAcknowledgedEmergence] = useState<Set<string>>(new Set())
  const [pullStartY, setPullStartY] = useState<number | null>(null)
  const [pullDistance, setPullDistance] = useState(0)

  const stateRef = useRef(state)
  useEffect(() => {
    stateRef.current = state
  }, [state])

  const client = useMemo(() => createRadarClient({ baseUrl, token }), [baseUrl, token])

  const refresh = useCallback(async () => {
    dispatch({ type: 'loading' })

    const previous = stateRef.current

    try {
      const [statusRes, emergenceRes, activationsRes, heatmapRes, sourcesRes, clustersRes, gravityRes, discoveriesRes, papersRes] = await Promise.allSettled([
        client.status(),
        client.emergence(),
        client.activations({ limit: 30 }),
        client.heatmap(),
        client.sources(),
        client.clusters(),
        client.gravity(),
        client.discoveries(),
        client.papers({ limit: 30 })
      ])

      const successCount = [statusRes, emergenceRes, activationsRes, heatmapRes, sourcesRes, clustersRes, gravityRes, discoveriesRes, papersRes].filter(
        (result) => result.status === 'fulfilled'
      ).length

      if (successCount === 0) {
        throw new Error('Geen verbinding met radar')
      }

      const status = statusRes.status === 'fulfilled' ? statusRes.value : previous.status
      const emergence = emergenceRes.status === 'fulfilled' ? sortEmergence(emergenceRes.value) : previous.emergence
      const activations = activationsRes.status === 'fulfilled' ? sortActivations(activationsRes.value) : previous.activations
      const heatmap = heatmapRes.status === 'fulfilled' ? heatmapRes.value.heatmap : previous.heatmap
      const sourceStats = sourcesRes.status === 'fulfilled' ? [...sourcesRes.value].sort((a, b) => a.source.localeCompare(b.source)) : previous.sourceStats
      const clusterApi = clustersRes.status === 'fulfilled' ? clustersRes.value : null
      const gravityHotspots = gravityRes.status === 'fulfilled' ? gravityRes.value.hotspots : previous.gravityHotspots
      const discoveryCandidates = discoveriesRes.status === 'fulfilled' ? discoveriesRes.value.candidates : previous.discoveryCandidates
      const papers = papersRes.status === 'fulfilled' ? papersRes.value.papers : previous.papers

      const payload: DataPayload = {
        status,
        emergence,
        activations,
        heatmap,
        sourceStats,
        hotClusters: deriveClusters(clusterApi, status),
        gravityHotspots,
        discoveryCandidates,
        papers,
        lastRefresh: new Date().toISOString()
      }

      writeCache(payload)
      dispatch({ type: 'success', payload })
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Verbinding verbroken'
      const cached = readCache()
      if (cached) {
        dispatch({ type: 'cache', payload: cached, error: message })
      } else {
        dispatch({ type: 'failure', error: message })
      }
    }
  }, [client])

  useEffect(() => {
    const cached = readCache()
    if (cached) {
      dispatch({ type: 'cache', payload: cached, error: 'Cache actief' })
    }
    void refresh()
  }, [refresh])

  useEffect(() => {
    const interval = window.setInterval(() => {
      void refresh()
    }, 60000)
    return () => window.clearInterval(interval)
  }, [refresh])

  const onTouchStart: TouchEventHandler<HTMLElement> = (event) => {
    if (window.scrollY > 0) return
    setPullStartY(event.touches[0].clientY)
  }

  const onTouchMove: TouchEventHandler<HTMLElement> = (event) => {
    if (pullStartY === null) return
    if (window.scrollY > 0) return

    const distance = event.touches[0].clientY - pullStartY
    if (distance > 0) {
      setPullDistance(Math.min(distance, 120))
    }
  }

  const onTouchEnd: TouchEventHandler<HTMLElement> = () => {
    if (pullDistance >= 80) {
      void refresh()
    }
    setPullDistance(0)
    setPullStartY(null)
  }

  const emergenceVisible = useMemo(() => {
    return state.emergence.filter((item) => !dismissedEmergence.has(item.collisionId))
  }, [dismissedEmergence, state.emergence])

  const emergenceCellIds = useMemo(() => {
    const set = new Set<string>()
    for (const item of emergenceVisible) {
      for (const cell of item.cells) {
        set.add(cell.cellId)
      }
    }
    return set
  }, [emergenceVisible])

  const onAcknowledge = useCallback((collisionId: string) => {
    setAcknowledgedEmergence((prev) => {
      const next = new Set(prev)
      next.add(collisionId)
      return next
    })
    logEmergenceAction('acknowledge', collisionId)
  }, [])

  const onDismiss = useCallback((collisionId: string) => {
    setDismissedEmergence((prev) => {
      const next = new Set(prev)
      next.add(collisionId)
      return next
    })
    logEmergenceAction('dismiss', collisionId)
  }, [])

  const onInject = useCallback(
    async (signal: { title: string; summary?: string; source?: string }) => {
      await client.injectSignal(signal)
      await refresh()
    },
    [client, refresh]
  )

  const statusClass = state.isConnected ? 'online' : state.status ? 'offline' : 'error'

  return (
    <main className="observatory" onTouchStart={onTouchStart} onTouchMove={onTouchMove} onTouchEnd={onTouchEnd}>
      <div className={`pull-indicator ${pullDistance > 12 ? 'visible' : ''}`.trim()}>
        {pullDistance >= 80 ? 'Laat los om te verversen' : 'Trek omlaag om te verversen'}
      </div>

      <header className="obs-header">
        <h1>Observatory</h1>
        <div>
          <div className="status-text">
            <span className={`status-dot ${statusClass}`} />
            {state.isLoading ? 'verversen...' : `laatste ${formatTime(state.lastRefresh)}`}
          </div>
          <button className="disconnect-button" onClick={onDisconnect} type="button">
            token wissen
          </button>
        </div>
      </header>

      {!state.isConnected ? <div className="connection-banner">verbinding verbroken</div> : null}

      <JeevesVoice message={getJeevesMessage(state)} />

      <div className="section-header">Emergence</div>
      {emergenceVisible.length === 0 ? (
        <div className="empty-state">
          <div className="message">Geen emergence op dit moment.</div>
        </div>
      ) : (
        emergenceVisible.map((collision) => (
          <EmergenceCard
            key={collision.collisionId}
            collision={collision}
            acknowledged={acknowledgedEmergence.has(collision.collisionId)}
            onAcknowledge={onAcknowledge}
            onDismiss={onDismiss}
          />
        ))
      )}

      <div className="section-header">Cube</div>
      <CubeHeatmap heatmap={state.heatmap} emergenceCellIds={emergenceCellIds} />

      <div className="section-header">Clusters</div>
      <ClusterTags clusters={state.hotClusters} />

      <div className="section-header">Gravity Hotspots</div>
      {state.gravityHotspots.length === 0 ? (
        <div className="empty-state">
          <div className="message">Geen gravity hotspots.</div>
        </div>
      ) : (
        state.gravityHotspots.slice(0, 10).map((hotspot) => (
          <GravityHotspotCard key={`g-${hotspot.cell}-${hotspot.rank}`} hotspot={hotspot} />
        ))
      )}

      <div className="section-header">Discovery Candidates</div>
      {state.discoveryCandidates.length === 0 ? (
        <div className="empty-state">
          <div className="message">Geen discovery candidates.</div>
        </div>
      ) : (
        state.discoveryCandidates.slice(0, 10).map((candidate) => (
          <DiscoveryCandidateCard key={candidate.candidateId} candidate={candidate} />
        ))
      )}

      <div className="section-header">Papers</div>
      {state.papers.length === 0 ? (
        <div className="empty-state">
          <div className="message">Geen papers.</div>
        </div>
      ) : (
        state.papers.slice(0, 20).map((paper) => (
          <PaperSignalCard key={paper.signalId} paper={paper} />
        ))
      )}

      <div className="section-header">Signals</div>
      {state.activations.length === 0 ? (
        <div className="empty-state">
          <div className="message">Het huis is stil. Geen signalen.</div>
        </div>
      ) : (
        state.activations.slice(0, 20).map((activation) => <SignalCard key={activation.activationId} activation={activation} />)
      )}

      <SourceBar sourceStats={state.sourceStats} />

      <SignalInject onSubmit={onInject} />
    </main>
  )
}
