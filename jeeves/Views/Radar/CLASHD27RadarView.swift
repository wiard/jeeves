import SwiftUI

struct CLASHD27RadarView: View {
    @State private var viewModel = RadarViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if !viewModel.layers.isEmpty {
                    Picker("Layer", selection: $viewModel.selectedLayerIndex) {
                        ForEach(Array(viewModel.layers.enumerated()), id: \.offset) { index, layer in
                            Text(layer.title).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                if let layer = viewModel.selectedLayer {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(layer.cells) { cell in
                                NavigationLink {
                                    RadarCellDetailView(cell: cell)
                                } label: {
                                    RadarCellCard(cell: cell)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                } else {
                    ProgressView("Radar laden…")
                        .task { await viewModel.load() }
                }
            }
            .navigationTitle("Radar")
            .task { await viewModel.load() }
        }
    }
}

private struct RadarCellCard: View {
    let cell: DiscoveryCell

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(cell.title)
                .font(.jeevesHeadline)
                .foregroundStyle(.primary)

            Text(cell.subtitle)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            HStack {
                Label("\(cell.clusterCount)", systemImage: "sparkles")
                    .font(.jeevesCaption)
                Spacer()
                Circle()
                    .fill(color(for: cell.intensity))
                    .frame(width: 12, height: 12)
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func color(for intensity: RadarIntensity) -> Color {
        switch intensity {
        case .quiet: return .gray
        case .normal: return .blue
        case .rising: return .orange
        case .hot: return .red
        }
    }
}

private struct RadarCellDetailView: View {
    let cell: DiscoveryCell

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(cell.title)
                    .font(.jeevesLargeTitle)

                Text(cell.subtitle)
                    .font(.jeevesTitle)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Clusters: \(cell.clusterCount)")
                    Spacer()
                    Text("State: \(cell.intensity.rawValue)")
                }
                .font(.jeevesBody)

                if cell.hints.isEmpty {
                    Text("Nog geen concrete discovery hints in deze cel.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(cell.hints) { hint in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(hint.topic)
                                .font(.jeevesHeadline)
                            Text(hint.why)
                                .font(.jeevesBody)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("Bronnen: \(hint.sourceCount)")
                                Text("Novelty: \(String(format: "%.2f", hint.noveltyScore))")
                                Text("Pressure: \(String(format: "%.2f", hint.pressureScore))")
                            }
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Cluster")
        .navigationBarTitleDisplayMode(.inline)
    }
}
