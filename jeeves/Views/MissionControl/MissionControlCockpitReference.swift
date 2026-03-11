import SwiftUI

struct MissionControlCockpitReference: View {
    let statusTitle: String
    let statusDetail: String
    let summaryLine: String
    let activeStage: SystemLoopStage
    let loopSubtitle: String
    let cards: [MissionStageCardModel]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard

                    SystemLoopCapsuleStrip(
                        activeStage: activeStage,
                        subtitle: loopSubtitle
                    )

                    ForEach(cards) { card in
                        MissionStageCompactCard(card: card)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mission Control")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SYSTEM STATUS")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Spacer()

                Text(statusBadgeText)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusBadgeColor.opacity(0.12))
                    .foregroundStyle(statusBadgeColor)
                    .clipShape(Capsule())
            }

            Text(statusTitle)
                .font(.title3.weight(.semibold))

            Text(statusDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(summaryLine)
                .font(.footnote)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var statusBadgeText: String {
        switch activeStage {
        case .approval: return "ATTENTION"
        case .discovery: return "LIVE"
        case .proposal: return "QUEUE"
        case .action: return "ACTIVE"
        case .knowledge: return "FLOW"
        }
    }

    private var statusBadgeColor: Color {
        switch activeStage {
        case .approval: return .orange
        case .discovery: return .blue
        case .proposal: return .brown
        case .action: return .green
        case .knowledge: return .mint
        }
    }
}

enum SystemLoopStage: String, CaseIterable, Identifiable {
    case discovery = "Discovery"
    case proposal = "Proposal"
    case approval = "Approval"
    case action = "Action"
    case knowledge = "Knowledge"

    var id: String { rawValue }

    var tint: Color {
        switch self {
        case .discovery: return .blue
        case .proposal: return .brown
        case .approval: return .orange
        case .action: return .green
        case .knowledge: return .mint
        }
    }
}

struct SystemLoopCapsuleStrip: View {
    let activeStage: SystemLoopStage
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SYSTEM LOOP")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(SystemLoopStage.allCases) { stage in
                    Text(stage.rawValue)
                        .font(.caption)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            stage == activeStage
                            ? stage.tint.opacity(0.15)
                            : Color(.tertiarySystemFill)
                        )
                        .clipShape(Capsule())
                }
            }

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct MissionStageCardModel: Identifiable {
    let id: String
    let stage: SystemLoopStage
    let title: String
    let primaryMetric: String
    let status: String
    let summary: String
    let pills: [String]
}

struct MissionStageCompactCard: View {
    let card: MissionStageCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(card.stage.rawValue.uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(card.stage.tint)

                Spacer()

                Text(card.status.uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(card.stage.tint)
            }

            HStack {
                Text(card.primaryMetric)
                    .font(.system(size: 28, weight: .bold))

                Spacer()

                Text(card.title)
                    .font(.headline)
            }

            Text(card.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(card.pills.prefix(3), id: \.self) { pill in
                    Text(pill)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
