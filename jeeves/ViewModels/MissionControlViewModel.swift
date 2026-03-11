import Foundation
import Observation

struct MissionControlSystemLoopSnapshot {
    enum Stage: String, CaseIterable {
        case discovery = "Discovery"
        case proposal = "Proposal"
        case approval = "Approval"
        case action = "Action"
        case knowledge = "Knowledge"

        var eventLabel: String {
            switch self {
            case .discovery:
                return "Signals live"
            case .proposal:
                return "Proposals created"
            case .approval:
                return "Pending approvals"
            case .action:
                return "Actions processed"
            case .knowledge:
                return "Knowledge objects"
            }
        }
    }

    let currentStage: Stage
    let eventCount: Int
    let stageSummary: String
    let lastTransitionAt: Date?
}

@MainActor
@Observable
final class MissionControlViewModel {
    var trustSnapshot: MissionControlTrustSnapshot = .placeholder
    var isLoading = false
    var hasLoaded = false

    func load(gateway: GatewayManager, force: Bool = false) async {
        if isLoading && !force {
            return
        }
        if hasLoaded && !force {
            return
        }

        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        if gateway.useMock || gateway.host.lowercased() == "mock" {
            trustSnapshot = .mock
            return
        }

        let client = await makeSafeClashClient(gateway: gateway)

        do {
            let feed = try await client.fetchBrowserFeed()
            trustSnapshot = Self.snapshot(from: feed)
        } catch {
            trustSnapshot = .placeholder
        }
    }

    static func snapshot(from feed: SafeClashBrowserFeed) -> MissionControlTrustSnapshot {
        let certified = Array(feed.certified.prefix(6))
        let featured = feed.featured.isEmpty ? certified : Array(feed.featured.prefix(3))
        let attestations = featured.enumerated().map { index, item in
            MissionControlAttestation(
                id: item.certificateId ?? item.configId,
                title: item.title,
                detail: "\(item.certificationLevel) · \(item.deployReady ? "deploy ready" : "review only")",
                certificateId: item.certificateId ?? "attestation-\(index)"
            )
        }

        let statuses = capabilityStatuses(from: certified)
        let note: String?
        if attestations.isEmpty {
            note = "SafeClash feed responded without certification details. Rendering a read-only trust placeholder."
        } else {
            note = "Trust signals are read-only. Jeeves displays SafeClash attestations without gaining execution authority."
        }

        return MissionControlTrustSnapshot(
            attestationCount: feed.certified.count,
            attestations: Array(attestations.prefix(3)),
            capabilityStatuses: Array(statuses.prefix(4)),
            operatorNote: note,
            isPlaceholder: attestations.isEmpty && statuses.isEmpty
        )
    }

    private static func capabilityStatuses(from certified: [SafeClashCertifiedIntention]) -> [MissionControlCapabilityStatus] {
        var counts: [String: Int] = [:]

        for item in certified {
            for capability in splitCapabilities(item.capabilitiesSummary) {
                counts[capability, default: 0] += 1
            }
        }

        return counts
            .sorted {
                if $0.value == $1.value {
                    return $0.key < $1.key
                }
                return $0.value > $1.value
            }
            .map { capability, count in
                MissionControlCapabilityStatus(
                    id: capability,
                    title: capability.capitalized,
                    detail: "\(count) certified configuration\(count == 1 ? "" : "s")",
                    emphasis: count > 1 ? "ready" : "watch"
                )
            }
    }

    private static func splitCapabilities(_ summary: String?) -> [String] {
        guard let summary else { return [] }

        return summary
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func makeSafeClashClient(gateway: GatewayManager) async -> SafeClashClient {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["SAFECLASH_BASE_URL"] ?? env["SAFECLASH_URL"],
           let url = URL(string: raw),
           let scheme = url.scheme,
           (scheme == "http" || scheme == "https"),
           url.host != nil {
            let token = gateway.token?.trimmingCharacters(in: .whitespacesAndNewlines)
            return SafeClashClient(baseURL: url, token: (token?.isEmpty == false) ? token : nil)
        }

        let endpoint = await gateway.resolveEndpoint()
        var components = URLComponents()
        components.scheme = "http"
        components.host = endpoint.host
        components.port = endpoint.port
        let baseURL = components.url ?? URL(string: "http://localhost:19001")!
        let token = endpoint.token?.trimmingCharacters(in: .whitespacesAndNewlines)
        return SafeClashClient(baseURL: baseURL, token: (token?.isEmpty == false) ? token : nil)
    }

    static func systemLoopSnapshot(
        poller: ProposalPoller,
        gateway: GatewayManager
    ) -> MissionControlSystemLoopSnapshot {
        let pendingApprovals = max(
            poller.pendingProposals.count,
            poller.conductorState?.consentPending ?? gateway.currentStatus?.consent.pending ?? 0
        )
        let discoveryEvents = max(
            poller.radarDiscoveryCandidates.count,
            poller.radarActivations.count,
            poller.radarStatus?.store?.activationCount ?? 0
        )
        let proposalEvents = max(
            poller.proposals.count,
            poller.pendingProposals.count + poller.decidedProposals.count
        )
        let knowledgeEvents = poller.recentKnowledgeObjects.count

        if pendingApprovals > 0 {
            return MissionControlSystemLoopSnapshot(
                currentStage: .approval,
                eventCount: pendingApprovals,
                stageSummary: "\(pendingApprovals) proposal\(pendingApprovals == 1 ? "" : "s") waiting for operator review.",
                lastTransitionAt: latestDate(
                    parseISO(poller.pendingProposals.first?.createdAtIso),
                    parseISO(poller.conductorState?.updatedAtIso)
                )
            )
        }

        let runningActions = poller.recentActions.filter { action in
            let state = action.executionState.lowercased()
            return state == "running" || state == "queued" || state == "pending" || state == "in_progress"
        }
        if !runningActions.isEmpty {
            return MissionControlSystemLoopSnapshot(
                currentStage: .action,
                eventCount: runningActions.count,
                stageSummary: "\(runningActions.count) bounded action\(runningActions.count == 1 ? "" : "s") currently executing.",
                lastTransitionAt: latestDate(
                    runningActions.compactMap { parseISO($0.receipt?.completedAtIso) } + [poller.lastSuccessfulRefreshAt].compactMap { $0 }
                )
            )
        }

        if proposalEvents > 0 && (!poller.pendingProposals.isEmpty || !poller.decidedProposals.isEmpty) {
            return MissionControlSystemLoopSnapshot(
                currentStage: .proposal,
                eventCount: proposalEvents,
                stageSummary: "\(proposalEvents) proposal event\(proposalEvents == 1 ? "" : "s") visible in the governed queue.",
                lastTransitionAt: latestDate(
                    parseISO(poller.pendingProposals.first?.createdAtIso),
                    parseISO(poller.decidedProposals.first?.decidedAtIso)
                )
            )
        }

        if discoveryEvents > 0 {
            return MissionControlSystemLoopSnapshot(
                currentStage: .discovery,
                eventCount: discoveryEvents,
                stageSummary: "\(discoveryEvents) live discovery event\(discoveryEvents == 1 ? "" : "s") flowing from CLASHD27.",
                lastTransitionAt: latestDate(
                    parseISO(poller.radarActivations.first?.timestampIso),
                    parseISO(poller.radarStatus?.collector?.lastRun),
                    poller.lastSuccessfulRefreshAt
                )
            )
        }

        if knowledgeEvents > 0 {
            return MissionControlSystemLoopSnapshot(
                currentStage: .knowledge,
                eventCount: knowledgeEvents,
                stageSummary: "\(knowledgeEvents) recent knowledge object\(knowledgeEvents == 1 ? "" : "s") visible to the operator.",
                lastTransitionAt: latestDate(
                    parseISO(poller.recentKnowledgeObjects.first?.createdAtIso),
                    parseISO(poller.knowledgeStatus?.lastScanAtIso)
                )
            )
        }

        return MissionControlSystemLoopSnapshot(
            currentStage: .discovery,
            eventCount: 0,
            stageSummary: "Waiting for the next governed system event.",
            lastTransitionAt: poller.lastSuccessfulRefreshAt
        )
    }

    private static func parseISO(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        return isoFormatter.date(from: iso)
    }

    private static func latestDate(_ dates: Date?...) -> Date? {
        latestDate(dates.compactMap { $0 })
    }

    private static func latestDate(_ dates: [Date]) -> Date? {
        dates.max()
    }

    private static let isoFormatter = ISO8601DateFormatter()
}
