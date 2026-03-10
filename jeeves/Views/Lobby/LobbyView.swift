import SwiftUI

struct LobbyView: View {
    private enum MissionZone {
        case system
        case radar
        case incomingTools
        case aiBrowser
        case marketplace
        case deployments
        case decisions
        case knowledge

        var title: String {
            switch self {
            case .system: return "SYSTEM"
            case .radar: return "RADAR"
            case .incomingTools: return "INCOMING TOOLS"
            case .aiBrowser: return "AI BROWSER"
            case .marketplace: return "MARKETPLACE"
            case .deployments: return "DEPLOYMENTS"
            case .decisions: return "DECISIONS"
            case .knowledge: return "KNOWLEDGE"
            }
        }

        var subtitle: String {
            switch self {
            case .system: return "Terminal telemetry"
            case .radar: return "Radar — Emerging Signals"
            case .incomingTools: return "Forensic intake workbench"
            case .aiBrowser: return "Intention catalog — certified + emerging"
            case .marketplace: return "Featured shelf + category browse"
            case .deployments: return "Proposal-to-knowledge deployment trail"
            case .decisions: return "Governed approvals"
            case .knowledge: return "Resulting knowledge"
            }
        }

        var tint: Color {
            switch self {
            case .system: return .blue
            case .radar: return .cyan
            case .incomingTools: return .cyan
            case .aiBrowser: return .blue
            case .marketplace: return .cyan
            case .deployments: return .consentGreen
            case .decisions: return .jeevesGold
            case .knowledge: return .consentGreen
            }
        }

        var icon: String {
            switch self {
            case .system: return "terminal"
            case .radar: return "dot.radiowaves.left.and.right"
            case .incomingTools: return "shippingbox"
            case .aiBrowser: return "magnifyingglass.circle"
            case .marketplace: return "storefront"
            case .deployments: return "shippingbox.circle"
            case .decisions: return "checkmark.shield"
            case .knowledge: return "book.closed"
            }
        }

        var anchorId: String {
            switch self {
            case .system: return "zone-system"
            case .radar: return "zone-radar"
            case .incomingTools: return "zone-incoming-tools"
            case .aiBrowser: return "zone-ai-browser"
            case .marketplace: return "zone-marketplace"
            case .deployments: return "zone-deployments"
            case .decisions: return "zone-decisions"
            case .knowledge: return "zone-knowledge"
            }
        }
    }

    private enum TriageBucket: CaseIterable, Hashable {
        case critical
        case high
        case normal
        case low

        var title: String {
            switch self {
            case .critical: return "CRITICAL"
            case .high: return "HIGH"
            case .normal: return "NORMAL"
            case .low: return "LOW"
            }
        }

        var tint: Color {
            switch self {
            case .critical: return .consentRed
            case .high: return .consentOrange
            case .normal: return .blue
            case .low: return .secondary
            }
        }

        var icon: String {
            switch self {
            case .critical: return "exclamationmark.octagon.fill"
            case .high: return "exclamationmark.triangle.fill"
            case .normal: return "circle.hexagongrid.fill"
            case .low: return "line.3.horizontal.decrease.circle"
            }
        }
    }

    private enum BrowserCategory: String, CaseIterable, Identifiable {
        case financial
        case legal
        case research
        case education
        case operations
        case security

        var id: String { rawValue }

        var title: String {
            switch self {
            case .financial: return "Financial"
            case .legal: return "Legal"
            case .research: return "Research"
            case .education: return "Education"
            case .operations: return "Operations"
            case .security: return "Security"
            }
        }

        var domain: String { rawValue }

        var icon: String {
            switch self {
            case .financial: return "chart.line.uptrend.xyaxis"
            case .legal: return "scroll"
            case .research: return "atom"
            case .education: return "graduationcap"
            case .operations: return "gearshape.2"
            case .security: return "lock.shield"
            }
        }

        var defaultRisk: String {
            switch self {
            case .financial, .legal, .education:
                return "low"
            case .research, .operations:
                return "medium"
            case .security:
                return "high"
            }
        }

        var subdomains: [String] {
            switch self {
            case .financial:
                return ["investing", "payments", "treasury"]
            case .legal:
                return ["contracts", "compliance", "policy"]
            case .research:
                return ["literature", "benchmarking", "hypothesis"]
            case .education:
                return ["tutoring", "curriculum", "assessment"]
            case .operations:
                return ["workflow", "automation", "planning"]
            case .security:
                return ["threat-detection", "identity", "incident-response"]
            }
        }
    }

    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @State private var showOrangeConfirm = false
    @State private var pendingDecision: (proposalId: String, decision: String)?
    @State private var decidingProposalId: String?
    @State private var decisionErrorMessage: String?
    @State private var showDecisionError = false
    @State private var showActionReceipt = false
    @State private var selectedDecision: DecidedProposal?
    @State private var selectedKnowledgeObjectId: String?
    @State private var knowledgeGraphData: KnowledgeGraphResponse?
    @State private var showKnowledgeGraph = false
    @State private var loadingKnowledgeGraph = false
    @State private var selectedRadarSignal: RadarSignalSummary?
    @State private var selectedIncomingTool: IncomingToolSummary?
    @State private var incomingToolActionInFlightId: String?
    @State private var incomingToolActionErrorMessage: String?
    @State private var showIncomingToolActionError = false
    @State private var incomingToolStatusMessage: String?
    @State private var browserDomain = "financial"
    @State private var browserSubdomain = "investing"
    @State private var browserRiskProfile = "low"
    @State private var selectedBrowserCategory: BrowserCategory = .financial
    @State private var selectedBrowserSubdomain = "investing"
    @State private var showBrowserAdvancedFilters = false
    @State private var browserConstraintsRaw = ""
    @State private var browserFeed: SafeClashBrowserFeed?
    @State private var selectedFeedCategoryId: String?
    @State private var browserResults: [IntentionProfile] = []
    @State private var browserLoading = false
    @State private var browserHasExecutedQuery = false
    @State private var browserHasPrimedEmergingFeed = false
    @State private var browserGuideModeEnabled = true
    @State private var browserErrorMessage: String?
    @State private var browserStatusMessage: String?
    @State private var selectedBrowserCard: BrowserCard?
    @State private var selectedEmergingIntention: EmergingIntentionProfile?
    @State private var browserEmergingRemote: [EmergingIntentionProfile] = []
    @State private var browserConfigurationCache: [String: AIConfigurationAtom] = [:]
    @State private var browserDeploymentProposalByConfigId: [String: String] = [:]
    @State private var browserConfigurationLoadingId: String?
    @State private var browserDeployingConfigId: String?
    @State private var pendingBrowserDeployment: DeployConfigurationRequest?
    @State private var browserLastCreatedProposalId: String?
    @State private var browserActionErrorMessage: String?
    @State private var showBrowserActionError = false
    @State private var decidingExtensionId: String?
    @State private var loadingManifestExtensionId: String?
    @State private var extensionActionErrorMessage: String?
    @State private var showExtensionActionError = false
    @State private var selectedExtensionManifest: ExtensionManifest?
    @State private var extensionDecisions: [String: ExtensionDecision] = [:]
    @State private var expandedClusterIDs: Set<String> = []
    @State private var shouldScrollToDecisions = false
    @State private var requestedZoneAnchor: String?

    private struct TriageReviewItem: Identifiable {
        enum Kind {
            case proposal
            case extensionProposal
        }

        let id: String
        let kind: Kind
        let title: String
        let summary: String
        let source: String
        let risk: String
        let priority: Double
        let intentKey: String?
        let titleFamily: String
        let linkedCells: [String]
    }

    private struct TriageCluster: Identifiable {
        let id: String
        let bucket: TriageBucket
        let title: String
        let explanation: String
        let sharedPattern: String
        let items: [TriageReviewItem]
        let highestPriority: Double
        let dominantRisk: String
    }

    private enum BrowserDeployActionOrigin {
        case card
        case detail
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            systemZoneSection
                                .id(MissionZone.system.anchorId)
                            radarZoneSection
                                .id(MissionZone.radar.anchorId)
                            incomingToolsZoneSection
                                .id(MissionZone.incomingTools.anchorId)
                            aiBrowserZoneSection
                                .id(MissionZone.aiBrowser.anchorId)
                            marketplaceZoneSection
                                .id(MissionZone.marketplace.anchorId)
                            deploymentsZoneSection
                                .id(MissionZone.deployments.anchorId)
                            decisionsZoneSection
                                .id(MissionZone.decisions.anchorId)
                            knowledgeZoneSection
                                .id(MissionZone.knowledge.anchorId)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                    .onChange(of: shouldScrollToDecisions) { _, requested in
                        guard requested else { return }
                        requestedZoneAnchor = MissionZone.decisions.anchorId
                        shouldScrollToDecisions = false
                    }
                    .onChange(of: requestedZoneAnchor) { _, anchor in
                        guard let anchor else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(anchor, anchor: .top)
                        }
                        requestedZoneAnchor = nil
                    }
                }
            }
            .navigationTitle("Mission Control")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .alert(TextKeys.Lobby.confirmOrange, isPresented: $showOrangeConfirm) {
                Button(TextKeys.Lobby.confirmYes) {
                    if let decision = pendingDecision {
                        executeDecision(proposalId: decision.proposalId, decision: decision.decision)
                    }
                }
                Button(TextKeys.Lobby.confirmNo, role: .cancel) {
                    pendingDecision = nil
                }
            }
            .alert("Actie niet uitgevoerd", isPresented: $showDecisionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(decisionErrorMessage ?? "Onbekende fout.")
            }
            .alert("Extension actie niet uitgevoerd", isPresented: $showExtensionActionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(extensionActionErrorMessage ?? "Onbekende fout.")
            }
            .alert("Incoming Tool actie niet uitgevoerd", isPresented: $showIncomingToolActionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(incomingToolActionErrorMessage ?? "Onbekende fout.")
            }
            .alert("AI Browser actie niet uitgevoerd", isPresented: $showBrowserActionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(browserActionErrorMessage ?? "Onbekende fout.")
            }
            .sheet(isPresented: $showActionReceipt) {
                if let action = poller.lastActionReceipt {
                    ActionReceiptSheet(
                        action: action,
                        linkedKnowledge: poller.lastDecideLinkedKnowledge,
                        onKnowledgeTap: { objectId in
                            showActionReceipt = false
                            fetchAndShowKnowledgeGraph(objectId: objectId)
                        }
                    )
                }
            }
            .sheet(item: $selectedDecision) { decision in
                DecisionDetailSheet(
                    decision: decision,
                    onKnowledgeTap: { objectId in
                        selectedDecision = nil
                        fetchAndShowKnowledgeGraph(objectId: objectId)
                    }
                )
            }
            .sheet(isPresented: $showKnowledgeGraph) {
                KnowledgeGraphSheet(
                    graphData: knowledgeGraphData,
                    isLoading: loadingKnowledgeGraph
                )
            }
            .sheet(item: $selectedRadarSignal) { signal in
                RadarSignalDetailSheet(
                    signal: signal,
                    relatedProposals: relatedExtensionProposals(for: signal),
                    onOpenApprovalCard: { proposal in
                        selectedRadarSignal = nil
                        inspectExtensionManifest(proposal)
                    },
                    onOpenObservatory: {
                        selectedRadarSignal = nil
                        openObservatory()
                    }
                )
            }
            .sheet(item: $selectedIncomingTool) { tool in
                IncomingToolDetailSheet(
                    tool: tool,
                    relatedProposals: relatedExtensionProposals(for: tool),
                    isActionInFlight: incomingToolActionInFlightId == tool.id,
                    onAction: { kind in
                        handleIncomingToolAction(kind, tool: tool)
                    },
                    onOpenApprovalCard: { proposal in
                        selectedIncomingTool = nil
                        inspectExtensionManifest(proposal)
                    }
                )
            }
            .sheet(item: $selectedBrowserCard) { card in
                let resolvedConfiguration = browserConfigurationCache[card.bestConfiguration.configId] ?? card.bestConfiguration
                AIBrowserDetailSheet(
                    card: card,
                    configuration: resolvedConfiguration,
                    lifecycle: browserLifecycle(for: card, configuration: resolvedConfiguration),
                    isLoadingConfiguration: browserConfigurationLoadingId == card.bestConfiguration.configId,
                    isDeploying: browserDeployingConfigId == card.bestConfiguration.configId,
                    onRefreshConfiguration: {
                        fetchBrowserConfiguration(configId: card.bestConfiguration.configId)
                    },
                    onDeploy: {
                        requestBrowserDeployment(for: card, origin: .detail)
                    },
                    onOpenProposal: { proposalId in
                        openLifecycleProposal(proposalId: proposalId)
                    },
                    onOpenDecision: { proposalId in
                        openLifecycleDecision(proposalId: proposalId)
                    },
                    onOpenKnowledgeArtifact: { objectId in
                        openLifecycleKnowledge(objectId: objectId)
                    }
                )
            }
            .sheet(item: $pendingBrowserDeployment) { request in
                BrowserDeployConfirmationSheet(
                    request: request,
                    benchmarkSummary: benchmarkSummary(for: request),
                    constraintsSummary: constraintsSummary(for: request),
                    isCreatingProposal: browserDeployingConfigId == request.configId,
                    onCreateProposal: {
                        pendingBrowserDeployment = nil
                        createGovernedBrowserDeploymentProposal(request: request)
                    }
                )
            }
            .sheet(item: $selectedEmergingIntention) { intention in
                EmergingIntentionDetailSheet(
                    intention: intention,
                    relatedTools: relatedIncomingTools(for: intention),
                    certifiedMatch: certifiedMatch(for: intention),
                    onOpenTool: { tool in
                        selectedEmergingIntention = nil
                        selectedIncomingTool = tool
                    },
                    onOpenCertified: { card in
                        selectedEmergingIntention = nil
                        openBrowserCard(card)
                    }
                )
            }
            .sheet(item: $selectedExtensionManifest) { manifest in
                ExtensionDetailSheet(
                    manifest: manifest,
                    onKnowledgeTap: { objectId in
                        selectedExtensionManifest = nil
                        fetchAndShowKnowledgeGraph(objectId: objectId)
                    },
                    onGraphTap: { extensionId in
                        selectedExtensionManifest = nil
                        fetchAndShowExtensionGraph(extensionId: extensionId)
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private var systemZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader(.system)
            topStatusBar
            browserSurfaceNavigationPanel
        }
    }

    private var radarZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader(.radar)

            if radarSignals.isEmpty {
                radarEmptyCard
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(radarSignals.prefix(5)) { signal in
                        RadarSignalCard(signal: signal) {
                            selectedRadarSignal = signal
                        }
                    }
                }
            }
        }
    }

    private var decisionsZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader(.decisions)
            operatorFocusPanel
            triageSections
            pendingQueueSection
            extensionProposalsSection
        }
    }

    private var incomingToolsZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader(.incomingTools)
            incomingToolsSection
        }
    }

    private var aiBrowserZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader(.aiBrowser)
            aiBrowserSection
        }
        .onAppear {
            syncBrowserCategorySelection()
            primeEmergingIntentionsFeedIfNeeded()
            if !browserHasExecutedQuery {
                runSafeClashSearch()
            }
        }
    }

    private var marketplaceZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader(.marketplace)
            marketplaceOverviewPanel
        }
    }

    private var deploymentsZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader(.deployments)
            deploymentsOverviewPanel
        }
    }

    private var operatorFocusPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Operator Focus")
                .font(.jeevesHeadline.weight(.semibold))
                .foregroundStyle(.white)
            Text("\(attentionNowCount) items need attention")
                .font(.jeevesBody)
                .foregroundStyle(.white)
            Text("\(criticalCount) critical · \(highCount) high")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            Text("\(detectedClusterCount) clusters detected")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
        }
        .controlRoomPanel(padding: 14)
    }

    private var triageSections: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(visibleTriageBuckets, id: \.self) { bucket in
                triageSection(bucket)
            }
        }
    }

    private func triageSection(_ bucket: TriageBucket) -> some View {
        let items = triageGroups[bucket] ?? []
        let clusters = triageClustersByBucket[bucket] ?? []
        let clusteredItemIDs = Set(clusters.flatMap { cluster in
            cluster.items.map(\.id)
        })
        let individualItems = items.filter { !clusteredItemIDs.contains($0.id) }
        let individualPreview = Array(individualItems.prefix(2))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: bucket.icon)
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(bucket.tint)
                Text("\(bucket.title) · \(items.count)")
                    .font(.jeevesMono.weight(.semibold))
                    .foregroundStyle(bucket.tint)
                Spacer()
            }

            if !clusters.isEmpty {
                HStack(spacing: 6) {
                    Text("CLUSTERS · \(clusters.count)")
                        .font(.jeevesCaption.weight(.semibold))
                        .foregroundStyle(bucket.tint)
                    Spacer()
                }
                ForEach(clusters) { cluster in
                    triageClusterCard(cluster: cluster)
                }
            }

            if !individualPreview.isEmpty {
                HStack(spacing: 6) {
                    Text("INDIVIDUAL · \(individualItems.count)")
                        .font(.jeevesCaption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ForEach(individualPreview) { item in
                    triagePreviewCard(item: item, tint: bucket.tint)
                }
            }

            let shown = individualPreview.count + clusters.reduce(0) { $0 + $1.items.count }
            if items.count > shown {
                Text("+\(items.count - shown) more in this priority tier")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .controlRoomPanel(padding: 12)
    }

    private func triageClusterCard(cluster: TriageCluster) -> some View {
        let tint = clusterTint(for: cluster.dominantRisk, fallback: cluster.bucket.tint)
        let isExpanded = expandedClusterIDs.contains(cluster.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cluster.title)
                        .font(.jeevesBody.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(cluster.explanation)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("P\(Int(cluster.highestPriority.rounded()))")
                    .font(.jeevesMono)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(tint.opacity(0.16))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                Text(cluster.sharedPattern)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button(isExpanded ? "Collapse" : "Expand cluster") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedClusterIDs.remove(cluster.id)
                        } else {
                            expandedClusterIDs.insert(cluster.id)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button("Review individually") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        _ = expandedClusterIDs.insert(cluster.id)
                    }
                }
                .buttonStyle(.bordered)
            }

            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(cluster.items) { item in
                        triagePreviewCard(item: item, tint: tint)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background {
            Color.white.opacity(0.04)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint, lineWidth: 1)
                .opacity(0.35)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func triagePreviewCard(item: TriageReviewItem, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title)
                    .font(.jeevesBody.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text("P\(Int(item.priority.rounded()))")
                    .font(.jeevesMono)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(tint.opacity(0.16))
                    .clipShape(Capsule())
            }

            Text(item.summary)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(item.source)
                    .font(.jeevesCaption.weight(.medium))
                    .foregroundStyle(.secondary)
                if let intent = item.intentKey, !intent.isEmpty {
                    Text(intent.replacingOccurrences(of: "_", with: " "))
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
                Text("risk \(item.risk.lowercased())")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint, lineWidth: 1)
                .opacity(0.3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var knowledgeZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            zoneHeader(.knowledge)
            recentDecisionsSection
            knowledgeResultsSection
        }
    }

    private var topStatusBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jeeves")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    Text("Calm AI Mission Control")
                        .font(.jeevesTitle.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                statusChip(
                    label: missionHealth.label,
                    systemImage: missionHealth.systemImage,
                    tint: missionHealth.tint
                )
            }

            HStack(spacing: 8) {
                statusChip(
                    label: "Gateway \(gatewayHealthLabel)",
                    systemImage: gatewayStateSymbol,
                    tint: gatewayStateTint
                )
                statusChip(
                    label: radarTelemetryLabel,
                    systemImage: radarTelemetrySymbol,
                    tint: radarTelemetryTint
                )
                statusChip(
                    label: telemetryDegradedLabel,
                    systemImage: "waveform.path.ecg.rectangle",
                    tint: telemetryDegradedTint
                )
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 120), spacing: 10, alignment: .leading),
                    GridItem(.flexible(minimum: 120), spacing: 10, alignment: .leading)
                ],
                alignment: .leading,
                spacing: 8
            ) {
                terminalTelemetryRow(label: "Queue", value: "\(queueSize)")
                terminalTelemetryRow(label: "Decisions today", value: "\(decisionsToday)")
                terminalTelemetryRow(label: "Last discovery", value: lastDiscoveryLabel)
                terminalTelemetryRow(label: "Last refresh", value: lastRefreshLabel)
            }

            if poller.isDegraded, let message = poller.lastRefreshError {
                Text(message)
                    .font(.jeevesCaption)
                    .foregroundStyle(Color.consentOrange)
                    .lineLimit(2)
            }
        }
        .controlRoomPanel()
    }

    private var missionHealth: (label: String, systemImage: String, tint: Color) {
        if !gateway.isConnected {
            return ("Offline", "antenna.radiowaves.left.and.right.slash", .consentRed)
        }
        if poller.isDegraded {
            return ("Degraded", "exclamationmark.triangle.fill", .consentOrange)
        }
        return ("Healthy", "checkmark.shield.fill", .blue)
    }

    private var gatewayStateLabel: String {
        switch gateway.connectionState {
        case .connected:
            return "Gateway connected"
        case .connecting:
            return "Gateway connecting"
        case .reconnecting:
            return "Gateway reconnecting"
        case .failed:
            return "Gateway failed"
        case .idle, .disconnected:
            return "Gateway idle"
        }
    }

    private var gatewayHealthLabel: String {
        switch gateway.connectionState {
        case .connected:
            return "healthy"
        case .connecting, .reconnecting:
            return "syncing"
        case .failed:
            return "failed"
        case .idle, .disconnected:
            return "offline"
        }
    }

    private var gatewayStateSymbol: String {
        switch gateway.connectionState {
        case .connected:
            return "bolt.horizontal.circle.fill"
        case .connecting, .reconnecting:
            return "dot.radiowaves.left.and.right"
        case .failed:
            return "xmark.octagon.fill"
        case .idle, .disconnected:
            return "wifi.slash"
        }
    }

    private var gatewayStateTint: Color {
        switch gateway.connectionState {
        case .connected:
            return .blue
        case .connecting, .reconnecting:
            return .cyan
        case .failed:
            return .consentRed
        case .idle, .disconnected:
            return .secondary
        }
    }

    private var lastRefreshLabel: String {
        guard let date = poller.lastSuccessfulRefreshAt else {
            return "nog geen succesvolle refresh"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var queueSize: Int {
        poller.pendingProposals.count + pendingExtensionProposals.count
    }

    private var pendingExtensionProposals: [ExtensionProposal] {
        poller.extensionProposals.filter(\.isPending)
    }

    private var decisionsToday: Int {
        let calendar = Calendar.current
        return poller.decidedProposals.filter { decision in
            guard let decidedAt = decision.decidedAt else { return false }
            return calendar.isDateInToday(decidedAt)
        }.count
    }

    private var triageItems: [TriageReviewItem] {
        let proposalItems = poller.pendingProposals.map { proposal in
            TriageReviewItem(
                id: "proposal-\(proposal.proposalId)",
                kind: .proposal,
                title: proposal.title,
                summary: proposal.priorityExplanation ?? proposal.intent.key,
                source: triageSourceLabel(agentId: proposal.agentId),
                risk: proposal.intent.risk,
                priority: triagePriorityScore(rawScore: proposal.priorityScore, risk: proposal.intent.risk),
                intentKey: proposal.intent.key,
                titleFamily: triageTitleFamily(text: proposal.title),
                linkedCells: triageCells(fromText: proposal.title + " " + (proposal.priorityExplanation ?? ""))
            )
        }

        let extensionItems = pendingExtensionProposals.map { proposal in
            TriageReviewItem(
                id: "extension-\(proposal.extensionId)",
                kind: .extensionProposal,
                title: proposal.title,
                summary: proposal.purpose,
                source: triageExtensionSourceLabel(sourceType: proposal.sourceType),
                risk: proposal.risk,
                priority: triagePriorityScore(rawScore: nil, risk: proposal.risk),
                intentKey: proposal.capabilities.first?.key,
                titleFamily: triageTitleFamily(text: proposal.title),
                linkedCells: proposal.linkedCells
            )
        }

        return (proposalItems + extensionItems)
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.title < rhs.title
            }
    }

    private var triageGroups: [TriageBucket: [TriageReviewItem]] {
        Dictionary(grouping: triageItems, by: { triageBucket(for: $0.priority) })
    }

    private var triageClustersByBucket: [TriageBucket: [TriageCluster]] {
        Dictionary(uniqueKeysWithValues: TriageBucket.allCases.map { bucket in
            let items = triageGroups[bucket] ?? []
            return (bucket, clusteredTriageItems(items, bucket: bucket))
        })
    }

    private var visibleTriageBuckets: [TriageBucket] {
        TriageBucket.allCases.filter { !(triageGroups[$0] ?? []).isEmpty }
    }

    private var criticalCount: Int { triageGroups[.critical]?.count ?? 0 }
    private var highCount: Int { triageGroups[.high]?.count ?? 0 }
    private var attentionNowCount: Int { criticalCount + highCount }
    private var detectedClusterCount: Int {
        triageClustersByBucket.values.reduce(0) { $0 + $1.count }
    }

    private var radarTelemetryLabel: String {
        if isMockMode {
            return "Radar demo"
        }
        if let collector = poller.radarStatus?.collector {
            return collector.isRunning ? "Radar live" : "Radar idle"
        }
        if poller.isDegraded {
            return "Radar degraded"
        }
        return gateway.isConnected ? "Radar syncing" : "Radar offline"
    }

    private var radarTelemetrySymbol: String {
        if isMockMode { return "scope" }
        if poller.radarStatus?.collector?.isRunning == true { return "dot.radiowaves.left.and.right" }
        if poller.isDegraded { return "exclamationmark.triangle.fill" }
        return gateway.isConnected ? "clock.arrow.circlepath" : "waveform.path.badge.minus"
    }

    private var radarTelemetryTint: Color {
        if isMockMode { return .jeevesGold }
        if poller.radarStatus?.collector?.isRunning == true { return .cyan }
        if poller.isDegraded { return .consentOrange }
        return gateway.isConnected ? .secondary : .consentRed
    }

    private var telemetryDegradedLabel: String {
        poller.isDegraded ? "Telemetry degraded" : "Telemetry nominal"
    }

    private var telemetryDegradedTint: Color {
        poller.isDegraded ? .consentRed : .blue
    }

    private var lastDiscoveryLabel: String {
        guard let date = lastDiscoveryDate else { return "none" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var lastDiscoveryDate: Date? {
        if let timestamp = poller.streamEvents.first(where: { $0.isDiscoveryCandidate })?.timestampIso,
           let parsed = parseISODate(timestamp) {
            return parsed
        }
        if let collectorLastRun = poller.radarStatus?.collector?.lastRun,
           let parsed = parseISODate(collectorLastRun) {
            return parsed
        }
        return nil
    }

    private var radarSignals: [RadarSignalSummary] {
        if !poller.radarDiscoveryCandidates.isEmpty {
            return poller.radarDiscoveryCandidates.enumerated().map { index, candidate in
                let hotspot = index < poller.radarGravityHotspots.count ? poller.radarGravityHotspots[index] : nil
                let axes = hotspot?.axes ?? candidateAxes(from: candidate.candidateType)
                let cellValues = radarLinkedCells(hotspot: hotspot)
                let summary = candidate.explanation.isEmpty ? (hotspot?.explanation ?? "Signal requires operator review.") : candidate.explanation
                let related = relatedExtensionProposals(
                    what: axes.what,
                    whereValue: axes.whereValue,
                    timeAxis: axes.time,
                    linkedCells: cellValues
                )
                return RadarSignalSummary(
                    id: candidate.candidateId,
                    title: readableSignalTitle(candidateType: candidate.candidateType),
                    what: axes.what,
                    whereValue: axes.whereValue,
                    timeAxis: axes.time,
                    score: candidate.candidateScore,
                    linkedCells: cellValues,
                    explanation: summary,
                    timestampIso: poller.streamEvents.first(where: { $0.candidateId == candidate.candidateId })?.timestampIso,
                    linkedProposalLabel: linkedProposalLabel(for: related)
                )
            }
        }

        return poller.radarGravityHotspots.map { hotspot in
            let related = relatedExtensionProposals(
                what: hotspot.axes.what,
                whereValue: hotspot.axes.whereValue,
                timeAxis: hotspot.axes.time,
                linkedCells: radarLinkedCells(hotspot: hotspot)
            )
            return RadarSignalSummary(
                id: "gravity-\(hotspot.id)",
                title: "gravity hotspot",
                what: hotspot.axes.what,
                whereValue: hotspot.axes.whereValue,
                timeAxis: hotspot.axes.time,
                score: hotspot.gravityScore,
                linkedCells: radarLinkedCells(hotspot: hotspot),
                explanation: hotspot.explanation,
                timestampIso: poller.radarStatus?.collector?.lastRun,
                linkedProposalLabel: linkedProposalLabel(for: related)
            )
        }
    }

    private var radarEmptyCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.jeevesTitle)
                .foregroundStyle(.secondary)
            Text("Nog geen radar signalen van CLASHD27.")
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlRoomPanel()
    }

    private var knowledgeResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Resulting knowledge",
                icon: "book.closed.fill",
                count: poller.recentKnowledgeObjects.count,
                tint: .consentGreen
            )

            if poller.recentKnowledgeObjects.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "book")
                        .font(.jeevesTitle)
                        .foregroundStyle(.secondary)
                    Text("Nog geen kennisobjecten.")
                        .font(.jeevesBody)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .controlRoomPanel()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(poller.recentKnowledgeObjects) { object in
                        let lifecycle = lifecycleFromKnowledgeObject(object)
                        KnowledgeResultCard(
                            object: object,
                            createdLabel: formatKnowledgeTimestamp(object.createdAt),
                            proposalOrigin: proposalOrigin(for: object),
                            producer: producerLabel(for: object),
                            lifecycle: lifecycle,
                            onOpenProposal: { proposalId in
                                openLifecycleProposal(proposalId: proposalId)
                            },
                            onOpenDecision: { proposalId in
                                openLifecycleDecision(proposalId: proposalId)
                            },
                            onOpenKnowledgeArtifact: { objectId in
                                openLifecycleKnowledge(objectId: objectId)
                            }
                        ) {
                            fetchAndShowKnowledgeGraph(objectId: object.objectId)
                        }
                    }
                }
            }
        }
    }

    private func zoneHeader(_ zone: MissionZone) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: zone.icon)
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(zone.tint)
                Text(zone.title)
                    .font(.jeevesMono.weight(.semibold))
                    .foregroundStyle(zone.tint)
                    .tracking(1.2)
                Spacer()
            }
            Text(zone.subtitle)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(zone.tint.opacity(0.35))
                .frame(height: 1)
        }
    }

    private func linkedProposalLabel(for proposals: [ExtensionProposal]) -> String? {
        guard let first = proposals.first else { return nil }
        let status = first.status.lowercased()
        if status == "pending" || status == "proposed" || status == "review" {
            return "linked proposal pending"
        }
        if status == "approved" {
            return "linked proposal approved"
        }
        if status == "denied" || status == "rejected" {
            return "linked proposal denied"
        }
        return "linked proposal \(status)"
    }

    private func relatedExtensionProposals(
        what: String,
        whereValue: String,
        timeAxis: String,
        linkedCells: [String]
    ) -> [ExtensionProposal] {
        let baseTerms = [what.lowercased(), whereValue.lowercased(), timeAxis.lowercased()]
        let signalCells = linkedCells.map { $0.lowercased() }
        return poller.extensionProposals
            .map { proposal -> (proposal: ExtensionProposal, score: Int) in
                var score = 0
                let purpose = proposal.purpose.lowercased()
                let title = proposal.title.lowercased()
                let trace = proposal.reasoningTrace?.lowercased() ?? ""
                let proposalCells = proposal.linkedCells.map { $0.lowercased() }

                if proposalCells.contains(where: { linked in
                    baseTerms.contains(where: { linked.contains($0) })
                }) {
                    score += 3
                }
                if proposalCells.contains(where: { signalCells.contains($0) }) {
                    score += 2
                }
                if baseTerms.contains(where: { purpose.contains($0) || title.contains($0) || trace.contains($0) }) {
                    score += 1
                }
                return (proposal, score)
            }
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.proposal.title < rhs.proposal.title
            }
            .map(\.proposal)
            .prefix(3)
            .map { $0 }
    }

    private func terminalTelemetryRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.jeevesCaption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func triageBucket(for priority: Double) -> TriageBucket {
        if priority >= 80 { return .critical }
        if priority >= 60 { return .high }
        if priority >= 30 { return .normal }
        return .low
    }

    private func triagePriorityScore(rawScore: Double?, risk: String) -> Double {
        guard var score = rawScore, score > 0 else {
            return fallbackPriorityScore(forRisk: risk)
        }
        if score <= 1 {
            score *= 100
        } else if score <= 10 {
            score *= 10
        }
        return min(max(score, 0), 100)
    }

    private func fallbackPriorityScore(forRisk risk: String) -> Double {
        switch risk.lowercased() {
        case "red":
            return 85
        case "orange":
            return 65
        case "green":
            return 45
        default:
            return 20
        }
    }

    private func triageSourceLabel(agentId: String) -> String {
        let lower = agentId.lowercased()
        if lower.contains("clashd27") || lower.contains("radar") {
            return "CLASHD27"
        }
        if lower.contains("manual") || lower.contains("human") {
            return "MANUAL"
        }
        return "SYSTEM"
    }

    private func triageExtensionSourceLabel(sourceType: String?) -> String {
        let normalized = sourceType?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let normalized, !normalized.isEmpty {
            return normalized
        }
        return "SYSTEM"
    }

    private func clusteredTriageItems(_ items: [TriageReviewItem], bucket: TriageBucket) -> [TriageCluster] {
        let grouped = Dictionary(grouping: items, by: { item in
            clusterGroupingKey(for: item)
        })

        return grouped.compactMap { groupKey, members in
            guard members.count > 1 else { return nil }
            let highest = members.map(\.priority).max() ?? 0
            let dominantRisk = dominantRiskLabel(in: members)
            let template = clusterDisplayTemplate(for: groupKey, sample: members[0])
            return TriageCluster(
                id: "\(bucket.title.lowercased())-\(groupKey)",
                bucket: bucket,
                title: template.title,
                explanation: "\(members.count) similar reviews",
                sharedPattern: template.pattern,
                items: members.sorted { lhs, rhs in
                    if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                    return lhs.title < rhs.title
                },
                highestPriority: highest,
                dominantRisk: dominantRisk
            )
        }
        .sorted { lhs, rhs in
            if lhs.highestPriority != rhs.highestPriority {
                return lhs.highestPriority > rhs.highestPriority
            }
            if lhs.items.count != rhs.items.count {
                return lhs.items.count > rhs.items.count
            }
            return lhs.title < rhs.title
        }
    }

    private func clusterGroupingKey(for item: TriageReviewItem) -> String {
        let source = item.source.lowercased()
        let risk = item.risk.lowercased()
        if let intent = item.intentKey?.lowercased(), !intent.isEmpty {
            return "intent:\(intent)|risk:\(risk)|source:\(source)"
        }
        if !item.titleFamily.isEmpty {
            return "family:\(item.titleFamily)|risk:\(risk)|source:\(source)"
        }
        if !item.linkedCells.isEmpty {
            let cells = item.linkedCells
                .map { $0.lowercased() }
                .sorted()
                .prefix(2)
                .joined(separator: ",")
            return "cells:\(cells)|risk:\(risk)|source:\(source)"
        }
        return "source:\(source)|risk:\(risk)"
    }

    private func clusterDisplayTemplate(for key: String, sample: TriageReviewItem) -> (title: String, pattern: String) {
        if let intent = key.components(separatedBy: "|").first(where: { $0.hasPrefix("intent:") })?
            .replacingOccurrences(of: "intent:", with: "") {
            return (readableClusterIntent(intent), "shared intent · \(sample.risk.uppercased()) risk")
        }
        if let family = key.components(separatedBy: "|").first(where: { $0.hasPrefix("family:") })?
            .replacingOccurrences(of: "family:", with: "") {
            return ("\(family.replacingOccurrences(of: "-", with: " ")) family", "same title/challenge family")
        }
        if let cells = key.components(separatedBy: "|").first(where: { $0.hasPrefix("cells:") })?
            .replacingOccurrences(of: "cells:", with: "") {
            return ("cell corridor \(cells)", "shared related cells")
        }
        return ("\(sample.source.lowercased()) review group", "same source and risk pattern")
    }

    private func readableClusterIntent(_ intent: String) -> String {
        intent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func dominantRiskLabel(in items: [TriageReviewItem]) -> String {
        let counts = Dictionary(grouping: items.map { $0.risk.lowercased() }, by: { $0 }).mapValues(\.count)
        return counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key < rhs.key
        }?.key ?? "unknown"
    }

    private func clusterTint(for risk: String, fallback: Color) -> Color {
        switch risk.lowercased() {
        case "red":
            return .consentRed
        case "orange":
            return .consentOrange
        case "green":
            return .blue
        default:
            return fallback
        }
    }

    private func triageTitleFamily(text: String) -> String {
        let stopwords: Set<String> = [
            "the", "and", "for", "with", "from", "into", "onto", "task", "review",
            "proposal", "extension", "investigate", "analysis", "summary", "signal"
        ]
        let normalized = text.lowercased().replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        let tokens = normalized
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { token in
                token.count >= 3 && !stopwords.contains(token)
            }
        return tokens.prefix(2).joined(separator: "-")
    }

    private func triageCells(fromText text: String) -> [String] {
        let matches = text.matches(of: /(\d{1,3})/)
        let values = matches.map { String($0.1) }
        if values.isEmpty { return [] }
        return Array(Set(values)).sorted().prefix(3).map { $0 }
    }

    private func parseISODate(_ iso: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = isoFormatter.date(from: iso) {
            return parsed
        }
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: iso)
    }

    private func candidateAxes(from value: String) -> RadarAxes {
        let normalized = value.replacingOccurrences(of: "_", with: "-")
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if parts.count == 3 {
            return RadarAxes(what: parts[0], whereValue: parts[1], time: parts[2])
        }
        return RadarAxes(what: normalized, whereValue: "external", time: "emerging")
    }

    private func readableSignalTitle(candidateType: String) -> String {
        let normalized = candidateType
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return "emerging signal"
        }
        return normalized.lowercased()
    }

    private func radarLinkedCells(hotspot: RadarGravityHotspot?) -> [String] {
        if let hotspot {
            var cells = ["\(hotspot.cell)"]
            for candidate in poller.radarGravityHotspots where candidate.cell != hotspot.cell {
                cells.append("\(candidate.cell)")
                if cells.count == 3 { break }
            }
            return cells
        }

        let fallback = poller.radarGravityHotspots.prefix(3).map { "\($0.cell)" }
        return fallback.isEmpty ? ["13", "22", "4"] : fallback
    }

    private func relatedExtensionProposals(for signal: RadarSignalSummary) -> [ExtensionProposal] {
        relatedExtensionProposals(
            what: signal.what,
            whereValue: signal.whereValue,
            timeAxis: signal.timeAxis,
            linkedCells: signal.linkedCells
        )
    }

    private func formatKnowledgeTimestamp(_ date: Date?) -> String {
        guard let date else { return "unknown time" }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func proposalOrigin(for object: KnowledgeObject) -> String {
        if let source = object.sourceRefs?.first(where: {
            $0.sourceType.localizedCaseInsensitiveContains("proposal")
                || $0.sourceId.localizedCaseInsensitiveContains("proposal")
        }) {
            return source.label ?? source.sourceId
        }
        if let linked = object.linkedObjectIds?.first(where: { $0.localizedCaseInsensitiveContains("proposal") }) {
            return linked
        }
        return "system-origin"
    }

    private func producerLabel(for object: KnowledgeObject) -> String {
        if let source = object.sourceRefs?.first(where: {
            $0.sourceType.localizedCaseInsensitiveContains("extension")
                || $0.sourceType.localizedCaseInsensitiveContains("action")
                || $0.sourceType.localizedCaseInsensitiveContains("receipt")
        }) {
            return source.label ?? source.sourceId
        }
        if let linked = object.linkedObjectIds?.first(where: {
            $0.localizedCaseInsensitiveContains("extension")
                || $0.localizedCaseInsensitiveContains("action")
                || $0.localizedCaseInsensitiveContains("receipt")
        }) {
            return linked
        }
        if object.kind.localizedCaseInsensitiveContains("extension") {
            return "extension"
        }
        return "action-pipeline"
    }

    // MARK: - Incoming Tools

    private var incomingToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Incoming Tools",
                icon: "shippingbox.fill",
                count: incomingTools.count,
                tint: .cyan
            )

            if let status = incomingToolStatusMessage, !status.isEmpty {
                Text(status)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }

            if incomingTools.isEmpty {
                incomingToolsEmptyCard
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(incomingTools) { tool in
                        IncomingToolCard(
                            tool: tool,
                            isActionInFlight: incomingToolActionInFlightId == tool.id,
                            onOpen: { selectedIncomingTool = tool },
                            onAction: { kind in
                                handleIncomingToolAction(kind, tool: tool)
                            }
                        )
                    }
                }
            }
        }
    }

    private var incomingTools: [IncomingToolSummary] {
        if !poller.incomingTools.isEmpty {
            return poller.incomingTools.sorted { lhs, rhs in
                let lDate = parseISODate(lhs.discoveredAtIso ?? "") ?? .distantPast
                let rDate = parseISODate(rhs.discoveredAtIso ?? "") ?? .distantPast
                if lDate != rDate { return lDate > rDate }
                if incomingRiskRank(lhs.risk) != incomingRiskRank(rhs.risk) {
                    return incomingRiskRank(lhs.risk) > incomingRiskRank(rhs.risk)
                }
                return lhs.title < rhs.title
            }
        }

        let derived = poller.recentKnowledgeObjects
            .filter(isIncomingToolKnowledgeObject(_:))
            .map(incomingToolSummary(from:))
            .sorted { lhs, rhs in
                if lhs.risk != rhs.risk {
                    return incomingRiskRank(lhs.risk) > incomingRiskRank(rhs.risk)
                }
                return lhs.title < rhs.title
            }

        if !derived.isEmpty {
            return derived
        }

        if isMockMode || poller.extensionUsesDemoFallback {
            return pendingExtensionProposals.prefix(3).map { proposal in
                IncomingToolSummary(
                    id: "mock-tool-\(proposal.extensionId)",
                    extensionId: proposal.extensionId,
                    status: proposal.status,
                    discoveredAtIso: ISO8601DateFormatter().string(from: Date()),
                    objectId: proposal.extensionId,
                    title: proposal.title,
                    source: triageExtensionSourceLabel(sourceType: proposal.sourceType),
                    intentSummary: proposal.purpose,
                    capabilitySummary: proposal.capabilities.map(\.title).joined(separator: ", "),
                    capabilities: proposal.capabilities.map(\.title),
                    risk: normalizeIncomingRisk(proposal.risk),
                    suggestedRefinement: "Constrain to a narrow scoped workflow before promotion.",
                    suggestedRefinedTool: nil,
                    refinementSuggestions: [],
                    linkedCells: proposal.linkedCells,
                    explanation: proposal.reasoningTrace ?? proposal.purpose,
                    discoveryOrigin: "Mock discovery feed",
                    weakPoints: "Demo fallback artifact",
                    weakPointsList: ["Demo fallback artifact"],
                    evidenceRefs: [IncomingToolEvidenceRef(label: "Evidence", value: "Demo fallback artifact")],
                    actionHistory: [],
                    actions: IncomingToolActionSet(),
                    promotionReady: false,
                    lineageHint: "Discovery -> Forensics -> Proposal"
                )
            }
        }

        return []
    }

    private var incomingToolsEmptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox")
                    .font(.jeevesTitle)
                    .foregroundStyle(.secondary)
                Text("No incoming forensic tool artifacts.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
            }
            if !isMockMode, let error = poller.lastRefreshError, !error.isEmpty {
                Text(error)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlRoomPanel()
    }

    private func isIncomingToolKnowledgeObject(_ object: KnowledgeObject) -> Bool {
        let kind = object.kind.lowercased()
        let toolLikeKinds = [
            "forensic_tool",
            "incoming_tool",
            "tool_candidate",
            "tool_profile",
            "forensics",
            "repository_candidate",
            "agent_candidate",
            "extension_candidate",
            "governed_extension_candidate"
        ]
        if toolLikeKinds.contains(where: { kind.contains($0) }) {
            return true
        }
        let titleSummary = "\(object.title) \(object.summary)".lowercased()
        if titleSummary.contains("tool")
            || titleSummary.contains("agent")
            || titleSummary.contains("workflow")
            || titleSummary.contains("repository")
            || titleSummary.contains("forensic") {
            return true
        }
        return metadataValue(
            for: object,
            keys: [
                "tool_name",
                "detected_tool",
                "capabilities",
                "capability_list",
                "suggested_refinement",
                "weak_points",
                "evidence_refs"
            ]
        ) != nil
    }

    private func incomingToolSummary(from object: KnowledgeObject) -> IncomingToolSummary {
        let extensionId = metadataString(
            for: object,
            keys: ["extension_id", "extensionId", "tool_id", "toolId"]
        ) ?? object.objectId

        let title = metadataString(
            for: object,
            keys: ["tool_name", "detected_tool", "name", "title"]
        ) ?? object.title

        let source = readableIncomingSource(
            metadataString(for: object, keys: ["source", "source_type", "origin_source"])
                ?? object.sourceRefs?.first?.sourceType
                ?? object.sourceRefs?.first?.label
                ?? "CLASHD27 discovery"
        )

        let intentSummary = metadataString(
            for: object,
            keys: ["intent_summary", "purpose", "intent", "proposal_intent"]
        ) ?? object.summary

        let capabilities = metadataStrings(
            for: object,
            keys: ["capabilities", "capability_list", "detected_capabilities"]
        )
        let capabilitySummary = capabilities.isEmpty
            ? "No explicit capabilities captured."
            : capabilities.prefix(4).joined(separator: ", ")

        let risk = normalizeIncomingRisk(
            metadataString(for: object, keys: ["risk", "risk_level", "risk_classification"])
                ?? object.summary
        )

        let suggestedRefinement = metadataString(
            for: object,
            keys: ["suggested_refinement", "refinement", "improvement", "recommended_scope"]
        ) ?? "Scope this tool to one governed task before promotion."

        var linkedCells = metadataStrings(
            for: object,
            keys: ["linked_cells", "cube_cells", "cells"]
        )
        if linkedCells.isEmpty,
           let linked = object.linkedObjectIds?.filter({ $0.localizedCaseInsensitiveContains("cell") }),
           !linked.isEmpty {
            linkedCells = linked
        }
        if linkedCells.isEmpty {
            linkedCells = triageCells(fromText: "\(object.summary) \(title)")
        }
        linkedCells = Array(uniqueStrings(linkedCells).prefix(4))

        let explanation = metadataString(
            for: object,
            keys: ["explanation", "why_matters", "forensic_summary", "governance_reason"]
        ) ?? object.summary

        let discoveryOrigin = metadataString(
            for: object,
            keys: ["discovery_origin", "origin", "feed", "signal_origin"]
        ) ?? object.sourceRefs?.first?.label
            ?? object.sourceRefs?.first?.sourceId
            ?? "CLASHD27 signal"

        let weakPoints = metadataString(
            for: object,
            keys: ["weak_points", "limitations", "concerns"]
        ) ?? "Not yet documented."

        let evidenceRefs = incomingEvidenceRefs(for: object)
        let lineageHint = incomingLineageHint(for: object)

        return IncomingToolSummary(
            id: object.objectId,
            extensionId: extensionId,
            proposalId: metadataString(for: object, keys: ["proposal_id", "proposalId"]),
            status: metadataString(for: object, keys: ["status"]) ?? "proposed",
            discoveredAtIso: object.createdAtIso,
            objectId: object.objectId,
            title: title,
            source: source,
            intentSummary: intentSummary,
            capabilitySummary: capabilitySummary,
            capabilities: capabilities,
            risk: risk,
            suggestedRefinement: suggestedRefinement,
            suggestedRefinedTool: nil,
            refinementSuggestions: [],
            linkedCells: linkedCells,
            explanation: explanation,
            discoveryOrigin: discoveryOrigin,
            weakPoints: weakPoints,
            weakPointsList: [],
            evidenceRefs: evidenceRefs,
            forensicsReportId: metadataString(for: object, keys: ["forensics_report_id", "forensicsReportId"]),
            actionHistory: [],
            actions: IncomingToolActionSet(),
            promotionReady: false,
            lineageHint: lineageHint
        )
    }

    private func incomingEvidenceRefs(for object: KnowledgeObject) -> [IncomingToolEvidenceRef] {
        var refs: [IncomingToolEvidenceRef] = []

        for source in object.sourceRefs ?? [] {
            let label = source.label ?? source.sourceType.uppercased()
            refs.append(
                IncomingToolEvidenceRef(
                    label: label,
                    value: source.sourceId,
                    url: source.url,
                    id: "\(object.objectId)-source-\(source.sourceId)"
                )
            )
        }

        let extra = metadataStrings(
            for: object,
            keys: ["evidence_refs", "evidence", "references", "sources"]
        )
        for (index, value) in extra.prefix(4).enumerated() {
            let normalizedURL = value.hasPrefix("http://") || value.hasPrefix("https://") ? value : nil
            refs.append(
                IncomingToolEvidenceRef(
                    label: "Evidence",
                    value: value,
                    url: normalizedURL,
                    id: "\(object.objectId)-evidence-\(index)"
                )
            )
        }

        if refs.isEmpty {
            refs.append(
                IncomingToolEvidenceRef(
                    label: "Evidence",
                    value: "No explicit references provided.",
                    id: "\(object.objectId)-evidence-empty"
                )
            )
        }
        return refs
    }

    private func incomingLineageHint(for object: KnowledgeObject) -> String {
        if let linked = object.linkedObjectIds, !linked.isEmpty {
            let joined = linked.prefix(3).joined(separator: " -> ")
            return "Related: \(joined)"
        }
        return "Discovery -> Forensics -> Proposal"
    }

    private func readableIncomingSource(_ value: String) -> String {
        let normalized = value.lowercased()
        if normalized.contains("clashd27") || normalized.contains("radar") {
            return "CLASHD27 discovery"
        }
        if normalized.contains("github") {
            return "GitHub"
        }
        if normalized.contains("openalex") {
            return "OpenAlex"
        }
        if normalized.contains("semantic") {
            return "Semantic Scholar"
        }
        if normalized.contains("system") {
            return "System"
        }
        return value
    }

    private func normalizeIncomingRisk(_ value: String) -> String {
        let normalized = value.lowercased()
        if normalized.contains("red") || normalized.contains("high") {
            return "red"
        }
        if normalized.contains("orange") || normalized.contains("amber") || normalized.contains("medium") {
            return "orange"
        }
        if normalized.contains("green") || normalized.contains("low") {
            return "green"
        }
        return "unknown"
    }

    private func incomingRiskRank(_ risk: String) -> Int {
        switch risk {
        case "red": return 3
        case "orange": return 2
        case "green": return 1
        default: return 0
        }
    }

    private func metadataValue(for object: KnowledgeObject, keys: [String]) -> AnyCodableValue? {
        guard let metadata = object.metadata else { return nil }
        let normalized = Dictionary(uniqueKeysWithValues: metadata.map { ($0.key.lowercased(), $0.value) })
        for key in keys {
            if let value = normalized[key.lowercased()] {
                return value
            }
        }
        return nil
    }

    private func metadataValue(for object: KnowledgeObject?, keys: [String]) -> AnyCodableValue? {
        guard let object else { return nil }
        return metadataValue(for: object, keys: keys)
    }

    private func metadataString(for object: KnowledgeObject, keys: [String]) -> String? {
        guard let value = metadataValue(for: object, keys: keys),
              let text = value.scalarStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return text
    }

    private func metadataString(for object: KnowledgeObject?, keys: [String]) -> String? {
        guard let value = metadataValue(for: object, keys: keys),
              let text = value.scalarStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return text
    }

    private func metadataStrings(for object: KnowledgeObject, keys: [String]) -> [String] {
        guard let value = metadataValue(for: object, keys: keys),
              let values = value.stringArrayValue else {
            return []
        }
        return uniqueStrings(values)
    }

    private func uniqueStrings(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            if seen.insert(normalized).inserted {
                ordered.append(normalized)
            }
        }
        return ordered
    }

    private func relatedExtensionProposals(for tool: IncomingToolSummary) -> [ExtensionProposal] {
        let cells = Set(tool.linkedCells.map { $0.lowercased() })
        let terms = Set(
            (tool.title + " " + tool.intentSummary)
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" && $0 != "-" })
                .map(String.init)
                .filter { $0.count >= 4 }
        )

        return poller.extensionProposals
            .map { proposal -> (proposal: ExtensionProposal, score: Int) in
                var score = 0
                let proposalText = "\(proposal.title) \(proposal.purpose) \(proposal.reasoningTrace ?? "")".lowercased()
                if proposal.linkedCells.map({ $0.lowercased() }).contains(where: { cells.contains($0) }) {
                    score += 3
                }
                if terms.contains(where: { proposalText.contains($0) }) {
                    score += 2
                }
                if normalizeIncomingRisk(proposal.risk) == tool.risk {
                    score += 1
                }
                return (proposal, score)
            }
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.proposal.title < rhs.proposal.title
            }
            .map(\.proposal)
            .prefix(3)
            .map { $0 }
    }

    private func handleIncomingToolAction(_ kind: IncomingToolActionKind, tool: IncomingToolSummary) {
        if kind == .refine {
            incomingToolStatusMessage = "Refinement brief prepared: \(tool.suggestedRefinement)"
            selectedIncomingTool = tool
            return
        }
        performIncomingToolBackendAction(kind, tool: tool)
    }

    private func performIncomingToolBackendAction(_ kind: IncomingToolActionKind, tool: IncomingToolSummary) {
        guard incomingToolActionInFlightId == nil else { return }
        let action = tool.actions.state(for: kind)
        guard action.available else {
            incomingToolActionErrorMessage = "\(kind.rawValue.capitalized) is currently unavailable for this tool."
            showIncomingToolActionError = true
            return
        }
        guard let endpoint = action.endpoint, !endpoint.isEmpty else {
            incomingToolActionErrorMessage = "No backend endpoint is available for this action."
            showIncomingToolActionError = true
            return
        }

        incomingToolActionInFlightId = tool.id

        Task {
            let resolved = await resolveEndpoint()
            guard let token = resolved.token, !token.isEmpty else {
                await MainActor.run {
                    incomingToolActionInFlightId = nil
                    incomingToolActionErrorMessage = "Geen token beschikbaar. Voeg een token toe in Instellingen."
                    showIncomingToolActionError = true
                }
                return
            }

            let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)

            do {
                _ = try await client.performIncomingToolAction(
                    endpoint: endpoint,
                    reason: incomingToolActionReason(for: kind)
                )
                await poller.refresh(gateway: gateway)
                await MainActor.run {
                    incomingToolActionInFlightId = nil
                    incomingToolStatusMessage = incomingToolActionSuccessMessage(for: kind, extensionId: tool.extensionId)
                    selectedIncomingTool = incomingTools.first(where: { $0.id == tool.id })
                }
            } catch {
                await MainActor.run {
                    incomingToolActionInFlightId = nil
                    incomingToolActionErrorMessage = describeIncomingToolActionFailure(
                        error,
                        host: resolved.host,
                        port: resolved.port
                    )
                    showIncomingToolActionError = true
                }
            }
        }
    }

    private func incomingToolActionReason(for kind: IncomingToolActionKind) -> String? {
        switch kind {
        case .reject:
            return "incoming_tool_rejected"
        case .promote:
            return "incoming_tool_promoted"
        case .sandbox, .refine:
            return nil
        }
    }

    private func incomingToolActionSuccessMessage(for kind: IncomingToolActionKind, extensionId: String) -> String {
        switch kind {
        case .reject:
            return "Incoming tool rejected: \(extensionId)"
        case .sandbox:
            return "Extension sandbox loaded: \(extensionId)"
        case .promote:
            return "Tool promoted into proposal flow: \(extensionId)"
        case .refine:
            return "Refinement brief prepared: \(extensionId)"
        }
    }

    private func describeIncomingToolActionFailure(_ error: Error, host: String, port: Int) -> String {
        if case GatewayClientError.httpStatus(let status) = error {
            switch status {
            case 401:
                return "Token ongeldig of verlopen voor \(host):\(port)."
            case 404:
                return "Incoming Tool endpoint niet gevonden op \(host):\(port)."
            default:
                return "Backend fout (\(status)) op \(host):\(port)."
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotFindHost, .cannotConnectToHost, .timedOut, .networkConnectionLost:
                return "Backend onbereikbaar op \(host):\(port)."
            default:
                break
            }
        }
        return "Incoming Tool actie mislukt."
    }

    // MARK: - AI Browser

    private var aiBrowserSection: some View {
        let certifiedCards = certifiedCatalogCards
        let featuredCards = featuredCertifiedCards
        let emergingCards = filteredEmergingIntentions
        let hasCertified = !certifiedCards.isEmpty
        let hasEmerging = !emergingCards.isEmpty
        let guidance = browserGuidance(
            certifiedCards: certifiedCards,
            emergingCards: emergingCards,
            sourceLabel: browserFeed == nil ? "SafeClash search fallback" : "SafeClash browser feed"
        )

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(BrowserGuidanceContract.modeTitle)
                        .font(.jeevesHeadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle("Guide", isOn: $browserGuideModeEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                if browserGuideModeEnabled {
                    BrowserGuidancePanel(brief: guidance)
                }
            }
            .controlRoomPanel(padding: 12)

            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(
                    title: "FEATURED / RECOMMENDED",
                    icon: "star.fill",
                    count: featuredCards.count,
                    tint: .cyan
                )

                if featuredCards.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .foregroundStyle(.secondary)
                        Text("Featured recommendations appear after category search results are loaded.")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .controlRoomPanel(padding: 12)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(featuredCards) { card in
                            FeaturedAICard(
                                card: card,
                                isDeploying: browserDeployingConfigId == card.bestConfiguration.configId,
                                onInspect: { openBrowserCard(card) },
                                onDeploy: { requestBrowserDeployment(for: card, origin: .card) }
                            )
                        }
                    }
                }
            }

            aiBrowserQueryPanel

            HStack(spacing: 8) {
                Image(systemName: browserFeed == nil ? "rectangle.3.offgrid.bubble.left" : "rectangle.3.group.bubble.left.fill")
                    .foregroundStyle(browserFeed == nil ? Color.secondary : Color.cyan)
                Text(browserFeed == nil ? "Source: SafeClash search fallback" : "Source: SafeClash browser feed")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .controlRoomPanel(padding: 10)

            if isMockMode {
                Text("Mock mode active: AI Browser may include simulated discovery signals.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }

            if let proposalId = browserLastCreatedProposalId, !proposalId.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.consentGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Proposal created")
                            .font(.jeevesCaption.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Proposal \(proposalId) is pending approval in DECISIONS.")
                            .font(.jeevesCaption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Button("Open Decisions") {
                            shouldScrollToDecisions = true
                        }
                        .buttonStyle(.bordered)
                        Button("View Proposal") {
                            shouldScrollToDecisions = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .controlRoomPanel(padding: 10)
            }

            if let status = browserStatusMessage, !status.isEmpty {
                Text(status)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }

            if browserLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("SafeClash search uitvoeren...")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .controlRoomPanel(padding: 12)
            }

            if let browserErrorMessage, !browserErrorMessage.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SafeClash query mislukt")
                        .font(.jeevesHeadline)
                        .foregroundStyle(.white)
                    Text(browserErrorMessage)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    Button("Retry search") {
                        runSafeClashSearch()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .controlRoomPanel(padding: 12)
            }

            if !browserLoading, !hasCertified, !hasEmerging {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Living intention catalog is waiting for data.")
                        .font(.jeevesHeadline)
                        .foregroundStyle(.white)
                    Text("SafeClash browser feed and certified search are currently empty. Emerging intentions still include CLASHD27 discovery fallback.")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    Text("No certified or emerging intentions available right now.")
                        .font(.jeevesCaption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .controlRoomPanel(padding: 12)
            }

            if hasCertified {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(
                        title: "CERTIFIED",
                        icon: "checkmark.seal.fill",
                        count: certifiedCards.count,
                        tint: .consentGreen
                    )

                    LazyVStack(spacing: 10) {
                        ForEach(certifiedCards.prefix(8)) { card in
                            AIBrowserResultCard(
                                card: card,
                                emergingMomentumCount: emergingSiblingCount(for: card),
                                isDeploying: browserDeployingConfigId == card.bestConfiguration.configId,
                                onOpen: {
                                    openBrowserCard(card)
                                },
                                onDeploy: {
                                    requestBrowserDeployment(for: card, origin: .card)
                                }
                            )
                        }
                    }
                }
            }

            if hasEmerging {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(
                        title: "EMERGING",
                        icon: "sparkles",
                        count: emergingCards.count,
                        tint: .consentOrange
                    )

                    LazyVStack(spacing: 10) {
                        ForEach(emergingCards.prefix(8)) { intention in
                            EmergingIntentionCard(
                                intention: intention,
                                relatedToolsCount: relatedIncomingTools(for: intention).count,
                                hasCertifiedConfiguration: hasCertifiedConfiguration(for: intention)
                            ) {
                                selectedEmergingIntention = intention
                            }
                        }
                    }
                }
            }
        }
    }

    private func browserGuidance(
        certifiedCards: [BrowserCard],
        emergingCards: [EmergingIntentionProfile],
        sourceLabel: String
    ) -> BrowserGuidanceBrief {
        let sortedCertified = certifiedCards.sorted {
            if $0.rankingScore == $1.rankingScore {
                return $0.id < $1.id
            }
            return $0.rankingScore > $1.rankingScore
        }
        let sortedEmerging = emergingCards.sorted {
            if $0.confidenceScore == $1.confidenceScore {
                return $0.id < $1.id
            }
            return $0.confidenceScore > $1.confidenceScore
        }

        let leadCertified = sortedCertified.first
        let leadEmerging = sortedEmerging.first

        let state: BrowserUncertaintyState = {
            if let leadCertified {
                return leadCertified.uncertaintyState
            }
            if let leadEmerging {
                return leadEmerging.uncertaintyState
            }
            return .unknown
        }()

        var clear: [String] = []
        if !sortedCertified.isEmpty {
            clear.append("Certified options are available in \(browserDomain) / \(browserSubdomain).")
        }
        if sortedCertified.contains(where: \.deployReady) {
            clear.append("At least one certified option is deploy-ready through proposal.")
        }
        if !sortedEmerging.isEmpty {
            clear.append("Emerging intentions are visible from CLASHD27 and SafeClash feeds.")
        }
        if clear.isEmpty {
            clear.append("Current feed source: \(sourceLabel).")
        }

        var uncertain: [String] = []
        if sortedCertified.isEmpty {
            uncertain.append("No certified configuration is currently available for this focus.")
        } else if let leadCertified, !leadCertified.deployReady {
            uncertain.append("Top certified option is not deploy-ready yet.")
        }
        if let leadEmerging, leadEmerging.confidenceScore < 0.75 {
            uncertain.append("Emerging confidence is below confirmation level.")
        }
        if uncertain.isEmpty {
            uncertain.append("Deployment still requires proposal and human approval.")
        }

        var options: [String] = []
        if let leadCertified {
            options.append("Inspect \"\(leadCertified.title)\" and validate constraints.")
        }
        if let leadEmerging {
            options.append("Inspect emerging intention \"\(leadEmerging.title)\" for related tools.")
        }
        if options.isEmpty {
            options.append("Run category search and gather stronger candidates.")
        }

        var why: [String] = []
        if let leadCertified {
            why.append("Ranking \(String(format: "%.2f", leadCertified.rankingScore)) with \(leadCertified.bestConfiguration.certificationLevel) certification.")
        }
        if let leadEmerging {
            why.append("Emerging confidence \(String(format: "%.2f", leadEmerging.confidenceScore)) from linked source clusters.")
        }
        why.append("Source path: \(sourceLabel).")

        var next: [String] = []
        if let leadCertified, leadCertified.deployReady {
            next.append("If appropriate, create a governed deployment proposal.")
        } else {
            next.append("Compare certified alternatives before requesting deployment.")
        }
        if !sortedEmerging.isEmpty {
            next.append("Inspect related incoming tools and lineage before narrowing intention scope.")
        }
        if next.isEmpty {
            next.append("Wait for additional evidence before action.")
        }

        return BrowserGuidanceBrief(
            state: state,
            clear: clear,
            uncertain: uncertain,
            options: options,
            why: why,
            next: next
        )
    }

    private var aiBrowserQueryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Browse by Category")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)

            if !browserFeedCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(browserFeedCategories) { category in
                            Button {
                                applyFeedCategory(category)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.grid.2x2")
                                        .font(.jeevesCaption)
                                    Text(category.title)
                                        .font(.jeevesCaption.weight(.medium))
                                    if let count = category.certifiedCount {
                                        Text("\(count)")
                                            .font(.jeevesCaption2.weight(.semibold))
                                    }
                                }
                                .foregroundStyle(selectedFeedCategoryId == category.id ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedFeedCategoryId == category.id ? Color.cyan.opacity(0.28) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectedFeedCategoryId == category.id ? Color.cyan.opacity(0.7) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BrowserCategory.allCases) { category in
                        Button {
                            applyBrowserCategory(category)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.jeevesCaption)
                                Text(category.title)
                                    .font(.jeevesCaption.weight(.medium))
                            }
                            .foregroundStyle(selectedBrowserCategory == category ? .white : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedBrowserCategory == category ? Color.cyan.opacity(0.28) : Color.white.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(selectedBrowserCategory == category ? Color.cyan.opacity(0.7) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(activeBrowserSubdomainOptions, id: \.self) { subdomain in
                        Button {
                            selectedBrowserSubdomain = subdomain
                            browserSubdomain = subdomain
                        } label: {
                            Text(readableSubdomain(subdomain))
                                .font(.jeevesCaption.weight(.medium))
                                .foregroundStyle(selectedBrowserSubdomain == subdomain ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedBrowserSubdomain == subdomain ? Color.blue.opacity(0.24) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectedBrowserSubdomain == subdomain ? Color.blue.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                Text("\(readableSubdomain(browserDomain)) / \(readableSubdomain(browserSubdomain))")
                    .font(.jeevesMono)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text(browserRiskProfile.uppercased())
                    .font(.jeevesCaption2.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.16))
                    .clipShape(Capsule())
            }

            Picker("Risk", selection: $browserRiskProfile) {
                Text("Low").tag("low")
                Text("Medium").tag("medium")
                Text("High").tag("high")
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Explore Category") {
                    runSafeClashSearch()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(browserLoading)

                Spacer()
                Button(showBrowserAdvancedFilters ? "Hide advanced" : "Advanced filters") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBrowserAdvancedFilters.toggle()
                    }
                }
                .buttonStyle(.bordered)
            }

            if showBrowserAdvancedFilters {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("constraints (k=v,comma-separated)", text: $browserConstraintsRaw)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(.jeevesMono)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("/api/browser/feed?domain=\(browserDomain)&subdomain=\(browserSubdomain)&risk=\(browserRiskProfile)")
                        .font(.jeevesCaption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .controlRoomPanel(padding: 12)
    }

    private var browserFeedCategories: [SafeClashBrowserCategory] {
        (browserFeed?.categories ?? [])
            .sorted { lhs, rhs in
                let lhsCount = lhs.certifiedCount ?? 0
                let rhsCount = rhs.certifiedCount ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }
                return lhs.title < rhs.title
            }
    }

    private var activeBrowserSubdomainOptions: [String] {
        if let selectedFeedCategory,
           !selectedFeedCategory.subdomains.isEmpty {
            return selectedFeedCategory.subdomains
        }
        return selectedBrowserCategory.subdomains
    }

    private var selectedFeedCategory: SafeClashBrowserCategory? {
        guard let selectedFeedCategoryId else { return nil }
        return browserFeedCategories.first(where: { $0.id == selectedFeedCategoryId })
    }

    private var aiBrowserCards: [BrowserCard] {
        if let feed = browserFeed, !feed.certified.isEmpty {
            return feed.certified.map { BrowserCard(certified: $0) }
        }
        return browserResults.map { BrowserCard(profile: $0) }
    }

    private var feedFeaturedCards: [BrowserCard] {
        guard let feed = browserFeed else { return [] }
        return feed.featured.map { BrowserCard(certified: $0) }
    }

    private var certifiedCatalogCards: [BrowserCard] {
        let domainToken = normalizedCatalogToken(browserDomain)
        let subdomainToken = normalizedCatalogToken(browserSubdomain)
        let riskToken = normalizedBrowserRisk(browserRiskProfile)

        return aiBrowserCards
            .filter { card in
                let cardDomain = normalizedCatalogToken(card.domain)
                let cardSubdomain = normalizedCatalogToken(card.subdomain)
                let cardRisk = normalizedBrowserRisk(card.riskProfile)

                let domainMatch = domainToken.isEmpty || cardDomain.contains(domainToken) || domainToken.contains(cardDomain)
                let subdomainMatch = subdomainToken.isEmpty || cardSubdomain.contains(subdomainToken) || subdomainToken.contains(cardSubdomain)
                let riskMatch = riskToken.isEmpty || cardRisk == riskToken
                return domainMatch && subdomainMatch && riskMatch
            }
            .sorted { lhs, rhs in
                if lhs.rankingScore != rhs.rankingScore { return lhs.rankingScore > rhs.rankingScore }
                return lhs.title < rhs.title
            }
    }

    private var featuredCertifiedCards: [BrowserCard] {
        let featuredSource = !feedFeaturedCards.isEmpty ? feedFeaturedCards : certifiedCatalogCards
        return featuredSource
            .filter { card in
                let cardDomain = normalizedCatalogToken(card.domain)
                let cardSubdomain = normalizedCatalogToken(card.subdomain)
                let cardRisk = normalizedBrowserRisk(card.riskProfile)
                let domainToken = normalizedCatalogToken(browserDomain)
                let subdomainToken = normalizedCatalogToken(browserSubdomain)
                let riskToken = normalizedBrowserRisk(browserRiskProfile)
                let domainMatch = domainToken.isEmpty || cardDomain.contains(domainToken) || domainToken.contains(cardDomain)
                let subdomainMatch = subdomainToken.isEmpty || cardSubdomain.contains(subdomainToken) || subdomainToken.contains(cardSubdomain)
                let riskMatch = riskToken.isEmpty || cardRisk == riskToken
                return domainMatch && subdomainMatch && riskMatch
            }
            .sorted { lhs, rhs in
                let lhsTrust = certificationRank(lhs.bestConfiguration.certificationLevel)
                let rhsTrust = certificationRank(rhs.bestConfiguration.certificationLevel)
                if lhsTrust != rhsTrust { return lhsTrust > rhsTrust }
                if lhs.rankingScore != rhs.rankingScore { return lhs.rankingScore > rhs.rankingScore }
                return lhs.bestConfiguration.benchmarkScore > rhs.bestConfiguration.benchmarkScore
            }
            .prefix(3)
            .map { $0 }
    }

    private var emergingIntentions: [EmergingIntentionProfile] {
        let feedEmerging = (browserFeed?.emerging ?? []).map(\.profile)
        let remoteMerged = mergeEmergingIntentions(
            primary: browserEmergingRemote,
            secondary: emergingIntentionsFromRadar
        )
        let merged = mergeEmergingIntentions(
            primary: feedEmerging,
            secondary: remoteMerged
        )
        return merged.sorted { lhs, rhs in
            if catalogStateRank(lhs.state) != catalogStateRank(rhs.state) {
                return catalogStateRank(lhs.state) > catalogStateRank(rhs.state)
            }
            if lhs.confidenceScore != rhs.confidenceScore {
                return lhs.confidenceScore > rhs.confidenceScore
            }
            return "\(lhs.domain)/\(lhs.subdomain)" < "\(rhs.domain)/\(rhs.subdomain)"
        }
    }

    private var filteredEmergingIntentions: [EmergingIntentionProfile] {
        guard browserHasExecutedQuery else {
            return emergingIntentions
        }

        let domainToken = normalizedCatalogToken(browserDomain)
        let subdomainToken = normalizedCatalogToken(browserSubdomain)
        let riskToken = normalizedBrowserRisk(browserRiskProfile)

        return emergingIntentions.filter { intention in
            intentionMatchesQuery(
                intention: intention,
                domainToken: domainToken,
                subdomainToken: subdomainToken,
                riskToken: riskToken
            )
        }
    }

    private var emergingIntentionsFromRadar: [EmergingIntentionProfile] {
        radarSignals.compactMap { signal in
            let confidence = normalizedConfidence(signal.score)
            guard confidence >= 0.45 else { return nil }

            let sourceCandidate = poller.radarDiscoveryCandidates.first { candidate in
                candidate.candidateId == signal.id
            }

            let sourceClusters = sourceCandidate?.sources ?? [
                "clashd27.\(signal.what)",
                "radar.\(signal.whereValue)"
            ]
            let discoveredAtIso = signal.timestampIso ?? poller.streamEvents.first(where: { event in
                event.candidateId == signal.id || event.id == signal.id
            })?.timestampIso

            return EmergingIntentionProfile(
                intentionId: signal.id,
                domain: signal.what,
                subdomain: signal.whereValue,
                description: signal.explanation,
                confidenceScore: confidence,
                sourceClusters: Array(uniqueStrings(sourceClusters).prefix(3)),
                linkedCells: signal.linkedCells,
                clashdSignalSummary: signal.explanation,
                state: inferredCatalogState(for: signal),
                discoveredAtIso: discoveredAtIso,
                hasCertifiedConfiguration: nil,
                candidateConfigurationAvailable: nil
            )
        }
    }

    private func mergeEmergingIntentions(
        primary: [EmergingIntentionProfile],
        secondary: [EmergingIntentionProfile]
    ) -> [EmergingIntentionProfile] {
        var byKey: [String: EmergingIntentionProfile] = [:]

        for profile in secondary {
            byKey[catalogKey(for: profile)] = profile
        }
        for profile in primary {
            let key = catalogKey(for: profile)
            if let existing = byKey[key] {
                byKey[key] = mergedProfile(existing: existing, incoming: profile)
            } else {
                byKey[key] = profile
            }
        }
        return Array(byKey.values)
    }

    private func mergedProfile(
        existing: EmergingIntentionProfile,
        incoming: EmergingIntentionProfile
    ) -> EmergingIntentionProfile {
        EmergingIntentionProfile(
            intentionId: incoming.intentionId,
            domain: incoming.domain,
            subdomain: incoming.subdomain,
            description: incoming.description.isEmpty ? existing.description : incoming.description,
            riskProfile: incoming.riskProfile ?? existing.riskProfile,
            confidenceScore: max(existing.confidenceScore, incoming.confidenceScore),
            sourceClusters: uniqueStrings(incoming.sourceClusters + existing.sourceClusters),
            linkedCells: uniqueStrings(incoming.linkedCells + existing.linkedCells),
            clashdSignalSummary: incoming.clashdSignalSummary.isEmpty ? existing.clashdSignalSummary : incoming.clashdSignalSummary,
            state: catalogStateRank(incoming.state) >= catalogStateRank(existing.state) ? incoming.state : existing.state,
            discoveredAtIso: incoming.discoveredAtIso ?? existing.discoveredAtIso,
            hasCertifiedConfiguration: incoming.hasCertifiedConfiguration ?? existing.hasCertifiedConfiguration,
            candidateConfigurationAvailable: incoming.candidateConfigurationAvailable ?? existing.candidateConfigurationAvailable,
            relatedIncomingToolCount: incoming.relatedIncomingToolCount ?? existing.relatedIncomingToolCount
        )
    }

    private func catalogKey(for profile: EmergingIntentionProfile) -> String {
        let domain = normalizedCatalogToken(profile.domain)
        let subdomain = normalizedCatalogToken(profile.subdomain)
        if !domain.isEmpty || !subdomain.isEmpty {
            return "domain:\(domain)|subdomain:\(subdomain)"
        }
        return "id:\(normalizedCatalogToken(profile.intentionId))"
    }

    private func intentionMatchesQuery(
        intention: EmergingIntentionProfile,
        domainToken: String,
        subdomainToken: String,
        riskToken: String
    ) -> Bool {
        let intentionDomain = normalizedCatalogToken(intention.domain)
        let intentionSubdomain = normalizedCatalogToken(intention.subdomain)

        if !domainToken.isEmpty,
           !intentionDomain.contains(domainToken),
           !domainToken.contains(intentionDomain) {
            return false
        }

        if !subdomainToken.isEmpty,
           !intentionSubdomain.contains(subdomainToken),
           !subdomainToken.contains(intentionSubdomain) {
            return false
        }

        if !riskToken.isEmpty,
           let risk = intention.riskProfile {
            let intentionRisk = normalizedBrowserRisk(risk)
            if !intentionRisk.isEmpty, intentionRisk != riskToken {
                return false
            }
        }

        return true
    }

    private func catalogStateRank(_ state: IntentionCatalogState) -> Int {
        switch state {
        case .promoted: return 3
        case .certified: return 2
        case .emerging: return 1
        }
    }

    private func inferredCatalogState(for signal: RadarSignalSummary) -> IntentionCatalogState {
        let linked = signal.linkedProposalLabel?.lowercased() ?? ""
        if linked.contains("approved") {
            return .promoted
        }
        if linked.contains("pending") || linked.contains("linked proposal") {
            return .certified
        }
        return .emerging
    }

    private func normalizedConfidence(_ rawScore: Double) -> Double {
        var score = rawScore
        if score > 1 {
            if score <= 10 {
                score /= 10
            } else {
                score /= 100
            }
        }
        return min(max(score, 0), 1)
    }

    private func normalizedCatalogToken(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }

    private func normalizedBrowserRisk(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("low") || normalized.contains("green") {
            return "low"
        }
        if normalized.contains("medium") || normalized.contains("orange") || normalized.contains("amber") {
            return "medium"
        }
        if normalized.contains("high") || normalized.contains("red") {
            return "high"
        }
        return normalized
    }

    private func certificationRank(_ certificationLevel: String) -> Int {
        switch certificationLevel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "gold":
            return 3
        case "silver":
            return 2
        case "bronze":
            return 1
        default:
            return 0
        }
    }

    private func syncBrowserCategorySelection() {
        let domainToken = normalizedCatalogToken(browserDomain)
        if let matched = BrowserCategory.allCases.first(where: { normalizedCatalogToken($0.domain) == domainToken }) {
            selectedBrowserCategory = matched
        }

        if selectedBrowserCategory.subdomains.contains(browserSubdomain) {
            selectedBrowserSubdomain = browserSubdomain
        } else if let first = selectedBrowserCategory.subdomains.first {
            selectedBrowserSubdomain = first
            browserSubdomain = first
        }

        if let selectedFeedCategoryId,
           !browserFeedCategories.contains(where: { $0.id == selectedFeedCategoryId }) {
            self.selectedFeedCategoryId = nil
        }
    }

    private func applyBrowserCategory(_ category: BrowserCategory) {
        selectedFeedCategoryId = nil
        selectedBrowserCategory = category
        browserDomain = category.domain
        browserRiskProfile = category.defaultRisk

        if !category.subdomains.contains(selectedBrowserSubdomain),
           let first = category.subdomains.first {
            selectedBrowserSubdomain = first
        }
        browserSubdomain = selectedBrowserSubdomain
    }

    private func applyFeedCategory(_ category: SafeClashBrowserCategory) {
        selectedFeedCategoryId = category.id
        browserDomain = category.domain
        if let first = category.subdomains.first {
            selectedBrowserSubdomain = first
            browserSubdomain = first
        }

        let domainToken = normalizedCatalogToken(category.domain)
        if let matched = BrowserCategory.allCases.first(where: { normalizedCatalogToken($0.domain) == domainToken }) {
            selectedBrowserCategory = matched
            if matched.subdomains.contains(browserSubdomain) {
                selectedBrowserSubdomain = browserSubdomain
            }
        }
        runSafeClashSearch()
    }

    private func readableSubdomain(_ value: String) -> String {
        value
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func relatedIncomingTools(for intention: EmergingIntentionProfile) -> [IncomingToolSummary] {
        let cells = Set(intention.linkedCells.map { $0.lowercased() })
        let intentionTerms = browserTerms(
            from: "\(intention.domain) \(intention.subdomain) \(intention.description) \(intention.clashdSignalSummary)"
        )

        return incomingTools
            .map { tool -> (tool: IncomingToolSummary, score: Int) in
                var score = 0
                let toolText = "\(tool.title) \(tool.intentSummary) \(tool.capabilitySummary) \(tool.discoveryOrigin)".lowercased()
                let toolCells = Set(tool.linkedCells.map { $0.lowercased() })

                if !cells.isEmpty && !cells.intersection(toolCells).isEmpty {
                    score += 3
                }
                if toolText.contains(normalizedCatalogToken(intention.domain).replacingOccurrences(of: "-", with: " ")) {
                    score += 2
                }
                if toolText.contains(normalizedCatalogToken(intention.subdomain).replacingOccurrences(of: "-", with: " ")) {
                    score += 2
                }
                if intentionTerms.contains(where: { token in toolText.contains(token) }) {
                    score += 1
                }
                return (tool, score)
            }
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.tool.title < rhs.tool.title
            }
            .map(\.tool)
            .prefix(3)
            .map { $0 }
    }

    private func certifiedMatch(for intention: EmergingIntentionProfile) -> BrowserCard? {
        let domain = normalizedCatalogToken(intention.domain)
        let subdomain = normalizedCatalogToken(intention.subdomain)
        let intentionTokens = browserTerms(from: "\(intention.intentionId) \(intention.description)")

        return aiBrowserCards
            .map { card -> (card: BrowserCard, score: Int) in
                var score = 0
                if normalizedCatalogToken(card.domain) == domain { score += 4 }
                if normalizedCatalogToken(card.subdomain) == subdomain { score += 4 }
                if normalizedCatalogToken(card.intentionId) == normalizedCatalogToken(intention.intentionId) {
                    score += 5
                }
                let cardText = "\(card.title) \(card.intentionId) \(card.whyRecommended)".lowercased()
                if intentionTokens.contains(where: { token in cardText.contains(token) }) {
                    score += 1
                }
                return (card, score)
            }
            .filter { $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.card.rankingScore > rhs.card.rankingScore
            }
            .first?
            .card
    }

    private func hasCertifiedConfiguration(for intention: EmergingIntentionProfile) -> Bool {
        if intention.hasCertifiedConfiguration == true { return true }
        if intention.candidateConfigurationAvailable == true { return true }
        if intention.state == .certified || intention.state == .promoted { return true }
        return certifiedMatch(for: intention) != nil
    }

    private func emergingSiblingCount(for card: BrowserCard) -> Int {
        let cardDomain = normalizedCatalogToken(card.domain)
        let cardSubdomain = normalizedCatalogToken(card.subdomain)
        return emergingIntentions.reduce(into: 0) { count, intention in
            let intentionDomain = normalizedCatalogToken(intention.domain)
            let intentionSubdomain = normalizedCatalogToken(intention.subdomain)
            if intentionDomain == cardDomain && intentionSubdomain == cardSubdomain {
                count += 1
            }
        }
    }

    private func browserTerms(from text: String) -> Set<String> {
        Set(
            text
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" && $0 != "-" })
                .map(String.init)
                .filter { $0.count >= 4 }
        )
    }

    private func runSafeClashSearch() {
        let domain = browserDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        let subdomain = browserSubdomain.trimmingCharacters(in: .whitespacesAndNewlines)
        let risk = browserRiskProfile.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !domain.isEmpty, !subdomain.isEmpty else {
            browserErrorMessage = "Domain and subdomain are required."
            return
        }

        browserHasExecutedQuery = true
        browserLoading = true
        browserErrorMessage = nil
        browserStatusMessage = nil
        let constraints = parsedBrowserConstraints(browserConstraintsRaw)

        Task {
            do {
                let client = safeClashClient()

                if let feed = try? await client.fetchBrowserFeed(
                    domain: domain,
                    subdomain: subdomain,
                    risk: risk,
                    constraints: constraints
                ) {
                    let certified = feed.certified
                    let emerging = feed.emerging
                    var cacheUpdates: [String: AIConfigurationAtom] = [:]
                    for item in certified {
                        cacheUpdates[item.configId] = item.configurationAtom
                    }
                    await MainActor.run {
                        browserFeed = feed
                        browserResults = certified.map(\.profile)
                        browserEmergingRemote = emerging.map(\.profile)
                        browserConfigurationCache.merge(cacheUpdates) { _, incoming in incoming }
                        browserLoading = false
                        browserStatusMessage = "Browser feed loaded: \(feed.featured.count) featured, \(certified.count) certified, \(emerging.count) emerging."
                    }
                    return
                }

                let results = try await client.searchIntentions(
                    domain: domain,
                    subdomain: subdomain,
                    risk: risk,
                    constraints: constraints
                )
                var emerging: [EmergingIntentionProfile] = []
                do {
                    emerging = try await client.fetchEmergingIntentions(
                        domain: domain,
                        subdomain: subdomain,
                        risk: risk,
                        constraints: constraints
                    )
                } catch {}

                await MainActor.run {
                    browserFeed = nil
                    browserResults = results
                    browserEmergingRemote = emerging
                    browserLoading = false
                    browserStatusMessage = "Found \(results.count) certified and \(emerging.count) emerging intentions for \(domain)/\(subdomain)."
                }
            } catch {
                await MainActor.run {
                    browserLoading = false
                    browserErrorMessage = describeSafeClashFailure(error)
                }
            }
        }
    }

    private func primeEmergingIntentionsFeedIfNeeded() {
        guard !browserHasPrimedEmergingFeed else { return }
        browserHasPrimedEmergingFeed = true

        Task {
            do {
                let client = safeClashClient()
                if let feed = try? await client.fetchBrowserFeed() {
                    var cacheUpdates: [String: AIConfigurationAtom] = [:]
                    for item in feed.certified {
                        cacheUpdates[item.configId] = item.configurationAtom
                    }
                    await MainActor.run {
                        browserFeed = feed
                        browserConfigurationCache.merge(cacheUpdates) { _, incoming in incoming }
                        browserResults = feed.certified.map(\.profile)
                        browserEmergingRemote = mergeEmergingIntentions(
                            primary: browserEmergingRemote,
                            secondary: feed.emerging.map(\.profile)
                        )
                        if browserStatusMessage == nil {
                            browserStatusMessage = "Browser feed active."
                        }
                    }
                    return
                }
                let emerging = try await client.fetchEmergingIntentions()
                await MainActor.run {
                    browserEmergingRemote = mergeEmergingIntentions(
                        primary: browserEmergingRemote,
                        secondary: emerging
                    )
                    if !emerging.isEmpty, browserStatusMessage == nil {
                        browserStatusMessage = "Emerging intentions feed active (\(emerging.count))."
                    }
                }
            } catch {
                // Radar-derived emerging intentions remain available as fallback.
            }
        }
    }

    private func openBrowserCard(_ card: BrowserCard) {
        selectedBrowserCard = card
        fetchBrowserConfiguration(configId: card.bestConfiguration.configId)
    }

    private func fetchBrowserConfiguration(configId: String) {
        if browserConfigurationCache[configId] != nil { return }
        guard browserConfigurationLoadingId == nil else { return }
        browserConfigurationLoadingId = configId

        Task {
            do {
                let client = safeClashClient()
                let configuration = try await client.getConfiguration(configId: configId)
                await MainActor.run {
                    browserConfigurationCache[configId] = configuration
                    browserConfigurationLoadingId = nil
                }
            } catch {
                await MainActor.run {
                    browserConfigurationLoadingId = nil
                    browserStatusMessage = "Configuration details unavailable for \(configId)."
                }
            }
        }
    }

    private func requestBrowserDeployment(for card: BrowserCard, origin: BrowserDeployActionOrigin) {
        guard card.deployReady else {
            browserActionErrorMessage = "This certified result is not deploy-ready yet. Inspect details and wait for certification readiness."
            showBrowserActionError = true
            return
        }
        let configuration = browserConfigurationCache[card.bestConfiguration.configId] ?? card.bestConfiguration
        let request = makeBrowserDeploymentRequest(card: card, configuration: configuration)
        if case .detail = origin {
            selectedBrowserCard = nil
            DispatchQueue.main.async {
                pendingBrowserDeployment = request
            }
        } else {
            pendingBrowserDeployment = request
        }
        if case .card = origin {
            fetchBrowserConfiguration(configId: card.bestConfiguration.configId)
        }
    }

    private func makeBrowserDeploymentRequest(
        card: BrowserCard,
        configuration: AIConfigurationAtom
    ) -> DeployConfigurationRequest {
        DeployConfigurationRequest(
            intentionId: card.intentionId,
            intentionTitle: card.title,
            domain: card.domain,
            subdomain: card.subdomain,
            riskProfile: card.riskProfile,
            configId: configuration.configId,
            model: configuration.model,
            certificationLevel: configuration.certificationLevel,
            certificateId: configuration.certificateId,
            rankingScore: card.rankingScore,
            benchmarkScore: configuration.benchmarkScore,
            benchmarkContractId: configuration.benchmarkContract,
            runtimeEnvelopeHash: configuration.runtimeEnvelopeHash,
            promptArchitectureReference: configuration.promptArchitectureReference,
            capabilities: configuration.capabilities,
            constraints: parsedBrowserConstraints(browserConstraintsRaw),
            whyEligible: card.whyRecommended,
            source: "safeclash_browser"
        )
    }

    private func benchmarkSummary(for request: DeployConfigurationRequest) -> String {
        "benchmark \(String(format: "%.2f", request.benchmarkScore)) · ranking \(String(format: "%.2f", request.rankingScore))"
    }

    private func constraintsSummary(for request: DeployConfigurationRequest) -> String {
        if request.constraints.isEmpty {
            return "No additional constraints"
        }
        return request.constraints.keys.sorted().compactMap { key in
            guard let value = request.constraints[key], !value.isEmpty else { return nil }
            return "\(key)=\(value)"
        }.joined(separator: ", ")
    }

    private func createGovernedBrowserDeploymentProposal(request: DeployConfigurationRequest) {
        guard browserDeployingConfigId == nil else { return }
        browserDeployingConfigId = request.configId
        browserLastCreatedProposalId = nil

        Task {
            let resolved = await resolveEndpoint()
            guard let token = resolved.token, !token.isEmpty else {
                await MainActor.run {
                    browserDeployingConfigId = nil
                    browserActionErrorMessage = "Geen token beschikbaar. Voeg een token toe in Instellingen."
                    showBrowserActionError = true
                }
                return
            }

            let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)

            do {
                let response = try await client.deployCertifiedConfiguration(deployment: request)
                await poller.refresh(gateway: gateway)
                await MainActor.run {
                    browserDeployingConfigId = nil
                    browserLastCreatedProposalId = response.proposalId
                    if let proposalId = response.proposalId, !proposalId.isEmpty {
                        browserDeploymentProposalByConfigId[request.configId] = proposalId
                    }
                    let summary = response.summary
                        ?? "Governed deployment proposal created for \(request.configId)."
                    let nextStep = response.nextStep ?? "Approval is required before activation."
                    browserStatusMessage = "\(summary) \(nextStep)"
                }
            } catch {
                await MainActor.run {
                    browserDeployingConfigId = nil
                    browserActionErrorMessage = describeBrowserDeployFailure(error, host: resolved.host, port: resolved.port)
                    showBrowserActionError = true
                }
            }
        }
    }

    private func safeClashClient() -> SafeClashClient {
        let token = gateway.token?.trimmingCharacters(in: .whitespacesAndNewlines)
        return SafeClashClient(
            baseURL: resolveSafeClashBaseURL(),
            token: (token?.isEmpty == false) ? token : nil
        )
    }

    private func resolveSafeClashBaseURL() -> URL {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["SAFECLASH_BASE_URL"] ?? env["SAFECLASH_URL"],
           let url = URL(string: raw),
           let scheme = url.scheme,
           (scheme == "http" || scheme == "https"),
           url.host != nil {
            return url
        }

        var components = URLComponents()
        components.scheme = "http"
        if !gateway.host.isEmpty, gateway.host.lowercased() != "mock" {
            components.host = gateway.host
            components.port = gateway.port > 0 ? gateway.port : 19001
        } else if let runtimeHost = RuntimeConfig.shared.host {
            components.host = runtimeHost
            components.port = RuntimeConfig.shared.port ?? 19001
        } else {
            components.host = "localhost"
            components.port = 19001
        }
        return components.url ?? URL(string: "http://localhost:19001")!
    }

    private func parsedBrowserConstraints(_ raw: String) -> [String: String] {
        var values: [String: String] = [:]
        let entries = raw.split(separator: ",")
        for entry in entries {
            let pair = entry.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard pair.count == 2, !pair[0].isEmpty, !pair[1].isEmpty else { continue }
            values[pair[0]] = pair[1]
        }
        return values
    }

    private func describeSafeClashFailure(_ error: Error) -> String {
        if case SafeClashClientError.httpStatus(let status) = error {
            return "SafeClash browser query failed (\(status))."
        }
        return "SafeClash browser feed unavailable."
    }

    private func describeBrowserDeployFailure(_ error: Error, host: String, port: Int) -> String {
        if case GatewayClientError.httpStatus(let status) = error {
            switch status {
            case 400, 422:
                return "Deployment proposal rejected: missing or invalid certified configuration provenance."
            case 401:
                return "Token ongeldig of verlopen voor \(host):\(port)."
            case 403:
                return "Governed deployment proposal blocked by policy."
            case 404:
                return "Canonical deploy route not available on \(host):\(port)."
            default:
                return "Proposal creation failed with backend status \(status)."
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotFindHost, .cannotConnectToHost, .timedOut, .networkConnectionLost:
                return "Backend onbereikbaar op \(host):\(port)."
            default:
                break
            }
        }
        return "Aanmaken van governed deployment proposal mislukt."
    }

    private func browserLifecycle(for card: BrowserCard, configuration: AIConfigurationAtom) -> DeploymentLifecycle {
        let matchingKnowledge = deploymentKnowledgeObjects(
            configId: configuration.configId,
            intentionId: card.intentionId
        )
        let latestKnowledge = matchingKnowledge
            .sorted { lhs, rhs in
                let lhsDate = lhs.createdAt ?? .distantPast
                let rhsDate = rhs.createdAt ?? .distantPast
                if lhsDate != rhsDate { return lhsDate > rhsDate }
                return lhs.objectId < rhs.objectId
            }
            .first

        let source = "SafeClash Registry"
        let proposalHint = browserDeploymentProposalByConfigId[configuration.configId]
            ?? proposalIdHint(from: latestKnowledge)

        let fallbackAction = (
            kind: latestKnowledge.flatMap { metadataString(for: $0, keys: ["action_kind", "actionKind"]) },
            id: latestKnowledge.flatMap { metadataString(for: $0, keys: ["action_id", "actionId"]) },
            state: latestKnowledge.flatMap { metadataString(for: $0, keys: ["execution_state", "executionState", "action_state", "actionState"]) },
            atIso: latestKnowledge.flatMap { metadataString(for: $0, keys: ["action_at_iso", "actionAtIso", "completed_at_iso", "completedAtIso"]) }
        )

        return buildDeploymentLifecycle(
            source: source,
            configId: configuration.configId,
            intentionId: card.intentionId,
            certificateId: configuration.certificateId,
            runtimeEnvelopeHash: configuration.runtimeEnvelopeHash,
            benchmarkContractId: configuration.benchmarkContract,
            proposalHint: proposalHint,
            fallbackAction: fallbackAction,
            knowledgeObject: latestKnowledge
        )
    }

    private func lifecycleFromKnowledgeObject(_ object: KnowledgeObject) -> DeploymentLifecycle? {
        let configId = metadataString(for: object, keys: ["config_id", "configId"])
            ?? sourceRefValue(for: object, sourceTypeContains: ["config", "configuration"])
        let intentionId = metadataString(for: object, keys: ["intention_id", "intentionId"])
            ?? sourceRefValue(for: object, sourceTypeContains: ["intention"])

        guard isDeploymentKnowledgeObject(object, configId: configId, intentionId: intentionId) else {
            return nil
        }

        let resolvedConfigId = configId ?? "unknown-config-\(object.objectId)"
        let resolvedIntentionId = intentionId ?? "unknown-intention"
        let source = sourceLabel(for: object)
        let proposalHint = proposalIdHint(from: object) ?? browserDeploymentProposalByConfigId[resolvedConfigId]
        let fallbackAction = (
            kind: metadataString(for: object, keys: ["action_kind", "actionKind"]),
            id: metadataString(for: object, keys: ["action_id", "actionId"]),
            state: metadataString(for: object, keys: ["execution_state", "executionState", "action_state", "actionState"]),
            atIso: metadataString(for: object, keys: ["action_at_iso", "actionAtIso", "completed_at_iso", "completedAtIso"])
        )

        return buildDeploymentLifecycle(
            source: source,
            configId: resolvedConfigId,
            intentionId: resolvedIntentionId,
            certificateId: metadataString(for: object, keys: ["certificate_id", "certificateId"]),
            runtimeEnvelopeHash: metadataString(for: object, keys: ["runtime_envelope_hash", "runtimeEnvelopeHash"]),
            benchmarkContractId: metadataString(for: object, keys: ["benchmark_contract_id", "benchmarkContractId"]),
            proposalHint: proposalHint,
            fallbackAction: fallbackAction,
            knowledgeObject: object
        )
    }

    private func buildDeploymentLifecycle(
        source: String,
        configId: String,
        intentionId: String,
        certificateId: String?,
        runtimeEnvelopeHash: String?,
        benchmarkContractId: String?,
        proposalHint: String?,
        fallbackAction: (kind: String?, id: String?, state: String?, atIso: String?),
        knowledgeObject: KnowledgeObject?
    ) -> DeploymentLifecycle {
        let proposalId = proposalHint
        let proposal = poller.proposals.first(where: { $0.proposalId == proposalId })
            ?? poller.pendingProposals.first(where: { $0.proposalId == proposalId })
        let decided = poller.decidedProposals.first(where: { $0.proposalId == proposalId })
        let action = decided?.action
        let receipt = action?.receipt

        let actionKind = action?.actionKind ?? fallbackAction.kind
        let actionId = action?.actionId ?? fallbackAction.id
        let actionState = action?.executionState ?? fallbackAction.state
        let actionAtIso = receipt?.completedAtIso ?? fallbackAction.atIso

        return DeploymentLifecycle(
            source: source,
            configId: configId,
            intentionId: intentionId,
            certificateId: certificateId,
            runtimeEnvelopeHash: runtimeEnvelopeHash,
            benchmarkContractId: benchmarkContractId,
            proposalId: proposalId,
            proposalCreatedAtIso: proposal?.createdAtIso ?? metadataString(for: knowledgeObject, keys: ["proposal_created_at_iso", "proposalCreatedAtIso"]),
            approvalDecision: decided?.status,
            approvalActor: receipt?.actor,
            approvalAtIso: decided?.decidedAtIso,
            actionKind: actionKind,
            actionId: actionId,
            actionState: actionState,
            actionAtIso: actionAtIso,
            knowledgeKind: knowledgeObject?.kind,
            knowledgeId: knowledgeObject?.objectId,
            knowledgeAtIso: knowledgeObject?.createdAtIso
        )
    }

    private func deploymentKnowledgeObjects(configId: String, intentionId: String) -> [KnowledgeObject] {
        poller.recentKnowledgeObjects.filter { object in
            isDeploymentKnowledgeObject(object, configId: configId, intentionId: intentionId)
        }
    }

    private func isDeploymentKnowledgeObject(_ object: KnowledgeObject, configId: String?, intentionId: String?) -> Bool {
        let kind = object.kind.lowercased()
        if kind.contains("configuration_deployment") {
            return true
        }
        if kind.contains("deployment"), sourceLabel(for: object).lowercased().contains("safeclash") {
            return true
        }
        if let configId, !configId.isEmpty {
            if metadataString(for: object, keys: ["config_id", "configId"]) == configId {
                return true
            }
            if sourceRefContains(object: object, value: configId) {
                return true
            }
        }
        if let intentionId, !intentionId.isEmpty,
           metadataString(for: object, keys: ["intention_id", "intentionId"]) == intentionId {
            return true
        }
        if metadataString(for: object, keys: ["source"]) == "safeclash_browser" {
            return true
        }
        return false
    }

    private func sourceLabel(for object: KnowledgeObject) -> String {
        if let source = metadataString(for: object, keys: ["source", "origin_source"]), !source.isEmpty {
            if source.lowercased().contains("safeclash") {
                return "SafeClash Registry"
            }
            return source
        }
        if object.sourceRefs?.contains(where: { ref in
            ref.sourceType.lowercased().contains("safeclash")
                || ref.label?.lowercased().contains("safeclash") == true
        }) == true {
            return "SafeClash Registry"
        }
        return "SafeClash Registry"
    }

    private func sourceRefContains(object: KnowledgeObject, value: String) -> Bool {
        object.sourceRefs?.contains(where: { ref in
            ref.sourceId == value || ref.label == value
        }) == true
    }

    private func sourceRefValue(for object: KnowledgeObject, sourceTypeContains tokens: [String]) -> String? {
        object.sourceRefs?.first(where: { ref in
            let sourceType = ref.sourceType.lowercased()
            return tokens.contains(where: { sourceType.contains($0) })
        })?.sourceId
    }

    private func proposalIdHint(from object: KnowledgeObject?) -> String? {
        guard let object else { return nil }
        if let proposalId = metadataString(for: object, keys: ["proposal_id", "proposalId"]), !proposalId.isEmpty {
            return proposalId
        }
        if let fromSource = object.sourceRefs?.first(where: { ref in
            ref.sourceType.lowercased().contains("proposal")
                || ref.sourceId.lowercased().contains("proposal")
        })?.sourceId {
            return fromSource
        }
        if let linked = object.linkedObjectIds?.first(where: { $0.lowercased().contains("proposal") }) {
            return linked
        }
        return nil
    }

    private func openLifecycleProposal(proposalId: String) {
        selectedBrowserCard = nil
        selectedDecision = nil
        browserLastCreatedProposalId = proposalId
        shouldScrollToDecisions = true
    }

    private func openLifecycleDecision(proposalId: String) {
        selectedBrowserCard = nil
        if let decision = poller.decidedProposals.first(where: { $0.proposalId == proposalId }) {
            selectedDecision = decision
        } else {
            shouldScrollToDecisions = true
        }
    }

    private func openLifecycleKnowledge(objectId: String) {
        selectedBrowserCard = nil
        fetchAndShowKnowledgeGraph(objectId: objectId)
    }

    // MARK: - Pending Queue

    @ViewBuilder
    private var pendingQueueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: TextKeys.Lobby.pendingQueue,
                icon: "tray.full",
                count: poller.pendingProposals.count,
                tint: .jeevesGold
            )

            if isBackendUnavailable {
                backendUnavailableCard
            } else if poller.pendingProposals.isEmpty {
                emptyQueueCard
            } else {
                cardStack
            }
        }
    }

    private var emptyQueueCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.jeevesTitle)
                .foregroundStyle(.secondary)
            Text(TextKeys.Lobby.noProposals)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlRoomPanel()
    }

    private var backendUnavailableCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.jeevesTitle)
                    .foregroundStyle(.secondary)
                Text("Backend niet beschikbaar")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let message = unavailableMessage {
                Text(message)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .controlRoomPanel()
    }

    private var cardStack: some View {
        VStack(spacing: 20) {
            if let topProposal = poller.pendingProposals.first {
                SwipeCard(
                    proposal: topProposal,
                    isTop: true,
                    isDecisionInFlight: decidingProposalId != nil,
                    onSwipe: { direction in
                        handleSwipe(proposal: topProposal, direction: direction)
                    }
                )
                .id(topProposal.id)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                HStack(spacing: 16) {
                    Button {
                        handleSwipe(proposal: topProposal, direction: .left)
                    } label: {
                        Text(TextKeys.Lobby.deny)
                            .font(.jeevesHeadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.consentRed.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(decidingProposalId != nil)

                    Button {
                        handleSwipe(proposal: topProposal, direction: .right)
                    } label: {
                        Text(TextKeys.Lobby.approve)
                            .font(.jeevesHeadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.consentGreen.opacity(0.88))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(decidingProposalId != nil)
                }

                if decidingProposalId != nil {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Beslissing wordt bevestigd bij backend...")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .animation(.spring(response: 0.4), value: poller.pendingProposals.first?.id)
    }

    // MARK: - Extension Proposals

    @ViewBuilder
    private var extensionProposalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: TextKeys.Lobby.extensionProposals,
                icon: "puzzlepiece.extension",
                count: pendingExtensionProposals.count,
                tint: .jeevesGold
            )

            if pendingExtensionProposals.isEmpty {
                extensionEmptyCard
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(pendingExtensionProposals) { proposal in
                        ExtensionProposalCard(
                            proposal: proposal,
                            isActionInFlight: decidingExtensionId == proposal.extensionId || loadingManifestExtensionId == proposal.extensionId,
                            onApprove: { approveExtension(proposal) },
                            onReject: { rejectExtension(proposal) },
                            onInspectManifest: { inspectExtensionManifest(proposal) }
                        )
                    }
                }
            }

            if poller.extensionUsesDemoFallback {
                Text(TextKeys.Lobby.extensionDemoFallback)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var extensionEmptyCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension")
                .font(.jeevesTitle)
                .foregroundStyle(.secondary)
            Text(TextKeys.Lobby.noExtensionProposals)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlRoomPanel()
    }

    // MARK: - Recent Decisions

    @ViewBuilder
    private var recentDecisionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: TextKeys.Lobby.recentDecisions,
                icon: "checkmark.rectangle.stack",
                count: nil,
                tint: .jeevesGold
            )

            if poller.decidedProposals.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.jeevesTitle)
                        .foregroundStyle(.secondary)
                    Text(TextKeys.Lobby.noDecisions)
                        .font(.jeevesBody)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .controlRoomPanel()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(poller.decidedProposals) { decision in
                        DecidedProposalRow(decision: decision)
                            .onTapGesture {
                                selectedDecision = decision
                            }
                    }
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String, count: Int?, tint: Color = .jeevesGold) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.jeevesHeadline.weight(.semibold))
                .foregroundStyle(.white)
            if let count, count > 0 {
                Text("\(count)")
                    .font(.jeevesCaption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(tint)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    private func statusChip(label: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(label)
        }
        .font(.jeevesCaption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.18))
        .foregroundStyle(tint)
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func handleSwipe(proposal: Proposal, direction: SwipeDirection) {
        guard decidingProposalId == nil else { return }
        let decision = direction == .right ? "approve" : "deny"

        if proposal.intent.risk == "orange" {
            pendingDecision = (proposal.proposalId, decision)
            showOrangeConfirm = true
            return
        }

        executeDecision(proposalId: proposal.proposalId, decision: decision)
    }

    private func executeDecision(proposalId: String, decision: String) {
        if decision == "approve" {
            JeevesHaptics.approved()
        } else {
            JeevesHaptics.swipeDeny()
        }

        let reason = decision == "approve" ? TextKeys.Lobby.approveReason : TextKeys.Lobby.denyReason
        decidingProposalId = proposalId
        Task {
            let result = await poller.decide(
                proposalId: proposalId,
                decision: decision,
                reason: reason,
                gateway: gateway
            )
            await MainActor.run {
                decidingProposalId = nil
                switch result {
                case .success:
                    if decision == "approve" && poller.lastActionReceipt != nil {
                        showActionReceipt = true
                    }
                case .failure(let message):
                    decisionErrorMessage = message
                    showDecisionError = true
                }
            }
        }

        pendingDecision = nil
    }

    private func approveExtension(_ proposal: ExtensionProposal) {
        performExtensionDecision(proposal: proposal, approve: true)
    }

    private func rejectExtension(_ proposal: ExtensionProposal) {
        performExtensionDecision(proposal: proposal, approve: false)
    }

    private func performExtensionDecision(proposal: ExtensionProposal, approve: Bool) {
        guard decidingExtensionId == nil else { return }
        decidingExtensionId = proposal.extensionId

        Task {
            let resolved = await resolveEndpoint()
            guard let token = resolved.token, !token.isEmpty else {
                await MainActor.run {
                    decidingExtensionId = nil
                    extensionActionErrorMessage = "Geen token beschikbaar. Voeg een token toe in Instellingen."
                    showExtensionActionError = true
                }
                return
            }

            let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)
            do {
                let decision = try await (approve
                    ? client.approveExtension(id: proposal.extensionId)
                    : client.rejectExtension(id: proposal.extensionId))
                await poller.refresh(gateway: gateway)
                await MainActor.run {
                    extensionDecisions[proposal.extensionId] = decision
                    decidingExtensionId = nil
                }
                await MainActor.run {
                    inspectExtensionManifest(proposal)
                }
            } catch {
                await MainActor.run {
                    decidingExtensionId = nil
                    extensionActionErrorMessage = describeExtensionActionFailure(
                        error,
                        host: resolved.host,
                        port: resolved.port
                    )
                    showExtensionActionError = true
                }
            }
        }
    }

    private func inspectExtensionManifest(_ proposal: ExtensionProposal) {
        guard loadingManifestExtensionId == nil else { return }
        loadingManifestExtensionId = proposal.extensionId

        Task {
            let fallbackDecision = extensionDecisions[proposal.extensionId]
            let fallbackManifest = ExtensionManifest(
                proposal: proposal,
                receipt: fallbackDecision?.receipt,
                auditTrail: fallbackDecision.map { [$0] } ?? []
            )

            if isMockMode || poller.extensionUsesDemoFallback {
                await MainActor.run {
                    selectedExtensionManifest = fallbackManifest
                    loadingManifestExtensionId = nil
                }
                return
            }

            let resolved = await resolveEndpoint()
            guard let token = resolved.token, !token.isEmpty else {
                await MainActor.run {
                    selectedExtensionManifest = fallbackManifest
                    loadingManifestExtensionId = nil
                }
                return
            }

            let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)
            do {
                let fetched = try await client.fetchExtension(id: proposal.extensionId)
                let merged = mergeManifestWithCachedDecision(fetched)
                await MainActor.run {
                    selectedExtensionManifest = merged
                    loadingManifestExtensionId = nil
                }
            } catch {
                await MainActor.run {
                    selectedExtensionManifest = fallbackManifest
                    loadingManifestExtensionId = nil
                }
            }
        }
    }

    private func mergeManifestWithCachedDecision(_ manifest: ExtensionManifest) -> ExtensionManifest {
        guard let cached = extensionDecisions[manifest.extensionId] else { return manifest }
        let mergedAuditTrail = manifest.auditTrail.isEmpty ? [cached] : manifest.auditTrail
        let mergedReceipt = manifest.receipt ?? cached.receipt
        return ExtensionManifest(
            extensionId: manifest.extensionId,
            title: manifest.title,
            purpose: manifest.purpose,
            capabilities: manifest.capabilities,
            risk: manifest.risk,
            codeHash: manifest.codeHash,
            entrypoint: manifest.entrypoint,
            status: manifest.status,
            approvedAtIso: manifest.approvedAtIso ?? cached.approvedAtIso,
            loadedAtIso: manifest.loadedAtIso ?? cached.loadedAtIso,
            sourceType: manifest.sourceType,
            linkedCells: manifest.linkedCells,
            reasoningTrace: manifest.reasoningTrace,
            knowledgeLinks: manifest.knowledgeLinks,
            auditTrail: mergedAuditTrail,
            receipt: mergedReceipt
        )
    }

    private func fetchAndShowKnowledgeGraph(objectId: String) {
        loadingKnowledgeGraph = true
        knowledgeGraphData = nil
        showKnowledgeGraph = true

        Task {
            guard !isMockMode else {
                await MainActor.run {
                    knowledgeGraphData = KnowledgeGraphResponse(
                        ok: true,
                        root: KnowledgeObject(
                            objectId: objectId,
                            kind: "decision",
                            createdAtIso: ISO8601DateFormatter().string(from: Date()),
                            title: "Demo kennisgraaf object",
                            summary: "Dit is een demo object uit de kennisgraaf.",
                            sourceRefs: nil,
                            linkedObjectIds: ["linked-1", "linked-2"],
                            metadata: nil
                        ),
                        linked: [
                            KnowledgeObject(
                                objectId: "linked-1",
                                kind: "action_receipt",
                                createdAtIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-300)),
                                title: "Actie-ontvangstbewijs: residue analyse",
                                summary: "Analyse van residue patronen voltooid met 8 signalen.",
                                sourceRefs: nil,
                                linkedObjectIds: nil,
                                metadata: nil
                            ),
                            KnowledgeObject(
                                objectId: "linked-2",
                                kind: "investigation_outcome",
                                createdAtIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-600)),
                                title: "Onderzoeksresultaat: anomalie patroon",
                                summary: "Cross-domain anomalie onderzocht, geen escalatie nodig.",
                                sourceRefs: nil,
                                linkedObjectIds: nil,
                                metadata: nil
                            ),
                        ],
                        edges: nil
                    )
                    loadingKnowledgeGraph = false
                }
                return
            }

            let resolved = await resolveEndpoint()
            guard let token = resolved.token, !token.isEmpty else {
                await MainActor.run { loadingKnowledgeGraph = false }
                return
            }

            let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)
            do {
                let graph = try await client.fetchKnowledgeGraph(objectId: objectId)
                await MainActor.run {
                    knowledgeGraphData = graph
                    loadingKnowledgeGraph = false
                }
            } catch {
                await MainActor.run { loadingKnowledgeGraph = false }
            }
        }
    }

    private func fetchAndShowExtensionGraph(extensionId: String) {
        loadingKnowledgeGraph = true
        knowledgeGraphData = nil
        showKnowledgeGraph = true

        Task {
            guard !isMockMode else {
                await MainActor.run {
                    knowledgeGraphData = demoExtensionGraph(extensionId: extensionId)
                    loadingKnowledgeGraph = false
                }
                return
            }

            let resolved = await resolveEndpoint()
            guard let token = resolved.token, !token.isEmpty else {
                await MainActor.run {
                    knowledgeGraphData = demoExtensionGraph(extensionId: extensionId)
                    loadingKnowledgeGraph = false
                }
                return
            }

            let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)
            do {
                let graph = try await client.fetchExtensionGraph(id: extensionId)
                await MainActor.run {
                    knowledgeGraphData = graph
                    loadingKnowledgeGraph = false
                }
            } catch {
                await MainActor.run {
                    knowledgeGraphData = demoExtensionGraph(extensionId: extensionId)
                    loadingKnowledgeGraph = false
                }
            }
        }
    }

    private func demoExtensionGraph(extensionId: String) -> KnowledgeGraphResponse {
        let now = ISO8601DateFormatter().string(from: Date())
        let root = KnowledgeObject(
            objectId: "extension-proposal-\(extensionId)",
            kind: "extension_proposal",
            createdAtIso: now,
            title: "Extension proposal \(extensionId)",
            summary: "Demo kennisgraaf voor extension review.",
            sourceRefs: nil,
            linkedObjectIds: [
                "extension-decision-\(extensionId)",
                "extension-manifest-\(extensionId)",
                "extension-receipt-\(extensionId)"
            ],
            metadata: nil
        )
        let linked: [KnowledgeObject] = [
            KnowledgeObject(
                objectId: "extension-decision-\(extensionId)",
                kind: "extension_decision",
                createdAtIso: now,
                title: "Decision \(extensionId)",
                summary: "Beslissing geregistreerd in demo modus.",
                sourceRefs: nil,
                linkedObjectIds: nil,
                metadata: nil
            ),
            KnowledgeObject(
                objectId: "extension-manifest-\(extensionId)",
                kind: "extension_manifest",
                createdAtIso: now,
                title: "Manifest \(extensionId)",
                summary: "Manifest geannoteerd met capabilities en risico.",
                sourceRefs: nil,
                linkedObjectIds: nil,
                metadata: nil
            ),
            KnowledgeObject(
                objectId: "extension-receipt-\(extensionId)",
                kind: "extension_receipt",
                createdAtIso: now,
                title: "Receipt \(extensionId)",
                summary: "Uitvoering niet automatisch geladen; alleen goedkeuring vastgelegd.",
                sourceRefs: nil,
                linkedObjectIds: nil,
                metadata: nil
            ),
        ]
        return KnowledgeGraphResponse(ok: true, root: root, linked: linked, edges: nil)
    }

    private func describeExtensionActionFailure(_ error: Error, host: String, port: Int) -> String {
        if case GatewayClientError.httpStatus(let status) = error {
            switch status {
            case 401:
                return "Token ongeldig of verlopen voor \(host):\(port)."
            case 404:
                return "Extension niet gevonden of al verwerkt."
            default:
                return "Backend fout (\(status)) op \(host):\(port)."
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotFindHost, .cannotConnectToHost, .timedOut, .networkConnectionLost:
                return "Backend onbereikbaar op \(host):\(port)."
            default:
                break
            }
        }
        return "Extension actie mislukt."
    }

    private func resolveEndpoint() async -> (host: String, port: Int, token: String?) {
        let host = gateway.host.isEmpty ? "localhost" : gateway.host
        let port = gateway.port > 0 ? gateway.port : 19001
        let token = gateway.token
        return (host, port, token)
    }

    private var isBackendUnavailable: Bool {
        !isMockMode && !gateway.isConnected
    }

    private var isMockMode: Bool {
        gateway.useMock || gateway.host.lowercased() == "mock"
    }

    private var unavailableMessage: String? {
        if isBackendUnavailable {
            return poller.lastRefreshError ?? "Geen actieve verbinding met de echte backend."
        }
        return nil
    }

    private var browserSurfaceNavigationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Browser Extensions")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)
            Text("Mission Control remains the cockpit. AI Browser, Deployments, and Marketplace are added as companion surfaces.")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                browserSurfaceButton(
                    title: "AI Browser",
                    subtitle: "Discovery",
                    icon: "sparkle.magnifyingglass",
                    tint: .blue,
                    zone: .aiBrowser
                )
                browserSurfaceButton(
                    title: "Deployments",
                    subtitle: "Governed flow",
                    icon: "shippingbox.circle",
                    tint: .consentGreen,
                    zone: .deployments
                )
                browserSurfaceButton(
                    title: "Marketplace",
                    subtitle: "Certified shelf",
                    icon: "storefront",
                    tint: .cyan,
                    zone: .marketplace
                )
            }
        }
        .controlRoomPanel(padding: 12)
    }

    private func browserSurfaceButton(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        zone: MissionZone
    ) -> some View {
        Button {
            requestedZoneAnchor = zone.anchorId
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.jeevesCaption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var marketplaceOverviewPanel: some View {
        let featured = featuredCertifiedCards
        let categories = browserFeedCategories
        let certifiedCount = certifiedCatalogCards.count
        let emergingCount = filteredEmergingIntentions.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                marketplaceMetric(label: "Featured", value: "\(featured.count)")
                marketplaceMetric(label: "Categories", value: "\(categories.count)")
                marketplaceMetric(label: "Certified", value: "\(certifiedCount)")
                marketplaceMetric(label: "Emerging", value: "\(emergingCount)")
            }

            if featured.isEmpty {
                Text("No featured shelf loaded yet. Run a category search in AI Browser to populate Marketplace.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(featured.prefix(3)) { card in
                        HStack(spacing: 8) {
                            Image(systemName: card.deployReady ? "checkmark.seal.fill" : "clock")
                                .foregroundStyle(card.deployReady ? Color.consentGreen : Color.consentOrange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.title)
                                    .font(.jeevesCaption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text("\(card.domain) / \(card.subdomain)")
                                    .font(.jeevesCaption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(String(format: "%.2f", card.rankingScore))
                                .font(.jeevesMono)
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button("Open AI Browser") {
                    requestedZoneAnchor = MissionZone.aiBrowser.anchorId
                }
                .buttonStyle(.bordered)

                Button("Refresh Marketplace") {
                    runSafeClashSearch()
                }
                .buttonStyle(.bordered)
            }
        }
        .controlRoomPanel(padding: 12)
    }

    private func marketplaceMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.jeevesCaption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.jeevesMono.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var deploymentsOverviewPanel: some View {
        let recent = Array(poller.decidedProposals.prefix(5))
        let approved = poller.decidedProposals.filter(\.isApproved).count
        let denied = poller.decidedProposals.filter(\.isDenied).count

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                marketplaceMetric(label: "Pending", value: "\(queueSize)")
                marketplaceMetric(label: "Approved", value: "\(approved)")
                marketplaceMetric(label: "Denied", value: "\(denied)")
                marketplaceMetric(label: "Today", value: "\(decisionsToday)")
            }

            if recent.isEmpty {
                Text("No deployment decisions yet. Governed actions will appear here after proposal decisions.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recent) { decision in
                        HStack(spacing: 8) {
                            Image(systemName: decision.isApproved ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(decision.isApproved ? Color.consentGreen : Color.consentRed)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(decision.title)
                                    .font(.jeevesCaption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(decision.proposalId)
                                    .font(.jeevesCaption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(relativeDateLabel(iso: decision.decidedAtIso))
                                .font(.jeevesCaption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Button("Open Decisions") {
                    requestedZoneAnchor = MissionZone.decisions.anchorId
                }
                .buttonStyle(.bordered)

                Button("Open Knowledge") {
                    requestedZoneAnchor = MissionZone.knowledge.anchorId
                }
                .buttonStyle(.bordered)
            }
        }
        .controlRoomPanel(padding: 12)
    }

    private func relativeDateLabel(iso: String?) -> String {
        guard let iso, let date = parseISODate(iso) else {
            return "unknown"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func openObservatory() {
        NotificationCenter.default.post(name: .jeevesOpenObservatoryTab, object: nil)
    }
}

private struct RadarSignalSummary: Identifiable {
    let id: String
    let title: String
    let what: String
    let whereValue: String
    let timeAxis: String
    let score: Double
    let linkedCells: [String]
    let explanation: String
    let timestampIso: String?
    let linkedProposalLabel: String?
}

private struct RadarSignalCard: View {
    let signal: RadarSignalSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(signal.title)
                        .font(.jeevesHeadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    scoreChip
                }

                Text("\(signal.what) / \(signal.whereValue) / \(signal.timeAxis)")
                    .font(.jeevesMono)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("CLASHD27")
                        .font(.jeevesCaption.weight(.medium))
                        .foregroundStyle(Color.jeevesGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.jeevesGold.opacity(0.16))
                        .clipShape(Capsule())

                    Text("cells \(signal.linkedCells.joined(separator: ", "))")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let linked = signal.linkedProposalLabel {
                        Text(linked)
                            .font(.jeevesCaption.weight(.medium))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.14))
                            .clipShape(Capsule())
                            .lineLimit(1)
                    }
                }

                Text(signal.explanation)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    if let lastSeen = relativeTimestampLabel {
                        Text(lastSeen)
                            .font(.jeevesCaption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("Open Observatory →")
                        .font(.jeevesCaption)
                        .foregroundStyle(Color.jeevesGold)
                }
            }
            .controlRoomPanel(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private var scoreChip: some View {
        Text("score \(String(format: "%.2f", signal.score))")
            .font(.jeevesCaption.weight(.medium))
            .foregroundStyle(.teal)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.teal.opacity(0.14))
            .clipShape(Capsule())
    }

    private var relativeTimestampLabel: String? {
        guard let iso = signal.timestampIso else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "seen \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

private struct RadarSignalDetailSheet: View {
    let signal: RadarSignalSummary
    let relatedProposals: [ExtensionProposal]
    let onOpenApprovalCard: (ExtensionProposal) -> Void
    let onOpenObservatory: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(signal.title)
                            .font(.jeevesTitle.weight(.semibold))
                            .foregroundStyle(.white)

                        detailRow(label: "WHAT", value: signal.what)
                        detailRow(label: "WHERE", value: signal.whereValue)
                        detailRow(label: "TIME", value: signal.timeAxis)
                        detailRow(label: "Score", value: String(format: "%.2f", signal.score))
                        detailRow(label: "Cells", value: signal.linkedCells.joined(separator: ", "))
                        detailRow(label: "Source", value: "CLASHD27")

                        Text(signal.explanation)
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        relatedProposalsSection

                        Button("Open Observatory →") {
                            onOpenObservatory()
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlRoomPanel()
                    .padding()
                }
            }
            .navigationTitle("Radar Signal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var relatedProposalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related approvals")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)

            if relatedProposals.isEmpty {
                Text("No linked extension proposal in queue yet.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(relatedProposals) { proposal in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(proposal.title)
                            .font(.jeevesBody)
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text(proposal.purpose)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack {
                            Text("risk \(proposal.risk.lowercased())")
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Open approval card") {
                                onOpenApprovalCard(proposal)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}

private struct BrowserGuidancePanel: View {
    let brief: BrowserGuidanceBrief

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Browser Guidance")
                    .font(.jeevesHeadline)
                    .foregroundStyle(.white)
                Spacer()
                Text(brief.state.rawValue.uppercased())
                    .font(.jeevesCaption2.weight(.semibold))
                    .foregroundStyle(stateTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stateTint.opacity(0.18))
                    .clipShape(Capsule())
            }

            Text("Not knowing → compare evidence → explain → propose next step.")
                .font(.jeevesCaption2)
                .foregroundStyle(.secondary)

            section(title: "What seems clear", rows: brief.clear)
            section(title: "What is still uncertain", rows: brief.uncertain)
            section(title: "Best current options", rows: brief.options)
            section(title: "Why these options appear", rows: brief.why)
            section(title: "What should happen next", rows: brief.next)
        }
    }

    private var stateTint: Color {
        switch brief.state {
        case .confirmed:
            return .consentGreen
        case .strongCandidate:
            return .cyan
        case .exploratory:
            return .consentOrange
        case .unknown:
            return .secondary
        }
    }

    private func section(title: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.jeevesCaption.weight(.semibold))
                .foregroundStyle(.white)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Text("• \(row)")
                    .font(.jeevesCaption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FeaturedAICard: View {
    let card: BrowserCard
    let isDeploying: Bool
    let onInspect: () -> Void
    let onDeploy: () -> Void

    private var certificationColor: Color {
        switch card.bestConfiguration.certificationLevel.lowercased() {
        case "gold":
            return .consentGreen
        case "silver":
            return .cyan
        case "bronze":
            return .consentOrange
        default:
            return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Featured AI")
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(.cyan)
                Spacer()
                Text(card.uncertaintyState.rawValue.uppercased())
                    .font(.jeevesCaption2.weight(.semibold))
                    .foregroundStyle(uncertaintyTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(uncertaintyTint.opacity(0.16))
                    .clipShape(Capsule())
                Text(card.bestConfiguration.certificationLevel.uppercased())
                    .font(.jeevesCaption2.weight(.semibold))
                    .foregroundStyle(certificationColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(certificationColor.opacity(0.16))
                    .clipShape(Capsule())
            }

            Text(card.title)
                .font(.jeevesTitle.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(card.intentionPath)
                .font(.jeevesMono)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(card.shortDescription)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(card.whyRecommended)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(card.uncertaintyNarrative)
                .font(.jeevesCaption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                statChip(text: "score \(String(format: "%.2f", card.rankingScore))", tint: .cyan)
                statChip(text: card.benchmarkSummary, tint: .blue)
                statChip(text: card.bestConfiguration.model, tint: .secondary)
            }

            Text(card.deployReady ? "Ready for governed deployment proposal." : "Deploy readiness pending certification envelope.")
                .font(.jeevesCaption2)
                .foregroundStyle(card.deployReady ? Color.consentGreen : .consentOrange)

            HStack(spacing: 8) {
                Button("Inspect") {
                    onInspect()
                }
                .buttonStyle(.bordered)

                Button("Deploy via proposal") {
                    onDeploy()
                }
                .buttonStyle(.borderedProminent)
                .tint(.consentGreen)
                .disabled(isDeploying || !card.deployReady)

                if isDeploying {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .controlRoomPanel(padding: 14)
    }

    private var uncertaintyTint: Color {
        switch card.uncertaintyState {
        case .confirmed:
            return .consentGreen
        case .strongCandidate:
            return .cyan
        case .exploratory:
            return .consentOrange
        case .unknown:
            return .secondary
        }
    }

    private func statChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(.jeevesCaption2.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct AIBrowserResultCard: View {
    let card: BrowserCard
    let emergingMomentumCount: Int
    let isDeploying: Bool
    let onOpen: () -> Void
    let onDeploy: () -> Void

    private var certificationColor: Color {
        switch card.bestConfiguration.certificationLevel.lowercased() {
        case "gold":
            return .consentGreen
        case "silver":
            return .blue
        case "bronze":
            return .consentOrange
        default:
            return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.jeevesHeadline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(card.intentionPath)
                        .font(.jeevesMono)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                capsule(text: card.uncertaintyState.rawValue, tint: uncertaintyTint)
                capsule(text: card.bestConfiguration.certificationLevel, tint: certificationColor)
                capsule(text: card.deployReady ? "READY" : "PENDING", tint: card.deployReady ? .consentGreen : .consentOrange)
            }

            Text(card.shortDescription)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(card.whyRecommended)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(card.uncertaintyNarrative)
                .font(.jeevesCaption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                metricChip(text: "score \(String(format: "%.2f", card.rankingScore))", tint: .cyan)
                metricChip(text: card.benchmarkSummary, tint: .blue)
                metricChip(text: card.bestConfiguration.model, tint: .secondary)
            }

            Text(card.deployReady ? "Deploy readiness: governed proposal available." : "Deploy readiness: awaiting certification envelope.")
                .font(.jeevesCaption2)
                .foregroundStyle(card.deployReady ? Color.consentGreen : .consentOrange)

            if emergingMomentumCount > 0 {
                Text("Emerging momentum: \(emergingMomentumCount) related signal(s)")
                    .font(.jeevesCaption2)
                    .foregroundStyle(Color.consentOrange)
            }

            HStack(spacing: 8) {
                Button("Inspect") {
                    onOpen()
                }
                    .buttonStyle(.bordered)

                Button("Deploy via proposal") {
                    onDeploy()
                }
                .buttonStyle(.borderedProminent)
                .tint(.consentGreen)
                .disabled(isDeploying || !card.deployReady)

                if isDeploying {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .controlRoomPanel(padding: 12)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            onOpen()
        }
    }

    private var uncertaintyTint: Color {
        switch card.uncertaintyState {
        case .confirmed:
            return .consentGreen
        case .strongCandidate:
            return .cyan
        case .exploratory:
            return .consentOrange
        case .unknown:
            return .secondary
        }
    }

    private func capsule(text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.jeevesCaption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
    }

    private func metricChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(.jeevesCaption2.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct AIBrowserDetailSheet: View {
    let card: BrowserCard
    let configuration: AIConfigurationAtom
    let lifecycle: DeploymentLifecycle
    let isLoadingConfiguration: Bool
    let isDeploying: Bool
    let onRefreshConfiguration: () -> Void
    let onDeploy: () -> Void
    let onOpenProposal: (String) -> Void
    let onOpenDecision: (String) -> Void
    let onOpenKnowledgeArtifact: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(card.title)
                            .font(.jeevesTitle.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(card.shortDescription)
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)

                        metadataRow(label: "Intention path", value: card.intentionPath)
                        metadataRow(label: "Evidence state", value: card.uncertaintyState.rawValue)

                        metadataRow(label: "Config ID", value: configuration.configId)
                        metadataRow(label: "Model", value: configuration.model)
                        metadataRow(label: "Certification", value: configuration.certificationLevel)
                        metadataRow(label: "Ranking", value: String(format: "%.2f", configuration.rankingScore))
                        metadataRow(label: "Benchmark", value: String(format: "%.2f", configuration.benchmarkScore))
                        metadataRow(label: "Prompt architecture", value: configuration.promptArchitectureReference ?? "not provided")
                        metadataRow(label: "Capabilities", value: configuration.capabilities.joined(separator: ", "))
                        metadataRow(label: "Benchmark contract", value: configuration.benchmarkContract ?? "not provided")
                        metadataRow(label: "Runtime envelope", value: configuration.runtimeEnvelopeHash ?? "not provided")
                        metadataRow(label: "Publisher", value: configuration.publisherIdentity ?? "not provided")
                        metadataRow(label: "Pricing policy", value: configuration.pricingPolicy ?? "not provided")
                        if let certificate = card.certificateReference, !certificate.isEmpty {
                            metadataRow(label: "Certificate", value: certificate)
                        }
                        if let benchmarkContract = card.benchmarkContractReference, !benchmarkContract.isEmpty {
                            metadataRow(label: "Benchmark contract", value: benchmarkContract)
                        }
                        if let capabilities = card.capabilitiesSummary, !capabilities.isEmpty {
                            metadataRow(label: "Capabilities", value: capabilities)
                        }
                        if let constraints = card.constraintsSummary, !constraints.isEmpty {
                            metadataRow(label: "Constraints", value: constraints)
                        }

                        Text("Why recommended")
                            .font(.jeevesHeadline)
                            .foregroundStyle(.white)
                        Text(card.whyRecommended)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Text("Uncertainty")
                            .font(.jeevesHeadline)
                            .foregroundStyle(.white)
                        Text(card.uncertaintyNarrative)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        if let rankingExplanation = card.rankingExplanation, !rankingExplanation.isEmpty {
                            Text("Ranking explanation")
                            .font(.jeevesHeadline)
                            .foregroundStyle(.white)
                            Text(rankingExplanation)
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        LifecycleLineagePanel(
                            lifecycle: lifecycle,
                            onOpenProposal: { proposalId in
                                onOpenProposal(proposalId)
                                dismiss()
                            },
                            onOpenDecision: { proposalId in
                                onOpenDecision(proposalId)
                                dismiss()
                            },
                            onOpenKnowledgeArtifact: { objectId in
                                onOpenKnowledgeArtifact(objectId)
                                dismiss()
                            }
                        )

                        Text(card.deployReady
                             ? "Deploy creates a governed proposal. Human approval remains required before any action executes."
                             : "This item is certified for browsing but not deploy-ready yet. Governance deploy route stays locked until readiness is true.")
                            .font(.jeevesCaption2)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Button("Refresh config") {
                                onRefreshConfiguration()
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoadingConfiguration)

                            Button("Deploy via proposal") {
                                onDeploy()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.consentGreen)
                            .disabled(isDeploying || !card.deployReady)
                        }

                        if isLoadingConfiguration {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Loading configuration details...")
                                    .font(.jeevesCaption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if isDeploying {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Creating governed deployment proposal...")
                                    .font(.jeevesCaption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .controlRoomPanel()
                    .padding()
                }
            }
            .navigationTitle("AI Configuration")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 132, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(.white)
        }
    }
}

private struct BrowserDeployConfirmationSheet: View {
    let request: DeployConfigurationRequest
    let benchmarkSummary: String
    let constraintsSummary: String
    let isCreatingProposal: Bool
    let onCreateProposal: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Deploy this certified configuration?")
                            .font(.jeevesTitle.weight(.semibold))
                            .foregroundStyle(.white)

                        Text("This creates a governed proposal in openclashd. Execution can only happen after human approval.")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)

                        metadataRow(label: "Config ID", value: request.configId)
                        metadataRow(label: "Intention", value: "\(request.domain) / \(request.subdomain)")
                        metadataRow(label: "Certification", value: request.certificationLevel)
                        metadataRow(label: "Benchmark", value: benchmarkSummary)
                        metadataRow(label: "Constraints", value: constraintsSummary)
                        metadataRow(label: "Runtime envelope", value: abbreviatedHash(request.runtimeEnvelopeHash))
                        metadataRow(label: "Eligibility", value: request.whyEligible)
                        metadataRow(label: "Source", value: request.source)

                        if let certificateId = request.certificateId, !certificateId.isEmpty {
                            metadataRow(label: "Certificate ID", value: certificateId)
                        }
                        if let benchmarkContractId = request.benchmarkContractId, !benchmarkContractId.isEmpty {
                            metadataRow(label: "Benchmark contract", value: benchmarkContractId)
                        }

                        HStack(spacing: 8) {
                            Button("Cancel", role: .cancel) {
                                dismiss()
                            }
                            .buttonStyle(.bordered)

                            Button("Create Proposal") {
                                onCreateProposal()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.consentGreen)
                            .disabled(isCreatingProposal)
                        }

                        if isCreatingProposal {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Submitting governed proposal...")
                                    .font(.jeevesCaption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .controlRoomPanel()
                    .padding()
                }
            }
            .navigationTitle("Governed Deployment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 126, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(.white)
        }
    }

    private func abbreviatedHash(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "not provided" }
        if value.count <= 20 { return value }
        let prefix = value.prefix(10)
        let suffix = value.suffix(8)
        return "\(prefix)…\(suffix)"
    }
}

private struct EmergingIntentionCard: View {
    let intention: EmergingIntentionProfile
    let relatedToolsCount: Int
    let hasCertifiedConfiguration: Bool
    let onOpen: () -> Void

    private var stateTint: Color {
        switch intention.state {
        case .promoted:
            return .consentGreen
        case .certified:
            return .cyan
        case .emerging:
            return .consentOrange
        }
    }

    private var stateLabel: String {
        switch intention.state {
        case .promoted:
            return "PROMOTED"
        case .certified:
            return "CERTIFIED"
        case .emerging:
            return "EMERGING"
        }
    }

    private var confidenceLabel: String {
        "score \(String(format: "%.2f", intention.confidenceScore))"
    }

    private var effectiveRelatedToolsCount: Int {
        max(relatedToolsCount, intention.relatedIncomingToolCount ?? 0)
    }

    private var discoveryLabel: String {
        if let source = intention.sourceClusters.first, !source.isEmpty {
            return source
        }
        return "CLASHD27 cluster"
    }

    private var certificationLabel: String {
        if hasCertifiedConfiguration {
            return "Candidate configuration available"
        }
        return "No certified configuration yet"
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(intention.title)
                        .font(.jeevesHeadline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                    capsule(text: stateLabel, tint: stateTint)
                    capsule(text: intention.uncertaintyState.rawValue, tint: uncertaintyTint)
                }

                Text("\(intention.domain) / \(intention.subdomain)")
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(intention.description)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(intention.uncertaintyNarrative)
                    .font(.jeevesCaption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    capsule(text: "Emerging intention", tint: .consentOrange)
                    capsule(text: confidenceLabel, tint: .cyan)
                    if let risk = intention.riskProfile, !risk.isEmpty {
                        capsule(text: "risk \(risk)", tint: .secondary)
                    }
                    capsule(text: discoveryLabel, tint: .secondary)
                    Spacer()
                }

                detailRow(label: "Signal", value: intention.clashdSignalSummary)
                detailRow(label: "Certification", value: certificationLabel)

                if !intention.linkedCells.isEmpty {
                    detailRow(label: "Cells", value: intention.linkedCells.joined(separator: ", "))
                }
                if effectiveRelatedToolsCount > 0 {
                    detailRow(label: "Related tools", value: "\(effectiveRelatedToolsCount)")
                }
            }
            .controlRoomPanel(padding: 12)
        }
        .buttonStyle(.plain)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(.white)
                .lineLimit(2)
        }
    }

    private func capsule(text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.jeevesCaption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
    }

    private var uncertaintyTint: Color {
        switch intention.uncertaintyState {
        case .confirmed:
            return .consentGreen
        case .strongCandidate:
            return .cyan
        case .exploratory:
            return .consentOrange
        case .unknown:
            return .secondary
        }
    }
}

private struct EmergingIntentionDetailSheet: View {
    let intention: EmergingIntentionProfile
    let relatedTools: [IncomingToolSummary]
    let certifiedMatch: BrowserCard?
    let onOpenTool: (IncomingToolSummary) -> Void
    let onOpenCertified: (BrowserCard) -> Void
    @Environment(\.dismiss) private var dismiss

    private var stateTint: Color {
        switch intention.state {
        case .promoted:
            return .consentGreen
        case .certified:
            return .cyan
        case .emerging:
            return .consentOrange
        }
    }

    private var stateLabel: String {
        switch intention.state {
        case .promoted:
            return "promoted"
        case .certified:
            return "certified"
        case .emerging:
            return "emerging"
        }
    }

    private var confidenceText: String {
        String(format: "%.2f", intention.confidenceScore)
    }

    private var uncertaintyTint: Color {
        switch intention.uncertaintyState {
        case .confirmed:
            return .consentGreen
        case .strongCandidate:
            return .cyan
        case .exploratory:
            return .consentOrange
        case .unknown:
            return .secondary
        }
    }

    private var certificationText: String {
        if intention.hasCertifiedConfiguration == true || certifiedMatch != nil {
            return "Certified configuration available."
        }
        if intention.candidateConfigurationAvailable == true {
            return "Candidate configuration available, certification in progress."
        }
        return "No certified configuration yet."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(intention.title)
                            .font(.jeevesTitle.weight(.semibold))
                            .foregroundStyle(.white)

                        Text("\(intention.domain) / \(intention.subdomain)")
                            .font(.jeevesMono)
                            .foregroundStyle(.secondary)

                        metadataRow(label: "State", value: stateLabel, tint: stateTint)
                        metadataRow(label: "Evidence state", value: intention.uncertaintyState.rawValue, tint: uncertaintyTint)
                        metadataRow(label: "Confidence", value: confidenceText)
                        if let risk = intention.riskProfile, !risk.isEmpty {
                            metadataRow(label: "Risk profile", value: risk)
                        }
                        metadataRow(label: "Intention ID", value: intention.intentionId)
                        if let discoveredAtIso = intention.discoveredAtIso {
                            metadataRow(label: "Discovered", value: discoveredAtIso)
                        }
                        metadataRow(label: "Certification", value: certificationText)

                        Text("Why this intention exists")
                            .font(.jeevesHeadline)
                            .foregroundStyle(.white)
                        Text(intention.description)
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Text("Uncertainty")
                            .font(.jeevesHeadline)
                            .foregroundStyle(.white)
                        Text(intention.uncertaintyNarrative)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Text("Signal summary")
                            .font(.jeevesHeadline)
                            .foregroundStyle(.white)
                        Text(intention.clashdSignalSummary)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)

                        if !intention.sourceClusters.isEmpty {
                            Text("Originating clusters")
                                .font(.jeevesHeadline)
                                .foregroundStyle(.white)
                            ForEach(intention.sourceClusters.prefix(4), id: \.self) { cluster in
                                Text(cluster)
                                    .font(.jeevesMono)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !intention.linkedCells.isEmpty {
                            metadataRow(label: "Linked cells", value: intention.linkedCells.joined(separator: ", "))
                        }

                        certificationSection
                        relatedToolsSection
                        nextStepSection
                    }
                    .controlRoomPanel()
                    .padding()
                }
            }
            .navigationTitle("Emerging Intention")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func metadataRow(label: String, value: String, tint: Color = .white) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 118, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private var certificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Certification path")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)

            if let certifiedMatch {
                Text("A certified SafeClash configuration is already linked to this intention.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text(certifiedMatch.title)
                        .font(.jeevesBody)
                        .foregroundStyle(.white)
                    Text("Model \(certifiedMatch.bestConfiguration.model) · \(certifiedMatch.bestConfiguration.certificationLevel)")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    Button("Open certified configuration") {
                        onOpenCertified(certifiedMatch)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Text("No certified SafeClash configuration yet. Route this through refinement or incoming tools.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var relatedToolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related incoming tools")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)

            if relatedTools.isEmpty {
                Text("No linked incoming tools detected.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(relatedTools) { tool in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tool.title)
                            .font(.jeevesBody)
                            .foregroundStyle(.white)
                        Text(tool.intentSummary)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack {
                            Text("risk \(tool.risk)")
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Open Incoming Tool") {
                                onOpenTool(tool)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private var nextStepSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next governed step")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)
            Text(nextStepHint)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
        }
    }

    private var nextStepHint: String {
        if certifiedMatch != nil {
            return "Inspect certified configuration and deploy into proposal flow when governance context is complete."
        }
        return "Inspect related tools, review lineage, and search certified alternatives before deployment. Emerging intentions do not bypass approval."
    }
}

private struct IncomingToolCard: View {
    let tool: IncomingToolSummary
    let isActionInFlight: Bool
    let onOpen: () -> Void
    let onAction: (IncomingToolActionKind) -> Void

    private var riskColor: Color {
        switch tool.risk {
        case "green":
            return .green
        case "orange":
            return .orange
        case "red":
            return .red
        default:
            return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(tool.title)
                    .font(.jeevesHeadline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
                capsule(text: tool.source, tint: .cyan)
                capsule(text: tool.risk.uppercased(), tint: riskColor)
            }

            detailRow(label: "Intent", value: tool.intentSummary)
            detailRow(label: "Capabilities", value: tool.capabilitySummary)
            detailRow(label: "Suggested refinement", value: tool.suggestedRefinement)
            detailRow(label: "Status", value: tool.status)

            if !tool.linkedCells.isEmpty {
                detailRow(label: "Cells", value: tool.linkedCells.joined(separator: ", "))
            }

            HStack(spacing: 8) {
                actionChip(title: "Reject", tint: .consentRed, enabled: tool.actions.reject.available) {
                    onAction(.reject)
                }
                actionChip(title: "Sandbox", tint: .consentOrange, enabled: tool.actions.sandbox.available) {
                    onAction(.sandbox)
                }
                actionChip(title: "Refine", tint: .cyan, enabled: tool.actions.refine.available) {
                    onAction(.refine)
                }
                actionChip(title: "Promote", tint: .consentGreen, enabled: tool.actions.promote.available) {
                    onAction(.promote)
                }
                if isActionInFlight {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let latest = tool.actionHistory.first {
                Text("Last action: \(latest.action) · \(latest.atIso)")
                    .font(.jeevesCaption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("No operator actions recorded yet.")
                    .font(.jeevesCaption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .controlRoomPanel(padding: 14)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            onOpen()
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 118, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(.white)
                .lineLimit(2)
        }
    }

    private func capsule(text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.jeevesCaption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
    }

    private func actionChip(title: String, tint: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.jeevesCaption.weight(.medium))
                .foregroundStyle(enabled ? tint : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((enabled ? tint : Color.secondary).opacity(0.16))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled || isActionInFlight)
    }
}

private struct IncomingToolDetailSheet: View {
    let tool: IncomingToolSummary
    let relatedProposals: [ExtensionProposal]
    let isActionInFlight: Bool
    let onAction: (IncomingToolActionKind) -> Void
    let onOpenApprovalCard: (ExtensionProposal) -> Void
    @Environment(\.dismiss) private var dismiss

    private var riskColor: Color {
        switch tool.risk {
        case "green":
            return .green
        case "orange":
            return .orange
        case "red":
            return .red
        default:
            return .secondary
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(tool.title)
                            .font(.jeevesTitle.weight(.semibold))
                            .foregroundStyle(.white)

                        metadataRow(label: "Discovery origin", value: tool.discoveryOrigin)
                        metadataRow(label: "Risk classification", value: tool.risk.uppercased(), tint: riskColor)
                        metadataRow(label: "Intent", value: tool.intentSummary)
                        metadataRow(label: "Capabilities", value: tool.capabilitySummary)
                        metadataRow(label: "Status", value: tool.status)
                        metadataRow(label: "Linked cells", value: tool.linkedCells.isEmpty ? "none" : tool.linkedCells.joined(separator: ", "))
                        metadataRow(label: "Weak points", value: tool.weakPoints)
                        metadataRow(label: "Refinement", value: tool.suggestedRefinement)
                        if let reportId = tool.forensicsReportId {
                            metadataRow(label: "Forensics report", value: reportId)
                        }
                        metadataRow(label: "Lineage hint", value: tool.lineageHint)

                        actionSection

                        if !tool.explanation.isEmpty {
                            Text(tool.explanation)
                                .font(.jeevesBody)
                                .foregroundStyle(.secondary)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        evidenceSection
                        relatedProposalSection
                    }
                    .controlRoomPanel()
                    .padding()
                }
            }
            .navigationTitle("Incoming Tool")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func metadataRow(label: String, value: String, tint: Color = .white) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 126, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(tint)
        }
    }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Evidence refs")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)

            ForEach(tool.evidenceRefs) { reference in
                if let urlString = reference.url, let url = URL(string: urlString) {
                    Link(destination: url) {
                        evidenceRow(reference: reference)
                    }
                } else {
                    evidenceRow(reference: reference)
                }
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Operator actions")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                actionButton(title: "Reject", tint: .consentRed, enabled: tool.actions.reject.available) {
                    onAction(.reject)
                }
                actionButton(title: "Sandbox", tint: .consentOrange, enabled: tool.actions.sandbox.available) {
                    onAction(.sandbox)
                }
                actionButton(title: "Refine", tint: .cyan, enabled: tool.actions.refine.available) {
                    onAction(.refine)
                }
                actionButton(title: "Promote", tint: .consentGreen, enabled: tool.actions.promote.available) {
                    onAction(.promote)
                }
                if isActionInFlight {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if tool.actionHistory.isEmpty {
                Text("No operator actions recorded yet.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tool.actionHistory) { item in
                    Text("\(item.action) · \(item.atIso)")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func evidenceRow(reference: IncomingToolEvidenceRef) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(reference.label.uppercased())
                .font(.jeevesCaption2.weight(.semibold))
                .foregroundStyle(.cyan)
            Text(reference.value)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            if reference.url != nil {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
                    .font(.jeevesCaption)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var relatedProposalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related extension proposals")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)

            if relatedProposals.isEmpty {
                Text("No linked approval card is currently in queue.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(relatedProposals) { proposal in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(proposal.title)
                            .font(.jeevesBody)
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text(proposal.purpose)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack {
                            Text("risk \(proposal.risk.lowercased())")
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Open approval card") {
                                onOpenApprovalCard(proposal)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private func actionButton(title: String, tint: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(enabled ? title : "\(title) (Unavailable)")
                .font(.jeevesCaption.weight(.medium))
                .foregroundStyle(enabled ? tint : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((enabled ? tint : Color.secondary).opacity(0.16))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled || isActionInFlight)
    }
}

private struct KnowledgeResultCard: View {
    let object: KnowledgeObject
    let createdLabel: String
    let proposalOrigin: String
    let producer: String
    let lifecycle: DeploymentLifecycle?
    let onOpenProposal: (String) -> Void
    let onOpenDecision: (String) -> Void
    let onOpenKnowledgeArtifact: (String) -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(object.title)
                            .font(.jeevesHeadline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Spacer()
                        Text(createdLabel)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }

                    Text(object.summary)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    detailRow(label: "Origin proposal", value: proposalOrigin)
                    detailRow(label: "Created by", value: producer)
                }
            }
            .buttonStyle(.plain)

            if let lifecycle {
                LifecycleLineagePanel(
                    lifecycle: lifecycle,
                    onOpenProposal: onOpenProposal,
                    onOpenDecision: onOpenDecision,
                    onOpenKnowledgeArtifact: onOpenKnowledgeArtifact
                )
            }
        }
        .controlRoomPanel(padding: 14)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 108, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

private struct LifecycleLineagePanel: View {
    let lifecycle: DeploymentLifecycle
    let onOpenProposal: ((String) -> Void)?
    let onOpenDecision: ((String) -> Void)?
    let onOpenKnowledgeArtifact: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lifecycle")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 6) {
                timelineDetailRow(label: "Config", value: lifecycle.configId)
                timelineDetailRow(label: "Intention", value: lifecycle.intentionId)
                if let certificateId = lifecycle.certificateId, !certificateId.isEmpty {
                    timelineDetailRow(label: "Certificate", value: certificateId)
                }
                if let runtimeEnvelopeHash = lifecycle.runtimeEnvelopeHash, !runtimeEnvelopeHash.isEmpty {
                    timelineDetailRow(label: "Runtime envelope", value: abbreviatedHash(runtimeEnvelopeHash))
                }
                if let benchmarkContractId = lifecycle.benchmarkContractId, !benchmarkContractId.isEmpty {
                    timelineDetailRow(label: "Benchmark contract", value: benchmarkContractId)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(lifecycle.steps.enumerated()), id: \.element.id) { index, step in
                    LifecycleTimelineRow(
                        step: step,
                        isLast: index == lifecycle.steps.count - 1
                    )
                }
            }

            HStack(spacing: 8) {
                if let proposalId = lifecycle.proposalId, let onOpenProposal {
                    Button("Open proposal") {
                        onOpenProposal(proposalId)
                    }
                    .buttonStyle(.bordered)
                }
                if let proposalId = lifecycle.proposalId, let onOpenDecision {
                    Button("Open decision") {
                        onOpenDecision(proposalId)
                    }
                    .buttonStyle(.bordered)
                }
                if let knowledgeId = lifecycle.knowledgeId, let onOpenKnowledgeArtifact {
                    Button("Open knowledge artifact") {
                        onOpenKnowledgeArtifact(knowledgeId)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func timelineDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 116, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    private func abbreviatedHash(_ value: String) -> String {
        if value.count <= 20 { return value }
        let prefix = value.prefix(10)
        let suffix = value.suffix(8)
        return "\(prefix)…\(suffix)"
    }
}

private struct LifecycleTimelineRow: View {
    let step: DeploymentLifecycleStep
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                if !isLast {
                    Rectangle()
                        .fill(dotColor.opacity(0.45))
                        .frame(width: 2, height: 28)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(.white)
                Text(step.primary)
                    .font(.jeevesMono)
                    .foregroundStyle(step.state == .missing ? Color.secondary : Color.white)
                    .lineLimit(1)
                if let secondary = step.secondary, !secondary.isEmpty {
                    Text(secondary)
                        .font(.jeevesCaption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }

    private var dotColor: Color {
        if step.id == "source" {
            return .cyan
        }
        switch step.state {
        case .complete:
            return .consentGreen
        case .pending:
            return .consentOrange
        case .missing:
            return .secondary
        }
    }
}

private struct ExtensionProposalCard: View {
    let proposal: ExtensionProposal
    let isActionInFlight: Bool
    let onApprove: () -> Void
    let onReject: () -> Void
    let onInspectManifest: () -> Void

    private var riskColor: Color {
        switch proposal.risk.lowercased() {
        case "green":
            return .green
        case "orange":
            return .orange
        case "red":
            return .red
        default:
            return .secondary
        }
    }

    private var priorityScore: Int {
        switch proposal.risk.lowercased() {
        case "red":
            return 85
        case "orange":
            return 65
        case "green":
            return 45
        default:
            return 20
        }
    }

    private var priorityTint: Color {
        switch priorityScore {
        case 80...: return .consentRed
        case 60..<80: return .consentOrange
        case 30..<60: return .blue
        default: return .secondary
        }
    }

    private var capabilitySummary: String {
        if proposal.capabilities.isEmpty {
            return "Geen capabilities"
        }
        return proposal.capabilities.map(\.title).joined(separator: ", ")
    }

    private var linkedCellsSummary: String {
        if !proposal.linkedCells.isEmpty {
            return proposal.linkedCells.joined(separator: ", ")
        }
        return "surface|engine|current"
    }

    private var reasoningTraceSummary: String {
        if let trace = proposal.reasoningTrace, !trace.isEmpty {
            return trace
        }
        return "Risico en capabilities vragen menselijke bevestiging voor bounded execution."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(proposal.title)
                    .font(.jeevesHeadline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
                Text("PR \(priorityScore)")
                    .font(.jeevesCaption.weight(.medium))
                    .foregroundStyle(priorityTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityTint.opacity(0.15))
                    .clipShape(Capsule())
                Text(proposal.risk.uppercased())
                    .font(.jeevesCaption)
                    .foregroundStyle(riskColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(riskColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                capsule(text: (proposal.sourceType ?? "system").uppercased(), tint: .jeevesGold)
                capsule(text: proposal.status.uppercased(), tint: .blue)
            }

            detailRow(label: TextKeys.Lobby.extensionPurpose, value: proposal.purpose)
            detailRow(label: TextKeys.Lobby.extensionCapabilities, value: capabilitySummary)
            detailRow(label: "Cells", value: linkedCellsSummary)
            detailRow(label: "Trace", value: reasoningTraceSummary)
            detailRow(label: TextKeys.Lobby.extensionCodeHash, value: proposal.codeHash)

            HStack(spacing: 8) {
                Button(TextKeys.Lobby.approve, action: onApprove)
                    .buttonStyle(.borderedProminent)
                    .tint(.consentGreen)
                    .disabled(isActionInFlight)

                Button(TextKeys.Lobby.deny, action: onReject)
                    .buttonStyle(.bordered)
                    .tint(.consentRed)
                    .disabled(isActionInFlight)

                Button(TextKeys.Lobby.inspectManifest, action: onInspectManifest)
                    .buttonStyle(.bordered)
                    .disabled(isActionInFlight)

                if isActionInFlight {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .controlRoomPanel(padding: 14)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            onInspectManifest()
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .lineLimit(2)
        }
    }

    private func capsule(text: String, tint: Color) -> some View {
        Text(text)
            .font(.jeevesCaption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - SwipeDirection

enum SwipeDirection {
    case left, right
}

// MARK: - Decided Proposal Row

private struct DecidedProposalRow: View {
    let decision: DecidedProposal

    private var statusIcon: String {
        decision.isApproved ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var statusColor: Color {
        decision.isApproved ? .green : .red
    }

    private var statusLabel: String {
        decision.isApproved ? TextKeys.Lobby.approved : TextKeys.Lobby.denied
    }

    private var timeSince: String {
        guard let date = decision.decidedAt else { return "" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s geleden" }
        if seconds < 3600 { return "\(seconds / 60)m geleden" }
        if seconds < 86400 { return "\(seconds / 3600)u geleden" }
        return "\(seconds / 86400)d geleden"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.jeevesTitle)

            VStack(alignment: .leading, spacing: 4) {
                Text(decision.title)
                    .font(.jeevesBody)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(statusLabel)
                        .font(.jeevesCaption)
                        .foregroundStyle(statusColor)

                    if !timeSince.isEmpty {
                        Text(timeSince)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let reason = decision.decisionReason, !reason.isEmpty {
                    Text(reason)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if decision.action != nil {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.jeevesBody)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.jeevesCaption)
        }
        .controlRoomPanel(padding: 12)
    }
}

// MARK: - Decision Detail Sheet

private struct DecisionDetailSheet: View {
    let decision: DecidedProposal
    let onKnowledgeTap: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        decisionHeader
                        decisionMetadata
                        if decision.action != nil {
                            Divider().overlay(Color.white.opacity(0.12))
                            decisionActionSection
                        }
                    }
                    .controlRoomPanel()
                    .padding()
                }
            }
            .navigationTitle(TextKeys.Lobby.recentDecisions)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private var decisionHeader: some View {
        let icon = decision.isApproved ? "checkmark.circle.fill" : "xmark.circle.fill"
        let color: Color = decision.isApproved ? .green : .red
        let label = decision.isApproved ? TextKeys.Lobby.approved : TextKeys.Lobby.denied
        return HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.jeevesLargeTitle)
            VStack(alignment: .leading, spacing: 2) {
                Text(decision.title)
                    .font(.jeevesHeadline)
                    .foregroundStyle(.white)
                Text(label)
                    .font(.jeevesCaption)
                    .foregroundStyle(color)
            }
        }
    }

    private var decisionMetadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataRow(label: "Agent", value: decision.agentId)
            if let decidedAt = decision.decidedAt {
                metadataRow(label: "Beslist", value: formatDate(decidedAt))
            }
            if let reason = decision.decisionReason {
                metadataRow(label: "Reden", value: reason)
            }
            if let intent = decision.intent {
                metadataRow(label: "Intent", value: intent.key)
                metadataRow(label: "Risico", value: intent.risk)
            }
            if let score = decision.priorityScore, score > 0 {
                metadataRow(label: "Prioriteit", value: "P\(Int(score))")
            }
        }
    }

    @ViewBuilder
    private var decisionActionSection: some View {
        if let action = decision.action {
            let actionIcon = action.isCompleted ? "checkmark.seal.fill" : "xmark.seal.fill"
            let actionColor: Color = action.isCompleted ? .green : .red
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: actionIcon)
                        .foregroundStyle(actionColor)
                    Text(TextKeys.Lobby.actionReceipt)
                        .font(.jeevesHeadline)
                }

                metadataRow(label: TextKeys.Lobby.actionKind, value: action.actionKind)
                metadataRow(label: TextKeys.Lobby.actionStatus, value: action.executionState)

                if let receipt = action.receipt {
                    decisionReceiptDetails(receipt: receipt)
                }
            }
        }
    }

    @ViewBuilder
    private func decisionReceiptDetails(receipt: ActionReceipt) -> some View {
        Text(receipt.resultSummary)
            .font(.jeevesBody)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        if let duration = receipt.durationMs {
            metadataRow(label: TextKeys.Lobby.actionDuration, value: "\(Int(duration))ms")
        }
        if let resultType = receipt.resultType {
            metadataRow(label: TextKeys.Lobby.actionResultType, value: resultType)
        }
        if let notes = receipt.notes, !notes.isEmpty {
            metadataRow(label: TextKeys.Lobby.actionNotes, value: notes)
        }
        if let outputIds = receipt.outputObjectIds, !outputIds.isEmpty {
            Divider()
            Text(TextKeys.Lobby.actionOutputObjects)
                .font(.jeevesHeadline)
            ForEach(outputIds, id: \.self) { objId in
                Button {
                    onKnowledgeTap(objId)
                } label: {
                    knowledgeLinkRow(objId: objId)
                }
            }
        }
    }

    private func knowledgeLinkRow(objId: String) -> some View {
        HStack {
            Image(systemName: "link")
                .foregroundStyle(Color.jeevesGold)
            Text(objId)
                .font(.jeevesMono)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Swipe Card

private struct SwipeCard: View {
    let proposal: Proposal
    let isTop: Bool
    let isDecisionInFlight: Bool
    let onSwipe: (SwipeDirection) -> Void

    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1.0

    private var riskColor: Color {
        switch proposal.intent.risk {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        default: return .secondary
        }
    }

    private var timeSince: String {
        guard let created = proposal.createdAt else { return "" }
        let seconds = Int(Date().timeIntervalSince(created))
        if seconds < 60 { return "\(seconds)s geleden" }
        if seconds < 3600 { return "\(seconds / 60)m geleden" }
        return "\(seconds / 3600)u geleden"
    }

    private var sourceLabel: String {
        let lower = proposal.agentId.lowercased()
        if lower.contains("clashd27") || lower.contains("radar") {
            return "CLASHD27"
        }
        if lower.contains("manual") || lower.contains("human") {
            return "MANUAL"
        }
        return "SYSTEM"
    }

    private var noveltyValue: String {
        guard let novelty = proposal.priorityFactors?.novelty else { return "n/a" }
        return String(format: "%.2f", novelty)
    }

    private var governanceValue: String {
        guard let gov = proposal.priorityFactors?.governanceValue else { return "n/a" }
        return String(format: "%.2f", gov)
    }

    private var normalizedPriority: Double {
        guard var score = proposal.priorityScore, score > 0 else {
            switch proposal.intent.risk {
            case "red": return 85
            case "orange": return 65
            case "green": return 45
            default: return 20
            }
        }
        if score <= 1 {
            score *= 100
        } else if score <= 10 {
            score *= 10
        }
        return min(max(score, 0), 100)
    }

    private var priorityTint: Color {
        switch normalizedPriority {
        case 80...: return .consentRed
        case 60..<80: return .consentOrange
        case 30..<60: return .blue
        default: return .secondary
        }
    }

    private var priorityLabel: String {
        "PR \(Int(normalizedPriority.rounded()))"
    }

    private var relatedCellsLabel: String {
        switch proposal.intent.key {
        case "residue_summary":
            return "trust-model|engine|emerging, surface|engine|current"
        case "anomaly_probe":
            return "architecture|external|current"
        case "kernel_override":
            return "architecture|engine|emerging"
        default:
            return "surface|external|current"
        }
    }

    private var statusLabel: String {
        proposal.status.uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(proposal.title)
                    .font(.jeevesHeadline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
                metricChip(text: priorityLabel, tint: priorityTint)
                metricChip(text: statusLabel, tint: .blue)
                metricChip(text: sourceLabel, tint: .jeevesGold)
                if let rank = proposal.rank, rank > 0 {
                    Text("#\(rank)")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                Text("Agent:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Text(proposal.agentId)
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let explanation = proposal.priorityExplanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text("Intent:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Text(proposal.intent.key)
                    .font(.jeevesMono)
            }

            HStack {
                Text("Risico:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Text(proposal.intent.risk)
                    .font(.jeevesMono)
                    .foregroundStyle(riskColor)
            }

            HStack(spacing: 10) {
                metricChip(text: "Novelty \(noveltyValue)", tint: .purple)
                metricChip(text: "Gov \(governanceValue)", tint: .teal)
            }

            HStack(alignment: .top, spacing: 6) {
                Text("Cells:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Text(relatedCellsLabel)
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(timeSince)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(riskColor.opacity(0.55), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .opacity(opacity)
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width) / 20))
        .gesture(
            (isTop && !isDecisionInFlight) ? DragGesture()
                .onChanged { value in
                    offset = value.translation
                }
                .onEnded { value in
                    let threshold: CGFloat = 100
                    if value.translation.width > threshold {
                        swipeAway(direction: .right)
                    } else if value.translation.width < -threshold {
                        swipeAway(direction: .left)
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            offset = .zero
                        }
                    }
                }
            : nil
        )
        .allowsHitTesting(isTop && !isDecisionInFlight)
    }

    private func swipeAway(direction: SwipeDirection) {
        let offscreenX: CGFloat = direction == .right ? 500 : -500
        withAnimation(.easeOut(duration: 0.3)) {
            offset = CGSize(width: offscreenX, height: 0)
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSwipe(direction)
        }
    }

    private func metricChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(.jeevesCaption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(tint)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }
}

// MARK: - Enhanced Action Receipt Sheet

private struct ActionReceiptSheet: View {
    let action: ActionSummary
    let linkedKnowledge: [KnowledgeObject]
    let onKnowledgeTap: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        receiptHeader
                        receiptMetadata
                        if action.receipt != nil {
                            Divider().overlay(Color.white.opacity(0.12))
                            receiptDetailsSection
                        }
                        if !linkedKnowledge.isEmpty {
                            Divider().overlay(Color.white.opacity(0.12))
                            linkedKnowledgeSection
                        }
                    }
                    .controlRoomPanel()
                    .padding()
                }
            }
            .navigationTitle(TextKeys.Lobby.actionReceipt)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private var receiptHeader: some View {
        let icon = action.isCompleted ? "checkmark.circle.fill" : "xmark.circle.fill"
        let color: Color = action.isCompleted ? .green : .red
        let label = action.isCompleted ? TextKeys.Lobby.actionCompleted : TextKeys.Lobby.actionFailed
        return HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.jeevesLargeTitle)
            Text(label)
                .font(.jeevesHeadline)
                .foregroundStyle(.white)
        }
    }

    private var receiptMetadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eventType = action.receipt?.eventType, !eventType.isEmpty {
                metadataRow(label: "Event", value: eventType)
            } else {
                metadataRow(label: "Event", value: action.actionKind)
            }
            metadataRow(label: TextKeys.Lobby.actionKind, value: action.actionKind)
            metadataRow(label: TextKeys.Lobby.actionStatus, value: action.executionState)
            if let completedAt = action.receipt?.completedAtIso {
                metadataRow(label: "Timestamp", value: completedAt)
            }
            if let actor = action.receipt?.actor, !actor.isEmpty {
                metadataRow(label: "Actor", value: actor)
            }
            if let reason = action.receipt?.reason, !reason.isEmpty {
                metadataRow(label: "Reason", value: reason)
            }
            if let correlationId = action.receipt?.correlationId, !correlationId.isEmpty {
                metadataRow(label: "Correlation", value: correlationId)
            }
            if let requestId = action.receipt?.requestId, !requestId.isEmpty {
                metadataRow(label: "Request", value: requestId)
            }
        }
    }

    @ViewBuilder
    private var receiptDetailsSection: some View {
        if let receipt = action.receipt {
            VStack(alignment: .leading, spacing: 8) {
                Text(TextKeys.Lobby.actionResult)
                    .font(.jeevesHeadline)

                Text(receipt.resultSummary)
                    .font(.jeevesBody)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                receiptExtraFields(receipt: receipt)
                receiptOutputObjects(receipt: receipt)
            }
        }
    }

    @ViewBuilder
    private func receiptExtraFields(receipt: ActionReceipt) -> some View {
        if let duration = receipt.durationMs {
            metadataRow(label: TextKeys.Lobby.actionDuration, value: "\(Int(duration))ms")
        }
        if let resultType = receipt.resultType {
            metadataRow(label: TextKeys.Lobby.actionResultType, value: resultType)
        }
        if let notes = receipt.notes, !notes.isEmpty {
            metadataRow(label: TextKeys.Lobby.actionNotes, value: notes)
        }
    }

    @ViewBuilder
    private func receiptOutputObjects(receipt: ActionReceipt) -> some View {
        if let outputIds = receipt.outputObjectIds, !outputIds.isEmpty {
            Divider()
            Text(TextKeys.Lobby.actionOutputObjects)
                .font(.jeevesHeadline)
            ForEach(outputIds, id: \.self) { objId in
                Button {
                    onKnowledgeTap(objId)
                } label: {
                    outputObjectRow(objId: objId)
                }
            }
        }
    }

    private func outputObjectRow(objId: String) -> some View {
        HStack {
            Image(systemName: "link")
                .foregroundStyle(Color.jeevesGold)
            Text(objId)
                .font(.jeevesMono)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var linkedKnowledgeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TextKeys.Lobby.knowledgeObjects)
                .font(.jeevesHeadline)
            ForEach(linkedKnowledge) { obj in
                KnowledgeObjectCard(object: obj) {
                    onKnowledgeTap(obj.objectId)
                }
            }
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
        }
    }
}

// MARK: - Knowledge Object Card

private struct KnowledgeObjectCard: View {
    let object: KnowledgeObject
    let onTap: () -> Void

    private var kindColor: Color {
        switch object.kind {
        case "decision": return .blue
        case "investigation_outcome": return .purple
        case "action_receipt": return .green
        case "discovery": return .orange
        case "evidence": return .teal
        default: return .secondary
        }
    }

    private var stageLabel: String {
        switch object.kind {
        case "discovery", "signal":
            return "Discovery"
        case "proposal", "extension_proposal":
            return "Proposal"
        case "decision", "extension_decision":
            return "Approval"
        case "action_receipt", "extension_receipt":
            return "Action"
        default:
            return "Knowledge"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(object.kindEmoji)
                    Text(object.kind.replacingOccurrences(of: "_", with: " "))
                        .font(.jeevesCaption)
                        .foregroundStyle(kindColor)
                        .textCase(.uppercase)
                    Spacer()
                    Text(stageLabel)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .font(.jeevesCaption)
                }

                Text(object.title)
                    .font(.jeevesBody)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(object.summary)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(kindColor.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Knowledge Graph Sheet

private struct KnowledgeGraphSheet: View {
    let graphData: KnowledgeGraphResponse?
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedNode: LineageNodeDetail?

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                Group {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Kennisgraaf laden...")
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let graph = graphData {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                lineageHeader(graph: graph)
                                lineageColumn(graph: graph)
                            }
                            .controlRoomPanel()
                            .padding()
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.jeevesLargeTitle)
                                .foregroundStyle(.secondary)
                            Text("Kennisgraaf niet beschikbaar.")
                                .font(.jeevesBody)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle(TextKeys.Lobby.knowledgeGraph)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .sheet(item: $selectedNode) { node in
            LineageNodeDetailSheet(node: node)
        }
    }

    private func lineageHeader(graph: KnowledgeGraphResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Knowledge lineage")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)
            Text(causalPathLabel(for: graph))
                .font(.jeevesMono)
                .foregroundStyle(.secondary)
            if hasApprovalCheckpoint(in: graph) {
                Text("Approval recorded")
                    .font(.jeevesCaption.weight(.medium))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.14))
                    .clipShape(Capsule())
            }
        }
    }

    private func lineageColumn(graph: KnowledgeGraphResponse) -> some View {
        let nodes = lineageNodes(from: graph)
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(LineageLane.allCases) { lane in
                let laneNodes = nodes.filter { $0.lane == lane }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: lane.systemImage)
                            .font(.jeevesBody.weight(.semibold))
                            .foregroundStyle(lane.tint)
                        Text(lane.title)
                            .font(.jeevesHeadline)
                            .foregroundStyle(.white)
                        Text("\(laneNodes.count)")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }

                    if laneNodes.isEmpty {
                        Text("No \(lane.title.lowercased()) nodes available.")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 24)
                    } else {
                        ForEach(laneNodes) { node in
                            LineageNodeCard(node: node) {
                                selectedNode = node.detail
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if lane != .knowledge {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.down")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func lineageNodes(from graph: KnowledgeGraphResponse) -> [LineageNode] {
        let allObjects = deduplicatedGraphObjects(graph)
        let actionNodeIds = Set(
            allObjects
                .filter { lane(for: $0.kind) == .action }
                .map(\.objectId)
        )

        let nodes: [LineageNode] = allObjects.map { object in
            let nodeLane = lane(for: object.kind)
            return LineageNode(
                object: object,
                lane: nodeLane,
                origin: originLabel(for: object),
                timestamp: timestampLabel(for: object.createdAtIso),
                evidence: evidenceLabel(for: object),
                linkedCells: linkedCellsLabel(for: object),
                relatedReceipt: relatedReceiptLabel(for: object, lane: nodeLane, actionNodeIds: actionNodeIds)
            )
        }
        return nodes.sorted { lhs, rhs in
            if lhs.lane.sortOrder != rhs.lane.sortOrder {
                return lhs.lane.sortOrder < rhs.lane.sortOrder
            }
            return lhs.sortDate > rhs.sortDate
        }
    }

    private func deduplicatedGraphObjects(_ graph: KnowledgeGraphResponse) -> [KnowledgeObject] {
        let merged = [graph.root].compactMap { $0 } + (graph.linked ?? [])
        var seen: Set<String> = []
        var unique: [KnowledgeObject] = []
        for object in merged where seen.insert(object.objectId).inserted {
            unique.append(object)
        }
        return unique
    }

    private func lane(for kind: String) -> LineageLane {
        let normalized = kind.lowercased()
        if ["discovery", "signal", "investigation_outcome"].contains(normalized) {
            return .discovery
        }
        if ["proposal", "extension_proposal", "decision", "extension_decision"].contains(normalized) {
            return .proposal
        }
        if ["action_receipt", "extension_receipt"].contains(normalized) {
            return .action
        }
        return .knowledge
    }

    private func originLabel(for object: KnowledgeObject) -> String {
        if let first = object.sourceRefs?.first {
            return first.label ?? first.sourceId
        }
        return object.kind.replacingOccurrences(of: "_", with: " ")
    }

    private func evidenceLabel(for object: KnowledgeObject) -> String {
        if !object.summary.isEmpty {
            return object.summary
        }
        if let value = scalarMetadataValue(for: object, keys: ["evidence", "reason", "explanation"]) {
            return value
        }
        return "No explicit evidence recorded."
    }

    private func linkedCellsLabel(for object: KnowledgeObject) -> String {
        if let value = scalarMetadataValue(for: object, keys: ["linked_cells", "cells", "cube_cells", "cell"]) {
            return value
        }
        if let linkedId = object.linkedObjectIds?.first(where: { $0.localizedCaseInsensitiveContains("cell") }) {
            return linkedId
        }
        return "not specified"
    }

    private func relatedReceiptLabel(for object: KnowledgeObject, lane: LineageLane, actionNodeIds: Set<String>) -> String {
        if lane == .action || object.kind.lowercased().contains("receipt") {
            return object.objectId
        }
        if let linkedReceipt = object.linkedObjectIds?.first(where: { $0.localizedCaseInsensitiveContains("receipt") }) {
            return linkedReceipt
        }
        return actionNodeIds.first ?? "none"
    }

    private func scalarMetadataValue(for object: KnowledgeObject, keys: [String]) -> String? {
        guard let metadata = object.metadata else { return nil }
        for key in keys {
            if let value = metadata[key] {
                switch value {
                case .string(let text):
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return text }
                case .int(let number):
                    return "\(number)"
                case .double(let number):
                    return String(format: "%.2f", number)
                case .bool(let flag):
                    return flag ? "yes" : "no"
                case .array(let values):
                    let rendered = values.compactMap(\.scalarStringValue)
                    if !rendered.isEmpty {
                        return rendered.joined(separator: ", ")
                    }
                case .object(let values):
                    let rendered = values.keys.sorted().joined(separator: ", ")
                    if !rendered.isEmpty {
                        return rendered
                    }
                case .null:
                    continue
                }
            }
        }
        return nil
    }

    private func timestampLabel(for iso: String) -> String {
        if let date = parseISODate(iso) {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return iso
    }

    private func parseISODate(_ iso: String) -> Date? {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: iso) {
            return date
        }
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: iso)
    }

    private func causalPathLabel(for graph: KnowledgeGraphResponse) -> String {
        if hasApprovalCheckpoint(in: graph) {
            return "Discovery → Proposal → Approval → Action → Knowledge"
        }
        return "Discovery → Proposal → Action → Knowledge"
    }

    private func hasApprovalCheckpoint(in graph: KnowledgeGraphResponse) -> Bool {
        let objects = deduplicatedGraphObjects(graph)
        return objects.contains {
            let kind = $0.kind.lowercased()
            return kind == "decision" || kind == "extension_decision"
        }
    }
}

private enum LineageLane: String, CaseIterable, Identifiable {
    case discovery
    case proposal
    case action
    case knowledge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discovery: return "Discovery"
        case .proposal: return "Proposal"
        case .action: return "Action"
        case .knowledge: return "Knowledge"
        }
    }

    var systemImage: String {
        switch self {
        case .discovery: return "dot.radiowaves.left.and.right"
        case .proposal: return "doc.text.magnifyingglass"
        case .action: return "play.circle.fill"
        case .knowledge: return "book.closed.fill"
        }
    }

    var tint: Color {
        switch self {
        case .discovery: return .teal
        case .proposal: return .jeevesGold
        case .action: return .blue
        case .knowledge: return .purple
        }
    }

    var sortOrder: Int {
        switch self {
        case .discovery: return 0
        case .proposal: return 1
        case .action: return 2
        case .knowledge: return 3
        }
    }
}

private struct LineageNode: Identifiable {
    let object: KnowledgeObject
    let lane: LineageLane
    let origin: String
    let timestamp: String
    let evidence: String
    let linkedCells: String
    let relatedReceipt: String

    var id: String { object.objectId }
    var title: String { object.title }
    var sortDate: Date { object.createdAt ?? .distantPast }

    var detail: LineageNodeDetail {
        LineageNodeDetail(
            id: object.objectId,
            type: lane.title,
            title: object.title,
            origin: origin,
            timestamp: timestamp,
            evidence: evidence,
            linkedCells: linkedCells,
            relatedReceipt: relatedReceipt
        )
    }
}

private struct LineageNodeDetail: Identifiable {
    let id: String
    let type: String
    let title: String
    let origin: String
    let timestamp: String
    let evidence: String
    let linkedCells: String
    let relatedReceipt: String
}

private struct LineageNodeCard: View {
    let node: LineageNode
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: node.lane.systemImage)
                        .foregroundStyle(node.lane.tint)
                    Text(node.title)
                        .font(.jeevesBody)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                    Text(node.timestamp)
                        .font(.jeevesCaption2)
                        .foregroundStyle(.tertiary)
                }

                Text(node.origin)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(node.evidence)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(node.lane.tint.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct LineageNodeDetailSheet: View {
    let node: LineageNodeDetail
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(node.type)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(node.title)
                            .font(.jeevesTitle.weight(.semibold))
                            .foregroundStyle(.white)

                        detailRow(label: "Origin", value: node.origin)
                        detailRow(label: "Timestamp", value: node.timestamp)
                        detailRow(label: "Evidence", value: node.evidence)
                        detailRow(label: "Linked cells", value: node.linkedCells)
                        detailRow(label: "Related receipt", value: node.relatedReceipt)
                    }
                    .controlRoomPanel()
                    .padding()
                }
            }
            .navigationTitle("Lineage Detail")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(.white)
        }
    }
}

private struct ControlRoomBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.07, blue: 0.11),
                    Color(red: 0.02, green: 0.03, blue: 0.06),
                    Color(red: 0.01, green: 0.02, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.jeevesGold.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 420
            )

            RadialGradient(
                colors: [Color.blue.opacity(0.14), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }
}

private struct ControlRoomPanelModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
    }
}

private extension View {
    func controlRoomPanel(padding: CGFloat = 16) -> some View {
        modifier(ControlRoomPanelModifier(padding: padding))
    }
}

extension Notification.Name {
    static let jeevesOpenObservatoryTab = Notification.Name("jeeves.openObservatoryTab")
}
