import Foundation

@MainActor
final class CubeOracleViewModel: ObservableObject {
    private static let localDefaultPort = 19001
    @Published var cards: [CubeCard] = []
    @Published var currentCard: CubeCard?
    @Published var soundProfile: SoundProfile?
    @Published var hotspots: [Hotspot] = []
    @Published var clusters: [ClusterSummary] = []
    @Published var topics: [TopicItem] = []
    @Published var selectedTopic: TopicItem?
    @Published var related: CubeRelatedResources = .empty
    @Published var suggestedCards: [CubeCard] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private struct ResolvedGateway {
        let host: String
        let port: Int
        let token: String
        let useFixture: Bool
    }

    private var resolved: ResolvedGateway?

    func configure(gateway: GatewayManager, connection: GatewayConnection?) {
        let host = resolveHost(gateway: gateway, connection: connection)
        let port = resolvePort(gateway: gateway, connection: connection)

        if gateway.useMock || host.lowercased() == "mock" {
            resolved = ResolvedGateway(host: host, port: port, token: "mock", useFixture: true)
            return
        }

        if let token = resolveToken(host: host, port: port, gateway: gateway), !token.isEmpty {
            resolved = ResolvedGateway(host: host, port: port, token: token, useFixture: false)
        } else {
            resolved = nil
        }
    }

    func loadCards() async {
        guard let cfg = resolved else {
            applyFixtureIfNeeded()
            error = "Missing token"
            return
        }

        if cfg.useFixture {
            cards = fixtureCards()
            if currentCard == nil {
                currentCard = cards.first
                soundProfile = SoundProfile(preset: "glitch-echo", params: ["feedback": 0.4], volume: 0.8, pitchShift: 0)
            }
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await CubeOracleAPI.cards(host: cfg.host, port: cfg.port, token: cfg.token)
            cards = loaded.sorted { lhs, rhs in
                if lhs.cellIndex != rhs.cellIndex { return lhs.cellIndex < rhs.cellIndex }
                return lhs.id < rhs.id
            }
            if cards.isEmpty {
                cards = fixtureCards()
            }
            if currentCard == nil {
                currentCard = cards.first
            }
            error = nil
        } catch {
            applyFixtureIfNeeded()
            self.error = "Cards unavailable"
        }
    }

    func loadTopics() async {
        guard let cfg = resolved else {
            topics = fixtureTopics()
            error = "Missing token"
            return
        }

        if cfg.useFixture {
            topics = fixtureTopics()
            error = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await CubeOracleAPI.topics(host: cfg.host, port: cfg.port, token: cfg.token)
            topics = loaded.sorted {
                if $0.category != $1.category { return $0.category < $1.category }
                return $0.title < $1.title
            }
            error = nil
        } catch {
            if topics.isEmpty {
                topics = fixtureTopics()
            }
            self.error = "Topics unavailable"
        }
    }

    func drawCard(mode: String, topic: String?) async {
        guard let cfg = resolved else {
            drawFixtureCard(mode: mode, topic: topic)
            error = "Missing token"
            return
        }

        if cards.isEmpty {
            cards = fixtureCards()
        }

        if cfg.useFixture {
            drawFixtureCard(mode: mode, topic: topic)
            error = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await CubeOracleAPI.draw(host: cfg.host, port: cfg.port, token: cfg.token, mode: mode, topic: topic)
            currentCard = response.card
            soundProfile = response.soundProfile
            hotspots = response.hotspots.sorted {
                if $0.residue != $1.residue { return $0.residue > $1.residue }
                return $0.id < $1.id
            }
            clusters = response.clusters.sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.id < $1.id
            }
            related = response.related
            if !cards.contains(response.card) {
                cards.append(response.card)
                cards.sort { $0.id < $1.id }
            }
            error = nil
        } catch {
            drawFixtureCard(mode: mode, topic: topic)
            self.error = "Draw unavailable"
        }
    }

    func selectTopic(topicId: String) async {
        selectedTopic = topics.first(where: { $0.id == topicId })

        guard let cfg = resolved else {
            applyFixtureTopicSelection(topicId: topicId)
            error = "Missing token"
            return
        }

        if cfg.useFixture {
            applyFixtureTopicSelection(topicId: topicId)
            error = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await CubeOracleAPI.selectTopic(host: cfg.host, port: cfg.port, token: cfg.token, topicId: topicId)
            selectedTopic = response.topic
            hotspots = response.hotspots.sorted {
                if $0.residue != $1.residue { return $0.residue > $1.residue }
                return $0.id < $1.id
            }
            clusters = response.clusters.sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.id < $1.id
            }
            suggestedCards = response.suggestedCards.sorted { $0.id < $1.id }
            for card in suggestedCards where !cards.contains(card) {
                cards.append(card)
            }
            cards.sort { $0.id < $1.id }
            error = nil
        } catch {
            applyFixtureTopicSelection(topicId: topicId)
            self.error = "Topic select unavailable"
        }
    }

    func sharePayload() -> String {
        guard let card = currentCard else { return "🔮 Cube Oracle — no card" }
        let profile = CubeOracleCardProfile.profile(for: card)
        let cardTitle = profile?.title ?? card.title
        let shareLine = profile?.shareLine ?? card.subtitle
        let symbol = profile?.symbol ?? "🔮"
        let hotspot = hotspots.first(where: { $0.cellIndex == card.cellIndex }) ?? hotspots.first
        let residue = hotspot?.residue ?? 0
        let trend = hotspot?.trend ?? 0
        let trendSign = trend >= 0 ? "↑" : "↓"
        let topicTitle = selectedTopic?.title ?? "General"
        return """
🔮 Cube Oracle — \(symbol) \(cardTitle)
\(card.id)
Cell: \(card.cubeCell.what) / \(card.cubeCell.where_) / \(card.cubeCell.when) (index \(card.cellIndex))
Meaning: \(shareLine)
🔥 Topic: \(topicTitle)
📊 Residue score: \(String(format: "%.1f", residue)) (\(trendSign) \(String(format: "%+.1f", trend)))
#CubeOracle #CLASHD27
contentHash: \(card.ordinal.contentHash)
"""
    }

    func profile(for card: CubeCard) -> CubeOracleCardProfile? {
        CubeOracleCardProfile.profile(for: card)
    }

    private func drawFixtureCard(mode: String, topic: String?) {
        if cards.isEmpty {
            cards = fixtureCards()
        }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let seed: Int
        if mode == "day" {
            seed = day
        } else {
            let topicPart = topic ?? selectedTopic?.id ?? "cube"
            seed = stableHash("\(topicPart)|\(day)")
        }
        let idx = cards.isEmpty ? 0 : max(0, seed) % cards.count
        let card = cards[idx]
        currentCard = card
        soundProfile = SoundProfile(preset: card.sound.preset, params: card.sound.params, volume: 0.8, pitchShift: 0)
        hotspots = fixtureHotspots(for: card)
        clusters = fixtureClusters(for: card)
        related = fixtureRelated(for: card)
        suggestedCards = cards.filter { $0.cubeCell.what == card.cubeCell.what }.prefix(3).map { $0 }
    }

    private func applyFixtureIfNeeded() {
        if cards.isEmpty {
            cards = fixtureCards()
        }
        if topics.isEmpty {
            topics = fixtureTopics()
        }
        if currentCard == nil {
            drawFixtureCard(mode: "day", topic: nil)
        }
    }

    private func applyFixtureTopicSelection(topicId: String) {
        selectedTopic = topics.first(where: { $0.id == topicId })
        drawFixtureCard(mode: "block", topic: topicId)
    }

    private func resolveHost(gateway: GatewayManager, connection: GatewayConnection?) -> String {
        let runtimeHost = RuntimeConfig.shared.host?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let runtimeHost, !runtimeHost.isEmpty {
            return runtimeHost
        }

        if let host = connection?.host.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty {
            return host
        }

        let gatewayHost = gateway.host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !gatewayHost.isEmpty {
            return gatewayHost
        }
        return "localhost"
    }

    private func resolvePort(gateway: GatewayManager, connection: GatewayConnection?) -> Int {
        if let runtimePort = RuntimeConfig.shared.port, runtimePort > 0 {
            return runtimePort
        }
        if let p = connection?.port, p > 0 {
            return p
        }
        return gateway.port > 0 ? gateway.port : Self.localDefaultPort
    }

    private func resolveToken(host: String, port: Int, gateway: GatewayManager) -> String? {
        if let runtimeToken = RuntimeConfig.shared.token?.trimmingCharacters(in: .whitespacesAndNewlines),
           !runtimeToken.isEmpty {
            return runtimeToken
        }

        if let stored = KeychainHelper.load(for: "\(host):\(port)"), !stored.isEmpty {
            return stored
        }

        let normalizedHost = host.lowercased()
        if GatewayManager.isLocalDevelopmentHost(normalizedHost) {
            for candidatePort in GatewayManager.localDiscoveryPorts {
                if let candidate = KeychainHelper.load(for: "\(host):\(candidatePort)"), !candidate.isEmpty {
                    return candidate
                }
            }
        }

        if let gatewayToken = gateway.token?.trimmingCharacters(in: .whitespacesAndNewlines), !gatewayToken.isEmpty {
            return gatewayToken
        }

        return nil
    }

    private func fixtureCards() -> [CubeCard] {
        CubeOracleCardProfile.canonicalCards()
    }

    private func fixtureTopics() -> [TopicItem] {
        [
            TopicItem(id: "ai_agents", title: "AI Agents", category: "AI"),
            TopicItem(id: "bitcoin_security", title: "Bitcoin Security", category: "Security"),
            TopicItem(id: "taproot_scripts", title: "Taproot Scripts", category: "Crypto"),
            TopicItem(id: "distributed_systems", title: "Distributed Systems", category: "Tech"),
            TopicItem(id: "signal_theory", title: "Signal Theory", category: "Science")
        ]
    }

    private func fixtureHotspots(for card: CubeCard) -> [Hotspot] {
        let all = fixtureCards()
        func cell(for index: Int) -> CubeCell {
            all.first(where: { $0.cellIndex == index })?.cubeCell ?? card.cubeCell
        }
        let next = (card.cellIndex % 27) + 1
        let next2 = ((card.cellIndex + 1) % 27) + 1
        let prev = ((card.cellIndex + 25) % 27) + 1
        return [
            Hotspot(id: "CELL:\(card.cellIndex)", cellIndex: card.cellIndex, cubeCell: card.cubeCell, residue: 23.4, trend: 0.8),
            Hotspot(id: "CELL:\(next)", cellIndex: next, cubeCell: cell(for: next), residue: 18.1, trend: 0.5),
            Hotspot(id: "CELL:\(next2)", cellIndex: next2, cubeCell: cell(for: next2), residue: 12.9, trend: -0.3),
            Hotspot(id: "CELL:\(prev)", cellIndex: prev, cubeCell: cell(for: prev), residue: 11.4, trend: 0.1)
        ]
    }

    private func fixtureClusters(for card: CubeCard) -> [ClusterSummary] {
        let all = fixtureCards()
        func cell(for index: Int) -> CubeCell {
            all.first(where: { $0.cellIndex == index })?.cubeCell ?? card.cubeCell
        }
        let next = (card.cellIndex % 27) + 1
        let pivot = 14
        return [
            ClusterSummary(
                id: "CL:EMG:001",
                label: "consent × injection × payments",
                cellIndex: card.cellIndex,
                cubeCell: card.cubeCell,
                score: 0.91,
                signals: ["arxiv", "github", "clawhub"],
                nodes: ["n1", "n2", "n3"]
            ),
            ClusterSummary(
                id: "CL:EMG:002",
                label: "policy × audit",
                cellIndex: next,
                cubeCell: cell(for: next),
                score: 0.72,
                signals: ["repo", "audit"],
                nodes: ["n4", "n5"]
            ),
            ClusterSummary(
                id: "CL:EMG:003",
                label: "surface relay",
                cellIndex: pivot,
                cubeCell: cell(for: pivot),
                score: 0.61,
                signals: ["telegram", "rss"],
                nodes: ["n6"]
            )
        ]
    }

    private func fixtureRelated(for card: CubeCard) -> CubeRelatedResources {
        CubeRelatedResources(
            repos: [
                CubeRelatedItem(title: "agent-consent-framework", url: "https://github.com/example/agent-consent-framework")
            ],
            papers: [
                CubeRelatedItem(title: "Cross-channel prompt injection in multi-surface agents", url: "https://arxiv.org/abs/2501.00001")
            ],
            posts: [
                CubeRelatedItem(title: "CLASHD27 weekly note", url: "https://example.com/posts/clashd27-weekly")
            ]
        )
    }

    private func stableHash(_ text: String) -> Int {
        var value = 0
        for scalar in text.unicodeScalars {
            value = (value &* 31 &+ Int(scalar.value)) & 0x7fffffff
        }
        return value
    }
}
