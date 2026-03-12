import SwiftUI

struct SystemLoopStrip: View {
    let snapshot: MissionControlSystemLoopSnapshot
    @State private var pulseActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            stageRow
            subtitleText
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundCard)
        .onAppear {
            guard !pulseActive else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulseActive = true
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("SYSTEM LOOP")
                .font(.caption.monospaced())
                .foregroundStyle(Color.white.opacity(0.62))

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
            .foregroundStyle(Color.white.opacity(0.62))
            .lineLimit(2)
    }

    private var backgroundCard: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.08), stageTint.opacity(0.14), Color.black.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(stageTint.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: stageTint.opacity(0.14), radius: 10, y: 3)
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
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: active
                                ? [tint.opacity(0.30), Color.black.opacity(0.12)]
                                : [tint.opacity(0.10), Color.black.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .foregroundStyle(active ? Color.white.opacity(0.98) : Color.white.opacity(0.74))
            .clipShape(Capsule())
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(tint)
                    .frame(width: active ? (pulseActive ? 10 : 8) : 6, height: active ? (pulseActive ? 10 : 8) : 6)
                    .shadow(color: tint.opacity(active ? 0.4 : 0.14), radius: active ? 6 : 2)
                    .padding(.top, 5)
                    .padding(.trailing, 5)
            }
            .overlay(
                Capsule()
                    .stroke(tint.opacity(active ? 0.34 : 0.12), lineWidth: 1)
            )
    }

    private var stageTint: Color {
        tint(for: snapshot.currentStage)
    }

    private func tint(for stage: MissionControlSystemLoopSnapshot.Stage) -> Color {
        switch stage {
        case .discovery:
            return .blue
        case .proposal:
            return .blue
        case .approval:
            return .orange
        case .action:
            return .blue
        case .knowledge:
            return .green
        }
    }
}
