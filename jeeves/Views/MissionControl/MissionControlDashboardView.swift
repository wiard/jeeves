import SwiftUI

struct MissionControlDashboardView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @State private var model = MissionControlViewModel()
    @State private var selectedDiscoveryCellIndex: Int?

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
                    dashboardContent
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
                    Task {
                        await refresh()
                    }
                }
            }
        }
    }

    private var isBootstrapping: Bool {
        !poller.hasLoadedOnce && model.isLoading
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                systemStatusCard
                    .calmAppear()

                SystemLoopStrip(snapshot: systemLoopSnapshot)
                    .calmAppear(delay: 0.03)

                ForEach(Array(stageCards.enumerated()), id: \.element.id) { index, card in
                    MissionControlCompactStageCard(
                        card: card,
                        isActive: systemLoopSnapshot.currentStage == card.stage
                    )
                    .calmAppear(delay: 0.05 + (Double(index) * 0.04))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    private var discoveryPanel: some View {
        InstrumentSectionPanel(
            eyebrow: "Discovery",
            title: "Radar pressure and gap emergence",
            subtitle: "Jeeves is only visualizing CLASHD27 discovery state. No discovery logic lives in the cockpit.",
            accent: .cyan,
            metric: "\(discoveryMetric)"
        ) {
            MissionControlMiniMetricRow(items: [
                .init(label: "Collisions", value: "\(collisionCount)", tint: .cyan),
                .init(label: "Emergence", value: "\(emergenceCount)", tint: .purple),
                .init(label: "Gap candidates", value: "\(gapCandidateCount)", tint: .orange)
            ])

            MissionControlDiscoveryCubeView(
                cube: discoveryCube,
                topSignal: topDiscoverySignal,
                selectedCellIndex: resolvedSelectedDiscoveryCellIndex,
                onSelectCell: { cell in
                    selectedDiscoveryCellIndex = cell.index
                }
            )

            if let detail = selectedDiscoveryDetail {
                MissionControlCubeCellDetailView(detail: detail)
            }

            if let signal = topDiscoverySignal {
                MissionControlSpotlightCard(
                    eyebrow: "Top discovery signal",
                    title: signal.title,
                    detail: "\(signal.source) is carrying the strongest visible residue at \(format(signal.residue)). Jeeves is surfacing the signal only; CLASHD27 remains the discovery authority.",
                    tint: .blue,
                    badge: "RESIDUE \(format(signal.residue))"
                )
            } else {
                MissionControlPlaceholderRow(
                    title: "Top discovery signal",
                    detail: "Waiting for CLASHD27 radar output."
                )
            }

            if topCollisionSummary != nil || topEmergenceSummary != nil {
                MissionControlSummaryStrip(
                    items: [
                        topCollisionSummary.map {
                            .init(label: "Collision summary", detail: $0, tint: .cyan)
                        },
                        topEmergenceSummary.map {
                            .init(label: "Emergence summary", detail: $0, tint: .purple)
                        }
                    ].compactMap { $0 }
                )
            } else {
                MissionControlPlaceholderRow(
                    title: "Collision / emergence summary",
                    detail: "No dense collision or emergence summary is available right now."
                )
            }

            if let candidate = topGapCandidate {
                MissionControlFeatureRow(
                    title: "Top gap candidate",
                    detail: candidate.explanation.isEmpty ? candidate.sources.joined(separator: ", ") : candidate.explanation,
                    tint: candidate.crossDomain ? .orange : .cyan,
                    badge: gapCandidateBadge(for: candidate)
                )
            } else {
                MissionControlPlaceholderRow(
                    title: "Gap candidate lane",
                    detail: "No gap candidates are currently being surfaced."
                )
            }

            MissionControlFeatureRow(
                title: "Field posture",
                detail: discoveryStateDetail,
                tint: discoveryTint,
                badge: discoveryStateLabel
            )
        }
    }

    private var governancePanel: some View {
        InstrumentSectionPanel(
            eyebrow: "Governance",
            title: "Pending review and bounded actions",
            subtitle: "All execution authority remains with openclashd-v2. Jeeves only reflects approval state and recent action receipts.",
            accent: .orange,
            metric: "\(pendingApprovalCount)"
        ) {
            MissionControlMiniMetricRow(items: [
                .init(label: "Pending gaps", value: "\(pendingGapCount)", tint: .orange),
                .init(label: "All pending", value: "\(pendingApprovalCount)", tint: .orange),
                .init(label: "Approved", value: "\(approvedCount)", tint: .green),
                .init(label: "Denied", value: "\(deniedCount)", tint: .red)
            ])

            MissionControlFeatureRow(
                title: "Kernel posture",
                detail: governanceStateDetail,
                tint: governanceTint,
                badge: governanceStateLabel
            )

            if let proposal = topPendingProposal {
                MissionControlSpotlightCard(
                    eyebrow: "Operator pressure",
                    title: proposal.title,
                    detail: proposal.priorityExplanation ?? proposal.intent.key.replacingOccurrences(of: "_", with: " "),
                    tint: governanceTint,
                    badge: proposalPressureBadge(for: proposal)
                )
            } else {
                MissionControlPlaceholderRow(
                    title: "Pending proposal spotlight",
                    detail: "No pending proposals are currently applying operator pressure."
                )
            }

            if let action = recentBoundedActions.first {
                MissionControlFeatureRow(
                    title: "Most recent bounded action",
                    detail: recentActionDetail(action),
                    tint: action.isFailed ? .red : .green,
                    badge: action.executionState.uppercased()
                )
            } else {
                MissionControlPlaceholderRow(
                    title: "Recent bounded actions",
                    detail: "No action receipts have been surfaced yet."
                )
            }

            if recentBoundedActions.count > 1 {
                ForEach(Array(recentBoundedActions.dropFirst())) { action in
                    MissionControlFeatureRow(
                        title: action.actionKind.replacingOccurrences(of: "_", with: " ").capitalized,
                        detail: action.receipt?.resultSummary ?? action.executionState.capitalized,
                        tint: action.isFailed ? .red : .green,
                        badge: action.executionState.uppercased()
                    )
                }
            }
        }
    }

    private var knowledgePanel: some View {
        InstrumentSectionPanel(
            eyebrow: "Knowledge",
            title: "Recent objects, discoveries, and evidence",
            subtitle: "Knowledge remains operator-visible here and stays attributable to the proposal or action that produced it.",
            accent: .green,
            metric: knowledgeMetric
        ) {
            MissionControlMiniMetricRow(items: [
                .init(label: "Signals 24h", value: "\(knowledgeSignals24h)", tint: .green),
                .init(label: "Clusters", value: "\(knowledgeClusterCount)", tint: .purple),
                .init(label: "Fresh objects", value: "\(poller.recentKnowledgeObjects.count)", tint: .blue)
            ])

            MissionControlFeatureRow(
                title: "Knowledge posture",
                detail: knowledgeStateDetail,
                tint: knowledgeTint,
                badge: knowledgeStateLabel
            )

            if let object = mostRecentKnowledgeObject {
                MissionControlSpotlightCard(
                    eyebrow: "Most recent knowledge object",
                    title: object.title,
                    detail: object.summary,
                    tint: color(forKnowledgeKind: object.kind),
                    badge: object.kind.uppercased()
                )
            } else {
                MissionControlPlaceholderRow(
                    title: "Recent knowledge objects",
                    detail: "No recent knowledge objects are available."
                )
            }

            MissionControlFlowCard(
                title: "Discovery to knowledge flow",
                detail: discoveryKnowledgeFlowDetail,
                tint: .green
            )

            if recentKnowledge.count > 1 {
                ForEach(Array(recentKnowledge.dropFirst())) { object in
                    MissionControlFeatureRow(
                        title: object.title,
                        detail: object.summary,
                        tint: color(forKnowledgeKind: object.kind),
                        badge: object.kind.uppercased()
                    )
                }
            }

            if let discovery = recentDiscoveries.first {
                MissionControlFeatureRow(
                    title: "Latest discovery in flow",
                    detail: discovery.explanation,
                    tint: .purple,
                    badge: gapCandidateBadge(for: discovery)
                )
            } else {
                MissionControlPlaceholderRow(
                    title: "Recent discoveries",
                    detail: "Discovery candidates will appear here when CLASHD27 emits them."
                )
            }

            if researchEvidence.isEmpty {
                MissionControlPlaceholderRow(
                    title: "Research / evidence summaries",
                    detail: "Evidence summaries are waiting on knowledge objects of kind evidence or discovery."
                )
            } else {
                ForEach(researchEvidence) { object in
                    MissionControlFeatureRow(
                        title: object.title,
                        detail: object.summary,
                        tint: .blue
                    )
                }
            }
        }
    }

    private var trustPanel: some View {
        InstrumentSectionPanel(
            eyebrow: "Trust",
            title: "Receipts, attestations, and capability status",
            subtitle: "SafeClash stays the trust and certification layer. Jeeves presents the trust picture as a read-only operator surface.",
            accent: .blue,
            metric: trustMetric
        ) {
            MissionControlMiniMetricRow(items: [
                .init(label: "Trusted", value: "\(trustedChannelCount)", tint: .green),
                .init(label: "Semi", value: "\(semiTrustedChannelCount)", tint: .orange),
                .init(label: "Untrusted", value: "\(untrustedChannelCount)", tint: .red)
            ])

            MissionControlFeatureRow(
                title: "Boundary posture",
                detail: trustStateDetail,
                tint: trustTint,
                badge: trustStateLabel
            )

            MissionControlReadOnlyBadge(
                title: "Read-only trust surface",
                detail: "Receipts, attestations, and certifications are displayed here without adding execution authority to Jeeves."
            )

            if let receipt = recentReceipts.first {
                MissionControlSpotlightCard(
                    eyebrow: "Latest receipt",
                    title: receipt.resultType ?? "Governed receipt",
                    detail: receipt.resultSummary,
                    tint: receipt.executionState == "completed" ? .green : .orange,
                    badge: receipt.executionState.uppercased()
                )
            } else {
                MissionControlPlaceholderRow(
                    title: "Receipts",
                    detail: "No recent receipts available from governed actions."
                )
            }

            if recentReceipts.count > 1 {
                ForEach(Array(recentReceipts.dropFirst())) { receipt in
                    MissionControlFeatureRow(
                        title: receipt.resultType ?? "Governed receipt",
                        detail: receipt.resultSummary,
                        tint: receipt.executionState == "completed" ? .green : .orange,
                        badge: receipt.executionState.uppercased()
                    )
                }
            }

            if let attestation = primaryAttestation {
                MissionControlFeatureRow(
                    title: "Primary attestation",
                    detail: attestation.detail + (attestation.certificateId.map { " · \($0)" } ?? ""),
                    tint: .blue,
                    badge: "SAFECLASH"
                )
            } else {
                MissionControlPlaceholderRow(
                    title: "Attestations",
                    detail: model.trustSnapshot.operatorNote ?? "SafeClash attestation feed is not connected yet."
                )
            }

            if model.trustSnapshot.attestations.count > 1 {
                ForEach(Array(model.trustSnapshot.attestations.dropFirst())) { attestation in
                    MissionControlFeatureRow(
                        title: attestation.title,
                        detail: attestation.detail + (attestation.certificateId.map { " · \($0)" } ?? ""),
                        tint: .blue
                    )
                }
            }

            if let capability = primaryCapabilityStatus {
                MissionControlFeatureRow(
                    title: "Strongest capability status",
                    detail: capability.detail,
                    tint: capability.emphasis == "ready" ? .green : .orange,
                    badge: capability.title.uppercased()
                )
            } else {
                MissionControlPlaceholderRow(
                    title: "Capability status",
                    detail: "Capability certification detail is currently placeholder/read-only."
                )
            }

            if model.trustSnapshot.capabilityStatuses.count > 1 {
                ForEach(Array(model.trustSnapshot.capabilityStatuses.dropFirst())) { status in
                    MissionControlFeatureRow(
                        title: status.title,
                        detail: status.detail,
                        tint: status.emphasis == "ready" ? .green : .orange
                    )
                }
            }
        }
    }

    private var topDiscoverySignal: RadarTopSignal? {
        poller.radarStatus?.store?.topSignals.first
    }

    private var discoveryCube: MissionControlDiscoveryCube {
        MissionControlDiscoveryCube.derive(
            topSignal: topDiscoverySignal,
            radarStatus: poller.radarStatus,
            collisions: poller.radarCollisions,
            emergence: poller.radarEmergence,
            hotspots: poller.radarGravityHotspots,
            activations: poller.radarActivations,
            discoveries: poller.radarDiscoveryCandidates,
            knowledgeStatus: knowledgeSnapshot,
            pendingGapCount: pendingGapCount
        )
    }

    private var resolvedSelectedDiscoveryCellIndex: Int? {
        if let selectedDiscoveryCellIndex,
           discoveryCube.cells.contains(where: { $0.index == selectedDiscoveryCellIndex }) {
            return selectedDiscoveryCellIndex
        }
        return discoveryCube.topCellIndex
            ?? discoveryCube.cells.first(where: \.isActive)?.index
            ?? discoveryCube.cells.first?.index
    }

    private var selectedDiscoveryDetail: MissionControlCubeCellDetailState? {
        guard let index = resolvedSelectedDiscoveryCellIndex else { return nil }
        return discoveryCube.detailState(
            for: index,
            topSignal: topDiscoverySignal,
            collisions: poller.radarCollisions,
            emergence: poller.radarEmergence,
            hotspots: poller.radarGravityHotspots,
            activations: poller.radarActivations,
            discoveries: poller.radarDiscoveryCandidates,
            knowledgeObjects: poller.recentKnowledgeObjects,
            pendingProposals: poller.pendingProposals
        )
    }

    private var collisionCount: Int {
        poller.radarStatus?.store?.collisionCount ?? poller.radarCollisions.count
    }

    private var emergenceCount: Int {
        poller.radarStatus?.store?.emergenceCount ?? poller.radarEmergence.count
    }

    private var gapCandidateCount: Int {
        max(poller.radarDiscoveryCandidates.count, pendingGapCount)
    }

    private var pendingApprovalCount: Int {
        max(
            poller.pendingProposals.count,
            poller.conductorState?.consentPending ?? gateway.currentStatus?.consent.pending ?? 0
        )
    }

    private var killSwitchActive: Bool {
        poller.conductorState?.killSwitch.active ?? gateway.currentStatus?.killSwitch.active ?? false
    }

    private var budgetHardStop: Bool {
        poller.conductorState?.budget.hardStop ?? gateway.currentStatus?.budget.hardStop ?? false
    }

    private var discoveryStateLabel: String {
        if gapCandidateCount > 0 { return "HEATING" }
        if emergenceCount > 0 { return "RISING" }
        if collisionCount > 0 { return "WATCH" }
        return "QUIET"
    }

    private var discoveryTint: Color {
        if gapCandidateCount > 0 { return .orange }
        if emergenceCount > 0 { return .purple }
        if collisionCount > 0 { return .cyan }
        return .secondary
    }

    private var discoveryStateDetail: String {
        if let signal = topDiscoverySignal {
            return "Top live signal: \(signal.title) from \(signal.source). Discovery stays read-only inside Jeeves."
        }
        if gapCandidateCount > 0 {
            return "\(gapCandidateCount) discovery candidate\(gapCandidateCount == 1 ? "" : "s") are visible from CLASHD27."
        }
        return "No strong discovery pressure is currently visible."
    }

    private var discoveryMetric: Int {
        collisionCount + emergenceCount + gapCandidateCount
    }

    private var topCollision: RadarCollision? {
        poller.radarCollisions.max { lhs, rhs in
            lhs.density < rhs.density
        }
    }

    private var topEmergence: RadarCollision? {
        poller.radarEmergence.max { lhs, rhs in
            lhs.density < rhs.density
        }
    }

    private var topGapCandidate: RadarDiscoveryCandidate? {
        poller.radarDiscoveryCandidates.min { lhs, rhs in
            let leftRank = lhs.rank == 0 ? Int.max : lhs.rank
            let rightRank = rhs.rank == 0 ? Int.max : rhs.rank
            if leftRank == rightRank {
                return lhs.candidateScore > rhs.candidateScore
            }
            return leftRank < rightRank
        }
    }

    private var topCollisionSummary: String? {
        guard let collision = topCollision else { return nil }
        let sources = collision.sources.prefix(2).joined(separator: ", ")
        let headline = collision.signalTitles.first ?? "signal overlap"
        return "\(headline) is colliding across \(sources.isEmpty ? "multiple sources" : sources) with density \(format(collision.density))."
    }

    private var topEmergenceSummary: String? {
        guard let emergence = topEmergence else { return nil }
        let cell = emergence.cellIds.first ?? "unmapped cell"
        return "The strongest emergence is centered on \(cell) with density \(format(emergence.density))."
    }

    private var pendingGapCount: Int {
        max(
            poller.pendingProposals.filter(\.isGapDiscovery).count,
            poller.gapProposals.filter(\.isPending).count
        )
    }

    private var approvedCount: Int {
        poller.decidedProposals.filter(\.isApproved).count
    }

    private var deniedCount: Int {
        poller.decidedProposals.filter(\.isDenied).count
    }

    private var governanceStateLabel: String {
        if killSwitchActive { return "STOP" }
        if budgetHardStop { return "HARD STOP" }
        if pendingApprovalCount > 0 { return "REVIEW" }
        return "STEADY"
    }

    private var governanceTint: Color {
        if killSwitchActive { return .red }
        if budgetHardStop { return .orange }
        if pendingApprovalCount > 0 { return .orange }
        return .green
    }

    private var governanceStateDetail: String {
        if killSwitchActive {
            return "The kernel kill switch is active. Jeeves remains a cockpit only until openclashd-v2 clears execution."
        }
        if budgetHardStop {
            return "Budget policy is at hard stop. Approval can still be inspected, but execution must remain blocked."
        }
        if pendingApprovalCount > 0 {
            let cycle = poller.conductorState?.cycleStage ?? "review"
            return "\(pendingApprovalCount) proposal\(pendingApprovalCount == 1 ? "" : "s") are waiting in the governed queue. Current cycle: \(cycle)."
        }
        return "No approvals are waiting. openclashd-v2 is steady and Jeeves is observing only."
    }

    private var recentBoundedActions: [ActionSummary] {
        let actions = poller.decidedProposals.compactMap(\.action)
        if !actions.isEmpty {
            return Array(actions.sorted(by: compareActions).prefix(3))
        }
        if let fallback = poller.lastActionReceipt {
            return [fallback]
        }
        return []
    }

    private var recentReceipts: [ActionReceipt] {
        Array(recentBoundedActions.compactMap(\.receipt).prefix(3))
    }

    private var recentKnowledge: [KnowledgeObject] {
        Array(poller.recentKnowledgeObjects.prefix(3))
    }

    private var mostRecentKnowledgeObject: KnowledgeObject? {
        poller.recentKnowledgeObjects.max { lhs, rhs in
            (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
        }
    }

    private var recentDiscoveries: [RadarDiscoveryCandidate] {
        Array(poller.radarDiscoveryCandidates.prefix(3))
    }

    private var discoveryCandidates: [RadarDiscoveryCandidate] {
        Array(poller.radarDiscoveryCandidates.prefix(3))
    }

    private var researchEvidence: [KnowledgeObject] {
        Array(
            poller.recentKnowledgeObjects
                .filter { ["evidence", "discovery", "investigation_outcome"].contains($0.kind) }
                .prefix(2)
        )
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

    private var knowledgeMetric: String {
        "\(knowledgeSignals24h) live"
    }

    private var knowledgeStateLabel: String {
        if knowledgeClusterCount > 0 { return "ACTIVE" }
        if knowledgeSignals24h > 0 || !poller.recentKnowledgeObjects.isEmpty { return "FLOWING" }
        return "QUIET"
    }

    private var knowledgeTint: Color {
        if knowledgeClusterCount > 0 { return .purple }
        if knowledgeSignals24h > 0 || !poller.recentKnowledgeObjects.isEmpty { return .green }
        return .secondary
    }

    private var knowledgeStateDetail: String {
        let topCell = knowledgeSnapshot?.topCubeCells.first ?? "none"
        if let lastScan = knowledgeSnapshot?.lastScanAtIso, !lastScan.isEmpty {
            return "Top cube address: \(topCell). Last scan: \(lastScan). Knowledge remains linked to proposals and receipts."
        }
        if topCell != "none" {
            return "Top cube address: \(topCell). Knowledge remains operator-visible and attributable."
        }
        return "No live knowledge status has been surfaced yet."
    }

    private var connectedChannels: [ChannelInfo] {
        (gateway.currentStatus?.channels ?? []).filter(\.connected)
    }

    private var trustedChannelCount: Int {
        connectedChannels.filter { $0.trust == .trusted }.count
    }

    private var semiTrustedChannelCount: Int {
        connectedChannels.filter { $0.trust == .semi }.count
    }

    private var untrustedChannelCount: Int {
        connectedChannels.filter { $0.trust == .untrusted }.count
    }

    private var trustMetric: String {
        if untrustedChannelCount > 0 {
            return "contain"
        }
        if model.trustSnapshot.isPlaceholder {
            return "partial"
        }
        return "\(model.trustSnapshot.attestationCount) attest."
    }

    private var topPendingProposal: Proposal? {
        poller.pendingProposals.first
    }

    private var primaryAttestation: MissionControlAttestation? {
        model.trustSnapshot.attestations.first
    }

    private var primaryCapabilityStatus: MissionControlCapabilityStatus? {
        model.trustSnapshot.capabilityStatuses.first
    }

    private var discoveryKnowledgeFlowDetail: String {
        if let discovery = topGapCandidate,
           let object = mostRecentKnowledgeObject {
            return "Visible flow: \(discovery.candidateType.replacingOccurrences(of: "_", with: " ")) -> \(object.kind) -> \(object.title). Jeeves is showing the chain, not producing it."
        }
        if let object = mostRecentKnowledgeObject {
            return "Latest visible flow ends at \(object.title). Awaiting a clearer upstream discovery-to-knowledge linkage."
        }
        if let discovery = topGapCandidate {
            return "Latest visible flow begins with \(discovery.candidateType.replacingOccurrences(of: "_", with: " ")). Knowledge output has not surfaced yet."
        }
        return "No explicit discovery-to-knowledge handoff is visible yet."
    }

    private func gapCandidateBadge(for candidate: RadarDiscoveryCandidate) -> String {
        let rank = candidate.rank > 0 ? "R\(candidate.rank)" : "DISCOVERY"
        let score = candidate.candidateScore > 0 ? " \(format(candidate.candidateScore))" : ""
        return rank + score
    }

    private func proposalPressureBadge(for proposal: Proposal) -> String {
        if let score = proposal.priorityScore, score > 0 {
            return "P\(Int(score))"
        }
        return proposal.intent.risk.uppercased()
    }

    private func recentActionDetail(_ action: ActionSummary) -> String {
        let summary = action.receipt?.resultSummary ?? action.executionState.capitalized
        if let objectCount = action.receipt?.outputObjectIds?.count, objectCount > 0 {
            return "\(summary) Produced \(objectCount) knowledge object\(objectCount == 1 ? "" : "s")."
        }
        return summary
    }

    private var trustStateLabel: String {
        if untrustedChannelCount > 0 { return "CONTAIN" }
        if model.trustSnapshot.isPlaceholder { return "PARTIAL" }
        if model.trustSnapshot.attestationCount > 0 { return "CERTIFIED" }
        return "QUIET"
    }

    private var trustTint: Color {
        if untrustedChannelCount > 0 { return .red }
        if model.trustSnapshot.isPlaceholder { return .orange }
        if model.trustSnapshot.attestationCount > 0 { return .blue }
        return .secondary
    }

    private var trustStateDetail: String {
        if untrustedChannelCount > 0 {
            return "\(untrustedChannelCount) untrusted channel\(untrustedChannelCount == 1 ? "" : "s") are connected. Trust boundaries must stay explicit."
        }
        if !connectedChannels.isEmpty {
            return "Connected channels: \(trustedChannelCount) trusted, \(semiTrustedChannelCount) semi-trusted, \(untrustedChannelCount) untrusted. SafeClash remains read-only."
        }
        return model.trustSnapshot.operatorNote ?? "SafeClash trust data is not available yet."
    }

    private var operatorFocusLine: String {
        if killSwitchActive {
            return "Operator focus: the kernel is stopped. Review why before reopening the governed loop."
        }
        if pendingApprovalCount > 0 {
            return "Operator focus: review \(pendingApprovalCount) pending proposal\(pendingApprovalCount == 1 ? "" : "s") before they turn into backlog."
        }
        if gapCandidateCount > 0 {
            return "Operator focus: discovery is heating up. Decide whether the strongest candidates deserve governed review."
        }
        if model.trustSnapshot.isPlaceholder {
            return "Operator focus: trust data is partial. SafeClash proofs are not fully surfaced yet."
        }
        return "Operator focus: the governed loop is calm and all authority boundaries remain intact."
    }

    private var systemStatusCard: some View {
        MissionControlSystemStatusCard(
            healthLabel: systemHealthLabel,
            healthTint: systemHealthTint,
            summary: operatorFocusLine,
            metrics: [
                .init(label: "Refresh", value: refreshStatusLabel, tint: .blue),
                .init(label: "Pending", value: "\(pendingApprovalCount)", tint: .orange),
                .init(label: "Trust", value: trustMetric.uppercased(), tint: trustTint)
            ]
        )
    }

    private var systemLoopSnapshot: MissionControlSystemLoopSnapshot {
        MissionControlViewModel.systemLoopSnapshot(poller: poller, gateway: gateway)
    }

    private var stageCards: [MissionControlCompactStageModel] {
        [
            MissionControlCompactStageModel(
                stage: .discovery,
                title: "Discovery",
                status: discoveryStateLabel,
                primaryMetric: "\(discoveryMetric)",
                accent: discoveryTint,
                summary: topDiscoverySignal.map {
                    "\($0.title) · \($0.source)"
                } ?? "No strong discovery pressure visible.",
                metrics: [
                    .init(label: "Collisions", value: "\(collisionCount)", tint: .cyan),
                    .init(label: "Emergence", value: "\(emergenceCount)", tint: .purple),
                    .init(label: "Gaps", value: "\(gapCandidateCount)", tint: .orange)
                ]
            ),
            MissionControlCompactStageModel(
                stage: .proposal,
                title: "Proposal",
                status: proposalQueueCount > 0 ? "QUEUE" : "CLEAR",
                primaryMetric: "\(proposalQueueCount)",
                accent: .blue,
                summary: topPendingProposal?.title ?? "No proposal queue pressure.",
                metrics: [
                    .init(label: "Gap", value: "\(pendingGapCount)", tint: .orange),
                    .init(label: "Decided", value: "\(poller.decidedProposals.count)", tint: .green),
                    .init(label: "Cycle", value: compactCycleLabel, tint: .blue)
                ]
            ),
            MissionControlCompactStageModel(
                stage: .approval,
                title: "Approval",
                status: pendingApprovalCount > 0 ? "REVIEW" : "STEADY",
                primaryMetric: "\(pendingApprovalCount)",
                accent: .orange,
                summary: pendingApprovalCount > 0
                    ? "Operator review required in governed queue."
                    : "No approval backlog visible.",
                metrics: [
                    .init(label: "Approved", value: "\(approvedCount)", tint: .green),
                    .init(label: "Denied", value: "\(deniedCount)", tint: .red),
                    .init(label: "Risk", value: killSwitchActive ? "STOP" : (budgetHardStop ? "HARD" : "OK"), tint: governanceTint)
                ]
            ),
            MissionControlCompactStageModel(
                stage: .action,
                title: "Action",
                status: runningActionCount > 0 ? "RUNNING" : (recentBoundedActions.isEmpty ? "QUIET" : "LAST"),
                primaryMetric: "\(max(runningActionCount, recentReceipts.count))",
                accent: .jeevesGold,
                summary: recentBoundedActions.first.map {
                    $0.actionKind.replacingOccurrences(of: "_", with: " ").capitalized
                } ?? "No recent bounded action surfaced.",
                metrics: [
                    .init(label: "Running", value: "\(runningActionCount)", tint: .jeevesGold),
                    .init(label: "Receipts", value: "\(recentReceipts.count)", tint: .green),
                    .init(label: "Failed", value: "\(failedActionCount)", tint: .red)
                ]
            ),
            MissionControlCompactStageModel(
                stage: .knowledge,
                title: "Knowledge",
                status: knowledgeStateLabel,
                primaryMetric: "\(knowledgeSignals24h)",
                accent: knowledgeTint,
                summary: mostRecentKnowledgeObject?.title ?? "Awaiting fresh governed knowledge.",
                metrics: [
                    .init(label: "Clusters", value: "\(knowledgeClusterCount)", tint: .purple),
                    .init(label: "Fresh", value: "\(poller.recentKnowledgeObjects.count)", tint: .blue),
                    .init(label: "Top cell", value: compactTopKnowledgeCell, tint: .green)
                ]
            )
        ]
    }

    private var systemHealthLabel: String {
        if killSwitchActive { return "STOPPED" }
        if poller.isDegraded { return "DEGRADED" }
        if !gateway.isConnected { return "OFFLINE" }
        if model.trustSnapshot.isPlaceholder { return "PARTIAL" }
        if pendingApprovalCount > 0 { return "ATTENTION" }
        return "HEALTHY"
    }

    private var systemHealthTint: Color {
        if killSwitchActive { return .red }
        if poller.isDegraded || !gateway.isConnected { return .orange }
        if model.trustSnapshot.isPlaceholder { return .blue }
        if pendingApprovalCount > 0 { return .orange }
        return .green
    }

    private var refreshStatusLabel: String {
        guard let date = poller.lastSuccessfulRefreshAt else { return "WAIT" }
        return Self.relativeFormatter.localizedString(for: date, relativeTo: Date()).uppercased()
    }

    private var proposalQueueCount: Int {
        max(poller.proposals.count, poller.pendingProposals.count + poller.decidedProposals.count)
    }

    private var compactCycleLabel: String {
        (poller.conductorState?.cycleStage ?? "steady").uppercased()
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

    private var compactTopKnowledgeCell: String {
        knowledgeSnapshot?.topCubeCells.first?.uppercased() ?? "--"
    }

    private var surfaceStates: [MissionControlCommandDeck.Surface] {
        [
            .init(title: "Discovery", value: discoveryStateLabel, tint: discoveryTint),
            .init(title: "Governance", value: governanceStateLabel, tint: governanceTint),
            .init(title: "Knowledge", value: knowledgeStateLabel, tint: knowledgeTint),
            .init(title: "Trust", value: trustStateLabel, tint: trustTint)
        ]
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

    private func columns(for width: CGFloat) -> [GridItem] {
        if width >= 900 {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
        return [GridItem(.flexible())]
    }

    private func compareActions(lhs: ActionSummary, rhs: ActionSummary) -> Bool {
        receiptDate(for: lhs) > receiptDate(for: rhs)
    }

    private func receiptDate(for action: ActionSummary) -> Date {
        guard let iso = action.receipt?.completedAtIso else { return .distantPast }
        return ISO8601DateFormatter().date(from: iso) ?? .distantPast
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func color(forKnowledgeKind kind: String) -> Color {
        switch kind {
        case "evidence":
            return .blue
        case "discovery":
            return .purple
        case "action_receipt":
            return .green
        default:
            return .secondary
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

private struct MissionControlCompactStageModel: Identifiable {
    struct Metric: Identifiable {
        let id: String
        let label: String
        let value: String
        let tint: Color

        init(label: String, value: String, tint: Color) {
            self.id = label
            self.label = label
            self.value = value
            self.tint = tint
        }
    }

    let stage: MissionControlSystemLoopSnapshot.Stage
    let title: String
    let status: String
    let primaryMetric: String
    let accent: Color
    let summary: String
    let metrics: [Metric]

    var id: MissionControlSystemLoopSnapshot.Stage { stage }
}

private struct MissionControlSystemStatusCard: View {
    let healthLabel: String
    let healthTint: Color
    let summary: String
    let metrics: [MissionControlCompactStageModel.Metric]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SYSTEM STATUS")
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(healthTint)
                    Text("Mission Control")
                        .font(.jeevesHeadline)
                }

                Spacer(minLength: 8)

                Text(healthLabel)
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(healthTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(healthTint.opacity(0.10))
                    )
            }

            Text(summary)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            MissionControlCompactMetricRow(metrics: metrics)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(healthTint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct MissionControlCompactStageCard: View {
    let card: MissionControlCompactStageModel
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title.uppercased())
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(card.accent)
                    Text(card.primaryMetric)
                        .font(.jeevesMetric)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Text(isActive ? "ACTIVE" : card.status)
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(isActive ? .white : card.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isActive ? card.accent : card.accent.opacity(0.10))
                    )
            }

            Text(card.summary)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            MissionControlCompactMetricRow(metrics: card.metrics)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(card.accent.opacity(isActive ? 0.30 : 0.12), lineWidth: 1)
        )
    }
}

private struct MissionControlCompactMetricRow: View {
    let metrics: [MissionControlCompactStageModel.Metric]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(metrics.prefix(3)) { metric in
                metricPill(metric)
            }
        }
    }

    private func metricPill(_ metric: MissionControlCompactStageModel.Metric) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.label.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(metric.value)
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(metric.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(metric.tint.opacity(0.08))
        )
    }
}

private struct MissionControlCommandDeck: View {
    struct Surface: Identifiable {
        let id: String
        let title: String
        let value: String
        let tint: Color

        init(title: String, value: String, tint: Color) {
            self.id = title
            self.title = title
            self.value = value
            self.tint = tint
        }
    }

    let loopLine: String
    let focusLine: String
    let surfaces: [Surface]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Governed loop".uppercased())
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(Color.white.opacity(0.64))
                Text(loopLine)
                    .font(.jeevesHeadline)
                    .foregroundStyle(.white)
                Text(focusLine)
                    .font(.jeevesCaption)
                    .foregroundStyle(Color.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits {
                HStack(spacing: 12) {
                    ForEach(surfaces) { surface in
                        surfaceCard(surface)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(surfaces) { surface in
                        surfaceCard(surface)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.10, blue: 0.16),
                            Color(red: 0.11, green: 0.14, blue: 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, y: 10)
    }

    private func surfaceCard(_ surface: Surface) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(surface.title)
                .font(.jeevesCaption)
                .foregroundStyle(Color.white.opacity(0.58))
            Text(surface.value)
                .font(.jeevesHeadline)
                .foregroundStyle(surface.tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct MissionControlMiniMetricRow: View {
    struct Item: Identifiable {
        let id: String
        let label: String
        let value: String
        let tint: Color

        init(label: String, value: String, tint: Color) {
            self.id = label
            self.label = label
            self.value = value
            self.tint = tint
        }
    }

    let items: [Item]

    var body: some View {
        ViewThatFits {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    card(for: item)
                }
            }

            VStack(spacing: 10) {
                ForEach(items) { item in
                    card(for: item)
                }
            }
        }
    }

    private func card(for item: Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.label)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)

            Text(item.value)
                .font(.jeevesHeadline)
                .foregroundStyle(item.tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.55))
        )
    }
}

private struct MissionControlFeatureRow: View {
    let title: String
    let detail: String
    let tint: Color
    var badge: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.jeevesHeadline)

                Spacer(minLength: 8)

                if let badge, !badge.isEmpty {
                    Text(badge)
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(tint)
                }
            }

            Text(detail)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct MissionControlDiscoveryCubeView: View {
    let cube: MissionControlDiscoveryCube
    let topSignal: RadarTopSignal?
    let selectedCellIndex: Int?
    let onSelectCell: (MissionControlCubeCellState) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            planes
            legend
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.12, blue: 0.17),
                            Color(red: 0.10, green: 0.16, blue: 0.22),
                            Color(red: 0.17, green: 0.14, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.14), radius: 18, y: 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CLASHD27 cube".uppercased())
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(Color.cyan.opacity(0.88))
                    Text(cube.topZoneSummary)
                        .font(.jeevesHeadline)
                        .foregroundStyle(.white)
                    Text(cube.topZoneDetail)
                        .font(.jeevesCaption)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Select a cell to inspect why it matters.")
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(Color.white.opacity(0.46))
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Active cells")
                        .font(.jeevesCaption)
                        .foregroundStyle(Color.white.opacity(0.62))
                    Text("\(cube.activeCellCount)")
                        .font(.jeevesMetric)
                        .foregroundStyle(.white)
                }
            }

            if cube.isPlaceholder {
                MissionControlReadOnlyBadge(
                    title: "Derived placement",
                    detail: "The cube is using stable fallback placement for partial radar data. CLASHD27 remains the discovery authority."
                )
            } else if let topSignal {
                MissionControlReadOnlyBadge(
                    title: "Top signal feed",
                    detail: "\(topSignal.source) is shaping the live discovery picture. Jeeves remains read-only."
                )
            }
        }
    }

    private var planes: some View {
        VStack(spacing: 12) {
            ForEach(Array(cube.planes.enumerated()), id: \.element.id) { offset, plane in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(plane.title)
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(Color.white.opacity(0.58))
                        Spacer()
                        Text(planeSummary(for: plane))
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(plane.cells.contains(where: \.isTopCell) ? Color.orange.opacity(0.92) : Color.white.opacity(0.45))
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(plane.cells) { cell in
                            MissionControlCubeTile(
                                cell: cell,
                                isSelected: selectedCellIndex == cell.index,
                                onSelect: {
                                    onSelectCell(cell)
                                }
                            )
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.04 + (Double(offset) * 0.02)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signal legend")
                .font(.jeevesMonoSmall)
                .foregroundStyle(Color.white.opacity(0.54))

            ViewThatFits {
                HStack(spacing: 8) {
                    legendPill(label: "C", detail: "collision", color: .cyan)
                    legendPill(label: "E", detail: "emergence", color: .purple)
                    legendPill(label: "G", detail: "gravity", color: .yellow)
                    legendPill(label: "R", detail: "residue", color: .blue)
                    legendPill(label: "Gap", detail: "candidate", color: .orange)
                }

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        legendPill(label: "C", detail: "collision", color: .cyan)
                        legendPill(label: "E", detail: "emergence", color: .purple)
                        legendPill(label: "G", detail: "gravity", color: .yellow)
                    }
                    HStack(spacing: 8) {
                        legendPill(label: "R", detail: "residue", color: .blue)
                        legendPill(label: "Gap", detail: "candidate", color: .orange)
                    }
                }
            }
        }
    }

    private func planeSummary(for plane: MissionControlCubePlane) -> String {
        if let topCell = plane.cells.first(where: \.isTopCell) {
            return "Top zone \(topCell.coordinateLabel)"
        }
        let activeCount = plane.cells.filter(\.isActive).count
        return activeCount == 0 ? "Quiet" : "\(activeCount) active"
    }

    private func legendPill(label: String, detail: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.jeevesMonoSmall)
                .foregroundStyle(color)
            Text(detail)
                .font(.jeevesCaption)
                .foregroundStyle(Color.white.opacity(0.66))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(color.opacity(0.22), lineWidth: 1)
                )
        )
    }
}

private struct MissionControlCubeTile: View {
    let cell: MissionControlCubeCellState
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(cell.coordinateLabel)
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(.white.opacity(0.88))

                    Spacer(minLength: 4)

                    if isSelected {
                        Text("VIEW")
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(Color.white.opacity(0.92))
                    } else if cell.isTopCell {
                        Text("TOP")
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(Color.orange.opacity(0.95))
                    } else if cell.gapFocusRank != nil {
                        Text("R\(cell.gapFocusRank ?? 0)")
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(Color.orange.opacity(0.9))
                    }
                }

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 5)
                    .overlay(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(tileAccent)
                            .frame(width: max(10, 64 * cell.pressure), height: 5)
                    }

                HStack(spacing: 5) {
                    signalBadge("C", active: cell.hasCollision, color: .cyan)
                    signalBadge("E", active: cell.hasEmergence, color: .purple)
                    signalBadge("G", active: cell.hasGravity, color: .yellow)
                    signalBadge("R", active: cell.hasResidue, color: .blue)
                    signalBadge("Gap", active: cell.hasGapFocus, color: .orange)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(metricText)
                        .font(.jeevesCaption)
                        .foregroundStyle(.white.opacity(cell.isActive ? 0.84 : 0.42))

                    Spacer(minLength: 6)

                    if cell.sourceCount > 0 {
                        Text("\(cell.sourceCount)s")
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(.white.opacity(0.46))
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(tileBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tileStroke, lineWidth: isSelected || cell.isTopCell ? 1.5 : 1)
            )
            .shadow(color: isSelected ? Color.white.opacity(0.16) : (cell.isTopCell ? tileAccent.opacity(0.28) : .clear), radius: 10)
        }
        .buttonStyle(.plain)
    }

    private var metricText: String {
        if cell.hasGapFocus {
            return "gap \(cell.gapCandidateCount)"
        }
        if cell.hasGravity {
            return "g \(String(format: "%.2f", cell.gravityScore))"
        }
        if cell.hasResidue {
            return "r \(String(format: "%.2f", cell.residue))"
        }
        if cell.hasCollision || cell.hasEmergence {
            return "\(cell.collisionCount + cell.emergenceCount) event"
        }
        return "standby"
    }

    private var tileAccent: Color {
        if cell.hasGapFocus { return .orange }
        if cell.hasEmergence { return .purple }
        if cell.hasCollision { return .cyan }
        if cell.hasGravity { return .yellow }
        if cell.hasResidue { return .blue }
        return .white.opacity(0.2)
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tileAccent.opacity(isSelected ? 0.34 : (cell.isActive ? 0.26 : 0.08)),
                        Color.white.opacity(isSelected || cell.isTopCell ? 0.12 : 0.03),
                        Color.black.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var tileStroke: Color {
        if isSelected {
            return Color.white.opacity(0.88)
        }
        if cell.isTopCell {
            return tileAccent.opacity(0.9)
        }
        if cell.isActive {
            return tileAccent.opacity(0.36)
        }
        return Color.white.opacity(0.08)
    }

    private func signalBadge(_ label: String, active: Bool, color: Color) -> some View {
        Text(label)
            .font(.jeevesMonoSmall)
            .foregroundStyle(active ? color : Color.white.opacity(0.24))
            .padding(.horizontal, label.count > 1 ? 6 : 5)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(active ? color.opacity(0.18) : Color.white.opacity(0.05))
            )
    }
}

private struct MissionControlCubeCellDetailView: View {
    let detail: MissionControlCubeCellDetailState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            MissionControlMiniMetricRow(items: [
                .init(label: "Cell", value: detail.cellId, tint: .cyan),
                .init(label: "Plane", value: detail.planeLabel, tint: .blue),
                .init(label: "Layer", value: detail.layerLabel, tint: .secondary),
                .init(
                    label: "Governance",
                    value: detail.hasGovernanceFollowUp ? "linked" : "none",
                    tint: detail.hasGovernanceFollowUp ? .orange : .secondary
                )
            ])

            MissionControlSummaryStrip(items: [
                .init(label: "Collision", detail: detail.collisionSummary, tint: .cyan),
                .init(label: "Emergence", detail: detail.emergenceSummary, tint: .purple),
                .init(label: "Gravity", detail: detail.gravitySummary, tint: .yellow),
                .init(label: "Residue", detail: detail.residueSummary, tint: .blue)
            ])

            MissionControlFeatureRow(
                title: detail.topGapCandidateTitle,
                detail: detail.topGapCandidateDetail + " " + detail.topDiscoverySignalSummary + " " + detail.confidenceSummary + " " + detail.prioritySummary,
                tint: detail.cell.hasGapFocus ? .orange : .cyan,
                badge: detail.attentionBand
            )

            MissionControlFeatureRow(
                title: "Evidence posture",
                detail: detail.evidencePosture + " " + detail.representationSummary,
                tint: .green
            )

            if detail.evidenceItems.isEmpty {
                MissionControlPlaceholderRow(
                    title: "Linked knowledge / evidence",
                    detail: "No cell-linked knowledge objects are visible yet."
                )
            } else {
                ForEach(detail.evidenceItems) { item in
                    MissionControlFeatureRow(
                        title: item.title,
                        detail: item.summary,
                        tint: color(for: item.kind),
                        badge: item.kind
                    )
                }
            }

            MissionControlFeatureRow(
                title: "Operator guidance",
                detail: detail.operatorGuidance + " " + detail.governanceSummary,
                tint: detail.hasGovernanceFollowUp ? .orange : .blue,
                badge: detail.attentionBand
            )

            MissionControlReadOnlyBadge(
                title: "Inspection only",
                detail: "This cell detail surface explains why the discovery zone matters. It does not add approval or execution controls to Jeeves."
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.cyan.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cell inspection".uppercased())
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(.cyan)
                Text("\(detail.cellId) · \(detail.label)")
                    .font(.jeevesHeadline)
                Text("\(detail.planeLabel) · \(detail.layerLabel)")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(detail.attentionBand)
                .font(.jeevesMonoSmall)
                .foregroundStyle(detail.hasGovernanceFollowUp ? .orange : .blue)
        }
    }

    private func color(for kind: String) -> Color {
        switch kind.lowercased() {
        case "evidence":
            return .blue
        case "discovery":
            return .purple
        case "action_receipt":
            return .green
        default:
            return .secondary
        }
    }
}

private struct MissionControlSpotlightCard: View {
    let eyebrow: String
    let title: String
    let detail: String
    let tint: Color
    let badge: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(tint)

                Spacer(minLength: 8)

                Text(badge)
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.jeevesHeadline)

            Text(detail)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.68))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                )
        )
    }
}

private struct MissionControlSummaryStrip: View {
    struct Item: Identifiable {
        let id: String
        let label: String
        let detail: String
        let tint: Color

        init(label: String, detail: String, tint: Color) {
            self.id = label
            self.label = label
            self.detail = detail
            self.tint = tint
        }
    }

    let items: [Item]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(item.tint)
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.label)
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(item.tint)
                        Text(item.detail)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.42))
                )
            }
        }
    }
}

private struct MissionControlFlowCard: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Circle()
                    .fill(.purple)
                    .frame(width: 9, height: 9)
                Rectangle()
                    .fill(Color.purple.opacity(0.28))
                    .frame(width: 2, height: 18)
                Circle()
                    .fill(tint)
                    .frame(width: 9, height: 9)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.jeevesHeadline)
                Text(detail)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.48))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

private struct MissionControlReadOnlyBadge: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(.blue)
            Text(detail)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.blue.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.blue.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct MissionControlPlaceholderRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.jeevesHeadline)
            Text(detail)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.36))
        )
    }
}
