
import Foundation
import Observation

@MainActor
@Observable
final class KnowledgeBrowserViewModel {
    var objects: [KnowledgeObject] = []
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var isRateLimited = false

    func load(gateway: GatewayManager, force: Bool = false) async {
        if isLoading && !force {
            return
        }
        if hasLoaded && !force {
            return
        }

        isLoading = true
        errorMessage = nil
        isRateLimited = false
        defer { isLoading = false }

        print("[KnowledgeVM] gateway.useMock=\(gateway.useMock), gateway.host=\(gateway.host)")
        if gateway.useMock || gateway.host.lowercased() == "mock" {
            objects = Self.mockObjects()
            hasLoaded = true
            print("[KnowledgeVM] using mock: \(objects.count) objects")
            return
        }

        let resolved = await gateway.resolveEndpoint()
        print("[KnowledgeVM] resolved: host=\(resolved.host), port=\(resolved.port), token=\(resolved.token != nil ? "present(\(resolved.token!.prefix(8))...)" : "nil")")
        guard let token = resolved.token, !token.isEmpty else {
            errorMessage = "Geen geldige gateway-token beschikbaar voor Knowledge."
            print("[KnowledgeVM] no token — aborting")
            return
        }

        let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)

        print("[KnowledgeVM] loading from \(resolved.host):\(resolved.port)")
        do {
            let fetched = try await client.fetchRecentKnowledgeObjects(limit: 24)
            objects = fetched
            hasLoaded = true
            print("[KnowledgeVM] success: \(fetched.count) objects")
        } catch GatewayClientError.rateLimited {
            isRateLimited = true
            print("[KnowledgeVM] rate limited, retrying after 800ms")
            // One calm retry after a short backoff
            try? await Task.sleep(for: .milliseconds(800))
            do {
                let fetched = try await client.fetchRecentKnowledgeObjects(limit: 24)
                objects = fetched
                isRateLimited = false
                hasLoaded = true
                print("[KnowledgeVM] retry success: \(fetched.count) objects")
            } catch {
                print("[KnowledgeVM] retry failed: \(error)")
                // Still rate-limited — keep existing objects visible
                // Only mark loaded if we have objects from a prior successful fetch
                if !objects.isEmpty { hasLoaded = true }
            }
        } catch {
            print("[KnowledgeVM] fetch error: \(error)")
            errorMessage = "Jeeves kon de bibliotheek nu niet openen."
            // Preserve existing library; only mark loaded if objects remain
            if !objects.isEmpty { hasLoaded = true }
        }
        print("[KnowledgeVM] final state: \(objects.count) objects, hasLoaded=\(hasLoaded), error=\(errorMessage ?? "nil"), rateLimited=\(isRateLimited)")
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
