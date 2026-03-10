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

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(domainLabel)
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Circle()
                        .fill(glowColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: glowColor.opacity(cell.intensity == .quiet ? 0 : 0.35), radius: 10)
                }

                Spacer(minLength: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(RadarMeaning.patternTitle(for: cell))
                        .font(.jeevesHeadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(RadarMeaning.patternInterpretation(for: cell))
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 2)

                HStack {
                    Text(intensityLabel)
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(glowColor)

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

    private var domainLabel: String {
        let title = cell.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "ZONE" }
        return title.uppercased()
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

                Text(RadarMeaning.patternTitle(for: cell))
                    .font(.jeevesTitle)
                    .foregroundStyle(.primary)

                HStack {
                    Text("Signal convergence: \(cell.clusterCount)")
                    Spacer()
                    Text("State: \(operatorStateLabel)")
                }
                .font(.jeevesBody)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Signals detected across:")
                        .font(.jeevesHeadline)

                    ForEach(RadarMeaning.signalSources(for: cell), id: \.self) { source in
                        Text("• \(source)")
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if cell.hints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CLASHD27 reading")
                            .font(.jeevesHeadline)

                        Text(RadarMeaning.clashdReading(for: cell))
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Signal overview")
                            .font(.jeevesHeadline)

                        ForEach(Array(cell.hints.prefix(5))) { hint in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(hint.topic)
                                    .font(.jeevesHeadline)
                                Text(operatorHintExplanation(hint))
                                    .font(.jeevesBody)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CLASHD27 reading")
                            .font(.jeevesHeadline)

                        Text(RadarMeaning.clashdReading(for: cell))
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Operator interpretation")
                            .font(.jeevesHeadline)

                        Text(RadarMeaning.operatorInterpretation(for: cell))
                            .font(.jeevesBody)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .replacingOccurrences(of: "cell", with: "domain intersection", options: .caseInsensitive)
                .replacingOccurrences(of: "gravity", with: "pressure", options: .caseInsensitive)
                .replacingOccurrences(of: "candidate", with: "signal convergence", options: .caseInsensitive)
                .replacingOccurrences(of: "disc-paper", with: "research signal", options: .caseInsensitive)
                .replacingOccurrences(of: "cross-domain overlap", with: "multi-domain signal convergence", options: .caseInsensitive)
        }
        return "Recent developments are increasing pressure across this domain intersection."
    }
}

private enum RadarMeaning {
    static func patternTitle(for cell: DiscoveryCell) -> String {
        switch normalizedDomainKey(for: cell) {
        case "AIxTECH":
            return "Inference engines accelerating"
        case "AIxGOV":
            return "Model regulation pressure"
        case "AIxECON":
            return "Compute cost competition"
        case "GEOxTECH":
            return "Technology sanctions pressure"
        case "GEOxGOV":
            return "Policy realignment signals"
        case "GEOxECON":
            return "Economic leverage building"
        case "INFRAxTECH":
            return "Compute infrastructure expansion"
        case "INFRAxGOV":
            return "Infrastructure regulation pressure"
        case "INFRAxECON":
            return "Infrastructure investment race"
        default:
            switch cell.intensity {
            case .quiet:
                return "Signals holding steady"
            case .normal:
                return "Early movement detected"
            case .rising:
                return "Pressure beginning to build"
            case .hot:
                return "Strong convergence forming"
            }
        }
    }

    static func patternInterpretation(for cell: DiscoveryCell) -> String {
        switch normalizedDomainKey(for: cell) {
        case "AIxTECH":
            return "Acceleration detected across code and infrastructure."
        case "AIxGOV":
            return "Policy attention is increasing around model development."
        case "AIxECON":
            return "Competition is building around compute access and cost."
        case "GEOxTECH":
            return "Geopolitical pressure is shaping strategic technology."
        case "GEOxGOV":
            return "Government priorities are shifting in this intersection."
        case "GEOxECON":
            return "State and market signals are reinforcing the same direction."
        case "INFRAxTECH":
            return "Acceleration detected across code, research, and infrastructure."
        case "INFRAxGOV":
            return "Policy attention is increasing around critical infrastructure."
        case "INFRAxECON":
            return "Multiple sources point to rising infrastructure demand."
        default:
            switch cell.intensity {
            case .quiet:
                return "Signals are present but not yet moving together."
            case .normal:
                return "Signals are gathering but not yet converging."
            case .rising:
                return "Multiple independent sources are reinforcing the same direction."
            case .hot:
                return "Pressure is building quickly across this intersection."
            }
        }
    }

    static func clashdReading(for cell: DiscoveryCell) -> String {
        switch normalizedDomainKey(for: cell) {
        case "AIxTECH":
            return "Technical capability in this domain is accelerating faster than governance."
        case "AIxGOV":
            return "State and regulatory attention is beginning to shape how models can be developed and deployed."
        case "AIxECON":
            return "Economic pressure is concentrating around access to compute, tooling, and model advantage."
        case "GEOxTECH":
            return "Strategic technology decisions are increasingly being shaped by geopolitical pressure."
        case "GEOxGOV":
            return "Government action in this intersection may reset strategic priorities."
        case "GEOxECON":
            return "Political and economic signals are converging into the same strategic direction."
        case "INFRAxTECH":
            return "Infrastructure capability is becoming a limiting factor for technical progress in this domain."
        case "INFRAxGOV":
            return "Policy attention is rising as infrastructure becomes more strategically consequential."
        case "INFRAxECON":
            return "Capital, capacity, and infrastructure demand are moving in the same direction."
        default:
            switch cell.intensity {
            case .quiet:
                return "This domain intersection is stable and not yet showing meaningful pressure."
            case .normal:
                return "Signals are beginning to gather here, but the direction is still early."
            case .rising:
                return "Independent sources are starting to reinforce the same pattern."
            case .hot:
                return "This intersection is now strategically active and merits closer investigation."
            }
        }
    }

    static func operatorInterpretation(for cell: DiscoveryCell) -> String {
        switch normalizedDomainKey(for: cell) {
        case "AIxTECH":
            return "This intersection may shape the next generation of AI deployment."
        case "AIxGOV":
            return "This area may determine how quickly AI capability can move into real-world systems."
        case "AIxECON":
            return "This pattern may reshape who can afford to compete at the frontier."
        case "GEOxTECH":
            return "This intersection may redefine where technical power can be built and maintained."
        case "GEOxGOV":
            return "This pattern may influence how state power is expressed through technology."
        case "GEOxECON":
            return "This area may affect how geopolitical shifts turn into economic leverage."
        case "INFRAxTECH":
            return "This domain intersection may shape the next generation of AI deployment."
        case "INFRAxGOV":
            return "This pattern may determine how infrastructure can scale under political constraint."
        case "INFRAxECON":
            return "This area may influence who controls future infrastructure capacity."
        default:
            return "This intersection is worth watching because early movement here may shape broader system behavior."
        }
    }

    static func signalSources(for cell: DiscoveryCell) -> [String] {
        switch normalizedDomainKey(for: cell) {
        case "AIxTECH":
            return ["GitHub repositories", "research papers", "infrastructure announcements"]
        case "AIxGOV":
            return ["policy papers", "law proposals", "government programs"]
        case "AIxECON":
            return ["market signals", "compute pricing moves", "investment announcements"]
        case "GEOxTECH":
            return ["export controls", "technology policy", "strategic infrastructure announcements"]
        case "GEOxGOV":
            return ["state programs", "policy statements", "institutional changes"]
        case "GEOxECON":
            return ["trade policy", "capital flows", "sanctions announcements"]
        case "INFRAxTECH":
            return ["infrastructure announcements", "GitHub repositories", "research papers"]
        case "INFRAxGOV":
            return ["regulatory proposals", "infrastructure policy", "public investment signals"]
        case "INFRAxECON":
            return ["capacity announcements", "investment rounds", "supply chain signals"]
        default:
            return ["research papers", "GitHub repositories", "public announcements"]
        }
    }

    private static func normalizedDomainKey(for cell: DiscoveryCell) -> String {
        cell.title
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: "*", with: "x")
    }
}

private extension Array {
    func adjacentPairs() -> [(Element, Element)] {
        guard count > 1 else { return [] }
        return zip(self, dropFirst()).map { ($0.0, $0.1) }
    }
}
