import Foundation
import Testing
@testable import jeeves

@Suite(.serialized)
struct ObservatoryViewModelTests {

    @Test
    @MainActor
    func refreshMarksSectionAvailabilityDeterministically() async throws {
        URLProtocol.registerClass(ObservatoryURLProtocolStub.self)
        defer { URLProtocol.unregisterClass(ObservatoryURLProtocolStub.self) }

        ObservatoryURLProtocolStub.responses = [
            "/api/conductor/state": (200, """
            {
              "cycleStage": "observe",
              "consentPending": 2,
              "budget": {"remaining": 11.5, "hardStop": false},
              "killSwitch": {"active": false},
              "lastAuditEvents": [],
              "nowSuggestions": "none",
              "updatedAtIso": "2026-03-04T10:00:00Z"
            }
            """),
            "/api/fabric/clock": (200, """
            {"source": "btc", "tickN": 99, "timeIso": "2026-03-04T10:01:00Z"}
            """),
            "/api/fabric/emergence": (200, """
            {
              "strongestCell": "x1y1z1",
              "warmLayer": "z1",
              "suggestions": ["observe", "wait"],
              "clusters": [
                {"clusterId": "cluster-b", "score": 0.7},
                {"clusterId": "cluster-a", "score": 0.7}
              ]
            }
            """),
            "/api/lobby/challenges": (200, """
            {
              "challenges": [
                {"challengeId": "c-b", "title": "B", "suggestedIntentKey": "k2", "createdAtIso": "2026-03-04T10:00:00Z", "status": "open"},
                {"challengeId": "c-a", "title": "A", "suggestedIntentKey": "k1", "createdAtIso": "2026-03-04T10:00:00Z", "status": "open"},
                {"challengeId": "c-c", "title": "C", "suggestedIntentKey": "k3", "createdAtIso": "2026-03-04T11:00:00Z", "status": "open"}
              ]
            }
            """),
            "/api/observatory/alerts": (200, """
            {
              "alerts": [
                {"id": "a-b", "summary": "b", "timestamp": "2026-03-04T10:00:00Z"},
                {"id": "a-a", "summary": "a", "timestamp": "2026-03-04T10:00:00Z"},
                {"id": "a-c", "summary": "c", "timestamp": "2026-03-04T11:00:00Z"}
              ]
            }
            """),
            "/api/signals/state": (404, "{}"),
            "/api/knowledge/status": (200, """
            {
              "last24hSignalsCount": 5,
              "topCubeCells": ["a"],
              "emergenceClustersCount": 2,
              "lastKnowledgeChallenges": []
            }
            """),
            "/api/knowledge/emergence": (200, """
            {
              "clusters": [
                {"clusterId": "k-b", "score": 0.4},
                {"clusterId": "k-a", "score": 0.9}
              ]
            }
            """),
            "/api/observatory/stream": (200, """
            {
              "ok": true,
              "pendingCount": 1,
              "events": [
                {"id": "ev-b", "type": "audit", "timestamp": "2026-03-04T10:00:00Z", "event": "challenge.created"},
                {"id": "ev-a", "type": "audit", "timestamp": "2026-03-04T10:00:00Z", "event": "challenge.created"},
                {"id": "ev-c", "type": "proposal_pending", "timestamp": "2026-03-04T11:00:00Z", "proposalId": "p-1"}
              ]
            }
            """),
            "/api/radar/status": (200, """
            {
              "store": {
                "activationCount": 5,
                "collisionCount": 2,
                "emergenceCount": 1,
                "lastFetchBySource": {"github": "2026-03-04T12:00:00Z"},
                "hotClusters": [{"cluster": "architecture", "count": 2}],
                "topSignals": [{"title": "s", "source": "github", "residue": 0.6}]
              },
              "collector": {"isRunning": true, "lastRun": "2026-03-04T12:00:00Z"}
            }
            """),
            "/api/radar/activations": (200, """
            {
              "activations": [
                {"activationId": "ra-b", "signal": {"source": "github", "title": "B"}, "timestamp": "2026-03-04T10:00:00Z"},
                {"activationId": "ra-a", "signal": {"source": "github", "title": "A"}, "timestamp": "2026-03-04T10:00:00Z"},
                {"activationId": "ra-c", "signal": {"source": "github", "title": "C"}, "timestamp": "2026-03-04T11:00:00Z"}
              ]
            }
            """),
            "/api/radar/collisions": (200, """
            {
              "collisions": [
                {"collisionId": "rc-b", "density": 0.5, "detectedAtIso": "2026-03-04T10:00:00Z"},
                {"collisionId": "rc-a", "density": 0.5, "detectedAtIso": "2026-03-04T10:00:00Z"},
                {"collisionId": "rc-c", "density": 0.8, "detectedAtIso": "2026-03-04T11:00:00Z"}
              ]
            }
            """),
            "/api/radar/emergence": (200, """
            {
              "emergence": [
                {"collisionId": "re-b", "density": 0.7, "detectedAtIso": "2026-03-04T10:00:00Z", "isEmergence": true},
                {"collisionId": "re-a", "density": 0.7, "detectedAtIso": "2026-03-04T10:00:00Z", "isEmergence": true}
              ]
            }
            """),
            "/api/radar/clusters": (200, """
            {
              "clusters": [
                {"cluster": "surface", "count": 2},
                {"cluster": "architecture", "count": 4}
              ]
            }
            """),
            "/api/radar/sources": (200, """
            {
              "sources": [
                {"source": "arxiv", "signalCount": 2, "avgResidue": 0.4, "lastFetch": "2026-03-04T10:00:00Z"},
                {"source": "github", "signalCount": 3, "avgResidue": 0.6, "lastFetch": "2026-03-04T11:00:00Z"}
              ]
            }
            """)
        ]

        let connection = GatewayConnection(host: "127.0.0.1", port: 19001, channelId: "ios-app")
        try? KeychainHelper.save(token: "test-token", for: "127.0.0.1:19001")
        defer { try? KeychainHelper.delete(for: "127.0.0.1:19001") }

        let gateway = GatewayManager()
        let vm = ObservatoryViewModel()

        await vm.refresh(gateway: gateway, connection: connection)

        #expect(vm.errorText == nil)
        #expect(vm.snapshot != nil)
        #expect(vm.status(for: .loop) == .ok)
        #expect(vm.status(for: .fabric) == .ok)
        #expect(vm.status(for: .lobby) == .ok)
        #expect(vm.status(for: .alerts) == .ok)
        #expect(vm.status(for: .knowledge) == .ok)
        #expect(vm.status(for: .signals) == .unavailable)
        #expect(vm.status(for: .radar) == .ok)
        #expect(vm.status(for: .discovery) == .ok)

        let alertIds = vm.snapshot?.alerts.map(\.id) ?? []
        let challengeIds = vm.snapshot?.lobbyOpenChallenges.map(\.id) ?? []
        let emergenceIds = vm.snapshot?.knowledgeEmergence?.clusters.map(\.id) ?? []
        let streamIds = vm.snapshot?.stream?.events.map(\.id) ?? []
        let radarActivationIds = vm.snapshot?.radarActivations.map(\.id) ?? []
        let radarCollisionIds = vm.snapshot?.radarCollisions.map(\.id) ?? []
        let radarClusterIds = vm.snapshot?.radarClusters.map(\.id) ?? []
        let radarSourceIds = vm.snapshot?.radarSources.map(\.id) ?? []

        #expect(alertIds == ["a-c", "a-a", "a-b"])
        #expect(challengeIds == ["c-c", "c-a", "c-b"])
        #expect(emergenceIds == ["k-a", "k-b"])
        #expect(streamIds == ["ev-c", "ev-a", "ev-b"])
        #expect(radarActivationIds == ["ra-c", "ra-a", "ra-b"])
        #expect(radarCollisionIds == ["rc-c", "rc-a", "rc-b"])
        #expect(radarClusterIds == ["architecture", "surface"])
        #expect(radarSourceIds == ["github", "arxiv"])
    }
}

private final class ObservatoryURLProtocolStub: URLProtocol {
    static var responses: [String: (Int, String)] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let path = url.path
        let entry = Self.responses[path] ?? (404, "{}")
        let data = Data(entry.1.utf8)
        let response = HTTPURLResponse(url: url, statusCode: entry.0, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
