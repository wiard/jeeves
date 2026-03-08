import Foundation
import Testing
@testable import jeeves

struct SafeClashBrowserFeedTests {

    @Test
    func decodeBrowserFeedEnvelopeAndMapCards() throws {
        let json = """
        {
          "ok": true,
          "feed": {
            "featured": [
              {
                "configId": "cfg-featured-1",
                "intentionId": "intent.featured",
                "title": "Research Signal Synthesizer",
                "description": "Curates research signals into governed summaries.",
                "domain": "research",
                "subdomain": "literature",
                "riskProfile": "medium",
                "certificationLevel": "gold",
                "rankingScore": 0.93,
                "benchmarkSummary": "benchmark 0.91",
                "benchmarkScore": 0.91,
                "model": "gpt-5-mini",
                "runtimeEnvelopeHash": "abc123456789",
                "certificateId": "CERT:001",
                "benchmarkContractId": "BC:001",
                "deployReady": true,
                "rankingExplanation": "High reliability with low variance."
              }
            ],
            "categories": [
              {
                "id": "research",
                "title": "Research",
                "domain": "research",
                "subdomains": ["literature", "benchmarking"],
                "certifiedCount": 3,
                "emergingCount": 2
              }
            ],
            "certified": [
              {
                "configId": "cfg-certified-1",
                "intentionId": "intent.certified",
                "title": "Policy Sentinel",
                "description": "Monitors policy drift and proposes mitigations.",
                "domain": "operations",
                "subdomain": "workflow",
                "riskProfile": "low",
                "certificationLevel": "silver",
                "rankingScore": 0.88,
                "benchmarkScore": 0.85,
                "model": "gpt-5-mini",
                "deployReady": false
              }
            ],
            "emerging": [
              {
                "intentionId": "intent.emerging",
                "title": "Quantum Incident Watch",
                "description": "Tracks post-quantum migration discussions.",
                "domain": "security",
                "subdomain": "incident-response",
                "confidenceScore": 0.72,
                "sourceSummary": "OpenAlex + arXiv signal convergence",
                "sourceClusters": ["openalex.security", "arxiv.crypto"],
                "linkedCells": ["architecture|engine|emerging"],
                "relatedIncomingToolCount": 2,
                "certifiedConfigurationExists": false,
                "state": "emerging"
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(SafeClashBrowserFeedEnvelope.self, from: json)
        let feed = try #require(envelope.resolved)

        #expect(feed.featured.count == 1)
        #expect(feed.categories.count == 1)
        #expect(feed.certified.count == 1)
        #expect(feed.emerging.count == 1)

        let featuredCard = BrowserCard(certified: try #require(feed.featured.first))
        #expect(featuredCard.deployReady == true)
        #expect(featuredCard.certificateReference == "CERT:001")

        let certifiedCard = BrowserCard(certified: try #require(feed.certified.first))
        #expect(certifiedCard.deployReady == false)
        #expect(certifiedCard.intentionPath == "operations / workflow / low")

        let emerging = try #require(feed.emerging.first).profile
        #expect(emerging.title == "Quantum Incident Watch")
        #expect(emerging.sourceClusters == ["openalex.security", "arxiv.crypto"])
    }
}
