import SwiftUI

struct OperatorLatestFlowStrip: View {
    let items: [OperatorOverviewSnapshot.FlowItem]

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: "Latest Flow",
            title: "From signal to approval to visible knowledge",
            subtitle: "A compact strip showing the most recent governed path through discovery, approval, action, and knowledge.",
            accent: .blue
        ) {
            ViewThatFits {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        flowCell(for: item)

                        if index < items.count - 1 {
                            Image(systemName: "arrow.right")
                                .font(.jeevesMonoSmall)
                                .foregroundStyle(Color.secondary)
                                .padding(.top, 22)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        flowCell(for: item)

                        if index < items.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func flowCell(for item: OperatorOverviewSnapshot.FlowItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(item.label.uppercased())
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(accentColor(for: item.tone))

                Spacer(minLength: 8)

                Text(item.badge)
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(accentColor(for: item.tone))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(accentColor(for: item.tone).opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(item.title)
                .font(.jeevesHeadline)

            Text(item.detail)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accentColor(for: item.tone).opacity(0.14), lineWidth: 1)
                )
        )
    }

    private func accentColor(for tone: OperatorOverviewSnapshot.Tone) -> Color {
        switch tone {
        case .discovery:
            return .cyan
        case .governance:
            return .orange
        case .knowledge:
            return .green
        case .trust:
            return .jeevesGold
        }
    }
}
