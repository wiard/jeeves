import { useMemo, useState, type TouchEventHandler } from 'react'
import type { Collision } from '../api/radar'

type EmergenceCardProps = {
  collision: Collision
  acknowledged: boolean
  onAcknowledge: (collisionId: string) => void
  onDismiss: (collisionId: string) => void
}

const SWIPE_THRESHOLD = 80

export function EmergenceCard({ collision, acknowledged, onAcknowledge, onDismiss }: EmergenceCardProps) {
  const [startX, setStartX] = useState<number | null>(null)
  const [deltaX, setDeltaX] = useState(0)
  const [dismissed, setDismissed] = useState(false)

  const title = useMemo(() => {
    const topSignals = collision.signals
      .slice()
      .sort((a, b) => a.title.localeCompare(b.title))
      .slice(0, 2)
      .map((signal) => signal.title)
    return topSignals.length > 0 ? topSignals.join(' × ') : collision.collisionId
  }, [collision.collisionId, collision.signals])

  const sources = useMemo(() => {
    return [...new Set(collision.sources)].sort().join(', ')
  }, [collision.sources])

  const cells = useMemo(() => {
    return collision.cells
      .map((cell) => cell.cellId)
      .sort()
      .join(', ')
  }, [collision.cells])

  const densityPct = Math.max(0, Math.min(100, Math.round(collision.density * 100)))

  const onTouchStart: TouchEventHandler<HTMLElement> = (event) => {
    setStartX(event.touches[0].clientX)
    setDeltaX(0)
  }

  const onTouchMove: TouchEventHandler<HTMLElement> = (event) => {
    if (startX === null) return
    setDeltaX(event.touches[0].clientX - startX)
  }

  const onTouchEnd: TouchEventHandler<HTMLElement> = () => {
    if (deltaX >= SWIPE_THRESHOLD) {
      onAcknowledge(collision.collisionId)
      setDeltaX(0)
      setStartX(null)
      return
    }

    if (deltaX <= -SWIPE_THRESHOLD) {
      setDismissed(true)
      window.setTimeout(() => onDismiss(collision.collisionId), 220)
      return
    }

    setDeltaX(0)
    setStartX(null)
  }

  const swipeClass = deltaX > 24 ? 'swiping-right' : deltaX < -24 ? 'swiping-left' : ''

  return (
    <article
      className={`emergence-card ${swipeClass} ${dismissed ? 'dismissed' : ''}`.trim()}
      style={{ transform: dismissed ? undefined : `translateX(${deltaX}px)` }}
      onTouchStart={onTouchStart}
      onTouchMove={onTouchMove}
      onTouchEnd={onTouchEnd}
    >
      <div className="title">{title}</div>
      <div className="sources">{sources} · {collision.density.toFixed(2)}</div>
      <div className="density-bar">
        <div className="density-fill" style={{ width: `${densityPct}%` }} />
      </div>
      <div className="cells">cells: {cells || '-'}</div>
      {acknowledged ? <div className="cells">gezien</div> : null}
    </article>
  )
}
