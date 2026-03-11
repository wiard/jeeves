import SwiftUI

struct SystemLoopStrip: View {
    let snapshot: MissionControlSystemLoopSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("SYSTEM LOOP")
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                Text(snapshot.currentStage.rawValue.uppercased())
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(accentColor)
            }

            HStack(spacing: 6) {
                ForEach(MissionControlSystemLoopSnapshot.Stage.allCases, id: \.self) { stage in
                    stagePill(stage)
                }
            }

            HStack(spacing: 8) {
                Text(snapshot.currentStage.eventLabel)
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(.secondary)

                Text("\(snapshot.eventCount)")
                    .font(.jeevesBody.weight(.semibold))
                    .foregroundStyle(accentColor)

                Spacer(minLength: 4)

                if let date = snapshot.lastTransitionAt {
                    Text(Self.relativeFormatter.localizedString(for: date, relativeTo: Date()))
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(0.18), lineWidth: 1)
        )
    }

    private func stagePill(_ stage: MissionControlSystemLoopSnapshot.Stage) -> some View {
        let isActive = stage == snapshot.currentStage
        return Text(stage.rawValue)
            .font(.jeevesMonoSmall)
            .foregroundStyle(isActive ? .white : .primary.opacity(0.7))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(isActive ? accentColor : accentColor.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(accentColor.opacity(isActive ? 0 : 0.14), lineWidth: 1)
            )
    }

    private var accentColor: Color {
        switch snapshot.currentStage {
        case .discovery:
            return .cyan
        case .proposal:
            return .blue
        case .approval:
            return .orange
        case .action:
            return .jeevesGold
        case .knowledge:
            return .green
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

#Preview {
    SystemLoopStrip(
        snapshot: MissionControlSystemLoopSnapshot(
            currentStage: .approval,
            eventCount: 5,
            stageSummary: "5 proposals waiting for operator review.",
            lastTransitionAt: Date().addingTimeInterval(-12)
        )
    )
    .padding(.horizontal, 16)
}
