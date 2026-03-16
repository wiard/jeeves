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
                        Text("Research frontier")
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.jeevesSky)

                        Text(gap.displayTitle)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color.jeevesInk)

                        Text("Discovered by CLASHD27 from live research signals.")
                            .font(.footnote)
                            .foregroundStyle(Color.jeevesSubtleText)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            statusBadge
                            confidenceBadge
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("What the system thinks")
                            .font(.headline)
                            .foregroundStyle(Color.jeevesInk)

                        Text(gap.displayHypothesis)
                            .font(.body)
                            .foregroundStyle(Color.jeevesSubtleText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.jeevesSky.opacity(0.08))
                            )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Signal strength")
                            .font(.headline)
                            .foregroundStyle(Color.jeevesInk)

                        ProgressView(value: boundedScore)
                            .tint(confidenceTint)

                        HStack {
                            Text(gap.confidenceLabel)
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

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Governed status")
                            .font(.headline)
                            .foregroundStyle(Color.jeevesInk)

                        Text(displayStatusLabel(gap.status))
                            .font(.footnote)
                            .foregroundStyle(Color.jeevesSubtleText)
                    }

                    if let reviewStatus = gap.reviewStatus, !reviewStatus.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Review status")
                                .font(.headline)
                                .foregroundStyle(Color.jeevesInk)

                            Text(displayStatusLabel(reviewStatus))
                                .font(.footnote)
                                .foregroundStyle(Color.jeevesSubtleText)
                        }
                    }

                    if let trustBoundary = gap.trustBoundary, !trustBoundary.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Trust boundary")
                                .font(.headline)
                                .foregroundStyle(Color.jeevesInk)

                            Text(trustBoundary.replacingOccurrences(of: "_", with: " "))
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
                            submit(decision: "approve")
                        } label: {
                            if isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Approve this")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.consentGreen)
                        .disabled(isSubmitting)

                        Button {
                            submit(decision: "deny")
                        } label: {
                            Text("Dismiss")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.consentRed)
                        .disabled(isSubmitting)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Research frontier")
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
        Text(displayStatusLabel(gap.status))
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
        Text(gap.confidenceLabel)
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

    private func displayStatusLabel(_ value: String) -> String {
        switch value.lowercased() {
        case "proposed", "pending":
            return "Awaiting your review"
        case "approved":
            return "Approved"
        case "denied":
            return "Dismissed"
        default:
            return value.capitalized
        }
    }

    private func submit(decision: String) {
        guard !isSubmitting else { return }

        isSubmitting = true
        actionError = nil

        Task {
            let succeeded = await viewModel.decide(gapProposalId: gap.gapProposalId, decision: decision)
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
