import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(GatewayManager.self) private var gateway
    @Query private var connections: [GatewayConnection]
    @State private var showOnboarding: Bool = false

    private var hasConnection: Bool { !connections.isEmpty }

    var body: some View {
        Group {
            if showOnboarding || !hasConnection {
                OnboardingView {
                    withAnimation {
                        showOnboarding = false
                    }
                }
            } else {
                mainTabView
            }
        }
        .onAppear {
            if !hasConnection {
                showOnboarding = true
            } else if !gateway.isConnected {
                // Auto-connect with mock for development
                gateway.useMock = true
                if let conn = connections.first {
                    gateway.connect(
                        host: conn.host,
                        port: conn.port,
                        token: KeychainHelper.load(for: "\(conn.host):\(conn.port)") ?? "mock",
                        channelId: conn.channelId
                    )
                }
            }
        }
    }

    private var mainTabView: some View {
        TabView {
            Tab("Jeeves", systemImage: "bubble.left.fill") {
                ChatView()
            }

            Tab("Huis", systemImage: "house.fill") {
                HouseView()
            }

            Tab("Logboek", systemImage: "scroll.fill") {
                LogbookView()
            }

            Tab("Instellingen", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(.jeevesGold)
    }
}
