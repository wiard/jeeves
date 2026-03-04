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

        guard gateway.isConnected,
              let token = gateway.token else {
            return
        }

        let client = GatewayClient(host: gateway.host, port: gateway.port, token: token)

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

        do {
            let snapshot = try await client.fetchObservatorySnapshot(proposals: proposals)
            observatorySnapshot = snapshot

            let escalatedClusters = snapshot.collisions
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

            processEmergenceChanges(escalatedClusters)
        } catch {
            do {
                let clusters = try await client.fetchEmergence()
                let escalated = clusters.filter(\.escalatesToIphone)
                processEmergenceChanges(escalated)
            } catch {}
        }
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
}
