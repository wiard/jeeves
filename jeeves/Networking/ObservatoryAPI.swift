import Foundation

enum ObservatoryAPI {
    static func conductorState(host: String, port: Int, token: String) async throws -> ConductorState {
        try await ConductorAPI.state(host: host, port: port, token: token)
    }

    static func observatoryAlerts(host: String, port: Int, token: String) async throws -> [ObservatoryAlert] {
        let data = try await get(host: host, port: port, token: token, path: "/api/observatory/alerts")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([ObservatoryAlert].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(ObservatoryAlertsEnvelope.self, from: data) {
            return wrapped.alerts ?? wrapped.items ?? wrapped.data ?? []
        }
        return []
    }

    static func fabricClock(host: String, port: Int, token: String) async throws -> FabricClockState {
        let data = try await get(host: host, port: port, token: token, path: "/api/fabric/clock")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(FabricClockState.self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(FabricClockEnvelope.self, from: data),
           let clock = wrapped.clock {
            return clock
        }

        throw URLError(.cannotParseResponse)
    }

    static func fabricEmergence(host: String, port: Int, token: String) async throws -> FabricEmergence {
        let data = try await get(host: host, port: port, token: token, path: "/api/fabric/emergence")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(FabricEmergence.self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(FabricEmergenceEnvelope.self, from: data),
           let value = wrapped.emergence ?? wrapped.data {
            return value
        }

        throw URLError(.cannotParseResponse)
    }

    static func lobbyChallenges(host: String, port: Int, token: String) async throws -> [LobbyChallenge] {
        let data = try await get(host: host, port: port, token: token, path: "/api/lobby/challenges")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([LobbyChallenge].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(LobbyChallengesEnvelope.self, from: data) {
            return wrapped.challenges ?? wrapped.items ?? wrapped.data ?? []
        }

        return []
    }

    static func signalsState(host: String, port: Int, token: String) async throws -> SignalsState {
        let path = "/api/signals/state"
        let data = try await get(host: host, port: port, token: token, path: "/api/signals/state")
        let decoder = JSONDecoder()

        if let wrapped = try? decoder.decode(SignalsStateEnvelope.self, from: data),
           let value = wrapped.state ?? wrapped.signals ?? wrapped.data {
            debugDecode(path: path, result: "wrapped state", itemCount: value.totalSignals ?? value.signalsToday)
            return value
        }
        if let direct = try? decoder.decode(SignalsState.self, from: data) {
            debugDecode(path: path, result: "direct state", itemCount: direct.totalSignals ?? direct.signalsToday)
            return direct
        }

        debugDecode(path: path, result: "decode failed", itemCount: nil)
        throw URLError(.cannotParseResponse)
    }

    static func signalsRuntime(host: String, port: Int, token: String) async throws -> SignalsRuntimeSnapshot {
        let path = "/api/signals/state"
        let data = try await get(host: host, port: port, token: token, path: "/api/signals/state")
        let decoder = JSONDecoder()

        if let wrapped = try? decoder.decode(SignalsRuntimeEnvelope.self, from: data),
           let value = wrapped.state ?? wrapped.signals ?? wrapped.data {
            debugDecode(path: path, result: "wrapped runtime", itemCount: value.totalSignals)
            return value
        }
        if let direct = try? decoder.decode(SignalsRuntimeSnapshot.self, from: data) {
            debugDecode(path: path, result: "direct runtime", itemCount: direct.totalSignals)
            return direct
        }

        debugDecode(path: path, result: "decode failed", itemCount: nil)
        throw URLError(.cannotParseResponse)
    }

    static func knowledgeStatus(host: String, port: Int, token: String) async throws -> KnowledgeStatus {
        let data = try await get(host: host, port: port, token: token, path: "/api/knowledge/status")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(KnowledgeStatus.self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(KnowledgeStatusEnvelope.self, from: data),
           let value = wrapped.status ?? wrapped.data {
            return value
        }

        throw URLError(.cannotParseResponse)
    }

    static func knowledgeEmergence(host: String, port: Int, token: String) async throws -> KnowledgeEmergence {
        let data = try await get(host: host, port: port, token: token, path: "/api/knowledge/emergence")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(KnowledgeEmergence.self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(KnowledgeEmergenceEnvelope.self, from: data),
           let value = wrapped.emergence ?? wrapped.data {
            return value
        }
        if let clusters = try? decoder.decode([KnowledgeEmergenceCluster].self, from: data) {
            return KnowledgeEmergence(clusters: clusters)
        }

        throw URLError(.cannotParseResponse)
    }

    static func observatoryStream(host: String, port: Int, token: String, limit: Int = 60) async throws -> ObservatoryStreamFeed {
        let boundedLimit = max(1, min(limit, 240))
        let path = "/api/observatory/stream"
        let data = try await get(
            host: host,
            port: port,
            token: token,
            path: "/api/observatory/stream",
            queryItems: [URLQueryItem(name: "limit", value: "\(boundedLimit)")]
        )
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(ObservatoryStreamFeed.self, from: data) {
            debugDecode(path: path, result: "direct feed", itemCount: direct.events.count)
            return direct
        }
        if let wrapped = try? decoder.decode(ObservatoryStreamEnvelope.self, from: data) {
            let events = wrapped.events ?? wrapped.items ?? wrapped.data ?? []
            debugDecode(path: path, result: "wrapped feed", itemCount: events.count)
            return ObservatoryStreamFeed(
                ok: wrapped.ok,
                events: events,
                pendingCount: wrapped.pendingCount ?? 0
            )
        }
        if let events = try? decoder.decode([ObservatoryStreamEvent].self, from: data) {
            debugDecode(path: path, result: "direct events", itemCount: events.count)
            return ObservatoryStreamFeed(ok: true, events: events, pendingCount: 0)
        }

        debugDecode(path: path, result: "decode failed", itemCount: nil)
        throw URLError(.cannotParseResponse)
    }

    static func radarStatus(host: String, port: Int, token: String) async throws -> RadarStatusSnapshot {
        let path = "/api/radar/status"
        let data = try await get(host: host, port: port, token: token, path: path)
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(RadarStatusSnapshot.self, from: data) {
            debugDecode(path: path, result: "direct status", itemCount: direct.store?.activationCount)
            return direct
        }
        if let wrapped = try? decoder.decode(RadarStatusEnvelope.self, from: data),
           let status = wrapped.status ?? wrapped.data {
            debugDecode(path: path, result: "wrapped status", itemCount: status.store?.activationCount)
            return status
        }

        debugDecode(path: path, result: "decode failed", itemCount: nil)
        throw URLError(.cannotParseResponse)
    }

    static func radarActivations(host: String, port: Int, token: String, limit: Int = 40) async throws -> [RadarActivation] {
        let boundedLimit = max(1, min(limit, 200))
        let data = try await get(
            host: host,
            port: port,
            token: token,
            path: "/api/radar/activations",
            queryItems: [URLQueryItem(name: "limit", value: "\(boundedLimit)")]
        )
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([RadarActivation].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(RadarActivationsEnvelope.self, from: data) {
            return wrapped.activations ?? wrapped.items ?? wrapped.data ?? []
        }

        return []
    }

    static func radarCollisions(host: String, port: Int, token: String) async throws -> [RadarCollision] {
        let data = try await get(host: host, port: port, token: token, path: "/api/radar/collisions")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([RadarCollision].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(RadarCollisionsEnvelope.self, from: data) {
            return wrapped.collisions ?? wrapped.items ?? wrapped.data ?? []
        }

        return []
    }

    static func radarEmergence(host: String, port: Int, token: String) async throws -> [RadarCollision] {
        let data = try await get(host: host, port: port, token: token, path: "/api/radar/emergence")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([RadarCollision].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(RadarEmergenceEnvelope.self, from: data) {
            return wrapped.emergence ?? wrapped.items ?? wrapped.data ?? []
        }

        return []
    }

    static func radarClusters(host: String, port: Int, token: String) async throws -> [RadarClusterSummary] {
        let data = try await get(host: host, port: port, token: token, path: "/api/radar/clusters")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([RadarClusterSummary].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(RadarClustersEnvelope.self, from: data) {
            return wrapped.clusters ?? wrapped.items ?? wrapped.data ?? []
        }

        return []
    }

    static func radarSources(host: String, port: Int, token: String) async throws -> [RadarSourceStats] {
        let data = try await get(host: host, port: port, token: token, path: "/api/radar/sources")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([RadarSourceStats].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(RadarSourcesEnvelope.self, from: data) {
            return wrapped.sources ?? wrapped.items ?? wrapped.data ?? []
        }

        return []
    }

    static func radarGravity(host: String, port: Int, token: String) async throws -> [RadarGravityHotspot] {
        let data = try await get(host: host, port: port, token: token, path: "/api/radar/gravity")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([RadarGravityHotspot].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(RadarGravityEnvelope.self, from: data) {
            return wrapped.hotspots ?? wrapped.items ?? wrapped.data ?? []
        }

        return []
    }

    static func radarDiscoveries(host: String, port: Int, token: String) async throws -> [RadarDiscoveryCandidate] {
        let data = try await get(host: host, port: port, token: token, path: "/api/radar/discoveries")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([RadarDiscoveryCandidate].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(RadarDiscoveriesEnvelope.self, from: data) {
            return wrapped.candidates ?? wrapped.items ?? wrapped.data ?? []
        }

        return []
    }
    private static func get(
        host: String,
        port: Int,
        token: String,
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        let url = try endpointURL(host: host, port: port, path: path, token: token, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        debugRequest(path: path, url: url, hasAuthorization: request.value(forHTTPHeaderField: "Authorization") != nil)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            debugResponse(path: path, status: http.statusCode, bytes: data.count)
        }
        try ensureHTTP2xx(response)
        return data
    }

    private static func endpointURL(
        host: String,
        port: Int,
        path: String,
        token: String,
        queryItems: [URLQueryItem]
    ) throws -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = path
        components.queryItems = [URLQueryItem(name: "token", value: token)] + queryItems

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

    private static func debugRequest(path: String, url: URL, hasAuthorization: Bool) {
        guard shouldLogDebug(for: path) else { return }
        #if DEBUG
        print("[Jeeves][ObservatoryAPI] request path=\(path) url=\(url.absoluteString) auth=\(hasAuthorization)")
        #endif
    }

    private static func debugResponse(path: String, status: Int, bytes: Int) {
        guard shouldLogDebug(for: path) else { return }
        #if DEBUG
        print("[Jeeves][ObservatoryAPI] response path=\(path) status=\(status) bytes=\(bytes)")
        #endif
    }

    private static func debugDecode(path: String, result: String, itemCount: Int?) {
        guard shouldLogDebug(for: path) else { return }
        #if DEBUG
        let countLabel = itemCount.map(String.init) ?? "-"
        print("[Jeeves][ObservatoryAPI] decode path=\(path) result=\(result) count=\(countLabel)")
        #endif
    }

    private static func shouldLogDebug(for path: String) -> Bool {
        path == "/api/observatory/stream"
            || path == "/api/radar/status"
            || path == "/api/signals/state"
    }
}

private struct ObservatoryAlertsEnvelope: Decodable {
    let alerts: [ObservatoryAlert]?
    let items: [ObservatoryAlert]?
    let data: [ObservatoryAlert]?
}

private struct FabricClockEnvelope: Decodable {
    let clock: FabricClockState?
}

private struct FabricEmergenceEnvelope: Decodable {
    let emergence: FabricEmergence?
    let data: FabricEmergence?
}

private struct LobbyChallengesEnvelope: Decodable {
    let challenges: [LobbyChallenge]?
    let items: [LobbyChallenge]?
    let data: [LobbyChallenge]?
}

private struct SignalsStateEnvelope: Decodable {
    let state: SignalsState?
    let signals: SignalsState?
    let data: SignalsState?
}

private struct SignalsRuntimeEnvelope: Decodable {
    let state: SignalsRuntimeSnapshot?
    let signals: SignalsRuntimeSnapshot?
    let data: SignalsRuntimeSnapshot?
}

private struct KnowledgeStatusEnvelope: Decodable {
    let status: KnowledgeStatus?
    let data: KnowledgeStatus?
}

private struct KnowledgeEmergenceEnvelope: Decodable {
    let emergence: KnowledgeEmergence?
    let data: KnowledgeEmergence?
}

private struct ObservatoryStreamEnvelope: Decodable {
    let ok: Bool?
    let events: [ObservatoryStreamEvent]?
    let items: [ObservatoryStreamEvent]?
    let data: [ObservatoryStreamEvent]?
    let pendingCount: Int?
}

private struct RadarStatusEnvelope: Decodable {
    let status: RadarStatusSnapshot?
    let data: RadarStatusSnapshot?
}

private struct RadarActivationsEnvelope: Decodable {
    let activations: [RadarActivation]?
    let items: [RadarActivation]?
    let data: [RadarActivation]?
}

private struct RadarCollisionsEnvelope: Decodable {
    let collisions: [RadarCollision]?
    let items: [RadarCollision]?
    let data: [RadarCollision]?
}

private struct RadarEmergenceEnvelope: Decodable {
    let emergence: [RadarCollision]?
    let items: [RadarCollision]?
    let data: [RadarCollision]?
}

private struct RadarClustersEnvelope: Decodable {
    let clusters: [RadarClusterSummary]?
    let items: [RadarClusterSummary]?
    let data: [RadarClusterSummary]?
}

private struct RadarSourcesEnvelope: Decodable {
    let sources: [RadarSourceStats]?
    let items: [RadarSourceStats]?
    let data: [RadarSourceStats]?
}

private struct RadarGravityEnvelope: Decodable {
    let hotspots: [RadarGravityHotspot]?
    let items: [RadarGravityHotspot]?
    let data: [RadarGravityHotspot]?
}

private struct RadarDiscoveriesEnvelope: Decodable {
    let candidates: [RadarDiscoveryCandidate]?
    let items: [RadarDiscoveryCandidate]?
    let data: [RadarDiscoveryCandidate]?
}
