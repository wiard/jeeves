import SwiftUI

struct OperatorOverviewCard: View {
    let card: OperatorOverviewSnapshot.OverviewCard

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: card.eyebrow,
            title: card.title,
            subtitle: card.headline,
            accent: accentColor,
            metric: card.metric
        ) {
            Text(card.detail)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }

                Text(toneLine)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var accentColor: Color {
        switch card.tone {
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

    private var iconName: String {
        switch card.tone {
        case .discovery:
            return "dot.radiowaves.left.and.right"
        case .governance:
            return "checkmark.shield"
        case .knowledge:
            return "book.closed"
        case .trust:
            return "checklist.checked"
        }
    }

    private var toneLine: String {
        switch card.tone {
        case .discovery:
            return "CLASHD27 remains the discovery authority. Jeeves is only surfacing the pressure."
        case .governance:
            return "Approval state is reflected here; execution authority stays in openclashd-v2."
        case .knowledge:
            return "Knowledge stays operator-visible and attributable to the proposal or action that produced it."
        case .trust:
            return "Trust signals reflect bounded execution, receipts, and SafeClash visibility."
        }
    }
}
