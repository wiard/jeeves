import SwiftUI

struct GapFinderPanel: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let accent: Color
    let snapshot: SystemGapFinderSnapshot

    private let columns = [
        GridItem(.flexible(minimum: 160), spacing: 14),
        GridItem(.flexible(minimum: 160), spacing: 14)
    ]

    private var focusLabel: String {
        snapshot.topGaps.first?.title ?? snapshot.topMatches.first?.involvedDomains.prefix(2).map(humanize).joined(separator: " x ") ?? "Watching"
    }

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            accent: accent,
            metric: focusLabel
        ) {
            summaryCard

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                overlapsCard
                gapsCard
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What is surfacing".uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(accent)

            Text("\(snapshot.counts.matches) overlaps · \(snapshot.counts.gaps) gap candidates")
                .font(.jeevesHeadline)
                .foregroundStyle(.primary)

            Text(summaryLine)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }

    private var overlapsCard: some View {
        rankedCard(
            title: "Cross-domain overlaps",
            subtitle: "The strongest explainable method, cause, effect, and entropy alignments.",
            tint: .jeevesSky,
            rows: snapshot.topMatches.prefix(3).map { match in
                GapFinderRow(
                    title: match.involvedDomains.prefix(2).map(humanize).joined(separator: " x "),
                    detail: detailLine(methods: match.sharedMethods, causes: match.sharedCauses, effects: match.sharedEffects),
                    explanation: "\(match.explanation) Pattern pressure: \(patternPressure(for: match)). Entropy: \(humanize(match.entropyRelation)).",
                    weight: match.strengthScore
                )
            },
            emptyText: "No strong cross-domain overlap is visible yet."
        )
    }

    private var gapsCard: some View {
        rankedCard(
            title: "Gap candidates",
            subtitle: "Promising bridge questions where overlap is strong but the explanation is still weak.",
            tint: .jeevesGold,
            rows: snapshot.topGaps.prefix(3).map { gap in
                GapFinderRow(
                    title: gap.title,
                    detail: gap.suggestedQuestion,
                    explanation: "\(gap.whyGap) \(gap.entropyNote)",
                    weight: gap.score
                )
            },
            emptyText: "No bridge-worthy gap candidate is visible yet."
        )
    }

    private func rankedCard(
        title: String,
        subtitle: String,
        tint: Color,
        rows: [GapFinderRow],
        emptyText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(tint)

            Text(subtitle)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if rows.isEmpty {
                Text(emptyText)
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.jeevesMonoSmall.weight(.semibold))
                                .foregroundStyle(tint)
                                .frame(width: 24, height: 24)
                                .background(tint.opacity(0.10))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.title)
                                    .font(.jeevesBody.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text(row.detail)
                                    .font(.jeevesCaption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(row.explanation)
                                    .font(.jeevesCaption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(tint.opacity(0.15))
                                    .overlay(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                                            .fill(tint)
                                            .frame(width: max(20, row.weight * 120), height: 6)
                                    }
                                    .frame(width: 120, height: 6)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }

    private func detailLine(methods: [String], causes: [String], effects: [String]) -> String {
        var parts: [String] = []
        if let method = methods.first {
            parts.append("Method overlap: \(humanize(method))")
        }
        if let cause = causes.first {
            parts.append("Cause pattern: \(humanize(cause))")
        }
        if let effect = effects.first {
            parts.append("Effect pattern: \(humanize(effect))")
        }
        return parts.joined(separator: " · ")
    }

    private var summaryLine: String {
        let entropyConflicts = snapshot.topMatches.filter { $0.entropyRelation == "contradiction" }.count
        let emergingPatterns = snapshot.topMatches.filter { $0.strengthScore >= 0.68 }.count
        return "Cross-domain matches: \(snapshot.counts.matches) · Gap candidates: \(snapshot.counts.gaps) · Emerging patterns: \(emergingPatterns) · Entropy conflicts: \(entropyConflicts)"
    }

    private func patternPressure(for match: SystemGapFinderMatch) -> String {
        switch match.strengthScore {
        case 0.8...:
            return "high"
        case 0.6..<0.8:
            return "rising"
        default:
            return "watching"
        }
    }

    private func humanize(_ value: String) -> String {
        value
            .split(separator: " ")
            .flatMap { $0.split(separator: "_") }
            .flatMap { $0.split(separator: "-") }
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

private struct GapFinderRow {
    let title: String
    let detail: String
    let explanation: String
    let weight: Double
}

// MARK: - Candidate Structure List

/// Shows gap-finder candidate structures that may become knowledge after human review.
/// SAFETY: This view is strictly observational — it displays candidates
/// but does NOT create proposals, trigger actions, or modify governance state.
struct CandidateStructureList: View {
    let candidates: [GapFinderCandidateStructure]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Candidate Knowledge Structures".uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(Color.jeevesSky)

            Text("Cross-domain evidence nearing structure. These candidates show where repeated signals may be strong enough to become future knowledge after human review.")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(candidates.prefix(4).enumerated()), id: \.element.id) { index, candidate in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.jeevesMonoSmall.weight(.semibold))
                            .foregroundStyle(Color.jeevesSky)
                            .frame(width: 24, height: 24)
                            .background(Color.jeevesSky.opacity(0.10))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(candidate.title)
                                .font(.jeevesBody.weight(.semibold))

                            Text(candidate.domains.map { $0.replacingOccurrences(of: "-", with: " ").capitalized }.joined(separator: " · "))
                                .font(.jeevesMonoSmall)
                                .foregroundStyle(Color.jeevesSky)

                            Text(candidate.question)
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 8) {
                                if !candidate.sharedMethods.isEmpty {
                                    Text("method: \(candidate.sharedMethods.first!)")
                                        .font(.jeevesMonoSmall)
                                        .foregroundStyle(.secondary)
                                }
                                Text("evidence: \(candidate.evidenceCount)")
                                    .font(.jeevesMonoSmall)
                                    .foregroundStyle(.secondary)
                            }

                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(Color.jeevesSky.opacity(0.15))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                                        .fill(Color.jeevesSky)
                                        .frame(width: max(20, candidate.structureStrength * 120), height: 6)
                                }
                                .frame(width: 120, height: 6)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }
}
