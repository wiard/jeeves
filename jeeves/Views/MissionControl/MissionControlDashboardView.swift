import SwiftUI

struct MissionControlDashboardView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @State private var model = MissionControlViewModel()
    @State private var pulseActive = false

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.04, green: 0.05, blue: 0.08),
                        Color(red: 0.03, green: 0.04, blue: 0.06),
                        Color(red: 0.02, green: 0.03, blue: 0.05)
                    ]
                )
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(Color.blue.opacity(0.10))
                        .blur(radius: 68)
                        .frame(width: 220, height: 220)
                        .offset(x: -50, y: -80)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.orange.opacity(0.08))
                        .blur(radius: 78)
                        .frame(width: 240, height: 240)
                        .offset(x: 60, y: -70)
                }
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
            .onAppear {
                guard !pulseActive else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulseActive = true
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
                    .foregroundStyle(Color.white.opacity(0.96))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [statusTint.opacity(0.34), Color.black.opacity(0.16)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(statusTint)
                            .frame(width: pulseFrame, height: pulseFrame)
                            .shadow(color: statusTint.opacity(0.45), radius: 7)
                            .padding(.top, 5)
                            .padding(.trailing, 5)
                    }
                    .clipShape(Capsule())
                    .shadow(color: statusTint.opacity(0.18), radius: 6, y: 2)
            }

            Text("\(statusBadge.capitalized) • Last tick \(lastTickLine)")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.98))

            Text("System health, live pipeline pressure, and operator review at a glance.")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                infoPill("\(discoveryCount) discoveries")
                infoPill("\(pendingApprovalCount) approvals pending")
            }

            Text(operatorLine)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(border: statusTint))
    }

    private func infoPill(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced).weight(.medium))
            .foregroundStyle(monoTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), statusTint.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(statusTint.opacity(0.16), lineWidth: 1)
            )
    }

    private func cardBackground(border: Color) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.08), border.opacity(0.10), Color.black.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(border.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: border.opacity(0.14), radius: 10, y: 3)
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

    private var monoTint: Color {
        Color(red: 147 / 255.0, green: 197 / 255.0, blue: 253 / 255.0)
    }

    private var pulseFrame: CGFloat {
        pulseActive && statusBadge != "HEALTHY" ? 10 : 8
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
    @State private var pulseActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.stage.rawValue.uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(stageTint)

                Spacer()

                Text(card.status.uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.white.opacity(0.94))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [stageTint.opacity(0.34), Color.black.opacity(0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(stageTint)
                            .frame(width: badgeDotSize, height: badgeDotSize)
                            .shadow(color: stageTint.opacity(0.45), radius: 6)
                            .padding(.top, 4)
                            .padding(.trailing, 4)
                    }
                    .clipShape(Capsule())
                    .shadow(color: glowTint.opacity(glowOpacity), radius: glowRadius)
            }

            HStack(alignment: .lastTextBaseline) {
                Text(card.primaryMetric)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(monoTint)

                Spacer(minLength: 12)

                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(Color.white.opacity(0.96))
            }

            Text(card.summary)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.62))
                .lineLimit(1)

            HStack(spacing: 8) {
                ForEach(card.pills.prefix(3), id: \.self) { pill in
                    Text(pill)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(monoTint.opacity(0.92))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.06), stageTint.opacity(0.10)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(stageTint.opacity(0.16), lineWidth: 1)
                        )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), stageTint.opacity(isActive ? 0.16 : 0.10), Color.black.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(stageTint.opacity(isActive ? 0.34 : 0.18), lineWidth: 1)
                )
                .shadow(color: glowTint.opacity(isActive ? 0.16 : 0.08), radius: isActive ? 10 : 6, y: 3)
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(stageTint.opacity(isActive ? 0.16 : 0.08))
                .frame(width: 96, height: 96)
                .blur(radius: 28)
                .offset(x: -18, y: -20)
        }
        .onAppear {
            guard !pulseActive else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulseActive = true
            }
        }
    }

    private var stageTint: Color {
        switch card.stage {
        case .discovery: return .blue
        case .proposal: return .blue
        case .approval: return .orange
        case .action: return .blue
        case .knowledge: return .green
        }
    }

    private var monoTint: Color {
        Color(red: 147 / 255.0, green: 197 / 255.0, blue: 253 / 255.0)
    }

    private var glowTint: Color {
        if card.status.lowercased().contains("failure") || card.status.lowercased().contains("denied") {
            return .red
        }
        return stageTint
    }

    private var glowOpacity: Double {
        if card.stage == .approval && !card.primaryMetric.hasPrefix("0") {
            return 0.22
        }
        if card.stage == .knowledge {
            return 0.16
        }
        return isActive ? 0.18 : 0.10
    }

    private var glowRadius: CGFloat {
        if card.stage == .action && card.status.lowercased().contains("active") {
            return pulseActive ? 9 : 5
        }
        return 5
    }

    private var badgeDotSize: CGFloat {
        if card.stage == .action && card.status.lowercased().contains("active") {
            return pulseActive ? 10 : 8
        }
        return 8
    }
}
