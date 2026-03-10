
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
                        JeevesMorningBackdrop()
                            .ignoresSafeArea()

                        ScrollView {
                            VStack(spacing: 22) {
                                DailyBriefingView(
                                    briefing: cappedBriefing(from: briefing),
                                    warning: briefingModel.usingCachedFallback ? "Toon gecachte briefing." : briefingModel.errorMessage,
                                    onSelectAttention: { item in
                                        selectedBriefingItem = item
                                    },
                                    onSelectSignal: { signal in
                                        selectedBriefingItem = DailyBriefingItem(
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
                                    },
                                    onSelectEvidence: { object in
                                        fetchAndShowKnowledgeGraph(objectId: object.objectId)
                                    }
                                )

                                if let pulse = briefing.discoveryPulse {
                                    DiscoveryPulsePanel(cells: pulseCells(from: pulse)) {
                                        NotificationCenter.default.post(name: .jeevesOpenObservatoryTab, object: nil)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                } else if let errorMessage = briefingModel.errorMessage {
                    JeevesEmptyState(
                        icon: "sun.max",
                        tint: .secondary.opacity(0.5),
                        title: "Mijn excuses, meneer.",
                        subtitle: errorMessage
                    )
                } else {
                    JeevesEmptyState(
                        icon: "sun.max",
                        tint: Color.jeevesGold.opacity(0.4),
                        title: "Uw briefing wordt voorbereid.",
                        subtitle: "Zodra er evidence binnenkomt, presenteer ik hier de ochtendbriefing."
                    )
                }
            }
            .navigationTitle("Jeeves")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
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

private struct JeevesMorningBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.97, blue: 0.99),
                Color(red: 0.93, green: 0.95, blue: 0.98),
                Color(red: 0.98, green: 0.96, blue: 0.93)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
