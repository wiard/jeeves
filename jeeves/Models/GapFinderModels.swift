import Foundation

// MARK: - Gap Finder Display Models

/// A single discovery item derived from gap finder analysis,
/// combining match/gap data for operator-facing display.
struct GapFinderDiscoveryItem: Identifiable {
    enum Kind: String {
        case overlap
        case gap
        case emerging
    }

    let id: String
    let kind: Kind
    let title: String
    let domains: [String]
    let explanation: String
    let score: Double
    let suggestedQuestion: String?
    let entropyNote: String?
    let evidenceCount: Int

    /// Derive discovery items from a SystemGapFinderSnapshot.
    static func from(snapshot: SystemGapFinderSnapshot) -> [GapFinderDiscoveryItem] {
        var items: [GapFinderDiscoveryItem] = []

        for match in snapshot.topMatches {
            items.append(GapFinderDiscoveryItem(
                id: match.matchId,
                kind: match.strengthScore >= 0.68 ? .emerging : .overlap,
                title: match.involvedDomains.prefix(2)
                    .map { $0.replacingOccurrences(of: "-", with: " ").capitalized }
                    .joined(separator: " x "),
                domains: match.involvedDomains,
                explanation: match.explanation,
                score: match.strengthScore,
                suggestedQuestion: nil,
                entropyNote: match.entropyRelation == "contradiction"
                    ? "Entropy directions diverge across these domains."
                    : nil,
                evidenceCount: match.evidenceRefs.count
            ))
        }

        for gap in snapshot.topGaps {
            items.append(GapFinderDiscoveryItem(
                id: gap.gapId,
                kind: .gap,
                title: gap.title,
                domains: gap.involvedDomains,
                explanation: gap.whyGap,
                score: gap.score,
                suggestedQuestion: gap.suggestedQuestion,
                entropyNote: gap.entropyNote,
                evidenceCount: gap.evidenceRefs.count
            ))
        }

        return items.sorted { $0.score > $1.score }
    }
}

/// A candidate knowledge structure — a gap or overlap that has enough
/// cross-domain evidence to potentially become structured knowledge
/// after human review.
struct GapFinderCandidateStructure: Identifiable {
    let id: String
    let title: String
    let domains: [String]
    let sharedMethods: [String]
    let sharedCauses: [String]
    let sharedEffects: [String]
    let structureStrength: Double
    let question: String
    let evidenceCount: Int

    /// Extract candidate structures from gaps with high enough scores.
    static func from(snapshot: SystemGapFinderSnapshot) -> [GapFinderCandidateStructure] {
        snapshot.topGaps
            .filter { $0.score >= 0.5 }
            .map { gap in
                GapFinderCandidateStructure(
                    id: gap.gapId,
                    title: gap.title,
                    domains: gap.involvedDomains,
                    sharedMethods: gap.sharedMethods,
                    sharedCauses: gap.sharedCauses,
                    sharedEffects: gap.sharedEffects,
                    structureStrength: gap.score,
                    question: gap.suggestedQuestion,
                    evidenceCount: gap.evidenceRefs.count
                )
            }
    }
}

/// Summary stats for gap finder display in compact panels.
struct GapFinderStats {
    let matchCount: Int
    let gapCount: Int
    let fingerprintCount: Int
    let emergingCount: Int
    let entropyConflicts: Int

    static func from(snapshot: SystemGapFinderSnapshot) -> GapFinderStats {
        GapFinderStats(
            matchCount: snapshot.counts.matches,
            gapCount: snapshot.counts.gaps,
            fingerprintCount: snapshot.counts.fingerprints,
            emergingCount: snapshot.topMatches.filter { $0.strengthScore >= 0.68 }.count,
            entropyConflicts: snapshot.topMatches.filter { $0.entropyRelation == "contradiction" }.count
        )
    }

    static let empty = GapFinderStats(
        matchCount: 0,
        gapCount: 0,
        fingerprintCount: 0,
        emergingCount: 0,
        entropyConflicts: 0
    )
}
