import Foundation
import SwiftUI

struct CivilizationPanel: View {
    let title: String
    let accent: Color
    let snapshot: SystemCivilizationSnapshot

    private let columns = [
        GridItem(.flexible(minimum: 160), spacing: 14),
        GridItem(.flexible(minimum: 160), spacing: 14)
    ]

    private var focusLabel: String {
        if let zone = snapshot.durableKnowledgeZones.first?.region {
            return humanize(zone)
        }
        if let action = snapshot.trustedActionTemplates.first?.actionType {
            return humanize(action)
        }
        if let field = snapshot.longHorizonResearchFields.first?.domain {
            return humanize(field)
        }
        return "Shared structure"
    }

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: "Civilization",
            title: title,
            subtitle: "Civilization is the durable layer of governed knowledge: structures that stayed useful long enough to matter beyond the moment, while authority still remains human and explicit.",
            accent: accent,
            metric: focusLabel
        ) {
            summaryCard

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                rankedCard(
                    title: "What has become durable",
                    subtitle: "Regions where governed interaction kept producing stable knowledge and lowered uncertainty.",
                    tint: .jeevesSky,
                    rows: snapshot.durableKnowledgeZones.prefix(3).map { zone in
                        RankedCivilizationRow(
                            title: humanize(zone.region),
                            detail: "\(formatPercent(zone.knowledgeWeight)) knowledge weight · \(formatPercent(zone.persistence)) persistence",
                            explanation: zone.explanation,
                            weight: zone.persistence
                        )
                    }
                )

                rankedCard(
                    title: "Trusted action templates",
                    subtitle: "Bounded actions that repeatedly led to attributable useful outcomes.",
                    tint: .jeevesGold,
                    rows: snapshot.trustedActionTemplates.prefix(3).map { template in
                        RankedCivilizationRow(
                            title: humanize(template.actionType),
                            detail: "\(template.receiptCount) receipts · \(formatPercent(template.boundedUsefulness)) usefulness",
                            explanation: template.explanation,
                            weight: template.boundedUsefulness
                        )
                    }
                )
            }

            trendCard
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Civic visibility".uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(accent)

            Text(focusLabel)
                .font(.jeevesHeadline)
                .foregroundStyle(.primary)

            Text("This layer stays visible because the system has seen the same governed structures prove useful often enough to matter beyond a single incident.")
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }

    private var trendCard: some View {
        let civicRisk = snapshot.civicRiskStructures.first
        let pattern = snapshot.recurringCoordinationPatterns.first
        let research = snapshot.longHorizonResearchFields.first
        let resilience = snapshot.resilienceStructures.first

        return VStack(alignment: .leading, spacing: 12) {
            Text("Why this should remain visible".uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(Color.jeevesMint)

            if let civicRisk {
                civilizationTrendRow(
                    title: "Civic risk structure",
                    value: humanize(civicRisk.region),
                    detail: "\(humanize(civicRisk.signalFamily)) · \(civicRisk.linkedResidueCount) residue links · \(formatPercent(civicRisk.persistence)) persistence",
                    explanation: civicRisk.explanation
                )
            }

            if let pattern {
                civilizationTrendRow(
                    title: "Coordination pattern",
                    value: humanize(pattern.patternType),
                    detail: "\(pattern.recurrence) recurrences",
                    explanation: pattern.explanation
                )
            }

            if let research {
                civilizationTrendRow(
                    title: "Long-horizon field",
                    value: humanize(research.domain),
                    detail: "\(formatPercent(research.persistence)) persistence · \(formatPercent(research.crossDomainStrength)) cross-domain strength",
                    explanation: research.explanation
                )
            }

            if let resilience {
                civilizationTrendRow(
                    title: "Resilience structure",
                    value: humanize(resilience.region),
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
        rows: [RankedCivilizationRow]
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
                Text("No durable civilization layer is visible here yet.")
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

    private func civilizationTrendRow(title: String, value: String, detail: String, explanation: String) -> some View {
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
            .split(separator: " ")
            .flatMap { $0.split(separator: "_") }
            .flatMap { $0.split(separator: "-") }
            .flatMap { $0.split(separator: ".") }
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func formatPercent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct RankedCivilizationRow {
    let title: String
    let detail: String
    let explanation: String
    let weight: Double
}
