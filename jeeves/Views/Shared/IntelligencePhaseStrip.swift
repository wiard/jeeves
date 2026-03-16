import Foundation
import SwiftUI

enum IntelligencePhaseStage: String, CaseIterable, Identifiable {
    case safety = "Safety"
    case define = "Define"
    case investigate = "Investigate"

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .safety:
            return .consentOrange
        case .define:
            return .jeevesSky
        case .investigate:
            return .jeevesMint
        }
    }

    var note: String {
        switch self {
        case .safety:
            return "Human authority and risk limits stay explicit."
        case .define:
            return "Signals are being shaped into something legible."
        case .investigate:
            return "The field is open for deeper evidence and pattern work."
        }
    }
}

struct IntelligencePhaseStrip: View {
    @Environment(GatewayManager.self) private var gateway

    let currentStage: IntelligencePhaseStage
    let summary: String
    @State private var remoteSnapshot: SystemIntelligenceSnapshot?

    private var activeStage: IntelligencePhaseStage {
        remoteSnapshot?.stagePhase ?? currentStage
    }

    private var activeSummary: String {
        guard let remoteSnapshot else {
            return summary
        }

        let confidenceLabel: String
        if remoteSnapshot.entropy > 0.6 {
            confidenceLabel = "Low"
        } else if remoteSnapshot.entropy > 0.3 {
            confidenceLabel = "Medium"
        } else {
            confidenceLabel = "High"
        }
        return "\(summary) Confidence: \(confidenceLabel) · pattern strength \(Int((remoteSnapshot.residueStrength * 100).rounded()))%."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("HOW THIS WORKS")
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(Color.jeevesMutedText)

                Spacer()

                Text(activeStage.rawValue.uppercased())
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(activeStage.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(activeStage.accent.opacity(0.12), in: Capsule())
            }

            ViewThatFits {
                HStack(spacing: 10) {
                    ForEach(IntelligencePhaseStage.allCases) { stage in
                        stageCard(stage)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(IntelligencePhaseStage.allCases) { stage in
                        stageCard(stage)
                    }
                }
            }

            Text(activeSummary)
                .font(.jeevesCaption)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .briefingPanel()
        .task(id: gateway.isConnected) {
            await refreshRemotePhase()
        }
    }

    private func stageCard(_ stage: IntelligencePhaseStage) -> some View {
        let isCurrent = stage == activeStage

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isCurrent ? stage.accent : Color.jeevesLine)
                    .frame(width: 8, height: 8)
                Text(stage.rawValue)
                    .font(.jeevesHeadline)
                    .foregroundStyle(isCurrent ? Color.jeevesInk : Color.jeevesSubtleText)
            }

            Text(stage.note)
                .font(.jeevesCaption)
                .foregroundStyle(isCurrent ? Color.jeevesSubtleText : Color.jeevesMutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isCurrent
                        ? AnyShapeStyle(LinearGradient(
                            colors: [stage.accent.opacity(0.18), stage.accent.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(Color.jeevesCloud.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isCurrent ? stage.accent.opacity(0.35) : Color.jeevesLine.opacity(0.55), lineWidth: 1)
                )
        )
        .shadow(color: isCurrent ? stage.accent.opacity(0.08) : Color.clear, radius: 8, y: 4)
    }

    @MainActor
    private func refreshRemotePhase() async {
        do {
            let builder = try gateway.requireBuilder()
            remoteSnapshot = try await ObservatoryAPI.systemIntelligence(builder: builder)
        } catch {
            remoteSnapshot = nil
        }
    }
}

extension IntelligencePhaseStage {
    init?(phase: String) {
        switch phase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "safety":
            self = .safety
        case "define":
            self = .define
        case "investigate":
            self = .investigate
        default:
            return nil
        }
    }
}
