
import Foundation
import Observation

@MainActor
@Observable
final class KnowledgeBrowserViewModel {
    var objects: [KnowledgeObject] = []
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?

    func load(gateway: GatewayManager, force: Bool = false) async {
        if isLoading && !force {
            return
        }
        if hasLoaded && !force {
            return
        }

        isLoading = true
        errorMessage = nil
        defer {
            hasLoaded = true
            isLoading = false
        }

        if gateway.useMock || gateway.host.lowercased() == "mock" {
            objects = Self.mockObjects()
            return
        }

        let resolved = await gateway.resolveEndpoint()
        guard let token = resolved.token, !token.isEmpty else {
            errorMessage = "Geen geldige gateway-token beschikbaar voor Knowledge."
            return
        }

        let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)

        do {
            objects = try await client.fetchRecentKnowledgeObjects(limit: 24)
        } catch {
            errorMessage = "Kon recente knowledge objecten niet laden."
        }
    }

    private static func mockObjects() -> [KnowledgeObject] {
        let formatter = ISO8601DateFormatter()
        let now = Date()
        return [
            KnowledgeObject(
                objectId: "knowledge-demo-1",
                kind: "evidence",
                createdAtIso: formatter.string(from: now),
                title: "Execution runtime repository activity",
                summary: "Recent repository changes suggest more modular execution layers for agent systems.",
                sourceRefs: nil,
                linkedObjectIds: ["knowledge-demo-2"],
                metadata: nil
            ),
            KnowledgeObject(
                objectId: "knowledge-demo-2",
                kind: "evidence",
                createdAtIso: formatter.string(from: now.addingTimeInterval(-1800)),
                title: "Research on modular agent orchestration",
                summary: "A new paper describes lighter coordination layers for model-driven tools.",
                sourceRefs: nil,
                linkedObjectIds: ["knowledge-demo-1"],
                metadata: nil
            ),
            KnowledgeObject(
                objectId: "knowledge-demo-3",
                kind: "discovery",
                createdAtIso: formatter.string(from: now.addingTimeInterval(-3600)),
                title: "Inference stack cluster",
                summary: "A discovery object linking infra signals, code activity, and recent evidence.",
                sourceRefs: nil,
                linkedObjectIds: nil,
                metadata: nil
            )
        ]
    }
}
