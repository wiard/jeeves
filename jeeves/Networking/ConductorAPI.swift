import Foundation

struct ConductorHealth: Decodable {
    let ok: Bool
    let name: String
    let updatedAtIso: String
    var responseTimeMs: Int?
}

struct ConductorState: Decodable {
    let cycleStage: String
    let consentPending: Int
    let budget: Budget
    let killSwitch: KillSwitch
    let lastAuditEvents: [AuditEvent]
    let nowSuggestions: String
    let updatedAtIso: String

    struct Budget: Decodable {
        let remaining: Double
        let hardStop: Bool
    }

    struct KillSwitch: Decodable {
        let active: Bool
    }

    struct AuditEvent: Decodable {
        let timestamp: String
        let event: String
        let decision: String?
        let reason: String?
        let toolName: String?
    }
}

struct KnowledgeStatus: Decodable, Sendable {
    struct ChallengeSummary: Decodable, Sendable {
        let challengeId: String
        let createdAtIso: String
        let title: String
        let maxRisk: String
        let status: String

        private enum CodingKeys: String, CodingKey {
            case challengeId
            case createdAtIso
            case title
            case maxRisk
            case status
        }

        init(challengeId: String, createdAtIso: String, title: String, maxRisk: String, status: String) {
            self.challengeId = challengeId
            self.createdAtIso = createdAtIso
            self.title = title
            self.maxRisk = maxRisk
            self.status = status
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            challengeId = try c.decodeIfPresent(String.self, forKey: .challengeId) ?? ""
            createdAtIso = try c.decodeIfPresent(String.self, forKey: .createdAtIso) ?? ""
            title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
            maxRisk = try c.decodeIfPresent(String.self, forKey: .maxRisk) ?? "green"
            status = try c.decodeIfPresent(String.self, forKey: .status) ?? "open"
        }
    }

    let last24hSignalsCount: Int
    let topCubeCells: [String]
    let emergenceClustersCount: Int
    let lastKnowledgeChallenges: [ChallengeSummary]
    let lastScanAtIso: String?

    private enum CodingKeys: String, CodingKey {
        case last24hSignalsCount
        case topCubeCells
        case emergenceClustersCount
        case lastKnowledgeChallenges
        case lastScanAtIso
    }

    init(last24hSignalsCount: Int, topCubeCells: [String], emergenceClustersCount: Int, lastKnowledgeChallenges: [ChallengeSummary], lastScanAtIso: String?) {
        self.last24hSignalsCount = last24hSignalsCount
        self.topCubeCells = topCubeCells
        self.emergenceClustersCount = emergenceClustersCount
        self.lastKnowledgeChallenges = lastKnowledgeChallenges
        self.lastScanAtIso = lastScanAtIso
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        last24hSignalsCount = try c.decodeIfPresent(Int.self, forKey: .last24hSignalsCount) ?? 0
        topCubeCells = try c.decodeIfPresent([String].self, forKey: .topCubeCells) ?? []
        emergenceClustersCount = try c.decodeIfPresent(Int.self, forKey: .emergenceClustersCount) ?? 0
        lastKnowledgeChallenges = try c.decodeIfPresent([ChallengeSummary].self, forKey: .lastKnowledgeChallenges) ?? []
        lastScanAtIso = try c.decodeIfPresent(String.self, forKey: .lastScanAtIso)
    }

    static let empty = KnowledgeStatus(
        last24hSignalsCount: 0,
        topCubeCells: [],
        emergenceClustersCount: 0,
        lastKnowledgeChallenges: [],
        lastScanAtIso: nil
    )
}

private struct KnowledgeStatusEnvelope: Decodable {
    let status: KnowledgeStatus?
}

private struct LobbyChallengesEnvelope: Decodable {
    let challenges: [LobbyChallengeItem]?
    let items: [LobbyChallengeItem]?
    let data: [LobbyChallengeItem]?
}

private struct OpenclawSkillsSummaryEnvelope: Decodable {
    let summary: OpenclawSkillsSummary?
}

struct ConductorAuditEvent: Decodable {
    let id: String?
    let timestamp: String?
    let event: String?
    let decision: String?
    let reason: String?
    let toolName: String?
    let channel: String?
    let cost: Double?
    let params: [String: String]?
    let status: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case ts
        case event
        case decision
        case reason
        case toolName
        case tool
        case channel
        case cost
        case params
        case status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp)
            ?? c.decodeIfPresent(String.self, forKey: .ts)
        event = try c.decodeIfPresent(String.self, forKey: .event)
        decision = try c.decodeIfPresent(String.self, forKey: .decision)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        toolName = try c.decodeIfPresent(String.self, forKey: .toolName)
            ?? c.decodeIfPresent(String.self, forKey: .tool)
        channel = try c.decodeIfPresent(String.self, forKey: .channel)
        cost = try c.decodeIfPresent(Double.self, forKey: .cost)
        params = try c.decodeIfPresent([String: String].self, forKey: .params)
        status = try c.decodeIfPresent(String.self, forKey: .status)
    }
}

private struct ConductorAuditEnvelope: Decodable {
    let entries: [ConductorAuditEvent]?
    let events: [ConductorAuditEvent]?
    let audit: [ConductorAuditEvent]?
    let items: [ConductorAuditEvent]?
    let data: [ConductorAuditEvent]?
}

enum ConductorAPI {
    static func health(builder: AuthorizedRequestBuilder) async throws -> ConductorHealth {
        let req = try builder.request(for: RouteContract.Conductor.health)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)

        var health = try JSONDecoder().decode(ConductorHealth.self, from: data)
        if let http = response as? HTTPURLResponse,
           let header = http.value(forHTTPHeaderField: "X-Response-Time-Ms"),
           let ms = Int(header) {
            health.responseTimeMs = ms
        }
        return health
    }

    static func state(builder: AuthorizedRequestBuilder) async throws -> ConductorState {
        let req = try builder.request(for: RouteContract.Conductor.state)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return try JSONDecoder().decode(ConductorState.self, from: data)
    }

    static func knowledgeStatus(builder: AuthorizedRequestBuilder) async throws -> KnowledgeStatus {
        let req = try builder.request(for: RouteContract.Knowledge.status)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)

        let decoder = JSONDecoder()
        if let wrapped = try? decoder.decode(KnowledgeStatusEnvelope.self, from: data),
           let status = wrapped.status {
            return status
        }

        if let direct = try? decoder.decode(KnowledgeStatus.self, from: data) {
            return direct
        }

        return .empty
    }

    static func fabricClock(builder: AuthorizedRequestBuilder) async throws -> FabricClockState {
        let req = try builder.request(for: RouteContract.Fabric.clock)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return (try? JSONDecoder().decode(FabricClockState.self, from: data)) ?? .empty
    }

    static func fabricEmergence(builder: AuthorizedRequestBuilder) async throws -> FabricEmergenceResponse {
        let req = try builder.request(for: RouteContract.Fabric.emergence)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return (try? JSONDecoder().decode(FabricEmergenceResponse.self, from: data)) ?? .empty
    }

    static func fabricState(builder: AuthorizedRequestBuilder) async throws -> FabricStateSummaryResponse {
        let req = try builder.request(for: RouteContract.Fabric.state)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return (try? JSONDecoder().decode(FabricStateSummaryResponse.self, from: data)) ?? .empty
    }

    static func lobbyChallenges(builder: AuthorizedRequestBuilder) async throws -> [LobbyChallengeItem] {
        let req = try builder.request(for: RouteContract.Lobby.challenges)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)

        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([LobbyChallengeItem].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(LobbyChallengesEnvelope.self, from: data) {
            return wrapped.challenges ?? wrapped.items ?? wrapped.data ?? []
        }
        return []
    }

    static func openclawSkillsSummary(builder: AuthorizedRequestBuilder) async throws -> OpenclawSkillsSummary {
        let req = try builder.request(for: RouteContract.openclawSkillsSummary)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)

        let decoder = JSONDecoder()
        if let wrapped = try? decoder.decode(OpenclawSkillsSummaryEnvelope.self, from: data),
           let summary = wrapped.summary {
            return summary
        }
        if let direct = try? decoder.decode(OpenclawSkillsSummary.self, from: data) {
            return direct
        }
        return .empty
    }

    static func observatoryAlerts(builder: AuthorizedRequestBuilder) async throws -> ObservatoryAlertsResponse {
        let req = try builder.request(for: RouteContract.Observatory.alerts)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return (try? JSONDecoder().decode(ObservatoryAlertsResponse.self, from: data)) ?? .empty
    }

    static func postMessage(builder: AuthorizedRequestBuilder, text: String, peerId: String) async throws -> Data {
        let body = try JSONEncoder().encode(["text": text, "peerId": peerId])
        let req = try builder.request(for: RouteContract.message, body: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            let backendReason = decodeErrorReason(from: data)
            let suffix = backendReason.map { ": \($0)" } ?? ""
            throw NSError(
                domain: "Gateway",
                code: http.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "Chat request failed (HTTP \(http.statusCode))\(suffix)"
                ]
            )
        }
        return data
    }

    static func postIntent(builder: AuthorizedRequestBuilder, body: Data) async throws -> Data {
        let req = try builder.request(for: RouteContract.Conductor.intent, body: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return data
    }

    static func audit(builder: AuthorizedRequestBuilder, period: String) async throws -> [ConductorAuditEvent] {
        let req = try builder.request(
            for: RouteContract.Conductor.audit,
            additionalQuery: [URLQueryItem(name: "period", value: period)]
        )
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return try decodeAuditEvents(from: data)
    }

    static func killActivate(builder: AuthorizedRequestBuilder, reason: String) async throws {
        let body = try JSONEncoder().encode(["reason": reason])
        let req = try builder.request(for: RouteContract.Conductor.killActivate, body: body)
        let (_, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
    }

    static func killDeactivate(builder: AuthorizedRequestBuilder) async throws {
        let req = try builder.request(for: RouteContract.Conductor.killDeactivate)
        let (_, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
    }

    private static func ensureHTTP2xx(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private static func decodeAuditEvents(from data: Data) throws -> [ConductorAuditEvent] {
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([ConductorAuditEvent].self, from: data) {
            return direct
        }

        if let wrapped = try? decoder.decode(ConductorAuditEnvelope.self, from: data) {
            return wrapped.entries
                ?? wrapped.events
                ?? wrapped.audit
                ?? wrapped.items
                ?? wrapped.data
                ?? []
        }

        if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["entries", "events", "audit", "items", "data"] {
                if let arr = object[key] {
                    let arrData = try JSONSerialization.data(withJSONObject: arr)
                    return try decoder.decode([ConductorAuditEvent].self, from: arrData)
                }
            }
        }

        return []
    }

    private static func decodeErrorReason(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        for key in ["reason", "error", "message"] {
            if let value = object[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }
}
