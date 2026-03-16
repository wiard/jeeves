
import SwiftUI

struct JeevesView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @State private var briefingModel = DailyBriefingViewModel()
    @State private var selectedBriefingItem: DailyBriefingItem?
    @State private var knowledgeGraphData: KnowledgeGraphResponse?
    @State private var showKnowledgeGraph = false
    @State private var loadingKnowledgeGraph = false

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.96, green: 0.97, blue: 0.99),
                        Color(red: 0.94, green: 0.96, blue: 0.99),
                        Color(red: 0.98, green: 0.96, blue: 0.93)
                    ]
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        landingHeader
                        primaryActions
                        dailyBriefingCard
                        systemStatusCard
                        nextDecisionCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Jeeves")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .refreshable {
                await briefingModel.load(gateway: gateway, force: true)
            }
            .task {
                if !briefingModel.hasLoaded {
                    await briefingModel.load(gateway: gateway)
                }
            }
            .onChange(of: gateway.isConnected) {
                if gateway.isConnected {
                    Task {
                        await briefingModel.load(gateway: gateway, force: true)
                    }
                }
            }
            .sheet(item: $selectedBriefingItem) { item in
                DailyBriefingExplanationSheet(
                    item: item,
                    relatedEvidence: relatedEvidence(for: item),
                    onSelectEvidence: { object in
                        selectedBriefingItem = nil
                        fetchAndShowKnowledgeGraph(objectId: object.objectId)
                    }
                )
            }
            .sheet(isPresented: $showKnowledgeGraph) {
                DailyBriefingKnowledgeGraphSheet(
                    graphData: knowledgeGraphData,
                    isLoading: loadingKnowledgeGraph
                )
            }
        }
    }

    private var landingHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Jeeves")
                .font(.caption.monospaced())
                .foregroundStyle(Color.jeevesSky)

            Text("AI Observatory")
                .font(.jeevesLargeTitle)

            Text("Jeeves monitors global signals, detects emerging patterns and brings important decisions to your attention.")
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(landingCardBackground(accent: .jeevesSky))
    }

    private var primaryActions: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await briefingModel.load(gateway: gateway, force: true)
                }
            } label: {
                Label("Start briefing", systemImage: "play.fill")
                    .font(.jeevesBody.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.jeevesGold)

            Button {
                NotificationCenter.default.post(name: .jeevesOpenSystemTab, object: nil)
            } label: {
                Label("Connect system", systemImage: "gearshape")
                    .font(.jeevesBody.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var dailyBriefingCard: some View {
        let briefing = briefingModel.briefing

        return briefingLandingCard(
            eyebrow: "Signal Briefing",
            title: briefing?.headline ?? "Your briefing is preparing.",
            subtitle: briefing?.statusLine ?? "Jeeves is translating outside-world signals into operator language."
        ) {
            if briefingModel.isLoading && briefing == nil {
                ProgressView("Loading briefing...")
                    .font(.footnote)
            } else if let briefing {
                VStack(alignment: .leading, spacing: 10) {
                    let items = OperatorSignalPresentation.briefingItems(from: cappedBriefing(from: briefing))

                    if items.isEmpty {
                        Text("No readable signal summary is available yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items.prefix(3)) { item in
                            operatorBriefingCard(item)
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Open Observatory") {
                            handleRoute(.observatory)
                        }
                        .font(.caption.weight(.semibold))

                        if !briefing.pendingProposals.isEmpty {
                            Button("Open Mission Control") {
                                handleRoute(.missionControl)
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                }
            } else if let errorMessage = briefingModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var systemStatusCard: some View {
        briefingLandingCard(
            eyebrow: "System Status",
            title: systemStatusTitle,
            subtitle: systemStatusSubtitle
        ) {
            VStack(alignment: .leading, spacing: 10) {
                statusRow(label: "Connection", value: connectionSummary)
                statusRow(label: "Signals", value: signalsSummary)
                statusRow(label: "System", value: memorySummary)
            }
        }
    }

    private var nextDecisionCard: some View {
        let attention = briefingModel.briefing.flatMap { briefing in
            OperatorSignalPresentation.decisionAttention(from: cappedBriefing(from: briefing))
        }

        return briefingLandingCard(
            eyebrow: attention == nil ? "Decision Attention" : "Needs Attention",
            title: attention?.title ?? nextDecisionTitle,
            subtitle: attention?.message ?? nextDecisionSubtitle
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if let attention {
                    Text(attention.whyItMatters)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        briefingMetaPill(attention.attention.label, tint: tint(for: attention.attention))
                        briefingMetaPill(attention.recencyLabel, tint: .jeevesSky)
                    }

                    Button(attention.route.label) {
                        handleRoute(attention.route)
                    }
                    .font(.caption.weight(.semibold))
                } else {
                    Text("No operator decision is waiting right now.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func briefingLandingCard<Content: View>(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow.uppercased())
                .font(.caption.monospaced())
                .foregroundStyle(Color.jeevesGold)

            Text(title)
                .font(.headline)
                .foregroundStyle(Color.jeevesInk)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(Color.jeevesSubtleText)
                .fixedSize(horizontal: false, vertical: true)

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(landingCardBackground(accent: .jeevesGold))
    }

    private func operatorBriefingCard(_ item: OperatorBriefingItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.jeevesInk)

                Spacer(minLength: 12)

                Text(item.recencyLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)
            }

            HStack(spacing: 8) {
                briefingMetaPill(item.sourceLabel, tint: .jeevesSky)
                briefingMetaPill(item.attention.label, tint: tint(for: item.attention))
            }

            Text(item.summary)
                .font(.footnote)
                .foregroundStyle(Color.jeevesInk)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Why it matters".uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.jeevesMutedText)

                Text(item.whyItMatters)
                    .font(.caption)
                    .foregroundStyle(Color.jeevesSubtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button("Read more") {
                    selectedBriefingItem = item.detailItem
                }
                .font(.caption.weight(.semibold))

                Button(item.route.label) {
                    handleRoute(item.route)
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.74))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint(for: item.attention).opacity(0.14), lineWidth: 1)
                )
        )
    }

    private func briefingMetaPill(_ label: String, tint: Color) -> some View {
        Text(label)
            .font(.caption2.monospaced())
            .foregroundStyle(Color.jeevesInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }

    private func tint(for attention: OperatorAttentionLevel) -> Color {
        switch attention {
        case .informational:
            return .jeevesMint
        case .noteworthy:
            return .jeevesGold
        case .needsAttention:
            return .orange
        }
    }

    private func handleRoute(_ route: OperatorSignalRoute) {
        switch route {
        case .observatory, .radar, .knowledge:
            NotificationCenter.default.post(name: .jeevesOpenObservatoryTab, object: nil)
        case .missionControl:
            NotificationCenter.default.post(name: .jeevesOpenMissionControlTab, object: nil)
        }
    }

    private func statusRow(label: String, value: String) -> some View {
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

    private func landingCardBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.90))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(accent.opacity(0.16), lineWidth: 1)
            )
    }

    private var systemStatusTitle: String {
        if gateway.useMock || gateway.host.lowercased() == "mock" {
            return "Demo mode is active."
        }
        if gateway.isConnected {
            return "The governed system is connected."
        }
        return "The system is not connected yet."
    }

    private var systemStatusSubtitle: String {
        if gateway.useMock || gateway.host.lowercased() == "mock" {
            return "You are exploring Jeeves with safe preview data."
        }
        if gateway.isConnected {
            return "Live signals, decisions, and knowledge can now reach the operator."
        }
        return "Connect your gateway in the System tab to see live signals and pending decisions."
    }

    private var connectionSummary: String {
        if gateway.useMock || gateway.host.lowercased() == "mock" {
            return "Mock preview"
        }
        if gateway.isConnected {
            return "Connected to \(gateway.host):\(gateway.port)"
        }
        return "Not connected"
    }

    private var signalsSummary: String {
        if let briefing = briefingModel.briefing {
            return "\(briefing.counts.groupedSignals) important signals, \(briefing.counts.knowledgeSignals24h) recent knowledge updates"
        }
        return "Briefing data will summarize signals here."
    }

    private var memorySummary: String {
        let knowledgeCount = poller.recentKnowledgeObjects.count
        if knowledgeCount > 0 {
            return "\(knowledgeCount) knowledge item\(knowledgeCount == 1 ? "" : "s") retained"
        }
        return "No retained knowledge is visible yet."
    }

    private var nextDecisionTitle: String {
        let count = poller.pendingProposals.count
        if count > 0 {
            return "\(count) pending decision\(count == 1 ? "" : "s") need attention."
        }
        return "No pending decision is blocking the system."
    }

    private var nextDecisionSubtitle: String {
        if poller.pendingProposals.count > 0 {
            return "Jeeves has already filtered the queue down to governed work that needs your attention."
        }
        return "When something matters, Jeeves will bring the next governed decision here."
    }

    private func cappedBriefing(from briefing: DailyBriefing) -> DailyBriefing {
        DailyBriefing(
            generatedAtIso: briefing.generatedAtIso,
            headline: briefing.headline,
            statusLine: briefing.statusLine,
            quiet: briefing.quiet,
            overview: Array(briefing.overview.prefix(3)),
            counts: briefing.counts,
            system: briefing.system,
            attention: Array(briefing.attention.prefix(4)),
            signals: Array(briefing.signals.prefix(4)),
            pendingProposals: Array(briefing.pendingProposals.prefix(2)),
            evidence: Array(briefing.evidence.prefix(4)),
            lastSignalAtIso: briefing.lastSignalAtIso,
            lastKnowledgeAtIso: briefing.lastKnowledgeAtIso,
            discoveryPulse: briefing.discoveryPulse
        )
    }

    private func worldSituationItems(from briefing: DailyBriefing) -> [DailyBriefingItem] {
        Array(briefing.attention.prefix(5))
    }

    private func aiDevelopmentItems(from briefing: DailyBriefing) -> [DailyBriefingSignalGroup] {
        Array(briefing.signals.prefix(5))
    }

    private func discoveryHintItems(from briefing: DailyBriefing) -> [JeevesDiscoveryHint] {
        let pulseHints: [JeevesDiscoveryHint] = briefing.discoveryPulse?.cells.compactMap { cell -> JeevesDiscoveryHint? in
            let summary = cell.topHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !summary.isEmpty else { return nil }
            return JeevesDiscoveryHint(
                id: cell.cellId,
                title: discoveryPatternTitle(for: cell),
                summary: operatorFacingSummary(summary),
                meta: "\(cell.clusterCount) related signal\(cell.clusterCount == 1 ? "" : "s")",
                objectId: nil
            )
        } ?? []

        if !pulseHints.isEmpty {
            return Array(pulseHints.prefix(5))
        }

        return Array(briefing.evidence.prefix(5)).map { object in
            JeevesDiscoveryHint(
                id: object.objectId,
                title: operatorFacingTitle(object.title),
                summary: operatorFacingSummary(object.summary),
                meta: operatorFacingMeta(object.kind),
                objectId: object.objectId
            )
        }
    }

    private func intelligencePhase(for briefing: DailyBriefing) -> IntelligencePhaseStage {
        if !briefing.pendingProposals.isEmpty {
            return .safety
        }

        if !discoveryHintItems(from: briefing).isEmpty || !(briefing.discoveryPulse?.cells.isEmpty ?? true) {
            return .investigate
        }

        return .define
    }

    private func intelligencePhaseSummary(for briefing: DailyBriefing) -> String {
        switch intelligencePhase(for: briefing) {
        case .safety:
            return "Safety is foregrounded because governed proposals are already waiting for explicit human review."
        case .define:
            return "Define is foregrounded because the morning brief is turning broad external movement into a usable frame for the day."
        case .investigate:
            return "Investigate is foregrounded because emerging patterns and discovery hints are active enough to justify deeper study."
        }
    }

    private func dailyBriefingItem(from signal: DailyBriefingSignalGroup) -> DailyBriefingItem {
        DailyBriefingItem(
            itemId: signal.groupId,
            kind: "signal",
            title: signal.title,
            summary: signal.summary,
            why: signal.why,
            score: Double(signal.signalCount),
            createdAtIso: signal.latestDetectedAtIso,
            sourceCount: signal.sourceCount,
            objectId: nil,
            proposalId: nil,
            relatedObjectIds: signal.relatedObjectIds
        )
    }

    private func discoveryPatternTitle(for cell: BriefingDiscoveryPulseCell) -> String {
        switch cell.intensity {
        case "hot":
            return "New convergence"
        case "rising":
            return "Rising signal"
        default:
            return "Emerging pattern"
        }
    }

    private func operatorFacingSummary(_ text: String) -> String {
        let lowered = text.lowercased()
        if lowered.contains("langchain") && lowered.contains("internet evidence") {
            return "LangChain ecosystem activity is contributing to this pattern."
        }
        if lowered.contains("discovery review") {
            return "New research signals are reinforcing this direction."
        }
        if lowered.contains("challenge review") {
            return "Further investigation is warranted across multiple signals."
        }

        return text
            .replacingOccurrences(of: "gravity", with: "pressure", options: .caseInsensitive)
            .replacingOccurrences(of: "cluster", with: "pattern", options: .caseInsensitive)
            .replacingOccurrences(of: "cell", with: "zone", options: .caseInsensitive)
            .replacingOccurrences(of: "emergence candidate", with: "emerging pattern", options: .caseInsensitive)
            .replacingOccurrences(of: "discovery candidate", with: "emerging pattern", options: .caseInsensitive)
            .replacingOccurrences(of: "cross-domain overlap", with: "multi-domain signal convergence", options: .caseInsensitive)
            .replacingOccurrences(of: "disc-paper", with: "research signal", options: .caseInsensitive)
            .replacingOccurrences(of: "internet evidence", with: "ecosystem activity", options: .caseInsensitive)
    }

    private func operatorFacingTitle(_ text: String) -> String {
        let lowered = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered.contains("possible emerging cluster") {
            return "Emerging pattern"
        }
        if lowered.contains("discovery review") {
            return "New research signal detected"
        }
        if lowered.contains("challenge review") {
            return "Investigation suggested"
        }
        if lowered.contains("internet evidence") && lowered.contains("langchain") {
            return "LangChain ecosystem activity"
        }
        if lowered.contains("internet evidence") {
            return "Ecosystem activity"
        }

        return text
            .replacingOccurrences(of: "gravity intersection", with: "pressure pattern", options: .caseInsensitive)
            .replacingOccurrences(of: "discovery candidate", with: "emerging pattern", options: .caseInsensitive)
            .replacingOccurrences(of: "disc-paper", with: "research signal", options: .caseInsensitive)
    }

    private func operatorFacingMeta(_ text: String) -> String {
        text
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "discovery", with: "signal", options: .caseInsensitive)
    }

    private func pulseCells(from pulse: BriefingDiscoveryPulse) -> [DiscoveryCell] {
        pulse.cells.map { cell in
            DiscoveryCell(
                id: cell.cellId,
                title: cell.title,
                subtitle: "",
                intensity: RadarIntensity(rawValue: cell.intensity) ?? .quiet,
                clusterCount: cell.clusterCount,
                hints: cell.topHint.map { hint in
                    [DiscoveryHint(
                        id: "\(cell.cellId)-hint",
                        topic: hint,
                        why: "",
                        sourceCount: 0,
                        noveltyScore: 0,
                        pressureScore: 0
                    )]
                } ?? []
            )
        }
    }

    private func relatedEvidence(for item: DailyBriefingItem) -> [KnowledgeObject] {
        guard let briefing = briefingModel.briefing else { return [] }
        let ids = Set(item.relatedObjectIds + [item.objectId].compactMap { $0 })
        if ids.isEmpty {
            return []
        }
        return briefing.evidence.filter { ids.contains($0.objectId) }
    }

    private func fetchAndShowKnowledgeGraph(objectId: String) {
        loadingKnowledgeGraph = true
        knowledgeGraphData = nil
        showKnowledgeGraph = true

        Task {
            if gateway.useMock || gateway.host.lowercased() == "mock" {
                await MainActor.run {
                    knowledgeGraphData = KnowledgeGraphResponse(
                        ok: true,
                        root: KnowledgeObject(
                            objectId: objectId,
                            kind: "evidence",
                            createdAtIso: ISO8601DateFormatter().string(from: Date()),
                            title: "Demo evidence object",
                            summary: "Structured evidence shown from the local demo briefing.",
                            sourceRefs: nil,
                            linkedObjectIds: ["demo-linked-1"],
                            metadata: nil
                        ),
                        linked: [
                            KnowledgeObject(
                                objectId: "demo-linked-1",
                                kind: "discovery",
                                createdAtIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-300)),
                                title: "Related discovery",
                                summary: "A linked pattern grounded in the same evidence.",
                                sourceRefs: nil,
                                linkedObjectIds: nil,
                                metadata: nil
                            )
                        ],
                        edges: nil
                    )
                    loadingKnowledgeGraph = false
                }
                return
            }

            let resolved = await gateway.resolveEndpoint()
            guard let token = resolved.token, !token.isEmpty else {
                await MainActor.run {
                    loadingKnowledgeGraph = false
                }
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
                await MainActor.run {
                    loadingKnowledgeGraph = false
                }
            }
        }
    }
}

private struct JeevesDiscoveryHint: Identifiable {
    let id: String
    let title: String
    let summary: String
    let meta: String
    let objectId: String?
}

private struct JeevesBriefingCard: View {
    let title: String
    let summary: String
    let meta: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(summary)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 6, height: 6)
                Text(meta)
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(accent)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.10), accent.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.14), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}


struct JeevesEmptyState: View {
    let icon: String
    var tint: Color = .secondary.opacity(0.4)
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .light, design: .rounded))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.jeevesHeadline)

            Text(subtitle)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}
