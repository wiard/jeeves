import SwiftUI

struct CLASHD27RadarView: View {
    @State private var viewModel = RadarViewModel()

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
                                    summary: "A spatial reading of where pressure is forming across domains and where attention is beginning to build.",
                                    accent: .purple,
                                    metrics: [
                                        InstrumentRoleMetric(label: "Zones", value: "\(activeCount(in: layer))"),
                                        InstrumentRoleMetric(label: "Active", value: "\(hotCount(in: layer))"),
                                        InstrumentRoleMetric(label: "Signals", value: "\(clusterTotal(in: layer))")
                                    ]
                                )
                                .calmAppear()

                                RadarGridPanel(layer: layer)
                                    .calmAppear(delay: 0.12)
                            }
                            .padding()
                        }
                    } else {
                        ProgressView("Radar laden…")
                            .task { await viewModel.load() }
                    }
                }
            }
            .navigationTitle("Jeeves")
            .task { await viewModel.load() }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
                Text("\(displayCells.count) zones")
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
                                    Color.blue.opacity(0.08),
                                    Color.white.opacity(0.55),
                                    Color.jeevesGold.opacity(0.10)
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

    private var hotIndices: [Int] {
        cells.enumerated().compactMap { index, cell in
            cell.intensity == .hot ? index : nil
        }
    }

    var body: some View {
        Canvas { context, _ in
            guard hotIndices.count > 1 else { return }
            for pair in hotIndices.adjacentPairs() {
                var path = Path()
                path.move(to: center(for: pair.0))
                path.addLine(to: center(for: pair.1))
                context.stroke(
                    path,
                    with: .color(Color.blue.opacity(0.26)),
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
        case .normal: return "Watching"
        case .rising: return "Rising"
        case .hot: return "Active"
        }
    }

    private var glowColor: Color {
        switch cell.intensity {
        case .quiet: return .gray
        case .normal: return .blue
        case .rising: return .purple
        case .hot: return .orange
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
                    Text(shortTitle)
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Circle()
                        .fill(glowColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: glowColor.opacity(cell.intensity == .quiet ? 0 : 0.35), radius: 10)
                }

                Spacer(minLength: 4)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(cell.clusterCount) signals")
                            .font(.jeevesMetric)
                            .foregroundStyle(.primary)

                        Text(intensityLabel)
                            .font(.jeevesMonoSmall)
                            .foregroundStyle(glowColor)
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
        .animation(.easeInOut(duration: 0.45), value: cell.intensity)
        .onAppear {
            guard shouldPulse, !animatePulse else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                animatePulse = true
            }
        }
    }

    private var shortTitle: String {
        let title = cell.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "ZONE" }
        return String(title.prefix(14)).uppercased()
    }
}

private struct RadarCellDetailView: View {
    let cell: DiscoveryCell

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Domain intersection")
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(.secondary)

                Text(cell.title)
                    .font(.jeevesLargeTitle)

                Text("What signals are driving pressure here.")
                    .font(.jeevesTitle)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Signals: \(cell.clusterCount)")
                    Spacer()
                    Text("State: \(operatorStateLabel)")
                }
                .font(.jeevesBody)

                if cell.hints.isEmpty {
                    Text("No clear signals are surfacing here yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(cell.hints) { hint in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(hint.topic)
                                .font(.jeevesHeadline)
                            Text(operatorHintExplanation(hint))
                                .font(.jeevesBody)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("Sources: \(hint.sourceCount)")
                                Text("Change: \(String(format: "%.2f", hint.noveltyScore))")
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
        .navigationTitle("Signal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var operatorStateLabel: String {
        switch cell.intensity {
        case .quiet: return "Quiet"
        case .normal: return "Watching"
        case .rising: return "Rising"
        case .hot: return "Active"
        }
    }

    private func operatorHintExplanation(_ hint: DiscoveryHint) -> String {
        let text = hint.why.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
                .replacingOccurrences(of: "cluster", with: "pattern", options: .caseInsensitive)
                .replacingOccurrences(of: "cell", with: "zone", options: .caseInsensitive)
                .replacingOccurrences(of: "gravity", with: "pressure", options: .caseInsensitive)
        }
        return "Recent developments are increasing pressure across this domain intersection."
    }
}

private extension Array {
    func adjacentPairs() -> [(Element, Element)] {
        guard count > 1 else { return [] }
        return zip(self, dropFirst()).map { ($0.0, $0.1) }
    }
}
