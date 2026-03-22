import SwiftUI

struct BeslissingenView: View {
    @Environment(GatewayManager.self) private var gateway
    @ObservedObject var viewModel: BeslissingenViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.97, green: 0.98, blue: 0.99),
                        Color(red: 0.96, green: 0.97, blue: 0.99),
                        Color(red: 0.98, green: 0.96, blue: 0.95)
                    ]
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        InstrumentRoleHeader(
                            eyebrow: "Research Frontiers",
                            title: "Beslissingen",
                            summary: "Actie vereist. Dit zijn de frontier-signalen die nog op jouw besluit wachten.",
                            accent: .jeevesLogoRed,
                            metrics: [
                                InstrumentRoleMetric(label: "Open", value: "\(viewModel.openDecisionCount)"),
                                InstrumentRoleMetric(label: "Status", value: viewModel.openDecisionCount == 0 ? "Rustig" : "Review")
                            ]
                        )

                        if let error = viewModel.error {
                            statusNotice(error)
                        }

                        InstrumentSectionPanel(
                            eyebrow: "Queue",
                            title: "Openstaande beslissingen",
                            subtitle: "Alleen frontier-items met status proposed of awaiting_review staan hier.",
                            accent: .jeevesLogoRed,
                            metric: viewModel.badgeText
                        ) {
                            if viewModel.isLoading && viewModel.gaps.isEmpty {
                                ProgressView("Beslissingen worden geladen...")
                                    .font(.jeevesBody)
                            } else if viewModel.openDecisions.isEmpty {
                                emptyState("Geen beslissingen nodig. Het systeem observeert.")
                            } else {
                                ForEach(viewModel.openDecisions) { gap in
                                    decisionCard(gap)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Beslissingen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                viewModel.configure(gateway: gateway)
                if viewModel.gaps.isEmpty {
                    await viewModel.fetchOpenDecisions()
                }
            }
            .refreshable {
                viewModel.configure(gateway: gateway)
                await viewModel.fetchOpenDecisions()
            }
            .onChange(of: gateway.isConnected) {
                if gateway.isConnected {
                    Task {
                        viewModel.configure(gateway: gateway)
                        await viewModel.fetchOpenDecisions()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func decisionCard(_ gap: GapProposal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(gap.displayTitle)
                    .font(.jeevesHeadline.weight(.semibold))
                    .foregroundStyle(Color.jeevesInk)
                    .lineLimit(2)

                Spacer()

                if viewModel.activeDecisionId == gap.id {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.jeevesLogoRed)
                }
            }

            HStack(spacing: 8) {
                badge(scoreLabel(for: gap), accent: scoreColor(for: gap))
                badge(domainLabel(for: gap), accent: domainColor(for: gap))
            }

            Text(gap.displayHypothesis)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 10) {
                Button {
                    Task {
                        await viewModel.decide(gap, decision: "approved")
                    }
                } label: {
                    Text("Goedkeuren")
                        .font(.jeevesBody.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.consentGreen)
                .disabled(viewModel.activeDecisionId == gap.id)

                Button {
                    Task {
                        await viewModel.decide(gap, decision: "denied")
                    }
                } label: {
                    Text("Afwijzen")
                        .font(.jeevesBody.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.consentRed)
                .disabled(viewModel.activeDecisionId == gap.id)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.jeevesLogoRed.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func scoreLabel(for gap: GapProposal) -> String {
        guard let score = gap.score else { return "Geen score" }
        return String(format: "%.0f%%", min(max(score, 0), 1) * 100)
    }

    private func scoreColor(for gap: GapProposal) -> Color {
        switch gap.score ?? 0 {
        case 0.7...:
            return .consentGreen
        case 0.5..<0.7:
            return .jeevesGold
        default:
            return .jeevesLogoRed
        }
    }

    private func domainLabel(for gap: GapProposal) -> String {
        let candidate = gap.trustBoundary ?? gap.gapType ?? gap.source ?? "Algemeen"
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Algemeen" : trimmed
    }

    private func domainColor(for gap: GapProposal) -> Color {
        let palette: [Color] = [.jeevesLogoRed, .jeevesSky, .jeevesMint, .jeevesGold, .jeevesTeal]
        let index = abs(domainLabel(for: gap).lowercased().hashValue) % palette.count
        return palette[index]
    }

    @ViewBuilder
    private func badge(_ text: String, accent: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(accent.opacity(0.12))
            )
    }

    @ViewBuilder
    private func statusNotice(_ message: String) -> some View {
        Text(message)
            .font(.jeevesBody)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.jeevesLogoRed.opacity(0.14), lineWidth: 1)
                    )
            )
    }

    @ViewBuilder
    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.jeevesBody)
            .foregroundStyle(.secondary)
            .padding(.vertical, 10)
    }
}
