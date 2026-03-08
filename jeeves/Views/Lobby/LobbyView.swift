import SwiftUI

struct LobbyView: View {
    private enum MissionZone {
        case system
        case radar
        case incomingTools
        case decisions
        case knowledge

        var title: String {
            switch self {
            case .system: return "SYSTEM"
            case .radar: return "RADAR"
            case .incomingTools: return "INCOMING TOOLS"
            case .decisions: return "DECISIONS"
            case .knowledge: return "KNOWLEDGE"
            }
        }

        var subtitle: String {
            switch self {
            case .system: return "Terminal telemetry"
            case .radar: return "Radar — Emerging Signals"
            case .incomingTools: return "Forensic intake workbench"
            case .decisions: return "Governed approvals"
            case .knowledge: return "Resulting knowledge"
            }
        }

        var tint: Color {
            switch self {
            case .system: return .blue
            case .radar: return .cyan
            case .incomingTools: return .cyan
            case .decisions: return .jeevesGold
            case .knowledge: return .consentGreen
            }
        }

        var icon: String {
            switch self {
            case .system: return "terminal"
            case .radar: return "dot.radiowaves.left.and.right"
            case .incomingTools: return "shippingbox"
            case .decisions: return "checkmark.shield"
            case .knowledge: return "book.closed"
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
    @State private var decidingExtensionId: String?
    @State private var loadingManifestExtensionId: String?
    @State private var extensionActionErrorMessage: String?
    @State private var showExtensionActionError = false
    @State private var selectedExtensionManifest: ExtensionManifest?
    @State private var extensionDecisions: [String: ExtensionDecision] = [:]
    @State private var expandedClusterIDs: Set<String> = []

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

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        systemZoneSection
                        radarZoneSection
                        incomingToolsZoneSection
                        decisionsZoneSection
                        knowledgeZoneSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
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
                    onOpenApprovalCard: { proposal in
                        selectedIncomingTool = nil
                        inspectExtensionManifest(proposal)
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
                    .font(.caption.weight(.semibold))
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
                        .font(.title3.weight(.semibold))
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
                .font(.title2)
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
                        .font(.title3)
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
                        KnowledgeResultCard(
                            object: object,
                            createdLabel: formatKnowledgeTimestamp(object.createdAt),
                            proposalOrigin: proposalOrigin(for: object),
                            producer: producerLabel(for: object)
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
                    .font(.caption.weight(.semibold))
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
                .font(.caption2.weight(.medium))
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

            if incomingTools.isEmpty {
                incomingToolsEmptyCard
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(incomingTools) { tool in
                        IncomingToolCard(tool: tool) {
                            selectedIncomingTool = tool
                        }
                    }
                }
            }
        }
    }

    private var incomingTools: [IncomingToolSummary] {
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
                    objectId: proposal.extensionId,
                    title: proposal.title,
                    source: triageExtensionSourceLabel(sourceType: proposal.sourceType),
                    intentSummary: proposal.purpose,
                    capabilitySummary: proposal.capabilities.map(\.title).joined(separator: ", "),
                    capabilities: proposal.capabilities.map(\.title),
                    risk: normalizeIncomingRisk(proposal.risk),
                    suggestedRefinement: "Constrain to a narrow scoped workflow before promotion.",
                    linkedCells: proposal.linkedCells,
                    explanation: proposal.reasoningTrace ?? proposal.purpose,
                    discoveryOrigin: "Mock discovery feed",
                    weakPoints: "Demo fallback artifact",
                    evidenceRefs: [],
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
                    .font(.title2)
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
            objectId: object.objectId,
            title: title,
            source: source,
            intentSummary: intentSummary,
            capabilitySummary: capabilitySummary,
            capabilities: capabilities,
            risk: risk,
            suggestedRefinement: suggestedRefinement,
            linkedCells: linkedCells,
            explanation: explanation,
            discoveryOrigin: discoveryOrigin,
            weakPoints: weakPoints,
            evidenceRefs: evidenceRefs,
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

    private func metadataString(for object: KnowledgeObject, keys: [String]) -> String? {
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
                .font(.title2)
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
                    .font(.title2)
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
                .font(.title2)
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
                        .font(.title3)
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
                .font(.subheadline.weight(.semibold))
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
                            .font(.caption2)
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
                            .font(.title3.weight(.semibold))
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

private struct IncomingToolCard: View {
    let tool: IncomingToolSummary
    let onOpen: () -> Void

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
        Button(action: onOpen) {
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
                if !tool.linkedCells.isEmpty {
                    detailRow(label: "Cells", value: tool.linkedCells.joined(separator: ", "))
                }

                HStack(spacing: 8) {
                    actionChip(title: "Reject", tint: .consentRed, enabled: false, action: {})
                    actionChip(title: "Sandbox", tint: .consentOrange, enabled: false, action: {})
                    actionChip(title: "Refine", tint: .cyan, enabled: true, action: onOpen)
                    actionChip(title: "Promote", tint: .consentGreen, enabled: false, action: {})
                }

                Text("Reject/Sandbox/Promote wiring remains backend-governed. Open card to inspect first.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .controlRoomPanel(padding: 14)
        }
        .buttonStyle(.plain)
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
        .disabled(!enabled)
    }
}

private struct IncomingToolDetailSheet: View {
    let tool: IncomingToolSummary
    let relatedProposals: [ExtensionProposal]
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
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)

                        metadataRow(label: "Discovery origin", value: tool.discoveryOrigin)
                        metadataRow(label: "Risk classification", value: tool.risk.uppercased(), tint: riskColor)
                        metadataRow(label: "Intent", value: tool.intentSummary)
                        metadataRow(label: "Capabilities", value: tool.capabilitySummary)
                        metadataRow(label: "Linked cells", value: tool.linkedCells.isEmpty ? "none" : tool.linkedCells.joined(separator: ", "))
                        metadataRow(label: "Weak points", value: tool.weakPoints)
                        metadataRow(label: "Refinement", value: tool.suggestedRefinement)
                        metadataRow(label: "Lineage hint", value: tool.lineageHint)

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

    private func evidenceRow(reference: IncomingToolEvidenceRef) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(reference.label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.cyan)
            Text(reference.value)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            if reference.url != nil {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
                    .font(.caption)
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
}

private struct KnowledgeResultCard: View {
    let object: KnowledgeObject
    let createdLabel: String
    let proposalOrigin: String
    let producer: String
    let onTap: () -> Void

    var body: some View {
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
            .controlRoomPanel(padding: 14)
        }
        .buttonStyle(.plain)
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
                .font(.title3)

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
                    .font(.body)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.caption)
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
                .font(.title)
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
                .font(.title)
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
                        .font(.caption)
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
                                .font(.title)
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
                            .font(.subheadline.weight(.semibold))
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
                            .font(.caption)
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
                        .font(.caption2)
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
                            .font(.title3.weight(.semibold))
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
