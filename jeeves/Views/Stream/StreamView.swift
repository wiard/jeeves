
import SwiftUI

struct StreamView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @State private var knowledgeGraphData: KnowledgeGraphResponse?
    @State private var showKnowledgeGraph = false
    @State private var loadingKnowledgeGraph = false

    var body: some View {
        NavigationStack {
            Group {
                if !poller.hasLoadedOnce {
                    ProgressView("Mission Control laden...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if hasNoRenderableContent {
                    ContentUnavailableView(
                        TextKeys.Stream.empty,
                        systemImage: "list.bullet.rectangle",
                        description: Text(poller.lastRefreshError ?? "Mission Control heeft nog geen operationele signalen.")
                    )
                } else {
                    missionControlContent
                }
            }
            .navigationTitle("Mission Control")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .refreshable {
                await poller.refresh(gateway: gateway)
            }
            .task {
                if !poller.hasLoadedOnce {
                    await poller.refresh(gateway: gateway)
                }
            }
            .onChange(of: gateway.isConnected) {
                if gateway.isConnected {
                    Task {
                        await poller.refresh(gateway: gateway)
                    }
                }
            }
            .sheet(isPresented: $showKnowledgeGraph) {
                DailyBriefingKnowledgeGraphSheet(
                    graphData: knowledgeGraphData,
                    isLoading: loadingKnowledgeGraph
                )
            }
        }
    }

    private var missionControlContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MissionControlHeroPanel(
                    pendingCount: poller.pendingProposals.count,
                    emergenceCount: poller.emergenceClusters.count,
                    knowledgeCount: poller.recentKnowledgeObjects.count,
                    lastSuccessfulRefreshAt: poller.lastSuccessfulRefreshAt,
                    warning: poller.lastRefreshError
                )

                if let store = poller.radarStatus?.store {
                    DailyBriefingSectionHeader(
                        title: "Radar status",
                        subtitle: "Operational signal volume across the collector."
                    )
                    RadarSummaryRow(
                        activations: store.activationCount,
                        collisions: store.collisionCount,
                        emergence: store.emergenceCount
                    )
                }

                if !pendingProposalItems.isEmpty {
                    DailyBriefingSectionHeader(
                        title: "Pending approvals",
                        subtitle: "Operator decisions waiting in the queue."
                    )
                    ForEach(pendingProposalItems) { proposal in
                        ProposalRow(proposal: proposal)
                    }
                }

                if !emergenceItems.isEmpty {
                    DailyBriefingSectionHeader(
                        title: "Emergence",
                        subtitle: "Escalated structural patterns seen by the runtime."
                    )
                    ForEach(emergenceItems) { cluster in
                        EmergenceRow(cluster: cluster)
                    }
                }

                if let action = poller.lastActionReceipt {
                    DailyBriefingSectionHeader(
                        title: "Last action receipt",
                        subtitle: "Most recent governed execution result."
                    )
                    ActionReceiptRow(action: action)
                }

                if !recentKnowledgeItems.isEmpty {
                    DailyBriefingSectionHeader(
                        title: "Recent knowledge",
                        subtitle: "Fresh evidence and knowledge objects entering the kernel."
                    )
                    ForEach(recentKnowledgeItems) { object in
                        Button {
                            fetchAndShowKnowledgeGraph(objectId: object.objectId)
                        } label: {
                            KnowledgeObjectRow(object: object)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !recentSignalEvents.isEmpty {
                    DailyBriefingSectionHeader(
                        title: "Recent activity",
                        subtitle: "Mission-level runtime activity, not the operator briefing."
                    )
                    ForEach(recentSignalEvents) { event in
                        eventRow(for: event)
                    }
                }
            }
            .padding()
        }
    }

    private var pendingProposalItems: [Proposal] {
        Array(poller.pendingProposals.prefix(4))
    }

    private var emergenceItems: [EmergenceCluster] {
        Array(poller.emergenceClusters.prefix(3))
    }

    private var recentKnowledgeItems: [KnowledgeObject] {
        Array(poller.recentKnowledgeObjects.prefix(5))
    }

    private var recentSignalEvents: [ObservatoryStreamEvent] {
        Array(poller.streamEvents.prefix(6))
    }

    private var hasNoRenderableContent: Bool {
        poller.pendingProposals.isEmpty
            && poller.streamEvents.isEmpty
            && poller.emergenceClusters.isEmpty
            && poller.recentKnowledgeObjects.isEmpty
            && poller.lastActionReceipt == nil
    }

    @ViewBuilder
    private func eventRow(for event: ObservatoryStreamEvent) -> some View {
        switch event.type {
        case "paper_signal", "signal_detected":
            PaperSignalRow(event: event)
        case "gravity_hotspot":
            GravityHotspotRow(event: event)
        case "discovery_candidate":
            DiscoveryCandidateRow(event: event)
        default:
            StreamEventRow(event: event)
        }
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
                            summary: "Structured evidence shown from the local demo knowledge state.",
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
                                summary: "A linked discovery candidate grounded in the same evidence.",
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

private struct MissionControlHeroPanel: View {
    let pendingCount: Int
    let emergenceCount: Int
    let knowledgeCount: Int
    let lastSuccessfulRefreshAt: Date?
    let warning: String?

    private var refreshLabel: String {
        guard let lastSuccessfulRefreshAt else { return "Nog geen succesvolle refresh." }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Laatste refresh om \(formatter.string(from: lastSuccessfulRefreshAt))."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mission Control")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)

            Text("Operationele staat van het systeem")
                .font(.jeevesHeadline)

            Text(refreshLabel)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                metricCell(label: "Approvals", value: pendingCount, tint: .orange)
                metricCell(label: "Emergence", value: emergenceCount, tint: .purple)
                metricCell(label: "Knowledge", value: knowledgeCount, tint: .indigo)
            }

            if let warning, !warning.isEmpty {
                Text(warning)
                    .font(.jeevesCaption)
                    .foregroundStyle(.orange)
            }
        }
        .briefingPanel()
    }

    private func metricCell(label: String, value: Int, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.jeevesMono)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DailyBriefingHeroCard: View {
    let briefing: DailyBriefing
    let warning: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Daily Briefing")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)

                    Text(briefing.headline)
                        .font(.jeevesMono)
                        .fontWeight(.semibold)

                    Text(briefing.statusLine)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if briefing.quiet {
                    Text("quiet")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green)
                } else if briefing.counts.stale {
                    Text("stale")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 8) {
                briefingMetric(label: "Approvals", value: briefing.counts.pendingApprovals, tint: .orange)
                briefingMetric(label: "Signals", value: briefing.counts.groupedSignals, tint: .cyan)
                briefingMetric(label: "Evidence", value: briefing.counts.recentEvidence, tint: .indigo)
            }

            if !briefing.overview.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(briefing.overview, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                            Text(line)
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let warning, !warning.isEmpty {
                Text(warning)
                    .font(.jeevesCaption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.jeevesGold.opacity(0.18), Color.blue.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func briefingMetric(label: String, value: Int, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.jeevesMono)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct DailyBriefingSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.jeevesMono)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

private struct DailyBriefingAttentionRow: View {
    let item: DailyBriefingItem

    private var icon: String {
        switch item.kind {
        case "approval":
            return "checkmark.shield"
        case "discovery":
            return "sparkle.magnifyingglass"
        case "emergence":
            return "waveform.path.ecg"
        default:
            return "doc.text.magnifyingglass"
        }
    }

    private var tint: Color {
        switch item.kind {
        case "approval":
            return .orange
        case "discovery":
            return .cyan
        case "emergence":
            return .purple
        default:
            return .indigo
        }
    }

    private var timeString: String {
        guard let date = item.createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var scoreText: String {
        item.score >= 1 ? String(format: "%.0f", item.score) : String(format: "%.2f", item.score)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeString)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.jeevesMono)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(item.summary)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Text("Why this matters: \(item.why)")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Text(item.kind)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tint)
                    Text("score \(scoreText)")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    Text("\(item.sourceCount) bron\(item.sourceCount == 1 ? "" : "nen")")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct DailyBriefingWarningRow: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.jeevesCaption)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct RadarSummaryRow: View {
    let activations: Int
    let collisions: Int
    let emergence: Int

    var body: some View {
        HStack(spacing: 8) {
            summaryCell(label: "Activations", value: activations)
            summaryCell(label: "Collisions", value: collisions)
            summaryCell(label: "Emergence", value: emergence)
        }
        .padding(12)
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func summaryCell(label: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.jeevesMono)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProposalRow: View {
    let proposal: Proposal

    private var timeString: String {
        guard let date = proposal.createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var statusIcon: String {
        if proposal.isApproved { return "\u{2713}" }
        if proposal.isDenied { return "\u{2717}" }
        return "\u{231B}"
    }

    private var statusColor: Color {
        if proposal.isApproved { return .green }
        if proposal.isDenied { return .red }
        return .orange
    }

    private var statusLabel: String {
        if proposal.isApproved { return TextKeys.Stream.approved }
        if proposal.isDenied { return TextKeys.Stream.denied }
        return TextKeys.Stream.pending
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeString)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Text(statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(proposal.agentId)
                    .font(.jeevesMono)
                    .fontWeight(.medium)

                Text(proposal.title)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(statusLabel)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var rowBackground: Color {
        if proposal.isPending { return .orange.opacity(0.08) }
        if proposal.isDenied { return .red.opacity(0.08) }
        return Color(.secondarySystemFill)
    }
}

private struct EmergenceRow: View {
    let cluster: EmergenceCluster

    private func emergenceSummary(for cluster: EmergenceCluster) -> String {
        let text = cluster.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty && text != "No summary available." {
            return text
        }
        if !cluster.dimensions.isEmpty {
            return "Emergent patroon: \(cluster.dimensions.joined(separator: "/"))"
        }
        return "Emergent patroon"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("")
                .frame(width: 40, alignment: .leading)

            Text("\u{26A1}")
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(emergenceSummary(for: cluster))
                    .font(.jeevesMono)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("\(cluster.dimensions.count) \(TextKeys.Emergence.sources)")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    Text("\(TextKeys.Emergence.score): \(cluster.relevanceScore, specifier: "%.2f")")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct StreamEventRow: View {
    let event: ObservatoryStreamEvent

    private var timeString: String {
        guard let date = ISO8601DateFormatter().date(from: event.timestampIso ?? "") else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var titleText: String {
        event.displayTitle
    }

    private var detailText: String {
        let source = event.agentId ?? event.sourceId ?? event.peerId ?? "observatory"
        if let reason = event.reason, !reason.isEmpty {
            return "\(source) · \(reason)"
        }
        if let decision = event.decision, !decision.isEmpty {
            return "\(source) · \(decision)"
        }
        return source
    }

    private var eventTypeLabel: String {
        event.type.replacingOccurrences(of: "_", with: " ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeString)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Text("\u{25E6}")
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.jeevesMono)
                    .fontWeight(.medium)

                Text(detailText)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(eventTypeLabel)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PaperSignalRow: View {
    let event: ObservatoryStreamEvent

    private var timeString: String {
        guard let date = ISO8601DateFormatter().date(from: event.timestampIso ?? "") else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var sourceBadges: [String] {
        mergeSources(primary: [event.sourceId], secondary: event.reason)
    }

    private var whyMatters: String {
        readableWhyMatters(
            type: event.type,
            explanation: event.explanation,
            summary: event.summary,
            reason: event.reason
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeString)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Text("\u{25C8}")
                .foregroundStyle(.indigo)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title ?? event.displayTitle)
                    .font(.jeevesMono)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if !sourceBadges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(sourceBadges, id: \.self) { source in
                            SourceBadge(source: source)
                        }
                    }
                }

                Text("Why this matters: \(whyMatters)")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.indigo.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct GravityHotspotRow: View {
    let event: ObservatoryStreamEvent

    private var timeString: String {
        guard let date = ISO8601DateFormatter().date(from: event.timestampIso ?? "") else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var bandColor: Color {
        switch event.band ?? "" {
        case "red": return .red
        case "yellow": return .orange
        case "green": return .green
        default: return .blue
        }
    }

    private var scoreText: String {
        guard let score = event.gravityScore else { return "" }
        return String(format: "%.1f", score)
    }

    private var sourceBadges: [String] {
        mergeSources(primary: [event.sourceId], secondary: event.reason)
    }

    private var whyMatters: String {
        readableWhyMatters(
            type: event.type,
            explanation: event.explanation,
            summary: event.summary,
            reason: event.reason
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeString)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Circle()
                .fill(bandColor)
                .frame(width: 10, height: 10)
                .padding(.top, 4)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.explanation ?? event.displayTitle)
                    .font(.jeevesMono)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("gravity \(scoreText)")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    if let band = event.band {
                        Text(band)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(bandColor)
                    }
                    if let rank = event.rank {
                        Text("#\(rank)")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !sourceBadges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(sourceBadges, id: \.self) { source in
                            SourceBadge(source: source)
                        }
                    }
                }

                Text("Why this matters: \(whyMatters)")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(bandColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DiscoveryCandidateRow: View {
    let event: ObservatoryStreamEvent

    private var timeString: String {
        guard let date = ISO8601DateFormatter().date(from: event.timestampIso ?? "") else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var scoreText: String {
        guard let score = event.candidateScore else { return "" }
        return String(format: "%.2f", score)
    }

    private var sourceBadges: [String] {
        mergeSources(primary: [event.sourceId], secondary: event.reason)
    }

    private var whyMatters: String {
        readableWhyMatters(
            type: event.type,
            explanation: event.explanation,
            summary: event.summary,
            reason: event.reason
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeString)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Text("\u{1F52D}")
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.explanation ?? event.displayTitle)
                    .font(.jeevesMono)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    if let candidateType = event.candidateType {
                        Text(candidateType.replacingOccurrences(of: "_", with: " "))
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                    if !scoreText.isEmpty {
                        Text("score \(scoreText)")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                    if event.crossDomain == true {
                        Text("cross-domain")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.cyan)
                    }
                    if let rank = event.rank {
                        Text("#\(rank)")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !sourceBadges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(sourceBadges, id: \.self) { source in
                            SourceBadge(source: source)
                        }
                    }
                }

                Text("Why this matters: \(whyMatters)")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.cyan.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ActionReceiptRow: View {
    let action: ActionSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("")
                .frame(width: 40, alignment: .leading)

            Image(systemName: action.isCompleted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(action.isCompleted ? .green : .red)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.actionKind)
                    .font(.jeevesMono)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(action.executionState)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    if let receipt = action.receipt, let duration = receipt.durationMs {
                        Text("\(Int(duration))ms")
                            .font(.jeevesMono)
                            .foregroundStyle(.secondary)
                    }
                }

                if let receipt = action.receipt {
                    Text(receipt.resultSummary)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text("actie")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(action.isCompleted ? .green : .red)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(action.isCompleted ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct KnowledgeObjectRow: View {
    let object: KnowledgeObject

    private var timeString: String {
        guard let date = object.createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var kindColor: Color {
        switch object.kind {
        case "discovery": return .cyan
        case "decision": return .orange
        case "action_receipt": return .green
        case "investigation_outcome": return .purple
        case "evidence": return .indigo
        default: return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeString)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Text(object.kindEmoji)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(object.title)
                    .font(.jeevesMono)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(object.summary)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(object.kind.replacingOccurrences(of: "_", with: " "))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(kindColor)

                    if let refs = object.sourceRefs, !refs.isEmpty {
                        Text("\(refs.count) bron\(refs.count == 1 ? "" : "nen")")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(kindColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct RadarCollisionRow: View {
    let collision: RadarCollision

    private var timeString: String {
        guard let date = ISO8601DateFormatter().date(from: collision.detectedAtIso ?? "") else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private var summaryText: String {
        if let first = collision.signalTitles.first, !first.isEmpty {
            return first
        }
        if !collision.sources.isEmpty {
            return collision.sources.joined(separator: " × ")
        }
        return "Collision detected"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeString)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Text("\u{26A1}")
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(summaryText)
                    .font(.jeevesMono)
                    .fontWeight(.medium)

                Text("density \(String(format: "%.2f", collision.density)) · \(collision.sources.count) bronnen")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct SourceBadge: View {
    let source: String

    private var label: String {
        switch source {
        case "openalex":
            return "OpenAlex"
        case "arxiv":
            return "arXiv"
        case "github":
            return "GitHub"
        case "manual":
            return "Manual"
        default:
            return source.capitalized
        }
    }

    private var tint: Color {
        switch source {
        case "openalex":
            return .indigo
        case "arxiv":
            return .orange
        case "github":
            return .green
        case "manual":
            return .gray
        default:
            return .secondary
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

private func mergeSources(primary: [String?], secondary: String?) -> [String] {
    var collected: [String] = []

    for item in primary {
        if let normalized = normalizeSource(item), !collected.contains(normalized) {
            collected.append(normalized)
        }
    }

    for raw in splitSourceTokens(secondary) {
        if let normalized = normalizeSource(raw), !collected.contains(normalized) {
            collected.append(normalized)
        }
    }

    return collected
}

private func splitSourceTokens(_ raw: String?) -> [String] {
    guard let raw, !raw.isEmpty else { return [] }
    return raw
        .replacingOccurrences(of: "|", with: "/")
        .replacingOccurrences(of: ",", with: "/")
        .split(separator: "/")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

private func normalizeSource(_ raw: String?) -> String? {
    guard let raw else { return nil }
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if value.isEmpty { return nil }
    switch value {
    case "openalex", "knowledge_openalex":
        return "openalex"
    case "arxiv", "knowledge_arxiv":
        return "arxiv"
    case "github", "knowledge_github":
        return "github"
    case "manual":
        return "manual"
    default:
        return nil
    }
}

private func readableWhyMatters(type: String, explanation: String?, summary: String?, reason: String?) -> String {
    let preferred = [explanation, summary, reason]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }

    if let preferred {
        let cleaned = preferred
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        return cleaned
    }

    switch type {
    case "signal_detected":
        return "A new paper signal aligns with active observatory pressure."
    case "gravity_hotspot":
        return "This cell is attracting sustained attention and can reshape upcoming collisions."
    case "discovery_candidate":
        return "This candidate combines multiple signals into a concrete research direction."
    default:
        return "This event changes the current discovery context."
    }
}
