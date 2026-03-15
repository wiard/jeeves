import SwiftUI

struct SystemLoopStrip: View {
    let snapshot: MissionControlSystemLoopSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            stageRow
            subtitleText
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .briefingPanel()
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("SYSTEM LOOP")
                .font(.caption.monospaced())
                .foregroundStyle(Color.jeevesMutedText)

            Spacer()

            Text(snapshot.currentStage.rawValue.uppercased())
                .font(.caption.monospaced())
                .foregroundStyle(stageTint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(stageTint.opacity(0.12), in: Capsule())
        }
    }

    private var stageRow: some View {
        ViewThatFits {
            HStack(spacing: 8) {
                stagePill(.discovery)
                stagePill(.proposal)
                stagePill(.approval)
                stagePill(.action)
                stagePill(.knowledge)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    stagePill(.discovery)
                    stagePill(.proposal)
                    stagePill(.approval)
                }
                HStack(spacing: 8) {
                    stagePill(.action)
                    stagePill(.knowledge)
                }
            }
        }
    }

    private var subtitleText: some View {
        Text(snapshot.stageSummary)
            .font(.footnote)
            .foregroundStyle(Color.jeevesSubtleText)
            .lineLimit(2)
    }

    @ViewBuilder
    private func stagePill(_ stage: MissionControlSystemLoopSnapshot.Stage) -> some View {
        let active = stage == snapshot.currentStage
        let tint = tint(for: stage)

        HStack(spacing: 5) {
            if active {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
            }
            Text(stage.rawValue)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(active ? tint.opacity(0.22) : Color.jeevesCloud.opacity(0.60))
        )
        .foregroundStyle(active ? Color.jeevesInk : Color.jeevesSubtleText)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(active ? 0.40 : 0.12), lineWidth: 1)
        )
        .shadow(color: active ? tint.opacity(0.10) : Color.clear, radius: 6, y: 3)
    }

    private var stageTint: Color {
        tint(for: snapshot.currentStage)
    }

    private func tint(for stage: MissionControlSystemLoopSnapshot.Stage) -> Color {
        switch stage {
        case .discovery:
            return .jeevesSky
        case .proposal:
            return .blue
        case .approval:
            return .orange
        case .action:
            return .teal
        case .knowledge:
            return .jeevesMint
        }
    }
}
