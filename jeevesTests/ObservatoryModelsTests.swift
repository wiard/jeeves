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
        let streamJSON = """
        {
          "ok": true,
          "pendingCount": 1,
          "events": [
            {"type": "audit", "timestamp": "2026-03-04T11:00:00Z", "event": "challenge.created", "agentId": "signals"},
            {"type": "proposal_pending", "timestamp": "2026-03-04T12:00:00Z", "proposalId": "p-1", "agentId": "observer"}
          ]
        }
        """.data(using: .utf8)!
        let radarStatusJSON = """
        {
          "store": {
            "activationCount": 10,
            "collisionCount": 3,
            "emergenceCount": 1,
            "lastFetchBySource": {"github": "2026-03-04T12:00:00Z"},
            "hotClusters": [{"cluster": "architecture", "count": 2}],
            "topSignals": [{"title": "s", "source": "github", "residue": 0.8}]
          },
          "collector": {"isRunning": true, "lastRun": "2026-03-04T12:00:00Z"}
        }
        """.data(using: .utf8)!
        let radarCollisionJSON = """
        {
          "collisionId": "col-1",
          "sources": ["github", "arxiv"],
          "density": 0.7,
          "isEmergence": true,
          "detectedAtIso": "2026-03-04T12:00:00Z",
          "cells": [{"cellId": "surface|external|current"}]
        }
        """.data(using: .utf8)!
        let radarActivationJSON = """
        {
          "activationId": "act-1",
          "signal": {"source": "github", "title": "relay", "summary": "summary"},
          "activatedClusters": ["architecture"],
          "cells": [{"cellId": "surface|external|current"}],
          "residueValue": 0.9,
          "timestamp": "2026-03-04T12:00:00Z"
        }
        """.data(using: .utf8)!
        let runtimeJSON = """
        {
          "started": true,
          "lastRunAtIso": "2026-03-04T12:00:00Z",
          "runCount": 3,
          "totalSignals": 10,
          "activeSourceCount": 4,
          "lastSignals": [
            {"signalId": "s-1", "sourceId": "github", "detectedAtIso": "2026-03-04T11:59:00Z", "summary": "relay"}
          ],
          "lastChallenges": [
            {"challengeId": "ch-1", "createdAtIso": "2026-03-04T11:58:00Z", "title": "review", "status": "open"}
          ],
          "emergenceClusters": [
            {"clusterId": "em-1", "dimensions": ["trust-model","external","emerging"], "relevanceScore": 0.8, "summary": "cluster", "escalatesToIphone": true}
          ]
        }
        """.data(using: .utf8)!

        let alert = try JSONDecoder().decode(ObservatoryAlert.self, from: alertJSON)
        let emergence = try JSONDecoder().decode(FabricEmergence.self, from: emergenceJSON)
        let challenge = try JSONDecoder().decode(LobbyChallenge.self, from: challengeJSON)
        let signals = try JSONDecoder().decode(SignalsState.self, from: signalsJSON)
        let knowledgeEmergence = try JSONDecoder().decode(KnowledgeEmergence.self, from: knowledgeEmergenceJSON)
        let stream = try JSONDecoder().decode(ObservatoryStreamFeed.self, from: streamJSON)
        let radarStatus = try JSONDecoder().decode(RadarStatusSnapshot.self, from: radarStatusJSON)
        let radarCollision = try JSONDecoder().decode(RadarCollision.self, from: radarCollisionJSON)
        let radarActivation = try JSONDecoder().decode(RadarActivation.self, from: radarActivationJSON)
        let runtime = try JSONDecoder().decode(SignalsRuntimeSnapshot.self, from: runtimeJSON)

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
        #expect(stream.events.count == 2)
        #expect(stream.pendingCount == 1)
        #expect(radarStatus.store?.activationCount == 10)
        #expect(radarStatus.collector?.isRunning == true)
        #expect(radarCollision.id == "col-1")
        #expect(radarCollision.cellIds == ["surface|external|current"])
        #expect(radarActivation.id == "act-1")
        #expect(radarActivation.source == "github")
        #expect(runtime.runCount == 3)
        #expect(runtime.lastSignals.count == 1)
        #expect(runtime.lastChallenges.count == 1)
        #expect(runtime.emergenceClusters.count == 1)
    }

    @Test
    func deterministicSortingForAlertsChallengesAndStream() {
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
        let stream = ObservatoryStreamFeed(
            ok: true,
            events: [
                ObservatoryStreamEvent(
                    id: "b",
                    type: "audit",
                    timestampIso: "2026-03-04T10:00:00Z",
                    event: "e",
                    proposalId: nil,
                    agentId: nil,
                    title: nil,
                    decision: nil,
                    reason: nil,
                    risk: nil,
                    peerId: nil
                ),
                ObservatoryStreamEvent(
                    id: "a",
                    type: "audit",
                    timestampIso: "2026-03-04T10:00:00Z",
                    event: "e",
                    proposalId: nil,
                    agentId: nil,
                    title: nil,
                    decision: nil,
                    reason: nil,
                    risk: nil,
                    peerId: nil
                ),
                ObservatoryStreamEvent(
                    id: "c",
                    type: "audit",
                    timestampIso: "2026-03-04T11:00:00Z",
                    event: "e",
                    proposalId: nil,
                    agentId: nil,
                    title: nil,
                    decision: nil,
                    reason: nil,
                    risk: nil,
                    peerId: nil
                )
            ],
            pendingCount: 0
        )
        let sortedStream = ObservatoryViewModel.sortStream(stream)

        #expect(sortedAlerts.map(\.id) == ["c", "a", "b"])
        #expect(sortedChallenges.map(\.id) == ["c", "a", "b"])
        #expect(sortedStream.events.map(\.id) == ["c", "a", "b"])
    }
}
