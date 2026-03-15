import Foundation
import SwiftUI

struct PlanetaryPanel: View {
    let title: String
    let accent: Color
    let snapshot: SystemPlanetarySnapshot

    private let columns = [
        GridItem(.flexible(minimum: 160), spacing: 14),
        GridItem(.flexible(minimum: 160), spacing: 14)
    ]

    private var focusLabel: String {
        if let risk = snapshot.planetaryRiskStructures.first?.regions.first {
            return humanize(risk)
        }
        if let field = snapshot.longHorizonResearchFields.first?.domain {
            return humanize(field)
        }
        if let action = snapshot.trustedActionTemplates.first?.actionType {
            return humanize(action)
        }
        return "Planetary relevance"
    }

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: "Planetary",
            title: title,
            subtitle: "The planetary layer shows what has become cross-region and cross-domain enough to matter globally, while keeping governance local, explicit, and human-led.",
            accent: accent,
            metric: focusLabel
        ) {
            summaryCard

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                rankedCard(
                    title: "What is becoming globally important",
                    subtitle: "Cross-region structures that now matter beyond one locale or institution.",
                    tint: .jeevesSky,
                    rows: snapshot.planetaryRiskStructures.prefix(3).map { entry in
                        RankedPlanetaryRow(
                            title: humanize(entry.signalFamily),
                            detail: "\(humanize(entry.regions.joined(separator: ", "))) · \(formatPercent(entry.persistence)) persistence",
                            explanation: entry.explanation,
                            weight: entry.persistence
                        )
                    }
                )

                rankedCard(
                    title: "Globally trusted templates",
                    subtitle: "Bounded actions that proved useful across multiple regional contexts.",
                    tint: .jeevesGold,
                    rows: snapshot.trustedActionTemplates.prefix(3).map { entry in
                        RankedPlanetaryRow(
                            title: humanize(entry.actionType),
                            detail: "\(entry.receiptCount) receipts · \(formatPercent(entry.crossRegionUsefulness)) cross-region usefulness",
                            explanation: entry.explanation,
                            weight: entry.crossRegionUsefulness
                        )
                    }
                )
            }

            trendCard
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planetary visibility".uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(accent)

            Text(focusLabel)
                .font(.jeevesHeadline)
                .foregroundStyle(.primary)

            Text("This stays visible because governed history now shows the same structure persisting across regions or domains, without turning that pattern into autonomous authority.")
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }

    private var trendCard: some View {
        let field = snapshot.crossRegionKnowledgeFields.first
        let infrastructure = snapshot.globalInfrastructurePatterns.first
        let bottleneck = snapshot.planetaryCoordinationBottlenecks.first
        let resilience = snapshot.resilienceGradients.first

        return VStack(alignment: .leading, spacing: 12) {
            Text("Where human attention is needed".uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(Color.jeevesMint)

            if let field {
                planetaryTrendRow(
                    title: "Cross-region field",
                    value: humanize(field.regions.joined(separator: ", ")),
                    detail: "\(formatPercent(field.knowledgeWeight)) knowledge weight · \(formatPercent(field.persistence)) persistence",
                    explanation: field.explanation
                )
            }

            if let infrastructure {
                planetaryTrendRow(
                    title: "Infrastructure echo",
                    value: humanize(infrastructure.infrastructureType),
                    detail: "\(humanize(infrastructure.regions.joined(separator: ", "))) · \(infrastructure.recurrence) recurrences",
                    explanation: infrastructure.explanation
                )
            }

            if let bottleneck {
                planetaryTrendRow(
                    title: "Coordination bottleneck",
                    value: humanize(bottleneck.patternType),
                    detail: "\(humanize(bottleneck.regions.joined(separator: ", "))) · \(bottleneck.recurrence) recurrences",
                    explanation: bottleneck.explanation
                )
            }

            if let resilience {
                planetaryTrendRow(
                    title: "Resilience gradient",
                    value: humanize(resilience.regionGroup.joined(separator: ", ")),
                    detail: "\(formatPercent(resilience.resilienceScore)) resilience score",
                    explanation: resilience.explanation
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
        rows: [RankedPlanetaryRow]
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
                Text("No planetary layer is visible here yet.")
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

    private func planetaryTrendRow(title: String, value: String, detail: String, explanation: String) -> some View {
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

private struct RankedPlanetaryRow {
    let title: String
    let detail: String
    let explanation: String
    let weight: Double
}
