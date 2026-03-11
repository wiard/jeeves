import Foundation

struct MissionControlTrustSnapshot: Sendable {
    let attestationCount: Int
    let attestations: [MissionControlAttestation]
    let capabilityStatuses: [MissionControlCapabilityStatus]
    let operatorNote: String?
    let isPlaceholder: Bool

    static let placeholder = MissionControlTrustSnapshot(
        attestationCount: 0,
        attestations: [],
        capabilityStatuses: [],
        operatorNote: "SafeClash trust data is not available yet. Showing a read-only placeholder.",
        isPlaceholder: true
    )

    static let mock = MissionControlTrustSnapshot(
        attestationCount: 3,
        attestations: [
            MissionControlAttestation(
                id: "mock-attestation-1",
                title: "Certified research synthesis",
                detail: "Level A2 · deploy ready",
                certificateId: "cert-research-001"
            ),
            MissionControlAttestation(
                id: "mock-attestation-2",
                title: "Governed evidence summarizer",
                detail: "Level A1 · bounded output",
                certificateId: "cert-evidence-014"
            ),
            MissionControlAttestation(
                id: "mock-attestation-3",
                title: "Operator logbook classifier",
                detail: "Level B1 · review only",
                certificateId: "cert-logbook-021"
            )
        ],
        capabilityStatuses: [
            MissionControlCapabilityStatus(id: "research", title: "Research", detail: "2 certified configurations", emphasis: "ready"),
            MissionControlCapabilityStatus(id: "evidence", title: "Evidence", detail: "2 certified configurations", emphasis: "ready"),
            MissionControlCapabilityStatus(id: "audit", title: "Audit", detail: "1 certified configuration", emphasis: "watch")
        ],
        operatorNote: "Mock trust snapshot. SafeClash remains read-only from the Jeeves cockpit.",
        isPlaceholder: false
    )
}

struct MissionControlAttestation: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let certificateId: String?
}

struct MissionControlCapabilityStatus: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let emphasis: String
}

struct MissionControlDiscoveryCube: Sendable {
    let cells: [MissionControlCubeCellState]
    let topCellIndex: Int?
    let topZoneSummary: String
    let topZoneDetail: String
    let isPlaceholder: Bool

    var topCell: MissionControlCubeCellState? {
        guard let topCellIndex else { return nil }
        return cells.first { $0.index == topCellIndex }
    }

    var planes: [MissionControlCubePlane] {
        stride(from: 2, through: 0, by: -1).map { z in
            MissionControlCubePlane(
                z: z,
                title: String(format: "Plane %02d", z + 1),
                cells: cells.filter { $0.position.z == z }.sorted { lhs, rhs in
                    if lhs.position.y == rhs.position.y {
                        return lhs.position.x < rhs.position.x
                    }
                    return lhs.position.y < rhs.position.y
                }
            )
        }
    }

    var activeCellCount: Int {
        cells.filter(\.isActive).count
    }

    static func derive(
        topSignal: RadarTopSignal?,
        radarStatus: RadarStatusSnapshot?,
        collisions: [RadarCollision],
        emergence: [RadarCollision],
        hotspots: [RadarGravityHotspot],
        activations: [RadarActivation],
        discoveries: [RadarDiscoveryCandidate],
        knowledgeStatus: KnowledgeStatus?,
        pendingGapCount: Int
    ) -> MissionControlDiscoveryCube {
        var accumulators = (0..<27).map { index in
            DiscoveryAccumulator(index: index, position: position(for: index))
        }

        for hotspot in hotspots {
            guard let index = normalizedIndex(for: hotspot.cell) else { continue }
            accumulators[index].gravityScore = max(accumulators[index].gravityScore, hotspot.gravityScore)
            accumulators[index].hotspotBand = hotspot.band
            accumulators[index].contributors.formUnion(hotspot.contributors)
            if !hotspot.explanation.isEmpty && accumulators[index].note == nil {
                accumulators[index].note = hotspot.explanation
            }
        }

        for activation in activations {
            let indices = cellIndices(from: activation.cellIds)
            for index in indices {
                accumulators[index].residue += activation.residue
                accumulators[index].persistence += 1
                accumulators[index].sources.insert(activation.source)
                if accumulators[index].note == nil {
                    accumulators[index].note = activation.summary.isEmpty ? activation.title : activation.summary
                }
            }
        }

        for collision in collisions {
            let indices = cellIndices(from: collision.cellIds)
            for index in indices {
                accumulators[index].collisionCount += 1
                accumulators[index].collisionDensity = max(accumulators[index].collisionDensity, collision.density)
                accumulators[index].sources.formUnion(collision.sources)
                if accumulators[index].note == nil {
                    accumulators[index].note = collision.signalTitles.first
                }
            }
        }

        for event in emergence {
            let indices = cellIndices(from: event.cellIds)
            for index in indices {
                accumulators[index].emergenceCount += 1
                accumulators[index].collisionDensity = max(accumulators[index].collisionDensity, event.density)
                accumulators[index].sources.formUnion(event.sources)
                if accumulators[index].note == nil {
                    accumulators[index].note = event.signalTitles.first
                }
            }
        }

        let aggregateCollisionCount = max(radarStatus?.store?.collisionCount ?? 0, collisions.count)
        let aggregateEmergenceCount = max(radarStatus?.store?.emergenceCount ?? 0, emergence.count)
        let aggregateGapCount = max(discoveries.count, pendingGapCount)

        applyDerivedCoverage(
            to: &accumulators,
            currentValue: accumulators.reduce(0) { $0 + $1.collisionCount },
            targetCount: aggregateCollisionCount,
            indices: [13, 14, 10, 16, 12, 4, 22, 1, 25]
        ) { accumulator, order in
            accumulator.collisionCount += 1
            accumulator.collisionDensity = max(accumulator.collisionDensity, 0.62 - (Double(order) * 0.06))
            accumulator.note = accumulator.note ?? "Derived collision pressure from radar aggregate counts."
            accumulator.isDerived = true
        }

        applyDerivedCoverage(
            to: &accumulators,
            currentValue: accumulators.reduce(0) { $0 + $1.emergenceCount },
            targetCount: aggregateEmergenceCount,
            indices: [13, 14, 10, 16, 4, 22]
        ) { accumulator, order in
            accumulator.emergenceCount += 1
            accumulator.collisionDensity = max(accumulator.collisionDensity, 0.72 - (Double(order) * 0.07))
            accumulator.note = accumulator.note ?? "Derived emergence focus from radar aggregate counts."
            accumulator.isDerived = true
        }

        let preferredGapCells = preferredGapIndices(
            accumulators: accumulators,
            knowledgeStatus: knowledgeStatus
        )

        for (offset, candidate) in discoveries.prefix(6).enumerated() {
            guard let index = preferredGapCells[safe: offset] else { break }
            accumulators[index].gapCandidateCount += 1
            if accumulators[index].gapFocusRank == nil || candidate.rank < (accumulators[index].gapFocusRank ?? Int.max) {
                accumulators[index].gapFocusRank = candidate.rank == 0 ? offset + 1 : candidate.rank
            }
            accumulators[index].sources.formUnion(candidate.sources)
            accumulators[index].note = accumulators[index].note ?? candidate.explanation
        }

        applyDerivedCoverage(
            to: &accumulators,
            currentValue: accumulators.filter { $0.gapCandidateCount > 0 || $0.gapFocusRank != nil }.count,
            targetCount: aggregateGapCount,
            indices: preferredGapCells
        ) { accumulator, order in
            accumulator.gapCandidateCount = max(accumulator.gapCandidateCount, 1)
            accumulator.gapFocusRank = accumulator.gapFocusRank ?? (order + 1)
            accumulator.note = accumulator.note ?? "Derived gap focus while awaiting explicit cube placement from CLASHD27."
            accumulator.isDerived = true
        }

        if let topSignal {
            let targetIndex = preferredGapCells.first ?? 13
            if accumulators.allSatisfy({ $0.residue <= 0 }) {
                accumulators[targetIndex].residue = max(accumulators[targetIndex].residue, topSignal.residue)
                accumulators[targetIndex].persistence = max(accumulators[targetIndex].persistence, 1)
                accumulators[targetIndex].sources.insert(topSignal.source)
                accumulators[targetIndex].note = accumulators[targetIndex].note ?? topSignal.title
                accumulators[targetIndex].isDerived = true
            }
        }

        let maxCollisionDensity = max(accumulators.map(\.collisionDensity).max() ?? 0, 1)
        let maxGravityScore = max(accumulators.map(\.gravityScore).max() ?? 0, 1)
        let maxResidue = max(accumulators.map(\.residue).max() ?? topSignal?.residue ?? 0, 1)
        let maxPersistence = max(accumulators.map(\.persistence).max() ?? 0, 1)

        let provisionalCells = accumulators.map { accumulator in
            MissionControlCubeCellState(
                index: accumulator.index,
                position: accumulator.position,
                collisionCount: accumulator.collisionCount,
                emergenceCount: accumulator.emergenceCount,
                gravityScore: accumulator.gravityScore,
                residue: accumulator.residue,
                persistence: accumulator.persistence,
                gapCandidateCount: accumulator.gapCandidateCount,
                gapFocusRank: accumulator.gapFocusRank,
                hotspotBand: accumulator.hotspotBand,
                contributorCount: accumulator.contributors.count,
                sourceCount: accumulator.sources.count,
                pressure: pressure(
                    for: accumulator,
                    maxCollisionDensity: maxCollisionDensity,
                    maxGravityScore: maxGravityScore,
                    maxResidue: maxResidue,
                    maxPersistence: maxPersistence
                ),
                isTopCell: false,
                isPlaceholder: accumulator.isDerived,
                note: accumulator.note
            )
        }

        let sortedTopCells = provisionalCells.sorted { lhs, rhs in
            if lhs.pressure == rhs.pressure {
                if lhs.emergenceCount == rhs.emergenceCount {
                    if lhs.gapCandidateCount == rhs.gapCandidateCount {
                        return lhs.index < rhs.index
                    }
                    return lhs.gapCandidateCount > rhs.gapCandidateCount
                }
                return lhs.emergenceCount > rhs.emergenceCount
            }
            return lhs.pressure > rhs.pressure
        }

        let topCell = sortedTopCells.first(where: \.isActive)
        let cells = provisionalCells.map { cell in
            MissionControlCubeCellState(
                index: cell.index,
                position: cell.position,
                collisionCount: cell.collisionCount,
                emergenceCount: cell.emergenceCount,
                gravityScore: cell.gravityScore,
                residue: cell.residue,
                persistence: cell.persistence,
                gapCandidateCount: cell.gapCandidateCount,
                gapFocusRank: cell.gapFocusRank,
                hotspotBand: cell.hotspotBand,
                contributorCount: cell.contributorCount,
                sourceCount: cell.sourceCount,
                pressure: cell.pressure,
                isTopCell: cell.index == topCell?.index,
                isPlaceholder: cell.isPlaceholder,
                note: cell.note
            )
        }

        let topSummary: String
        let topDetail: String
        if let topCell {
            topSummary = "Top discovery zone \(topCell.coordinateLabel)"
            topDetail = zoneDetail(for: topCell, topSignal: topSignal)
        } else if let topSignal {
            topSummary = "Top discovery zone pending placement"
            topDetail = "\(topSignal.title) is visible from \(topSignal.source), but CLASHD27 has not attached it to a cube cell yet."
        } else {
            topSummary = "Cube standing by"
            topDetail = "The 27-cell shell is visible, but CLASHD27 has not surfaced enough localized pressure to rank a discovery zone."
        }

        return MissionControlDiscoveryCube(
            cells: cells,
            topCellIndex: topCell?.index,
            topZoneSummary: topSummary,
            topZoneDetail: topDetail,
            isPlaceholder: cells.allSatisfy { !$0.isActive || $0.isPlaceholder }
        )
    }

    private static func preferredGapIndices(
        accumulators: [DiscoveryAccumulator],
        knowledgeStatus: KnowledgeStatus?
    ) -> [Int] {
        var ordered: [Int] = accumulators
            .sorted { lhs, rhs in
                let leftScore = lhs.gravityScore + lhs.collisionDensity + lhs.residue
                let rightScore = rhs.gravityScore + rhs.collisionDensity + rhs.residue
                if leftScore == rightScore {
                    return lhs.index < rhs.index
                }
                return leftScore > rightScore
            }
            .map(\.index)

        let knowledge = (knowledgeStatus?.topCubeCells ?? []).compactMap(parseCellReference)
        ordered.insert(contentsOf: knowledge, at: 0)
        ordered.insert(contentsOf: [13, 14, 10, 16, 12, 4, 22, 1, 25], at: 0)
        return unique(ordered)
    }

    private static func applyDerivedCoverage(
        to accumulators: inout [DiscoveryAccumulator],
        currentValue: Int,
        targetCount: Int,
        indices: [Int],
        update: (inout DiscoveryAccumulator, Int) -> Void
    ) {
        guard targetCount > currentValue else { return }
        let needed = min(targetCount - currentValue, indices.count)
        for order in 0..<needed {
            let index = indices[order]
            guard accumulators.indices.contains(index) else { continue }
            update(&accumulators[index], order)
        }
    }

    private static func pressure(
        for accumulator: DiscoveryAccumulator,
        maxCollisionDensity: Double,
        maxGravityScore: Double,
        maxResidue: Double,
        maxPersistence: Int
    ) -> Double {
        let collision = accumulator.collisionDensity / maxCollisionDensity
        let gravity = accumulator.gravityScore / maxGravityScore
        let residue = accumulator.residue / maxResidue
        let persistence = Double(accumulator.persistence) / Double(maxPersistence)
        let emergence = accumulator.emergenceCount > 0 ? 1.0 : 0.0
        let gap = accumulator.gapCandidateCount > 0 ? 1.0 : 0.0
        let score = (collision * 0.28)
            + (gravity * 0.24)
            + (residue * 0.18)
            + (persistence * 0.12)
            + (emergence * 0.12)
            + (gap * 0.10)
        return min(max(score, 0), 1)
    }

    private static func zoneDetail(for cell: MissionControlCubeCellState, topSignal: RadarTopSignal?) -> String {
        var fragments: [String] = []
        if cell.hasCollision {
            fragments.append("\(cell.collisionCount) collision\(cell.collisionCount == 1 ? "" : "s")")
        }
        if cell.hasEmergence {
            fragments.append("\(cell.emergenceCount) emergence")
        }
        if cell.hasGravity {
            fragments.append("gravity \(String(format: "%.2f", cell.gravityScore))")
        }
        if cell.hasResidue {
            fragments.append("residue \(String(format: "%.2f", cell.residue))")
        }
        if cell.hasGapFocus {
            fragments.append("gap focus")
        }
        if fragments.isEmpty, let topSignal {
            return "\(topSignal.title) is the leading visible signal, but cell-level instrumentation is still sparse."
        }
        let headline = fragments.joined(separator: " · ")
        if let note = cell.note, !note.isEmpty {
            return headline + ". " + note
        }
        return headline.capitalized + "."
    }

    private static func position(for index: Int) -> CubePosition {
        CubePosition(x: index % 3, y: (index / 3) % 3, z: index / 9)
    }

    private static func normalizedIndex(for rawValue: Int) -> Int? {
        if (0..<27).contains(rawValue) {
            return rawValue
        }
        if (1...27).contains(rawValue) {
            return rawValue - 1
        }
        return nil
    }

    private static func cellIndices(from values: [String]) -> [Int] {
        unique(values.compactMap(parseCellReference))
    }

    private static func parseCellReference(_ rawValue: String) -> Int? {
        let normalized = rawValue
            .lowercased()
            .replacingOccurrences(of: "[^0-9]+", with: " ", options: .regularExpression)
            .split(separator: " ")
            .compactMap { Int($0) }

        if normalized.count >= 3 {
            let x = normalized[0]
            let y = normalized[1]
            let z = normalized[2]
            if (0...2).contains(x), (0...2).contains(y), (0...2).contains(z) {
                return x + (y * 3) + (z * 9)
            }
            if (1...3).contains(x), (1...3).contains(y), (1...3).contains(z) {
                return (x - 1) + ((y - 1) * 3) + ((z - 1) * 9)
            }
        }

        guard let first = normalized.first else { return nil }
        return normalizedIndex(for: first)
    }

    private static func unique(_ values: [Int]) -> [Int] {
        var seen: Set<Int> = []
        var result: [Int] = []
        for value in values where (0..<27).contains(value) {
            if seen.insert(value).inserted {
                result.append(value)
            }
        }
        return result
    }

    private struct DiscoveryAccumulator {
        let index: Int
        let position: CubePosition
        var collisionCount = 0
        var emergenceCount = 0
        var collisionDensity = 0.0
        var gravityScore = 0.0
        var residue = 0.0
        var persistence = 0
        var gapCandidateCount = 0
        var gapFocusRank: Int?
        var hotspotBand: String?
        var contributors: Set<String> = []
        var sources: Set<String> = []
        var isDerived = false
        var note: String?
    }
}

struct MissionControlCubePlane: Identifiable, Hashable, Sendable {
    let z: Int
    let title: String
    let cells: [MissionControlCubeCellState]

    var id: Int { z }
}

struct MissionControlCubeCellState: Identifiable, Hashable, Sendable {
    let index: Int
    let position: CubePosition
    let collisionCount: Int
    let emergenceCount: Int
    let gravityScore: Double
    let residue: Double
    let persistence: Int
    let gapCandidateCount: Int
    let gapFocusRank: Int?
    let hotspotBand: String?
    let contributorCount: Int
    let sourceCount: Int
    let pressure: Double
    let isTopCell: Bool
    let isPlaceholder: Bool
    let note: String?

    var id: Int { index }

    var hasCollision: Bool { collisionCount > 0 }
    var hasEmergence: Bool { emergenceCount > 0 }
    var hasGravity: Bool { gravityScore > 0.01 }
    var hasResidue: Bool { residue > 0.01 || persistence > 0 }
    var hasGapFocus: Bool { gapCandidateCount > 0 || gapFocusRank != nil }
    var isActive: Bool {
        hasCollision || hasEmergence || hasGravity || hasResidue || hasGapFocus || pressure > 0.08
    }

    var coordinateLabel: String {
        "C\(index + 1)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
