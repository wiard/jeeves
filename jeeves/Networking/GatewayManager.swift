import Foundation
import Observation

@MainActor
@Observable
final class GatewayManager {
    private static let localDefaultPort = 19001
    static let localDiscoveryPorts: [Int] = [19001, 19002, 19003, 19004, 19005]
    private static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1"]
    private static let localGatewayDiscoveryFile = ".openclashd/gateway.json"

    static func normalizeEndpoint(host: String, port: Int) -> (host: String, port: Int) {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackPort = port > 0 ? port : localDefaultPort

        guard !trimmedHost.isEmpty else {
            return ("localhost", fallbackPort)
        }
        if trimmedHost.lowercased() == "mock" {
            return ("mock", fallbackPort)
        }

        let candidateInputs = [trimmedHost, "http://\(trimmedHost)"]
        for candidate in candidateInputs {
            guard let components = URLComponents(string: candidate),
                  let parsedHost = components.host,
                  !parsedHost.isEmpty else {
                continue
            }
            let parsedPort = components.port ?? fallbackPort
            return (parsedHost, parsedPort > 0 ? parsedPort : fallbackPort)
        }

        return (trimmedHost, fallbackPort)
    }

    /// Returns true if the host is a loopback address or a private/local IP
    /// that likely represents a local development gateway.
    static func isLocalDevelopmentHost(_ host: String) -> Bool {
        let lower = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if loopbackHosts.contains(lower) { return true }
        if lower.hasSuffix(".local") { return true }
        // Check for private IPv4 ranges
        let parts = lower.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        if parts[0] == 10 { return true }
        if parts[0] == 172, (16...31).contains(parts[1]) { return true }
        if parts[0] == 192, parts[1] == 168 { return true }
        return false
    }

    enum ConnectionState {
        case disconnected
        case connecting
        case reconnecting
        case connected
        case failed

        static var idle: ConnectionState { .disconnected }
    }

    var connectionState: ConnectionState = .disconnected
    var latencyMs: Int?
    var currentStatus: GatewayStatus?
    var currentKnowledgeStatus: KnowledgeStatus?
    var currentObservatoryBundle: ObservatoryGatewayBundle?

    var useMock: Bool = false
    var host: String = "localhost"
    var port: Int = GatewayManager.localDefaultPort
    var channelId: String = "ios-app"
    private(set) var token: String?

    var isConnected: Bool { connectionState == .connected }

    private let mock = MockGateway()
    private var connectivityTask: Task<Void, Never>?
    private var messageHandler: ((IncomingMessage) -> Void)?
    private let iso8601 = ISO8601DateFormatter()

    struct LocalGatewayResolution: Sendable {
        let host: String
        let port: Int
        let token: String?
        let isHealthy: Bool
    }

    struct StartupGatewayConfig: Sendable {
        let host: String
        let port: Int
        let token: String?
    }

    private struct GatewayEndpoint: Hashable, Sendable {
        let host: String
        let port: Int
    }

    private struct LocalGatewayDiscoveryRecord: Decodable {
        let baseURL: String?
        let host: String?
        let port: Int?
        let healthPath: String?
        let token: String?

        enum CodingKeys: String, CodingKey {
            case baseURL = "base_url"
            case host
            case port
            case healthPath = "health_path"
            case token
            case gateway
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let nested = try container.decodeIfPresent(LocalGatewayDiscoveryRecord.self, forKey: .gateway)

            let directBaseURL = try container.decodeIfPresent(String.self, forKey: .baseURL)
            let directHost = try container.decodeIfPresent(String.self, forKey: .host)
            let directPort = try container.decodeIfPresent(Int.self, forKey: .port)
            let directHealthPath = try container.decodeIfPresent(String.self, forKey: .healthPath)
            let directToken = try container.decodeIfPresent(String.self, forKey: .token)

            self.baseURL = nested?.baseURL ?? directBaseURL
            self.host = nested?.host ?? directHost
            self.port = nested?.port ?? directPort
            self.healthPath = nested?.healthPath ?? directHealthPath
            self.token = nested?.token ?? directToken
        }
    }

    func onMessage(_ handler: @escaping (IncomingMessage) -> Void) {
        messageHandler = handler
    }

    func connect(host: String, port: Int, token: String?) {
        connect(host: host, port: port, token: token, channelId: channelId)
    }

    func connect(host: String, port: Int, token: String?, channelId: String) {
        connectivityTask?.cancel()
        connectivityTask = nil

        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedChannel = channelId.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferredHost = normalizedHost.isEmpty ? self.host : normalizedHost
        let preferredPort = port > 0 ? port : self.port
        let normalizedEndpoint = Self.normalizeEndpoint(host: preferredHost, port: preferredPort)
        let resolvedHost = normalizedEndpoint.host
        let resolvedPort = normalizedEndpoint.port
        let resolvedChannel = normalizedChannel.isEmpty ? self.channelId : normalizedChannel
        let normalizedLowerHost = resolvedHost.lowercased()

        self.host = resolvedHost
        self.port = resolvedPort
        self.channelId = resolvedChannel
        self.latencyMs = nil

        if useMock || resolvedHost.lowercased() == "mock" {
            self.token = token
            self.connectionState = .connected
            self.currentStatus = mock.mockStatus()
            self.currentKnowledgeStatus = mockKnowledgeStatus()
            return
        }

        let key = "\(resolvedHost):\(resolvedPort)"
        let rawToken = (token ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedToken = rawToken.isEmpty
            ? (
                KeychainHelper.load(for: key)
                ?? (
                    Self.isLocalDevelopmentHost(normalizedLowerHost)
                    ? Self.localDiscoveryPorts
                        .map { KeychainHelper.load(for: "\(resolvedHost):\($0)") }
                        .first(where: { ($0 ?? "").isEmpty == false })
                        ?? loadDiscoveredGatewayToken()
                    : nil
                )
            )
            : rawToken

        guard let resolvedToken, !resolvedToken.isEmpty else {
            self.token = nil
            self.connectionState = .failed
            return
        }

        self.token = resolvedToken

        do {
            try KeychainHelper.save(token: resolvedToken, for: key)
        } catch {
            self.connectionState = .failed
            return
        }

        let previous = connectionState
        self.connectionState = (previous == .connected || previous == .reconnecting) ? .reconnecting : .connecting

        connectivityTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshConnectivityAndStatus(host: resolvedHost, port: resolvedPort, token: resolvedToken)
        }
    }

    func resolveLocalDevelopmentGateway(
        host: String,
        preferredPort: Int,
        preferredToken: String?,
        allowPortFallback: Bool
    ) async -> LocalGatewayResolution {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPreferredPort = preferredPort > 0 ? preferredPort : Self.localDefaultPort
        let normalizedPreferredToken = preferredToken?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Self.isLocalDevelopmentHost(normalizedHost) else {
            return LocalGatewayResolution(
                host: normalizedHost,
                port: normalizedPreferredPort,
                token: normalizedPreferredToken,
                isHealthy: false
            )
        }

        let endpoints: [GatewayEndpoint] = {
            var ordered: [GatewayEndpoint] = [
                GatewayEndpoint(host: normalizedHost, port: normalizedPreferredPort)
            ]
            let discovered = allowPortFallback ? loadLocalGatewayDiscoveryEndpoint() : nil
            if let discovered, !ordered.contains(discovered) {
                ordered.append(discovered)
            }
            // When discovery provides a non-loopback host (e.g. bridge IP for simulator),
            // also try that host with all common ports — localhost won't reach the Mac from
            // the iOS Simulator.
            let discoveredHost = discovered?.host
            let discoveredHostIsNonLoopback = discoveredHost.map {
                !Self.loopbackHosts.contains($0.lowercased())
            } ?? false
            if allowPortFallback {
                if discoveredHostIsNonLoopback, let bridgeHost = discoveredHost {
                    // Prefer bridge host with all ports (reachable from simulator)
                    for port in Self.localDiscoveryPorts {
                        let candidate = GatewayEndpoint(host: bridgeHost, port: port)
                        if !ordered.contains(candidate) {
                            ordered.append(candidate)
                        }
                    }
                }
                for port in Self.localDiscoveryPorts {
                    let candidate = GatewayEndpoint(host: normalizedHost, port: port)
                    if !ordered.contains(candidate) {
                        ordered.append(candidate)
                    }
                }
            }
            return ordered
        }()

        var tokenCandidates: [String] = []
        if let normalizedPreferredToken, !normalizedPreferredToken.isEmpty {
            tokenCandidates.append(normalizedPreferredToken)
        }
        // Token from the discovery file itself (backend publishes it for local dev)
        if let discoveryToken = loadDiscoveredGatewayToken(),
           !discoveryToken.isEmpty,
           !tokenCandidates.contains(discoveryToken) {
            tokenCandidates.append(discoveryToken)
        }
        for endpoint in endpoints {
            if let token = KeychainHelper.load(for: "\(endpoint.host):\(endpoint.port)"),
               !token.isEmpty,
               !tokenCandidates.contains(token) {
                tokenCandidates.append(token)
            }
        }
        if let activeToken = token?.trimmingCharacters(in: .whitespacesAndNewlines),
           !activeToken.isEmpty,
           !tokenCandidates.contains(activeToken) {
            tokenCandidates.append(activeToken)
        }

        #if DEBUG
        print("[Jeeves][GatewayManager] resolveLocal endpoints=\(endpoints.map { "\($0.host):\($0.port)" }) tokenCandidates=\(tokenCandidates.count)")
        #endif

        var firstHealthyWithoutTokenEndpoint: GatewayEndpoint?

        for endpoint in endpoints {
            for candidateToken in tokenCandidates {
                let status = await probeConductorHealth(host: endpoint.host, port: endpoint.port, token: candidateToken)
                #if DEBUG
                print("[Jeeves][GatewayManager] probe \(endpoint.host):\(endpoint.port) auth=true status=\(status)")
                #endif
                if status == .healthy {
                    return LocalGatewayResolution(
                        host: endpoint.host,
                        port: endpoint.port,
                        token: candidateToken,
                        isHealthy: true
                    )
                }
            }

            let unauthStatus = await probeConductorHealth(host: endpoint.host, port: endpoint.port, token: nil)
            #if DEBUG
            print("[Jeeves][GatewayManager] probe \(endpoint.host):\(endpoint.port) auth=false status=\(unauthStatus)")
            #endif
            if unauthStatus == .unauthorized || unauthStatus == .healthy {
                firstHealthyWithoutTokenEndpoint = firstHealthyWithoutTokenEndpoint ?? endpoint
            }
        }

        let fallbackEndpoint = firstHealthyWithoutTokenEndpoint ?? endpoints.first ?? GatewayEndpoint(host: normalizedHost, port: normalizedPreferredPort)
        #if DEBUG
        print("[Jeeves][GatewayManager] resolveLocal result=\(fallbackEndpoint.host):\(fallbackEndpoint.port) healthy=\(firstHealthyWithoutTokenEndpoint != nil)")
        #endif
        return LocalGatewayResolution(
            host: fallbackEndpoint.host,
            port: fallbackEndpoint.port,
            token: normalizedPreferredToken,
            isHealthy: firstHealthyWithoutTokenEndpoint != nil
        )
    }

    func startupGatewayConfigFromFile() -> StartupGatewayConfig? {
        guard let (_, record) = firstLocalGatewayDiscoveryRecord(),
              let endpoint = gatewayEndpoint(from: record) else {
            return nil
        }
        let fileToken = record.token?.trimmingCharacters(in: .whitespacesAndNewlines)
        return StartupGatewayConfig(
            host: endpoint.host,
            port: endpoint.port,
            token: (fileToken?.isEmpty == false) ? fileToken : nil
        )
    }

    func startupGatewayFileExists() -> Bool {
        firstExistingLocalGatewayDiscoveryPath() != nil
    }

    func disconnect() {
        connectivityTask?.cancel()
        connectivityTask = nil
        connectionState = .disconnected
        latencyMs = nil
        currentStatus = nil
        currentKnowledgeStatus = nil
        currentObservatoryBundle = nil
    }

    func fetchStatus() async throws -> GatewayStatus {
        if useMock || host.lowercased() == "mock" {
            let status = mock.mockStatus()
            currentStatus = status
            return status
        }

        let token = try requireToken()
        let state = try await ConductorAPI.state(host: host, port: port, token: token)

        let status = GatewayStatus(
            budget: BudgetStatus(
                daily: BudgetPeriod(used: 0, limit: state.budget.remaining),
                weekly: BudgetPeriod(used: 0, limit: state.budget.remaining),
                monthly: BudgetPeriod(used: 0, limit: state.budget.remaining),
                hardStop: state.budget.hardStop
            ),
            consent: ConsentStatus(pending: state.consentPending, active: 0),
            killSwitch: KillSwitchStatus(active: state.killSwitch.active),
            channels: [
                ChannelInfo(id: channelId, trust: .trusted, connected: true)
            ]
        )

        currentStatus = status
        return status
    }

    func fetchKnowledgeStatus() async throws -> KnowledgeStatus {
        if useMock || host.lowercased() == "mock" {
            let status = mockKnowledgeStatus()
            currentKnowledgeStatus = status
            return status
        }

        let token = try requireToken()
        let status = try await ConductorAPI.knowledgeStatus(host: host, port: port, token: token)
        currentKnowledgeStatus = status
        return status
    }

    func fetchObservatoryBundle() async throws -> ObservatoryGatewayBundle {
        if useMock || host.lowercased() == "mock" {
            let mock = mockObservatoryBundle()
            currentObservatoryBundle = mock
            return mock
        }

        let token = try requireToken()
        async let clock = ConductorAPI.fabricClock(host: host, port: port, token: token)
        async let emergence = ConductorAPI.fabricEmergence(host: host, port: port, token: token)
        async let fabricState = ConductorAPI.fabricState(host: host, port: port, token: token)
        async let challenges = ConductorAPI.lobbyChallenges(host: host, port: port, token: token)
        async let openclaw = ConductorAPI.openclawSkillsSummary(host: host, port: port, token: token)
        async let alerts = ConductorAPI.observatoryAlerts(host: host, port: port, token: token)

        let bundle = try await ObservatoryGatewayBundle(
            clock: clock,
            emergence: emergence,
            fabricState: fabricState,
            challenges: challenges,
            openclawSummary: openclaw,
            alerts: alerts,
            fetchedAt: Date()
        )
        currentObservatoryBundle = bundle
        return bundle
    }

    func fetchAudit(period: AuditPeriod) async throws -> [AuditEntry] {
        if useMock || host.lowercased() == "mock" {
            return mock.mockAuditEntries()
        }

        let token = try requireToken()
        let remotePeriod: String
        switch period {
        case .today:
            remotePeriod = "daily"
        case .week:
            remotePeriod = "weekly"
        case .month:
            remotePeriod = "monthly"
        }

        let events = try await ConductorAPI.audit(host: host, port: port, token: token, period: remotePeriod)

        return events.enumerated().map { index, event in
            let timestampString = event.timestamp ?? ""
            let date = iso8601.date(from: timestampString) ?? Date()

            let statusValue: AuditStatus
            let decision = (event.decision ?? event.status ?? "").lowercased()
            switch decision {
            case "block", "blocked", "deny", "denied":
                statusValue = .blocked
            case "consent", "consent_requested", "pending":
                statusValue = .consentRequested
            default:
                statusValue = .allowed
            }

            let toolName = event.toolName ?? event.event ?? "unknown"

            return AuditEntry(
                id: event.id ?? "audit-\(index)-\(timestampString)",
                timestamp: date,
                tool: toolName,
                status: statusValue,
                channel: event.channel ?? channelId,
                reason: event.reason,
                cost: event.cost,
                params: event.params
            )
        }
    }

    func activateKillSwitch(reason: String) async throws {
        if useMock || host.lowercased() == "mock" {
            var status = currentStatus ?? mock.mockStatus()
            status.killSwitch.active = true
            currentStatus = status
            return
        }

        let token = try requireToken()
        try await ConductorAPI.killActivate(host: host, port: port, token: token, reason: reason)
        _ = try? await fetchStatus()
    }

    func deactivateKillSwitch() async throws {
        if useMock || host.lowercased() == "mock" {
            var status = currentStatus ?? mock.mockStatus()
            status.killSwitch.active = false
            currentStatus = status
            return
        }

        let token = try requireToken()
        try await ConductorAPI.killDeactivate(host: host, port: port, token: token)
        _ = try? await fetchStatus()
    }

    func send(text: String) async throws {
        if useMock || host.lowercased() == "mock" {
            let messages = await mock.simulateResponse(for: text)
            messages.forEach { handleIncoming($0) }
            return
        }

        let token = try requireToken()
        let body = try JSONEncoder().encode(OutgoingMessage.chat(text: text, channelId: channelId))
        let response = try await ConductorAPI.postIntent(host: host, port: port, token: token, body: body)

        if let incoming = IncomingMessageDecoder.decode(from: response) {
            handleIncoming(incoming)
        }
    }

    func respondToConsent(id: String, approved: Bool, tool: String? = nil) async throws {
        if useMock || host.lowercased() == "mock" {
            guard approved, let tool else { return }
            let response = await mock.simulateConsentApproval(tool: tool)
            handleIncoming(response)
            return
        }

        let token = try requireToken()
        let body = try JSONEncoder().encode(ConsentResponseMessage(id: id, approved: approved))
        let response = try await ConductorAPI.postIntent(host: host, port: port, token: token, body: body)

        if let incoming = IncomingMessageDecoder.decode(from: response) {
            handleIncoming(incoming)
        }
    }

    private func refreshConnectivityAndStatus(host: String, port: Int, token: String) async {
        let startedNs = DispatchTime.now().uptimeNanoseconds

        do {
            let health = try await ConductorAPI.health(host: host, port: port, token: token)
            let elapsedMs = Int((DispatchTime.now().uptimeNanoseconds - startedNs) / 1_000_000)
            latencyMs = health.responseTimeMs ?? elapsedMs
            connectionState = health.ok ? .connected : .failed

            if health.ok {
                _ = try? await fetchStatus()
                _ = try? await fetchKnowledgeStatus()
            }
        } catch {
            latencyMs = nil
            connectionState = .failed
        }
    }

    private func requireToken() throws -> String {
        if let token, !token.isEmpty {
            return token
        }

        if let stored = KeychainHelper.load(for: "\(host):\(port)"), !stored.isEmpty {
            self.token = stored
            return stored
        }

        let normalizedHost = host.lowercased()
        if Self.isLocalDevelopmentHost(normalizedHost) {
            for candidatePort in Self.localDiscoveryPorts {
                if let candidate = KeychainHelper.load(for: "\(host):\(candidatePort)"), !candidate.isEmpty {
                    self.token = candidate
                    return candidate
                }
            }
            if let discoveredToken = loadDiscoveredGatewayToken(), !discoveredToken.isEmpty {
                self.token = discoveredToken
                return discoveredToken
            }
        }

        throw NSError(domain: "Gateway", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing token"])
    }

    private enum ConductorProbeStatus {
        case healthy
        case unauthorized
        case unavailable
    }

    private func probeConductorHealth(host: String, port: Int, token: String?) async -> ConductorProbeStatus {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = "/api/conductor/health"
        if let token, !token.isEmpty {
            components.queryItems = [URLQueryItem(name: "token", value: token)]
        }

        guard let url = components.url else { return .unavailable }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.2
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .unavailable }
            if http.statusCode == 200 {
                if let decoded = try? JSONDecoder().decode(ConductorHealth.self, from: data) {
                    return decoded.ok ? .healthy : .unavailable
                }
                return .healthy
            }
            if http.statusCode == 401 {
                return .unauthorized
            }
            return .unavailable
        } catch {
            return .unavailable
        }
    }

    private func loadDiscoveredGatewayToken() -> String? {
        let (_, token) = loadLocalGatewayDiscovery()
        return token
    }

    private func loadLocalGatewayDiscoveryEndpoint() -> GatewayEndpoint? {
        let (endpoint, _) = loadLocalGatewayDiscovery()
        return endpoint
    }

    /// Returns (endpoint, token) from the first valid discovery file.
    private func loadLocalGatewayDiscovery() -> (GatewayEndpoint?, String?) {
        guard let (path, record) = firstLocalGatewayDiscoveryRecord() else {
            return (nil, nil)
        }
        let endpoint = gatewayEndpoint(from: record)
        // Token from discovery file itself (local dev)
        let fileToken = record.token?.trimmingCharacters(in: .whitespacesAndNewlines)
        let discoveredToken: String? = {
            if let fileToken, !fileToken.isEmpty { return fileToken }
            // Fall back to keychain entry for the discovered endpoint
            if let ep = endpoint {
                let key = "\(ep.host):\(ep.port)"
                if let stored = KeychainHelper.load(for: key), !stored.isEmpty { return stored }
            }
            return nil
        }()
        if endpoint != nil || (discoveredToken != nil && !(discoveredToken?.isEmpty ?? true)) {
            #if DEBUG
            print("[Jeeves][GatewayManager] discovery file=\(path) endpoint=\(endpoint.map { "\($0.host):\($0.port)" } ?? "nil") token=\(discoveredToken != nil ? "present" : "nil")")
            #endif
        }
        return (endpoint, discoveredToken)
    }

    private func firstLocalGatewayDiscoveryRecord() -> (path: String, record: LocalGatewayDiscoveryRecord)? {
        let fm = FileManager.default
        for path in localGatewayDiscoveryPaths() {
            guard fm.fileExists(atPath: path) else { continue }
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }
            guard let record = try? JSONDecoder().decode(LocalGatewayDiscoveryRecord.self, from: data) else { continue }
            return (path, record)
        }
        return nil
    }

    private func firstExistingLocalGatewayDiscoveryPath() -> String? {
        let fm = FileManager.default
        for path in localGatewayDiscoveryPaths() where fm.fileExists(atPath: path) {
            return path
        }
        return nil
    }

    private func gatewayEndpoint(from record: LocalGatewayDiscoveryRecord) -> GatewayEndpoint? {
        let baseURL = (record.baseURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !baseURL.isEmpty,
           let components = URLComponents(string: baseURL),
           let host = components.host {
            let parsedPort = components.port ?? record.port ?? Self.localDefaultPort
            guard parsedPort > 0 else { return nil }
            return GatewayEndpoint(host: host, port: parsedPort)
        }

        let fallbackHost = (record.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !fallbackHost.isEmpty, let fallbackPort = record.port, fallbackPort > 0 {
            return GatewayEndpoint(host: fallbackHost, port: fallbackPort)
        }
        if !fallbackHost.isEmpty {
            return GatewayEndpoint(host: fallbackHost, port: Self.localDefaultPort)
        }
        return nil
    }

    private func localGatewayDiscoveryPaths() -> [String] {
        let env = ProcessInfo.processInfo.environment
        var candidates: [String] = []

        if let explicitPath = env["OPENCLASHD_GATEWAY_FILE"] {
            let normalized = normalizeDiscoveryPath(explicitPath)
            if !normalized.isEmpty {
                candidates.append(normalized)
            }
        }

        if let simulatorHostHome = env["SIMULATOR_HOST_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !simulatorHostHome.isEmpty {
            let path = (simulatorHostHome as NSString).appendingPathComponent(Self.localGatewayDiscoveryFile)
            candidates.append(path)
        }

        if let home = env["HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !home.isEmpty {
            let path = (home as NSString).appendingPathComponent(Self.localGatewayDiscoveryFile)
            candidates.append(path)
        }

        let tildePath = "~/" + Self.localGatewayDiscoveryFile
        candidates.append((tildePath as NSString).expandingTildeInPath)

        var unique: [String] = []
        var seen = Set<String>()
        for candidate in candidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || seen.contains(trimmed) {
                continue
            }
            seen.insert(trimmed)
            unique.append(trimmed)
        }
        return unique
    }

    private func normalizeDiscoveryPath(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ""
        }
        if trimmed.hasPrefix("file://"), let url = URL(string: trimmed), url.isFileURL {
            return url.path
        }
        return (trimmed as NSString).expandingTildeInPath
    }

    private func handleIncoming(_ message: IncomingMessage) {
        if case .status(let status) = message {
            currentStatus = status
        }
        messageHandler?(message)
    }

    private func mockKnowledgeStatus() -> KnowledgeStatus {
        KnowledgeStatus(
            last24hSignalsCount: 7,
            topCubeCells: [
                "trust-model|engine|emerging",
                "architecture|external|current",
                "surface|engine|current"
            ],
            emergenceClustersCount: 2,
            lastKnowledgeChallenges: [
                KnowledgeStatus.ChallengeSummary(
                    challengeId: "knowledge-001",
                    createdAtIso: "2026-03-04T09:00:00.000Z",
                    title: "Knowledge collision: consent architecture",
                    maxRisk: "green",
                    status: "open"
                ),
                KnowledgeStatus.ChallengeSummary(
                    challengeId: "knowledge-002",
                    createdAtIso: "2026-03-04T08:40:00.000Z",
                    title: "Knowledge collision: channel policy",
                    maxRisk: "green",
                    status: "claimed"
                ),
                KnowledgeStatus.ChallengeSummary(
                    challengeId: "knowledge-003",
                    createdAtIso: "2026-03-04T08:15:00.000Z",
                    title: "Knowledge emergence: trust surface",
                    maxRisk: "orange",
                    status: "open"
                )
            ],
            lastScanAtIso: "2026-03-04T09:10:00.000Z"
        )
    }

    private func mockObservatoryBundle() -> ObservatoryGatewayBundle {
        let nowIso = "2026-03-04T12:00:00.000Z"
        let clock = FabricClockState(
            source: "sim",
            tickN: 42,
            height: nil,
            timeIso: nowIso,
            degraded: false,
            error: nil
        )
        let emergence = FabricEmergenceResponse(
            clock: clock,
            heatmap: """
z=0 (cells 0–8)
  · 0  ░ 1  ░ 2
  ░ 3  ▒ 4  ▓ 5
  · 6  ░ 7  █ 8

z=1 (cells 9–17)
  · 9  ░10  ▒11
  ░12  ▒13  ▓14
  ·15  ░16  █17

z=2 (cells 18–26)
  ·18  ░19  ▒20
  ░21  ▒22  ▓23
  ·24  ░25  █26
""",
            topRoutes: [
                FabricEmergenceRoute(start: 4, path: [4, 5, 8, 17], totalScore: 1.82),
                FabricEmergenceRoute(start: 13, path: [13, 14, 17, 26], totalScore: 1.74),
                FabricEmergenceRoute(start: 22, path: [22, 23, 26], totalScore: 1.31)
            ],
            suggestions: [
                "Sterkste residue: cel 26 (0.8800)",
                "Beste route: 4 → 5 → 8 → 17 (1.8200)",
                "Actieve cel: 15 (residue 0.1200)"
            ],
            clusters: [
                FabricEmergenceCluster(
                    kind: "hotspot",
                    cells: [5, 8, 17],
                    totalScore: 1.62,
                    summary: "Residue hotspot rond route 5→8→17"
                ),
                FabricEmergenceCluster(
                    kind: "corridor",
                    cells: [13, 14, 17, 23, 26],
                    totalScore: 2.25,
                    summary: "Corridor naar bovenlaag"
                )
            ],
            knowledgeHitsToday: 6,
            knowledgeTopCubeAddresses: [
                "trust-model|external|emerging",
                "architecture|external|current",
                "surface|external|current"
            ]
        )
        let fabricState = FabricStateSummaryResponse(
            tickN: 42,
            activeCell: 15,
            clockSource: "sim",
            topCells: [
                FabricTopCell(cell: 26, score: 0.88, events: 9, lastTickN: 42),
                FabricTopCell(cell: 17, score: 0.71, events: 7, lastTickN: 41),
                FabricTopCell(cell: 8, score: 0.64, events: 6, lastTickN: 41)
            ]
        )
        let challenges: [LobbyChallengeItem] = [
            LobbyChallengeItem(
                challengeId: "c-001",
                createdAtIso: "2026-03-04T11:35:00.000Z",
                title: "Onderzoek OpenClaw skill hotspot",
                description: "Hot cell trust-model|external|emerging",
                domain: "external",
                suggestedIntentKey: "intent.openclaw.skills.review",
                maxRisk: "orange",
                status: "open",
                claimedByAgentId: nil
            ),
            LobbyChallengeItem(
                challengeId: "c-002",
                createdAtIso: "2026-03-04T10:50:00.000Z",
                title: "Controleer fabric route drift",
                description: "Route score verandert",
                domain: "engine",
                suggestedIntentKey: "intent.fabric.tick",
                maxRisk: "green",
                status: "claimed",
                claimedByAgentId: "jeeves"
            ),
            LobbyChallengeItem(
                challengeId: "c-003",
                createdAtIso: "2026-03-04T09:10:00.000Z",
                title: "Daily extern scan",
                description: "Routine check",
                domain: "external",
                suggestedIntentKey: "intent.scan.openclaw",
                maxRisk: "green",
                status: "completed",
                claimedByAgentId: "commonphone"
            )
        ]
        let openclawSummary = OpenclawSkillsSummary(
            generatedAtIso: nowIso,
            totalSkillsScanned: 12,
            topSkillsByResidue: [
                OpenclawSkillResult(
                    skillName: "discord",
                    fileCountScanned: 8,
                    markersFound: OpenclawSkillMarkers(secrets: 2, writes: 1, externalIO: 6, consentWords: 0),
                    cubePosition: OpenclawSkillCubePosition(wat: "trust-model", waar: "external", wanneer: "emerging"),
                    residueValue: 0.75
                ),
                OpenclawSkillResult(
                    skillName: "github",
                    fileCountScanned: 5,
                    markersFound: OpenclawSkillMarkers(secrets: 0, writes: 1, externalIO: 4, consentWords: 1),
                    cubePosition: OpenclawSkillCubePosition(wat: "trust-model", waar: "external", wanneer: "current"),
                    residueValue: 0.40
                )
            ],
            hotCells: [
                OpenclawHotCellSummary(
                    cubeAddress: "trust-model|external|emerging",
                    count: 4,
                    sumResidue: 2.3,
                    topSkills: ["discord", "github", "slack"],
                    hasAnomaly: true
                )
            ],
            anomalies: [
                OpenclawSkillResult(
                    skillName: "discord",
                    fileCountScanned: 8,
                    markersFound: OpenclawSkillMarkers(secrets: 2, writes: 1, externalIO: 6, consentWords: 0),
                    cubePosition: OpenclawSkillCubePosition(wat: "trust-model", waar: "external", wanneer: "emerging"),
                    residueValue: 0.75
                )
            ]
        )
        let alerts = ObservatoryAlertsResponse(
            updatedAtIso: nowIso,
            alerts: [
                ObservatoryAlertItem(
                    alertId: "a-001",
                    kind: "emergence",
                    severity: "high",
                    title: "Emergent patroon gedetecteerd",
                    summary: "3 clusters, 7 hits, 12 signalen",
                    cube: ObservatoryAlertCube(a1: "trust-model", a2: "external", a3: "emerging", cell: 20),
                    evidence: ObservatoryAlertEvidence(sources: ["fabric", "signals", "git"]),
                    recommendedAction: "escalate_to_iphone",
                    escalatedAtIso: "2026-03-04T11:58:00.000Z"
                )
            ]
        )
        return ObservatoryGatewayBundle(
            clock: clock,
            emergence: emergence,
            fabricState: fabricState,
            challenges: challenges,
            openclawSummary: openclawSummary,
            alerts: alerts,
            fetchedAt: Date()
        )
    }
}
