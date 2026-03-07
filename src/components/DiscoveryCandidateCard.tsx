import type { DiscoveryCandidate } from '../api/radar'

type DiscoveryCandidateCardProps = {
  candidate: DiscoveryCandidate
}

export function DiscoveryCandidateCard({ candidate }: DiscoveryCandidateCardProps) {
  return (
    <article className="discovery-candidate-card">
      <div className="header">
        <span className="type">{candidate.candidateType.replace(/_/g, ' ')}</span>
        <span className="score">score {candidate.candidateScore.toFixed(2)}</span>
        {candidate.crossDomain ? <span className="cross-domain">cross-domain</span> : null}
        <span className="rank">#{candidate.rank}</span>
      </div>
      {candidate.explanation ? <div className="explanation">{candidate.explanation}</div> : null}
      {candidate.sources.length > 0 ? (
        <div className="sources">{candidate.sources.join(', ')}</div>
      ) : null}
    </article>
  )
}
