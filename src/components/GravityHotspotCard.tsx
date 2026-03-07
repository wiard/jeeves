import type { GravityHotspot } from '../api/radar'

type GravityHotspotCardProps = {
  hotspot: GravityHotspot
}

const BAND_COLORS: Record<string, string> = {
  red: 'var(--red)',
  yellow: 'var(--amber)',
  green: 'var(--green)',
  blue: 'var(--amber-dim)'
}

export function GravityHotspotCard({ hotspot }: GravityHotspotCardProps) {
  const bandColor = BAND_COLORS[hotspot.band] ?? 'var(--text-muted)'

  return (
    <article className="gravity-hotspot-card">
      <div className="band-indicator" style={{ backgroundColor: bandColor }} />
      <div className="content">
        <div className="header">
          <span className="cell-label">cell {hotspot.cell}</span>
          <span className="axes">{hotspot.axes.what}/{hotspot.axes.where}/{hotspot.axes.time}</span>
        </div>
        <div className="score">
          gravity {hotspot.gravityScore.toFixed(1)} · {hotspot.band} · #{hotspot.rank}
        </div>
        {hotspot.explanation ? <div className="explanation">{hotspot.explanation}</div> : null}
        {hotspot.contributors.length > 0 ? (
          <div className="contributors">{hotspot.contributors.join(', ')}</div>
        ) : null}
      </div>
    </article>
  )
}
