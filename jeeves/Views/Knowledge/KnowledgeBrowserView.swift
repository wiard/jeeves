
import SwiftUI

struct KnowledgeBrowserView: View {
    @Environment(GatewayManager.self) private var gateway
    @State private var viewModel = KnowledgeBrowserViewModel()
    @State private var knowledgeGraphData: KnowledgeGraphResponse?
    @State private var showKnowledgeGraph = false
    @State private var loadingKnowledgeGraph = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && !viewModel.hasLoaded {
                    ProgressView("Knowledge laden...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.objects.isEmpty {
                    ContentUnavailableView(
                        "Geen knowledge beschikbaar",
                        systemImage: "books.vertical",
                        description: Text(viewModel.errorMessage ?? "Er zijn nog geen recente knowledge objecten.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            KnowledgeBrowserHero(count: viewModel.objects.count, warning: viewModel.errorMessage)

                            ForEach(viewModel.objects) { object in
                                Button {
                                    fetchAndShowKnowledgeGraph(objectId: object.objectId)
                                } label: {
                                    KnowledgeBrowserCard(object: object)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Knowledge")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
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

private struct KnowledgeBrowserHero: View {
    let count: Int
    let warning: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Knowledge Browser")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)

            Text("Recente evidence en knowledge objecten")
                .font(.jeevesHeadline)

            Text("\(count) objecten beschikbaar voor inspectie.")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)

            if let warning, !warning.isEmpty {
                Text(warning)
                    .font(.jeevesCaption)
                    .foregroundStyle(.orange)
            }
        }
        .briefingPanel()
    }
}

private struct KnowledgeBrowserCard: View {
    let object: KnowledgeObject

    private var kindLabel: String {
        object.kind.replacingOccurrences(of: "_", with: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(object.title)
                    .font(.jeevesBody.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer()
                Text(kindLabel)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text(object.summary)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 8) {
                Text(object.createdAtIso)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let refs = object.sourceRefs, !refs.isEmpty {
                    Text("\(refs.count) bron\(refs.count == 1 ? "" : "nen")")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .briefingPanel()
    }
}
