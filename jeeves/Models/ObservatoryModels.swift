import Foundation

struct ObservatoryDashboardSnapshot: Sendable {
    let conductor: ConductorState?
    let alerts: [ObservatoryAlert]
    let fabricClock: FabricClockState?
    let fabricEmergence: FabricEmergence?
    let lobbyOpenChallenges: [LobbyChallenge]
    let signals: SignalsState?
    let knowledgeStatus: KnowledgeStatus?
    let knowledgeEmergence: KnowledgeEmergence?
    let fetchedAt: Date
}

struct ObservatoryAlert: Decodable, Sendable, Identifiable {
    let id: String
    let title: String?
    let summary: String?
    let timestampIso: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case alertId
        case title
        case summary
        case message
        case timestampIso
        case timestamp
        case escalatedAtIso
        case createdAtIso
    }

    init(id: String, title: String?, summary: String?, timestampIso: String?) {
        self.id = id
        self.title = title
        self.summary = summary
        self.timestampIso = timestampIso
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
            ?? c.decodeIfPresent(String.self, forKey: .alertId)
            ?? UUID().uuidString
        title = try c.decodeIfPresent(String.self, forKey: .title)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
            ?? c.decodeIfPresent(String.self, forKey: .message)
        timestampIso = try c.decodeIfPresent(String.self, forKey: .timestampIso)
            ?? c.decodeIfPresent(String.self, forKey: .timestamp)
            ?? c.decodeIfPresent(String.self, forKey: .escalatedAtIso)
            ?? c.decodeIfPresent(String.self, forKey: .createdAtIso)
    }
}

struct FabricEmergence: Decodable, Sendable {
    let strongestCell: String?
    let warmLayer: String?
    let suggestions: [String]
    let clusters: [KnowledgeEmergenceCluster]

    private enum CodingKeys: String, CodingKey {
        case strongestCell
        case warmLayer
        case suggestions
        case clusters
    }

    init(strongestCell: String?, warmLayer: String?, suggestions: [String], clusters: [KnowledgeEmergenceCluster]) {
        self.strongestCell = strongestCell
        self.warmLayer = warmLayer
        self.suggestions = suggestions
        self.clusters = clusters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        strongestCell = try c.decodeIfPresent(String.self, forKey: .strongestCell)
        warmLayer = try c.decodeIfPresent(String.self, forKey: .warmLayer)
        suggestions = try c.decodeIfPresent([String].self, forKey: .suggestions) ?? []
        clusters = try c.decodeIfPresent([KnowledgeEmergenceCluster].self, forKey: .clusters) ?? []
    }
}

struct LobbyChallenge: Decodable, Sendable, Identifiable {
    let id: String
    let title: String?
    let key: String?
    let createdAtIso: String?
    let status: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case challengeId
        case title
        case key
        case suggestedIntentKey
        case createdAtIso
        case status
    }

    init(id: String, title: String?, key: String?, createdAtIso: String?, status: String?) {
        self.id = id
        self.title = title
        self.key = key
        self.createdAtIso = createdAtIso
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
            ?? c.decodeIfPresent(String.self, forKey: .challengeId)
            ?? UUID().uuidString
        title = try c.decodeIfPresent(String.self, forKey: .title)
        key = try c.decodeIfPresent(String.self, forKey: .key)
            ?? c.decodeIfPresent(String.self, forKey: .suggestedIntentKey)
        createdAtIso = try c.decodeIfPresent(String.self, forKey: .createdAtIso)
        status = try c.decodeIfPresent(String.self, forKey: .status)
    }
}

struct SignalsState: Decodable, Sendable {
    let signalsToday: Int?
    let challengesToday: Int?
    let proposalsToday: Int?
    let executedActions: Int?

    private enum CodingKeys: String, CodingKey {
        case signalsToday
        case challengesToday
        case proposalsToday
        case executedActions
        case signals
        case challenges
        case proposals
        case executed
    }

    init(signalsToday: Int?, challengesToday: Int?, proposalsToday: Int?, executedActions: Int?) {
        self.signalsToday = signalsToday
        self.challengesToday = challengesToday
        self.proposalsToday = proposalsToday
        self.executedActions = executedActions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        signalsToday = try c.decodeIfPresent(Int.self, forKey: .signalsToday)
            ?? c.decodeIfPresent(Int.self, forKey: .signals)
        challengesToday = try c.decodeIfPresent(Int.self, forKey: .challengesToday)
            ?? c.decodeIfPresent(Int.self, forKey: .challenges)
        proposalsToday = try c.decodeIfPresent(Int.self, forKey: .proposalsToday)
            ?? c.decodeIfPresent(Int.self, forKey: .proposals)
        executedActions = try c.decodeIfPresent(Int.self, forKey: .executedActions)
            ?? c.decodeIfPresent(Int.self, forKey: .executed)
    }
}

struct KnowledgeEmergence: Decodable, Sendable {
    let clusters: [KnowledgeEmergenceCluster]

    private enum CodingKeys: String, CodingKey {
        case clusters
    }

    init(clusters: [KnowledgeEmergenceCluster]) {
        self.clusters = clusters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clusters = try c.decodeIfPresent([KnowledgeEmergenceCluster].self, forKey: .clusters) ?? []
    }
}

struct KnowledgeEmergenceCluster: Decodable, Sendable, Identifiable {
    let id: String
    let summary: String?
    let score: Double?

    private enum CodingKeys: String, CodingKey {
        case id
        case clusterId
        case summary
        case score
        case relevanceScore
        case densityScore
    }

    init(id: String, summary: String?, score: Double?) {
        self.id = id
        self.summary = summary
        self.score = score
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
            ?? c.decodeIfPresent(String.self, forKey: .clusterId)
            ?? UUID().uuidString
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        score = try c.decodeIfPresent(Double.self, forKey: .score)
            ?? c.decodeIfPresent(Double.self, forKey: .relevanceScore)
            ?? c.decodeIfPresent(Double.self, forKey: .densityScore)
    }
}

struct CubePosition: Hashable, Codable, Sendable {
    let x: Int
    let y: Int
    let z: Int

    init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    var id: String { "\(x)-\(y)-\(z)" }
}

struct ClashdCell: Identifiable, Sendable {
    let position: CubePosition
    let residue: Double
    let highlightedClusterId: String?
    let routeArrows: [String]

    var id: String { position.id }
}

struct ClashdRoute: Identifiable, Sendable {
    let id: String
    let from: CubePosition
    let to: CubePosition
    let strength: Double
}

struct KnowledgeCollisionCluster: Identifiable, Sendable {
    let clusterId: String
    let sourceTypes: [String]
    let densityScore: Double
    let cubePosition: CubePosition
    let summary: String
    let isEmergence: Bool

    var id: String { clusterId }
}

struct LoopMetrics: Sendable {
    let lastCycleDuration: TimeInterval
    let averageCycleDuration: TimeInterval
    let signalsToday: Int
    let challengesToday: Int
    let proposalsToday: Int
    let executedActions: Int

    static let empty = LoopMetrics(
        lastCycleDuration: 0,
        averageCycleDuration: 0,
        signalsToday: 0,
        challengesToday: 0,
        proposalsToday: 0,
        executedActions: 0
    )
}

enum JeevesDecisionKind: String, Sendable {
    case autoApproved = "auto-approved"
    case autoDenied = "auto-denied"
    case escalated = "escalated"
}

struct JeevesDecisionEvent: Identifiable, Sendable {
    let id: String
    let kind: JeevesDecisionKind
    let title: String
    let timestamp: Date
}

struct EmergenceAlert: Identifiable, Sendable {
    let id: String
    let title: String
    let summary: String
    let clusterId: String
    let timestamp: Date

    static func fromCluster(_ cluster: KnowledgeCollisionCluster, now: Date = Date()) -> EmergenceAlert {
        EmergenceAlert(
            id: "alert-\(cluster.clusterId)",
            title: "Unexpected connection detected",
            summary: cluster.summary,
            clusterId: cluster.clusterId,
            timestamp: now
        )
    }
}

struct ClashdCubeField: Sendable {
    let cells: [ClashdCell]
    let activeRoutes: [ClashdRoute]
    let clusters: [KnowledgeCollisionCluster]

    static let empty = ClashdCubeField(cells: [], activeRoutes: [], clusters: [])
}

struct ObservatorySnapshot: Sendable {
    let loop: LoopMetrics
    let field: ClashdCubeField
    let collisions: [KnowledgeCollisionCluster]
    let decisions: [JeevesDecisionEvent]
    let updatedAt: Date

    static let empty = ObservatorySnapshot(
        loop: .empty,
        field: .empty,
        collisions: [],
        decisions: [],
        updatedAt: Date()
    )

    static func demo(tick: Int, now: Date = Date()) -> ObservatorySnapshot {
        let clusters = [
            KnowledgeCollisionCluster(
                clusterId: "demo-\(tick)",
                sourceTypes: ["signal", "knowledge"],
                densityScore: 0.6,
                cubePosition: CubePosition(x: 1, y: 1, z: 1),
                summary: "Demo cluster",
                isEmergence: tick % 2 == 0
            )
        ]

        let cells = (0..<27).map { index in
            ClashdCell(
                position: CubePosition(x: index % 3, y: (index / 3) % 3, z: (index / 9) % 3),
                residue: Double(index % 10) / 10.0,
                highlightedClusterId: nil,
                routeArrows: []
            )
        }

        let decisions = [
            JeevesDecisionEvent(
                id: "decision-\(tick)",
                kind: tick % 2 == 0 ? .escalated : .autoApproved,
                title: "Demo decision",
                timestamp: now
            )
        ]

        return ObservatorySnapshot(
            loop: LoopMetrics(
                lastCycleDuration: 5.0,
                averageCycleDuration: 6.0,
                signalsToday: 10 + tick,
                challengesToday: 2,
                proposalsToday: 3,
                executedActions: 1
            ),
            field: ClashdCubeField(cells: cells, activeRoutes: [], clusters: clusters),
            collisions: clusters,
            decisions: decisions,
            updatedAt: now
        )
    }
}
