import Foundation

enum DemoSeed {
    private static let seedProposals: [[String: Any]] = [
        [
            "agentId": "mysterieuze-agent-nairobi",
            "title": "USSD consent pattern gevonden in Keniaans fieldwork",
            "intent": [
                "key": "intent.research.ussd-consent",
                "payload": ["bron": "fieldwork-bumala", "raakt": "angelopp"],
                "risk": "orange",
                "requiresConsent": true
            ] as [String: Any]
        ],
        [
            "agentId": "github-scanner",
            "title": "ironclaw voegt Ed25519 consent-binding toe",
            "intent": [
                "key": "intent.scan.competitors",
                "payload": ["repo": "ironclaw", "commit": "ed25519-consent"],
                "risk": "green",
                "requiresConsent": false
            ] as [String: Any]
        ],
        [
            "agentId": "arxiv-watcher",
            "title": "Paper: Cryptographic Consent in Multi-Agent Systems",
            "intent": [
                "key": "intent.research.consent-crypto",
                "payload": ["arxiv": "2026.03421", "keywords": ["consent", "multi-agent", "cryptographic"]],
                "risk": "green",
                "requiresConsent": false
            ] as [String: Any]
        ],
        [
            "agentId": "burnerphone-chaos",
            "title": "Poging: fase overslaan tijdens intern-modus",
            "intent": [
                "key": "intent.test.phase-skip",
                "payload": ["scenario": "phase-skipper", "fase": "extern"],
                "risk": "orange",
                "requiresConsent": true
            ] as [String: Any]
        ]
    ]

    static func seedIfNeeded(host: String, port: Int, token: String) async -> Bool {
        let client = GatewayClient(host: host, port: port, token: token)
        let existing = (try? await client.fetchProposals()) ?? []
        let pending = existing.filter(\.isPending)
        guard pending.isEmpty else { return false }

        let builder = AuthorizedRequestBuilder(host: host, port: port, token: token)
        for (index, proposal) in seedProposals.enumerated() {
            if index > 0 {
                try? await Task.sleep(for: .milliseconds(500))
            }
            do {
                try await postProposal(proposal, builder: builder)
            } catch {
                continue
            }
        }

        return true
    }

    private static func postProposal(_ proposal: [String: Any], builder: AuthorizedRequestBuilder) async throws {
        let body = try JSONSerialization.data(withJSONObject: proposal)
        let req = try builder.request(for: RouteContract.Agents.propose, body: body)
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
