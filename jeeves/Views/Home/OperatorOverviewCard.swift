import SwiftUI

struct OperatorOverviewCard: View {
    let card: OperatorOverviewSnapshot.StageCard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.stage.title.uppercased())
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(accentColor)

                    Text(card.stage.title)
                        .font(.jeevesHeadline)
                        .foregroundStyle(.primary)

                    Text("Source: \(card.stage.source)")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(card.primaryMetric)
                        .font(.jeevesMetric)
                        .foregroundStyle(accentColor)

                    Text(card.status.uppercased())
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Text(card.headline)
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits {
                HStack(spacing: 10) {
                    ForEach(card.metrics) { metric in
                        metricPill(metric)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(card.metrics) { metric in
                        metricPill(metric)
                    }
                }
            }

            Text(card.detail)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(borderColor, lineWidth: card.isActive ? 2 : 1)
                )
        )
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(accentColor.opacity(card.isActive ? 0.18 : 0.08))
                .frame(width: 5)
        }
        .shadow(color: Color.black.opacity(card.isActive ? 0.08 : 0.03), radius: card.isActive ? 14 : 8, y: 8)
    }

    private func metricPill(_ metric: OperatorOverviewSnapshot.MetricItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.label)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)

            Text(metric.value)
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accentColor.opacity(0.08))
        )
    }

    private var accentColor: Color {
        switch card.stage {
        case .discovery:
            return .cyan
        case .proposal:
            return .blue
        case .approval:
            return .orange
        case .action:
            return card.needsAttention ? .red : .jeevesGold
        case .knowledge:
            return .green
        }
    }

    private var borderColor: Color {
        if card.needsAttention {
            return Color.red.opacity(0.22)
        }
        return accentColor.opacity(card.isActive ? 0.35 : 0.14)
    }
}
