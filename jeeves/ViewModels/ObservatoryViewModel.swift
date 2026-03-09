import Foundation
import Combine

@MainActor
final class ObservatoryViewModel: ObservableObject, ScreenStateReadable {
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

        let endpoint = await gateway.resolveEndpoint(connection: connection)

        #if DEBUG
        print("[Jeeves][ObservatoryVM] refresh host=\(endpoint.host) port=\(endpoint.port) token=\((endpoint.token?.isEmpty == false) ? "present" : "missing")")
        #endif

        guard let builder = endpoint.makeRequestBuilder() else {
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

        var radarGravity: [RadarGravityHotspot] = []
        var radarDiscoveries: [RadarDiscoveryCandidate] = []
        var hasConductor = false
        var hasAlerts = false
        var hasFabric = false
        var hasLobby = false
        var hasSignals = false
        var hasKnowledge = false
        var hasRadar = false
        var hasDiscovery = false

        do {
            conductor = try await ObservatoryAPI.conductorState(builder: builder)
            hasConductor = true
        } catch {}

        do {
            alerts = try await ObservatoryAPI.observatoryAlerts(builder: builder)
            hasAlerts = true
        } catch {}

        do {
            fabricClock = try await ObservatoryAPI.fabricClock(builder: builder)
            hasFabric = true
        } catch {}

        do {
            fabricEmergence = try await ObservatoryAPI.fabricEmergence(builder: builder)
            hasFabric = true
        } catch {}

        do {
            challenges = try await ObservatoryAPI.lobbyChallenges(builder: builder)
            hasLobby = true
        } catch {}

        do {
            signals = try await ObservatoryAPI.signalsState(builder: builder)
            hasSignals = true
        } catch {}

        do {
            signalsRuntime = try await ObservatoryAPI.signalsRuntime(builder: builder)
            hasSignals = true
            hasDiscovery = true
        } catch {}

        do {
            knowledgeStatus = try await ObservatoryAPI.knowledgeStatus(builder: builder)
            hasKnowledge = true
        } catch {}

        do {
            knowledgeEmergence = try await ObservatoryAPI.knowledgeEmergence(builder: builder)
            hasKnowledge = true
        } catch {}

        do {
            stream = try await ObservatoryAPI.observatoryStream(builder: builder, limit: 60)
            hasDiscovery = true
        } catch {}

        do {
            radarStatus = try await ObservatoryAPI.radarStatus(builder: builder)
            hasRadar = true
        } catch {}

        do {
            radarActivations = try await ObservatoryAPI.radarActivations(builder: builder, limit: 40)
            hasRadar = true
        } catch {}

        do {
            radarCollisions = try await ObservatoryAPI.radarCollisions(builder: builder)
            hasRadar = true
            hasDiscovery = true
        } catch {}

        do {
            radarEmergence = try await ObservatoryAPI.radarEmergence(builder: builder)
            hasRadar = true
            hasDiscovery = true
        } catch {}

        do {
            radarClusters = try await ObservatoryAPI.radarClusters(builder: builder)
            hasRadar = true
        } catch {}

        do {
            radarSources = try await ObservatoryAPI.radarSources(builder: builder)
            hasRadar = true
        } catch {}
        do {
            radarGravity = try await ObservatoryAPI.radarGravity(builder: builder)
            hasRadar = true
            hasDiscovery = true
        } catch {}

        do {
            radarDiscoveries = try await ObservatoryAPI.radarDiscoveries(builder: builder)
            hasRadar = true
            hasDiscovery = true
        } catch {}

        let sortedRadarGravity = Self.sortRadarGravity(radarGravity)
        let sortedRadarDiscoveries = Self.sortRadarDiscoveries(radarDiscoveries)

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
            radarGravityHotspots: sortedRadarGravity,
            radarDiscoveryCandidates: sortedRadarDiscoveries,
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

        #if DEBUG
        let streamCount = snapshot?.stream?.events.count ?? 0
        let radarActivationCount = snapshot?.radarStatus?.store?.activationCount ?? snapshot?.radarActivations.count ?? 0
        let radarCollisionCount = snapshot?.radarStatus?.store?.collisionCount ?? snapshot?.radarCollisions.count ?? 0
        let runtimeSignals = snapshot?.signalsRuntime?.totalSignals ?? 0
        let gravityCount = snapshot?.radarGravityHotspots.count ?? 0
        let discoveryCount = snapshot?.radarDiscoveryCandidates.count ?? 0
        print("[Jeeves][ObservatoryVM] refresh result stream=\(streamCount) radarActivations=\(radarActivationCount) radarCollisions=\(radarCollisionCount) gravity=\(gravityCount) discoveries=\(discoveryCount) runtimeSignals=\(runtimeSignals)")
        #endif

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
    nonisolated static func sortRadarGravity(_ hotspots: [RadarGravityHotspot]) -> [RadarGravityHotspot] {
        hotspots.sorted { lhs, rhs in
            if lhs.gravityScore != rhs.gravityScore {
                return lhs.gravityScore > rhs.gravityScore
            }
            if lhs.rank != rhs.rank {
                return lhs.rank < rhs.rank
            }
            return lhs.id < rhs.id
        }
    }

    nonisolated static func sortRadarDiscoveries(_ candidates: [RadarDiscoveryCandidate]) -> [RadarDiscoveryCandidate] {
        candidates.sorted { lhs, rhs in
            if lhs.candidateScore != rhs.candidateScore {
                return lhs.candidateScore > rhs.candidateScore
            }
            if lhs.rank != rhs.rank {
                return lhs.rank < rhs.rank
            }
            return lhs.id < rhs.id
        }
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

    // MARK: - ScreenStateReadable

    var screenId: AppScreen { .observatory }

    func summary() -> ScreenStateSummary {
        guard let snap = snapshot else {
            return ScreenStateSummary(
                screen: .observatory,
                headline: "Observatory nog niet geladen.",
                itemCount: 0,
                highlights: [],
                isEmpty: true
            )
        }

        var highlights: [String] = []
        let collisions = snap.radarStatus?.store?.collisionCount ?? snap.radarCollisions.count
        let activations = snap.radarStatus?.store?.activationCount ?? snap.radarActivations.count
        let emergenceCount = snap.radarStatus?.store?.emergenceCount ?? snap.radarEmergence.count
        let alertCount = snap.alerts.count
        let signalsToday = snap.signals?.signalsToday ?? snap.signalsRuntime?.totalSignals ?? 0

        if activations > 0 { highlights.append("\(activations) radar activaties") }
        if collisions > 0 { highlights.append("\(collisions) botsingen") }
        if emergenceCount > 0 { highlights.append("\(emergenceCount) emergence events") }
        if alertCount > 0 { highlights.append("\(alertCount) alerts") }

        let headline = "\(signalsToday) signalen, \(collisions) botsingen, \(alertCount) alerts."

        return ScreenStateSummary(
            screen: .observatory,
            headline: headline,
            itemCount: signalsToday + collisions + alertCount,
            highlights: highlights,
            isEmpty: signalsToday == 0 && collisions == 0 && alertCount == 0
        )
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
                ],
                gravityHotspots: [
                    RadarGravityHotspot(
                        cell: 14,
                        axes: RadarAxes(what: "architecture", whereValue: "engine", time: "current"),
                        gravityScore: 7.40,
                        band: "red",
                        rank: 1,
                        contributors: ["collision(2)", "external_research(1)"],
                        explanation: "paper-derived hotspot in coordination core"
                    )
                ],
                discoveryCandidates: [
                    RadarDiscoveryCandidate(
                        candidateId: "demo-disc-14",
                        candidateType: "paper_signal_hotspot",
                        candidateScore: 3.33,
                        rank: 1,
                        crossDomain: false,
                        sources: ["external_research(1)"],
                        explanation: "candidate from repeated paper signal pressure"
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
            radarGravityHotspots: [
                RadarGravityHotspot(
                    cell: 14,
                    axes: RadarAxes(what: "architecture", whereValue: "engine", time: "current"),
                    gravityScore: 7.40,
                    band: "red",
                    rank: 1,
                    contributors: ["collision(2)", "external_research(1)"],
                    explanation: "paper-derived hotspot in coordination core"
                )
            ],
            radarDiscoveryCandidates: [
                RadarDiscoveryCandidate(
                    candidateId: "demo-disc-14",
                    candidateType: "paper_signal_hotspot",
                    candidateScore: 3.33,
                    rank: 1,
                    crossDomain: false,
                    sources: ["external_research(1)"],
                    explanation: "candidate from repeated paper signal pressure"
                )
            ],
            fetchedAt: Date()
        )
    }
}
