import Foundation
import Testing
@testable import jeeves

@MainActor
struct JeevesKanaalViewModelTests {

    @Test
    func intentParsingHerkenningWerkt() {
        #expect(JeevesKanaalViewModel.parseIntent(from: "wat wacht op mij") == .pendingApprovals)
        #expect(JeevesKanaalViewModel.parseIntent(from: "keur goed eerste") == .approve(reference: "eerste"))
        #expect(JeevesKanaalViewModel.parseIntent(from: "wijs af voorstel-7") == .dismiss(reference: "voorstel-7"))
    }

    @Test
    func statusCommandRoeptConductorEndpointAan() async {
        let api = MockKanaalAPI()
        let viewModel = JeevesKanaalViewModel(apiClient: api)

        await viewModel.send("wat is de status")

        #expect(api.fetchConductorStateCalls == 1)
        #expect(viewModel.messages.last?.text.contains("Status:") == true)
        #expect(viewModel.messages.last?.text.contains("Kill switch:") == true)
    }

    @Test
    func proposalAntwoordBlijftBondigEnConcreet() {
        let reply = JeevesKanaalViewModel.formatPendingProposals([
            MockKanaalAPI.proposal(id: "prop-1", title: "Sterk signaal rond oncologie", score: 0.75),
            MockKanaalAPI.proposal(id: "prop-2", title: "Tweede voorstel voor triage", score: 0.74),
            MockKanaalAPI.proposal(id: "prop-3", title: "Lagere score voor follow-up", score: 0.53)
        ])

        #expect(reply.contains("Er zijn 3 proposals"))
        #expect(reply.contains("0.75"))
        #expect(reply.contains("0.74"))
        #expect(reply.contains("prop-1"))
    }
}

private final class MockKanaalAPI: JeevesKanaalAPIClient {
    var fetchAgentProposalsCalls = 0
    var fetchJacobMeaningCalls = 0
    var fetchConductorStateCalls = 0
    var fetchRadarDiscoveriesCalls = 0
    var fetchClassifiedDiscoveriesCalls = 0
    var decideProposalCalls: [(String, String)] = []

    func fetchAgentProposals() async throws -> [Proposal] {
        fetchAgentProposalsCalls += 1
        return []
    }

    func fetchJacobMeaning() async throws -> [JeevesKanaalMeaningItem] {
        fetchJacobMeaningCalls += 1
        return []
    }

    func fetchConductorState() async throws -> ConductorState {
        fetchConductorStateCalls += 1
        return ConductorState(
            cycleStage: "review",
            consentPending: 2,
            budget: .init(remaining: 12.5, hardStop: false),
            killSwitch: .init(active: false),
            lastAuditEvents: [],
            nowSuggestions: "",
            updatedAtIso: "2026-03-22T09:00:00Z"
        )
    }

    func fetchRadarDiscoveries() async throws -> [RadarDiscoveryCandidate] {
        fetchRadarDiscoveriesCalls += 1
        return []
    }

    func fetchClassifiedDiscoveries() async throws -> [ClassifiedDiscovery] {
        fetchClassifiedDiscoveriesCalls += 1
        return []
    }

    func decideProposal(proposalId: String, decision: String) async throws -> OperatorMutationAck {
        decideProposalCalls.append((proposalId, decision))
        return OperatorMutationAck(ok: true)
    }

    static func proposal(id: String, title: String, score: Double) -> Proposal {
        Proposal(
            proposalId: id,
            createdAtIso: "2026-03-22T09:00:00Z",
            agentId: "radar",
            title: title,
            intent: ProposalIntent(kind: "proposal", key: "proposal.review", risk: "medium", requiresConsent: true),
            status: "pending",
            priorityScore: score,
            priorityExplanation: nil,
            rank: nil,
            priorityFactors: nil
        )
    }
}
