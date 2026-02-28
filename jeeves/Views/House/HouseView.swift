import SwiftUI

struct HouseView: View {
    @Environment(GatewayManager.self) private var gateway
    @State private var status: GatewayStatus?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let status = status ?? gateway.currentStatus {
                        KernelCard(consent: status.consent)
                        BudgetCard(budget: status.budget)
                        ChannelsCard(channels: status.channels)
                        KillSwitchButton(
                            isActive: status.killSwitch.active,
                            onActivate: activateKillSwitch,
                            onDeactivate: deactivateKillSwitch
                        )
                    } else if isLoading {
                        ProgressView("Status ophalen...")
                    } else {
                        ContentUnavailableView(
                            "Niet verbonden",
                            systemImage: "wifi.slash",
                            description: Text("Verbind met de gateway om de status te zien.")
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("De Grote Kamer")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshStatus()
            }
            .onAppear {
                status = gateway.currentStatus
            }
            .task {
                // Auto-refresh every 30 seconds
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    await refreshStatus()
                }
            }
        }
    }

    private func refreshStatus() async {
        isLoading = true
        defer { isLoading = false }
        status = try? await gateway.fetchStatus()
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
