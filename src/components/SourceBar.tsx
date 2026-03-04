import type { SourceStats } from '../api/radar'

type SourceBarProps = {
  sourceStats: SourceStats[]
}

type SourceState = 'active' | 'stale' | 'inactive'

function sourceState(lastFetch: string): SourceState {
  const t = Date.parse(lastFetch)
  if (Number.isNaN(t)) return 'inactive'
  const deltaMs = Date.now() - t
  const minutes = deltaMs / 60000
  if (minutes <= 30) return 'active'
  if (minutes <= 180) return 'stale'
  return 'inactive'
}

export function SourceBar({ sourceStats }: SourceBarProps) {
  const sorted = [...sourceStats].sort((a, b) => a.source.localeCompare(b.source))

  if (sorted.length === 0) return null

  return (
    <div className="source-bar">
      {sorted.map((src) => {
        const status = sourceState(src.lastFetch)
        return (
          <div className="source-badge" key={src.source}>
            <span className={`dot ${status}`} />
            <span>{src.source}</span>
          </div>
        )
      })}
    </div>
  )
}
