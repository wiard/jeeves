import Foundation

actor GatewayClient {
    let baseURL: URL
    let token: String

    init(host: String, port: Int, token: String) {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        self.baseURL = components.url ?? URL(string: "http://localhost:19001")!
        self.token = token
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        let url = try buildURL(path: path)
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureHTTP2xx(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let url = try buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureHTTP2xx(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func decideProposal(proposalId: String, decision: String, reason: String? = nil) async throws -> DecideResponse {
        let body = DecideRequest(proposalId: proposalId, decision: decision, reason: reason)
        return try await post("/api/agents/proposals/decide", body: body)
    }

    func fetchProposals() async throws -> [Proposal] {
        if let direct: [Proposal] = try? await get("/api/agents/proposals") {
            return direct
        }
        let envelope: ProposalsEnvelope = try await get("/api/agents/proposals")
        return envelope.resolved
    }

    func fetchEmergence() async throws -> [EmergenceCluster] {
        if let direct: [EmergenceCluster] = try? await get("/api/fabric/emergence") {
            return direct
        }
        let envelope: EmergenceEnvelope = try await get("/api/fabric/emergence")
        return envelope.resolved
    }

    func fetchClock() async throws -> FabricClock {
        try await get("/api/fabric/clock")
    }

    func healthCheck() async throws -> Bool {
        let _: ConductorHealth = try await get("/health")
        return true
    }

    private func buildURL(path: String) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path = path
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private func ensureHTTP2xx(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
