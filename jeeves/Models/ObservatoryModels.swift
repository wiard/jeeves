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
    let stream: ObservatoryStreamFeed?
    let radarStatus: RadarStatusSnapshot?
    let radarActivations: [RadarActivation]
    let radarCollisions: [RadarCollision]
    let radarEmergence: [RadarCollision]
    let radarClusters: [RadarClusterSummary]
    let radarSources: [RadarSourceStats]
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

struct ObservatoryStreamFeed: Decodable, Sendable {
    let ok: Bool?
    let events: [ObservatoryStreamEvent]
    let pendingCount: Int

    private enum CodingKeys: String, CodingKey {
        case ok
        case events
        case items
        case data
        case pendingCount
    }

    init(ok: Bool?, events: [ObservatoryStreamEvent], pendingCount: Int) {
        self.ok = ok
        self.events = events
        self.pendingCount = pendingCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        events = try c.decodeIfPresent([ObservatoryStreamEvent].self, forKey: .events)
            ?? c.decodeIfPresent([ObservatoryStreamEvent].self, forKey: .items)
            ?? c.decodeIfPresent([ObservatoryStreamEvent].self, forKey: .data)
            ?? []
        pendingCount = try c.decodeIfPresent(Int.self, forKey: .pendingCount) ?? 0
    }
}

struct ObservatoryStreamEvent: Decodable, Sendable, Identifiable {
    let id: String
    let type: String
    let timestampIso: String?
    let event: String?
    let proposalId: String?
    let agentId: String?
    let title: String?
    let decision: String?
    let reason: String?
    let risk: String?
    let peerId: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case eventId
        case type
        case timestampIso
        case timestamp
        case event
        case proposalId
        case agentId
        case title
        case decision
        case reason
        case risk
        case peerId
    }

    init(
        id: String,
        type: String,
        timestampIso: String?,
        event: String?,
        proposalId: String?,
        agentId: String?,
        title: String?,
        decision: String?,
        reason: String?,
        risk: String?,
        peerId: String?
    ) {
        self.id = id
        self.type = type
        self.timestampIso = timestampIso
        self.event = event
        self.proposalId = proposalId
        self.agentId = agentId
        self.title = title
        self.decision = decision
        self.reason = reason
        self.risk = risk
        self.peerId = peerId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "event"
        timestampIso = try c.decodeIfPresent(String.self, forKey: .timestampIso)
            ?? c.decodeIfPresent(String.self, forKey: .timestamp)
        event = try c.decodeIfPresent(String.self, forKey: .event)
        proposalId = try c.decodeIfPresent(String.self, forKey: .proposalId)
        agentId = try c.decodeIfPresent(String.self, forKey: .agentId)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        decision = try c.decodeIfPresent(String.self, forKey: .decision)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        risk = try c.decodeIfPresent(String.self, forKey: .risk)
        peerId = try c.decodeIfPresent(String.self, forKey: .peerId)

        id = try c.decodeIfPresent(String.self, forKey: .id)
            ?? c.decodeIfPresent(String.self, forKey: .eventId)
            ?? [
                type,
                timestampIso ?? "",
                proposalId ?? "",
                event ?? "",
                agentId ?? "",
                decision ?? "",
                reason ?? ""
            ].joined(separator: "|")
    }
}

struct RadarStatusSnapshot: Decodable, Sendable {
    let store: RadarStoreStatus?
    let collector: RadarCollectorStatus?
}

struct RadarStoreStatus: Decodable, Sendable {
    let activationCount: Int
    let collisionCount: Int
    let emergenceCount: Int
    let lastFetchBySource: [String: String]
    let hotClusters: [RadarHotCluster]
    let topSignals: [RadarTopSignal]

    private enum CodingKeys: String, CodingKey {
        case activationCount
        case collisionCount
        case emergenceCount
        case lastFetchBySource
        case hotClusters
        case topSignals
    }

    init(
        activationCount: Int,
        collisionCount: Int,
        emergenceCount: Int,
        lastFetchBySource: [String: String],
        hotClusters: [RadarHotCluster],
        topSignals: [RadarTopSignal]
    ) {
        self.activationCount = activationCount
        self.collisionCount = collisionCount
        self.emergenceCount = emergenceCount
        self.lastFetchBySource = lastFetchBySource
        self.hotClusters = hotClusters
        self.topSignals = topSignals
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activationCount = try c.decodeIfPresent(Int.self, forKey: .activationCount) ?? 0
        collisionCount = try c.decodeIfPresent(Int.self, forKey: .collisionCount) ?? 0
        emergenceCount = try c.decodeIfPresent(Int.self, forKey: .emergenceCount) ?? 0
        lastFetchBySource = try c.decodeIfPresent([String: String].self, forKey: .lastFetchBySource) ?? [:]
        hotClusters = try c.decodeIfPresent([RadarHotCluster].self, forKey: .hotClusters) ?? []
        topSignals = try c.decodeIfPresent([RadarTopSignal].self, forKey: .topSignals) ?? []
    }
}

struct RadarCollectorStatus: Decodable, Sendable {
    let isRunning: Bool
    let lastRun: String?

    private enum CodingKeys: String, CodingKey {
        case isRunning
        case lastRun
    }

    init(isRunning: Bool, lastRun: String?) {
        self.isRunning = isRunning
        self.lastRun = lastRun
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isRunning = try c.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false
        lastRun = try c.decodeIfPresent(String.self, forKey: .lastRun)
    }
}

struct RadarHotCluster: Decodable, Sendable, Identifiable {
    let cluster: String
    let count: Int

    var id: String { cluster }

    private enum CodingKeys: String, CodingKey {
        case cluster
        case count
    }

    init(cluster: String, count: Int) {
        self.cluster = cluster
        self.count = count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cluster = try c.decodeIfPresent(String.self, forKey: .cluster) ?? "unknown"
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

struct RadarTopSignal: Decodable, Sendable, Identifiable {
    let title: String
    let source: String
    let residue: Double

    var id: String { "\(source)|\(title)" }

    private enum CodingKeys: String, CodingKey {
        case title
        case source
        case residue
    }

    init(title: String, source: String, residue: Double) {
        self.title = title
        self.source = source
        self.residue = residue
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled signal"
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "unknown"
        residue = try c.decodeIfPresent(Double.self, forKey: .residue) ?? 0
    }
}

struct RadarActivation: Decodable, Sendable, Identifiable {
    let id: String
    let source: String
    let title: String
    let summary: String
    let residue: Double
    let timestampIso: String?
    let clusters: [String]
    let cellIds: [String]

    private enum CodingKeys: String, CodingKey {
        case activationId
        case id
        case signal
        case source
        case title
        case summary
        case residue
        case residueValue
        case timestamp
        case timestampIso
        case activatedClusters
        case clusters
        case cells
    }

    private struct SignalPayload: Decodable {
        let source: String?
        let title: String?
        let summary: String?
        let fetchedAtIso: String?
        let timestamp: String?
    }

    private struct ClusterPayload: Decodable {
        let cluster: String?
        let label: String?
    }

    private struct CellPayload: Decodable {
        let cellId: String?
    }

    init(
        id: String,
        source: String,
        title: String,
        summary: String,
        residue: Double,
        timestampIso: String?,
        clusters: [String],
        cellIds: [String]
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.summary = summary
        self.residue = residue
        self.timestampIso = timestampIso
        self.clusters = clusters
        self.cellIds = cellIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let signal = try c.decodeIfPresent(SignalPayload.self, forKey: .signal)

        source = try c.decodeIfPresent(String.self, forKey: .source)
            ?? signal?.source
            ?? "unknown"
        title = try c.decodeIfPresent(String.self, forKey: .title)
            ?? signal?.title
            ?? "Untitled signal"
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
            ?? signal?.summary
            ?? ""
        residue = try c.decodeIfPresent(Double.self, forKey: .residueValue)
            ?? c.decodeIfPresent(Double.self, forKey: .residue)
            ?? 0
        timestampIso = try c.decodeIfPresent(String.self, forKey: .timestampIso)
            ?? c.decodeIfPresent(String.self, forKey: .timestamp)
            ?? signal?.fetchedAtIso
            ?? signal?.timestamp

        if let raw = (try? c.decodeIfPresent([String].self, forKey: .activatedClusters)) ?? nil {
            clusters = raw.sorted()
        } else if let raw = (try? c.decodeIfPresent([String].self, forKey: .clusters)) ?? nil {
            clusters = raw.sorted()
        } else if let raw = (try? c.decodeIfPresent([ClusterPayload].self, forKey: .clusters)) ?? nil {
            clusters = raw
                .compactMap { item in
                    let value = item.label ?? item.cluster
                    guard let value, !value.isEmpty else { return nil }
                    return value
                }
                .sorted()
        } else {
            clusters = []
        }

        if let raw = (try? c.decodeIfPresent([CellPayload].self, forKey: .cells)) ?? nil {
            cellIds = raw.compactMap(\.cellId).sorted()
        } else if let raw = (try? c.decodeIfPresent([String].self, forKey: .cells)) ?? nil {
            cellIds = raw.sorted()
        } else {
            cellIds = []
        }

        id = try c.decodeIfPresent(String.self, forKey: .activationId)
            ?? c.decodeIfPresent(String.self, forKey: .id)
            ?? "\(source)|\(title)|\(timestampIso ?? "")"
    }
}

struct RadarCollision: Decodable, Sendable, Identifiable {
    let id: String
    let sources: [String]
    let density: Double
    let isEmergence: Bool
    let detectedAtIso: String?
    let cellIds: [String]
    let signalTitles: [String]

    private enum CodingKeys: String, CodingKey {
        case collisionId
        case id
        case cells
        case signals
        case sources
        case density
        case score
        case densityScore
        case isEmergence
        case detectedAtIso
        case timestamp
    }

    private struct CellPayload: Decodable {
        let cellId: String?
    }

    private struct SignalPayload: Decodable {
        let signalId: String?
        let title: String?
    }

    init(
        id: String,
        sources: [String],
        density: Double,
        isEmergence: Bool,
        detectedAtIso: String?,
        cellIds: [String],
        signalTitles: [String]
    ) {
        self.id = id
        self.sources = sources
        self.density = density
        self.isEmergence = isEmergence
        self.detectedAtIso = detectedAtIso
        self.cellIds = cellIds
        self.signalTitles = signalTitles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sources = (try c.decodeIfPresent([String].self, forKey: .sources) ?? []).sorted()
        density = try c.decodeIfPresent(Double.self, forKey: .density)
            ?? c.decodeIfPresent(Double.self, forKey: .densityScore)
            ?? c.decodeIfPresent(Double.self, forKey: .score)
            ?? 0
        isEmergence = try c.decodeIfPresent(Bool.self, forKey: .isEmergence) ?? false
        detectedAtIso = try c.decodeIfPresent(String.self, forKey: .detectedAtIso)
            ?? c.decodeIfPresent(String.self, forKey: .timestamp)

        if let raw = (try? c.decodeIfPresent([CellPayload].self, forKey: .cells)) ?? nil {
            cellIds = raw.compactMap(\.cellId).sorted()
        } else if let raw = (try? c.decodeIfPresent([String].self, forKey: .cells)) ?? nil {
            cellIds = raw.sorted()
        } else {
            cellIds = []
        }

        if let raw = (try? c.decodeIfPresent([SignalPayload].self, forKey: .signals)) ?? nil {
            signalTitles = raw
                .compactMap { item in
                    let value = item.title ?? item.signalId
                    guard let value, !value.isEmpty else { return nil }
                    return value
                }
                .sorted()
        } else {
            signalTitles = []
        }

        id = try c.decodeIfPresent(String.self, forKey: .collisionId)
            ?? c.decodeIfPresent(String.self, forKey: .id)
            ?? "\(sources.joined(separator: ","))|\(cellIds.joined(separator: ","))|\(detectedAtIso ?? "")"
    }
}

struct RadarClusterSummary: Decodable, Sendable, Identifiable {
    let cluster: String
    let label: String
    let count: Int

    var id: String { cluster }

    private enum CodingKeys: String, CodingKey {
        case cluster
        case label
        case count
    }

    init(cluster: String, label: String, count: Int) {
        self.cluster = cluster
        self.label = label
        self.count = count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cluster = try c.decodeIfPresent(String.self, forKey: .cluster) ?? "unknown"
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? cluster
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

struct RadarSourceStats: Decodable, Sendable, Identifiable {
    let source: String
    let signalCount: Int
    let avgResidue: Double
    let lastFetch: String?

    var id: String { source }

    private enum CodingKeys: String, CodingKey {
        case source
        case signalCount
        case avgResidue
        case lastFetch
    }

    init(source: String, signalCount: Int, avgResidue: Double, lastFetch: String?) {
        self.source = source
        self.signalCount = signalCount
        self.avgResidue = avgResidue
        self.lastFetch = lastFetch
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "unknown"
        signalCount = try c.decodeIfPresent(Int.self, forKey: .signalCount) ?? 0
        avgResidue = try c.decodeIfPresent(Double.self, forKey: .avgResidue) ?? 0
        lastFetch = try c.decodeIfPresent(String.self, forKey: .lastFetch)
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
