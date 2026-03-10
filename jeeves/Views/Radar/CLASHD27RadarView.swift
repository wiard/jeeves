import SwiftUI

struct CLASHD27RadarView: View {
    @State private var viewModel = RadarViewModel()
    @State private var animateAmbient = false

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.93, green: 0.96, blue: 0.98),
                        Color(red: 0.92, green: 0.95, blue: 0.96),
                        Color(red: 0.96, green: 0.97, blue: 0.99)
                    ]
                )
                .ignoresSafeArea()

                VStack(spacing: 18) {
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
                            VStack(alignment: .leading, spacing: 18) {
                                InstrumentRoleHeader(
                                    eyebrow: "Radar",
                                    title: "Discovery Engine",
                                    summary: "A quiet spatial reading of active cells, rising pressure, and linked zones that deserve attention.",
                                    accent: .cyan,
                                    metrics: [
                                        InstrumentRoleMetric(label: "Cells", value: "\(activeCount(in: layer))"),
                                        InstrumentRoleMetric(label: "Hot", value: "\(hotCount(in: layer))"),
                                        InstrumentRoleMetric(label: "Clusters", value: "\(clusterTotal(in: layer))")
                                    ]
                                )
                                .calmAppear()

                                RadarGridPanel(layer: layer, animateAmbient: animateAmbient)
                                    .calmAppear(delay: 0.08)
                            }
                            .padding()
                        }
                    } else {
                        ProgressView("Radar laden…")
                            .task { await viewModel.load() }
                    }
                }
            }
            .navigationTitle("Discovery Engine")
            .task {
                await viewModel.load()
                guard !animateAmbient else { return }
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    animateAmbient = true
                }
            }
        }
    }

    private func activeCount(in layer: DiscoveryLayer) -> Int {
        layer.cells.filter { $0.intensity != .quiet }.count
    }

    private func hotCount(in layer: DiscoveryLayer) -> Int {
        layer.cells.filter { intensityLevel($0.intensity) >= 3 }.count
    }

    private func clusterTotal(in layer: DiscoveryLayer) -> Int {
        layer.cells.reduce(0) { $0 + $1.clusterCount }
    }

    private func intensityLevel(_ intensity: RadarIntensity) -> Int {
        switch intensity {
        case .quiet: return 0
        case .normal: return 1
        case .rising: return 2
        case .hot: return 3
        }
    }
}

private struct RadarGridPanel: View {
    let layer: DiscoveryLayer
    let animateAmbient: Bool

    private let spacing: CGFloat = 12

    private var displayCells: [DiscoveryCell] {
        Array(layer.cells.prefix(9))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(layer.title.uppercased())
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(.secondary)

                    Text("Spatial pressure map")
                        .font(.jeevesHeadline)
                }
                Spacer()
                Text("\(displayCells.count) cells")
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                let cellSize = (geometry.size.width - spacing * 2) / 3

                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(animateAmbient ? 0.10 : 0.06),
                                    Color.white.opacity(0.55),
                                    Color.jeevesGold.opacity(animateAmbient ? 0.12 : 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RadarConnectionOverlay(
                        cells: displayCells,
                        cellSize: cellSize,
                        spacing: spacing
                    )

                    VStack(spacing: spacing) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<3, id: \.self) { column in
                                    let index = row * 3 + column
                                    if index < displayCells.count {
                                        NavigationLink {
                                            RadarCellDetailView(cell: displayCells[index])
                                        } label: {
                                            RadarCellCard(cell: displayCells[index])
                                                .frame(width: cellSize, height: cellSize)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .fill(Color.clear)
                                            .frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                        }
                    }
                    .padding(18)
                }
            }
            .frame(height: 380)
        }
        .briefingPanel()
    }
}

private struct RadarConnectionOverlay: View {
    let cells: [DiscoveryCell]
    let cellSize: CGFloat
    let spacing: CGFloat

    private var highActivityIndices: [Int] {
        cells.enumerated().compactMap { index, cell in
            switch cell.intensity {
            case .rising, .hot:
                return index
            case .quiet, .normal:
                return nil
            }
        }
    }

    var body: some View {
        Canvas { context, _ in
            guard highActivityIndices.count > 1 else { return }
            for pair in highActivityIndices.adjacentPairs() {
                var path = Path()
                path.move(to: center(for: pair.0))
                path.addLine(to: center(for: pair.1))
                context.stroke(
                    path,
                    with: .color(Color.cyan.opacity(0.30)),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 6])
                )
            }
        }
        .padding(18)
    }

    private func center(for index: Int) -> CGPoint {
        let row = CGFloat(index / 3)
        let column = CGFloat(index % 3)
        let step = cellSize + spacing
        return CGPoint(
            x: column * step + cellSize / 2,
            y: row * step + cellSize / 2
        )
    }
}

private struct RadarCellCard: View {
    let cell: DiscoveryCell
    @State private var animatePulse = false

    private var intensityLabel: String {
        switch cell.intensity {
        case .quiet: return "Quiet"
        case .normal: return "Tracking"
        case .rising: return "Rising"
        case .hot: return "Hot"
        }
    }

    private var glowColor: Color {
        switch cell.intensity {
        case .quiet: return .gray
        case .normal: return .blue
        case .rising: return .orange
        case .hot: return .red
        }
    }

    private var shouldPulse: Bool {
        cell.intensity == .hot
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.88),
                            glowColor.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if shouldPulse {
                Circle()
                    .fill(glowColor.opacity(0.16))
                    .frame(width: 88, height: 88)
                    .scaleEffect(animatePulse ? 1.08 : 0.92)
                    .blur(radius: 8)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(cell.title)
                        .font(.jeevesHeadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer()

                    Circle()
                        .fill(glowColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: glowColor.opacity(cell.intensity == .quiet ? 0 : 0.35), radius: 10)
                }

                Text(cell.subtitle.isEmpty ? "Signal density mapped for this cell." : cell.subtitle)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Spacer(minLength: 4)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(intensityLabel)
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(glowColor)

                        Text("\(cell.clusterCount) clusters")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.forward")
                        .font(.jeevesCaption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(glowColor.opacity(cell.intensity == .quiet ? 0.08 : 0.24), lineWidth: 1)
        )
        .shadow(color: glowColor.opacity(cell.intensity == .quiet ? 0.04 : 0.18), radius: cell.intensity == .quiet ? 8 : 18, y: 10)
        .scaleEffect(shouldPulse && animatePulse ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.55), value: cell.intensity)
        .onAppear {
            guard shouldPulse, !animatePulse else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                animatePulse = true
            }
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

private extension Array {
    func adjacentPairs() -> [(Element, Element)] {
        guard count > 1 else { return [] }
        return zip(self, dropFirst()).map { ($0.0, $0.1) }
    }
}
