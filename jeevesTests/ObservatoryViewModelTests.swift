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

        let alertIds = vm.snapshot?.alerts.map(\.id) ?? []
        let challengeIds = vm.snapshot?.lobbyOpenChallenges.map(\.id) ?? []
        let emergenceIds = vm.snapshot?.knowledgeEmergence?.clusters.map(\.id) ?? []

        #expect(alertIds == ["a-c", "a-a", "a-b"])
        #expect(challengeIds == ["c-c", "c-a", "c-b"])
        #expect(emergenceIds == ["k-a", "k-b"])
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
