import Foundation

struct OperatorSurfacesAPI: Sendable {
    let builder: AuthorizedRequestBuilder
    private static let requestTimeout: TimeInterval = 8
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = 8
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    func fetchBiebLatest(limit: Int = 12) async throws -> BiebLatestResponse {
        let boundedLimit = max(1, min(limit, 50))
        let data = try await request(
            path: "/api/bieb/latest",
            method: "GET",
            queryItems: [URLQueryItem(name: "limit", value: String(boundedLimit))]
        )
        return try BiebLatestResponse.decode(from: data)
    }

    func fetchResearchDomains() async throws -> [ResearchDomain] {
        var lastError: Error = OperatorSurfacesError(message: "De research-domeinfeed is niet bereikbaar.")

        for source in researchDomainsSources {
            do {
                let data: Data
                switch source {
                case .absolute(let url):
                    data = try await request(url: url, method: "GET")
                case .relative(let path):
                    data = try await request(path: path, method: "GET")
                }
                return try ResearchDomainsResponse.decode(from: data)
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    func startResearch(domainId: String) async throws -> ResearchJob {
        let body = try JSONEncoder().encode(ResearchStartBody(domainId: domainId))
        let data = try await request(path: "/api/research/start", method: "POST", body: body)
        return try ResearchJob.decode(from: data, fallbackDomainId: domainId)
    }

    func fetchResearchStatus(jobId: String) async throws -> ResearchJobStatus {
        let data = try await request(path: "/api/research/status/\(jobId)", method: "GET")
        return try ResearchJobStatus.decode(from: data, jobId: jobId)
    }

    func fetchGapPDF(gapId: String) async throws -> Data {
        var request = try builder.request(path: "/api/gaps/\(gapId)/pdf", method: "GET")
        request.setValue("application/pdf", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OperatorSurfacesError(message: "Geen geldig antwoord van de server.")
        }
        guard (200...299).contains(http.statusCode) else {
            throw decodeError(from: data, fallback: "De PDF kon niet worden opgehaald.")
        }
        return data
    }

    func decideBiebGap(gapId: String, decision: String, reason: String? = nil) async throws -> OperatorMutationAck {
        let body = try JSONEncoder().encode(
            DecisionBody(
                decision: decision,
                reason: reason?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
        )
        let data = try await request(path: "/api/gaps/\(gapId)/decide", method: "POST", body: body)
        return decodeAck(from: data)
    }

    func decideGapProposal(gapProposalId: String, decision: String, reason: String? = nil) async throws -> OperatorMutationAck {
        let body = try JSONEncoder().encode(
            GapProposalDecisionBody(
                gapProposalId: gapProposalId,
                decision: decision,
                reason: reason?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
        )
        let data = try await request(path: "/api/gaps/decide", method: "POST", body: body)
        return decodeAck(from: data)
    }

    func fetchRadarHeatmap() async throws -> RadarHeatmapResponse {
        let data = try await request(path: "/api/radar/heatmap", method: "GET")
        return try RadarHeatmapResponse.decode(from: data)
    }

    func fetchGapProposals(limit: Int = 64) async throws -> GapProposalResponse {
        let boundedLimit = max(1, min(limit, 100))
        let data = try await request(
            path: "/api/gaps",
            method: "GET",
            queryItems: [URLQueryItem(name: "limit", value: String(boundedLimit))]
        )
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(GapProposalResponse.self, from: data) {
            return direct
        }
        if let gaps = try? decoder.decode([GapProposal].self, from: data) {
            return GapProposalResponse(ok: true, gaps: gaps, statusSummary: GapStatusSummary.from(gaps: gaps))
        }

        throw URLError(.cannotParseResponse)
    }

    func fetchAgentProposals() async throws -> [Proposal] {
        let data = try await request(path: "/api/agents/proposals", method: "GET")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([Proposal].self, from: data) {
            return direct
        }
        if let envelope = try? decoder.decode(ProposalsEnvelope.self, from: data) {
            return envelope.resolved
        }

        throw URLError(.cannotParseResponse)
    }

    func fetchConductorState() async throws -> ConductorState {
        let data = try await request(path: "/api/conductor/state", method: "GET")
        return try JSONDecoder().decode(ConductorState.self, from: data)
    }

    func fetchRadarDiscoveries() async throws -> [RadarDiscoveryCandidate] {
        let data = try await request(path: "/api/radar/discoveries", method: "GET")
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode([RadarDiscoveryCandidate].self, from: data) {
            return direct
        }
        if let envelope = try? decoder.decode(RadarDiscoveriesEnvelope.self, from: data) {
            return envelope.candidates ?? envelope.items ?? envelope.data ?? []
        }

        throw URLError(.cannotParseResponse)
    }

    func fetchJacobMeaning() async throws -> [JeevesKanaalMeaningItem] {
        let data = try await request(path: "/api/jacob/meaning", method: "GET")
        return try decodeJacobMeaningItems(from: data)
    }

    func decideProposal(proposalId: String, decision: String) async throws -> OperatorMutationAck {
        let body = try JSONEncoder().encode(DecisionBody(decision: decision, reason: nil))
        let data = try await request(path: "/api/agents/proposals/\(proposalId)/decide", method: "POST", body: body)
        return decodeAck(from: data)
    }

    private func request(
        path: String,
        method: String,
        body: Data? = nil,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        let request = try builder.request(
            path: path,
            method: method,
            body: body,
            queryItems: queryItems,
            timeoutInterval: Self.requestTimeout
        )
        let (data, response) = try await Self.session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw OperatorSurfacesError(message: "Geen geldig antwoord van de server.")
        }
        guard (200...299).contains(http.statusCode) else {
            throw decodeError(from: data, fallback: "De server weigerde deze actie.")
        }

        return data
    }

    private func request(
        url: URL,
        method: String,
        body: Data? = nil,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var allQuery = queryItems
        if !builder.token.isEmpty {
            allQuery.insert(URLQueryItem(name: "token", value: builder.token), at: 0)
        }
        components?.queryItems = allQuery.isEmpty ? nil : allQuery

        guard let resolvedURL = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: resolvedURL, timeoutInterval: Self.requestTimeout)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !builder.token.isEmpty {
            request.setValue("Bearer \(builder.token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OperatorSurfacesError(message: "Geen geldig antwoord van de server.")
        }
        guard (200...299).contains(http.statusCode) else {
            throw decodeError(from: data, fallback: "De server weigerde deze actie.")
        }

        return data
    }

    private func request(
        paths: [String],
        method: String,
        body: Data? = nil,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        var lastError: Error = URLError(.badURL)

        for path in paths {
            do {
                return try await request(path: path, method: method, body: body, queryItems: queryItems)
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    private func decodeAck(from data: Data) -> OperatorMutationAck {
        guard !data.isEmpty else {
            return OperatorMutationAck(ok: true)
        }
        return (try? JSONDecoder().decode(OperatorMutationAck.self, from: data))
            ?? OperatorMutationAck(ok: true)
    }

    private func decodeError(from data: Data, fallback: String) -> OperatorSurfacesError {
        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let message = [
                payload["reason"] as? String,
                payload["message"] as? String,
                payload["error"] as? String,
                (payload["details"] as? [String: Any])?["reason"] as? String
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

            if let message {
                return OperatorSurfacesError(message: message)
            }
        }

        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return OperatorSurfacesError(message: text)
        }

        return OperatorSurfacesError(message: fallback)
    }

    private func decodeJacobMeaningItems(from data: Data) throws -> [JeevesKanaalMeaningItem] {
        if let direct = try? JSONDecoder().decode([JeevesKanaalMeaningItem].self, from: data) {
            return direct
        }

        let json = try JSONSerialization.jsonObject(with: data)

        if let array = json as? [Any] {
            return array.compactMap(JeevesKanaalMeaningItem.init(json:))
        }

        if let dictionary = json as? [String: Any] {
            let candidateKeys = ["items", "meanings", "decisions", "entries", "data"]
            for key in candidateKeys {
                if let array = dictionary[key] as? [Any] {
                    return array.compactMap(JeevesKanaalMeaningItem.init(json:))
                }
            }
            if let nested = dictionary["result"] as? [String: Any] {
                for key in candidateKeys {
                    if let array = nested[key] as? [Any] {
                        return array.compactMap(JeevesKanaalMeaningItem.init(json:))
                    }
                }
            }
        }

        throw URLError(.cannotParseResponse)
    }
}

private extension OperatorSurfacesAPI {
    enum ResearchDomainsSource {
        case absolute(URL)
        case relative(String)
    }

    var researchDomainsSources: [ResearchDomainsSource] {
        [
            .absolute(URL(string: "https://openclashd.com/api/research/domains")!),
            .relative("/api/research/domains")
        ]
    }
}

extension OperatorSurfacesAPI: JeevesKanaalAPIClient {}

extension GatewayManager {
    func makeOperatorSurfacesAPI() async -> OperatorSurfacesAPI? {
        if useMock || host.lowercased() == "mock" {
            return nil
        }

        let endpoint = await resolveEndpoint()
        let resolvedToken = resolvedOperatorSurfacesToken(for: endpoint)
        guard let resolvedToken, !resolvedToken.isEmpty else {
            return nil
        }
        let builder = AuthorizedRequestBuilder(host: endpoint.host, port: endpoint.port, token: resolvedToken)
        return OperatorSurfacesAPI(builder: builder)
    }

    private func resolvedOperatorSurfacesToken(for endpoint: ResolvedGatewayEndpoint) -> String? {
        if let token = endpoint.token?.trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            return token
        }

        if let token = self.token?.trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            return token
        }

        if let stored = KeychainHelper.load(for: "\(endpoint.host):\(endpoint.port)")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty {
            return stored
        }

        if let anyStored = KeychainHelper.loadAnyToken()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !anyStored.isEmpty {
            return anyStored
        }

        return nil
    }
}

private struct RadarDiscoveriesEnvelope: Decodable {
    let candidates: [RadarDiscoveryCandidate]?
    let items: [RadarDiscoveryCandidate]?
    let data: [RadarDiscoveryCandidate]?
}

private struct DecisionBody: Encodable {
    let decision: String
    let reason: String?
}

private struct GapProposalDecisionBody: Encodable {
    let gapProposalId: String
    let decision: String
    let reason: String?
}

private struct ResearchStartBody: Encodable {
    let domainId: String
}

struct OperatorSurfacesError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
