import Foundation
import Combine

@MainActor
final class ObservatoryViewModel: ObservableObject {
    private static let localDefaultPort = 19001
    private static let localDiscoveryPorts: [Int] = [19001, 19002, 19003, 19004, 19005]
    private static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1"]

    enum Section: CaseIterable {
        case loop
        case fabric
        case lobby
        case signals
        case knowledge
        case radar
        case discovery
        case alerts
    }

    enum SectionStatus: Equatable {
        case ok
        case unavailable
    }

    @Published var snapshot: ObservatoryDashboardSnapshot?
    @Published var isLoading = false
    @Published var errorText: String?

    private var sectionStatuses: [Section: SectionStatus] = {
        var statuses: [Section: SectionStatus] = [:]
        for section in Section.allCases {
            statuses[section] = .unavailable
        }
        return statuses
    }()

    func status(for section: Section) -> SectionStatus {
        sectionStatuses[section] ?? .unavailable
    }

    func refresh(gateway: GatewayManager, connection: GatewayConnection?) async {
        isLoading = true
        errorText = nil

        if gateway.useMock || gateway.host.lowercased() == "mock" {
            snapshot = Self.demoSnapshot()
            sectionStatuses[.loop] = .ok
            sectionStatuses[.fabric] = .ok
            sectionStatuses[.lobby] = .ok
            sectionStatuses[.signals] = .ok
            sectionStatuses[.knowledge] = .ok
            sectionStatuses[.radar] = .ok
            sectionStatuses[.discovery] = .ok
            sectionStatuses[.alerts] = .ok
            isLoading = false
            return
        }

        let resolvedHost = resolveHost(gateway: gateway, connection: connection)
        let resolvedPort = resolvePort(gateway: gateway, connection: connection)
        let resolvedToken = resolveToken(host: resolvedHost, port: resolvedPort, gateway: gateway)

        guard let token = resolvedToken, !token.isEmpty else {
            snapshot = nil
            markAllUnavailable()
            errorText = "Missing token"
            isLoading = false
            return
        }

        var conductor: ConductorState?
        var alerts: [ObservatoryAlert] = []
        var fabricClock: FabricClockState?
        var fabricEmergence: FabricEmergence?
        var challenges: [LobbyChallenge] = []
        var signals: SignalsState?
        var signalsRuntime: SignalsRuntimeSnapshot?
        var knowledgeStatus: KnowledgeStatus?
        var knowledgeEmergence: KnowledgeEmergence?
        var stream: ObservatoryStreamFeed?
        var radarStatus: RadarStatusSnapshot?
        var radarActivations: [RadarActivation] = []
        var radarCollisions: [RadarCollision] = []
        var radarEmergence: [RadarCollision] = []
        var radarClusters: [RadarClusterSummary] = []
        var radarSources: [RadarSourceStats] = []

        var hasConductor = false
        var hasAlerts = false
        var hasFabric = false
        var hasLobby = false
        var hasSignals = false
        var hasKnowledge = false
        var hasRadar = false
        var hasDiscovery = false

        do {
            conductor = try await ObservatoryAPI.conductorState(host: resolvedHost, port: resolvedPort, token: token)
            hasConductor = true
        } catch {}

        do {
            alerts = try await ObservatoryAPI.observatoryAlerts(host: resolvedHost, port: resolvedPort, token: token)
            hasAlerts = true
        } catch {}

        do {
            fabricClock = try await ObservatoryAPI.fabricClock(host: resolvedHost, port: resolvedPort, token: token)
            hasFabric = true
        } catch {}

        do {
            fabricEmergence = try await ObservatoryAPI.fabricEmergence(host: resolvedHost, port: resolvedPort, token: token)
            hasFabric = true
        } catch {}

        do {
            challenges = try await ObservatoryAPI.lobbyChallenges(host: resolvedHost, port: resolvedPort, token: token)
            hasLobby = true
        } catch {}

        do {
            signals = try await ObservatoryAPI.signalsState(host: resolvedHost, port: resolvedPort, token: token)
            hasSignals = true
        } catch {}

        do {
            signalsRuntime = try await ObservatoryAPI.signalsRuntime(host: resolvedHost, port: resolvedPort, token: token)
            hasSignals = true
            hasDiscovery = true
        } catch {}

        do {
            knowledgeStatus = try await ObservatoryAPI.knowledgeStatus(host: resolvedHost, port: resolvedPort, token: token)
            hasKnowledge = true
        } catch {}

        do {
            knowledgeEmergence = try await ObservatoryAPI.knowledgeEmergence(host: resolvedHost, port: resolvedPort, token: token)
            hasKnowledge = true
        } catch {}

        do {
            stream = try await ObservatoryAPI.observatoryStream(host: resolvedHost, port: resolvedPort, token: token, limit: 60)
            hasDiscovery = true
        } catch {}

        do {
            radarStatus = try await ObservatoryAPI.radarStatus(host: resolvedHost, port: resolvedPort, token: token)
            hasRadar = true
        } catch {}

        do {
            radarActivations = try await ObservatoryAPI.radarActivations(host: resolvedHost, port: resolvedPort, token: token, limit: 40)
            hasRadar = true
        } catch {}

        do {
            radarCollisions = try await ObservatoryAPI.radarCollisions(host: resolvedHost, port: resolvedPort, token: token)
            hasRadar = true
            hasDiscovery = true
        } catch {}

        do {
            radarEmergence = try await ObservatoryAPI.radarEmergence(host: resolvedHost, port: resolvedPort, token: token)
            hasRadar = true
            hasDiscovery = true
        } catch {}

        do {
            radarClusters = try await ObservatoryAPI.radarClusters(host: resolvedHost, port: resolvedPort, token: token)
            hasRadar = true
        } catch {}

        do {
            radarSources = try await ObservatoryAPI.radarSources(host: resolvedHost, port: resolvedPort, token: token)
            hasRadar = true
        } catch {}

        let sortedAlerts = Self.sortAlerts(alerts)
        let sortedChallenges = Self.sortChallenges(challenges)
            .filter { ($0.status ?? "").lowercased() == "open" || $0.status == nil }
        let sortedEmergence = knowledgeEmergence.map { Self.sortKnowledgeEmergence($0) }
        let sortedStream = stream.map(Self.sortStream)
        let sortedActivations = Self.sortActivations(radarActivations)
        let sortedCollisions = Self.sortCollisions(radarCollisions)
        let sortedRadarEmergence = Self.sortCollisions(radarEmergence)
        let sortedRadarClusters = Self.sortRadarClusters(radarClusters)
        let sortedRadarSources = Self.sortRadarSources(radarSources)

        snapshot = ObservatoryDashboardSnapshot(
            conductor: conductor,
            alerts: sortedAlerts,
            fabricClock: fabricClock,
            fabricEmergence: fabricEmergence,
            lobbyOpenChallenges: sortedChallenges,
            signals: signals,
            knowledgeStatus: knowledgeStatus,
            knowledgeEmergence: sortedEmergence,
            signalsRuntime: signalsRuntime,
            stream: sortedStream,
            radarStatus: radarStatus,
            radarActivations: sortedActivations,
            radarCollisions: sortedCollisions,
            radarEmergence: sortedRadarEmergence,
            radarClusters: sortedRadarClusters,
            radarSources: sortedRadarSources,
            fetchedAt: Date()
        )

        sectionStatuses[.loop] = hasConductor ? .ok : .unavailable
        sectionStatuses[.fabric] = hasFabric ? .ok : .unavailable
        sectionStatuses[.lobby] = hasLobby ? .ok : .unavailable
        sectionStatuses[.signals] = hasSignals ? .ok : .unavailable
        sectionStatuses[.knowledge] = hasKnowledge ? .ok : .unavailable
        sectionStatuses[.radar] = hasRadar ? .ok : .unavailable
        sectionStatuses[.discovery] = hasDiscovery ? .ok : .unavailable
        sectionStatuses[.alerts] = hasAlerts ? .ok : .unavailable

        isLoading = false
    }

    nonisolated static func sortAlerts(_ alerts: [ObservatoryAlert]) -> [ObservatoryAlert] {
        alerts.sorted { lhs, rhs in
            let lDate = parsedIso(lhs.timestampIso)
            let rDate = parsedIso(rhs.timestampIso)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.id < rhs.id
        }
    }

    nonisolated static func sortChallenges(_ challenges: [LobbyChallenge]) -> [LobbyChallenge] {
        challenges.sorted { lhs, rhs in
            let lDate = parsedIso(lhs.createdAtIso)
            let rDate = parsedIso(rhs.createdAtIso)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.id < rhs.id
        }
    }

    nonisolated static func sortKnowledgeEmergence(_ emergence: KnowledgeEmergence) -> KnowledgeEmergence {
        let sorted = emergence.clusters.sorted { lhs, rhs in
            let lScore = lhs.score ?? 0
            let rScore = rhs.score ?? 0
            if lScore != rScore {
                return lScore > rScore
            }
            return lhs.id < rhs.id
        }
        return KnowledgeEmergence(clusters: sorted)
    }

    nonisolated static func sortStream(_ stream: ObservatoryStreamFeed) -> ObservatoryStreamFeed {
        let sorted = stream.events.sorted { lhs, rhs in
            let lDate = parsedIso(lhs.timestampIso)
            let rDate = parsedIso(rhs.timestampIso)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.id < rhs.id
        }
        return ObservatoryStreamFeed(ok: stream.ok, events: sorted, pendingCount: stream.pendingCount)
    }

    nonisolated static func sortActivations(_ activations: [RadarActivation]) -> [RadarActivation] {
        activations.sorted { lhs, rhs in
            let lDate = parsedIso(lhs.timestampIso)
            let rDate = parsedIso(rhs.timestampIso)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.id < rhs.id
        }
    }

    nonisolated static func sortCollisions(_ collisions: [RadarCollision]) -> [RadarCollision] {
        collisions.sorted { lhs, rhs in
            if lhs.density != rhs.density {
                return lhs.density > rhs.density
            }
            let lDate = parsedIso(lhs.detectedAtIso)
            let rDate = parsedIso(rhs.detectedAtIso)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.id < rhs.id
        }
    }

    nonisolated static func sortRadarClusters(_ clusters: [RadarClusterSummary]) -> [RadarClusterSummary] {
        clusters.sorted { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return lhs.cluster < rhs.cluster
        }
    }

    nonisolated static func sortRadarSources(_ sources: [RadarSourceStats]) -> [RadarSourceStats] {
        sources.sorted { lhs, rhs in
            let lDate = parsedIso(lhs.lastFetch)
            let rDate = parsedIso(rhs.lastFetch)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.source < rhs.source
        }
    }

    private func resolveHost(gateway: GatewayManager, connection: GatewayConnection?) -> String {
        let runtimeHost = RuntimeConfig.shared.host?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let runtimeHost, !runtimeHost.isEmpty {
            return runtimeHost
        }

        if let connectionHost = connection?.host.trimmingCharacters(in: .whitespacesAndNewlines),
           !connectionHost.isEmpty {
            return connectionHost
        }

        let gatewayHost = gateway.host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !gatewayHost.isEmpty, gatewayHost.lowercased() != "mock" {
            return gatewayHost
        }

        return "localhost"
    }

    private func resolvePort(gateway: GatewayManager, connection: GatewayConnection?) -> Int {
        if let runtimePort = RuntimeConfig.shared.port, runtimePort > 0 {
            return runtimePort
        }
        if let connectionPort = connection?.port, connectionPort > 0 {
            return connectionPort
        }
        if gateway.port > 0 {
            return gateway.port
        }
        return Self.localDefaultPort
    }

    private func resolveToken(host: String, port: Int, gateway: GatewayManager) -> String? {
        if let runtimeToken = RuntimeConfig.shared.token?.trimmingCharacters(in: .whitespacesAndNewlines),
           !runtimeToken.isEmpty {
            return runtimeToken
        }

        if let stored = KeychainHelper.load(for: "\(host):\(port)"), !stored.isEmpty {
            return stored
        }

        let normalizedHost = host.lowercased()
        if Self.loopbackHosts.contains(normalizedHost) {
            for candidatePort in Self.localDiscoveryPorts {
                if let candidate = KeychainHelper.load(for: "\(host):\(candidatePort)"), !candidate.isEmpty {
                    return candidate
                }
            }
        }

        if let gatewayToken = gateway.token?.trimmingCharacters(in: .whitespacesAndNewlines),
           !gatewayToken.isEmpty {
            return gatewayToken
        }

        return nil
    }

    private func markAllUnavailable() {
        for section in Section.allCases {
            sectionStatuses[section] = .unavailable
        }
    }

    nonisolated private static func parsedIso(_ value: String?) -> Date {
        guard let value else { return .distantPast }
        return ISO8601DateFormatter().date(from: value) ?? .distantPast
    }

    nonisolated private static func demoSnapshot() -> ObservatoryDashboardSnapshot {
        let conductor = ConductorState(
            cycleStage: "observe",
            consentPending: 1,
            budget: .init(remaining: 18, hardStop: false),
            killSwitch: .init(active: false),
            lastAuditEvents: [],
            nowSuggestions: "observe",
            updatedAtIso: ISO8601DateFormatter().string(from: Date())
        )

        return ObservatoryDashboardSnapshot(
            conductor: conductor,
            alerts: [
                ObservatoryAlert(
                    id: "demo-alert-1",
                    title: "Unexpected connection detected",
                    summary: "Cross-source cluster formed in surface/external/current.",
                    timestampIso: ISO8601DateFormatter().string(from: Date())
                )
            ],
            fabricClock: FabricClockState(
                source: "sim",
                tickN: 42,
                height: nil,
                timeIso: ISO8601DateFormatter().string(from: Date()),
                degraded: false,
                error: nil
            ),
            fabricEmergence: FabricEmergence(
                strongestCell: "surface/external/current",
                warmLayer: "z1",
                suggestions: ["observe cluster trajectory", "wait for second source"],
                clusters: [KnowledgeEmergenceCluster(id: "demo-cluster", summary: "consent × relay", score: 0.82)]
            ),
            lobbyOpenChallenges: [
                LobbyChallenge(
                    id: "demo-challenge",
                    title: "Review emergence cluster",
                    key: "intent.review.emergence",
                    createdAtIso: ISO8601DateFormatter().string(from: Date()),
                    status: "open"
                )
            ],
            signals: SignalsState(signalsToday: 4, challengesToday: 1, proposalsToday: 2, executedActions: 1),
            knowledgeStatus: KnowledgeStatus(
                last24hSignalsCount: 9,
                topCubeCells: ["surface/external/current"],
                emergenceClustersCount: 1,
                lastKnowledgeChallenges: [],
                lastScanAtIso: ISO8601DateFormatter().string(from: Date())
            ),
            knowledgeEmergence: KnowledgeEmergence(
                clusters: [
                    KnowledgeEmergenceCluster(
                        id: "demo-knowledge",
                        summary: "Emergence cluster in shared consent surface.",
                        score: 0.86
                    )
                ]
            ),
            signalsRuntime: SignalsRuntimeSnapshot(
                started: true,
                startedAtIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)),
                lastRunAtIso: ISO8601DateFormatter().string(from: Date()),
                runCount: 14,
                totalSignals: 31,
                activeSourceCount: 6,
                lastError: nil,
                lastSignals: [
                    SignalsRuntimeSignal(
                        signalId: "demo-signal-1",
                        sourceId: "github",
                        detectedAtIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-50)),
                        summary: "consent relay drift"
                    )
                ],
                lastChallenges: [
                    SignalsRuntimeChallenge(
                        challengeId: "demo-runtime-challenge",
                        createdAtIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-120)),
                        title: "Review architecture emergence",
                        status: "open"
                    )
                ],
                emergenceClusters: [
                    SignalsRuntimeEmergenceCluster(
                        clusterId: "demo-runtime-emergence",
                        dimensions: ["trust-model", "external", "emerging"],
                        relevanceScore: 0.77,
                        summary: "runtime emergence pressure",
                        escalatesToIphone: true
                    )
                ]
            ),
            stream: ObservatoryStreamFeed(
                ok: true,
                events: [
                    ObservatoryStreamEvent(
                        id: "demo-stream-1",
                        type: "proposal_pending",
                        timestampIso: ISO8601DateFormatter().string(from: Date()),
                        event: nil,
                        proposalId: "demo-orange-1",
                        agentId: "observer.fabric",
                        title: "Inspect cross-domain anomaly",
                        decision: nil,
                        reason: nil,
                        risk: "orange",
                        peerId: nil
                    ),
                    ObservatoryStreamEvent(
                        id: "demo-stream-2",
                        type: "audit",
                        timestampIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-120)),
                        event: "challenge.created",
                        proposalId: nil,
                        agentId: "signals",
                        title: nil,
                        decision: "allow",
                        reason: "signal_generated",
                        risk: nil,
                        peerId: "system"
                    )
                ],
                pendingCount: 1
            ),
            radarStatus: RadarStatusSnapshot(
                store: RadarStoreStatus(
                    activationCount: 12,
                    collisionCount: 4,
                    emergenceCount: 1,
                    lastFetchBySource: ["github": ISO8601DateFormatter().string(from: Date())],
                    hotClusters: [RadarHotCluster(cluster: "architecture", count: 4)],
                    topSignals: [RadarTopSignal(title: "consent relay drift", source: "github", residue: 0.81)]
                ),
                collector: RadarCollectorStatus(isRunning: true, lastRun: ISO8601DateFormatter().string(from: Date()))
            ),
            radarActivations: [
                RadarActivation(
                    id: "demo-activation-1",
                    source: "github",
                    title: "consent relay drift",
                    summary: "Cross-channel signal moved into architecture/external/emerging.",
                    residue: 0.81,
                    timestampIso: ISO8601DateFormatter().string(from: Date()),
                    clusters: ["architecture", "surface"],
                    cellIds: ["architecture|external|emerging"]
                )
            ],
            radarCollisions: [
                RadarCollision(
                    id: "demo-collision-1",
                    sources: ["github", "arxiv"],
                    density: 0.74,
                    isEmergence: true,
                    detectedAtIso: ISO8601DateFormatter().string(from: Date()),
                    cellIds: ["architecture|external|emerging"],
                    signalTitles: ["consent relay drift"]
                )
            ],
            radarEmergence: [
                RadarCollision(
                    id: "demo-emergence-1",
                    sources: ["github", "arxiv", "manual"],
                    density: 0.82,
                    isEmergence: true,
                    detectedAtIso: ISO8601DateFormatter().string(from: Date()),
                    cellIds: ["surface|external|current"],
                    signalTitles: ["relay resonance"]
                )
            ],
            radarClusters: [
                RadarClusterSummary(cluster: "architecture", label: "Architecture", count: 4)
            ],
            radarSources: [
                RadarSourceStats(
                    source: "github",
                    signalCount: 6,
                    avgResidue: 0.44,
                    lastFetch: ISO8601DateFormatter().string(from: Date())
                )
            ],
            fetchedAt: Date()
        )
    }
}
