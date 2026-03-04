import SwiftUI

struct ObservatoryView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    loopSection
                    trafficSection
                    emergenceSection
                    jeevesAutoSection
                    roomsSection
                }
                .padding()
            }
            .navigationTitle(TextKeys.Observatory.header)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .refreshable {
                await poller.refresh(gateway: gateway)
            }
        }
    }

    private var loopSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Loop", systemImage: "arrow.triangle.2.circlepath")
                .font(.jeevesHeadline)

            HStack {
                Text(TextKeys.Observatory.loopLabel)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(lastCycleDuration)
                    .font(.jeevesMono)
            }

            HStack {
                Text(TextKeys.Observatory.avgLabel)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(avgCycleDuration)
                    .font(.jeevesMono)
            }
        }
        .padding()
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var trafficSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Verkeer", systemImage: "chart.bar")
                .font(.jeevesHeadline)

            ForEach(agentStats, id: \.agentId) { stat in
                HStack {
                    Text(stat.agentId)
                        .font(.jeevesMono)
                    Spacer()
                    Text("\(stat.total) acties")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    if stat.denied > 0 {
                        Text("(\(stat.denied) denied)")
                            .font(.jeevesCaption)
                            .foregroundStyle(.red)
                    }
                }
            }

            if agentStats.isEmpty {
                Text("Geen verkeer")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emergenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(TextKeys.Emergence.header, systemImage: "sparkles")
                .font(.jeevesHeadline)

            if poller.emergenceClusters.isEmpty {
                Text("Geen patronen gedetecteerd")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(poller.emergenceClusters) { cluster in
                    HStack {
                        Text("\u{1F52E}")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cluster.summary)
                                .font(.jeevesMono)
                            Text("\(cluster.dimensions.count) \(TextKeys.Emergence.sources), \(cluster.relevanceScore, specifier: "%.2f")")
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var jeevesAutoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(TextKeys.appTitle, systemImage: "brain.head.profile")
                .font(.jeevesHeadline)

            HStack {
                Text("Auto-approved:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(autoApprovedCount)")
                    .font(.jeevesMono)
                    .foregroundStyle(.green)
            }

            HStack {
                Text("Escalated:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(pendingCount)")
                    .font(.jeevesMono)
                    .foregroundStyle(.orange)
            }

            HStack {
                Text("Denied:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(deniedCount)")
                    .font(.jeevesMono)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Kamers", systemImage: "door.left.hand.open")
                .font(.jeevesHeadline)

            RoomRow(name: TextKeys.Rooms.huishouding, domain: "intern", status: "actief", active: true)
            RoomRow(name: TextKeys.Rooms.buitenwereld, domain: "extern", status: "vergrendeld", active: false)
            RoomRow(name: TextKeys.Rooms.machinekamer, domain: "kernel", status: "read-only", active: true)

            NavigationLink {
                LobbyView()
            } label: {
                HStack {
                    Circle()
                        .fill(poller.pendingCount > 0 ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(TextKeys.Rooms.lobby)
                        .font(.jeevesBody)
                    Text("agents")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if poller.pendingCount > 0 {
                        Text("\(poller.pendingCount) pending")
                            .font(.jeevesMono)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private struct AgentStat {
        let agentId: String
        let total: Int
        let denied: Int
    }

    private var agentStats: [AgentStat] {
        let grouped = Dictionary(grouping: poller.proposals, by: \.agentId)
        return grouped.map { agentId, proposals in
            let denied = proposals.filter(\.isDenied).count
            return AgentStat(agentId: agentId, total: proposals.count, denied: denied)
        }.sorted { $0.total > $1.total }
    }

    private var autoApprovedCount: Int {
        poller.proposals.filter { $0.isApproved && !$0.intent.requiresConsent }.count
    }

    private var pendingCount: Int {
        poller.pendingCount
    }

    private var deniedCount: Int {
        poller.proposals.filter(\.isDenied).count
    }

    private var lastCycleDuration: String {
        guard poller.proposals.count >= 2 else { return "-" }
        let sorted = poller.proposals.compactMap(\.createdAt).sorted()
        guard let last = sorted.last, let secondLast = sorted.dropLast().last else { return "-" }
        let interval = Int(last.timeIntervalSince(secondLast))
        return "\(interval)s"
    }

    private var avgCycleDuration: String {
        let dates = poller.proposals.compactMap(\.createdAt).sorted()
        guard dates.count >= 2 else { return "-" }
        var intervals: [TimeInterval] = []
        for i in 1..<dates.count {
            intervals.append(dates[i].timeIntervalSince(dates[i - 1]))
        }
        let avg = Int(intervals.reduce(0, +) / Double(intervals.count))
        return "\(avg)s"
    }
}

private struct RoomRow: View {
    let name: String
    let domain: String
    let status: String
    let active: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(active ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)
            Text(name)
                .font(.jeevesBody)
            Text(domain)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(status)
                .font(.jeevesMono)
                .foregroundStyle(.secondary)
        }
    }
}
