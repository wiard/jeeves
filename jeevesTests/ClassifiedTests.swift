import Foundation
import Testing
@testable import jeeves

@MainActor
struct ClassifiedTests {

    // MARK: - Model Decoding

    @Test
    func classifiedDiscoveryDecodesCorrectly() throws {
        let json = """
        {
            "classified": [
                {
                    "candidateId": "cd-001",
                    "outcomeType": "GAP",
                    "domainType": "dual",
                    "candidateScore": 2.36,
                    "axes": [
                        { "what": "oncologie", "where": "NL", "time": "2026-Q1" },
                        { "what": "AI-diagnostiek", "where": "EU", "time": "2026-Q2" }
                    ],
                    "explanation": "Sterke kruising tussen oncologie en AI-diagnostiek.",
                    "residueWeight": 0.78,
                    "signalDensity": 0.65,
                    "sources": ["pubmed", "arxiv"],
                    "crossDomain": true
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ClassifiedResponse.self, from: json)
        #expect(response.classified.count == 1)

        let item = response.classified[0]
        #expect(item.candidateId == "cd-001")
        #expect(item.outcomeType == "GAP")
        #expect(item.domainType == "dual")
        #expect(item.candidateScore == 2.36)
        #expect(item.axes.count == 2)
        #expect(item.axes[0].what == "oncologie")
        #expect(item.axes[0].where_ == "NL")
        #expect(item.axes[1].what == "AI-diagnostiek")
        #expect(item.crossDomain == true)
        #expect(item.sources == ["pubmed", "arxiv"])
    }

    // MARK: - Filter Logic

    @Test
    func filterLogicFiltersByOutcomeType() {
        let viewModel = ClassifiedViewModel()
        viewModel.items = [
            makeDiscovery(id: "1", outcome: "GAP"),
            makeDiscovery(id: "2", outcome: "DISCOVERY"),
            makeDiscovery(id: "3", outcome: "GAP"),
            makeDiscovery(id: "4", outcome: "SURE_WIN"),
        ]

        viewModel.activeFilter = "ALLE"
        #expect(viewModel.filtered.count == 4)

        viewModel.activeFilter = "GAP"
        #expect(viewModel.filtered.count == 2)
        #expect(viewModel.filtered.allSatisfy { $0.outcomeType == "GAP" })

        viewModel.activeFilter = "SURE_WIN"
        #expect(viewModel.filtered.count == 1)

        viewModel.activeFilter = "SURPRISE"
        #expect(viewModel.filtered.isEmpty)
    }

    // MARK: - Intent Parsing

    @Test
    func kanaalIntentParsingClassified() {
        #expect(JeevesKanaalViewModel.parseIntent(from: "toon ontdekkingen") == .classified)
        #expect(JeevesKanaalViewModel.parseIntent(from: "wat zijn gaps") == .classifiedGaps)
    }

    // MARK: - Helpers

    private func makeDiscovery(id: String, outcome: String) -> ClassifiedDiscovery {
        ClassifiedDiscovery(
            candidateId: id,
            outcomeType: outcome,
            domainType: "single",
            candidateScore: 1.0,
            axes: [DiscoveryAxis(what: "test", where_: "NL", time: "2026-Q1")],
            explanation: "Test discovery",
            residueWeight: 0.5,
            signalDensity: 0.5,
            sources: ["test"],
            crossDomain: false
        )
    }
}
