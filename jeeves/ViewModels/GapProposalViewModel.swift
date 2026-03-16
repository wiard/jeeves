import Foundation

@MainActor
final class GapProposalViewModel: ObservableObject {
    @Published var gaps: [GapProposal] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var statusSummary: GapStatusSummary? = nil

    private var gateway: GatewayManager?

    var proposedGaps: [GapProposal] {
        gaps
            .filter(\.isPendingReview)
            .sorted { ($0.score ?? 0) > ($1.score ?? 0) }
    }

    func configure(gateway: GatewayManager) {
        self.gateway = gateway
    }

    func fetchGaps() async {
        guard let gateway else {
            error = "The governed gateway is not configured yet."
            return
        }

        if isLoading {
            return
        }

        isLoading = true
        defer { isLoading = false }

        if gateway.useMock || gateway.host.lowercased() == "mock" {
            gaps = []
            statusSummary = GapStatusSummary()
            error = nil
            return
        }

        let resolved = await gateway.resolveEndpoint()
        guard let token = resolved.token, !token.isEmpty else {
            gaps = []
            statusSummary = nil
            error = "No conductor token is available for governed gap review."
            return
        }

        let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)

        do {
            let response = try await client.fetchGapProposals(limit: 64)
            gaps = response.gaps.sorted { ($0.score ?? 0) > ($1.score ?? 0) }
            statusSummary = response.statusSummary
            error = nil
        } catch {
            gaps = []
            statusSummary = nil
            self.error = "Could not load governed research gaps."
        }
    }

    @discardableResult
    func decide(gapProposalId: String, decision: String) async -> Bool {
        guard let gateway else {
            error = "The governed gateway is not configured yet."
            return false
        }

        if gateway.useMock || gateway.host.lowercased() == "mock" {
            gaps.removeAll { $0.gapProposalId == gapProposalId }
            statusSummary = GapStatusSummary.from(gaps: gaps)
            error = nil
            return true
        }

        let resolved = await gateway.resolveEndpoint()
        guard let token = resolved.token, !token.isEmpty else {
            error = "No conductor token is available for governed gap review."
            return false
        }

        let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)

        do {
            let response = try await client.decideGap(gapProposalId: gapProposalId, decision: decision)
            guard response.ok else {
                error = response.reason ?? "The governed gateway did not confirm the gap decision."
                return false
            }

            await fetchGaps()
            error = nil
            return true
        } catch {
            self.error = "Could not submit the governed gap decision."
            return false
        }
    }
}
