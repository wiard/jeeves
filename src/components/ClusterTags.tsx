type ClusterTagItem = {
  cluster: string
  label: string
  count: number
}

type ClusterTagsProps = {
  clusters: ClusterTagItem[]
}

export function ClusterTags({ clusters }: ClusterTagsProps) {
  const sorted = [...clusters]
    .sort((a, b) => {
      if (a.count !== b.count) return b.count - a.count
      return a.label.localeCompare(b.label)
    })
    .slice(0, 16)

  if (sorted.length === 0) {
    return (
      <div className="empty-state">
        <div className="message">Geen actieve clusters.</div>
      </div>
    )
  }

  return (
    <div className="cluster-tags">
      {sorted.map((cluster) => (
        <span className="cluster-tag" key={cluster.cluster}>
          {cluster.label}
          <span className="count">{cluster.count}</span>
        </span>
      ))}
    </div>
  )
}
