import SwiftUI

struct ObservatoryView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller

    private let collisionsSectionId = "observatory-collisions"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        loopSection
                        fabricFieldSection
                        collisionsSection
                            .id(collisionsSectionId)
                        decisionsSection
                    }
                    .padding()
                }
                .background(observatoryBackground)
                .navigationTitle(TextKeys.Observatory.header)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
                #endif
                .refreshable {
                    await poller.refresh(gateway: gateway)
                }
                .task {
                    if poller.observatorySnapshot.collisions.isEmpty {
                        await poller.refresh(gateway: gateway)
                    }
                }
                .overlay(alignment: .top) {
                    if let alert = poller.activeEmergenceAlert {
                        EmergenceAlertCard(
                            alert: alert,
                            onInvestigate: {
                                poller.handleEmergenceAlertAction(.investigate, clusterId: alert.clusterId)
                            },
                            onIgnore: {
                                poller.handleEmergenceAlertAction(.ignore, clusterId: alert.clusterId)
                            },
                            onBookmark: {
                                poller.handleEmergenceAlertAction(.bookmark, clusterId: alert.clusterId)
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: poller.activeEmergenceAlert?.id)
                .onChange(of: poller.focusedClusterId) { _, clusterId in
                    guard clusterId != nil else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(collisionsSectionId, anchor: .top)
                    }
                }
            }
        }
    }

    private var snapshot: ObservatorySnapshot {
        poller.observatorySnapshot
    }

    private var observatoryBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemBackground).opacity(0.35)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var loopSection: some View {
        ObservatoryCard(title: "Loop", systemImage: "arrow.triangle.2.circlepath") {
            VStack(spacing: 10) {
                MetricRow(label: "Last cycle duration", value: formatSeconds(snapshot.loop.lastCycleDuration))
                MetricRow(label: "Average cycle", value: formatSeconds(snapshot.loop.averageCycleDuration))
                MetricRow(label: "Signals today", value: "\(snapshot.loop.signalsToday)")
                MetricRow(label: "Challenges today", value: "\(snapshot.loop.challengesToday)")
                MetricRow(label: "Proposals today", value: "\(snapshot.loop.proposalsToday)")
                MetricRow(label: "Executed actions", value: "\(snapshot.loop.executedActions)")
            }
        }
    }

    private var fabricFieldSection: some View {
        ObservatoryCard(title: "Fabric Field", systemImage: "cube.transparent") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<3, id: \.self) { layer in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Layer z\(layer)")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)

                        ClashdLayerGrid(
                            layer: layer,
                            cells: snapshot.field.cellsForLayer(layer)
                        )
                    }
                }

                if !snapshot.field.activeRoutes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Active routes")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                        ForEach(snapshot.field.activeRoutes.prefix(5)) { route in
                            Text("(\(route.from.x),\(route.from.y),\(route.from.z)) -> (\(route.to.x),\(route.to.y),\(route.to.z))")
                                .font(.jeevesMono)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    Text("Clusters")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(snapshot.field.clusters.count)")
                        .font(.jeevesMono)
                }
            }
        }
    }

    private var collisionsSection: some View {
        ObservatoryCard(title: "Knowledge collisions", systemImage: "aqi.low") {
            VStack(alignment: .leading, spacing: 10) {
                if snapshot.collisions.isEmpty {
                    Text("No collisions detected.")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.collisions) { cluster in
                        CollisionRow(
                            cluster: cluster,
                            isFocused: poller.focusedClusterId == cluster.clusterId,
                            isBookmarked: poller.bookmarkedClusterIds.contains(cluster.clusterId)
                        )
                    }
                }
            }
        }
    }

    private var decisionsSection: some View {
        ObservatoryCard(title: "Jeeves decisions", systemImage: "timeline.selection") {
            VStack(alignment: .leading, spacing: 10) {
                if snapshot.decisions.isEmpty {
                    Text("No decisions yet.")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.decisions.prefix(20)) { event in
                        DecisionTimelineRow(event: event)
                    }
                }
            }
        }
    }

    private func formatSeconds(_ value: TimeInterval) -> String {
        guard value > 0 else { return "-" }
        return String(format: "%.1fs", value)
    }
}

private struct ObservatoryCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.jeevesHeadline)
                .foregroundStyle(.primary)
            content
        }
        .padding(14)
        .background(Color(.secondarySystemFill).opacity(0.9))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.jeevesMono)
        }
    }
}

private struct ClashdLayerGrid: View {
    let layer: Int
    let cells: [ClashdCell]

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 44, maximum: 120), spacing: 8), count: 3)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(cells) { cell in
                ClashdCellView(cell: cell)
            }
        }
    }
}

private struct ClashdCellView: View {
    let cell: ClashdCell

    private var heatColor: Color {
        let v = cell.residueClamped
        return Color(
            red: min(1, 0.20 + v * 0.50),
            green: min(1, 0.28 + (1 - v) * 0.32),
            blue: min(1, 0.35 + (1 - v) * 0.12)
        )
    }

    var body: some View {
        VStack(spacing: 3) {
            Text("\(cell.position.x)\(cell.position.y)\(cell.position.z)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            Text(String(format: "%.2f", cell.residueClamped))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))

            Text(cell.routeArrows.joined(separator: " ").isEmpty ? "." : cell.routeArrows.joined(separator: " "))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(4)
        .background(heatColor.opacity(0.58))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    cell.highlightedClusterId == nil ? Color.clear : Color.orange.opacity(0.8),
                    lineWidth: cell.highlightedClusterId == nil ? 0 : 1.2
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct CollisionRow: View {
    let cluster: KnowledgeCollisionCluster
    let isFocused: Bool
    let isBookmarked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: cluster.isEmergence ? "exclamationmark.triangle.fill" : "circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(cluster.isEmergence ? .orange : .secondary)
                Text(cluster.summary)
                    .font(.jeevesBody)
                Spacer(minLength: 6)
                if isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.yellow)
                }
            }

            HStack(spacing: 8) {
                Text(cluster.sourceTypes.joined(separator: ", "))
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(String(format: "density %.2f", cluster.densityScore))
                    .font(.jeevesMono)
                    .foregroundStyle(cluster.isEmergence ? .orange : .secondary)
            }

            Text("cube (\(cluster.cubePosition.x), \(cluster.cubePosition.y), \(cluster.cubePosition.z))")
                .font(.jeevesMono)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var backgroundColor: Color {
        if isFocused {
            return .orange.opacity(0.22)
        }
        if cluster.isEmergence {
            return .orange.opacity(0.10)
        }
        return Color(.tertiarySystemFill)
    }
}

private struct DecisionTimelineRow: View {
    let event: JeevesDecisionEvent

    private var color: Color {
        switch event.kind {
        case .autoApproved:
            return .green
        case .autoDenied:
            return .red
        case .escalated:
            return .orange
        }
    }

    private var icon: String {
        switch event.kind {
        case .autoApproved:
            return "checkmark.circle.fill"
        case .autoDenied:
            return "xmark.circle.fill"
        case .escalated:
            return "exclamationmark.circle.fill"
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.timestamp)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.kind.rawValue)
                    .font(.jeevesCaption)
                    .foregroundStyle(color)
                Text(event.title)
                    .font(.jeevesBody)
            }

            Spacer()

            Text(timeText)
                .font(.jeevesMono)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct EmergenceAlertCard: View {
    let alert: EmergenceAlert
    let onInvestigate: () -> Void
    let onIgnore: () -> Void
    let onBookmark: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(alert.title)
                .font(.jeevesHeadline)
            Text(alert.summary)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 8) {
                Button("Investigate", action: onInvestigate)
                    .buttonStyle(.borderedProminent)

                Button("Ignore", action: onIgnore)
                    .buttonStyle(.bordered)

                Button("Bookmark", action: onBookmark)
                    .buttonStyle(.bordered)
            }
            .font(.jeevesCaption)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}

private extension ClashdCubeField {
    func cellsForLayer(_ z: Int) -> [ClashdCell] {
        cells
            .filter { $0.position.z == z }
            .sorted { lhs, rhs in
                if lhs.position.y != rhs.position.y { return lhs.position.y < rhs.position.y }
                return lhs.position.x < rhs.position.x
            }
    }
}
