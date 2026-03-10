import SwiftUI

struct KnowledgeBrowserView: View {
    @Environment(GatewayManager.self) private var gateway
    @State private var viewModel = KnowledgeBrowserViewModel()
    @State private var knowledgeGraphData: KnowledgeGraphResponse?
    @State private var showKnowledgeGraph = false
    @State private var loadingKnowledgeGraph = false

    private var groupedShelves: [KnowledgeShelfSection] {
        KnowledgeShelf.allCases.compactMap { shelf in
            let items = Array(viewModel.objects.filter { classify($0) == shelf }.prefix(5))
            guard !items.isEmpty else { return nil }
            return KnowledgeShelfSection(shelf: shelf, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.97, green: 0.96, blue: 0.94),
                        Color(red: 0.96, green: 0.97, blue: 0.95),
                        Color(red: 0.95, green: 0.96, blue: 0.98)
                    ]
                )
                .ignoresSafeArea()

                Group {
                    if viewModel.isLoading && !viewModel.hasLoaded {
                        let _ = print("[KnowledgeView] branch: loading")
                        ProgressView("Knowledge laden...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.isRateLimited && viewModel.objects.isEmpty {
                        let _ = print("[KnowledgeView] branch: rateLimited+empty")
                        JeevesEmptyState(
                            icon: "clock.arrow.circlepath",
                            title: "Jeeves ordent de bibliotheek even.",
                            subtitle: "Probeer het zo opnieuw."
                        )
                    } else if viewModel.objects.isEmpty && viewModel.errorMessage != nil {
                        let _ = print("[KnowledgeView] branch: error (\(viewModel.errorMessage!))")
                        JeevesEmptyState(
                            icon: "exclamationmark.triangle",
                            title: "Jeeves kon de bibliotheek nu niet openen.",
                            subtitle: viewModel.errorMessage!
                        )
                    } else if viewModel.objects.isEmpty {
                        let _ = print("[KnowledgeView] branch: empty (hasLoaded=\(viewModel.hasLoaded), isLoading=\(viewModel.isLoading))")
                        JeevesEmptyState(
                            icon: "book.closed",
                            title: "De bibliotheek is nog leeg.",
                            subtitle: "Zodra het systeem evidence verwerkt, verschijnen hier de kennisobjecten."
                        )
                    } else {
                        let _ = print("[KnowledgeView] branch: list (\(viewModel.objects.count) objects)")
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                InstrumentRoleHeader(
                                    eyebrow: "Knowledge",
                                    title: "Library",
                                    summary: "Structured shelves for discoveries, evidence, code-adjacent signals, and research currently in circulation.",
                                    accent: .jeevesGold,
                                    metrics: [
                                        InstrumentRoleMetric(label: "Objects", value: "\(viewModel.objects.count)"),
                                        InstrumentRoleMetric(label: "Shelves", value: "\(groupedShelves.count)"),
                                        InstrumentRoleMetric(label: "Focus", value: groupedShelves.first?.shelf.shortLabel ?? "Calm")
                                    ]
                                )
                                .calmAppear()

                                KnowledgeBrowserHero(
                                    count: viewModel.objects.count,
                                    warning: viewModel.errorMessage
                                        ?? (viewModel.isRateLimited ? "Laatste data — server beperkt verzoeken." : nil)
                                )
                                .calmAppear(delay: 0.06)

                                ForEach(Array(groupedShelves.enumerated()), id: \.element.shelf) { index, section in
                                    KnowledgeShelfPanel(section: section) { objectId in
                                        fetchAndShowKnowledgeGraph(objectId: objectId)
                                    }
                                    .calmAppear(delay: 0.10 + (0.05 * Double(index)))
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Jeeves")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .refreshable {
                await viewModel.load(gateway: gateway, force: true)
            }
            .task {
                if !viewModel.hasLoaded {
                    await viewModel.load(gateway: gateway)
                }
            }
            .onChange(of: gateway.isConnected) {
                if gateway.isConnected {
                    Task {
                        await viewModel.load(gateway: gateway, force: true)
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

    private func classify(_ object: KnowledgeObject) -> KnowledgeShelf {
        if object.kind == "discovery" {
            return .discoveries
        }

        let sourceKind = metadataValue(in: object.metadata, path: ["sourceKind"])
            ?? metadataValue(in: object.metadata, path: ["source_kind"])
        let referenceTokens = sourceTokens(for: object)
        let allTokens = ([sourceKind] + referenceTokens)
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if allTokens.contains("github")
            || allTokens.contains("git")
            || allTokens.contains("repo")
            || allTokens.contains("commit")
            || allTokens.contains("code") {
            return .codeSignals
        }

        if allTokens.contains("research")
            || allTokens.contains("paper")
            || allTokens.contains("arxiv")
            || allTokens.contains("pubmed")
            || allTokens.contains("rss")
            || allTokens.contains("journal")
            || allTokens.contains("internet_source") {
            return .research
        }

        return .evidence
    }

    private func sourceTokens(for object: KnowledgeObject) -> [String?] {
        let refs = object.sourceRefs?.flatMap { ref in
            [
                Optional(ref.sourceType),
                Optional(ref.sourceId),
                ref.label,
                ref.url
            ]
        } ?? []

        return refs + [
            metadataValue(in: object.metadata, path: ["provenance", "adapterType"]),
            metadataValue(in: object.metadata, path: ["rawMetadata", "sourceKind"]),
            metadataValue(in: object.metadata, path: ["normalizedContent", "attributes", "sourceKind"])
        ]
    }

    private func metadataValue(in metadata: [String: AnyCodableValue]?, path: [String]) -> String? {
        guard let metadata, let first = path.first else { return nil }
        var current: AnyCodableValue? = metadata[first]
        for key in path.dropFirst() {
            guard let value = current, case .object(let object) = value else { return nil }
            current = object[key]
        }
        return current?.scalarStringValue
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
                        root: viewModel.objects.first(where: { $0.objectId == objectId }),
                        linked: viewModel.objects.filter { $0.objectId != objectId },
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

private enum KnowledgeShelf: CaseIterable, Hashable {
    case discoveries
    case evidence
    case codeSignals
    case research

    var title: String {
        switch self {
        case .discoveries: return "Recent discoveries"
        case .evidence: return "Evidence"
        case .codeSignals: return "Code signals"
        case .research: return "Research"
        }
    }

    var summary: String {
        switch self {
        case .discoveries: return "Newly formed patterns and structured findings."
        case .evidence: return "Grounded objects supporting the current state."
        case .codeSignals: return "Repository or implementation-adjacent signals."
        case .research: return "External reading, papers, and feed-derived context."
        }
    }

    var accent: Color {
        switch self {
        case .discoveries: return .cyan
        case .evidence: return .indigo
        case .codeSignals: return .orange
        case .research: return .jeevesGold
        }
    }

    var shortLabel: String {
        switch self {
        case .discoveries: return "Discovery"
        case .evidence: return "Evidence"
        case .codeSignals: return "Code"
        case .research: return "Research"
        }
    }
}

private struct KnowledgeShelfSection {
    let shelf: KnowledgeShelf
    let items: [KnowledgeObject]
}

private struct KnowledgeShelfPanel: View {
    let section: KnowledgeShelfSection
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.shelf.title)
                        .font(.jeevesHeadline)
                    Text(section.shelf.summary)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(section.items.count)")
                    .font(.jeevesMetric)
                    .foregroundStyle(section.shelf.accent)
            }

            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, object in
                Button {
                    onSelect(object.objectId)
                } label: {
                    KnowledgeBrowserCard(object: object, accent: section.shelf.accent)
                }
                .buttonStyle(.plain)
                .calmAppear(delay: 0.03 * Double(index))
            }
        }
        .briefingPanel()
    }
}

private struct KnowledgeBrowserHero: View {
    let count: Int
    let warning: String?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Library Index")
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(.secondary)

                Text("\(count) objecten beschikbaar voor inspectie.")
                    .font(.jeevesBody.weight(.semibold))

                Text("Shelves remain capped for clarity while the full graph stays accessible from each object.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let warning, !warning.isEmpty {
                Text(warning)
                    .font(.jeevesCaption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.trailing)
            }
        }
        .briefingPanel()
    }
}

private struct KnowledgeBrowserCard: View {
    let object: KnowledgeObject
    let accent: Color

    private var kindLabel: String {
        object.kind.replacingOccurrences(of: "_", with: " ")
    }

    private var sourceLabel: String {
        if let first = object.sourceRefs?.first {
            return first.label ?? first.sourceType
        }
        return object.createdAtIso
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(object.title)
                        .font(.jeevesBody.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(kindLabel)
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(accent)
                }

                Spacer()

                Text(object.kindEmoji)
                    .font(.jeevesHeadline)
            }

            Text(object.summary)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 8) {
                Text(sourceLabel)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if let refs = object.sourceRefs, !refs.isEmpty {
                    Text("\(refs.count) bron\(refs.count == 1 ? "" : "nen")")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
