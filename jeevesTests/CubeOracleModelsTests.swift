import Foundation
import Testing
@testable import jeeves

struct CubeOracleModelsTests {

    @Test
    func decodeCubeCardAndDrawResponse() throws {
        let cardJSON = """
        {
          "cardId": "CARD:014",
          "cellIndex": 14,
          "cubeCell": {"what": "surface", "where": "external", "when": "current"},
          "title": "The Relay Mirror",
          "subtitle": "Interfaces echo deeper architecture.",
          "keywords": ["agents", "consent"],
          "ordinal": {
            "inscriptionHint": "bitmap://card/014",
            "contentHash": "sha256:5c8f0f8a",
            "artifactRef": null
          },
          "sound": {
            "soundId": "SND:014",
            "preset": "glitch-echo",
            "params": {"feedback": 0.6}
          }
        }
        """.data(using: .utf8)!

        let drawJSON = """
        {
          "card": {
            "cardId": "CARD:014",
            "cellIndex": 14,
            "cubeCell": {"what": "surface", "where": "external", "when": "current"},
            "title": "The Relay Mirror",
            "subtitle": "Interfaces echo deeper architecture.",
            "keywords": ["agents", "consent"],
            "ordinal": {
              "inscriptionHint": "bitmap://card/014",
              "contentHash": "sha256:5c8f0f8a",
              "artifactRef": null
            },
            "sound": {
              "soundId": "SND:014",
              "preset": "glitch-echo",
              "params": {"feedback": 0.6}
            }
          },
          "soundProfile": {
            "preset": "glitch-echo",
            "params": {"feedback": 0.6},
            "volume": 0.8,
            "pitchShift": 0
          },
          "hotspots": [
            {
              "cellId": "CELL:14",
              "cellIndex": 14,
              "cubeCell": {"what": "surface", "where": "external", "when": "current"},
              "residue": 23.4,
              "trend": 0.8
            }
          ],
          "clusters": [
            {
              "clusterId": "CL:EMG:001",
              "label": "consent × injection",
              "cellIndex": 14,
              "cubeCell": {"what": "surface", "where": "external", "when": "current"},
              "score": 0.91,
              "signals": ["arxiv", "github"],
              "nodes": ["n1", "n2"]
            }
          ],
          "related": {
            "repos": [{"title": "repo", "url": "https://example.com"}],
            "papers": [],
            "posts": []
          }
        }
        """.data(using: .utf8)!

        let card = try JSONDecoder().decode(CubeCard.self, from: cardJSON)
        let draw = try JSONDecoder().decode(CubeDrawResponse.self, from: drawJSON)

        #expect(card.id == "CARD:014")
        #expect(card.cubeCell.where_ == "external")
        #expect(draw.hotspots.first?.id == "CELL:14")
        #expect(draw.clusters.first?.id == "CL:EMG:001")
        #expect(draw.related.repos.count == 1)
    }

    @Test
    func canonicalProfilesAreStable() {
        let profiles = CubeOracleCardProfile.all
        #expect(profiles.count == 27)
        #expect(profiles.first?.cardId == "CARD:001")
        #expect(profiles.last?.cardId == "CARD:027")

        let card = CubeCard(
            id: "CARD:014",
            cellIndex: 14,
            cubeCell: .init(what: "surface", where_: "external", when: "current"),
            title: "The Relay",
            subtitle: "Informatie beweegt snel.",
            keywords: [],
            ordinal: .init(inscriptionHint: "x", contentHash: "sha256:test", artifactRef: nil),
            sound: .init(soundId: "SND:014", preset: "glitch-echo", params: [:])
        )
        let profile = CubeOracleCardProfile.profile(for: card)
        #expect(profile?.title == "The Relay")
        #expect(profile?.symbol == "🔁")
    }
}
