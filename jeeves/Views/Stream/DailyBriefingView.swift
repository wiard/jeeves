import SwiftUI

struct DailyBriefingView: View {
    let briefing: DailyBriefing
    let warning: String?
    let onSelectAttention: (DailyBriefingItem) -> Void
    let onSelectSignal: (DailyBriefingSignalGroup) -> Void
    let onSelectEvidence: (KnowledgeObject) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BriefingHeroPanel(briefing: briefing, warning: warning)
            BriefingSystemPanel(system: briefing.system)

            if !briefing.attention.isEmpty {
                BriefingSectionHeader(
                    title: "What deserves attention",
                    subtitle: "Ranked and capped for the operator."
                )
                ForEach(briefing.attention) { item in
                    Button {
                        onSelectAttention(item)
                    } label: {
                        BriefingAttentionCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !briefing.signals.isEmpty {
                BriefingSectionHeader(
                    title: "What changed",
                    subtitle: "Grouped signals, not the raw feed."
                )
                ForEach(briefing.signals) { signal in
                    Button {
                        onSelectSignal(signal)
                    } label: {
                        BriefingSignalCard(signal: signal)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !briefing.evidence.isEmpty {
                BriefingSectionHeader(
                    title: "Supporting evidence",
                    subtitle: "Tap to inspect the underlying knowledge objects."
                )
                ForEach(briefing.evidence) { object in
                    Button {
                        onSelectEvidence(object)
                    } label: {
                        BriefingEvidenceCard(object: object)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !briefing.pendingProposals.isEmpty {
                BriefingSectionHeader(
                    title: "Needs approval",
                    subtitle: "Consent-first actions waiting in the system."
                )
                ForEach(Array(briefing.pendingProposals.prefix(3))) { proposal in
                    BriefingProposalCard(proposal: proposal)
                }
            }
        }
    }
}

struct DailyBriefingExplanationSheet: View {
    let item: DailyBriefingItem
    let relatedEvidence: [KnowledgeObject]
    let onSelectEvidence: (KnowledgeObject) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.jeevesHeadline)
                        Text(item.summary)
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)
                        Text("Why this matters")
                            .font(.jeevesMono)
                            .fontWeight(.semibold)
                            .padding(.top, 4)
                        Text(item.why)
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)
                    }
                    .briefingPanel()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Context")
                            .font(.jeevesMono)
                            .fontWeight(.semibold)
                        HStack(spacing: 10) {
                            contextChip(item.kind)
                            contextChip("\(item.sourceCount) bron\(item.sourceCount == 1 ? "" : "nen")")
                            contextChip("score \(scoreText)")
                        }
                    }
                    .briefingPanel()

                    if !relatedEvidence.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Evidence")
                                .font(.jeevesMono)
                                .fontWeight(.semibold)
                            ForEach(relatedEvidence) { object in
                                Button {
                                    onSelectEvidence(object)
                                } label: {
                                    BriefingEvidenceCard(object: object)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .briefingPanel()
                    }
                }
                .padding()
            }
            .navigationTitle("Why this matters")
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

    private var scoreText: String {
        item.score >= 1 ? String(format: "%.0f", item.score) : String(format: "%.2f", item.score)
    }

    private func contextChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(.secondarySystemFill))
            .clipShape(Capsule())
    }
}

struct DailyBriefingKnowledgeGraphSheet: View {
    let graphData: KnowledgeGraphResponse?
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Evidence laden...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let graph = graphData {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if let root = graph.root {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Root")
                                        .font(.jeevesMono)
                                        .fontWeight(.semibold)
                                    BriefingEvidenceCard(object: root)
                                }
                                .briefingPanel()
                            }

                            if let linked = graph.linked, !linked.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Linked evidence")
                                        .font(.jeevesMono)
                                        .fontWeight(.semibold)
                                    ForEach(linked) { object in
                                        BriefingEvidenceCard(object: object)
                                    }
                                }
                        .briefingPanel()
                            }
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "Evidence niet beschikbaar",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("De kennisgraaf kon niet worden geladen.")
                    )
                }
            }
            .navigationTitle("Supporting Evidence")
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
}

private struct BriefingHeroPanel: View {
    let briefing: DailyBriefing
    let warning: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Briefing")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            Text(briefing.headline)
                .font(.jeevesHeadline)
            Text(briefing.statusLine)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)

            if !briefing.overview.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(briefing.overview, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(line)
                                .font(.jeevesBody)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                metricCell(label: "Approvals", value: briefing.counts.pendingApprovals, tint: .orange)
                metricCell(label: "Signals", value: briefing.counts.groupedSignals, tint: .cyan)
                metricCell(label: "Evidence", value: briefing.counts.recentEvidence, tint: .indigo)
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

private struct BriefingSystemPanel: View {
    let system: DailyBriefingSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("System status")
                .font(.jeevesMono)
                .fontWeight(.semibold)
            HStack(spacing: 10) {
                statusChip("Conductor", system.conductor.status)
                statusChip("Signals", system.signalRuntime.status)
                statusChip("Knowledge", system.knowledge.status)
                statusChip("Freshness", system.freshness.status)
            }

            if !system.knowledge.topCubeCells.isEmpty {
                Text("Top cube cells: \(system.knowledge.topCubeCells.joined(separator: ", "))")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .briefingPanel()
    }

    private func statusChip(_ title: String, _ status: String) -> some View {
        let tint: Color
        switch status {
        case "healthy":
            tint = .green
        case "attention":
            tint = .orange
        default:
            tint = .red
        }
        return HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
            Text(status)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
        }
        .foregroundStyle(.secondary)
    }
}

private struct BriefingSectionHeader: View {
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
    }
}

private struct BriefingAttentionCard: View {
    let item: DailyBriefingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title)
                    .font(.jeevesBody.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(item.kind)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text(item.summary)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text(item.why)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .briefingPanel()
    }
}

private struct BriefingSignalCard: View {
    let signal: DailyBriefingSignalGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(signal.title)
                    .font(.jeevesBody.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(signal.signalCount)")
                    .font(.jeevesMono)
                    .foregroundStyle(.cyan)
            }
            Text(signal.summary)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text(signal.why)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
        }
        .briefingPanel()
    }
}

private struct BriefingEvidenceCard: View {
    let object: KnowledgeObject

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(object.title)
                    .font(.jeevesBody.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(object.kind.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text(object.summary)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .briefingPanel()
    }
}

private struct BriefingProposalCard: View {
    let proposal: Proposal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(proposal.title)
                    .font(.jeevesBody.weight(.semibold))
                Spacer()
                Text(proposal.intent.risk)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.orange)
            }
            Text("\(proposal.agentId) · \(proposal.intent.key)")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .briefingPanel()
    }
}

extension View {
    func briefingPanel() -> some View {
        self
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
