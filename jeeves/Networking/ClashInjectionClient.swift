import Foundation

actor ClashInjectionClient {
    private let builder: AuthorizedRequestBuilder

    init(builder: AuthorizedRequestBuilder) {
        self.builder = builder
    }

    func fetchReadiness() async throws -> SystemReadinessSnapshot {
        let request = try builder.request(for: RouteContract.System.readiness)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(SystemReadinessEnvelope.self, from: data).readiness
    }

    func fetchComputer() async throws -> Clashd27ComputerSnapshot {
        let request = try builder.request(for: RouteContract.System.computer)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Clashd27ComputerEnvelope.self, from: data).computer
    }

    func startCommand(_ body: ClashInjectionCommandRequest) async throws -> InjectionSessionSnapshot {
        let payload = try JSONEncoder().encode(body)
        let request = try builder.request(for: RouteContract.Injection.commands, body: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureSuccess(response: response)
        return try JSONDecoder().decode(ClashInjectionCommandEnvelope.self, from: data).session
    }

    func fetchSessions() async throws -> [InjectionSessionSnapshot] {
        let request = try builder.request(for: RouteContract.Injection.sessions)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(InjectionSessionsEnvelope.self, from: data).sessions
    }

    func fetchSession(id: String) async throws -> InjectionSessionSnapshot {
        let request = try builder.request(for: RouteContract.Injection.session(id: id))
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(InjectionSessionEnvelope.self, from: data).session
    }

    func fetchCycle(id: String) async throws -> InjectionCycleSnapshot {
        let request = try builder.request(for: RouteContract.Injection.cycle(id: id))
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(InjectionCycleEnvelope.self, from: data).cycle
    }

    func fetchFindings(id: String) async throws -> ([InjectionFindingSnapshot], [InjectionConsequenceSnapshot]) {
        let request = try builder.request(for: RouteContract.Injection.findings(id: id))
        let (data, _) = try await URLSession.shared.data(for: request)
        let envelope = try JSONDecoder().decode(InjectionFindingsEnvelope.self, from: data)
        return (envelope.findings, envelope.consequences)
    }

    func fetchResidue(id: String) async throws -> [InjectionResidueSnapshot] {
        let request = try builder.request(for: RouteContract.Injection.residue(id: id))
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(InjectionResidueEnvelope.self, from: data).residue
    }

    private func ensureSuccess(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
