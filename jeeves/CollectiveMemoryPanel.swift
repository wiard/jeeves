import Foundation
import SwiftUI

struct CollectiveMemoryPanel: View {
    let title: String
    let accent: Color
    let memory: SystemCollectiveMemorySnapshot

    private let columns = [
        GridItem(.flexible(minimum: 160), spacing: 14),
        GridItem(.flexible(minimum: 160), spacing: 14)
    ]

    private var focusLabel: String {
        if let region = memory.regionMemory.first?.region {
            return humanize(region)
        }
        if let signal = memory.signalFamilyMemory.first?.signalType {
            return humanize(signal)
        }
        if let pattern = memory.patternMemory.first?.patternType {
            return humanize(pattern)
        }
        return "Emerging"
    }

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: "Collective Memory",
            title: title,
            subtitle: "System memory is reconstructed from approvals, rejections, residue, knowledge, collisions, receipts, and entropy reduction. It explains what repeatedly became meaningful without changing authority.",
            accent: accent,
            metric: focusLabel
        ) {
            summaryCard

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                rankedCard(
                    title: "Regions that repeatedly mattered",
                    subtitle: "Places where governed activity kept producing residue and knowledge.",
                    tint: .jeevesSky,
                    rows: memory.regionMemory.prefix(3).map { entry in
                        RankedCollectiveMemoryRow(
                            title: humanize(entry.region),
                            detail: "\(entry.approvals) approvals · \(formatPercent(entry.residueStrength)) residue · \(entry.knowledgeCount) knowledge",
                            explanation: entry.explanation,
                            weight: entry.weight
                        )
                    }
                )

                rankedCard(
                    title: "Signal families with durable outcomes",
                    subtitle: "Families that often led to useful governed results.",
                    tint: .jeevesGold,
                    rows: memory.signalFamilyMemory.prefix(3).map { entry in
                        RankedCollectiveMemoryRow(
                            title: humanize(entry.signalType),
                            detail: "\(entry.approvals) approvals · \(entry.rejections) rejections · \(formatPercent(entry.usefulnessScore)) usefulness",
                            explanation: entry.explanation,
                            weight: entry.weight
                        )
                    }
                )
            }

            trendCard
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System memory".uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(accent)

            Text(focusLabel)
                .font(.jeevesHeadline)
                .foregroundStyle(.primary)

            Text("This is highlighted because governed activity kept turning similar interactions into attributable outcomes and durable knowledge.")
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }

    private var trendCard: some View {
        let collision = memory.collisionMemory.first
        let structure = memory.knowledgeStructureMemory.first
        let execution = memory.executionOutcomeMemory.first

        return VStack(alignment: .leading, spacing: 12) {
            Text("Why this matters now".uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(Color.jeevesMint)

            memoryTrendRow(
                title: "Average entropy reduction",
                value: formatEntropy(memory.entropyReductionMemory.averageEntropyReduction),
                detail: memory.entropyReductionMemory.strongestRegions.first.map { "Strongest region: \(humanize($0.region))" } ?? "No stable entropy-lowering region yet.",
                explanation: memory.entropyReductionMemory.strongestSignalFamilies.first?.explanation ?? "Collective memory is still forming."
            )

            if let collision {
                memoryTrendRow(
                    title: "Recurring collisions",
                    value: humanize(collision.cubeZone),
                    detail: "\(collision.recurrence) recurrences · \(formatPercent(collision.crossDomainStrength)) cross-domain strength",
                    explanation: collision.explanation
                )
            }

            if let structure {
                memoryTrendRow(
                    title: "Stable knowledge structures",
                    value: humanize(structure.structureType),
                    detail: "\(formatPercent(structure.persistence)) persistence · \(structure.linkedResidueCount) residue links",
                    explanation: structure.explanation
                )
            }

            if let execution {
                memoryTrendRow(
                    title: "Execution continuity",
                    value: humanize(execution.actionType),
                    detail: "\(execution.receiptCount) receipts · \(formatPercent(execution.outcomeQuality)) outcome quality",
                    explanation: execution.explanation
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
        rows: [RankedCollectiveMemoryRow]
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
                Text("No stable system memory is visible here yet.")
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

    private func memoryTrendRow(title: String, value: String, detail: String, explanation: String) -> some View {
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

    private func formatEntropy(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

private struct RankedCollectiveMemoryRow {
    let title: String
    let detail: String
    let explanation: String
    let weight: Double
}
