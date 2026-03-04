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
        let req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/conductor/health",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
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
        let req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/conductor/state",
            queryItems: [URLQueryItem(name: "token", value: token)]
        ))
        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return try JSONDecoder().decode(ConductorState.self, from: data)
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
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        try ensureHTTP2xx(response)
        return data
    }

    static func audit(host: String, port: Int, token: String, period: String) async throws -> [ConductorAuditEvent] {
        let req = URLRequest(url: try endpointURL(
            host: host,
            port: port,
            path: "/api/conductor/audit",
            queryItems: [
                URLQueryItem(name: "token", value: token),
                URLQueryItem(name: "period", value: period)
            ]
        ))
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
