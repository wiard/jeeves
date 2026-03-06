import Foundation
import Observation

@MainActor
@Observable
final class GatewayManager {
    private static let localDefaultPort = 19001
    static let localDiscoveryPorts: [Int] = [19001, 19002, 19003, 19004, 19005]
    private static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1"]

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

        let resolvedHost = normalizedHost.isEmpty ? self.host : normalizedHost
        let resolvedPort = port > 0 ? port : self.port
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
                    Self.loopbackHosts.contains(normalizedLowerHost)
                    ? Self.localDiscoveryPorts
                        .map { KeychainHelper.load(for: "\(resolvedHost):\($0)") }
                        .first(where: { ($0 ?? "").isEmpty == false }) ?? nil
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
        let normalizedLower = normalizedHost.lowercased()
        let normalizedPreferredPort = preferredPort > 0 ? preferredPort : Self.localDefaultPort
        let normalizedPreferredToken = preferredToken?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Self.loopbackHosts.contains(normalizedLower) else {
            return LocalGatewayResolution(
                host: normalizedHost,
                port: normalizedPreferredPort,
                token: normalizedPreferredToken,
                isHealthy: false
            )
        }

        let ports: [Int] = {
            var ordered: [Int] = [normalizedPreferredPort]
            if allowPortFallback {
                for port in Self.localDiscoveryPorts where !ordered.contains(port) {
                    ordered.append(port)
                }
            }
            return ordered
        }()

        var tokenCandidates: [String] = []
        if let normalizedPreferredToken, !normalizedPreferredToken.isEmpty {
            tokenCandidates.append(normalizedPreferredToken)
        }
        for port in ports {
            if let token = KeychainHelper.load(for: "\(normalizedHost):\(port)"),
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

        var firstHealthyWithoutTokenPort: Int?

        for port in ports {
            for candidateToken in tokenCandidates {
                let status = await probeConductorHealth(host: normalizedHost, port: port, token: candidateToken)
                if status == .healthy {
                    return LocalGatewayResolution(
                        host: normalizedHost,
                        port: port,
                        token: candidateToken,
                        isHealthy: true
                    )
                }
            }

            let unauthStatus = await probeConductorHealth(host: normalizedHost, port: port, token: nil)
            if unauthStatus == .unauthorized || unauthStatus == .healthy {
                firstHealthyWithoutTokenPort = firstHealthyWithoutTokenPort ?? port
            }
        }

        return LocalGatewayResolution(
            host: normalizedHost,
            port: firstHealthyWithoutTokenPort ?? normalizedPreferredPort,
            token: normalizedPreferredToken,
            isHealthy: firstHealthyWithoutTokenPort != nil
        )
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
        if Self.loopbackHosts.contains(normalizedHost) {
            for candidatePort in Self.localDiscoveryPorts {
                if let candidate = KeychainHelper.load(for: "\(host):\(candidatePort)"), !candidate.isEmpty {
                    self.token = candidate
                    return candidate
                }
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
