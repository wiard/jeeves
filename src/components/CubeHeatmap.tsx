import { useMemo } from 'react'
import type { HeatmapCell } from '../api/radar'

type CubeHeatmapProps = {
  heatmap: HeatmapCell[]
  emergenceCellIds: Set<string>
}

type Coords = {
  wat: number
  waar: number
  wanneer: number
}

const WAT_INDEX: Record<string, number> = {
  'trust-model': 0,
  trustmodel: 0,
  tm: 0,
  surface: 1,
  architecture: 2
}

const WAAR_INDEX: Record<string, number> = {
  internal: 0,
  external: 1,
  engine: 2
}

const WANNEER_INDEX: Record<string, number> = {
  historical: 0,
  current: 1,
  emerging: 2
}

function normalize(value: string): string {
  return value.trim().toLowerCase()
}

function parseCellId(cellId: string): Coords | null {
  const byPipe = cellId.split('|')
  const byColon = cellId.split(':')
  const bySlash = cellId.split('/')
  const parts = [byPipe, byColon, bySlash].find((entry) => entry.length === 3)
  if (!parts) return null

  const [watRaw, waarRaw, wanneerRaw] = parts.map(normalize)
  const wat = WAT_INDEX[watRaw]
  const waar = WAAR_INDEX[waarRaw]
  const wanneer = WANNEER_INDEX[wanneerRaw]
  if (wat === undefined || waar === undefined || wanneer === undefined) return null

  return { wat, waar, wanneer }
}

function heatLevel(totalResidue: number): number {
  if (totalResidue <= 0) return 0
  if (totalResidue < 0.15) return 1
  if (totalResidue < 0.3) return 2
  if (totalResidue < 0.45) return 3
  if (totalResidue < 0.6) return 4
  if (totalResidue < 0.75) return 5
  if (totalResidue < 0.9) return 6
  return 7
}

function positionKey(coords: Coords): string {
  return `${coords.wanneer}:${coords.waar}:${coords.wat}`
}

const LAYER_LABELS = ['historical', 'current', 'emerging']

export function CubeHeatmap({ heatmap, emergenceCellIds }: CubeHeatmapProps) {
  const { residues, emergencePositions } = useMemo(() => {
    const matrix = Array.from({ length: 3 }, () =>
      Array.from({ length: 3 }, () => Array.from({ length: 3 }, () => 0))
    )

    const unresolved = [...heatmap].sort((a, b) => a.cellId.localeCompare(b.cellId))
    const fallbackMap = new Map<string, Coords>()

    for (const cell of unresolved) {
      const parsed = parseCellId(cell.cellId)
      if (parsed) {
        matrix[parsed.wanneer][parsed.waar][parsed.wat] += cell.totalResidue
      }
    }

    const unresolvedOnly = unresolved.filter((cell) => parseCellId(cell.cellId) === null)
    unresolvedOnly.forEach((cell, idx) => {
      const wanneer = Math.floor(idx / 9) % 3
      const waar = Math.floor(idx / 3) % 3
      const wat = idx % 3
      matrix[wanneer][waar][wat] += cell.totalResidue
      fallbackMap.set(cell.cellId, { wat, waar, wanneer })
    })

    const emergence = new Set<string>()
    for (const cellId of emergenceCellIds) {
      const parsed = parseCellId(cellId) ?? fallbackMap.get(cellId)
      if (parsed) emergence.add(positionKey(parsed))
    }

    return { residues: matrix, emergencePositions: emergence }
  }, [emergenceCellIds, heatmap])

  return (
    <div className="cube-heatmap">
      {LAYER_LABELS.map((label, layer) => (
        <div className="cube-layer" key={label}>
          <div className="cube-layer-label">{label}</div>
          {Array.from({ length: 9 }).map((_, index) => {
            const waar = Math.floor(index / 3)
            const wat = index % 3
            const residue = residues[layer][waar][wat]
            const coords = { wat, waar, wanneer: layer }
            const isEmergence = emergencePositions.has(positionKey(coords))
            return (
              <div
                className={`cube-cell ${isEmergence ? 'emergence' : ''}`.trim()}
                data-heat={heatLevel(residue)}
                key={`${label}-${waar}-${wat}`}
                title={`residue ${residue.toFixed(2)}`}
              />
            )
          })}
        </div>
      ))}
    </div>
  )
}
