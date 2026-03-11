import SwiftUI

struct SystemLoopStrip: View {
    let snapshot: MissionControlSystemLoopSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            stageRow
            subtitleText
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundCard)
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("SYSTEM LOOP")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

            Spacer()

            Text(snapshot.currentStage.rawValue.uppercased())
                .font(.caption.monospaced())
                .foregroundStyle(stageTint)
        }
    }

    private var stageRow: some View {
        HStack(spacing: 8) {
            stagePill(.discovery)
            stagePill(.proposal)
            stagePill(.approval)
            stagePill(.action)
            stagePill(.knowledge)
        }
    }

    private var subtitleText: some View {
        Text(snapshot.stageSummary)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }

    private var backgroundCard: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(stageTint.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
    }

    @ViewBuilder
    private func stagePill(_ stage: MissionControlSystemLoopSnapshot.Stage) -> some View {
        let active = stage == snapshot.currentStage
        let tint = tint(for: stage)

        Text(stage.rawValue)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(active ? tint.opacity(0.15) : Color.black.opacity(0.04))
            .foregroundStyle(active ? tint : Color.primary)
            .clipShape(Capsule())
    }

    private var stageTint: Color {
        tint(for: snapshot.currentStage)
    }

    private func tint(for stage: MissionControlSystemLoopSnapshot.Stage) -> Color {
        switch stage {
        case .discovery:
            return .blue
        case .proposal:
            return .brown
        case .approval:
            return .orange
        case .action:
            return .green
        case .knowledge:
            return .mint
        }
    }
}
