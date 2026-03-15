import Foundation
import SwiftUI

struct CosmicPanel: View {
    let title: String
    let accent: Color
    let snapshot: SystemCosmicSnapshot

    private let columns = [
        GridItem(.flexible(minimum: 160), spacing: 14),
        GridItem(.flexible(minimum: 160), spacing: 14)
    ]

    private var focusLabel: String {
        if let question = snapshot.enduringHumanQuestions.first?.theme {
            return humanize(question)
        }
        if let field = snapshot.longHorizonKnowledgeFields.first?.domain {
            return humanize(field)
        }
        if let frontier = snapshot.recurringExplorationFrontiers.first?.frontier {
            return humanize(frontier)
        }
        return "Long-horizon meaning"
    }

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: "Cosmic",
            title: title,
            subtitle: "The cosmic layer keeps long-horizon meaning visible without turning significance into authority. It stays humble, inspectable, and grounded in governed history.",
            accent: accent,
            metric: focusLabel
        ) {
            summaryCard

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                rankedCard(
                    title: "Enduring questions",
                    subtitle: "Themes that keep returning across knowledge, residue, and governed discovery.",
                    tint: .jeevesGold,
                    rows: snapshot.enduringHumanQuestions.prefix(3).map { entry in
                        RankedCosmicRow(
                            title: humanize(entry.theme),
                            detail: "\(entry.linkedKnowledgeCount) linked knowledge objects · \(formatPercent(entry.persistence)) persistence",
                            explanation: entry.explanation,
                            weight: entry.persistence
                        )
                    }
                )

                rankedCard(
                    title: "Future-significance signals",
                    subtitle: "Signals that keep widening in relevance without becoming directives.",
                    tint: .jeevesMint,
                    rows: snapshot.futureSignificanceSignals.prefix(3).map { entry in
                        RankedCosmicRow(
                            title: humanize(entry.signalFamily),
                            detail: "\(formatPercent(entry.longHorizonScore)) long-horizon score · \(formatPercent(1 - entry.uncertainty)) confidence",
                            explanation: entry.explanation,
                            weight: entry.longHorizonScore
                        )
                    }
                )
            }

            stewardshipCard
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cosmic orientation".uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(accent)

            Text(focusLabel)
                .font(.jeevesHeadline)
                .foregroundStyle(.primary)

            Text("This layer keeps possible long-horizon significance visible in calm language. It remains reconstructible from governed history and never expands authority on its own.")
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }

    private var stewardshipCard: some View {
        let field = snapshot.longHorizonKnowledgeFields.first
        let resilience = snapshot.deepResilienceStructures.first
        let truth = snapshot.truthPreservingStructures.first
        let bridge = snapshot.civilizationToPlanetaryBridges.first

        return VStack(alignment: .leading, spacing: 12) {
            Text("Why human stewardship remains central".uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(Color.jeevesMint)

            if let field {
                cosmicTrendRow(
                    title: "Long-horizon field",
                    value: humanize(field.domain),
                    detail: "\(formatPercent(field.persistence)) persistence · \(formatPercent(field.crossDomainStrength)) cross-domain strength",
                    explanation: field.explanation
                )
            }

            if let resilience {
                cosmicTrendRow(
                    title: "Deep resilience",
                    value: humanize(resilience.structureType),
                    detail: "\(formatPercent(resilience.persistence)) persistence · \(formatPercent(resilience.usefulnessScore)) usefulness",
                    explanation: resilience.explanation
                )
            }

            if let truth {
                cosmicTrendRow(
                    title: "Truth-preserving structure",
                    value: humanize(truth.structureType),
                    detail: "\(formatPercent(truth.trustWeight)) trust weight · \(formatPercent(truth.provenanceDepth)) provenance depth",
                    explanation: truth.explanation
                )
            }

            if let bridge {
                cosmicTrendRow(
                    title: "Civilization to planetary bridge",
                    value: humanize(bridge.bridgeType),
                    detail: "\(bridge.recurrence) recurrences · \(formatPercent(bridge.significance)) significance",
                    explanation: bridge.explanation
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }

    private func rankedCard(
        title: String,
        subtitle: String,
        tint: Color,
        rows: [RankedCosmicRow]
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
                Text("No long-horizon meaning is visible here yet.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.element.title) { index, row in
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

    private func cosmicTrendRow(title: String, value: String, detail: String, explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(Color.jeevesMint)

            Text(value)
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(.primary)

            Text(detail)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)

            Text(explanation)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func humanize(_ value: String) -> String {
        value
            .split(separator: ",")
            .map { component in
                component
                    .split(separator: " ")
                    .flatMap { $0.split(separator: "_") }
                    .flatMap { $0.split(separator: "-") }
                    .flatMap { $0.split(separator: ".") }
                    .map { $0.capitalized }
                    .joined(separator: " ")
            }
            .joined(separator: ", ")
    }

    private func formatPercent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct RankedCosmicRow {
    let title: String
    let detail: String
    let explanation: String
    let weight: Double
}
