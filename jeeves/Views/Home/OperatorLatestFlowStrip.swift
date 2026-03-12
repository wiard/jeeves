import SwiftUI

struct OperatorLatestFlowStrip: View {
    let items: [OperatorOverviewSnapshot.LoopStage]

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: "System Loop",
            title: "Discovery -> Proposal -> Approval -> Bounded Action -> Knowledge",
            subtitle: "The highlighted stage is where the pipeline is currently active.",
            accent: .blue
        ) {
            ViewThatFits {
                HStack(alignment: .center, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        loopCell(for: item)

                        if index < items.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.jeevesMonoSmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items) { item in
                        loopCell(for: item)
                    }
                }
            }
        }
    }

    private func loopCell(for item: OperatorOverviewSnapshot.LoopStage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.stage.title.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(item.isActive ? .white : accentColor(for: item))

            Text(item.metric)
                .font(.jeevesHeadline)
                .foregroundStyle(item.isActive ? .white : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(item.isActive ? accentColor(for: item) : accentColor(for: item).opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor(for: item).opacity(item.isActive ? 0 : 0.14), lineWidth: 1)
        )
    }

    private func accentColor(for item: OperatorOverviewSnapshot.LoopStage) -> Color {
        switch item.stage {
        case .discovery:
            return .cyan
        case .proposal:
            return .blue
        case .approval:
            return item.isActive ? .orange : .orange
        case .action:
            return item.tone == .watch ? .red : .jeevesGold
        case .knowledge:
            return .green
        }
    }
}
