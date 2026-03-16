import SwiftUI

struct GapDetailView: View {
    @ObservedObject var viewModel: GapProposalViewModel
    let gap: GapProposal

    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false
    @State private var actionError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Governed Gap")
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.jeevesSky)

                        Text(OperatorSignalPresentation.plainGapTitle(gap.title))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.jeevesInk)

                        HStack(spacing: 8) {
                            statusBadge
                            confidenceBadge
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Hypothesis")
                            .font(.headline)
                            .foregroundStyle(Color.jeevesInk)

                        Text(gap.hypothesis)
                            .font(.body)
                            .foregroundStyle(Color.jeevesSubtleText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Confidence")
                            .font(.headline)
                            .foregroundStyle(Color.jeevesInk)

                        ProgressView(value: boundedScore)
                            .tint(confidenceTint)

                        HStack {
                            Text(OperatorSignalPresentation.gapConfidenceLabel(score: gap.score))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(confidenceTint)

                            Spacer()

                            Text(scoreText)
                                .font(.caption.monospaced())
                                .foregroundStyle(Color.jeevesMutedText)
                        }
                    }

                    if let detectedAtIso = gap.detectedAtIso, !detectedAtIso.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Detected")
                                .font(.headline)
                                .foregroundStyle(Color.jeevesInk)

                            Text(detectedAtIso)
                                .font(.footnote)
                                .foregroundStyle(Color.jeevesSubtleText)
                        }
                    }

                    if let actionError {
                        Text(actionError)
                            .font(.footnote)
                            .foregroundStyle(Color.consentRed)
                    } else if let viewModelError = viewModel.error {
                        Text(viewModelError)
                            .font(.footnote)
                            .foregroundStyle(Color.consentRed)
                    }

                    HStack(spacing: 12) {
                        Button {
                            submit(decision: "approved")
                        } label: {
                            if isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Approve")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.consentGreen)
                        .disabled(isSubmitting)

                        Button {
                            submit(decision: "denied")
                        } label: {
                            Text("Deny")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.consentRed)
                        .disabled(isSubmitting)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Gap Review")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var boundedScore: Double {
        min(max(gap.score ?? 0, 0), 1)
    }

    private var scoreText: String {
        if let score = gap.score {
            return String(format: "%.2f", score)
        }
        return "No score"
    }

    private var confidenceTint: Color {
        switch gap.score ?? 0 {
        case 0.7...:
            return .consentGreen
        case 0.5..<0.7:
            return .consentOrange
        default:
            return .jeevesSky
        }
    }

    private var statusBadge: some View {
        Text(gap.status.capitalized)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(statusTint.opacity(0.14))
            )
    }

    private var confidenceBadge: some View {
        Text(OperatorSignalPresentation.gapConfidenceLabel(score: gap.score))
            .font(.caption.weight(.semibold))
            .foregroundStyle(confidenceTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(confidenceTint.opacity(0.12))
            )
    }

    private var statusTint: Color {
        switch gap.status.lowercased() {
        case "approved":
            return .consentGreen
        case "denied":
            return .consentRed
        default:
            return .consentOrange
        }
    }

    private func submit(decision: String) {
        guard !isSubmitting else { return }

        isSubmitting = true
        actionError = nil

        Task {
            let succeeded = await viewModel.decide(gapId: gap.id, decision: decision)
            await MainActor.run {
                isSubmitting = false
                if succeeded {
                    dismiss()
                } else {
                    actionError = viewModel.error
                }
            }
        }
    }
}
