import SwiftUI

struct StreamView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller

    var body: some View {
        NavigationStack {
            Group {
                if !poller.hasLoadedOnce {
                    ProgressView("Verbinding maken...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if hasNoRenderableContent {
                    ContentUnavailableView(
                        TextKeys.Stream.empty,
                        systemImage: "leaf",
                        description: Text(poller.lastRefreshError ?? "Er zijn nog geen gebeurtenissen.")
                    )
                } else {
                    streamList
                }
            }
            .navigationTitle(TextKeys.Stream.header)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .refreshable {
                await poller.refresh(gateway: gateway)
            }
            .task {
                if poller.proposals.isEmpty
                    && poller.streamEvents.isEmpty
                    && poller.emergenceClusters.isEmpty {
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
        }
    }

    private var streamList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if let radarStore = poller.radarStatus?.store {
                    RadarSummaryRow(
                        activations: radarStore.activationCount,
                        collisions: radarStore.collisionCount,
                        emergence: radarStore.emergenceCount
                    )
                }

                ForEach(poller.emergenceClusters) { cluster in
                    EmergenceRow(cluster: cluster)
                }

                ForEach(Array(poller.radarEmergence.prefix(5))) { collision in
                    RadarCollisionRow(collision: collision)
                }

                ForEach(sortedStreamEvents) { event in
                    if event.isGravityHotspot {
                        GravityHotspotRow(event: event)
                    } else if event.isDiscoveryCandidate {
                        DiscoveryCandidateRow(event: event)
                    } else if event.type == "signal_detected" {
                        PaperSignalRow(event: event)
                    } else {
                        StreamEventRow(event: event)
                    }
                }

                ForEach(sortedProposals) { proposal in
                    ProposalRow(proposal: proposal)
                }
            }
            .padding()
        }
    }

    private var sortedProposals: [Proposal] {
        poller.proposals.sorted { a, b in
            (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast)
        }
    }

    private var hasNoRenderableContent: Bool {
        let radarCounts = (poller.radarStatus?.store?.activationCount ?? 0)
            + (poller.radarStatus?.store?.collisionCount ?? 0)
            + (poller.radarStatus?.store?.emergenceCount ?? 0)

        return poller.proposals.isEmpty
            && poller.emergenceClusters.isEmpty
            && poller.streamEvents.isEmpty
            && poller.radarCollisions.isEmpty
            && poller.radarEmergence.isEmpty
            && poller.radarActivations.isEmpty
            && poller.radarClusters.isEmpty
            && poller.radarSources.isEmpty
            && poller.radarGravityHotspots.isEmpty
            && poller.radarDiscoveryCandidates.isEmpty
            && radarCounts == 0
    }

    private var sortedStreamEvents: [ObservatoryStreamEvent] {
        poller.streamEvents.sorted { lhs, rhs in
            let lDate = parseIso(lhs.timestampIso)
            let rDate = parseIso(rhs.timestampIso)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.id < rhs.id
        }
    }

    private func parseIso(_ value: String?) -> Date {
        guard let value else { return .distantPast }
        return ISO8601DateFormatter().date(from: value) ?? .distantPast
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
