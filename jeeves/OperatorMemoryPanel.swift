import SwiftUI

struct OperatorMemoryPanel: View {
    let title: String
    let accent: Color
    let memory: SystemOperatorMemorySnapshot

    private let columns = [
        GridItem(.flexible(minimum: 160), spacing: 14),
        GridItem(.flexible(minimum: 160), spacing: 14)
    ]

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: "Operator Memory",
            title: title,
            subtitle: "Memory is reconstructed from governed approvals, rejections, residue, and knowledge links. It stays readable and never changes authority.",
            accent: accent,
            metric: humanize(memory.operatorFocusMemory.strongestFocus)
        ) {
            focusCard

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                rankedCard(
                    title: "Repeatedly important regions",
                    subtitle: "Places that kept returning in recent governed attention.",
                    tint: .jeevesSky,
                    rows: memory.regionMemory.prefix(3).map { entry in
                        RankedMemoryRow(
                            title: humanize(entry.region),
                            detail: "\(entry.recentApprovals) approvals · \(entry.recentAttention) touches",
                            explanation: entry.explanation,
                            weight: entry.weight
                        )
                    }
                )

                rankedCard(
                    title: "Recurring signal families",
                    subtitle: "Families that repeatedly mattered in earlier decisions.",
                    tint: .jeevesGold,
                    rows: memory.signalFamilyMemory.prefix(3).map { entry in
                        RankedMemoryRow(
                            title: humanize(entry.signalType),
                            detail: "\(entry.recentApprovals) approvals · \(entry.recentRejections) rejections · \(entry.linkedKnowledge) knowledge links",
                            explanation: entry.explanation,
                            weight: entry.weight
                        )
                    }
                )
            }

            trendCard
        }
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Remembered focus".uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(accent)

            Text(humanize(memory.operatorFocusMemory.strongestFocus))
                .font(.jeevesHeadline)
                .foregroundStyle(.primary)

            Text(memory.operatorFocusMemory.explanation)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }

    private var trendCard: some View {
        let pattern = memory.patternMemory.first
        let knowledge = memory.knowledgeMemory.first

        return VStack(alignment: .leading, spacing: 12) {
            Text("Attention trends".uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(Color.jeevesMint)

            if let pattern {
                memoryTrendRow(
                    title: "Pattern memory",
                    value: humanize(pattern.patternType),
                    detail: "\(pattern.recentApprovals) approvals · \(pattern.recurrence) recurrences",
                    explanation: pattern.explanation
                )
            }

            if let knowledge {
                memoryTrendRow(
                    title: "Knowledge memory",
                    value: humanize(knowledge.knowledgeKind),
                    detail: "\(knowledge.recentObjects) recent objects · \(knowledge.linkedApprovals) linked approvals",
                    explanation: knowledge.explanation
                )
            }

            if pattern == nil && knowledge == nil {
                Text("No stable operator memory trend is visible yet.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }

    private func rankedCard(
        title: String,
        subtitle: String,
        tint: Color,
        rows: [RankedMemoryRow]
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
                Text("No repeat memory is visible here yet.")
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
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

private struct RankedMemoryRow {
    let title: String
    let detail: String
    let explanation: String
    let weight: Double
}
