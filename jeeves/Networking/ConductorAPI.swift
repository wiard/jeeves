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
    static func health(host: String, port: Int, token: String) async throws -> ConductorHealth {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/conductor/health",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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

    static func state(host: String, port: Int, token: String) async throws -> ConductorState {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/conductor/state",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return try JSONDecoder().decode(ConductorState.self, from: data)
    }

    static func knowledgeStatus(host: String, port: Int, token: String) async throws -> KnowledgeStatus {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/knowledge/status",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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

    static func fabricClock(host: String, port: Int, token: String) async throws -> FabricClockState {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/fabric/clock",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return (try? JSONDecoder().decode(FabricClockState.self, from: data)) ?? .empty
    }

    static func fabricEmergence(host: String, port: Int, token: String) async throws -> FabricEmergenceResponse {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/fabric/emergence",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return (try? JSONDecoder().decode(FabricEmergenceResponse.self, from: data)) ?? .empty
    }

    static func fabricState(host: String, port: Int, token: String) async throws -> FabricStateSummaryResponse {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/fabric/state",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return (try? JSONDecoder().decode(FabricStateSummaryResponse.self, from: data)) ?? .empty
    }

    static func lobbyChallenges(host: String, port: Int, token: String) async throws -> [LobbyChallengeItem] {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/lobby/challenges",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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

    static func openclawSkillsSummary(host: String, port: Int, token: String) async throws -> OpenclawSkillsSummary {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/openclaw/skills/summary",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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

    static func observatoryAlerts(host: String, port: Int, token: String) async throws -> ObservatoryAlertsResponse {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/observatory/alerts",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return (try? JSONDecoder().decode(ObservatoryAlertsResponse.self, from: data)) ?? .empty
    }

    static func postMessage(host: String, port: Int, token: String, text: String, peerId: String) async throws -> Data {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/message",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(["text": text, "peerId": peerId])

        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return data
    }

    static func postIntent(host: String, port: Int, token: String, body: Data) async throws -> Data {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/conductor/intent",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return data
    }

    static func audit(host: String, port: Int, token: String, period: String) async throws -> [ConductorAuditEvent] {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/conductor/audit",
            queryItems: [
                URLQueryItem(name: "token", value: token),
                URLQueryItem(name: "period", value: period)
            ]
        ))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return try decodeAuditEvents(from: data)
    }

    static func killActivate(host: String, port: Int, token: String, reason: String) async throws {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/conductor/kill/activate",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(["reason": reason])

        let (_, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
    }

    static func killDeactivate(host: String, port: Int, token: String) async throws {
        var req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/conductor/kill/deactivate",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
    }

    private static func endpointURL(host: String,
                                    port: Int,
                                    path: String,
                                    queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = path
        components.queryItems = queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
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
}
