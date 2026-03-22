import Foundation

@MainActor
final class BeslissingenViewModel: ObservableObject {
    @Published var gaps: [GapProposal] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var activeDecisionId: String?

    private weak var gateway: GatewayManager?
    private let openStatuses: Set<String> = ["proposed", "awaiting_review"]

    var openDecisions: [GapProposal] {
        gaps
            .filter { gap in
                let status = gap.status.lowercased()
                let reviewStatus = gap.reviewStatus?.lowercased() ?? ""
                return openStatuses.contains(status) || openStatuses.contains(reviewStatus)
            }
            .sorted { ($0.score ?? 0) > ($1.score ?? 0) }
    }

    var openDecisionCount: Int {
        openDecisions.count
    }

    var badgeText: String? {
        openDecisionCount == 0 ? nil : String(openDecisionCount)
    }

    func configure(gateway: GatewayManager) {
        self.gateway = gateway
    }

    func fetchOpenDecisions() async {
        guard let gateway else {
            error = "De gateway is nog niet ingesteld."
            return
        }

        if isLoading {
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let api = await gateway.makeOperatorSurfacesAPI() else {
            gaps = []
            error = gateway.useMock ? nil : "Geen conductor-token beschikbaar voor beslissingen."
            return
        }

        do {
            let response = try await api.fetchGapProposals(limit: 64)
            gaps = response.gaps
            error = nil
        } catch {
            gaps = []
            self.error = "De frontier-queue kon niet worden geladen."
        }
    }

    func decide(_ gap: GapProposal, decision: String) async {
        guard let gateway else {
            error = "De gateway is nog niet ingesteld."
            return
        }

        guard let api = await gateway.makeOperatorSurfacesAPI() else {
            error = "Geen conductor-token beschikbaar voor deze beslissing."
            return
        }

        activeDecisionId = gap.id
        defer { activeDecisionId = nil }

        do {
            let ack = try await api.decideProposal(
                proposalId: gap.gapProposalId.isEmpty ? gap.gapId : gap.gapProposalId,
                decision: decision
            )
            guard ack.ok else {
                error = ack.reason ?? "De beslissing werd niet bevestigd."
                return
            }

            error = nil
            await fetchOpenDecisions()
        } catch {
            self.error = "De beslissing kon niet worden verstuurd."
        }
    }
}
