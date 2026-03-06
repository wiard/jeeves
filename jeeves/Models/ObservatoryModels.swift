import Foundation

private enum LossyJSONScalar: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: LossyJSONScalar])
    case array([LossyJSONScalar])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode([String: LossyJSONScalar].self) {
            self = .object(value)
            return
        }
        if let value = try? container.decode([LossyJSONScalar].self) {
            self = .array(value)
            return
        }
        throw DecodingError.typeMismatch(
            LossyJSONScalar.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported scalar")
        )
    }

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object(let value):
            let keys = value.keys.sorted().joined(separator: ",")
            return "{\(keys)}"
        case .array(let value):
            return "[\(value.map(\.stringValue).joined(separator: ","))]"
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(LossyJSONScalar.self, forKey: key) {
            return value.stringValue
        }
        return nil
    }
}

struct ObservatoryDashboardSnapshot: Sendable {
    let conductor: ConductorState?
    let alerts: [ObservatoryAlert]
    let fabricClock: FabricClockState?
    let fabricEmergence: FabricEmergence?
    let lobbyOpenChallenges: [LobbyChallenge]
    let signals: SignalsState?
    let knowledgeStatus: KnowledgeStatus?
    let knowledgeEmergence: KnowledgeEmergence?
    let signalsRuntime: SignalsRuntimeSnapshot?
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
    let runCount: Int?
    let activeSourceCount: Int?
    let totalSignals: Int?
    let lastRunAtIso: String?
    let lastError: String?

    private enum CodingKeys: String, CodingKey {
        case signalsToday
        case challengesToday
        case proposalsToday
        case executedActions
        case signals
        case challenges
        case proposals
        case executed
        case runCount
        case activeSourceCount
        case totalSignals
        case lastRunAtIso
        case lastError
    }

    init(
        signalsToday: Int?,
        challengesToday: Int?,
        proposalsToday: Int?,
        executedActions: Int?,
        runCount: Int? = nil,
        activeSourceCount: Int? = nil,
        totalSignals: Int? = nil,
        lastRunAtIso: String? = nil,
        lastError: String? = nil
    ) {
        self.signalsToday = signalsToday
        self.challengesToday = challengesToday
        self.proposalsToday = proposalsToday
        self.executedActions = executedActions
        self.runCount = runCount
        self.activeSourceCount = activeSourceCount
        self.totalSignals = totalSignals
        self.lastRunAtIso = lastRunAtIso
        self.lastError = lastError
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
        runCount = try c.decodeIfPresent(Int.self, forKey: .runCount)
        activeSourceCount = try c.decodeIfPresent(Int.self, forKey: .activeSourceCount)
        totalSignals = try c.decodeIfPresent(Int.self, forKey: .totalSignals)
        lastRunAtIso = try c.decodeIfPresent(String.self, forKey: .lastRunAtIso)
        lastError = try c.decodeIfPresent(String.self, forKey: .lastError)
    }
}

struct SignalsRuntimeSnapshot: Decodable, Sendable {
    let started: Bool?
    let startedAtIso: String?
    let lastRunAtIso: String?
    let runCount: Int
    let totalSignals: Int
    let activeSourceCount: Int
    let lastError: String?
    let lastSignals: [SignalsRuntimeSignal]
    let lastChallenges: [SignalsRuntimeChallenge]
    let emergenceClusters: [SignalsRuntimeEmergenceCluster]

    private enum CodingKeys: String, CodingKey {
        case started
        case startedAtIso
        case lastRunAtIso
        case runCount
        case totalSignals
        case activeSourceCount
        case lastError
        case lastSignals
        case lastChallenges
        case emergenceClusters
    }

    init(
        started: Bool?,
        startedAtIso: String?,
        lastRunAtIso: String?,
        runCount: Int,
        totalSignals: Int,
        activeSourceCount: Int,
        lastError: String?,
        lastSignals: [SignalsRuntimeSignal],
        lastChallenges: [SignalsRuntimeChallenge],
        emergenceClusters: [SignalsRuntimeEmergenceCluster]
    ) {
        self.started = started
        self.startedAtIso = startedAtIso
        self.lastRunAtIso = lastRunAtIso
        self.runCount = runCount
        self.totalSignals = totalSignals
        self.activeSourceCount = activeSourceCount
        self.lastError = lastError
        self.lastSignals = lastSignals
        self.lastChallenges = lastChallenges
        self.emergenceClusters = emergenceClusters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        started = try c.decodeIfPresent(Bool.self, forKey: .started)
        startedAtIso = try c.decodeIfPresent(String.self, forKey: .startedAtIso)
        lastRunAtIso = try c.decodeIfPresent(String.self, forKey: .lastRunAtIso)
        runCount = try c.decodeIfPresent(Int.self, forKey: .runCount) ?? 0
        totalSignals = try c.decodeIfPresent(Int.self, forKey: .totalSignals) ?? 0
        activeSourceCount = try c.decodeIfPresent(Int.self, forKey: .activeSourceCount) ?? 0
        lastError = try c.decodeIfPresent(String.self, forKey: .lastError)
        lastSignals = try c.decodeIfPresent([SignalsRuntimeSignal].self, forKey: .lastSignals) ?? []
        lastChallenges = try c.decodeIfPresent([SignalsRuntimeChallenge].self, forKey: .lastChallenges) ?? []
        emergenceClusters = try c.decodeIfPresent([SignalsRuntimeEmergenceCluster].self, forKey: .emergenceClusters) ?? []
    }
}

struct SignalsRuntimeSignal: Decodable, Sendable, Identifiable {
    let signalId: String
    let sourceId: String?
    let detectedAtIso: String?
    let summary: String?

    var id: String { signalId }

    private enum CodingKeys: String, CodingKey {
        case signalId
        case id
        case sourceId
        case source
        case detectedAtIso
        case timestamp
        case summary
        case title
    }

    init(signalId: String, sourceId: String?, detectedAtIso: String?, summary: String?) {
        self.signalId = signalId
        self.sourceId = sourceId
        self.detectedAtIso = detectedAtIso
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        signalId = c.decodeLossyString(forKey: .signalId)
            ?? c.decodeLossyString(forKey: .id)
            ?? UUID().uuidString
        sourceId = c.decodeLossyString(forKey: .sourceId)
            ?? c.decodeLossyString(forKey: .source)
        detectedAtIso = c.decodeLossyString(forKey: .detectedAtIso)
            ?? c.decodeLossyString(forKey: .timestamp)
        summary = c.decodeLossyString(forKey: .summary)
            ?? c.decodeLossyString(forKey: .title)
    }
}

struct SignalsRuntimeChallenge: Decodable, Sendable, Identifiable {
    let challengeId: String
    let createdAtIso: String?
    let title: String?
    let status: String?

    var id: String { challengeId }

    private enum CodingKeys: String, CodingKey {
        case challengeId
        case id
        case createdAtIso
        case timestamp
        case title
        case status
    }

    init(challengeId: String, createdAtIso: String?, title: String?, status: String?) {
        self.challengeId = challengeId
        self.createdAtIso = createdAtIso
        self.title = title
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        challengeId = c.decodeLossyString(forKey: .challengeId)
            ?? c.decodeLossyString(forKey: .id)
            ?? UUID().uuidString
        createdAtIso = c.decodeLossyString(forKey: .createdAtIso)
            ?? c.decodeLossyString(forKey: .timestamp)
        title = c.decodeLossyString(forKey: .title)
        status = c.decodeLossyString(forKey: .status)
    }
}

struct SignalsRuntimeEmergenceCluster: Decodable, Sendable, Identifiable {
    let clusterId: String
    let dimensions: [String]
    let relevanceScore: Double
    let summary: String?
    let escalatesToIphone: Bool

    var id: String { clusterId }

    private enum CodingKeys: String, CodingKey {
        case clusterId
        case id
        case dimensions
        case sourceTypes
        case relevanceScore
        case densityScore
        case score
        case summary
        case escalatesToIphone
        case isEmergence
    }

    init(
        clusterId: String,
        dimensions: [String],
        relevanceScore: Double,
        summary: String?,
        escalatesToIphone: Bool
    ) {
        self.clusterId = clusterId
        self.dimensions = dimensions
        self.relevanceScore = relevanceScore
        self.summary = summary
        self.escalatesToIphone = escalatesToIphone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clusterId = c.decodeLossyString(forKey: .clusterId)
            ?? c.decodeLossyString(forKey: .id)
            ?? UUID().uuidString
        dimensions = try c.decodeIfPresent([String].self, forKey: .dimensions)
            ?? c.decodeIfPresent([String].self, forKey: .sourceTypes)
            ?? []
        relevanceScore = try c.decodeIfPresent(Double.self, forKey: .relevanceScore)
            ?? c.decodeIfPresent(Double.self, forKey: .densityScore)
            ?? c.decodeIfPresent(Double.self, forKey: .score)
            ?? 0
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        escalatesToIphone = try c.decodeIfPresent(Bool.self, forKey: .escalatesToIphone)
            ?? c.decodeIfPresent(Bool.self, forKey: .isEmergence)
            ?? (relevanceScore >= 0.7)
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

    enum CodingKeys: String, CodingKey {
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
        // Try strict decode first, then lossy decode per-element to survive bad entries
        events = (try? c.decodeIfPresent([ObservatoryStreamEvent].self, forKey: .events))
            ?? (try? c.decodeIfPresent([ObservatoryStreamEvent].self, forKey: .items))
            ?? (try? c.decodeIfPresent([ObservatoryStreamEvent].self, forKey: .data))
            ?? Self.decodeLossyEvents(from: c, forKey: .events)
            ?? Self.decodeLossyEvents(from: c, forKey: .items)
            ?? Self.decodeLossyEvents(from: c, forKey: .data)
            ?? []
        pendingCount = try c.decodeIfPresent(Int.self, forKey: .pendingCount) ?? 0
    }

    /// Decode events lossily — skips individual elements that fail to decode.
    private static func decodeLossyEvents(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> [ObservatoryStreamEvent]? {
        guard var arrayContainer = try? container.nestedUnkeyedContainer(forKey: key) else {
            return nil
        }
        var events: [ObservatoryStreamEvent] = []
        while !arrayContainer.isAtEnd {
            if let event = try? arrayContainer.decode(ObservatoryStreamEvent.self) {
                events.append(event)
            } else {
                _ = try? arrayContainer.decode(LossyJSONScalarPublic.self)
            }
        }
        return events.isEmpty ? nil : events
    }
}

struct ObservatoryStreamEvent: Decodable, Sendable, Identifiable {
    let id: String
    let type: String
    let timestampIso: String?
    let event: String?
    let clusterId: String?
    let proposalId: String?
    let agentId: String?
    let title: String?
    let summary: String?
    let signalId: String?
    let sourceId: String?
    let challengeId: String?
    let decision: String?
    let reason: String?
    let risk: String?
    let peerId: String?
    let explanation: String?
    let gravityScore: Double?
    let band: String?
    let candidateScore: Double?
    let candidateType: String?
    let candidateId: String?
    let crossDomain: Bool?
    let rank: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case eventId
        case type
        case timestampIso
        case timestamp
        case event
        case clusterId
        case proposalId
        case agentId
        case title
        case summary
        case signalId
        case sourceId
        case challengeId
        case decision
        case reason
        case risk
        case peerId
        case explanation
        case gravityScore
        case band
        case candidateScore
        case candidateType
        case candidateId
        case crossDomain
        case rank
    }

    /// The best display text for this event.
    var displayTitle: String {
        if let explanation, !explanation.isEmpty { return explanation }
        if let title, !title.isEmpty { return title }
        if let summary, !summary.isEmpty { return summary }
        if let proposalId, !proposalId.isEmpty { return proposalId }
        if let clusterId, !clusterId.isEmpty { return clusterId }
        if let challengeId, !challengeId.isEmpty { return challengeId }
        if let signalId, !signalId.isEmpty { return signalId }
        if let eventName = event, !eventName.isEmpty { return eventName }
        return "event"
    }

    var isGravityHotspot: Bool { type == "gravity_hotspot" }
    var isDiscoveryCandidate: Bool { type == "discovery_candidate" }

    init(
        id: String,
        type: String,
        timestampIso: String?,
        event: String?,
        clusterId: String? = nil,
        proposalId: String?,
        agentId: String?,
        title: String?,
        summary: String? = nil,
        signalId: String? = nil,
        sourceId: String? = nil,
        challengeId: String? = nil,
        decision: String?,
        reason: String?,
        risk: String?,
        peerId: String?,
        explanation: String? = nil,
        gravityScore: Double? = nil,
        band: String? = nil,
        candidateScore: Double? = nil,
        candidateType: String? = nil,
        candidateId: String? = nil,
        crossDomain: Bool? = nil,
        rank: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.timestampIso = timestampIso
        self.event = event
        self.clusterId = clusterId
        self.proposalId = proposalId
        self.agentId = agentId
        self.title = title
        self.summary = summary
        self.signalId = signalId
        self.sourceId = sourceId
        self.challengeId = challengeId
        self.decision = decision
        self.reason = reason
        self.risk = risk
        self.peerId = peerId
        self.explanation = explanation
        self.gravityScore = gravityScore
        self.band = band
        self.candidateScore = candidateScore
        self.candidateType = candidateType
        self.candidateId = candidateId
        self.crossDomain = crossDomain
        self.rank = rank
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = c.decodeLossyString(forKey: .type) ?? "event"
        timestampIso = c.decodeLossyString(forKey: .timestampIso)
            ?? c.decodeLossyString(forKey: .timestamp)
        event = c.decodeLossyString(forKey: .event)
        clusterId = c.decodeLossyString(forKey: .clusterId)
        proposalId = c.decodeLossyString(forKey: .proposalId)
        agentId = c.decodeLossyString(forKey: .agentId)
        title = c.decodeLossyString(forKey: .title)
        summary = c.decodeLossyString(forKey: .summary)
        signalId = c.decodeLossyString(forKey: .signalId)
        sourceId = c.decodeLossyString(forKey: .sourceId)
        challengeId = c.decodeLossyString(forKey: .challengeId)
        decision = c.decodeLossyString(forKey: .decision)
        reason = c.decodeLossyString(forKey: .reason)
        risk = c.decodeLossyString(forKey: .risk)
        peerId = c.decodeLossyString(forKey: .peerId)
        explanation = c.decodeLossyString(forKey: .explanation)
        gravityScore = try c.decodeIfPresent(Double.self, forKey: .gravityScore)
        band = c.decodeLossyString(forKey: .band)
        candidateScore = try c.decodeIfPresent(Double.self, forKey: .candidateScore)
        candidateType = c.decodeLossyString(forKey: .candidateType)
        candidateId = c.decodeLossyString(forKey: .candidateId)
        crossDomain = try c.decodeIfPresent(Bool.self, forKey: .crossDomain)
        rank = try c.decodeIfPresent(Int.self, forKey: .rank)

        let decodedId: String? = c.decodeLossyString(forKey: .id)
            ?? c.decodeLossyString(forKey: .eventId)
        if let decodedId {
            id = decodedId
        } else {
            let parts: [String] = [
                type,
                timestampIso ?? "",
                clusterId ?? "",
                proposalId ?? "",
                signalId ?? "",
                challengeId ?? "",
                candidateId ?? "",
                event ?? "",
                agentId ?? "",
                decision ?? "",
                reason ?? ""
            ]
            id = parts.joined(separator: "|")
        }
    }

}

/// Public version of LossyJSONScalar for use in lossy array decoding.
struct LossyJSONScalarPublic: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let _ = try? container.decode(String.self) { return }
        if let _ = try? container.decode(Int.self) { return }
        if let _ = try? container.decode(Double.self) { return }
        if let _ = try? container.decode(Bool.self) { return }
        if let _ = try? container.decode([String: LossyJSONScalarPublic].self) { return }
        if let _ = try? container.decode([LossyJSONScalarPublic].self) { return }
        // Accept anything
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
