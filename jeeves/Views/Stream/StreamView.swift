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
