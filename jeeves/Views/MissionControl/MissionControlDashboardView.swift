import SwiftUI

struct MissionControlDashboardView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @State private var model = MissionControlViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.95, green: 0.98, blue: 1.00),
                        Color(red: 0.93, green: 0.97, blue: 0.99),
                        Color(red: 0.98, green: 0.97, blue: 0.94)
                    ]
                )
                .ignoresSafeArea()

                if isBootstrapping {
                    ProgressView("Mission Control preparing...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            systemStatusCard
                            SystemLoopStrip(snapshot: systemLoopSnapshot)

                            MissionControlCompactStageCard(card: discoveryCard, isActive: systemLoopSnapshot.currentStage == .discovery)
                            MissionControlCompactStageCard(card: proposalCard, isActive: systemLoopSnapshot.currentStage == .proposal)
                            MissionControlCompactStageCard(card: approvalCard, isActive: systemLoopSnapshot.currentStage == .approval)
                            MissionControlCompactStageCard(card: actionCard, isActive: systemLoopSnapshot.currentStage == .action)
                            MissionControlCompactStageCard(card: knowledgeCard, isActive: systemLoopSnapshot.currentStage == .knowledge)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationTitle("Mission Control")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .refreshable {
                await refresh()
            }
            .task {
                await refresh()
            }
            .onChange(of: gateway.isConnected) {
                if gateway.isConnected {
                    Task { await refresh() }
                }
            }
        }
    }

    private var isBootstrapping: Bool {
        !poller.hasLoadedOnce && model.isLoading
    }

    private var systemLoopSnapshot: MissionControlSystemLoopSnapshot {
        MissionControlViewModel.systemLoopSnapshot(poller: poller, gateway: gateway)
    }

    private var systemStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("SYSTEM STATUS")
                    .font(.caption.monospaced())
                    .foregroundStyle(statusTint)

                Spacer()

                Text(statusBadge)
                    .font(.caption.monospaced())
                    .foregroundStyle(statusTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusTint.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text("\(statusBadge.capitalized) • Last tick \(lastTickLine)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text("System health, live pipeline pressure, and operator review at a glance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                infoPill("\(discoveryCount) discoveries")
                infoPill("\(pendingApprovalCount) approvals pending")
            }

            Text(operatorLine)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(border: statusTint))
    }

    private func infoPill(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func cardBackground(border: Color) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(border.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
    }

    private var statusBadge: String {
        if killSwitchActive || budgetHardStop { return "ATTENTION" }
        if pendingApprovalCount > 0 { return "ATTENTION" }
        if discoveryCount > 0 { return "LIVE" }
        return "HEALTHY"
    }

    private var statusTint: Color {
        if killSwitchActive || budgetHardStop { return .red }
        if pendingApprovalCount > 0 { return .orange }
        if discoveryCount > 0 { return .blue }
        return .green
    }

    private var lastTickLine: String {
        guard let date = systemLoopSnapshot.lastTransitionAt else { return "unknown" }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        return "\(seconds) sec ago"
    }

    private var operatorLine: String {
        if pendingApprovalCount > 0 {
            return "Operator review is required now."
        }
        if discoveryCount > 0 {
            return "Pipeline active in Discovery."
        }
        return "No operator decision is required right now."
    }

    // MARK: - Data

    private var topDiscoverySignal: RadarTopSignal? {
        poller.radarStatus?.store?.topSignals.first
    }

    private var collisionCount: Int {
        poller.radarStatus?.store?.collisionCount ?? poller.radarCollisions.count
    }

    private var emergenceCount: Int {
        poller.radarStatus?.store?.emergenceCount ?? poller.radarEmergence.count
    }

    private var pendingGapCount: Int {
        max(
            poller.pendingProposals.filter(\.isGapDiscovery).count,
            poller.gapProposals.filter(\.isPending).count
        )
    }

    private var gapCandidateCount: Int {
        max(poller.radarDiscoveryCandidates.count, pendingGapCount)
    }

    private var discoveryCount: Int {
        max(gapCandidateCount, collisionCount + emergenceCount)
    }

    private var pendingApprovalCount: Int {
        max(
            poller.pendingProposals.count,
            poller.conductorState?.consentPending ?? gateway.currentStatus?.consent.pending ?? 0
        )
    }

    private var approvedCount: Int {
        poller.decidedProposals.filter(\.isApproved).count
    }

    private var deniedCount: Int {
        poller.decidedProposals.filter(\.isDenied).count
    }

    private var proposalCount: Int {
        poller.pendingProposals.count
    }

    private var recentBoundedActions: [ActionSummary] {
        let actions = poller.decidedProposals.compactMap(\.action)
        if !actions.isEmpty {
            return Array(actions.prefix(3))
        }
        if let fallback = poller.lastActionReceipt {
            return [fallback]
        }
        return []
    }

    private var recentReceipts: [ActionReceipt] {
        Array(recentBoundedActions.compactMap(\.receipt).prefix(3))
    }

    private var runningActionCount: Int {
        poller.recentActions.filter {
            let state = $0.executionState.lowercased()
            return state == "running" || state == "queued" || state == "pending" || state == "in_progress"
        }.count
    }

    private var failedActionCount: Int {
        recentBoundedActions.filter(\.isFailed).count
    }

    private var knowledgeSnapshot: KnowledgeStatus? {
        poller.knowledgeStatus ?? gateway.currentKnowledgeStatus
    }

    private var knowledgeSignals24h: Int {
        knowledgeSnapshot?.last24hSignalsCount ?? poller.recentKnowledgeObjects.count
    }

    private var knowledgeClusterCount: Int {
        knowledgeSnapshot?.emergenceClustersCount ?? 0
    }

    private var compactTopKnowledgeCell: String {
        knowledgeSnapshot?.topCubeCells.first?.uppercased() ?? "--"
    }

    private var killSwitchActive: Bool {
        poller.conductorState?.killSwitch.active ?? gateway.currentStatus?.killSwitch.active ?? false
    }

    private var budgetHardStop: Bool {
        poller.conductorState?.budget.hardStop ?? gateway.currentStatus?.budget.hardStop ?? false
    }

    // MARK: - Cards

    private var discoveryCard: MissionControlCompactStageCardModel {
        .init(
            id: "discovery",
            stage: .discovery,
            title: "Discovery",
            primaryMetric: "\(discoveryCount)",
            status: discoveryCount > 0 ? "live" : "quiet",
            summary: topDiscoverySignal?.title ?? "Waiting for CLASHD27 discovery output.",
            pills: [
                "\(collisionCount) collisions",
                "\(emergenceCount) emergence",
                "\(gapCandidateCount) gaps"
            ]
        )
    }

    private var proposalCard: MissionControlCompactStageCardModel {
        .init(
            id: "proposal",
            stage: .proposal,
            title: "Proposal",
            primaryMetric: "\(proposalCount)",
            status: proposalCount > 0 ? "queued" : "quiet",
            summary: proposalCount > 0 ? "Structured proposals are ready for review." : "No proposal pressure right now.",
            pills: [
                "\(proposalCount) queued",
                "\(pendingGapCount) gap-related",
                "\(approvedCount) approved"
            ]
        )
    }

    private var approvalCard: MissionControlCompactStageCardModel {
        .init(
            id: "approval",
            stage: .approval,
            title: "Approval",
            primaryMetric: "\(pendingApprovalCount)",
            status: pendingApprovalCount > 0 ? "attention" : "idle",
            summary: pendingApprovalCount > 0 ? "Operator approval is required before bounded execution." : "No approval queue at this moment.",
            pills: [
                "\(pendingApprovalCount) pending",
                "\(approvedCount) approved",
                "\(deniedCount) denied"
            ]
        )
    }

    private var actionCard: MissionControlCompactStageCardModel {
        .init(
            id: "action",
            stage: .action,
            title: "Bounded Action",
            primaryMetric: "\(recentBoundedActions.count)",
            status: runningActionCount > 0 ? "active" : (recentBoundedActions.isEmpty ? "idle" : "completed"),
            summary: recentReceipts.first?.resultSummary ?? "No recent bounded action.",
            pills: [
                "\(runningActionCount) running",
                "\(failedActionCount) failed",
                "\(recentReceipts.count) receipts"
            ]
        )
    }

    private var knowledgeCard: MissionControlCompactStageCardModel {
        .init(
            id: "knowledge",
            stage: .knowledge,
            title: "Knowledge",
            primaryMetric: "\(knowledgeSignals24h)",
            status: knowledgeClusterCount > 0 ? "active" : (knowledgeSignals24h > 0 ? "flowing" : "quiet"),
            summary: poller.recentKnowledgeObjects.first?.title ?? "No recent knowledge object.",
            pills: [
                "\(knowledgeSignals24h) 24h",
                "\(knowledgeClusterCount) clusters",
                compactTopKnowledgeCell
            ]
        )
    }

    private func refresh() async {
        await poller.refresh(gateway: gateway)
        if let feed = poller.safeClashFeed {
            model.trustSnapshot = MissionControlViewModel.snapshot(from: feed)
            model.hasLoaded = true
        } else {
            await model.load(gateway: gateway, force: true)
        }
    }
}

struct MissionControlCompactStageCardModel: Identifiable {
    let id: String
    let stage: MissionControlSystemLoopSnapshot.Stage
    let title: String
    let primaryMetric: String
    let status: String
    let summary: String
    let pills: [String]
}

private struct MissionControlCompactStageCard: View {
    let card: MissionControlCompactStageCardModel
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.stage.rawValue.uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(stageTint)

                Spacer()

                Text(card.status.uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(stageTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(stageTint.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(alignment: .lastTextBaseline) {
                Text(card.primaryMetric)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text(card.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                ForEach(card.pills.prefix(3), id: \.self) { pill in
                    Text(pill)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(stageTint.opacity(isActive ? 0.28 : 0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
        )
    }

    private var stageTint: Color {
        switch card.stage {
        case .discovery: return .blue
        case .proposal: return .brown
        case .approval: return .orange
        case .action: return .green
        case .knowledge: return .mint
        }
    }
}
