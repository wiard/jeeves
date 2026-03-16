import SwiftUI

struct MissionControlDashboardView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @State private var model = MissionControlViewModel()
    @State private var injectionModel = ClashInjectionViewModel()
    @State private var gapFinderModel = GapFinderViewModel()
    @State private var pulseActive = false
    @State private var showFullDashboard = false
    @State private var selectedRecentSignal: RecentGridSignal?

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color.jeevesMist,
                        Color(red: 0.94, green: 0.97, blue: 0.99),
                        Color(red: 0.97, green: 0.98, blue: 0.96)
                    ]
                )
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(Color.jeevesSky.opacity(0.10))
                        .blur(radius: 88)
                        .frame(width: 240, height: 240)
                        .offset(x: -52, y: -84)
                }
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.jeevesMint.opacity(0.10))
                        .blur(radius: 92)
                        .frame(width: 250, height: 250)
                        .offset(x: 62, y: -74)
                }
                .ignoresSafeArea()

                if isBootstrapping {
                    ProgressView("Mission Control preparing...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Always visible: orientation + status + action card
                            MissionControlOrientationCard(
                                connectionLine: connectionLine,
                                systemLine: missionControlSystemLine,
                                nextStepLine: missionControlNextStepLine,
                                primaryActions: missionControlPrimaryActions
                            )
                            systemStatusCard
                            activeActionCard

                            // Toggle for full dashboard
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showFullDashboard.toggle()
                                }
                            } label: {
                                HStack {
                                    Text(showFullDashboard ? "Hide full dashboard" : "Show full dashboard")
                                        .font(.jeevesBody.weight(.medium))
                                    Image(systemName: showFullDashboard ? "chevron.up" : "chevron.down")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(Color.jeevesSky)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.jeevesSky.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.jeevesSky.opacity(0.18), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)

                            if showFullDashboard {
                                SystemReadinessCard(
                                    readiness: injectionModel.readiness,
                                    isLoading: injectionModel.isLoading,
                                    errorText: injectionModel.errorText
                                )
                                Clashd27ComputerCard(
                                    computer: injectionModel.computer,
                                    isLoading: injectionModel.isLoading,
                                    errorText: injectionModel.errorText
                                )
                                ClashInjectionCommandCard(
                                    readiness: injectionModel.readiness,
                                    targets: injectionModel.availableTargets,
                                    selectedTargetId: $injectionModel.selectedTargetId,
                                    selectedIntent: $injectionModel.selectedIntent,
                                    notes: $injectionModel.notes,
                                    isStarting: injectionModel.isStarting
                                ) {
                                    Task {
                                        await injectionModel.startInvestigation(gateway: gateway)
                                    }
                                } onStartDemo: {
                                    Task {
                                        await injectionModel.startDemoInvestigation(gateway: gateway)
                                    }
                                }
                                InvestigationCycleView(
                                    session: injectionModel.session,
                                    computer: injectionModel.computer,
                                    cycle: injectionModel.cycle,
                                    findings: injectionModel.findings,
                                    consequences: injectionModel.consequences,
                                    residue: injectionModel.residue
                                )
                                ResidueMemoryView(
                                    entries: injectionModel.residueMemory
                                )
                                liveSignalsCard
                                if gapFinderModel.hasData {
                                    DiscoveryRadarStatsStrip(stats: gapFinderModel.stats)
                                }
                                if let gapFinder = poller.gapFinderSnapshot ?? gapFinderModel.snapshot {
                                    GapFinderPanel(
                                        eyebrow: "Signal Scanner",
                                        title: "Patterns forming across topics",
                                        subtitle: "Top overlaps, bridge questions, and conflicts derived from live signals. The panel stays observational and never changes authority.",
                                        accent: .jeevesSky,
                                        snapshot: gapFinder
                                    )
                                }
                                IntelligencePhaseStrip(
                                    currentStage: intelligencePhase,
                                    summary: intelligencePhaseSummary
                                )
                                humanMeaningCard
                                if let operatorMemory = poller.operatorMemorySnapshot {
                                    OperatorMemoryPanel(
                                        title: "What you repeatedly focus on",
                                        accent: .jeevesMint,
                                        memory: operatorMemory
                                    )
                                }
                                if let collectiveMemory = poller.collectiveMemorySnapshot {
                                    CollectiveMemoryPanel(
                                        title: "What the system keeps learning together",
                                        accent: .jeevesGold,
                                        memory: collectiveMemory
                                    )
                                }
                                if let civilization = poller.civilizationSnapshot {
                                    CivilizationPanel(
                                        title: "Societal signals",
                                        accent: .jeevesSky,
                                        snapshot: civilization
                                    )
                                }
                                if let planetary = poller.planetarySnapshot {
                                    PlanetaryPanel(
                                        title: "Global patterns",
                                        accent: .jeevesMint,
                                        snapshot: planetary
                                    )
                                }
                                if let cosmic = poller.cosmicSnapshot {
                                    CosmicPanel(
                                        title: "Long-term trends",
                                        accent: .jeevesGold,
                                        snapshot: cosmic
                                    )
                                }
                                bootstrapCard
                                autonomyCard
                                realityAlignmentCard
                                walletCard
                                residueCard
                                recentSignalsCard
                                SystemLoopStrip(snapshot: systemLoopSnapshot)

                                MissionControlCompactStageCard(card: discoveryCard, isActive: systemLoopSnapshot.currentStage == .discovery)
                                MissionControlCompactStageCard(card: proposalCard, isActive: systemLoopSnapshot.currentStage == .proposal)
                                MissionControlCompactStageCard(card: approvalCard, isActive: systemLoopSnapshot.currentStage == .approval)
                                MissionControlCompactStageCard(card: actionCard, isActive: systemLoopSnapshot.currentStage == .action)
                                MissionControlCompactStageCard(card: knowledgeCard, isActive: systemLoopSnapshot.currentStage == .knowledge)
                            }
                        }
                        .frame(maxWidth: 560, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                        .frame(maxWidth: .infinity)
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
            .sheet(item: $selectedRecentSignal) { signal in
                RecentGridSignalDetailSheet(
                    signal: signal,
                    pendingProposal: linkedProposal(for: signal),
                    latestResidueEvent: latestResidueImpact(for: signal),
                    regionResidue: regionResidue(for: signal.region)
                )
            }
        }
    }

    /// The one card that currently requires user action.
    @ViewBuilder
    private var activeActionCard: some View {
        if pendingApprovalCount > 0 {
            // Pending approvals need attention
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("ACTION NEEDED")
                        .font(.caption.monospaced())
                        .foregroundStyle(.orange)

                    Spacer()

                    Text("\(pendingApprovalCount) PENDING")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.jeevesInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.orange.opacity(0.14)))
                }

                Text("\(pendingApprovalCount) decision\(pendingApprovalCount == 1 ? "" : "s") waiting for your review")
                    .font(.headline)
                    .foregroundStyle(Color.jeevesInk)

                Text("Pending decisions need your approval before the system can proceed. Open the full dashboard to review them.")
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesSubtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(border: .orange))
        } else if injectionModel.session != nil, injectionModel.session?.status != "completed", injectionModel.session?.status != "failed" {
            // Active investigation
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("ACTIVE RESEARCH")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.jeevesGold)

                    Spacer()

                    Text("IN PROGRESS")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.jeevesInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.jeevesGold.opacity(0.14)))
                }

                Text("A research task is currently running")
                    .font(.headline)
                    .foregroundStyle(Color.jeevesInk)

                Text("Expand the full dashboard to follow the investigation cycle and review findings.")
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesSubtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(border: .jeevesGold))
        } else {
            // Calm state
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("ALL CLEAR")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.jeevesMint)

                    Spacer()

                    Text("NO ACTION NEEDED")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.jeevesInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.jeevesMint.opacity(0.14)))
                }

                Text("The system is running smoothly")
                    .font(.headline)
                    .foregroundStyle(Color.jeevesInk)

                Text("No decisions are waiting and no research tasks are active. Expand the full dashboard to explore system details or start a new research task.")
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesSubtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(border: .jeevesMint))
        }
    }

    private var isBootstrapping: Bool {
        !poller.hasLoadedOnce && model.isLoading
    }

    private var systemLoopSnapshot: MissionControlSystemLoopSnapshot {
        MissionControlViewModel.systemLoopSnapshot(poller: poller, gateway: gateway)
    }

    private var bootstrapSnapshot: GovernedBootstrapSnapshot {
        GovernedBootstrapSnapshot.derive(
            status: gateway.currentStatus,
            proposals: poller.proposals,
            residue: poller.gridResidueSummary
        )
    }

    private var humanMeaningCard: some View {
        HumanMeaningPanel(
            title: "What Mission Control means now",
            accent: statusTint,
            explanation: HumanMeaningBuilder.missionControl(poller: poller, gateway: gateway)
        )
    }

    private var liveSignalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("LIVE GATEWAY SOURCES")
                    .font(.caption.monospaced())
                    .foregroundStyle(monoTint)

                Spacer()

                Text(liveSignalsStatus)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(monoTint.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(monoTint.opacity(0.18), lineWidth: 1)
                    )
            }

            Text(liveSignalsHeadline)
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            Text(liveSignalsSummaryLine)
                .font(.footnote)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)

            if let gravity = poller.signalsRuntimeSnapshot?.gravitySummary,
               gravity.activeEdgeCount > 0 {
                gravitySignalsStrip(gravity)
            }

            if isLoadingGovernedSignals {
                ProgressView("Loading governed signal state...")
                    .font(.footnote)
                    .tint(monoTint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                JeevesLiveSignalsPanel(
                    runtime: poller.signalsRuntimeSnapshot,
                    operatorMemory: poller.operatorMemorySnapshot
                )
            }

            if let error = liveSignalsErrorLine {
                Text("Signals runtime status: \(error)")
                    .font(.caption)
                    .foregroundStyle(Color.red.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(liveSignalsFooterLine)
                    .font(.caption)
                    .foregroundStyle(Color.jeevesMutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(border: monoTint))
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
                    .foregroundStyle(Color.jeevesInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(statusTint.opacity(0.14))
                    )
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(statusTint)
                            .frame(width: pulseFrame, height: pulseFrame)
                            .shadow(color: statusTint.opacity(0.22), radius: 4)
                            .padding(.top, 5)
                            .padding(.trailing, 5)
                    }
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(statusTint.opacity(0.18), lineWidth: 1)
                    )
            }

            Text("\(statusBadge.capitalized) • Last tick \(lastTickLine)")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.jeevesInk)

            Text("Review decisions, start investigations, and monitor governed system state at a glance.")
                .font(.subheadline)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                infoPill("\(discoveryCount) discoveries")
                infoPill("\(pendingApprovalCount) approvals pending")
            }

            Text(operatorLine)
                .font(.footnote)
                .foregroundStyle(Color.jeevesInk.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(border: statusTint))
    }

    private var bootstrapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("BOOTSTRAP")
                    .font(.caption.monospaced())
                    .foregroundStyle(.cyan)

                Spacer()

                Text(bootstrapSnapshot.phase.displayLabel)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.cyan.opacity(0.16), lineWidth: 1)
                    )
            }

            bootstrapLine(
                label: "Current phase",
                value: bootstrapSnapshot.phase.title
            )
            bootstrapLine(
                label: "Proof achieved",
                value: bootstrapSnapshot.proofAchieved
            )
            bootstrapLine(
                label: "Next proof",
                value: bootstrapSnapshot.nextProof
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(border: .cyan))
    }

    private func infoPill(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced).weight(.medium))
            .foregroundStyle(monoTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.jeevesCloud.opacity(0.7))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(statusTint.opacity(0.14), lineWidth: 1)
            )
    }

    private func bootstrapLine(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.monospaced())
                .foregroundStyle(Color.jeevesMutedText)
            Text(value)
                .font(.footnote)
                .foregroundStyle(Color.jeevesInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func cardBackground(border: Color) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.jeevesPanelStrong)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(border.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: border.opacity(0.08), radius: 12, y: 6)
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
        if discoveryCount > 0 { return .jeevesSky }
        return .jeevesMint
    }

    private var lastTickLine: String {
        guard let date = systemLoopSnapshot.lastTransitionAt else { return "unknown" }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        return "\(seconds) sec ago"
    }

    private var operatorLine: String {
        if pendingApprovalCount > 0 {
            return "Your review is required now."
        }
        if discoveryCount > 0 {
            return "Pipeline active in Discovery."
        }
        return "No decision is required right now."
    }

    private var connectionLine: String {
        let endpoint = "\(gateway.host):\(gateway.port)"
        if gateway.useMock || gateway.host.lowercased() == "mock" {
            return "Mock preview active. You can explore the interface safely before connecting a real gateway."
        }

        switch gateway.connectionState {
        case .connected:
            return "Connected to governed gateway \(endpoint)."
        case .connecting:
            return "Connecting to governed gateway \(endpoint)."
        case .reconnecting:
            return "Reconnecting to governed gateway \(endpoint)."
        case .failed:
            return "Connection to governed gateway \(endpoint) failed."
        case .disconnected:
            return "Jeeves is not connected to a governed gateway yet."
        }
    }

    private var missionControlSystemLine: String {
        if let readiness = injectionModel.readiness {
            return readiness.summary
        }
        if gateway.isConnected {
            return "The kernel is connected and Jeeves is checking whether the system is ready for your commands."
        }
        return "Connect a governed gateway to expose live system state and your work."
    }

    private var missionControlNextStepLine: String {
        if pendingApprovalCount > 0 {
            return "Review pending approvals first."
        }
        if let session = injectionModel.session, session.status != "completed", session.status != "failed" {
            return "Follow the active investigation cycle and review its findings."
        }
        if gateway.useMock || gateway.host.lowercased() == "mock" {
            return "Explore the interface in mock mode, or connect a real gateway when you want live governed data."
        }
        if injectionModel.readiness?.commandInitiationReady == true {
            return "Start an investigation or review retained knowledge."
        }
        if gateway.isConnected {
            return "Wait for readiness checks to finish, then start an investigation."
        }
        return "Open Settings and connect Jeeves to your governed gateway."
    }

    private var missionControlPrimaryActions: [String] {
        [
            "Review approvals",
            "Start investigation",
            "Check knowledge"
        ]
    }

    private var intelligencePhase: IntelligencePhaseStage {
        if killSwitchActive || budgetHardStop || pendingApprovalCount > 0 {
            return .safety
        }

        if proposalCount > 0 || runningActionCount > 0 || !recentBoundedActions.isEmpty {
            return .define
        }

        return .investigate
    }

    private var intelligencePhaseSummary: String {
        switch intelligencePhase {
        case .safety:
            return "Safety is foregrounded because approval pressure or active stops must stay visible to you."
        case .define:
            return "Define is foregrounded because signals are already being shaped into proposals, execution scope, or governed follow-through."
        case .investigate:
            return "Investigate is foregrounded because the runtime is reading discovery pressure, residue, and recent signals without immediate safety intervention."
        }
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

    private var autonomyStateSnapshot: DecisionAutonomyStateSnapshot? {
        poller.decisionAutonomyState
    }

    private var recentAutonomyDecisions: [AutonomousDecisionRecordSnapshot] {
        autonomyStateSnapshot?.recentAutonomousDecisions ?? []
    }

    private var boundedActionReceipts: [ActionReceipt] {
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

    private var topResidueRegion: GridResidueRegionSummary? {
        poller.gridResidueSummary?.regions.first
    }

    private var topResidueNode: GridResidueNodeSummary? {
        poller.gridResidueSummary?.nodes.first
    }

    private var residueFieldSnapshot: GridResidueFieldSnapshot? {
        poller.gridResidueField
    }

    private var topResidueRegions: [GridResidueRegionSummary] {
        Array((residueFieldSnapshot?.topRegions ?? poller.gridResidueSummary?.regions ?? []).prefix(3))
    }

    private var topResidueNodes: [GridResidueNodeSummary] {
        Array((residueFieldSnapshot?.topNodes ?? poller.gridResidueSummary?.nodes ?? []).prefix(3))
    }

    private var repeatedResiduePatterns: [GridResidueRepeatedPatternSummary] {
        Array((residueFieldSnapshot?.repeatedPatterns ?? []).prefix(3))
    }

    private var topResidueSignalFamilies: [GridResidueFieldSignalFamilySummary] {
        Array((residueFieldSnapshot?.topSignalFamilies ?? []).prefix(3))
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
            summary: pendingApprovalCount > 0 ? "Your approval is required before execution." : "No approval queue at this moment.",
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
            summary: boundedActionReceipts.first?.resultSummary ?? "No recent bounded action.",
            pills: [
                "\(runningActionCount) running",
                "\(failedActionCount) failed",
                "\(boundedActionReceipts.count) receipts"
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
        async let injectionRefresh: () = injectionModel.refresh(gateway: gateway)
        async let gapFinderRefresh: () = gapFinderModel.load(gateway: gateway, force: true)
        _ = await (injectionRefresh, gapFinderRefresh)
        if let feed = poller.safeClashFeed {
            model.trustSnapshot = MissionControlViewModel.snapshot(from: feed)
            model.hasLoaded = true
        } else {
            await model.load(gateway: gateway, force: true)
        }
    }

    private var liveSignalsStatus: String {
        if isLoadingGovernedSignals {
            return "LOADING"
        }
        if let runtime = poller.signalsRuntimeSnapshot {
            return (runtime.lastError?.isEmpty == false) ? "DEGRADED" : "CONNECTED"
        }
        if gateway.isConnected && poller.operatorMemorySnapshot != nil {
            return "CONNECTED"
        }
        if liveSignalsErrorLine != nil {
            return "DEGRADED"
        }
        return gateway.isConnected ? "STANDBY" : "IDLE"
    }

    private var liveSignalsHeadline: String {
        guard let runtime = poller.signalsRuntimeSnapshot else {
            if poller.operatorMemorySnapshot != nil {
                return "Your focus history is visible through the governed gateway"
            }
            return gateway.isConnected
                ? "Governed gateway is connected and waiting for live signal pressure"
                : "Governed gateway is standing by"
        }
        if let gravity = poller.signalsRuntimeSnapshot?.gravitySummary,
           gravity.activeEdgeCount > 0,
           let research = poller.signalsRuntimeSnapshot?.researchLane,
           research.signalCount24h > 0 {
            return "\(runtime.activeSourceCount) governed sources · \(research.signalCount24h) research signals · \(gravity.activeEdgeCount) gravity links"
        }
        if let gravity = poller.signalsRuntimeSnapshot?.gravitySummary,
           gravity.activeEdgeCount > 0 {
            return "\(runtime.activeSourceCount) governed sources · \(runtime.totalSignals) total signals · \(gravity.activeEdgeCount) gravity links"
        }
        if let research = poller.signalsRuntimeSnapshot?.researchLane, research.signalCount24h > 0 {
            return "\(runtime.activeSourceCount) governed sources · \(runtime.totalSignals) total signals · \(research.signalCount24h) research signals"
        }
        return "\(runtime.activeSourceCount) governed sources · \(runtime.totalSignals) total signals"
    }

    private var liveSignalsSummaryLine: String {
        if let gravity = poller.signalsRuntimeSnapshot?.gravitySummary,
           gravity.activeEdgeCount > 0 {
            let strongest = gravity.strongestEdge?.explanation ?? "The strongest pull is still being explained."
            let researchText: String
            if let research = poller.signalsRuntimeSnapshot?.researchLane, research.signalCount24h > 0 {
                researchText = "\(research.activitySpikeCount) elevated research candidate\(research.activitySpikeCount == 1 ? "" : "s") are also visible."
            } else {
                researchText = "Signals remain read-only until a human approves a proposal."
            }
            return "\(gravity.crossDomainPullCount) cross-domain pull event\(gravity.crossDomainPullCount == 1 ? "" : "s") are shaping discovery pressure. \(strongest) \(researchText)"
        }
        if let research = poller.signalsRuntimeSnapshot?.researchLane, research.signalCount24h > 0 {
            let domains = research.topDomains.prefix(3).map(humanizeDomain).joined(separator: ", ")
            let sources = research.sourceBreakdown
                .prefix(3)
                .map { "\($0.source.capitalized) \($0.signalCount)" }
                .joined(separator: " · ")
            let domainLine = domains.isEmpty ? "Hot domains are still forming." : "Hot domains: \(domains)."
            let sourceLine = sources.isEmpty ? "Research lane is active." : "Sources: \(sources)."
            return "\(research.activitySpikeCount) elevated research candidate\(research.activitySpikeCount == 1 ? "" : "s") surfaced in the governed loop. \(domainLine) \(sourceLine)"
        }

        guard let runtime = poller.signalsRuntimeSnapshot else {
            return "This panel reads governed gateway state only: discovery telemetry, proposal pressure, and focus history that already passed through the trust boundary."
        }

        let sourceWord = runtime.activeSourceCount == 1 ? "source" : "sources"
        let failureLine: String
        if let error = runtime.lastError, !error.isEmpty {
            failureLine = "Latest runtime issue: \(error)."
        } else {
            failureLine = "No runtime errors are currently visible."
        }
        let memoryLine: String
        if let operatorMemory = poller.operatorMemorySnapshot {
            memoryLine = "Your focus is currently strongest on \(humanizeDomain(operatorMemory.operatorFocusMemory.strongestFocus))."
        } else {
            memoryLine = "Focus history will appear here as governed decisions accumulate."
        }
        return "\(runtime.activeSourceCount) governed \(sourceWord) are currently visible. \(failureLine) \(memoryLine)"
    }

    private var liveSignalsFooterLine: String {
        if let gravity = poller.signalsRuntimeSnapshot?.gravitySummary,
           gravity.activeEdgeCount > 0 {
            return "Persistence trend \(gravity.persistenceTrend.capitalized) · anomaly magnet \(formatPercent(gravity.anomalyMagnetScore)) · gravity only strengthens discovery, never authority."
        }
        if let research = poller.signalsRuntimeSnapshot?.researchLane, research.signalCount24h > 0 {
            return "Latest research lane update \(research.latestDetectedAtIso ?? "unknown") · signals stay read-only until human approval."
        }
        if let runtime = poller.signalsRuntimeSnapshot {
            return "Governed signal update \(runtime.lastRunAtIso ?? runtime.startedAtIso ?? "unknown") · discovery stays read-only until human approval."
        }
        if let operatorMemory = poller.operatorMemorySnapshot {
            return "Remembered focus: \(humanizeDomain(operatorMemory.operatorFocusMemory.strongestFocus)) · openclashd-v2 remains the trust root."
        }
        return "openclashd-v2 is the trust root; Jeeves only renders governed gateway state."
    }

    private var isLoadingGovernedSignals: Bool {
        !poller.hasLoadedOnce
            && poller.signalsRuntimeSnapshot == nil
            && poller.operatorMemorySnapshot == nil
    }

    private var liveSignalsErrorLine: String? {
        if let runtimeError = poller.signalsRuntimeSnapshot?.lastError,
           !runtimeError.isEmpty {
            return runtimeError
        }
        return poller.lastRefreshError
    }

    private func humanizeDomain(_ value: String) -> String {
        value
            .split(whereSeparator: { $0 == " " || $0 == "_" || $0 == "-" })
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func gravitySignalsStrip(_ gravity: DiscoveryGravitySummary) -> some View {
        HStack(spacing: 10) {
            gravityMetric(label: "Links", value: "\(gravity.activeEdgeCount)")
            gravityMetric(label: "Cross-domain", value: "\(gravity.crossDomainPullCount)")
            gravityMetric(label: "Trend", value: gravity.persistenceTrend.capitalized)
            gravityMetric(label: "Magnet", value: formatPercent(gravity.anomalyMagnetScore))
        }
    }

    private func gravityMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.monospaced())
                .foregroundStyle(Color.jeevesMutedText)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.jeevesInk)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.jeevesCloud.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.jeevesLine.opacity(0.56), lineWidth: 1)
        )
    }

    private var monoTint: Color {
        .jeevesSky
    }

    private var pulseFrame: CGFloat {
        pulseActive && statusBadge != "HEALTHY" ? 10 : 8
    }

    private var realityAuditSnapshot: RealityAuditStateSnapshot? {
        poller.realityAuditState
    }

    private var recentRealityAudits: [RealityAuditSnapshot] {
        realityAuditSnapshot?.recentAudits ?? []
    }

    private var highestRealityAnomalies: [RealityAuditSnapshot] {
        realityAuditSnapshot?.highestAnomalyDecisions ?? []
    }

    private var autonomyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("AUTONOMY STATE")
                    .font(.caption.monospaced())
                    .foregroundStyle(.orange)

                Spacer()

                Text(autonomyStatus)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                    )
            }

            Text(autonomyHeadline)
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            Text(autonomySummaryLine)
                .font(.footnote)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Allowed automatic decisions")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)
                Text(autonomyAllowedDomainsLine)
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesInk.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Still human-only")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)
                Text(autonomyHumanOnlyLine)
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesInk.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Recent autonomous decisions")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)

                if recentAutonomyDecisions.isEmpty {
                    Text("No autonomous decisions recorded yet.")
                        .font(.footnote)
                        .foregroundStyle(Color.jeevesSubtleText)
                } else {
                    ForEach(recentAutonomyDecisions.prefix(3)) { decision in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(decision.decisionType.replacingOccurrences(of: "_", with: " "))
                                    .font(.system(.caption, design: .monospaced).weight(.medium))
                                    .foregroundStyle(monoTint.opacity(0.95))

                                Spacer(minLength: 8)

                                Text(decision.outcomeStatus)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(autonomyOutcomeColor(decision.outcomeStatus))
                            }

                            Text(decision.summary)
                                .font(.caption)
                                .foregroundStyle(Color.jeevesInk.opacity(0.84))
                                .fixedSize(horizontal: false, vertical: true)

                            Text("\(decision.theme) · \(decision.outcomeSignal)")
                                .font(.caption2)
                                .foregroundStyle(Color.jeevesMutedText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(border: .orange))
    }

    private var realityAlignmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("REALITY ALIGNMENT")
                    .font(.caption.monospaced())
                    .foregroundStyle(.pink)

                Spacer()

                Text(realityAlignmentStatus)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.pink.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.pink.opacity(0.18), lineWidth: 1)
                    )
            }

            Text(realityAlignmentHeadline)
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            Text(realityAlignmentSummaryLine)
                .font(.footnote)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Top contradictions")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)

                if highestRealityAnomalies.isEmpty {
                    Text("No counter-analysis warnings recorded yet.")
                        .font(.footnote)
                        .foregroundStyle(Color.jeevesSubtleText)
                } else {
                    ForEach(highestRealityAnomalies.prefix(3)) { audit in
                        Text("\(audit.theme) · \(audit.contradictionSignals.isEmpty ? "no major contradiction" : audit.contradictionSignals.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(Color.jeevesInk.opacity(0.84))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Confidence adjustments")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)

                if recentRealityAudits.isEmpty {
                    Text("Adjusted confidence will appear here after autonomous decisions are audited.")
                        .font(.footnote)
                        .foregroundStyle(Color.jeevesSubtleText)
                } else {
                    ForEach(recentRealityAudits.prefix(3)) { audit in
                        HStack(alignment: .top) {
                            Text("\(String(format: "%.2f", audit.originalConfidence)) → \(String(format: "%.2f", audit.adjustedConfidence))")
                                .font(.system(.caption, design: .monospaced).weight(.medium))
                                .foregroundStyle(realityAnomalyColor(audit.anomalyScore))
                            Text(audit.auditSummary)
                                .font(.caption)
                                .foregroundStyle(Color.jeevesInk.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Entropy warnings")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)
                Text(realityEntropyWarningLine)
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesInk.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(border: .pink))
    }

    private var walletCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("SAFECLASH WALLET")
                    .font(.caption.monospaced())
                    .foregroundStyle(.mint)

                Spacer()

                Text(walletStatus)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.mint.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.mint.opacity(0.18), lineWidth: 1)
                    )
            }

            HStack(alignment: .lastTextBaseline) {
                Text(walletBalanceLine)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(monoTint)

                Spacer(minLength: 12)

                Text("Your wallet")
                    .font(.headline)
                    .foregroundStyle(Color.jeevesInk)
            }

            Text(walletSummaryLine)
                .font(.footnote)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                walletPill(latestWalletReceiptLine)
                walletPill(lastWalletProposalLine)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(border: .mint))
    }

    private var residueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("SIGNAL HISTORY")
                    .font(.caption.monospaced())
                    .foregroundStyle(.green)

                Spacer()

                Text(residueStatus)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.green.opacity(0.18), lineWidth: 1)
                    )
            }

            Text(residueHeadline)
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            Text(residueSummaryLine)
                .font(.footnote)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Field maturity")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)
                Text(residueFieldMaturityLine)
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesInk.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                if !topResidueSignalFamilies.isEmpty {
                    Text("Signal families: \(topResidueSignalFamilies.map(\.family).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(Color.jeevesSubtleText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Top nodes by residue")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)

                if topResidueNodes.isEmpty {
                    Text("No node residue recorded yet.")
                        .font(.footnote)
                        .foregroundStyle(Color.jeevesSubtleText)
                } else {
                    ForEach(topResidueNodes, id: \.nodeId) { entry in
                        residueRankRow(primary: entry.nodeId, residue: entry.residue)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Top regions by residue")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)

                if topResidueRegions.isEmpty {
                    Text("No regional residue recorded yet.")
                        .font(.footnote)
                        .foregroundStyle(Color.jeevesSubtleText)
                } else {
                    ForEach(topResidueRegions, id: \.region) { entry in
                        residueRankRow(primary: entry.region, residue: entry.residue)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Repeated patterns")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)

                if repeatedResiduePatterns.isEmpty {
                    Text("No repeated confirmed field patterns yet.")
                        .font(.footnote)
                        .foregroundStyle(Color.jeevesSubtleText)
                } else {
                    ForEach(repeatedResiduePatterns) { pattern in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(pattern.region) · \(pattern.signalFamily)")
                                    .font(.system(.caption, design: .monospaced).weight(.medium))
                                    .foregroundStyle(monoTint.opacity(0.95))
                                Text("\(pattern.confirmedCount) confirmed of \(pattern.occurrenceCount) · avg \(String(format: "%.2f", pattern.averageConfidence))")
                                    .font(.caption2)
                                    .foregroundStyle(Color.jeevesMutedText)
                            }

                            Spacer(minLength: 8)

                            Text("repeat")
                                .font(.caption2.monospaced())
                                .foregroundStyle(Color.green.opacity(0.88))
                        }
                    }
                }
            }

            if !poller.gridResidueEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent residue events")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.jeevesMutedText)

                    ForEach(poller.gridResidueEvents.prefix(3)) { event in
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(event.region) · \(event.nodeId)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(monoTint.opacity(0.95))

                            Spacer(minLength: 8)

                            Text(String(format: "+%.2f", event.residueValue))
                                .font(.system(.caption, design: .monospaced).weight(.medium))
                                .foregroundStyle(Color.green.opacity(0.92))
                        }

                        Text(shortResidueTimestamp(event.timestamp))
                            .font(.caption2)
                            .foregroundStyle(Color.jeevesMutedText)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(border: .green))
    }

    private func residueRankRow(primary: String, residue: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(primary)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(monoTint.opacity(0.95))

            Spacer(minLength: 8)

            Text("+\(formatResidue(residue))")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color.green.opacity(0.92))
        }
    }

    private var recentSignalsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("RECENT SIGNALS")
                    .font(.caption.monospaced())
                    .foregroundStyle(.blue)

                Spacer()

                Text(recentSignalsStatus)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.jeevesInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.blue.opacity(0.18), lineWidth: 1)
                    )
            }

            Text(recentSignalsHeadline)
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            Text(recentSignalsSummaryLine)
                .font(.footnote)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)

            if poller.recentGridSignals.isEmpty {
                Text("No recent grid signals are visible yet.")
                    .font(.footnote)
                    .foregroundStyle(Color.jeevesSubtleText)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(poller.recentGridSignals.prefix(4)) { signal in
                        Button {
                            selectedRecentSignal = signal
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(signal.nodeId) · \(signal.signalType)")
                                        .font(.system(.caption, design: .monospaced).weight(.medium))
                                        .foregroundStyle(monoTint.opacity(0.95))
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Text("\(signal.region) · \(signal.severity) · \(shortResidueTimestamp(signal.timestamp))")
                                        .font(.caption2)
                                        .foregroundStyle(Color.jeevesMutedText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.jeevesMutedText)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(border: .blue))
    }

    private func walletPill(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(monoTint.opacity(0.92))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.jeevesCloud.opacity(0.7))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.mint.opacity(0.14), lineWidth: 1)
            )
    }

    private var walletStatus: String {
        poller.walletBalance == nil ? "UNAVAILABLE" : "READ ONLY"
    }

    private var walletBalanceLine: String {
        guard let wallet = poller.walletBalance else { return "--" }
        return String(format: "%.2f %@", wallet.balance, wallet.currency.uppercased())
    }

    private var walletSummaryLine: String {
        guard let wallet = poller.walletBalance else {
            return "SafeClash wallet data is not available yet. Jeeves remains informational and will refresh when wallet receipts appear."
        }
        if let latest = poller.recentReceipts.first, !latest.receiptId.isEmpty {
            return "Recent receipt \(shortId(latest.receiptId)) links this wallet to governed runtime activity without enabling automatic spending."
        }
        return "Wallet \(shortId(wallet.walletId)) is visible. Receipts will appear here after SafeClash writes them."
    }

    private var latestWalletReceiptLine: String {
        guard let latest = poller.recentReceipts.first else { return "no receipt" }
        return "receipt \(shortId(latest.receiptId))"
    }

    private var lastWalletProposalLine: String {
        guard let latest = poller.recentReceipts.first, !latest.proposalId.isEmpty else { return "no linked proposal" }
        return "proposal \(shortId(latest.proposalId))"
    }

    private var residueStatus: String {
        residueFieldSnapshot == nil && poller.gridResidueSummary == nil ? "UNAVAILABLE" : "VISIBLE"
    }

    private var recentSignalsStatus: String {
        poller.recentGridSignals.isEmpty ? "IDLE" : "VISIBLE"
    }

    private var recentSignalsHeadline: String {
        let count = poller.recentGridSignals.count
        if count == 0 {
            return "No recent signals"
        }
        return "\(count) live signal\(count == 1 ? "" : "s") entering the kernel"
    }

    private var recentSignalsSummaryLine: String {
        if !poller.recentGridSignals.isEmpty {
            return "Read-only observability over the latest grid intake. Tap a signal to inspect its linked proposal, cluster status, and residue impact."
        }
        return "Signals appear here as soon as they enter the governed kernel."
    }

    private var residueHeadline: String {
        if let field = residueFieldSnapshot {
            switch field.fieldMaturity {
            case "maturing":
                return "Residue field is maturing"
            case "forming":
                return "Residue field is forming"
            default:
                return "Residue field is sparse"
            }
        }
        let count = poller.gridResidueEvents.count
        if count == 0 {
            return "No recent residue events"
        }
        return "\(count) recent residue event\(count == 1 ? "" : "s")"
    }

    private var residueSummaryLine: String {
        if let field = residueFieldSnapshot {
            return "The residue field is built from governed decisions. \(field.activeNodeCount) nodes, \(field.activeRegionCount) regions, and \(field.activeSignalFamilyCount) signal families are active."
        }
        if let topRegion = topResidueRegion, let topNode = topResidueNode {
            return "Residue is visible. Highest region is \(topRegion.region) (\(formatResidue(topRegion.residue))). Highest node is \(topNode.nodeId) (\(formatResidue(topNode.residue)))."
        }
        return "Residue becomes visible here after governed proposal decisions create new residue history."
    }

    private var residueFieldMaturityLine: String {
        guard let field = residueFieldSnapshot else {
            return "Field state is not available yet."
        }
        switch field.fieldMaturity {
        case "maturing":
            return "Maturing. Multiple repeated confirmed patterns now span nodes, regions, and signal families."
        case "forming":
            return "Forming. Repeated confirmed patterns are visible and the field is starting to hold shape."
        default:
            return "Sparse. Residue exists, but the field is still early and lightly connected."
        }
    }

    private var autonomyStatus: String {
        guard let autonomyStateSnapshot else {
            return "idle"
        }
        if autonomyStateSnapshot.recentAutonomousDecisions.isEmpty {
            return "limited"
        }
        return formatPercent(autonomyStateSnapshot.successRate)
    }

    private var autonomyHeadline: String {
        guard let autonomyStateSnapshot else {
            return "Limited autonomy is available but inactive."
        }
        return "\(autonomyStateSnapshot.recentAutonomousDecisions.count) autonomous decisions tracked"
    }

    private var autonomySummaryLine: String {
        guard let autonomyStateSnapshot else {
            return "Automatic decisions are limited to safe internal triage domains and remain fully inspectable."
        }
        return "Success rate \(formatPercent(autonomyStateSnapshot.successRate)) · autonomy residue \(formatSignedResidue(autonomyStateSnapshot.autonomousResidue))."
    }

    private var autonomyAllowedDomainsLine: String {
        let domains = autonomyStateSnapshot?.domainsCurrentlyAllowed ?? []
        if domains.isEmpty {
            return "prioritize, ignore as noise, monitor, escalate for human review"
        }
        return domains
            .map { $0.replacingOccurrences(of: "_", with: " ") }
            .joined(separator: ", ")
    }

    private var autonomyHumanOnlyLine: String {
        let domains = autonomyStateSnapshot?.stillRequiresHumanApproval ?? []
        if domains.isEmpty {
            return "proposal approval, payments, governance, and external actions"
        }
        return domains.joined(separator: ", ")
    }

    private var realityAlignmentStatus: String {
        guard let trend = realityAuditSnapshot?.entropyTrend else {
            return "idle"
        }
        switch trend.direction {
        case "improving":
            return "stable"
        case "degrading":
            return "warning"
        default:
            return "watch"
        }
    }

    private var realityAlignmentHeadline: String {
        guard let snapshot = realityAuditSnapshot else {
            return "Counter-analysis is available but no autonomous decisions have been audited yet."
        }
        return "\(snapshot.recentAudits.count) audited autonomous decisions"
    }

    private var realityAlignmentSummaryLine: String {
        guard let trend = realityAuditSnapshot?.entropyTrend else {
            return "Autonomous decisions face contradiction analysis before gaining long-term learning influence."
        }
        return "Entropy trend \(trend.direction) · average delta \(String(format: "%+.2f", trend.averageEntropyDelta)) · adjusted confidence \(String(format: "%.2f", trend.averageAdjustedConfidence))."
    }

    private var realityEntropyWarningLine: String {
        guard let trend = realityAuditSnapshot?.entropyTrend else {
            return "Low diversity, drift, and concentration warnings will be surfaced here."
        }
        switch trend.direction {
        case "degrading":
            return "Entropy is rising. Review contradiction-heavy automatic decisions before they gain more influence."
        case "improving":
            return "Entropy is lowering. Recent decisions are holding up under counter-analysis."
        default:
            return "Entropy is stable. Watch contradiction spikes and confidence reductions."
        }
    }

    private func shortId(_ value: String) -> String {
        if value.count <= 12 {
            return value
        }
        return String(value.prefix(12))
    }

    private func formatResidue(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func formatSignedResidue(_ value: Double) -> String {
        String(format: value >= 0 ? "+%.2f" : "%.2f", value)
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    private func autonomyOutcomeColor(_ status: String) -> Color {
        switch status {
        case "successful":
            return .green.opacity(0.9)
        case "unsuccessful":
            return .red.opacity(0.9)
        default:
            return .orange.opacity(0.9)
        }
    }

    private func realityAnomalyColor(_ score: Double) -> Color {
        if score >= 0.65 {
            return .red.opacity(0.9)
        }
        if score >= 0.4 {
            return .orange.opacity(0.9)
        }
        return .green.opacity(0.9)
    }

    private func shortResidueTimestamp(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }

    private func linkedProposal(for signal: RecentGridSignal) -> Proposal? {
        poller.proposals.first { proposal in
            proposal.gridOriginSignalId == signal.signalId
                || proposal.correlatedGridMemberSignalIds.contains(signal.signalId)
        }
    }

    private func latestResidueImpact(for signal: RecentGridSignal) -> GridResidueHistoryEvent? {
        poller.gridResidueEvents.first { event in
            event.nodeId == signal.nodeId && event.region == signal.region
        }
    }

    private func regionResidue(for region: String) -> GridResidueRegionSummary? {
        poller.gridResidueSummary?.regions.first { $0.region == region }
    }
}

private struct RecentGridSignalDetailSheet: View {
    let signal: RecentGridSignal
    let pendingProposal: Proposal?
    let latestResidueEvent: GridResidueHistoryEvent?
    let regionResidue: GridResidueRegionSummary?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("Signal") {
                        detailRow("Signal ID", signal.signalId)
                        detailRow("Node", signal.nodeId)
                        detailRow("Region", signal.region)
                        detailRow("Type", signal.signalType)
                        detailRow("Severity", signal.severity)
                        detailRow("Timestamp", signal.timestamp)
                    }

                    section("Proposal") {
                        if let pendingProposal {
                            detailRow("Title", pendingProposal.title)
                            detailRow("Status", pendingProposal.status)
                            detailRow("Proposal ID", pendingProposal.proposalId)
                        } else {
                            detailRow("Status", "No live proposal linked in the current queue.")
                        }
                    }

                    section("Cluster") {
                        if let pendingProposal, pendingProposal.isCorrelatedGridEvent {
                            detailRow("Mode", "Correlated grid event")
                            detailRow("Region", pendingProposal.gridRegion ?? signal.region)
                            detailRow("Members", pendingProposal.correlatedGridMemberNodeIds.joined(separator: ", "))
                            detailRow("Signals", pendingProposal.correlatedGridMemberSignalIds.joined(separator: ", "))
                            detailRow("Confidence", pendingProposal.correlatedGridConfidenceText ?? "--")
                            detailRow("Summary", pendingProposal.correlatedGridSummary ?? "Grouped signal cluster")
                        } else {
                            detailRow("Mode", "Single governed signal")
                        }
                    }

                    section("Residue Impact") {
                        if let latestResidueEvent {
                            detailRow("Latest event", "\(latestResidueEvent.region) · \(latestResidueEvent.nodeId)")
                            detailRow("Residue value", String(format: "+%.2f", latestResidueEvent.residueValue))
                            detailRow("Recorded at", latestResidueEvent.timestamp)
                        } else {
                            detailRow("Status", "No residue recorded yet for this node-region path.")
                        }

                        if let regionResidue {
                            detailRow("Region total", String(format: "%.2f", regionResidue.residue))
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Recent Signal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.monospaced())
                .foregroundStyle(Color.blue.opacity(0.86))

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.jeevesPanel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.jeevesLine.opacity(0.6), lineWidth: 1)
                    )
            )
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(Color.jeevesMutedText)
            Text(value)
                .font(.footnote)
                .foregroundStyle(Color.jeevesInk)
                .fixedSize(horizontal: false, vertical: true)
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
                    .foregroundStyle(Color.jeevesInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(stageTint.opacity(0.14))
                    )
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(stageTint)
                            .frame(width: badgeDotSize, height: badgeDotSize)
                            .shadow(color: stageTint.opacity(0.18), radius: 4)
                            .padding(.top, 4)
                            .padding(.trailing, 4)
                    }
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(stageTint.opacity(0.16), lineWidth: 1)
                    )
            }

            HStack(alignment: .lastTextBaseline) {
                Text(card.primaryMetric)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(monoTint)

                Spacer(minLength: 12)

                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(Color.jeevesInk)
            }

            Text(card.summary)
                .font(.footnote)
                .foregroundStyle(Color.jeevesSubtleText)
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
                                .fill(Color.jeevesCloud.opacity(0.7))
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
                .fill(Color.jeevesPanelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(stageTint.opacity(isActive ? 0.26 : 0.14), lineWidth: 1)
                )
                .shadow(color: glowTint.opacity(isActive ? 0.08 : 0.04), radius: isActive ? 12 : 8, y: 6)
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(stageTint.opacity(isActive ? 0.10 : 0.05))
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
        case .discovery: return .jeevesSky
        case .proposal: return .blue
        case .approval: return .orange
        case .action: return .teal
        case .knowledge: return .jeevesMint
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

// MARK: - Discovery Radar Stats Strip

struct DiscoveryRadarStatsStrip: View {
    let stats: GapFinderStats

    var body: some View {
        HStack(spacing: 14) {
            statPill(label: "Overlaps", value: "\(stats.matchCount)", tint: .jeevesSky)
            statPill(label: "Gap candidates", value: "\(stats.gapCount)", tint: .jeevesGold)
            statPill(label: "Emerging", value: "\(stats.emergingCount)", tint: .jeevesMint)
            if stats.entropyConflicts > 0 {
                statPill(label: "Entropy conflicts", value: "\(stats.entropyConflicts)", tint: .orange)
            }
            Spacer()
        }
        .briefingPanel()
    }

    private func statPill(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(tint)
            Text(value)
                .font(.jeevesHeadline)
                .foregroundStyle(.primary)
        }
    }
}
