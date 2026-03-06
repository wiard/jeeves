import Foundation
import Observation

@MainActor
@Observable
final class ProposalPoller {
    enum EmergenceAlertAction {
        case investigate
        case ignore
        case bookmark
    }

    var proposals: [Proposal] = []
    var pendingProposals: [Proposal] = []
    var emergenceClusters: [EmergenceCluster] = []
    var streamEvents: [ObservatoryStreamEvent] = []
    var radarStatus: RadarStatusSnapshot?
    var radarActivations: [RadarActivation] = []
    var radarCollisions: [RadarCollision] = []
    var radarEmergence: [RadarCollision] = []
    var radarClusters: [RadarClusterSummary] = []
    var radarSources: [RadarSourceStats] = []

    var observatorySnapshot: ObservatorySnapshot = .empty
    var activeEmergenceAlert: EmergenceAlert?
    var bookmarkedClusterIds: Set<String> = []
    var focusedClusterId: String?

    var pendingCount: Int { pendingProposals.count }
    var seedToastMessage: String?
    var isSeeding = false

    private var pollingTask: Task<Void, Never>?
    private var previousPendingIds: Set<String> = []
    private var previousEmergenceIds: Set<String> = []
    private var demoTick = 0
    private var hasSeeded = false

    func start(gateway: GatewayManager) {
        stop()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh(gateway: gateway)
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh(gateway: GatewayManager) async {
        if gateway.useMock || gateway.host.lowercased() == "mock" {
            refreshDemoState()
            return
        }

        guard gateway.isConnected else {
            #if DEBUG
            print("[Jeeves][ProposalPoller] refresh skipped: gateway not connected host=\(gateway.host) port=\(gateway.port)")
            #endif
            return
        }

        let token = resolveToken(gateway: gateway)
        guard let token, !token.isEmpty else {
            #if DEBUG
            print("[Jeeves][ProposalPoller] refresh skipped: missing token host=\(gateway.host) port=\(gateway.port)")
            #endif
            return
        }

        let client = GatewayClient(host: gateway.host, port: gateway.port, token: token)
        #if DEBUG
        print("[Jeeves][ProposalPoller] refresh start host=\(gateway.host) port=\(gateway.port) auth=true")
        #endif

        do {
            let fetched = try await client.fetchProposals()
            proposals = fetched

            let pending = fetched.filter(\.isPending)
            let newPendingIds = Set(pending.map(\.proposalId))
            let newOnes = newPendingIds.subtracting(previousPendingIds)

            if !newOnes.isEmpty && !previousPendingIds.isEmpty {
                let newProposals = pending.filter { newOnes.contains($0.proposalId) }
                NotificationManager.shared.notifyNewProposals(newProposals)
            }

            previousPendingIds = newPendingIds
            pendingProposals = pending
            NotificationManager.shared.updateBadge(count: pending.count)
        } catch {}

        var runtimeEmergenceClusters: [EmergenceCluster] = []
        var radarEmergenceClusters: [EmergenceCluster] = []
        var streamEventsFromApi: [ObservatoryStreamEvent] = []
        do {
            async let streamTask = client.fetchObservatoryStream(limit: 60)
            async let signalsRuntimeTask = client.fetchSignalsRuntime()
            async let radarStatusTask = client.fetchRadarStatus()
            async let activationsTask = client.fetchRadarActivations(limit: 40)
            async let collisionsTask = client.fetchRadarCollisions()
            async let emergenceTask = client.fetchRadarEmergence()
            async let clustersTask = client.fetchRadarClusters()
            async let sourcesTask = client.fetchRadarSources()

            if let stream = try? await streamTask {
                streamEventsFromApi = stream.events
            }
            if let runtime = try? await signalsRuntimeTask {
                let runtimeEvents = Self.runtimeStreamEvents(runtime)
                streamEventsFromApi = Self.mergeStreamEvents(primary: streamEventsFromApi, secondary: runtimeEvents)
                runtimeEmergenceClusters = Self.runtimeEmergenceToClusters(runtime.emergenceClusters)
            }
            if let status = try? await radarStatusTask {
                radarStatus = status
            }
            if let activations = try? await activationsTask {
                radarActivations = Self.sortRadarActivations(activations)
            }
            if let collisions = try? await collisionsTask {
                radarCollisions = Self.sortRadarCollisions(collisions)
            }
            if let emergence = try? await emergenceTask {
                radarEmergence = Self.sortRadarCollisions(emergence)
                radarEmergenceClusters = Self.radarEmergenceToClusters(radarEmergence)
            }
            if let clusters = try? await clustersTask {
                radarClusters = Self.sortRadarClusters(clusters)
            }
            if let sources = try? await sourcesTask {
                radarSources = Self.sortRadarSources(sources)
            }
        } catch {}
        streamEvents = Self.sortStreamEvents(streamEventsFromApi)
        #if DEBUG
        print("[Jeeves][ProposalPoller] stream events=\(streamEvents.count) activations=\(radarActivations.count) collisions=\(radarCollisions.count) emergence=\(radarEmergence.count)")
        #endif

        do {
            let snapshot = try await client.fetchObservatorySnapshot(proposals: proposals)
            observatorySnapshot = snapshot

            var escalatedClusters = snapshot.collisions
                .filter(\.isEmergence)
                .map { cluster in
                    EmergenceCluster(
                        clusterId: cluster.clusterId,
                        dimensions: cluster.sourceTypes,
                        relevanceScore: cluster.densityScore,
                        summary: cluster.summary,
                        escalatesToIphone: cluster.isEmergence
                    )
                }

            if escalatedClusters.isEmpty {
                escalatedClusters = radarEmergenceClusters
            }
            if escalatedClusters.isEmpty {
                escalatedClusters = runtimeEmergenceClusters
            }

            processEmergenceChanges(escalatedClusters)
        } catch {
            if !radarEmergenceClusters.isEmpty {
                processEmergenceChanges(radarEmergenceClusters)
            } else if !runtimeEmergenceClusters.isEmpty {
                processEmergenceChanges(runtimeEmergenceClusters)
            } else {
                do {
                    let clusters = try await client.fetchEmergence()
                    let escalated = clusters.filter(\.escalatesToIphone)
                    processEmergenceChanges(escalated)
                } catch {}
            }
        }
    }

    private func resolveToken(gateway: GatewayManager) -> String? {
        if let runtimeToken = RuntimeConfig.shared.token?.trimmingCharacters(in: .whitespacesAndNewlines),
           !runtimeToken.isEmpty {
            return runtimeToken
        }
        if let gatewayToken = gateway.token?.trimmingCharacters(in: .whitespacesAndNewlines),
           !gatewayToken.isEmpty {
            return gatewayToken
        }
        if let stored = KeychainHelper.load(for: "\(gateway.host):\(gateway.port)"),
           !stored.isEmpty {
            return stored
        }
        return nil
    }

    func decide(proposalId: String, decision: String, reason: String? = nil, gateway: GatewayManager) async -> Bool {
        if gateway.useMock || gateway.host.lowercased() == "mock" {
            applyDemoDecision(proposalId: proposalId, decision: decision)
            return true
        }

        guard let token = gateway.token else { return false }

        let client = GatewayClient(host: gateway.host, port: gateway.port, token: token)

        do {
            let response = try await client.decideProposal(proposalId: proposalId, decision: decision, reason: reason)
            if response.ok {
                await refresh(gateway: gateway)
            }
            return response.ok
        } catch {
            return false
        }
    }

    func seedIfNeeded(gateway: GatewayManager, force: Bool = false) async {
        guard !isSeeding else { return }
        guard force || !hasSeeded else { return }

        if gateway.useMock || gateway.host.lowercased() == "mock" {
            hasSeeded = true
            return
        }

        guard let token = gateway.token else { return }

        isSeeding = true
        let didSeed = await DemoSeed.seedIfNeeded(host: gateway.host, port: gateway.port, token: token)
        isSeeding = false

        if didSeed {
            hasSeeded = true
            seedToastMessage = TextKeys.Seed.toast
            await refresh(gateway: gateway)
            try? await Task.sleep(for: .seconds(3))
            seedToastMessage = nil
        } else {
            hasSeeded = true
        }
    }

    func handleEmergenceAlertAction(_ action: EmergenceAlertAction, clusterId: String) {
        switch action {
        case .investigate:
            focusedClusterId = clusterId
        case .bookmark:
            bookmarkedClusterIds.insert(clusterId)
            focusedClusterId = clusterId
        case .ignore:
            break
        }

        activeEmergenceAlert = nil
    }

    func dismissEmergenceAlert() {
        activeEmergenceAlert = nil
    }

    private func processEmergenceChanges(_ clusters: [EmergenceCluster]) {
        let escalated = clusters.filter(\.escalatesToIphone)
        let newClusterIds = Set(escalated.map(\.clusterId))
        let newOnes = newClusterIds.subtracting(previousEmergenceIds)

        if !newOnes.isEmpty {
            if !previousEmergenceIds.isEmpty {
                for cluster in escalated where newOnes.contains(cluster.clusterId) {
                    NotificationManager.shared.notifyEmergence(cluster)
                }
            }

            if let first = escalated.first(where: { newOnes.contains($0.clusterId) }) {
                let normalized = KnowledgeCollisionCluster(
                    clusterId: first.clusterId,
                    sourceTypes: first.dimensions,
                    densityScore: first.relevanceScore,
                    cubePosition: CubePosition(x: 1, y: 1, z: 1),
                    summary: first.summary,
                    isEmergence: true
                )
                activeEmergenceAlert = EmergenceAlert.fromCluster(normalized)
            }
        }

        previousEmergenceIds = newClusterIds
        emergenceClusters = escalated
    }

    private func refreshDemoState() {
        demoTick += 1

        let snapshot = ObservatorySnapshot.demo(tick: demoTick)
        observatorySnapshot = snapshot
        streamEvents = Self.demoStreamEvents(tick: demoTick)
        radarStatus = Self.demoRadarStatus(tick: demoTick)
        radarActivations = Self.demoRadarActivations(tick: demoTick)
        radarCollisions = Self.demoRadarCollisions(tick: demoTick)
        radarEmergence = radarCollisions.filter(\.isEmergence)
        radarClusters = Self.demoRadarClusters(tick: demoTick)
        radarSources = Self.demoRadarSources(tick: demoTick)

        proposals = demoProposals(tick: demoTick)
        pendingProposals = proposals.filter(\.isPending)
        NotificationManager.shared.updateBadge(count: pendingProposals.count)

        let escalated = snapshot.collisions
            .filter(\.isEmergence)
            .map { cluster in
                EmergenceCluster(
                    clusterId: cluster.clusterId,
                    dimensions: cluster.sourceTypes,
                    relevanceScore: cluster.densityScore,
                    summary: cluster.summary,
                    escalatesToIphone: cluster.isEmergence
                )
            }

        processEmergenceChanges(escalated)
    }

    private func demoProposals(tick: Int) -> [Proposal] {
        let now = Date()
        let greenStatus = tick % 3 == 0 ? "pending" : "approved"
        let orangeStatus = tick % 4 == 0 ? "pending" : "denied"

        let green = Proposal(
            proposalId: "demo-green-\(tick % 5)",
            createdAtIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-120)),
            agentId: "observer.loop",
            title: "Summarize stable residue drift",
            intent: ProposalIntent(kind: "analysis", key: "residue_summary", risk: "green", requiresConsent: false),
            status: greenStatus
        )

        let orange = Proposal(
            proposalId: "demo-orange-\(tick % 7)",
            createdAtIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-45)),
            agentId: "observer.fabric",
            title: "Inspect cross-domain anomaly",
            intent: ProposalIntent(kind: "analysis", key: "anomaly_probe", risk: "orange", requiresConsent: true),
            status: orangeStatus
        )

        let denied = Proposal(
            proposalId: "demo-red-\(tick % 3)",
            createdAtIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-300)),
            agentId: "observer.guard",
            title: "Rejected high-risk mutation",
            intent: ProposalIntent(kind: "mutation", key: "kernel_override", risk: "red", requiresConsent: true),
            status: "denied"
        )

        return [orange, green, denied].sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    private func applyDemoDecision(proposalId: String, decision: String) {
        guard let index = proposals.firstIndex(where: { $0.proposalId == proposalId }) else { return }

        let current = proposals[index]
        let updated = Proposal(
            proposalId: current.proposalId,
            createdAtIso: current.createdAtIso,
            agentId: current.agentId,
            title: current.title,
            intent: current.intent,
            status: decision == "approve" ? "approved" : "denied"
        )

        proposals[index] = updated
        pendingProposals = proposals.filter(\.isPending)

        let newDecision = JeevesDecisionEvent(
            id: "demo-decision-\(UUID().uuidString)",
            kind: decision == "approve" ? .autoApproved : .autoDenied,
            title: current.title,
            timestamp: Date()
        )

        observatorySnapshot = ObservatorySnapshot(
            loop: observatorySnapshot.loop,
            field: observatorySnapshot.field,
            collisions: observatorySnapshot.collisions,
            decisions: [newDecision] + observatorySnapshot.decisions,
            updatedAt: Date()
        )
    }

    private static func sortStreamEvents(_ events: [ObservatoryStreamEvent]) -> [ObservatoryStreamEvent] {
        events.sorted { lhs, rhs in
            let lDate = parseIso(lhs.timestampIso)
            let rDate = parseIso(rhs.timestampIso)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.id < rhs.id
        }
    }

    private static func sortRadarActivations(_ activations: [RadarActivation]) -> [RadarActivation] {
        activations.sorted { lhs, rhs in
            let lDate = parseIso(lhs.timestampIso)
            let rDate = parseIso(rhs.timestampIso)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.id < rhs.id
        }
    }

    private static func sortRadarCollisions(_ collisions: [RadarCollision]) -> [RadarCollision] {
        collisions.sorted { lhs, rhs in
            if lhs.density != rhs.density {
                return lhs.density > rhs.density
            }
            let lDate = parseIso(lhs.detectedAtIso)
            let rDate = parseIso(rhs.detectedAtIso)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.id < rhs.id
        }
    }

    private static func sortRadarClusters(_ clusters: [RadarClusterSummary]) -> [RadarClusterSummary] {
        clusters.sorted { lhs, rhs in
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return lhs.cluster < rhs.cluster
        }
    }

    private static func sortRadarSources(_ sources: [RadarSourceStats]) -> [RadarSourceStats] {
        sources.sorted { lhs, rhs in
            let lDate = parseIso(lhs.lastFetch)
            let rDate = parseIso(rhs.lastFetch)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.source < rhs.source
        }
    }

    private static func radarEmergenceToClusters(_ collisions: [RadarCollision]) -> [EmergenceCluster] {
        collisions
            .filter(\.isEmergence)
            .map { collision in
                EmergenceCluster(
                    clusterId: collision.id,
                    dimensions: collision.sources,
                    relevanceScore: collision.density,
                    summary: collision.signalTitles.first ?? "Emergence detected",
                    escalatesToIphone: true
                )
            }
    }

    private static func runtimeStreamEvents(_ runtime: SignalsRuntimeSnapshot) -> [ObservatoryStreamEvent] {
        let signalEvents = runtime.lastSignals.map { signal in
            ObservatoryStreamEvent(
                id: "runtime-signal-\(signal.signalId)",
                type: "signal",
                timestampIso: signal.detectedAtIso,
                event: nil,
                proposalId: nil,
                agentId: signal.sourceId ?? "signals",
                title: signal.summary ?? "signal",
                decision: nil,
                reason: nil,
                risk: nil,
                peerId: "system"
            )
        }
        let challengeEvents = runtime.lastChallenges.map { challenge in
            ObservatoryStreamEvent(
                id: "runtime-challenge-\(challenge.challengeId)",
                type: "challenge",
                timestampIso: challenge.createdAtIso,
                event: challenge.status,
                proposalId: nil,
                agentId: "signals",
                title: challenge.title ?? "challenge",
                decision: nil,
                reason: nil,
                risk: nil,
                peerId: "system"
            )
        }
        let emergenceEvents = runtime.emergenceClusters.map { cluster in
            ObservatoryStreamEvent(
                id: "runtime-emergence-\(cluster.clusterId)",
                type: "emergence",
                timestampIso: runtime.lastRunAtIso,
                event: nil,
                proposalId: nil,
                agentId: "signals",
                title: cluster.summary ?? "emergence",
                decision: nil,
                reason: "runtime_cluster",
                risk: nil,
                peerId: "system"
            )
        }
        return signalEvents + challengeEvents + emergenceEvents
    }

    private static func runtimeEmergenceToClusters(_ clusters: [SignalsRuntimeEmergenceCluster]) -> [EmergenceCluster] {
        clusters.map { cluster in
            EmergenceCluster(
                clusterId: cluster.clusterId,
                dimensions: cluster.dimensions,
                relevanceScore: cluster.relevanceScore,
                summary: cluster.summary ?? "Runtime emergence detected",
                escalatesToIphone: cluster.escalatesToIphone
            )
        }
    }

    private static func mergeStreamEvents(
        primary: [ObservatoryStreamEvent],
        secondary: [ObservatoryStreamEvent]
    ) -> [ObservatoryStreamEvent] {
        var byId: [String: ObservatoryStreamEvent] = [:]
        for event in primary {
            byId[event.id] = event
        }
        for event in secondary where byId[event.id] == nil {
            byId[event.id] = event
        }
        return Array(byId.values)
    }

    private static func parseIso(_ value: String?) -> Date {
        guard let value else { return .distantPast }
        return ISO8601DateFormatter().date(from: value) ?? .distantPast
    }

    private static func demoStreamEvents(tick: Int) -> [ObservatoryStreamEvent] {
        let now = Date()
        return sortStreamEvents([
            ObservatoryStreamEvent(
                id: "demo-stream-pending-\(tick)",
                type: "proposal_pending",
                timestampIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-30)),
                event: nil,
                proposalId: "demo-orange-\(tick % 7)",
                agentId: "observer.fabric",
                title: "Inspect cross-domain anomaly",
                decision: nil,
                reason: nil,
                risk: "orange",
                peerId: nil
            ),
            ObservatoryStreamEvent(
                id: "demo-stream-audit-\(tick)",
                type: "audit",
                timestampIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-120)),
                event: "challenge.created",
                proposalId: nil,
                agentId: "signals",
                title: nil,
                decision: "allow",
                reason: "signal_generated",
                risk: nil,
                peerId: "system"
            )
        ])
    }

    private static func demoRadarStatus(tick: Int) -> RadarStatusSnapshot {
        RadarStatusSnapshot(
            store: RadarStoreStatus(
                activationCount: 10 + (tick % 4),
                collisionCount: 2 + (tick % 3),
                emergenceCount: 1 + (tick % 2),
                lastFetchBySource: ["github": ISO8601DateFormatter().string(from: Date())],
                hotClusters: [
                    RadarHotCluster(cluster: "architecture", count: 4),
                    RadarHotCluster(cluster: "surface", count: 3)
                ],
                topSignals: [
                    RadarTopSignal(title: "consent relay drift", source: "github", residue: 0.82),
                    RadarTopSignal(title: "cluster pressure", source: "arxiv", residue: 0.74)
                ]
            ),
            collector: RadarCollectorStatus(isRunning: true, lastRun: ISO8601DateFormatter().string(from: Date()))
        )
    }

    private static func demoRadarActivations(tick: Int) -> [RadarActivation] {
        sortRadarActivations([
            RadarActivation(
                id: "demo-activation-\(tick)-1",
                source: "github",
                title: "consent relay drift",
                summary: "Cross-source relay trend.",
                residue: 0.82,
                timestampIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-20)),
                clusters: ["architecture", "surface"],
                cellIds: ["surface|external|current"]
            ),
            RadarActivation(
                id: "demo-activation-\(tick)-2",
                source: "arxiv",
                title: "agent governance update",
                summary: "Research signal on approval constraints.",
                residue: 0.71,
                timestampIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-200)),
                clusters: ["trust-model"],
                cellIds: ["trust-model|engine|current"]
            )
        ])
    }

    private static func demoRadarCollisions(tick: Int) -> [RadarCollision] {
        sortRadarCollisions([
            RadarCollision(
                id: "demo-collision-\(tick)-1",
                sources: ["github", "arxiv"],
                density: 0.79,
                isEmergence: true,
                detectedAtIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-40)),
                cellIds: ["surface|external|current"],
                signalTitles: ["consent relay drift"]
            ),
            RadarCollision(
                id: "demo-collision-\(tick)-2",
                sources: ["manual", "github"],
                density: 0.54,
                isEmergence: false,
                detectedAtIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-320)),
                cellIds: ["architecture|external|current"],
                signalTitles: ["cluster pressure"]
            )
        ])
    }

    private static func demoRadarClusters(tick: Int) -> [RadarClusterSummary] {
        sortRadarClusters([
            RadarClusterSummary(cluster: "architecture", label: "Architecture", count: 4 + (tick % 2)),
            RadarClusterSummary(cluster: "surface", label: "Surface", count: 3)
        ])
    }

    private static func demoRadarSources(tick: Int) -> [RadarSourceStats] {
        sortRadarSources([
            RadarSourceStats(
                source: "github",
                signalCount: 6 + (tick % 2),
                avgResidue: 0.43,
                lastFetch: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60))
            ),
            RadarSourceStats(
                source: "arxiv",
                signalCount: 4,
                avgResidue: 0.38,
                lastFetch: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-180))
            )
        ])
    }
}
