import type { PaperSignal } from '../api/radar'

type PaperSignalCardProps = {
  paper: PaperSignal
}

export function PaperSignalCard({ paper }: PaperSignalCardProps) {
  return (
    <article className="paper-signal-card">
      <div className="header">
        <span className="source-badge">{paper.paperSource}</span>
        <span className="topic-cluster">{paper.topicCluster}</span>
        <span className="quality">{paper.qualityTier}</span>
      </div>
      <div className="title">
        {paper.url ? (
          <a href={paper.url} target="_blank" rel="noopener noreferrer">{paper.title}</a>
        ) : (
          paper.title
        )}
      </div>
      <div className="meta">
        <span>{paper.semanticCategory}</span>
        <span>{paper.ageBucket}</span>
        <span>{paper.confidence}</span>
        {paper.cellIndex !== null ? <span>cell {paper.cellIndex}</span> : null}
      </div>
    </article>
  )
}
