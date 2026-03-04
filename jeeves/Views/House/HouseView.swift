import SwiftUI

struct HouseView: View {
    @Environment(GatewayManager.self) private var gateway
    @State private var status: GatewayStatus?
    @State private var knowledgeStatus: KnowledgeStatus?
    @State private var knowledgeError: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let status = status ?? gateway.currentStatus {
                        KernelCard(consent: status.consent)
                        BudgetCard(budget: status.budget)
                        ChannelsCard(channels: status.channels)
                        KnowledgeCard(
                            status: knowledgeStatus ?? gateway.currentKnowledgeStatus,
                            errorText: knowledgeError,
                            onRefresh: refreshKnowledgeStatus
                        )
                        NavigationLink {
                            ObservatoryView()
                        } label: {
                            MachinekamerObservatoryCard()
                        }
                        KillSwitchButton(
                            isActive: status.killSwitch.active,
                            onActivate: activateKillSwitch,
                            onDeactivate: deactivateKillSwitch
                        )
                    } else if isLoading {
                        ProgressView(TextKeys.House.loadingStatus)
                    } else {
                        ContentUnavailableView(
                            TextKeys.House.notConnectedTitle,
                            systemImage: "wifi.slash",
                            description: Text(TextKeys.House.notConnectedDescription)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle(TextKeys.House.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .refreshable {
                await refreshStatus()
                await refreshKnowledgeStatusAsync()
            }
            .onAppear {
                status = gateway.currentStatus
                knowledgeStatus = gateway.currentKnowledgeStatus
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    await refreshStatus()
                    await refreshKnowledgeStatusAsync()
                }
            }
        }
    }

    private func refreshStatus() async {
        isLoading = true
        defer { isLoading = false }
        status = try? await gateway.fetchStatus()
    }

    private func refreshKnowledgeStatus() {
        Task {
            await refreshKnowledgeStatusAsync()
        }
    }

    private func refreshKnowledgeStatusAsync() async {
        do {
            knowledgeError = nil
            knowledgeStatus = try await gateway.fetchKnowledgeStatus()
        } catch {
            knowledgeError = TextKeys.House.knowledgeError
        }
    }

    private func activateKillSwitch() {
        Task {
            try? await gateway.activateKillSwitch(reason: "Handmatig geactiveerd via iOS app")
            status = gateway.currentStatus
        }
    }

    private func deactivateKillSwitch() {
        Task {
            try? await gateway.deactivateKillSwitch()
            status = gateway.currentStatus
        }
    }
}

private struct MachinekamerObservatoryCard: View {
    var body: some View {
        HStack {
            Label("Machinekamer", systemImage: "cpu")
                .font(.jeevesHeadline)
            Spacer()
            Text("Observatory")
                .font(.jeevesMono)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct KnowledgeCard: View {
    let status: KnowledgeStatus?
    let errorText: String?
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(TextKeys.House.knowledgeHeader, systemImage: "aqi.low")
                    .font(.jeevesHeadline)
                Spacer()
                Button(TextKeys.House.knowledgeRefresh) {
                    onRefresh()
                }
                .font(.jeevesCaption)
            }

            if let status {
                metricRow(TextKeys.House.knowledgeSignals, "\(status.last24hSignalsCount)")
                metricRow(TextKeys.House.knowledgeEmergence, "\(status.emergenceClustersCount)")
                metricRow(TextKeys.House.knowledgeChallenges, "\(status.lastKnowledgeChallenges.count)")

                Text(TextKeys.House.knowledgeTopCells)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)

                if status.topCubeCells.isEmpty {
                    Text(TextKeys.House.knowledgeNoData)
                        .font(.jeevesMono)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(status.topCubeCells.prefix(3).enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(.jeevesMono)
                    }
                }

                if !status.lastKnowledgeChallenges.isEmpty {
                    ForEach(Array(status.lastKnowledgeChallenges.prefix(3).enumerated()), id: \.element.challengeId) { _, challenge in
                        Text(challenge.title)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(TextKeys.House.knowledgeNoData)
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
            }

            if let errorText {
                Text(errorText)
                    .font(.jeevesCaption)
                    .foregroundStyle(Color.consentRed)
            }
        }
        .padding()
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
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
