import Foundation

@MainActor
struct OperatorOverviewSnapshot {
    static let loopLine = "Discovery -> Proposal -> Approval -> Action -> Knowledge"

    enum Stage: String, CaseIterable, Identifiable {
        case discovery
        case proposal
        case approval
        case action
        case knowledge

        var id: String { rawValue }

        var title: String {
            switch self {
            case .discovery:
                return "Discovery"
            case .proposal:
                return "Proposal"
            case .approval:
                return "Approval"
            case .action:
                return "Action"
            case .knowledge:
                return "Knowledge"
            }
        }

        var source: String {
            switch self {
            case .discovery:
                return "clashd27"
            case .proposal:
                return "proposals.ts"
            case .approval:
                return "governance kernel"
            case .action:
                return "action-executor.ts"
            case .knowledge:
                return "knowledge persistence"
            }
        }
    }

    enum Tone: Equatable {
        case calm
        case active
        case watch
        case critical
    }

    struct StatusBar {
        let healthLabel: String
        let tone: Tone
        let lastTick: String
        let summary: String
        let activeStageLine: String
        let operatorLine: String
    }

    struct MetricItem: Identifiable {
        let id: String
        let label: String
        let value: String

        init(label: String, value: String) {
            self.id = label
            self.label = label
            self.value = value
        }
    }

    struct StageCard: Identifiable {
        let stage: Stage
        let tone: Tone
        let primaryMetric: String
        let status: String
        let headline: String
        let detail: String
        let metrics: [MetricItem]
        let isActive: Bool
        let needsAttention: Bool

        var id: String { stage.id }
    }

    struct LoopStage: Identifiable {
        let stage: Stage
        let metric: String
        let isActive: Bool
        let tone: Tone

        var id: String { stage.id }
    }

    let summary: String
    let statusBar: StatusBar
    let loopStages: [LoopStage]
    let stageCards: [StageCard]

    init(poller: ProposalPoller) {
        let discoverySignalsLive = max(
            poller.radarDiscoveryCandidates.count,
            poller.radarStatus?.store?.activationCount ?? 0,
            poller.radarActivations.count
        )
        let collisionCount = max(poller.radarCollisions.count, poller.radarStatus?.store?.collisionCount ?? 0)
        let emergenceCount = max(
            poller.radarEmergence.count,
            poller.radarStatus?.store?.emergenceCount ?? 0,
            poller.knowledgeStatus?.emergenceClustersCount ?? 0
        )
        let createdProposals = max(poller.proposals.count, poller.pendingProposals.count + poller.decidedProposals.count)
        let pendingApprovals = max(poller.pendingProposals.count, poller.conductorState?.consentPending ?? 0)
        let filteredProposals = poller.decidedProposals.filter { $0.isDenied || $0.isDeferred }.count
        let highRiskPending = poller.pendingProposals.filter(Self.isHighRisk).count
        let escalationAlerts = poller.gapProposals.filter(\.isPending).count + (poller.activeEmergenceAlert == nil ? 0 : 1)
        let actionsExecutedToday = poller.recentActions.filter(Self.completedToday).count
        let runningActions = poller.recentActions.filter(Self.isRunningAction).count
        let failedActions = poller.recentActions.filter(\.isFailed).count
        let knowledgeObjectsVisible = poller.recentKnowledgeObjects.count
        let newKnowledgeToday = poller.recentKnowledgeObjects.filter(Self.createdToday).count
        let linkedChallenges = poller.knowledgeStatus?.lastKnowledgeChallenges.count ?? 0
        let trustVisible = (poller.safeClashFeed?.certified.count ?? 0) + (poller.safeClashFeed?.emerging.count ?? 0)

        let activeStage = Self.activeStage(
            pendingApprovals: pendingApprovals,
            runningActions: runningActions,
            createdProposals: createdProposals,
            discoverySignalsLive: discoverySignalsLive,
            newKnowledgeToday: newKnowledgeToday
        )
        let healthTone = Self.healthTone(poller: poller, pendingApprovals: pendingApprovals, failedActions: failedActions)
        let topSignal = poller.radarDiscoveryCandidates.first?.candidateType
            ?? poller.radarStatus?.store?.topSignals.first?.title
            ?? poller.radarActivations.first?.title
            ?? "No live signal"
        let topProposal = poller.pendingProposals.first?.title
            ?? poller.decidedProposals.first?.title
            ?? "No proposal pressure"
        let latestKnowledge = poller.recentKnowledgeObjects.first?.title ?? "No recent knowledge object"

        summary = "System health, live pipeline pressure, and operator review at a glance."

        statusBar = StatusBar(
            healthLabel: Self.healthLabel(for: healthTone),
            tone: healthTone,
            lastTick: Self.relativeDateString(poller.lastSuccessfulRefreshAt),
            summary: "\(discoverySignalsLive) discoveries • \(pendingApprovals) approvals pending",
            activeStageLine: "Pipeline active in \(activeStage.title)",
            operatorLine: Self.operatorLine(
                pendingApprovals: pendingApprovals,
                failedActions: failedActions,
                killSwitchActive: poller.conductorState?.killSwitch.active ?? false
            )
        )

        loopStages = Stage.allCases.map { stage in
            LoopStage(
                stage: stage,
                metric: Self.loopMetric(
                    for: stage,
                    discoverySignalsLive: discoverySignalsLive,
                    createdProposals: createdProposals,
                    pendingApprovals: pendingApprovals,
                    runningActions: runningActions,
                    knowledgeObjectsVisible: knowledgeObjectsVisible
                ),
                isActive: stage == activeStage,
                tone: Self.stageTone(
                    for: stage,
                    isActive: stage == activeStage,
                    needsAttention: stage == .approval ? pendingApprovals > 0 : (stage == .action ? failedActions > 0 : false)
                )
            )
        }

        stageCards = [
            StageCard(
                stage: .discovery,
                tone: Self.stageTone(for: .discovery, isActive: activeStage == .discovery, needsAttention: discoverySignalsLive > 0),
                primaryMetric: "\(discoverySignalsLive)",
                status: discoverySignalsLive == 0 ? "Quiet" : "Signals live",
                headline: topSignal,
                detail: Self.discoveryDetail(poller: poller),
                metrics: [
                    MetricItem(label: "Signals", value: "\(discoverySignalsLive)"),
                    MetricItem(label: "Collisions", value: "\(collisionCount)"),
                    MetricItem(label: "Emerging", value: "\(emergenceCount)")
                ],
                isActive: activeStage == .discovery,
                needsAttention: false
            ),
            StageCard(
                stage: .proposal,
                tone: Self.stageTone(for: .proposal, isActive: activeStage == .proposal, needsAttention: createdProposals > 0),
                primaryMetric: "\(createdProposals)",
                status: createdProposals == 0 ? "Quiet" : "Proposals created",
                headline: topProposal,
                detail: Self.proposalDetail(poller: poller),
                metrics: [
                    MetricItem(label: "Created", value: "\(createdProposals)"),
                    MetricItem(label: "Awaiting", value: "\(pendingApprovals)"),
                    MetricItem(label: "Filtered", value: "\(filteredProposals)")
                ],
                isActive: activeStage == .proposal,
                needsAttention: false
            ),
            StageCard(
                stage: .approval,
                tone: Self.stageTone(for: .approval, isActive: activeStage == .approval, needsAttention: pendingApprovals > 0),
                primaryMetric: "\(pendingApprovals)",
                status: pendingApprovals == 0 ? "Queue clear" : "Review required",
                headline: poller.pendingProposals.first?.title ?? "No pending approval",
                detail: Self.approvalDetail(poller: poller),
                metrics: [
                    MetricItem(label: "Pending", value: "\(pendingApprovals)"),
                    MetricItem(label: "High risk", value: "\(highRiskPending)"),
                    MetricItem(label: "Escalations", value: "\(escalationAlerts)")
                ],
                isActive: activeStage == .approval,
                needsAttention: pendingApprovals > 0
            ),
            StageCard(
                stage: .action,
                tone: Self.stageTone(for: .action, isActive: activeStage == .action, needsAttention: failedActions > 0),
                primaryMetric: "\(actionsExecutedToday)",
                status: failedActions > 0 ? "Failures visible" : (runningActions > 0 ? "Running now" : "Bounded"),
                headline: poller.recentActions.first?.actionKind.replacingOccurrences(of: "_", with: " ").capitalized
                    ?? "No recent bounded action",
                detail: Self.actionDetail(poller: poller, trustVisible: trustVisible),
                metrics: [
                    MetricItem(label: "Today", value: "\(actionsExecutedToday)"),
                    MetricItem(label: "Running", value: "\(runningActions)"),
                    MetricItem(label: "Failures", value: "\(failedActions)")
                ],
                isActive: activeStage == .action,
                needsAttention: failedActions > 0
            ),
            StageCard(
                stage: .knowledge,
                tone: Self.stageTone(for: .knowledge, isActive: activeStage == .knowledge, needsAttention: newKnowledgeToday > 0),
                primaryMetric: "\(knowledgeObjectsVisible)",
                status: knowledgeObjectsVisible == 0 ? "Quiet" : "Objects visible",
                headline: latestKnowledge,
                detail: Self.knowledgeDetail(poller: poller),
                metrics: [
                    MetricItem(label: "Visible", value: "\(knowledgeObjectsVisible)"),
                    MetricItem(label: "New today", value: "\(newKnowledgeToday)"),
                    MetricItem(label: "Challenges", value: "\(linkedChallenges)")
                ],
                isActive: activeStage == .knowledge,
                needsAttention: false
            )
        ]
    }

    private static func discoveryDetail(poller: ProposalPoller) -> String {
        let sources = poller.radarSources.prefix(3).map(\.source).joined(separator: ", ")
        let sourceLine = sources.isEmpty ? "Sources quiet." : "Sources: \(sources)."
        let topSignal = poller.radarStatus?.store?.topSignals.first.map { "\($0.source) residue \(scoreString($0.residue))" }
        return "\(topSignal ?? "Discovery pressure is being tracked live.") \(sourceLine)"
    }

    private static func proposalDetail(poller: ProposalPoller) -> String {
        if let proposal = poller.pendingProposals.first {
            return proposal.priorityExplanation ?? "Proposal is staged for review in the governance queue."
        }
        if let decision = poller.decidedProposals.first {
            return decision.decisionReason ?? "Recent proposal decisions remain visible in the governed history."
        }
        return "No proposal traffic is pressing the operator right now."
    }

    private static func approvalDetail(poller: ProposalPoller) -> String {
        if let proposal = poller.pendingProposals.first {
            return proposal.priorityExplanation ?? "Explicit human approval is required before any bounded action can proceed."
        }
        if let decision = poller.decidedProposals.first {
            return decision.decisionReason ?? "\(decision.status.capitalized) decision recorded."
        }
        return "The approval queue is currently clear."
    }

    private static func actionDetail(poller: ProposalPoller, trustVisible: Int) -> String {
        if let action = poller.recentActions.first {
            let receiptLine = action.receipt?.resultSummary ?? action.executionState.capitalized
            return "\(receiptLine) SafeClash visibility \(trustVisible)."
        }
        return "No recent execution receipt. SafeClash visibility \(trustVisible)."
    }

    private static func knowledgeDetail(poller: ProposalPoller) -> String {
        if let object = poller.recentKnowledgeObjects.first {
            return object.summary.isEmpty ? "Knowledge object stored and visible to the operator." : object.summary
        }
        let lastScan = relativeDateString(poller.knowledgeStatus?.lastScanAtIso ?? "")
        return "No recent knowledge object. Last knowledge scan \(lastScan)."
    }

    private static func activeStage(
        pendingApprovals: Int,
        runningActions: Int,
        createdProposals: Int,
        discoverySignalsLive: Int,
        newKnowledgeToday: Int
    ) -> Stage {
        if pendingApprovals > 0 {
            return .approval
        }
        if runningActions > 0 {
            return .action
        }
        if createdProposals > 0 {
            return .proposal
        }
        if discoverySignalsLive > 0 {
            return .discovery
        }
        if newKnowledgeToday > 0 {
            return .knowledge
        }
        return .discovery
    }

    private static func healthTone(poller: ProposalPoller, pendingApprovals: Int, failedActions: Int) -> Tone {
        if poller.isDegraded || poller.lastRefreshError != nil {
            return .critical
        }
        if poller.conductorState?.killSwitch.active == true || failedActions > 0 {
            return .watch
        }
        if pendingApprovals > 0 {
            return .active
        }
        return .calm
    }

    private static func stageTone(for stage: Stage, isActive: Bool, needsAttention: Bool) -> Tone {
        if needsAttention {
            return .watch
        }
        if isActive {
            return .active
        }
        if stage == .knowledge {
            return .calm
        }
        return .calm
    }

    private static func healthLabel(for tone: Tone) -> String {
        switch tone {
        case .calm:
            return "Healthy"
        case .active:
            return "Healthy"
        case .watch:
            return "Guarded"
        case .critical:
            return "Attention"
        }
    }

    private static func operatorLine(pendingApprovals: Int, failedActions: Int, killSwitchActive: Bool) -> String {
        if killSwitchActive {
            return "Kill switch is active."
        }
        if pendingApprovals > 0 {
            return "Operator review is required now."
        }
        if failedActions > 0 {
            return "Review the latest action failures."
        }
        return "No operator decision is required right now."
    }

    private static func loopMetric(
        for stage: Stage,
        discoverySignalsLive: Int,
        createdProposals: Int,
        pendingApprovals: Int,
        runningActions: Int,
        knowledgeObjectsVisible: Int
    ) -> String {
        switch stage {
        case .discovery:
            return "\(discoverySignalsLive)"
        case .proposal:
            return "\(createdProposals)"
        case .approval:
            return "\(pendingApprovals)"
        case .action:
            return "\(runningActions)"
        case .knowledge:
            return "\(knowledgeObjectsVisible)"
        }
    }

    private static func isHighRisk(_ proposal: Proposal) -> Bool {
        let risk = proposal.intent.risk.lowercased()
        if risk.contains("high") || risk.contains("critical") {
            return true
        }
        return (proposal.priorityFactors?.riskScore ?? 0) >= 0.75
    }

    private static func isRunningAction(_ action: ActionSummary) -> Bool {
        let state = action.executionState.lowercased()
        return state == "running" || state == "queued" || state == "pending" || state == "started" || state == "in_progress"
    }

    private static func completedToday(_ action: ActionSummary) -> Bool {
        guard let iso = action.receipt?.completedAtIso else { return false }
        return createdToday(iso: iso)
    }

    private static func createdToday(_ object: KnowledgeObject) -> Bool {
        createdToday(iso: object.createdAtIso)
    }

    private static func createdToday(iso: String) -> Bool {
        guard let date = isoFormatter.date(from: iso) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private static func scoreString(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func relativeDateString(_ date: Date?) -> String {
        guard let date else { return "awaiting refresh" }
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private static func relativeDateString(_ iso: String) -> String {
        guard !iso.isEmpty else { return "awaiting scan" }
        return relativeDateString(isoFormatter.date(from: iso))
    }

    private static let isoFormatter = ISO8601DateFormatter()
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
