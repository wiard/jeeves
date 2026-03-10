
import SwiftUI

struct JeevesView: View {
    @Environment(GatewayManager.self) private var gateway
    @State private var briefingModel = DailyBriefingViewModel()
    @State private var selectedBriefingItem: DailyBriefingItem?
    @State private var knowledgeGraphData: KnowledgeGraphResponse?
    @State private var showKnowledgeGraph = false
    @State private var loadingKnowledgeGraph = false

    var body: some View {
        NavigationStack {
            Group {
                if briefingModel.isLoading && !briefingModel.hasLoaded {
                    ProgressView("Jeeves voorbereiden...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let briefing = briefingModel.briefing {
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
                            VStack(spacing: 22) {
                                InstrumentRoleHeader(
                                    eyebrow: "Jeeves",
                                    title: "Morning Intelligence",
                                    summary: "A reasoning instrument for watching geopolitics, frontier AI, and engineering infrastructure together, so emerging patterns can be seen where those domains begin to collide.",
                                    accent: .jeevesGold,
                                    metrics: [
                                        InstrumentRoleMetric(label: "World", value: "\(worldSituationItems(from: briefing).count)"),
                                        InstrumentRoleMetric(label: "AI", value: "\(aiDevelopmentItems(from: briefing).count)"),
                                        InstrumentRoleMetric(label: "Hints", value: "\(discoveryHintItems(from: briefing).count)")
                                    ]
                                )
                                .calmAppear()

                                InstrumentSectionPanel(
                                    eyebrow: "Section One",
                                    title: "World situation",
                                    subtitle: "Geopolitical shifts that may alter the operating environment.",
                                    accent: .jeevesGold,
                                    metric: "\(worldSituationItems(from: briefing).count)"
                                ) {
                                    ForEach(Array(worldSituationItems(from: briefing).enumerated()), id: \.element.id) { index, item in
                                        Button {
                                            selectedBriefingItem = item
                                        } label: {
                                            JeevesBriefingCard(
                                                title: item.title,
                                                summary: item.summary,
                                                meta: item.why,
                                                accent: .jeevesGold
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .calmAppear(delay: 0.12 + (0.07 * Double(index)))
                                    }
                                }
                                .calmAppear(delay: 0.12)

                                InstrumentSectionPanel(
                                    eyebrow: "Section Two",
                                    title: "AI developments",
                                    subtitle: "Frontier AI developments that may change capability, risk, or timing.",
                                    accent: .blue,
                                    metric: "\(aiDevelopmentItems(from: briefing).count)"
                                ) {
                                    ForEach(Array(aiDevelopmentItems(from: briefing).enumerated()), id: \.element.id) { index, signal in
                                        Button {
                                            selectedBriefingItem = dailyBriefingItem(from: signal)
                                        } label: {
                                            JeevesBriefingCard(
                                                title: signal.title,
                                                summary: signal.summary,
                                                meta: signal.why,
                                                accent: .blue
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .calmAppear(delay: 0.12 + (0.07 * Double(index)))
                                    }
                                }
                                .calmAppear(delay: 0.12)

                                InstrumentSectionPanel(
                                    eyebrow: "Section Three",
                                    title: "Discovery hints",
                                    subtitle: "Where geopolitics, AI, and infrastructure begin to converge in CLASHD27 signals.",
                                    accent: .purple,
                                    metric: "\(discoveryHintItems(from: briefing).count)"
                                ) {
                                    ForEach(Array(discoveryHintItems(from: briefing).enumerated()), id: \.element.id) { index, hint in
                                        Button {
                                            if let objectId = hint.objectId {
                                                fetchAndShowKnowledgeGraph(objectId: objectId)
                                            } else {
                                                NotificationCenter.default.post(name: .jeevesOpenObservatoryTab, object: nil)
                                            }
                                        } label: {
                                            JeevesBriefingCard(
                                                title: hint.title,
                                                summary: hint.summary,
                                                meta: hint.meta,
                                                accent: .purple
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .calmAppear(delay: 0.12 + (0.07 * Double(index)))
                                    }
                                }
                                .calmAppear(delay: 0.12)
                            }
                            .padding()
                        }
                    }
                } else if let errorMessage = briefingModel.errorMessage {
                    JeevesEmptyState(
                        icon: "sun.max",
                        tint: .secondary.opacity(0.5),
                        title: "Morning Intelligence is quiet.",
                        subtitle: errorMessage
                    )
                } else {
                    JeevesEmptyState(
                        icon: "sun.max",
                        tint: Color.jeevesGold.opacity(0.4),
                        title: "Morning Intelligence is preparing.",
                        subtitle: "Fresh signals and evidence will settle here when the system has something worth your attention."
                    )
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
                title: cell.title,
                summary: summary,
                meta: "\(cell.clusterCount) active cluster\(cell.clusterCount == 1 ? "" : "s")",
                objectId: nil
            )
        } ?? []

        if !pulseHints.isEmpty {
            return Array(pulseHints.prefix(5))
        }

        return Array(briefing.evidence.prefix(5)).map { object in
            JeevesDiscoveryHint(
                id: object.objectId,
                title: object.title,
                summary: object.summary,
                meta: object.kind.replacingOccurrences(of: "_", with: " "),
                objectId: object.objectId
            )
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

            Text(meta)
                .font(.jeevesMonoSmall)
                .foregroundStyle(accent)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.08))
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
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundStyle(tint)

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
