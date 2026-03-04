import Foundation
import Testing
@testable import jeeves

struct ObservatoryModelsTests {

    @Test
    func decodeMinimalObservatoryModels() throws {
        let alertJSON = """
        { "alertId": "a-1", "message": "m1", "timestamp": "2026-03-04T10:00:00Z" }
        """.data(using: .utf8)!
        let emergenceJSON = """
        {
          "strongestCell": "x1y1z1",
          "warmLayer": "z1",
          "suggestions": ["observe"],
          "clusters": [{"clusterId": "k-1", "summary": "s", "score": 0.9}]
        }
        """.data(using: .utf8)!
        let challengeJSON = """
        {
          "challengeId": "c-1",
          "title": "Challenge",
          "suggestedIntentKey": "intent.key",
          "createdAtIso": "2026-03-04T10:00:00Z",
          "status": "open"
        }
        """.data(using: .utf8)!
        let signalsJSON = """
        {
          "signals": 11,
          "challenges": 4,
          "proposals": 3,
          "executed": 2
        }
        """.data(using: .utf8)!
        let knowledgeEmergenceJSON = """
        {
          "clusters": [
            {"clusterId": "k-2", "summary": "b", "relevanceScore": 0.7}
          ]
        }
        """.data(using: .utf8)!

        let alert = try JSONDecoder().decode(ObservatoryAlert.self, from: alertJSON)
        let emergence = try JSONDecoder().decode(FabricEmergence.self, from: emergenceJSON)
        let challenge = try JSONDecoder().decode(LobbyChallenge.self, from: challengeJSON)
        let signals = try JSONDecoder().decode(SignalsState.self, from: signalsJSON)
        let knowledgeEmergence = try JSONDecoder().decode(KnowledgeEmergence.self, from: knowledgeEmergenceJSON)

        #expect(alert.id == "a-1")
        #expect(alert.summary == "m1")
        #expect(emergence.strongestCell == "x1y1z1")
        #expect(emergence.clusters.count == 1)
        #expect(challenge.id == "c-1")
        #expect(challenge.key == "intent.key")
        #expect(signals.signalsToday == 11)
        #expect(signals.executedActions == 2)
        #expect(knowledgeEmergence.clusters.first?.id == "k-2")
        #expect(knowledgeEmergence.clusters.first?.score == 0.7)
    }

    @Test
    func deterministicSortingForAlertsAndChallenges() {
        let alerts = [
            ObservatoryAlert(id: "b", title: nil, summary: nil, timestampIso: "2026-03-04T10:00:00Z"),
            ObservatoryAlert(id: "a", title: nil, summary: nil, timestampIso: "2026-03-04T10:00:00Z"),
            ObservatoryAlert(id: "c", title: nil, summary: nil, timestampIso: "2026-03-04T11:00:00Z")
        ]

        let challenges = [
            LobbyChallenge(id: "b", title: nil, key: nil, createdAtIso: "2026-03-04T10:00:00Z", status: "open"),
            LobbyChallenge(id: "a", title: nil, key: nil, createdAtIso: "2026-03-04T10:00:00Z", status: "open"),
            LobbyChallenge(id: "c", title: nil, key: nil, createdAtIso: "2026-03-04T11:00:00Z", status: "open")
        ]

        let sortedAlerts = ObservatoryViewModel.sortAlerts(alerts)
        let sortedChallenges = ObservatoryViewModel.sortChallenges(challenges)

        #expect(sortedAlerts.map(\.id) == ["c", "a", "b"])
        #expect(sortedChallenges.map(\.id) == ["c", "a", "b"])
    }
}
