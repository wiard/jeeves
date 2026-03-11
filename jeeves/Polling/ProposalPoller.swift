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

    enum ProposalDecisionResult {
        case success
        case failure(message: String)
    }

    var proposals: [Proposal] = []
    var pendingProposals: [Proposal] = []
    var extensionProposals: [ExtensionProposal] = []
    var incomingTools: [IncomingToolSummary] = []
    var extensionUsesDemoFallback = false
    var decidedProposals: [DecidedProposal] = []
    var gapProposals: [GovernedGapEntry] = []
    var recentActions: [ActionSummary] = []
    var recentKnowledgeObjects: [KnowledgeObject] = []
    var lastActionReceipt: ActionSummary?
    var lastDecideLinkedKnowledge: [KnowledgeObject] = []
    var conductorState: ConductorState?
    var knowledgeStatus: KnowledgeStatus?
    var safeClashFeed: SafeClashBrowserFeed?
    var emergenceClusters: [EmergenceCluster] = []
    var streamEvents: [ObservatoryStreamEvent] = []
    var radarStatus: RadarStatusSnapshot?
    var radarActivations: [RadarActivation] = []
    var radarCollisions: [RadarCollision] = []
    var radarEmergence: [RadarCollision] = []
    var radarClusters: [RadarClusterSummary] = []
    var radarSources: [RadarSourceStats] = []
    var radarGravityHotspots: [RadarGravityHotspot] = []
    var radarDiscoveryCandidates: [RadarDiscoveryCandidate] = []

    var observatorySnapshot: ObservatorySnapshot = .empty
    var activeEmergenceAlert: EmergenceAlert?
    var bookmarkedClusterIds: Set<String> = []
    var focusedClusterId: String?

    var pendingCount: Int { pendingProposals.count }
    var isDegraded: Bool { hasLoadedOnce && lastRefreshError != nil }
    var seedToastMessage: String?
    var isSeeding = false
    var hasLoadedOnce = false
    var lastRefreshError: String?
    var lastSuccessfulRefreshAt: Date?

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
            hasLoadedOnce = true
            lastRefreshError = nil
            lastSuccessfulRefreshAt = Date()
            return
        }

        let resolvedEndpoint = await gateway.resolveEndpoint()
        guard let token = resolvedEndpoint.token, !token.isEmpty else {
            #if DEBUG
            print("[Jeeves][ProposalPoller] refresh skipped: missing token host=\(resolvedEndpoint.host) port=\(resolvedEndpoint.port)")
            #endif
            lastRefreshError = "Geen token beschikbaar voor \(resolvedEndpoint.host):\(resolvedEndpoint.port)."
            hasLoadedOnce = true
            return
        }

        let client = GatewayClient(host: resolvedEndpoint.host, port: resolvedEndpoint.port, token: token)
        let builder = AuthorizedRequestBuilder(host: resolvedEndpoint.host, port: resolvedEndpoint.port, token: token)
        let safeClashClient = makeSafeClashClient(resolvedEndpoint: resolvedEndpoint)
        #if DEBUG
        print("[Jeeves][ProposalPoller] refresh start host=\(resolvedEndpoint.host) port=\(resolvedEndpoint.port) auth=true connected=\(gateway.isConnected)")
        #endif

        var proposalFetchSucceeded = false
        var observedSuccessfulResponse = false
        var proposalFetchErrorMessage: String?
        async let conductorTask = try? ConductorAPI.state(builder: builder)
        async let knowledgeStatusTask = try? ConductorAPI.knowledgeStatus(builder: builder)
        async let safeClashFeedTask = try? safeClashClient.fetchBrowserFeed()

        do {
            extensionProposals = try await client.fetchExtensionProposals()
            extensionUsesDemoFallback = false
            observedSuccessfulResponse = true
        } catch {
            extensionProposals = demoExtensionProposals()
            extensionUsesDemoFallback = true
        }

        do {
            incomingTools = try await client.fetchIncomingTools()
            observedSuccessfulResponse = true
        } catch {
            if extensionUsesDemoFallback {
                incomingTools = demoIncomingTools()
            }
        }

        do {
            let fetched: [Proposal]
            if let ranked = try? await client.fetchRankedProposals(), !ranked.isEmpty {
                fetched = ranked
            } else {
                fetched = try await client.fetchProposals()
            }
            proposalFetchSucceeded = true
            observedSuccessfulResponse = true
            proposals = fetched

            let pending = fetched.filter(\.isPending)
            let newPendingIds = Set(pending.map(\.proposalId))
            let newOnes = newPendingIds.subtracting(previousPendingIds)

            if !newOnes.isEmpty && !previousPendingIds.isEmpty {
                let newProposals = pending.filter { newOnes.contains($0.proposalId) }
                NotificationManager.shared.notifyNewProposals(newProposals)
            }

            previousPendingIds = newPendingIds
            pendingProposals = pending.sorted { ($0.priorityScore ?? 0) > ($1.priorityScore ?? 0) }
            NotificationManager.shared.updateBadge(count: pending.count)
        } catch {
            proposalFetchErrorMessage = describeRefreshFailure(
                error,
                host: resolvedEndpoint.host,
                port: resolvedEndpoint.port
            )
        }

        if let conductor = await conductorTask {
            conductorState = conductor
            observedSuccessfulResponse = true
        }

        if let knowledge = await knowledgeStatusTask {
            knowledgeStatus = knowledge
            observedSuccessfulResponse = true
        }

        if let feed = await safeClashFeedTask {
            safeClashFeed = feed
            observedSuccessfulResponse = true
        }

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
            async let gravityTask = client.fetchRadarGravity()
            async let discoveriesTask = client.fetchRadarDiscoveries()

            do {
                let stream = try await streamTask
                streamEventsFromApi = stream.events
                observedSuccessfulResponse = true
            } catch {
                #if DEBUG
                print("[Jeeves][ProposalPoller] stream fetch failed: \(error)")
                #endif
            }
            do {
                let runtime = try await signalsRuntimeTask
                let runtimeEvents = Self.runtimeStreamEvents(runtime)
                streamEventsFromApi = Self.mergeStreamEvents(primary: streamEventsFromApi, secondary: runtimeEvents)
                runtimeEmergenceClusters = Self.runtimeEmergenceToClusters(runtime.emergenceClusters)
                observedSuccessfulResponse = true
            } catch {
                #if DEBUG
                print("[Jeeves][ProposalPoller] signals runtime fetch failed: \(error)")
                #endif
            }
            do {
                let status = try await radarStatusTask
                radarStatus = status
                observedSuccessfulResponse = true
            } catch {
                #if DEBUG
                print("[Jeeves][ProposalPoller] radar status fetch failed: \(error)")
                #endif
            }
            if let activations = try? await activationsTask {
                radarActivations = Self.sortRadarActivations(activations)
                observedSuccessfulResponse = true
            }
            if let collisions = try? await collisionsTask {
                radarCollisions = Self.sortRadarCollisions(collisions)
                observedSuccessfulResponse = true
            }
            if let emergence = try? await emergenceTask {
                radarEmergence = Self.sortRadarCollisions(emergence)
                radarEmergenceClusters = Self.radarEmergenceToClusters(radarEmergence)
                observedSuccessfulResponse = true
            }
            if let clusters = try? await clustersTask {
                radarClusters = Self.sortRadarClusters(clusters)
                observedSuccessfulResponse = true
            }
            if let sources = try? await sourcesTask {
                radarSources = Self.sortRadarSources(sources)
                observedSuccessfulResponse = true
            }
            if let hotspots = try? await gravityTask {
                radarGravityHotspots = Self.sortRadarGravity(hotspots)
                observedSuccessfulResponse = true
            }
            if let discoveries = try? await discoveriesTask {
                radarDiscoveryCandidates = Self.sortRadarDiscoveries(discoveries)
                observedSuccessfulResponse = true
            }
        } catch {}

        let feedDiscoveries = Self.discoveryCandidatesFromStream(streamEventsFromApi)
        if !feedDiscoveries.isEmpty {
            radarDiscoveryCandidates = Self.mergeDiscoveryCandidates(
                primary: radarDiscoveryCandidates,
                secondary: feedDiscoveries
            )
            observedSuccessfulResponse = true
        }

        let derivedRadarEvents = Self.radarDerivedStreamEvents(
            activations: radarActivations,
            emergence: radarEmergence,
            hotspots: radarGravityHotspots,
            discoveries: radarDiscoveryCandidates,
            runtimeSummary: radarStatus?.collector?.lastRun
        )
        streamEventsFromApi = Self.mergeStreamEvents(primary: streamEventsFromApi, secondary: derivedRadarEvents)
        streamEvents = Self.sortStreamEvents(streamEventsFromApi)
        #if DEBUG
        print("[Jeeves][ProposalPoller] stream events=\(streamEvents.count) activations=\(radarActivations.count) collisions=\(radarCollisions.count) emergence=\(radarEmergence.count) gravity=\(radarGravityHotspots.count) discoveries=\(radarDiscoveryCandidates.count)")
        #endif

        let knowledgeObjects = try? await client.fetchRecentKnowledgeObjects(limit: 10)
        if let objects = knowledgeObjects {
            recentKnowledgeObjects = objects
            observedSuccessfulResponse = true
        }

        do {
            let decided = try await client.fetchDecidedProposals(limit: 20)
            decidedProposals = decided
            observedSuccessfulResponse = true
        } catch {
            #if DEBUG
            print("[Jeeves][ProposalPoller] decided proposals fetch failed: \(error)")
            #endif
        }

        do {
            let fetchedGaps = try await client.fetchGaps(limit: 40)
            gapProposals = fetchedGaps
            observedSuccessfulResponse = true
        } catch {
            #if DEBUG
            print("[Jeeves][ProposalPoller] gaps fetch failed: \(error)")
            #endif
        }

        do {
            let actions = try await client.fetchActions()
            recentActions = actions.sorted { lhs, rhs in
                let left = lhs.receipt?.completedAtIso ?? lhs.id
                let right = rhs.receipt?.completedAtIso ?? rhs.id
                return left > right
            }
            observedSuccessfulResponse = true
        } catch {
            #if DEBUG
            print("[Jeeves][ProposalPoller] actions fetch failed: \(error)")
            #endif
        }

        do {
            let snapshot = try await client.fetchObservatorySnapshot(proposals: proposals)
            observedSuccessfulResponse = true
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
                    observedSuccessfulResponse = true
                } catch {}
            }
        }

        if !proposalFetchSucceeded && !observedSuccessfulResponse {
            // Keep last known data visible in degraded mode.
        }

        if observedSuccessfulResponse {
            lastSuccessfulRefreshAt = Date()
        }

        if proposalFetchSucceeded {
            lastRefreshError = nil
        } else if let proposalFetchErrorMessage {
            lastRefreshError = proposalFetchErrorMessage
        } else if !observedSuccessfulResponse {
            lastRefreshError = "Backend onbereikbaar op \(resolvedEndpoint.host):\(resolvedEndpoint.port)."
        } else {
            lastRefreshError = nil
        }
        hasLoadedOnce = true
    }


    func decide(
        proposalId: String,
        decision: String,
        reason: String? = nil,
        gateway: GatewayManager
    ) async -> ProposalDecisionResult {
        if gateway.useMock || gateway.host.lowercased() == "mock" {
            applyDemoDecision(proposalId: proposalId, decision: decision)
            return .success
        }

        let resolvedEndpoint = await gateway.resolveEndpoint()
        guard let token = resolvedEndpoint.token, !token.isEmpty else {
            return .failure(message: "Geen token beschikbaar. Voeg een token toe in Instellingen.")
        }

        let client = GatewayClient(host: resolvedEndpoint.host, port: resolvedEndpoint.port, token: token)

        do {
            if gapProposals.contains(where: { $0.gapProposalId == proposalId }) {
                let response = try await client.decideGap(gapProposalId: proposalId, decision: decision, reason: reason)
                if response.ok {
                    lastActionReceipt = nil
                    lastDecideLinkedKnowledge = []
                    await refresh(gateway: gateway)
                    return .success
                }
                await refresh(gateway: gateway)
                return .failure(message: response.reason ?? "Gap-besluit niet bevestigd door backend.")
            }

            let response = try await client.decideProposal(proposalId: proposalId, decision: decision, reason: reason)
            if response.ok {
                if let action = response.action {
                    lastActionReceipt = action
                    // Fetch linked knowledge for output objects
                    if let outputIds = action.receipt?.outputObjectIds, !outputIds.isEmpty {
                        var linked: [KnowledgeObject] = []
                        for objId in outputIds.prefix(5) {
                            if let graph = try? await client.fetchKnowledgeGraph(objectId: objId) {
                                if let root = graph.root { linked.append(root) }
                            }
                        }
                        lastDecideLinkedKnowledge = linked
                    } else {
                        lastDecideLinkedKnowledge = []
                    }
                } else {
                    lastActionReceipt = nil
                    lastDecideLinkedKnowledge = []
                }
                await refresh(gateway: gateway)
                return .success
            }
            await refresh(gateway: gateway)
            return .failure(message: response.reason ?? "Besluit niet bevestigd door backend.")
        } catch {
            await refresh(gateway: gateway)
            if case GatewayClientError.httpStatus(let status) = error {
                if status == 404 {
                    return .failure(message: "Voorstel is al verwerkt of niet meer beschikbaar.")
                }
                if status == 401 {
                    return .failure(message: "Token verlopen of ongeldig.")
                }
                return .failure(message: "Backend fout (\(status)). Probeer opnieuw.")
            }
            return .failure(
                message: describeRefreshFailure(
                    error,
                    host: resolvedEndpoint.host,
                    port: resolvedEndpoint.port
                )
            )
        }
    }

    func seedIfNeeded(gateway: GatewayManager, force: Bool = false) async {
        guard !isSeeding else { return }
        guard force || !hasSeeded else { return }

        if gateway.useMock || gateway.host.lowercased() == "mock" {
            hasSeeded = true
            return
        }

        let resolvedEndpoint = await gateway.resolveEndpoint()
        guard let token = resolvedEndpoint.token, !token.isEmpty else { return }

        isSeeding = true
        let didSeed = await DemoSeed.seedIfNeeded(
            host: resolvedEndpoint.host,
            port: resolvedEndpoint.port,
            token: token
        )
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

    private func describeRefreshFailure(_ error: Error, host: String, port: Int) -> String {
        if case GatewayClientError.httpStatus(let status) = error {
            switch status {
            case 401:
                return "Token ongeldig of verlopen voor \(host):\(port)."
            case 404:
                return "API route niet gevonden op \(host):\(port)."
            default:
                return "Backend fout (\(status)) op \(host):\(port)."
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "Geen netwerkverbinding met \(host):\(port)."
            case .cannotFindHost, .cannotConnectToHost, .timedOut:
                return "Backend onbereikbaar op \(host):\(port)."
            default:
                break
            }
        }
        return "Verbinding met backend mislukt op \(host):\(port)."
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
        conductorState = nil
        knowledgeStatus = nil
        safeClashFeed = nil

        let snapshot = ObservatorySnapshot.demo(tick: demoTick)
        observatorySnapshot = snapshot
        streamEvents = Self.demoStreamEvents(tick: demoTick)
        radarStatus = Self.demoRadarStatus(tick: demoTick)
        radarActivations = Self.demoRadarActivations(tick: demoTick)
        radarCollisions = Self.demoRadarCollisions(tick: demoTick)
        radarEmergence = radarCollisions.filter(\.isEmergence)
        radarClusters = Self.demoRadarClusters(tick: demoTick)
        radarSources = Self.demoRadarSources(tick: demoTick)
        radarGravityHotspots = Self.demoRadarGravityHotspots(tick: demoTick)
        radarDiscoveryCandidates = Self.demoRadarDiscoveryCandidates(tick: demoTick)
        let derivedEvents = Self.radarDerivedStreamEvents(
            activations: radarActivations,
            emergence: radarEmergence,
            hotspots: radarGravityHotspots,
            discoveries: radarDiscoveryCandidates,
            runtimeSummary: ISO8601DateFormatter().string(from: Date())
        )
        streamEvents = Self.sortStreamEvents(Self.mergeStreamEvents(primary: streamEvents, secondary: derivedEvents))

        proposals = demoProposals(tick: demoTick)
        pendingProposals = proposals.filter(\.isPending)
        extensionProposals = demoExtensionProposals()
        incomingTools = demoIncomingTools()
        extensionUsesDemoFallback = true
        decidedProposals = demoDecidedProposals(tick: demoTick)
        gapProposals = []
        recentActions = []
        lastActionReceipt = nil
        lastDecideLinkedKnowledge = []
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

    private func makeSafeClashClient(resolvedEndpoint: ResolvedGatewayEndpoint) -> SafeClashClient {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["SAFECLASH_BASE_URL"] ?? env["SAFECLASH_URL"],
           let url = URL(string: raw),
           let scheme = url.scheme,
           (scheme == "http" || scheme == "https"),
           url.host != nil {
            let token = resolvedEndpoint.token?.trimmingCharacters(in: .whitespacesAndNewlines)
            return SafeClashClient(baseURL: url, token: (token?.isEmpty == false) ? token : nil)
        }

        var components = URLComponents()
        components.scheme = "http"
        components.host = resolvedEndpoint.host
        components.port = resolvedEndpoint.port
        let baseURL = components.url ?? URL(string: "http://localhost:19001")!
        let token = resolvedEndpoint.token?.trimmingCharacters(in: .whitespacesAndNewlines)
        return SafeClashClient(baseURL: baseURL, token: (token?.isEmpty == false) ? token : nil)
    }

    private func demoProposals(tick: Int) -> [Proposal] {
        let now = Date()
        let greenStatus = tick % 3 == 0 ? "pending" : "approved"
        let gapStatus = tick % 6 == 0 ? "deferred" : "pending"
        let orangeStatus = tick % 4 == 0 ? "pending" : "denied"

        let gap = Proposal(
            proposalId: "gap-\(tick % 4)",
            createdAtIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-90)),
            agentId: "clashd27.gap-radar",
            title: "Gap: cross-channel trust corridor is under-mapped",
            intent: ProposalIntent(
                kind: "gap_discovery",
                key: "gap.discovery.trust-corridor",
                risk: "orange",
                requiresConsent: true
            ),
            status: gapStatus,
            priorityScore: 84,
            priorityExplanation: "Multiple discovery signals indicate an unresolved governance blind spot between discovery and approval.",
            rank: 1,
            priorityFactors: ProposalPriorityFactors(
                riskScore: 0.72,
                evidenceStrength: 0.78,
                novelty: 0.81,
                crossDomainRelevance: 0.76,
                escalationSignal: 0.88,
                ageUrgency: 0.58,
                duplicatePressure: 0.44,
                governanceValue: 0.91,
                entropy: 0.69,
                serendipity: 0.63
            ),
            proposalType: "gap_discovery",
            gapDetails: GapProposalDetails(
                summary: "CLASHD27 found a gap where strong discovery evidence enters Jeeves without a crisp operator explanation of why the gap matters to governed execution.",
                sourceEvidence: [
                    GapEvidenceReference(label: "Radar activation", value: "trust-corridor activation cluster"),
                    GapEvidenceReference(label: "Collision trace", value: "signal overlap between policy drift and discovery residue"),
                    GapEvidenceReference(label: "Knowledge residue", value: "operator notes reference the same blind spot without a canonical proposal brief")
                ],
                cubeCell: "trust-model / operator-cockpit / emerging",
                scores: GapProposalScores(
                    novelty: 0.82,
                    collision: 0.67,
                    residue: 0.74,
                    gravity: 0.88,
                    evidence: 0.79,
                    entropy: 0.71,
                    serendipity: 0.66
                ),
                hypothesis: "If the cockpit does not explain governed gaps in operator language, important proposals will be approved late or denied for unclear reasons.",
                verificationPlan: [
                    "Compare recent CLASHD27 gap detections with operator-facing proposal detail available in Jeeves.",
                    "Check whether openclashd-v2 receipts already expose enough audit state to narrate the downstream path.",
                    "Prepare a bounded UI brief that keeps approval human-controlled and execution server-side."
                ],
                killTests: [
                    "Reject if the same operator context is already visible elsewhere in Jeeves.",
                    "Reject if the backend cannot link the proposal to audit or action state.",
                    "Reject if the UI implies client-side execution rather than governed approval."
                ],
                recommendedAction: "Open a bounded verification pass and surface the result as a dedicated Gap Inbox card for operator review."
            )
        )

        let green = Proposal(
            proposalId: "demo-green-\(tick % 5)",
            createdAtIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-120)),
            agentId: "observer.loop",
            title: "Summarize stable residue drift",
            intent: ProposalIntent(kind: "analysis", key: "residue_summary", risk: "green", requiresConsent: false),
            status: greenStatus,
            priorityScore: 35,
            priorityExplanation: nil,
            rank: 2,
            priorityFactors: nil
        )

        let orange = Proposal(
            proposalId: "demo-orange-\(tick % 7)",
            createdAtIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-45)),
            agentId: "observer.fabric",
            title: "Inspect cross-domain anomaly",
            intent: ProposalIntent(kind: "analysis", key: "anomaly_probe", risk: "orange", requiresConsent: true),
            status: orangeStatus,
            priorityScore: 72,
            priorityExplanation: "Cross-domain anomaly with elevated risk",
            rank: 1,
            priorityFactors: nil
        )

        let denied = Proposal(
            proposalId: "demo-red-\(tick % 3)",
            createdAtIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-300)),
            agentId: "observer.guard",
            title: "Rejected high-risk mutation",
            intent: ProposalIntent(kind: "mutation", key: "kernel_override", risk: "red", requiresConsent: true),
            status: "denied",
            priorityScore: 0,
            priorityExplanation: nil,
            rank: nil,
            priorityFactors: nil
        )

        return [gap, orange, green, denied].sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    private func demoExtensionProposals() -> [ExtensionProposal] {
        return [
            ExtensionProposal(
                extensionId: "demo.extension.observer.fabric",
                title: "Observer Fabric Analyzer",
                purpose: "Voert gecontroleerde cross-domain analyse uit op fabric-signalen.",
                capabilities: [
                    ExtensionCapability(key: "fabric.read"),
                    ExtensionCapability(key: "knowledge.write")
                ],
                risk: "orange",
                codeHash: "sha256:4af2e91d31f0",
                entrypoint: "dist/fabric-analyzer.js",
                status: "pending",
                approvedAtIso: nil,
                loadedAtIso: nil,
                sourceType: "system",
                linkedCells: ["architecture|external|current", "surface|engine|current"],
                reasoningTrace: "Cross-domain anomaly cluster vraagt beperkte read/write capability."
            ),
            ExtensionProposal(
                extensionId: "demo.extension.observer.loop",
                title: "Observer Loop Summarizer",
                purpose: "Maakt residue-samenvattingen en koppelt die aan de kennisgraaf.",
                capabilities: [
                    ExtensionCapability(key: "signals.read"),
                    ExtensionCapability(key: "summary.emit")
                ],
                risk: "green",
                codeHash: "sha256:b37f1890ac77",
                entrypoint: "dist/loop-summarizer.js",
                status: "pending",
                approvedAtIso: nil,
                loadedAtIso: nil,
                sourceType: "clashd27",
                linkedCells: ["trust-model|engine|emerging"],
                reasoningTrace: "Stabiele residue drift met lage risico-score; geschikt voor bounded summarization."
            ),
        ]
    }

    private func demoIncomingTools() -> [IncomingToolSummary] {
        demoExtensionProposals().map { proposal in
            let suggested = proposal.title.lowercased().contains("fabric")
                ? "Focused anomaly triage assistant"
                : "Bounded discovery summarizer"

            let actions = IncomingToolActionSet(
                reject: IncomingToolActionState(available: true, endpoint: "/api/extensions/\(proposal.extensionId)/deny"),
                sandbox: IncomingToolActionState(available: false, endpoint: "/api/extensions/\(proposal.extensionId)/load"),
                refine: IncomingToolActionState(available: true, endpoint: nil, hint: "Create a narrower variant before promotion."),
                promote: IncomingToolActionState(available: true, endpoint: "/api/extensions/\(proposal.extensionId)/approve"),
                approveProposal: IncomingToolActionState(available: true, endpoint: "/api/extensions/\(proposal.extensionId)/approve")
            )

            let history = [
                IncomingToolActionHistoryItem(
                    action: "discovered",
                    atIso: ISO8601DateFormatter().string(from: Date()),
                    state: "proposed"
                )
            ]

            return IncomingToolSummary(
                extensionId: proposal.extensionId,
                proposalId: nil,
                status: proposal.status,
                discoveredAtIso: ISO8601DateFormatter().string(from: Date()),
                objectId: proposal.extensionId,
                title: proposal.title,
                source: proposal.sourceType ?? "CLASHD27",
                intentSummary: proposal.purpose,
                capabilitySummary: proposal.capabilities.map(\.title).joined(separator: ", "),
                capabilities: proposal.capabilities.map(\.title),
                risk: proposal.risk,
                suggestedRefinement: suggested,
                suggestedRefinedTool: suggested,
                refinementSuggestions: [suggested],
                linkedCells: proposal.linkedCells,
                explanation: proposal.reasoningTrace ?? proposal.purpose,
                discoveryOrigin: "Mock discovery feed",
                weakPoints: "Demo fallback artifact",
                weakPointsList: ["Demo fallback artifact"],
                evidenceRefs: [
                    IncomingToolEvidenceRef(
                        label: "Evidence",
                        value: "Demo intake trace for \(proposal.extensionId)"
                    )
                ],
                forensicsReportId: nil,
                actionHistory: history,
                actions: actions,
                promotionReady: true,
                refinementState: "suggested",
                sandboxState: "blocked",
                lineageHint: "Discovery -> Forensics -> Proposal"
            )
        }
    }

    private func demoDecidedProposals(tick: Int) -> [DecidedProposal] {
        let now = Date()
        return [
            DecidedProposal(
                proposalId: "gap-approved-1",
                title: "Gap: approval language for discovery evidence",
                agentId: "clashd27.gap-radar",
                status: "approved",
                decidedAtIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-600)),
                decisionReason: "Goedgekeurd door Jeeves iPhone",
                intent: ProposalIntent(kind: "gap_discovery", key: "gap.discovery.operator-language", risk: "orange", requiresConsent: true),
                priorityScore: 82,
                action: ActionSummary(
                    actionId: "gap-action-1",
                    actionKind: "verification",
                    executionState: "completed",
                    receipt: ActionReceipt(
                        receiptId: "gap-receipt-1",
                        actionId: "gap-action-1",
                        completedAtIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-590)),
                        executionState: "completed",
                        resultSummary: "Gap verification brief generated and written to the governed knowledge pipeline.",
                        durationMs: 1240,
                        resultType: "knowledge_object",
                        outputObjectIds: ["ko-gap-approved-1"],
                        notes: "Receipt links the approved gap to a knowledge artifact for later audit."
                    )
                ),
                proposalType: "gap_discovery",
                gapDetails: GapProposalDetails(
                    summary: "A prior operator review confirmed that discovery evidence needed a clearer governance narrative before bounded execution.",
                    sourceEvidence: [
                        GapEvidenceReference(label: "Proposal brief", value: "operator-language review"),
                        GapEvidenceReference(label: "Receipt", value: "gap-receipt-1")
                    ],
                    cubeCell: "discovery / governance / current",
                    scores: GapProposalScores(
                        novelty: 0.71,
                        collision: 0.62,
                        residue: 0.69,
                        gravity: 0.77,
                        evidence: 0.84,
                        entropy: 0.48,
                        serendipity: 0.59
                    ),
                    hypothesis: "Operators move faster when the gap narrative is explicit before approval.",
                    verificationPlan: ["Compare approval latency before and after narrative improvements."],
                    killTests: ["Reject if no measurable approval clarity improvement appears."],
                    recommendedAction: "Keep the narrative template in the governed review path."
                )
            ),
            DecidedProposal(
                proposalId: "gap-denied-1",
                title: "Gap: automatic remediation without operator framing",
                agentId: "observer.fabric",
                status: "denied",
                decidedAtIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-1200)),
                decisionReason: "Afgewezen door Jeeves iPhone",
                intent: ProposalIntent(kind: "gap_discovery", key: "gap.discovery.auto-remediation", risk: "red", requiresConsent: true),
                priorityScore: 68,
                action: nil,
                proposalType: "gap_discovery",
                gapDetails: GapProposalDetails(
                    summary: "This proposal suggested closing a gap with an execution path that was not yet legible enough for human approval.",
                    sourceEvidence: [
                        GapEvidenceReference(label: "Audit note", value: "execution path too implicit"),
                        GapEvidenceReference(label: "Kill test", value: "client UX implied hidden action")
                    ],
                    cubeCell: "execution / operator-cockpit / current",
                    scores: GapProposalScores(
                        novelty: 0.56,
                        collision: 0.81,
                        residue: 0.63,
                        gravity: 0.86,
                        evidence: 0.58,
                        entropy: 0.74,
                        serendipity: 0.34
                    ),
                    hypothesis: "An unclear execution boundary would weaken operator trust.",
                    verificationPlan: ["Re-scope the proposal to approval-only UX before retrying."],
                    killTests: ["Reject if any client flow implies automatic execution."],
                    recommendedAction: "Reframe as a human-only review surface with explicit backend receipts."
                )
            ),
            DecidedProposal(
                proposalId: "decided-3",
                title: "Emit discovery paper brief",
                agentId: "observer.radar",
                status: "approved",
                decidedAtIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-3600)),
                decisionReason: "Goedgekeurd door Jeeves iPhone",
                intent: ProposalIntent(kind: "emit", key: "paper_brief", risk: "green", requiresConsent: false),
                priorityScore: 55,
                action: ActionSummary(
                    actionId: "demo-action-3",
                    actionKind: "emit",
                    executionState: "completed",
                    receipt: ActionReceipt(
                        receiptId: "demo-receipt-3",
                        actionId: "demo-action-3",
                        completedAtIso: ISO8601DateFormatter().string(from: now.addingTimeInterval(-3580)),
                        executionState: "completed",
                        resultSummary: "Paper brief verzonden naar kennisgraaf.",
                        durationMs: 860,
                        resultType: "knowledge_object",
                        outputObjectIds: nil,
                        notes: "Cross-domain relevance detected"
                    )
                )
            ),
        ]
    }

    private func applyDemoDecision(proposalId: String, decision: String) {
        guard let index = proposals.firstIndex(where: { $0.proposalId == proposalId }) else { return }

        let current = proposals[index]
        let nextStatus: String
        switch decision {
        case "approve":
            nextStatus = "approved"
        case "defer":
            nextStatus = "deferred"
        default:
            nextStatus = "denied"
        }
        let updated = Proposal(
            proposalId: current.proposalId,
            createdAtIso: current.createdAtIso,
            agentId: current.agentId,
            title: current.title,
            intent: current.intent,
            status: nextStatus,
            priorityScore: current.priorityScore,
            priorityExplanation: current.priorityExplanation,
            rank: current.rank,
            priorityFactors: current.priorityFactors,
            proposalType: current.proposalType,
            gapDetails: current.gapDetails
        )

        proposals[index] = updated
        pendingProposals = proposals.filter(\.isPending)

        if decision == "approve" {
            let now = Date()
            let isoNow = ISO8601DateFormatter().string(from: now)
            lastActionReceipt = ActionSummary(
                actionId: "demo-action-\(proposalId)",
                actionKind: current.intent.kind,
                executionState: "completed",
                receipt: ActionReceipt(
                    receiptId: "demo-receipt-\(proposalId)",
                    actionId: "demo-action-\(proposalId)",
                    completedAtIso: isoNow,
                    executionState: "completed",
                    resultSummary: "Actie '\(current.title)' succesvol uitgevoerd.",
                    durationMs: 980,
                    resultType: "report",
                    outputObjectIds: nil,
                    notes: nil
                )
            )
            lastDecideLinkedKnowledge = []
        } else {
            lastActionReceipt = nil
            lastDecideLinkedKnowledge = []
        }

        let newDecision = JeevesDecisionEvent(
            id: "demo-decision-\(UUID().uuidString)",
            kind: decision == "approve" ? .autoApproved : (decision == "defer" ? .escalated : .autoDenied),
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

    private static func sortRadarGravity(_ hotspots: [RadarGravityHotspot]) -> [RadarGravityHotspot] {
        hotspots.sorted { lhs, rhs in
            if lhs.gravityScore != rhs.gravityScore {
                return lhs.gravityScore > rhs.gravityScore
            }
            if lhs.rank != rhs.rank {
                return lhs.rank < rhs.rank
            }
            if lhs.cell != rhs.cell {
                return lhs.cell < rhs.cell
            }
            return lhs.id < rhs.id
        }
    }

    private static func sortRadarDiscoveries(_ discoveries: [RadarDiscoveryCandidate]) -> [RadarDiscoveryCandidate] {
        discoveries.sorted { lhs, rhs in
            if lhs.candidateScore != rhs.candidateScore {
                return lhs.candidateScore > rhs.candidateScore
            }
            if lhs.rank != rhs.rank {
                return lhs.rank < rhs.rank
            }
            return lhs.candidateId < rhs.candidateId
        }
    }

    private static func mergeDiscoveryCandidates(
        primary: [RadarDiscoveryCandidate],
        secondary: [RadarDiscoveryCandidate]
    ) -> [RadarDiscoveryCandidate] {
        var byId: [String: RadarDiscoveryCandidate] = [:]
        for candidate in primary {
            byId[candidate.candidateId] = candidate
        }
        for candidate in secondary where byId[candidate.candidateId] == nil {
            byId[candidate.candidateId] = candidate
        }
        return sortRadarDiscoveries(Array(byId.values))
    }

    private static func discoveryCandidatesFromStream(_ events: [ObservatoryStreamEvent]) -> [RadarDiscoveryCandidate] {
        var discovered: [RadarDiscoveryCandidate] = []
        for (index, event) in events.enumerated() {
            guard event.isDiscoveryCandidate || event.type == "discovery_candidate" else { continue }

            let candidateId = event.candidateId ?? event.signalId ?? event.id
            let candidateType = event.candidateType
                ?? event.title
                ?? event.event
                ?? "emerging_signal"
            let candidateScore = event.candidateScore ?? event.gravityScore ?? 0.5
            let rank = event.rank ?? (index + 1)
            let crossDomain = event.crossDomain
                ?? ((event.reason ?? "").localizedCaseInsensitiveContains("cross"))
            let sources = inferredSources(from: event)
            let explanation = event.explanation
                ?? event.summary
                ?? event.title
                ?? "Signal needs human review."

            discovered.append(
                RadarDiscoveryCandidate(
                    candidateId: candidateId,
                    candidateType: candidateType,
                    candidateScore: candidateScore,
                    rank: rank,
                    crossDomain: crossDomain,
                    sources: sources,
                    explanation: explanation
                )
            )
        }
        return sortRadarDiscoveries(deduplicateDiscoveries(discovered))
    }

    private static func deduplicateDiscoveries(_ discoveries: [RadarDiscoveryCandidate]) -> [RadarDiscoveryCandidate] {
        var seen: Set<String> = []
        var unique: [RadarDiscoveryCandidate] = []
        for candidate in discoveries {
            if seen.insert(candidate.candidateId).inserted {
                unique.append(candidate)
            }
        }
        return unique
    }

    private static func inferredSources(from event: ObservatoryStreamEvent) -> [String] {
        if let reason = event.reason, reason.contains("/") {
            let parts = reason
                .split(separator: "/")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !parts.isEmpty {
                return parts
            }
        }
        if let sourceId = event.sourceId, !sourceId.isEmpty {
            return [sourceId]
        }
        if let agentId = event.agentId, !agentId.isEmpty {
            return [agentId]
        }
        return []
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
                type: "signal_detected",
                timestampIso: signal.detectedAtIso,
                event: nil,
                proposalId: nil,
                agentId: signal.sourceId ?? "signals",
                title: signal.summary ?? "signal",
                summary: signal.summary,
                signalId: signal.signalId,
                sourceId: signal.sourceId,
                decision: nil,
                reason: nil,
                risk: nil,
                peerId: "system"
            )
        }
        let challengeEvents = runtime.lastChallenges.map { challenge in
            ObservatoryStreamEvent(
                id: "runtime-challenge-\(challenge.challengeId)",
                type: "challenge_open",
                timestampIso: challenge.createdAtIso,
                event: challenge.status,
                clusterId: nil,
                proposalId: nil,
                agentId: "signals",
                title: challenge.title ?? "challenge",
                summary: nil,
                signalId: nil,
                sourceId: nil,
                challengeId: challenge.challengeId,
                decision: nil,
                reason: nil,
                risk: nil,
                peerId: "system"
            )
        }
        let emergenceEvents = runtime.emergenceClusters.map { cluster in
            ObservatoryStreamEvent(
                id: "runtime-emergence-\(cluster.clusterId)",
                type: "emergence_cluster",
                timestampIso: runtime.lastRunAtIso,
                event: nil,
                clusterId: cluster.clusterId,
                proposalId: nil,
                agentId: "signals",
                title: cluster.summary ?? "emergence",
                decision: nil,
                reason: "runtime_cluster",
                risk: nil,
                peerId: "system"
            )
        }
        let summaryEvent = ObservatoryStreamEvent(
            id: "runtime-summary-\(runtime.lastRunAtIso ?? "none")",
            type: "runtime_summary",
            timestampIso: runtime.lastRunAtIso,
            event: nil,
            proposalId: nil,
            agentId: "signals",
            title: "Runtime cycle",
            summary: "\(runtime.totalSignals) signals · \(runtime.lastChallenges.count) challenges",
            decision: nil,
            reason: runtime.lastError,
            risk: nil,
            peerId: "system"
        )
        return signalEvents + challengeEvents + emergenceEvents + [summaryEvent]
    }

    private static func radarDerivedStreamEvents(
        activations: [RadarActivation],
        emergence: [RadarCollision],
        hotspots: [RadarGravityHotspot],
        discoveries: [RadarDiscoveryCandidate],
        runtimeSummary: String?
    ) -> [ObservatoryStreamEvent] {
        let fallbackTimestamp = runtimeSummary ?? ISO8601DateFormatter().string(from: Date())
        let activationEvents = activations.map { activation in
            ObservatoryStreamEvent(
                id: "radar-activation-\(activation.id)",
                type: "signal_detected",
                timestampIso: activation.timestampIso ?? fallbackTimestamp,
                event: nil,
                proposalId: nil,
                agentId: "radar",
                title: activation.title,
                summary: activation.summary,
                signalId: activation.id,
                sourceId: activation.source,
                decision: nil,
                reason: activation.clusters.isEmpty ? nil : activation.clusters.joined(separator: "/"),
                risk: nil,
                peerId: "radar"
            )
        }
        let emergenceEvents = emergence.filter(\.isEmergence).map { collision in
            ObservatoryStreamEvent(
                id: "radar-emergence-\(collision.id)",
                type: "emergence_cluster",
                timestampIso: collision.detectedAtIso ?? fallbackTimestamp,
                event: nil,
                clusterId: collision.id,
                proposalId: nil,
                agentId: "radar",
                title: collision.signalTitles.first ?? "Emergence cluster",
                summary: collision.signalTitles.first,
                decision: nil,
                reason: collision.sources.joined(separator: "/"),
                risk: nil,
                peerId: "radar"
            )
        }
        let hotspotEvents = hotspots.map { hotspot in
            ObservatoryStreamEvent(
                id: "radar-gravity-\(hotspot.cell)-\(hotspot.rank)",
                type: "gravity_hotspot",
                timestampIso: fallbackTimestamp,
                event: nil,
                proposalId: nil,
                agentId: "radar",
                title: "Gravity hotspot cell \(hotspot.cell)",
                summary: hotspot.explanation,
                decision: nil,
                reason: nil,
                risk: nil,
                peerId: "radar",
                explanation: hotspot.explanation,
                gravityScore: hotspot.gravityScore,
                band: hotspot.band,
                rank: hotspot.rank
            )
        }
        let discoveryEvents = discoveries.map { candidate in
            ObservatoryStreamEvent(
                id: "radar-discovery-\(candidate.candidateId)",
                type: "discovery_candidate",
                timestampIso: fallbackTimestamp,
                event: nil,
                proposalId: nil,
                agentId: "radar",
                title: candidate.candidateId,
                summary: candidate.explanation,
                decision: nil,
                reason: candidate.sources.joined(separator: "/"),
                risk: nil,
                peerId: "radar",
                explanation: candidate.explanation,
                candidateScore: candidate.candidateScore,
                candidateType: candidate.candidateType,
                candidateId: candidate.candidateId,
                crossDomain: candidate.crossDomain,
                rank: candidate.rank
            )
        }
        return activationEvents + emergenceEvents + hotspotEvents + discoveryEvents
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

    private static func demoRadarGravityHotspots(tick: Int) -> [RadarGravityHotspot] {
        sortRadarGravity([
            RadarGravityHotspot(
                cell: 14,
                axes: RadarAxes(what: "surface", whereValue: "external", time: "current"),
                gravityScore: 24.0 + Double(tick % 5),
                band: "red",
                rank: 1,
                contributors: ["openalex", "arxiv"],
                explanation: "Paper pressure around cross-channel relay safety"
            ),
            RadarGravityHotspot(
                cell: 23,
                axes: RadarAxes(what: "architecture", whereValue: "external", time: "emerging"),
                gravityScore: 18.4 + Double(tick % 3),
                band: "yellow",
                rank: 2,
                contributors: ["github", "openalex"],
                explanation: "Growing alignment on open research interoperability"
            )
        ])
    }

    private static func demoRadarDiscoveryCandidates(tick: Int) -> [RadarDiscoveryCandidate] {
        sortRadarDiscoveries([
            RadarDiscoveryCandidate(
                candidateId: "disc-\(tick)-agents-consent",
                candidateType: "research_hypothesis",
                candidateScore: 0.89,
                rank: 1,
                crossDomain: true,
                sources: ["openalex", "arxiv", "github"],
                explanation: "Agent consent patterns converge with relay hardening proposals"
            ),
            RadarDiscoveryCandidate(
                candidateId: "disc-\(tick)-utxo-audit",
                candidateType: "knowledge_seed",
                candidateScore: 0.76,
                rank: 2,
                crossDomain: false,
                sources: ["arxiv", "openalex"],
                explanation: "UTXO governance audit papers align with current signal drift"
            )
        ])
    }
}

// MARK: - ScreenStateReadable

extension ProposalPoller: ScreenStateReadable {
    var screenId: AppScreen { .stream }

    func summary() -> ScreenStateSummary {
        let pending = pendingProposals.count
        let clusters = emergenceClusters.count
        let events = streamEvents.count

        var highlights: [String] = []
        if pending > 0 { highlights.append("\(pending) voorstellen wachten op goedkeuring") }
        if clusters > 0 { highlights.append("\(clusters) emergence clusters") }

        let headline: String
        if pending > 0 {
            headline = "\(pending) openstaande goedkeuringen, \(events) stream events."
        } else {
            headline = "Geen openstaande goedkeuringen. \(events) recente events."
        }

        return ScreenStateSummary(
            screen: .stream,
            headline: headline,
            itemCount: pending + events,
            highlights: highlights,
            isEmpty: pending == 0 && events == 0 && clusters == 0
        )
    }
}
