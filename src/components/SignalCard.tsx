import type { Activation } from '../api/radar'

type SignalCardProps = {
  activation: Activation
}

export function SignalCard({ activation }: SignalCardProps) {
  const source = activation.signal.source || 'unknown'
  const title = activation.signal.title || 'Onbekend signaal'
  const residue = Number.isFinite(activation.residue) ? activation.residue.toFixed(2) : '0.00'
  const clusters = [...activation.clusters]
    .sort((a, b) => {
      if (a.count !== b.count) return b.count - a.count
      return a.label.localeCompare(b.label)
    })
    .slice(0, 3)
    .map((cluster) => cluster.label)

  return (
    <article className="signal-card">
      <div className="signal-source">{source}</div>
      <div className="signal-title">{title}</div>
      <div className="signal-residue">residue {residue}</div>
      {clusters.length > 0 ? <div className="signal-clusters">{clusters.join(' · ')}</div> : null}
    </article>
  )
}
