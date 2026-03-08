import Foundation

actor GatewayClient {
    let baseURL: URL
    let token: String

    private let maxRetries = 2

    init(host: String, port: Int, token: String) {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        self.baseURL = components.url ?? URL(string: "http://localhost:19001")!
        self.token = token
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, _) = try await request(path: path, method: "GET")
        return try JSONDecoder().decode(T.self, from: data)
    }

    func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        let data = try JSONEncoder().encode(body)
        let (responseData, _) = try await request(path: path, method: "POST", body: data)
        return try JSONDecoder().decode(T.self, from: responseData)
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

    func fetchExtensions() async throws -> [ExtensionProposal] {
        if let direct: [ExtensionProposal] = try? await get("/api/extensions") {
            return direct
        }
        let envelope: ExtensionProposalsEnvelope = try await get("/api/extensions")
        return envelope.resolved
    }

    func fetchExtensionProposals() async throws -> [ExtensionProposal] {
        let extensions = try await fetchExtensions()
        let pending = extensions.filter(\.isPending)
        return pending.isEmpty ? extensions : pending
    }

    func fetchExtension(id: String) async throws -> ExtensionManifest {
        if let direct: ExtensionManifest = try? await get("/api/extensions/\(id)") {
            return direct
        }
        let envelope: ExtensionManifestEnvelope = try await get("/api/extensions/\(id)")
        if let manifest = envelope.resolved {
            return manifest
        }
        throw URLError(.cannotParseResponse)
    }

    func approveExtension(id: String) async throws -> ExtensionDecision {
        try await postExtensionDecision(path: "/api/extensions/\(id)/approve")
    }

    func rejectExtension(id: String) async throws -> ExtensionDecision {
        try await postExtensionDecision(path: "/api/extensions/\(id)/deny")
    }

    func loadExtension(id: String) async throws -> ExtensionDecision {
        try await postExtensionDecision(path: "/api/extensions/\(id)/load")
    }

    func fetchExtensionGraph(id: String) async throws -> KnowledgeGraphResponse {
        try await get("/api/extensions/\(id)/graph")
    }

    func fetchRankedProposals() async throws -> [Proposal] {
        if let direct: [Proposal] = try? await get("/api/agents/proposals/ranked") {
            return direct
        }
        let envelope: ProposalsEnvelope = try await get("/api/agents/proposals/ranked")
        return envelope.resolved
    }

    func fetchActions() async throws -> [ActionSummary] {
        struct Envelope: Decodable {
            let ok: Bool?
            let actions: [ActionSummary]?
        }
        let envelope: Envelope = try await get("/api/actions")
        return envelope.actions ?? []
    }

    func fetchRecentKnowledgeObjects(limit: Int = 20) async throws -> [KnowledgeObject] {
        let envelope: KnowledgeObjectsEnvelope = try await get("/api/knowledge/objects/recent?limit=\(limit)")
        return envelope.objects ?? []
    }

    func fetchDecidedProposals(limit: Int = 20) async throws -> [DecidedProposal] {
        let boundedLimit = max(1, min(limit, 100))
        let (data, _) = try await request(
            path: "/api/agents/proposals/decided",
            method: "GET",
            queryItems: [URLQueryItem(name: "limit", value: String(boundedLimit))]
        )
        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([DecidedProposal].self, from: data) {
            return direct
        }
        if let envelope = try? decoder.decode(DecidedProposalsEnvelope.self, from: data) {
            return envelope.resolved
        }
        return []
    }

    func fetchKnowledgeGraph(objectId: String) async throws -> KnowledgeGraphResponse {
        try await get("/api/knowledge/objects/\(objectId)/graph")
    }

    func fetchEmergence() async throws -> [EmergenceCluster] {
        let snapshot = try await fetchObservatorySnapshot(proposals: [])

        if !snapshot.collisions.isEmpty {
            return snapshot.collisions.map { cluster in
                EmergenceCluster(
                    clusterId: cluster.clusterId,
                    dimensions: cluster.sourceTypes,
                    relevanceScore: cluster.densityScore,
                    summary: cluster.summary,
                    escalatesToIphone: cluster.isEmergence
                )
            }
        }

        if let direct: [EmergenceCluster] = try? await get("/api/fabric/emergence") {
            return direct
        }

        let envelope: EmergenceEnvelope = try await get("/api/fabric/emergence")
        return envelope.resolved
    }

    func fetchChallenges() async throws -> [Challenge] {
        if let direct: [Challenge] = try? await get("/api/lobby/challenges") {
            return direct
        }

        if let wrapped: ChallengesEnvelope = try? await get("/api/lobby/challenges") {
            return wrapped.resolved
        }

        let raw = try await getRawJSON("/api/lobby/challenges")
        return parseChallenges(from: raw)
    }

    func fetchClock() async throws -> FabricClock {
        try await get("/api/fabric/clock")
    }

    func fetchObservatoryStream(limit: Int = 60) async throws -> ObservatoryStreamFeed {
        let boundedLimit = max(1, min(limit, 240))
        let path = "/api/observatory/stream"
        let (data, _) = try await request(
            path: path,
            method: "GET",
            queryItems: [URLQueryItem(name: "limit", value: String(boundedLimit))]
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
        if let directEvents = try? decoder.decode([ObservatoryStreamEvent].self, from: data) {
            debugDecode(path: path, result: "direct events", itemCount: directEvents.count)
            return ObservatoryStreamFeed(ok: true, events: directEvents, pendingCount: 0)
        }

        let raw = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let events = parseStreamEvents(from: raw)
        debugDecode(path: path, result: "raw parse", itemCount: events.count)
        return ObservatoryStreamFeed(ok: true, events: events, pendingCount: countPendingEvents(events))
    }

    func fetchRadarStatus() async throws -> RadarStatusSnapshot {
        let path = "/api/radar/status"
        let (data, _) = try await request(path: path, method: "GET")
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

    func fetchRadarActivations(limit: Int = 40) async throws -> [RadarActivation] {
        let boundedLimit = max(1, min(limit, 200))
        let path = "/api/radar/activations"
        let (data, _) = try await request(
            path: path,
            method: "GET",
            queryItems: [URLQueryItem(name: "limit", value: String(boundedLimit))]
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

    func fetchRadarCollisions() async throws -> [RadarCollision] {
        if let direct: [RadarCollision] = try? await get("/api/radar/collisions") {
            return direct
        }
        if let wrapped: RadarCollisionsEnvelope = try? await get("/api/radar/collisions") {
            return wrapped.collisions ?? wrapped.items ?? wrapped.data ?? []
        }
        return []
    }

    func fetchRadarEmergence() async throws -> [RadarCollision] {
        if let direct: [RadarCollision] = try? await get("/api/radar/emergence") {
            return direct
        }
        if let wrapped: RadarEmergenceEnvelope = try? await get("/api/radar/emergence") {
            return wrapped.emergence ?? wrapped.items ?? wrapped.data ?? []
        }
        return []
    }

    func fetchRadarClusters() async throws -> [RadarClusterSummary] {
        if let direct: [RadarClusterSummary] = try? await get("/api/radar/clusters") {
            return direct
        }
        if let wrapped: RadarClustersEnvelope = try? await get("/api/radar/clusters") {
            return wrapped.clusters ?? wrapped.items ?? wrapped.data ?? []
        }
        return []
    }

    func fetchRadarSources() async throws -> [RadarSourceStats] {
        if let direct: [RadarSourceStats] = try? await get("/api/radar/sources") {
            return direct
        }
        if let wrapped: RadarSourcesEnvelope = try? await get("/api/radar/sources") {
            return wrapped.sources ?? wrapped.items ?? wrapped.data ?? []
        }
        return []
    }


    func fetchRadarGravity() async throws -> [RadarGravityHotspot] {
        if let direct: [RadarGravityHotspot] = try? await get("/api/radar/gravity") {
            return direct
        }
        if let wrapped: RadarGravityEnvelope = try? await get("/api/radar/gravity") {
            return wrapped.hotspots ?? wrapped.items ?? wrapped.data ?? []
        }
        return []
    }

    func fetchRadarDiscoveries() async throws -> [RadarDiscoveryCandidate] {
        if let direct: [RadarDiscoveryCandidate] = try? await get("/api/radar/discoveries") {
            return direct
        }
        if let wrapped: RadarDiscoveriesEnvelope = try? await get("/api/radar/discoveries") {
            return wrapped.candidates ?? wrapped.items ?? wrapped.data ?? []
        }
        return []
    }
    func fetchSignalsRuntime() async throws -> SignalsRuntimeSnapshot {
        let path = "/api/signals/state"
        let (data, _) = try await request(path: path, method: "GET")
        let decoder = JSONDecoder()

        if let wrapped = try? decoder.decode(SignalsRuntimeEnvelope.self, from: data),
           let state = wrapped.state ?? wrapped.signals ?? wrapped.data {
            debugDecode(path: path, result: "wrapped runtime", itemCount: state.totalSignals)
            return state
        }
        if let direct = try? decoder.decode(SignalsRuntimeSnapshot.self, from: data) {
            debugDecode(path: path, result: "direct runtime", itemCount: direct.totalSignals)
            return direct
        }
        debugDecode(path: path, result: "decode failed", itemCount: nil)
        throw URLError(.cannotParseResponse)
    }

    func healthCheck() async throws -> Bool {
        let _: ConductorHealth = try await get("/health")
        return true
    }

    func fetchObservatorySnapshot(proposals: [Proposal]) async throws -> ObservatorySnapshot {
        let now = Date()

        let stateJSON = try? await getRawJSON("/api/fabric/state")
        let fabricJSON = try? await getRawJSON("/api/fabric/emergence")
        let residueJSON = try? await getRawJSON("/api/knowledge/residue")
        let collisionsJSON = try? await getRawJSON("/api/knowledge/collisions")
        let knowledgeEmergenceJSON = try? await getRawJSON("/api/knowledge/emergence")
        let challenges = (try? await fetchChallenges()) ?? []

        let fieldClusters = parseClusters(from: fabricJSON)
        let collisionClusters = parseClusters(from: collisionsJSON)
        let emergenceClusters = parseClusters(from: knowledgeEmergenceJSON)

        let mergedClusters = mergeClusters([fieldClusters, collisionClusters, emergenceClusters])
        let cells = parseCells(primary: fabricJSON, residue: residueJSON, clusters: mergedClusters)
        let routes = parseRoutes(from: fabricJSON)

        let loop = LoopMetrics(
            lastCycleDuration: parseDurationSeconds(from: stateJSON, keys: ["lastCycleDuration", "lastCycleSeconds", "lastCycleMs", "cycleDurationMs", "cycleMs"]) ?? inferLastCycle(from: proposals),
            averageCycleDuration: parseDurationSeconds(from: stateJSON, keys: ["averageCycle", "avgCycle", "avgCycleSeconds", "averageCycleMs", "avgCycleMs"]) ?? inferAverageCycle(from: proposals),
            signalsToday: parseInt(from: stateJSON, keys: ["signalsToday", "signalCountToday", "signals"]) ?? countSignals(from: residueJSON, cells: cells),
            challengesToday: parseInt(from: stateJSON, keys: ["challengesToday", "challengeCountToday"]) ?? challenges.count,
            proposalsToday: parseInt(from: stateJSON, keys: ["proposalsToday", "proposalCountToday"]) ?? countTodayProposals(proposals),
            executedActions: parseInt(from: stateJSON, keys: ["executedActions", "executedToday", "actionsExecuted"]) ?? proposals.filter(\.isApproved).count
        )

        let decisions = buildDecisionTimeline(from: proposals, stateJSON: stateJSON, now: now)

        return ObservatorySnapshot(
            loop: loop,
            field: ClashdCubeField(cells: cells, activeRoutes: routes, clusters: mergedClusters),
            collisions: mergedClusters,
            decisions: decisions,
            updatedAt: now
        )
    }

    // MARK: - Request Core

    private func request(
        path: String,
        method: String,
        body: Data? = nil,
        queryItems: [URLQueryItem] = []
    ) async throws -> (Data, HTTPURLResponse) {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        var attempt = 0
        var lastError: Error?

        while attempt <= maxRetries {
            do {
                debugRequest(path: path, url: url, hasAuthorization: request.value(forHTTPHeaderField: "Authorization") != nil)
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                debugResponse(path: path, status: http.statusCode, bytes: data.count)

                if (200...299).contains(http.statusCode) {
                    return (data, http)
                }

                if shouldRetry(statusCode: http.statusCode), attempt < maxRetries {
                    attempt += 1
                    try? await Task.sleep(for: .milliseconds(150 * attempt))
                    continue
                }

                throw GatewayClientError.httpStatus(http.statusCode)
            } catch {
                debugFailure(path: path, error: error)
                lastError = error
                if shouldRetry(error: error), attempt < maxRetries {
                    attempt += 1
                    try? await Task.sleep(for: .milliseconds(150 * attempt))
                    continue
                }
                throw error
            }
        }

        throw lastError ?? GatewayClientError.unknown
    }

    private func buildURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path = path
        components.queryItems = [URLQueryItem(name: "token", value: token)] + queryItems

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private func shouldRetry(statusCode: Int) -> Bool {
        statusCode == 408 || statusCode == 429 || (500...599).contains(statusCode)
    }

    private func shouldRetry(error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }

        switch urlError.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private func getRawJSON(_ path: String) async throws -> Any {
        let (data, _) = try await request(path: path, method: "GET")
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    private struct EmptyPostBody: Encodable {}

    private func postExtensionDecision(path: String) async throws -> ExtensionDecision {
        let (data, _) = try await request(path: path, method: "POST", body: try JSONEncoder().encode(EmptyPostBody()))
        let decoder = JSONDecoder()

        if let direct = try? decoder.decode(ExtensionDecision.self, from: data) {
            return direct
        }

        if let envelope = try? decoder.decode(ExtensionDecisionEnvelope.self, from: data) {
            if let decision = envelope.decision ?? envelope.data {
                if decision.receipt != nil {
                    return decision
                }
                return ExtensionDecision(
                    extensionId: decision.extensionId,
                    status: decision.status,
                    approvedAtIso: decision.approvedAtIso ?? envelope.approvedAtIso,
                    loadedAtIso: decision.loadedAtIso ?? envelope.loadedAtIso,
                    decisionAtIso: decision.decisionAtIso,
                    reason: decision.reason,
                    actor: decision.actor,
                    receipt: envelope.receipt ?? decision.receipt
                )
            }

            if let extensionId = envelope.extensionId {
                return ExtensionDecision(
                    extensionId: extensionId,
                    status: envelope.status ?? "ok",
                    approvedAtIso: envelope.approvedAtIso,
                    loadedAtIso: envelope.loadedAtIso,
                    decisionAtIso: ISO8601DateFormatter().string(from: Date()),
                    reason: nil,
                    actor: nil,
                    receipt: envelope.receipt
                )
            }
        }

        throw URLError(.cannotParseResponse)
    }

    // MARK: - Observatory Parsing

    private func parseChallenges(from json: Any) -> [Challenge] {
        let decoder = JSONDecoder()

        if let arr = json as? [Any],
           let data = try? JSONSerialization.data(withJSONObject: arr),
           let parsed = try? decoder.decode([Challenge].self, from: data) {
            return parsed
        }

        if let dict = json as? [String: Any] {
            for key in ["challenges", "items", "data"] {
                if let arr = dict[key] as? [Any],
                   let data = try? JSONSerialization.data(withJSONObject: arr),
                   let parsed = try? decoder.decode([Challenge].self, from: data) {
                    return parsed
                }
            }
        }

        return []
    }

    private func parseStreamEvents(from json: Any) -> [ObservatoryStreamEvent] {
        let decoder = JSONDecoder()

        if let arr = json as? [Any],
           let data = try? JSONSerialization.data(withJSONObject: arr),
           let parsed = try? decoder.decode([ObservatoryStreamEvent].self, from: data) {
            return parsed
        }

        if let dict = json as? [String: Any] {
            for key in ["events", "items", "data"] {
                if let arr = dict[key] as? [Any],
                   let data = try? JSONSerialization.data(withJSONObject: arr),
                   let parsed = try? decoder.decode([ObservatoryStreamEvent].self, from: data) {
                    return parsed
                }
            }
        }

        return []
    }

    private func countPendingEvents(_ events: [ObservatoryStreamEvent]) -> Int {
        events.filter { $0.type == "proposal_pending" }.count
    }

    private func parseClusters(from json: Any?) -> [KnowledgeCollisionCluster] {
        guard let json else { return [] }

        let candidateArray: [Any]
        if let arr = json as? [Any] {
            candidateArray = arr
        } else if let dict = json as? [String: Any] {
            candidateArray = (
                dict["clusters"] as? [Any]
                ?? dict["collisions"] as? [Any]
                ?? dict["items"] as? [Any]
                ?? dict["data"] as? [Any]
                ?? dict["emergence"] as? [Any]
                ?? []
            )
        } else {
            candidateArray = []
        }

        var clusters: [KnowledgeCollisionCluster] = []

        for (index, raw) in candidateArray.enumerated() {
            guard let item = raw as? [String: Any] else { continue }

            let clusterId = parseString(item, keys: ["clusterId", "id", "key"]) ?? "cluster-\(index)"
            let sourceTypes = parseStringArray(item, keys: ["sourceTypes", "sources", "types", "dimensions"]) ?? []
            let density = parseDouble(item, keys: ["densityScore", "density", "score", "relevanceScore"]) ?? 0
            let rawSummary = parseString(item, keys: ["summary", "description", "text"])
            let kind = parseString(item, keys: ["kind", "type"]) ?? ""
            let summary: String
            if let rawSummary, rawSummary != "No summary available." {
                summary = rawSummary
            } else if !sourceTypes.isEmpty {
                let kindLabel = kind.isEmpty ? "Cluster" : kind.capitalized
                summary = "Emergent patroon: \(kindLabel) [\(sourceTypes.joined(separator: "/"))]"
            } else {
                summary = "Emergent patroon: \(kind.isEmpty ? "onbekend" : kind)"
            }
            let position = parsePosition(item["cubePosition"])
                ?? parsePosition(item["position"])
                ?? parsePosition(item["cell"])
                ?? CubePosition(x: index % 3, y: (index / 3) % 3, z: (index / 9) % 3)
            let emergence = parseBool(item, keys: ["isEmergence", "emergence", "highlight", "escalatesToIphone"])
                ?? (density >= 0.7)

            clusters.append(
                KnowledgeCollisionCluster(
                    clusterId: clusterId,
                    sourceTypes: sourceTypes,
                    densityScore: max(0, min(1, density)),
                    cubePosition: position,
                    summary: summary,
                    isEmergence: emergence
                )
            )
        }

        return clusters
    }

    private func mergeClusters(_ groups: [[KnowledgeCollisionCluster]]) -> [KnowledgeCollisionCluster] {
        var mergedById: [String: KnowledgeCollisionCluster] = [:]

        for group in groups {
            for cluster in group {
                if let existing = mergedById[cluster.clusterId] {
                    mergedById[cluster.clusterId] = KnowledgeCollisionCluster(
                        clusterId: cluster.clusterId,
                        sourceTypes: Array(Set(existing.sourceTypes + cluster.sourceTypes)).sorted(),
                        densityScore: max(existing.densityScore, cluster.densityScore),
                        cubePosition: cluster.cubePosition,
                        summary: cluster.summary.count >= existing.summary.count ? cluster.summary : existing.summary,
                        isEmergence: existing.isEmergence || cluster.isEmergence
                    )
                } else {
                    mergedById[cluster.clusterId] = cluster
                }
            }
        }

        return mergedById.values.sorted { lhs, rhs in
            lhs.densityScore > rhs.densityScore
        }
    }

    private func parseCells(primary: Any?, residue: Any?, clusters: [KnowledgeCollisionCluster]) -> [ClashdCell] {
        let clusterByPosition = Dictionary(uniqueKeysWithValues: clusters.map { ($0.cubePosition.id, $0.clusterId) })

        if let fromPrimary = parseCellsFromPayload(primary, clusterByPosition: clusterByPosition), !fromPrimary.isEmpty {
            return fromPrimary
        }

        if let fromResidue = parseCellsFromPayload(residue, clusterByPosition: clusterByPosition), !fromResidue.isEmpty {
            return fromResidue
        }

        return fallbackCells(clusterByPosition: clusterByPosition)
    }

    private func parseCellsFromPayload(_ payload: Any?, clusterByPosition: [String: String]) -> [ClashdCell]? {
        guard let payload else { return nil }

        let cellsRaw: [Any]
        if let arr = payload as? [Any] {
            cellsRaw = arr
        } else if let dict = payload as? [String: Any] {
            cellsRaw = (
                dict["cells"] as? [Any]
                ?? dict["field"] as? [Any]
                ?? dict["cube"] as? [Any]
                ?? dict["residue"] as? [Any]
                ?? []
            )
        } else {
            cellsRaw = []
        }

        guard !cellsRaw.isEmpty else { return nil }

        var cells: [ClashdCell] = []

        for (index, raw) in cellsRaw.enumerated() {
            guard let item = raw as? [String: Any] else { continue }

            let position = parsePosition(item["position"])
                ?? parsePosition(item["cell"])
                ?? parsePosition(item)
                ?? CubePosition(x: index % 3, y: (index / 3) % 3, z: (index / 9) % 3)

            let residueValue = parseDouble(item, keys: ["residue", "residueValue", "intensity", "value", "score"]) ?? 0
            let arrows = parseStringArray(item, keys: ["routeArrows", "arrows", "routes"]) ?? []

            cells.append(
                ClashdCell(
                    position: position,
                    residue: residueValue,
                    highlightedClusterId: clusterByPosition[position.id],
                    routeArrows: arrows
                )
            )
        }

        return fillMissingCells(cells, clusterByPosition: clusterByPosition)
    }

    private func fallbackCells(clusterByPosition: [String: String]) -> [ClashdCell] {
        var cells: [ClashdCell] = []
        for z in 0..<3 {
            for y in 0..<3 {
                for x in 0..<3 {
                    let position = CubePosition(x: x, y: y, z: z)
                    cells.append(
                        ClashdCell(
                            position: position,
                            residue: 0,
                            highlightedClusterId: clusterByPosition[position.id],
                            routeArrows: []
                        )
                    )
                }
            }
        }
        return cells
    }

    private func fillMissingCells(_ cells: [ClashdCell], clusterByPosition: [String: String]) -> [ClashdCell] {
        var byPosition = Dictionary(uniqueKeysWithValues: cells.map { ($0.position.id, $0) })

        for z in 0..<3 {
            for y in 0..<3 {
                for x in 0..<3 {
                    let position = CubePosition(x: x, y: y, z: z)
                    guard byPosition[position.id] == nil else { continue }
                    byPosition[position.id] = ClashdCell(
                        position: position,
                        residue: 0,
                        highlightedClusterId: clusterByPosition[position.id],
                        routeArrows: []
                    )
                }
            }
        }

        return byPosition.values.sorted { lhs, rhs in
            if lhs.position.z != rhs.position.z { return lhs.position.z < rhs.position.z }
            if lhs.position.y != rhs.position.y { return lhs.position.y < rhs.position.y }
            return lhs.position.x < rhs.position.x
        }
    }

    private func parseRoutes(from json: Any?) -> [ClashdRoute] {
        guard let dict = json as? [String: Any] else { return [] }

        let routeArray = (
            dict["activeRoutes"] as? [Any]
            ?? dict["routes"] as? [Any]
            ?? dict["edges"] as? [Any]
            ?? dict["links"] as? [Any]
            ?? []
        )

        var routes: [ClashdRoute] = []
        for (index, raw) in routeArray.enumerated() {
            guard let route = raw as? [String: Any] else { continue }

            let from = parsePosition(route["from"]) ?? CubePosition(x: 0, y: 0, z: 0)
            let to = parsePosition(route["to"]) ?? CubePosition(x: 0, y: 0, z: 0)
            let strength = parseDouble(route, keys: ["strength", "weight", "score"]) ?? 0.5
            let id = parseString(route, keys: ["id", "routeId"]) ?? "route-\(index)"

            routes.append(ClashdRoute(id: id, from: from, to: to, strength: strength))
        }

        return routes
    }

    private func buildDecisionTimeline(from proposals: [Proposal], stateJSON: Any?, now: Date) -> [JeevesDecisionEvent] {
        var events: [JeevesDecisionEvent] = proposals
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .prefix(30)
            .map { proposal in
                let kind: JeevesDecisionKind
                if proposal.isDenied {
                    kind = .autoDenied
                } else if proposal.isPending || proposal.intent.requiresConsent {
                    kind = .escalated
                } else {
                    kind = .autoApproved
                }

                return JeevesDecisionEvent(
                    id: "proposal-\(proposal.proposalId)",
                    kind: kind,
                    title: proposal.title,
                    timestamp: proposal.createdAt ?? now
                )
            }

        if events.isEmpty, let stateDict = stateJSON as? [String: Any], let audits = stateDict["lastAuditEvents"] as? [[String: Any]] {
            events = audits.enumerated().map { index, item in
                let decision = (parseString(item, keys: ["decision", "status"]) ?? "").lowercased()
                let kind: JeevesDecisionKind
                if ["deny", "denied", "block", "blocked"].contains(decision) {
                    kind = .autoDenied
                } else if ["consent", "pending", "escalated"].contains(decision) {
                    kind = .escalated
                } else {
                    kind = .autoApproved
                }

                let title = parseString(item, keys: ["event", "toolName", "tool"]) ?? "Decision event"
                let timestamp = parseDate(parseString(item, keys: ["timestamp", "ts"])) ?? now.addingTimeInterval(TimeInterval(-index * 240))

                return JeevesDecisionEvent(
                    id: "audit-\(index)-\(timestamp.timeIntervalSince1970)",
                    kind: kind,
                    title: title,
                    timestamp: timestamp
                )
            }
        }

        return events.sorted { $0.timestamp > $1.timestamp }
    }

    private func parseDurationSeconds(from json: Any?, keys: [String]) -> TimeInterval? {
        guard let value = parseDouble(from: json, keys: keys) else { return nil }
        if keys.contains(where: { $0.lowercased().contains("ms") }) {
            return value > 120 ? value / 1000.0 : value
        }
        return value
    }

    private func inferLastCycle(from proposals: [Proposal]) -> TimeInterval {
        let dates = proposals.compactMap(\.createdAt).sorted()
        guard dates.count >= 2,
              let last = dates.last,
              let previous = dates.dropLast().last else {
            return 0
        }

        return max(0, last.timeIntervalSince(previous))
    }

    private func inferAverageCycle(from proposals: [Proposal]) -> TimeInterval {
        let dates = proposals.compactMap(\.createdAt).sorted()
        guard dates.count >= 2 else { return 0 }

        var intervals: [TimeInterval] = []
        for index in 1..<dates.count {
            intervals.append(max(0, dates[index].timeIntervalSince(dates[index - 1])))
        }

        guard !intervals.isEmpty else { return 0 }
        return intervals.reduce(0, +) / Double(intervals.count)
    }

    private func countSignals(from residueJSON: Any?, cells: [ClashdCell]) -> Int {
        if let explicit = parseInt(from: residueJSON, keys: ["signalsToday", "signalCount"]) {
            return explicit
        }

        return cells.filter { $0.residue > 0.45 }.count
    }

    private func countTodayProposals(_ proposals: [Proposal]) -> Int {
        let calendar = Calendar.current
        return proposals.filter { proposal in
            guard let created = proposal.createdAt else { return false }
            return calendar.isDateInToday(created)
        }.count
    }

    // MARK: - JSON primitives

    private func parsePosition(_ raw: Any?) -> CubePosition? {
        if let dict = raw as? [String: Any] {
            let x = parseInt(dict, keys: ["x", "i"]) ?? 0
            let y = parseInt(dict, keys: ["y", "j"]) ?? 0
            let z = parseInt(dict, keys: ["z", "k"]) ?? 0
            return CubePosition(x: x, y: y, z: z)
        }

        if let arr = raw as? [Any], arr.count >= 3 {
            let x = parseInt(arr[0]) ?? 0
            let y = parseInt(arr[1]) ?? 0
            let z = parseInt(arr[2]) ?? 0
            return CubePosition(x: x, y: y, z: z)
        }

        if let text = raw as? String {
            let parts = text.split(separator: ",").map { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            if parts.count == 3,
               let x = parts[0],
               let y = parts[1],
               let z = parts[2] {
                return CubePosition(x: x, y: y, z: z)
            }
        }

        return nil
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private func parseString(_ dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private func parseStringArray(_ dict: [String: Any], keys: [String]) -> [String]? {
        for key in keys {
            if let strings = dict[key] as? [String], !strings.isEmpty {
                return strings
            }
            if let text = dict[key] as? String, !text.isEmpty {
                let list = text
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !list.isEmpty {
                    return list
                }
            }
            if let arr = dict[key] as? [Any], !arr.isEmpty {
                let list = arr.compactMap { $0 as? String }
                if !list.isEmpty {
                    return list
                }
            }
        }
        return nil
    }

    private func parseDouble(_ dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = parseDouble(dict[key]) {
                return value
            }
        }
        return nil
    }

    private func parseDouble(from json: Any?, keys: [String]) -> Double? {
        guard let dict = json as? [String: Any] else { return nil }
        return parseDouble(dict, keys: keys)
    }

    private func parseInt(_ dict: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = parseInt(dict[key]) {
                return value
            }
        }
        return nil
    }

    private func parseInt(from json: Any?, keys: [String]) -> Int? {
        guard let dict = json as? [String: Any] else { return nil }
        return parseInt(dict, keys: keys)
    }

    private func parseBool(_ dict: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = dict[key] as? Bool {
                return value
            }
            if let text = dict[key] as? String {
                let lower = text.lowercased()
                if ["true", "1", "yes"].contains(lower) { return true }
                if ["false", "0", "no"].contains(lower) { return false }
            }
        }
        return nil
    }

    private func parseDouble(_ raw: Any?) -> Double? {
        switch raw {
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as NSNumber:
            return value.doubleValue
        case let value as String:
            return Double(value)
        default:
            return nil
        }
    }

    private func parseInt(_ raw: Any?) -> Int? {
        switch raw {
        case let value as Int:
            return value
        case let value as Double:
            return Int(value)
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }

    private func debugRequest(path: String, url: URL, hasAuthorization: Bool) {
        guard shouldLogDebug(for: path) else { return }
        #if DEBUG
        print("[Jeeves][GatewayClient] request path=\(path) url=\(url.absoluteString) auth=\(hasAuthorization)")
        #endif
    }

    private func debugResponse(path: String, status: Int, bytes: Int) {
        guard shouldLogDebug(for: path) else { return }
        #if DEBUG
        print("[Jeeves][GatewayClient] response path=\(path) status=\(status) bytes=\(bytes)")
        #endif
    }

    private func debugDecode(path: String, result: String, itemCount: Int?) {
        guard shouldLogDebug(for: path) else { return }
        #if DEBUG
        let countLabel = itemCount.map(String.init) ?? "-"
        print("[Jeeves][GatewayClient] decode path=\(path) result=\(result) count=\(countLabel)")
        #endif
    }

    private func debugFailure(path: String, error: Error) {
        guard shouldLogDebug(for: path) else { return }
        #if DEBUG
        print("[Jeeves][GatewayClient] failure path=\(path) error=\(String(describing: error))")
        #endif
    }

    private func shouldLogDebug(for path: String) -> Bool {
        path == "/api/observatory/stream"
            || path == "/api/radar/status"
            || path == "/api/signals/state"
    }
}

enum GatewayClientError: Error {
    case httpStatus(Int)
    case unknown
}

struct ChallengesEnvelope: Decodable {
    let challenges: [Challenge]?
    let items: [Challenge]?
    let data: [Challenge]?

    var resolved: [Challenge] {
        challenges ?? items ?? data ?? []
    }
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

private struct SignalsRuntimeEnvelope: Decodable {
    let state: SignalsRuntimeSnapshot?
    let signals: SignalsRuntimeSnapshot?
    let data: SignalsRuntimeSnapshot?
}
