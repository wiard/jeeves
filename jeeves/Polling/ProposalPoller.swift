import Foundation
import Observation

@MainActor
@Observable
final class ProposalPoller {
    var proposals: [Proposal] = []
    var pendingProposals: [Proposal] = []
    var emergenceClusters: [EmergenceCluster] = []

    var pendingCount: Int { pendingProposals.count }

    private var pollingTask: Task<Void, Never>?
    private var previousPendingIds: Set<String> = []
    private var previousEmergenceIds: Set<String> = []

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
        guard gateway.isConnected,
              let token = gateway.token,
              !gateway.useMock else { return }

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
            let clusters = try await client.fetchEmergence()
            let escalated = clusters.filter(\.escalatesToIphone)

            let newClusterIds = Set(escalated.map(\.clusterId))
            let newOnes = newClusterIds.subtracting(previousEmergenceIds)

            if !newOnes.isEmpty && !previousEmergenceIds.isEmpty {
                for cluster in escalated where newOnes.contains(cluster.clusterId) {
                    NotificationManager.shared.notifyEmergence(cluster)
                }
            }

            previousEmergenceIds = newClusterIds
            emergenceClusters = escalated
        } catch {}
    }

    func decide(proposalId: String, decision: String, gateway: GatewayManager) async -> Bool {
        guard let token = gateway.token else { return false }

        let client = GatewayClient(host: gateway.host, port: gateway.port, token: token)

        do {
            let response = try await client.decideProposal(proposalId: proposalId, decision: decision)
            if response.ok {
                await refresh(gateway: gateway)
            }
            return response.ok
        } catch {
            return false
        }
    }
}
