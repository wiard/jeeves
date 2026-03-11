import Foundation

@MainActor
struct OperatorOverviewSnapshot {
    static let loopLine = "Discovery -> Proposal -> Approval -> Action -> Knowledge"

    enum Tone: String {
        case discovery
        case governance
        case knowledge
        case trust
    }

    struct HeaderMetric: Identifiable {
        let id: String
        let label: String
        let value: String

        init(label: String, value: String) {
            self.id = label
            self.label = label
            self.value = value
        }
    }

    struct OverviewCard: Identifiable {
        let id: Tone
        let tone: Tone
        let eyebrow: String
        let title: String
        let metric: String
        let headline: String
        let detail: String
    }

    struct FlowItem: Identifiable {
        let id: String
        let tone: Tone
        let label: String
        let title: String
        let detail: String
        let badge: String

        init(tone: Tone, label: String, title: String, detail: String, badge: String) {
            self.id = "\(tone.rawValue)-\(label)"
            self.tone = tone
            self.label = label
            self.title = title
            self.detail = detail
            self.badge = badge
        }
    }

    let summary: String
    let focusLine: String
    let updatedLine: String
    let headerMetrics: [HeaderMetric]
    let overviewCards: [OverviewCard]
    let flowItems: [FlowItem]

    init(poller: ProposalPoller) {
        let discoveryCandidate = poller.radarDiscoveryCandidates.first
        let topSignal = poller.radarStatus?.store?.topSignals.first
        let topActivation = poller.radarActivations.first
        let topPendingProposal = poller.pendingProposals.first
        let topGapProposal = poller.gapProposals.first(where: \.isPending)
        let latestDecision = poller.decidedProposals.first
        let latestAction = poller.recentActions.first ?? poller.decidedProposals.compactMap(\.action).first
        let latestKnowledge = poller.recentKnowledgeObjects.first
        let discoveryCount = max(poller.radarDiscoveryCandidates.count, poller.radarStatus?.store?.activationCount ?? 0)
        let pendingApprovalCount = max(poller.pendingProposals.count, poller.conductorState?.consentPending ?? 0)
        let recentKnowledgeCount = poller.recentKnowledgeObjects.count
        let recentChangeCount = max(poller.recentActions.count, poller.decidedProposals.count)
        let trustVisibleCount = (poller.safeClashFeed?.certified.count ?? 0) + (poller.safeClashFeed?.emerging.count ?? 0)
        let lastUpdatedAt = poller.lastSuccessfulRefreshAt

        summary = "A calm summary of internet and telemetry signals flowing through CLASHD27 discovery, openclashd-v2 governance, SafeClash receipts, and resulting knowledge without moving authority into Jeeves."
        focusLine = Self.focusLine(
            discoveryCandidate: discoveryCandidate,
            topSignal: topSignal,
            topPendingProposal: topPendingProposal,
            topGapProposal: topGapProposal,
            latestKnowledge: latestKnowledge
        )
        updatedLine = "Updated \(Self.relativeDateString(lastUpdatedAt))"

        headerMetrics = [
            HeaderMetric(label: "Discovery", value: "\(discoveryCount) live"),
            HeaderMetric(label: "Governance", value: "\(pendingApprovalCount) pending"),
            HeaderMetric(label: "Knowledge", value: recentKnowledgeCount == 0 ? "quiet" : "\(recentKnowledgeCount) recent"),
            HeaderMetric(
                label: "Trust",
                value: trustVisibleCount == 0
                    ? Self.killSwitchLabel(isActive: poller.conductorState?.killSwitch.active ?? false)
                    : "\(trustVisibleCount) visible"
            )
        ]

        let discoveryHeadline = discoveryCandidate?.candidateType
            ?? topSignal?.title
            ?? topActivation?.title
            ?? "Waiting for CLASHD27 discovery output"
        let discoveryDetail = Self.discoveryDetail(
            discoveryCandidate: discoveryCandidate,
            topSignal: topSignal,
            poller: poller
        )

        let governanceHeadline = topPendingProposal?.title
            ?? topGapProposal?.title
            ?? "No proposals are waiting for approval"
        let governanceDetail = Self.governanceDetail(
            topPendingProposal: topPendingProposal,
            topGapProposal: topGapProposal,
            latestAction: latestAction,
            conductorState: poller.conductorState
        )

        let knowledgeHeadline = latestKnowledge?.title
            ?? poller.knowledgeStatus?.lastKnowledgeChallenges.first?.title
            ?? "No recent knowledge objects surfaced"
        let knowledgeDetail = Self.knowledgeDetail(
            latestKnowledge: latestKnowledge,
            knowledgeStatus: poller.knowledgeStatus
        )

        let trustHeadline = Self.trustHeadline(poller: poller, latestDecision: latestDecision, latestAction: latestAction)
        let trustDetail = Self.trustDetail(
            poller: poller,
            latestDecision: latestDecision,
            latestAction: latestAction
        )

        overviewCards = [
            OverviewCard(
                id: .discovery,
                tone: .discovery,
                eyebrow: "Discovery",
                title: "What is forming",
                metric: discoveryCount == 0 ? "quiet" : "\(discoveryCount) live",
                headline: discoveryHeadline,
                detail: discoveryDetail
            ),
            OverviewCard(
                id: .governance,
                tone: .governance,
                eyebrow: "Governance",
                title: "What needs approval",
                metric: "\(pendingApprovalCount) pending",
                headline: governanceHeadline,
                detail: governanceDetail
            ),
            OverviewCard(
                id: .knowledge,
                tone: .knowledge,
                eyebrow: "Knowledge",
                title: "What was learned",
                metric: recentKnowledgeCount == 0 ? "quiet" : "\(recentKnowledgeCount) recent",
                headline: knowledgeHeadline,
                detail: knowledgeDetail
            ),
            OverviewCard(
                id: .trust,
                tone: .trust,
                eyebrow: "Trust",
                title: "What changed",
                metric: recentChangeCount == 0 ? "quiet" : "\(recentChangeCount) recent",
                headline: trustHeadline,
                detail: trustDetail
            )
        ]

        flowItems = [
            FlowItem(
                tone: .discovery,
                label: "Signal",
                title: discoveryHeadline,
                detail: discoveryCandidate?.explanation
                    ?? topSignal.map { "\($0.source) residue \(Self.scoreString($0.residue))." }
                    ?? topActivation?.summary
                    ?? "No discovery signal is currently leading the queue.",
                badge: discoveryCandidate.map { "score \(Self.scoreString($0.candidateScore))" }
                    ?? topSignal.map { "residue \(Self.scoreString($0.residue))" }
                    ?? "waiting"
            ),
            FlowItem(
                tone: .governance,
                label: "Proposal",
                title: governanceHeadline,
                detail: topPendingProposal?.priorityExplanation
                    ?? topGapProposal?.summary
                    ?? "No pending proposal is applying operator pressure.",
                badge: topPendingProposal?.displayPriority.isEmpty == false
                    ? topPendingProposal?.displayPriority ?? "pending"
                    : "\(pendingApprovalCount) pending"
            ),
            FlowItem(
                tone: .governance,
                label: "Approval",
                title: latestDecision?.title ?? topPendingProposal?.title ?? "Awaiting approval",
                detail: Self.approvalDetail(
                    latestDecision: latestDecision,
                    topPendingProposal: topPendingProposal,
                    topGapProposal: topGapProposal
                ),
                badge: latestDecision?.status.uppercased() ?? (topPendingProposal != nil || topGapProposal != nil ? "PENDING" : "IDLE")
            ),
            FlowItem(
                tone: .trust,
                label: "Action",
                title: latestAction?.actionKind.replacingOccurrences(of: "_", with: " ").capitalized
                    ?? "No recent bounded action",
                detail: latestAction?.receipt?.resultSummary
                    ?? latestAction?.executionState.capitalized
                    ?? "Awaiting the next governed execution receipt.",
                badge: latestAction?.executionState.uppercased() ?? "IDLE"
            ),
            FlowItem(
                tone: .knowledge,
                label: "Knowledge",
                title: latestKnowledge?.title ?? "No recent knowledge object",
                detail: latestKnowledge?.summary.isEmpty == false
                    ? latestKnowledge?.summary ?? ""
                    : "Knowledge will appear here once an action or investigation produces an addressable object.",
                badge: latestKnowledge?.kind.replacingOccurrences(of: "_", with: " ").uppercased() ?? "QUIET"
            )
        ]
    }

    private static func focusLine(
        discoveryCandidate: RadarDiscoveryCandidate?,
        topSignal: RadarTopSignal?,
        topPendingProposal: Proposal?,
        topGapProposal: GovernedGapEntry?,
        latestKnowledge: KnowledgeObject?
    ) -> String {
        let discovery = discoveryCandidate?.candidateType ?? topSignal?.title ?? "no leading discovery"
        let approval = topPendingProposal?.title ?? topGapProposal?.title ?? "no approval queue"
        let knowledge = latestKnowledge?.title ?? "no new knowledge object"
        return "\(discovery) is forming, \(approval) needs review, and \(knowledge) is the latest visible knowledge."
    }

    private static func discoveryDetail(
        discoveryCandidate: RadarDiscoveryCandidate?,
        topSignal: RadarTopSignal?,
        poller: ProposalPoller
    ) -> String {
        let candidateDetail = discoveryCandidate?.explanation
        let signalDetail = topSignal.map { "\($0.source) residue \(scoreString($0.residue))" }
        let discoveryLane = [candidateDetail, signalDetail]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .first ?? "No discovery explanation is available yet."
        let topSources = poller.radarSources
            .prefix(3)
            .map(\.source)
            .joined(separator: ", ")
        let sourceLine = topSources.isEmpty ? "Sources are still quiet." : "Source flow: \(topSources)."
        return "\(discoveryLane) \(poller.radarDiscoveryCandidates.count) candidates, \(poller.radarActivations.count) activations, \(poller.radarEmergence.count) emergence traces. \(sourceLine)"
    }

    private static func governanceDetail(
        topPendingProposal: Proposal?,
        topGapProposal: GovernedGapEntry?,
        latestAction: ActionSummary?,
        conductorState: ConductorState?
    ) -> String {
        let proposalContext = topPendingProposal?.priorityExplanation
            ?? topGapProposal?.summary
            ?? "The queue is currently clear."
        let cycleStage = conductorState?.cycleStage.replacingOccurrences(of: "_", with: " ").capitalized ?? "Unknown stage"
        let actionState = latestAction?.executionState.replacingOccurrences(of: "_", with: " ").capitalized ?? "No recent action"
        return "\(proposalContext) Kernel stage: \(cycleStage). Latest bounded action: \(actionState)."
    }

    private static func knowledgeDetail(
        latestKnowledge: KnowledgeObject?,
        knowledgeStatus: KnowledgeStatus?
    ) -> String {
        let scanLine: String
        if let scanIso = knowledgeStatus?.lastScanAtIso {
            scanLine = relativeDateString(scanIso)
        } else {
            scanLine = "awaiting scan"
        }
        let cells = knowledgeStatus?.topCubeCells.prefix(2).joined(separator: ", ")
        let discoveryLine = (cells?.isEmpty == false) ? "Top cube cells: \(cells!)." : "No hot cube cells surfaced."
        let summary = latestKnowledge?.summary.isEmpty == false
            ? latestKnowledge?.summary ?? ""
            : "Knowledge remains visible and attributable once an action produces it."
        return "\(summary) \(discoveryLine) Last scan \(scanLine). Knowledge remains visible for later discovery scans."
    }

    private static func trustHeadline(
        poller: ProposalPoller,
        latestDecision: DecidedProposal?,
        latestAction: ActionSummary?
    ) -> String {
        if let latestAction {
            return latestAction.actionKind.replacingOccurrences(of: "_", with: " ").capitalized
        }
        if let latestDecision {
            return latestDecision.title
        }
        if poller.conductorState?.killSwitch.active == true {
            return "Kill switch active"
        }
        let certified = poller.safeClashFeed?.certified.count ?? 0
        let emerging = poller.safeClashFeed?.emerging.count ?? 0
        if certified + emerging > 0 {
            return "\(certified) certified and \(emerging) emerging SafeClash entries"
        }
        return "No recent governed change"
    }

    private static func trustDetail(
        poller: ProposalPoller,
        latestDecision: DecidedProposal?,
        latestAction: ActionSummary?
    ) -> String {
        let killSwitch = killSwitchLabel(isActive: poller.conductorState?.killSwitch.active ?? false)
        let budget = poller.conductorState.map { String(format: "%.0f", $0.budget.remaining) } ?? "unknown"
        let receipt = latestAction?.receipt.map { relativeDateString($0.completedAtIso) } ?? "no fresh receipt"
        let attestations = (poller.safeClashFeed?.certified.count ?? 0) + (poller.safeClashFeed?.emerging.count ?? 0)
        let changeLine: String
        if let latestAction {
            changeLine = latestAction.receipt?.resultSummary
                ?? "\(latestAction.executionState.capitalized) \(receipt)"
        } else if let latestDecision {
            let status = latestDecision.status.replacingOccurrences(of: "_", with: " ")
            changeLine = latestDecision.decisionReason ?? "\(status.capitalized) decision recorded."
        } else {
            changeLine = "No recent decision or receipt is visible."
        }
        return "\(changeLine) \(killSwitch). Budget remaining \(budget). SafeClash visibility \(attestations)."
    }

    private static func approvalDetail(
        latestDecision: DecidedProposal?,
        topPendingProposal: Proposal?,
        topGapProposal: GovernedGapEntry?
    ) -> String {
        if let latestDecision {
            let status = latestDecision.status.replacingOccurrences(of: "_", with: " ").capitalized
            if let reason = latestDecision.decisionReason, !reason.isEmpty {
                return "\(status). \(reason)"
            }
            return "\(status) decision is visible in the governed history."
        }
        if let topPendingProposal {
            return topPendingProposal.priorityExplanation ?? "Awaiting explicit human approval through openclashd-v2."
        }
        if let topGapProposal {
            return topGapProposal.summary
        }
        return "No approval event is currently visible."
    }

    private static func killSwitchLabel(isActive: Bool) -> String {
        isActive ? "kill switch active" : "kill switch clear"
    }

    private static func scoreString(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func relativeDateString(_ date: Date?) -> String {
        guard let date else { return "awaiting refresh" }
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static func relativeDateString(_ iso: String) -> String {
        relativeDateString(isoFormatter.date(from: iso))
    }

    private static let isoFormatter = ISO8601DateFormatter()
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
