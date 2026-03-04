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
        let data = try await get(host: host, port: port, token: token, path: "/api/signals/state")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(SignalsState.self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode(SignalsStateEnvelope.self, from: data),
           let value = wrapped.state ?? wrapped.signals ?? wrapped.data {
            return value
        }

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

    private static func get(host: String, port: Int, token: String, path: String) async throws -> Data {
        let url = try endpointURL(host: host, port: port, path: path, token: token)
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureHTTP2xx(response)
        return data
    }

    private static func endpointURL(host: String, port: Int, path: String, token: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = path
        components.queryItems = [URLQueryItem(name: "token", value: token)]

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

private struct KnowledgeStatusEnvelope: Decodable {
    let status: KnowledgeStatus?
    let data: KnowledgeStatus?
}

private struct KnowledgeEmergenceEnvelope: Decodable {
    let emergence: KnowledgeEmergence?
    let data: KnowledgeEmergence?
}
