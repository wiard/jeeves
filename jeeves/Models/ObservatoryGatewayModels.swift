import Foundation

struct FabricClockState: Decodable, Sendable {
    let source: String
    let tickN: Int
    let height: Int?
    let timeIso: String?
    let degraded: Bool
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case source
        case tickN
        case height
        case blockHeight
        case timeIso
        case degraded
        case error
    }

    init(source: String, tickN: Int, height: Int?, timeIso: String?, degraded: Bool, error: String?) {
        self.source = source
        self.tickN = tickN
        self.height = height
        self.timeIso = timeIso
        self.degraded = degraded
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "sim"
        tickN = try c.decodeIfPresent(Int.self, forKey: .tickN) ?? 0
        height = try c.decodeIfPresent(Int.self, forKey: .height) ?? c.decodeIfPresent(Int.self, forKey: .blockHeight)
        timeIso = try c.decodeIfPresent(String.self, forKey: .timeIso)
        degraded = try c.decodeIfPresent(Bool.self, forKey: .degraded) ?? false
        error = try c.decodeIfPresent(String.self, forKey: .error)
    }

    static let empty = FabricClockState(
        source: "sim",
        tickN: 0,
        height: nil,
        timeIso: nil,
        degraded: false,
        error: nil
    )
}

struct FabricEmergenceRoute: Decodable, Sendable, Identifiable {
    let start: Int
    let path: [Int]
    let totalScore: Double

    var id: String {
        "\(start)|\(path.map(String.init).joined(separator: "-"))|\(String(format: "%.6f", totalScore))"
    }

    private enum CodingKeys: String, CodingKey {
        case start
        case path
        case totalScore
    }

    init(start: Int, path: [Int], totalScore: Double) {
        self.start = start
        self.path = path
        self.totalScore = totalScore
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        start = try c.decodeIfPresent(Int.self, forKey: .start) ?? 0
        path = try c.decodeIfPresent([Int].self, forKey: .path) ?? []
        totalScore = try c.decodeIfPresent(Double.self, forKey: .totalScore) ?? 0
    }
}

struct FabricEmergenceCluster: Decodable, Sendable, Identifiable {
    let kind: String
    let cells: [Int]
    let totalScore: Double
    let summary: String

    var id: String {
        "\(kind)|\(cells.map(String.init).joined(separator: "-"))"
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case cells
        case totalScore
        case summary
    }

    init(kind: String, cells: [Int], totalScore: Double, summary: String) {
        self.kind = kind
        self.cells = cells
        self.totalScore = totalScore
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "unknown"
        cells = try c.decodeIfPresent([Int].self, forKey: .cells) ?? []
        totalScore = try c.decodeIfPresent(Double.self, forKey: .totalScore) ?? 0
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
    }
}

struct FabricEmergenceResponse: Decodable, Sendable {
    let clock: FabricClockState
    let heatmap: String
    let topRoutes: [FabricEmergenceRoute]
    let suggestions: [String]
    let clusters: [FabricEmergenceCluster]
    let knowledgeHitsToday: Int
    let knowledgeTopCubeAddresses: [String]

    private enum CodingKeys: String, CodingKey {
        case clock
        case heatmap
        case topRoutes
        case suggestions
        case clusters
        case knowledgeHitsToday
        case knowledgeTopCubeAddresses
    }

    init(
        clock: FabricClockState,
        heatmap: String,
        topRoutes: [FabricEmergenceRoute],
        suggestions: [String],
        clusters: [FabricEmergenceCluster],
        knowledgeHitsToday: Int,
        knowledgeTopCubeAddresses: [String]
    ) {
        self.clock = clock
        self.heatmap = heatmap
        self.topRoutes = topRoutes
        self.suggestions = suggestions
        self.clusters = clusters
        self.knowledgeHitsToday = knowledgeHitsToday
        self.knowledgeTopCubeAddresses = knowledgeTopCubeAddresses
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clock = try c.decodeIfPresent(FabricClockState.self, forKey: .clock) ?? .empty
        heatmap = try c.decodeIfPresent(String.self, forKey: .heatmap) ?? ""
        topRoutes = try c.decodeIfPresent([FabricEmergenceRoute].self, forKey: .topRoutes) ?? []
        suggestions = try c.decodeIfPresent([String].self, forKey: .suggestions) ?? []
        clusters = try c.decodeIfPresent([FabricEmergenceCluster].self, forKey: .clusters) ?? []
        knowledgeHitsToday = try c.decodeIfPresent(Int.self, forKey: .knowledgeHitsToday) ?? 0
        knowledgeTopCubeAddresses = try c.decodeIfPresent([String].self, forKey: .knowledgeTopCubeAddresses) ?? []
    }

    static let empty = FabricEmergenceResponse(
        clock: .empty,
        heatmap: "",
        topRoutes: [],
        suggestions: [],
        clusters: [],
        knowledgeHitsToday: 0,
        knowledgeTopCubeAddresses: []
    )
}

struct FabricTopCell: Decodable, Sendable, Identifiable {
    let cell: Int
    let score: Double
    let events: Int
    let lastTickN: Int?

    var id: Int { cell }
}

struct FabricStateSummaryResponse: Decodable, Sendable {
    let tickN: Int
    let activeCell: Int
    let clockSource: String
    let topCells: [FabricTopCell]

    private enum CodingKeys: String, CodingKey {
        case tickN
        case activeCell
        case clockSource
        case topCells
    }

    init(tickN: Int, activeCell: Int, clockSource: String, topCells: [FabricTopCell]) {
        self.tickN = tickN
        self.activeCell = activeCell
        self.clockSource = clockSource
        self.topCells = topCells
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tickN = try c.decodeIfPresent(Int.self, forKey: .tickN) ?? 0
        activeCell = try c.decodeIfPresent(Int.self, forKey: .activeCell) ?? 0
        clockSource = try c.decodeIfPresent(String.self, forKey: .clockSource) ?? "sim"
        topCells = try c.decodeIfPresent([FabricTopCell].self, forKey: .topCells) ?? []
    }

    static let empty = FabricStateSummaryResponse(
        tickN: 0,
        activeCell: 0,
        clockSource: "sim",
        topCells: []
    )
}

struct LobbyChallengeItem: Decodable, Sendable, Identifiable {
    let challengeId: String
    let createdAtIso: String
    let title: String
    let description: String
    let domain: String
    let suggestedIntentKey: String
    let maxRisk: String
    let status: String
    let claimedByAgentId: String?

    var id: String { challengeId }
}

struct OpenclawSkillMarkers: Decodable, Sendable {
    let secrets: Int
    let writes: Int
    let externalIO: Int
    let consentWords: Int
}

struct OpenclawSkillCubePosition: Decodable, Sendable {
    let wat: String
    let waar: String
    let wanneer: String
}

struct OpenclawSkillResult: Decodable, Sendable, Identifiable {
    let skillName: String
    let fileCountScanned: Int
    let markersFound: OpenclawSkillMarkers
    let cubePosition: OpenclawSkillCubePosition
    let residueValue: Double

    var id: String { skillName }
}

struct OpenclawHotCellSummary: Decodable, Sendable, Identifiable {
    let cubeAddress: String
    let count: Int
    let sumResidue: Double
    let topSkills: [String]
    let hasAnomaly: Bool

    var id: String { cubeAddress }
}

struct OpenclawSkillsSummary: Decodable, Sendable {
    let generatedAtIso: String
    let totalSkillsScanned: Int
    let topSkillsByResidue: [OpenclawSkillResult]
    let hotCells: [OpenclawHotCellSummary]
    let anomalies: [OpenclawSkillResult]

    private enum CodingKeys: String, CodingKey {
        case generatedAtIso
        case totalSkillsScanned
        case topSkillsByResidue
        case hotCells
        case anomalies
    }

    init(
        generatedAtIso: String,
        totalSkillsScanned: Int,
        topSkillsByResidue: [OpenclawSkillResult],
        hotCells: [OpenclawHotCellSummary],
        anomalies: [OpenclawSkillResult]
    ) {
        self.generatedAtIso = generatedAtIso
        self.totalSkillsScanned = totalSkillsScanned
        self.topSkillsByResidue = topSkillsByResidue
        self.hotCells = hotCells
        self.anomalies = anomalies
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAtIso = try c.decodeIfPresent(String.self, forKey: .generatedAtIso) ?? ""
        totalSkillsScanned = try c.decodeIfPresent(Int.self, forKey: .totalSkillsScanned) ?? 0
        topSkillsByResidue = try c.decodeIfPresent([OpenclawSkillResult].self, forKey: .topSkillsByResidue) ?? []
        hotCells = try c.decodeIfPresent([OpenclawHotCellSummary].self, forKey: .hotCells) ?? []
        anomalies = try c.decodeIfPresent([OpenclawSkillResult].self, forKey: .anomalies) ?? []
    }

    static let empty = OpenclawSkillsSummary(
        generatedAtIso: "",
        totalSkillsScanned: 0,
        topSkillsByResidue: [],
        hotCells: [],
        anomalies: []
    )
}

struct ObservatoryAlertCube: Decodable, Sendable {
    let a1: String
    let a2: String
    let a3: String
    let cell: Int
}

struct ObservatoryAlertEvidence: Decodable, Sendable {
    let sources: [String]
}

struct ObservatoryAlertItem: Decodable, Sendable, Identifiable {
    let alertId: String
    let kind: String
    let severity: String
    let title: String
    let summary: String
    let cube: ObservatoryAlertCube
    let evidence: ObservatoryAlertEvidence
    let recommendedAction: String
    let escalatedAtIso: String?

    var id: String { alertId }
}

struct ObservatoryAlertsResponse: Decodable, Sendable {
    let updatedAtIso: String
    let alerts: [ObservatoryAlertItem]

    private enum CodingKeys: String, CodingKey {
        case updatedAtIso
        case alerts
    }

    init(updatedAtIso: String, alerts: [ObservatoryAlertItem]) {
        self.updatedAtIso = updatedAtIso
        self.alerts = alerts
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAtIso = try c.decodeIfPresent(String.self, forKey: .updatedAtIso) ?? ""
        alerts = try c.decodeIfPresent([ObservatoryAlertItem].self, forKey: .alerts) ?? []
    }

    static let empty = ObservatoryAlertsResponse(updatedAtIso: "", alerts: [])
}

struct ObservatoryGatewayBundle: Sendable {
    let clock: FabricClockState
    let emergence: FabricEmergenceResponse
    let fabricState: FabricStateSummaryResponse
    let challenges: [LobbyChallengeItem]
    let openclawSummary: OpenclawSkillsSummary
    let alerts: ObservatoryAlertsResponse
    let fetchedAt: Date
}

struct LobbyChallengeBuckets: Sendable, Equatable {
    let open: Int
    let claimed: Int
    let completed: Int
}

enum ObservatoryAggregation {
    static func sortedChallenges(_ challenges: [LobbyChallengeItem]) -> [LobbyChallengeItem] {
        challenges.sorted { left, right in
            let leftRank = statusRank(left.status)
            let rightRank = statusRank(right.status)
            if leftRank != rightRank {
                return leftRank < rightRank
            }
            if left.createdAtIso != right.createdAtIso {
                return left.createdAtIso < right.createdAtIso
            }
            return left.challengeId < right.challengeId
        }
    }

    static func challengeBuckets(_ challenges: [LobbyChallengeItem]) -> LobbyChallengeBuckets {
        var open = 0
        var claimed = 0
        var completed = 0

        for challenge in challenges {
            switch challenge.status {
            case "open":
                open += 1
            case "claimed":
                claimed += 1
            case "completed":
                completed += 1
            default:
                break
            }
        }

        return LobbyChallengeBuckets(open: open, claimed: claimed, completed: completed)
    }

    static func clusterKinds(_ clusters: [FabricEmergenceCluster]) -> [String] {
        let grouped = Dictionary(grouping: clusters, by: { $0.kind })
        return grouped
            .map { key, value in
                "\(key):\(value.count)"
            }
            .sorted()
    }

    static func topCluster(_ clusters: [FabricEmergenceCluster]) -> FabricEmergenceCluster? {
        clusters.sorted { left, right in
            if left.totalScore != right.totalScore {
                return left.totalScore > right.totalScore
            }
            if left.cells.count != right.cells.count {
                return left.cells.count > right.cells.count
            }
            return left.id < right.id
        }.first
    }

    static func watCounts(_ skills: [OpenclawSkillResult]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for skill in skills {
            counts[skill.cubePosition.wat, default: 0] += 1
        }
        return counts
    }

    private static func statusRank(_ status: String) -> Int {
        switch status {
        case "open":
            return 0
        case "claimed":
            return 1
        case "completed":
            return 2
        default:
            return 3
        }
    }
}
