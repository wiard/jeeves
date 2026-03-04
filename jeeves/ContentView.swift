import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @Query private var connections: [GatewayConnection]
    @State private var showOnboarding: Bool = false

    private var hasConnection: Bool { !connections.isEmpty }

    var body: some View {
        Group {
            if showOnboarding || !hasConnection {
                OnboardingView {
                    withAnimation { showOnboarding = false }
                }
            } else {
                mainTabView
            }
        }
        .onAppear {
            guard hasConnection else {
                showOnboarding = true
                return
            }

            guard !gateway.isConnected else { return }

            guard let conn = connections.first else { return }

            let cfg = RuntimeConfig.shared
            gateway.useMock = cfg.useMock

            let resolvedHost: String = {
                let h = (cfg.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return h.isEmpty ? conn.host : h
            }()

            let resolvedPort: Int = {
                if let p = cfg.port, p > 0 { return p }
                return conn.port
            }()

            let resolvedToken: String = {
                let t = (cfg.token ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t }
                return KeychainHelper.load(for: "\(conn.host):\(conn.port)") ?? "mock"
            }()

            gateway.connect(
                host: resolvedHost,
                port: resolvedPort,
                token: resolvedToken,
                channelId: conn.channelId
            )
        }
        .onChange(of: gateway.isConnected) {
            if gateway.isConnected {
                poller.start(gateway: gateway)
            } else {
                poller.stop()
            }
        }
    }

    @State private var selectedTab = 0

    private var mainTabView: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label(TextKeys.Stream.header, systemImage: "list.bullet").tag(0)
                Label(TextKeys.Lobby.header, systemImage: "tray.full").tag(1)
                Label("Jeeves", systemImage: "bubble.left.fill").tag(2)
                Label(TextKeys.Observatory.header, systemImage: "binoculars").tag(3)
                Label("Huis", systemImage: "house.fill").tag(4)
                Label("Logboek", systemImage: "scroll.fill").tag(5)
                Label(TextKeys.Settings.header, systemImage: "gearshape.fill").tag(6)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch selectedTab {
            case 0: StreamView()
            case 1: LobbyView()
            case 2: ChatView()
            case 3: ObservatoryView()
            case 4: HouseView()
            case 5: LogbookView()
            case 6: SettingsView()
            default: StreamView()
            }
        }
        .tint(Color.jeevesGold)
        #else
        TabView {
            Tab(TextKeys.Stream.header, systemImage: "list.bullet") { StreamView() }
            Tab(TextKeys.Lobby.header, systemImage: "tray.full") { LobbyView() }
                .badge(poller.pendingCount)
            Tab("Jeeves", systemImage: "bubble.left.fill") { ChatView() }
            Tab(TextKeys.Observatory.header, systemImage: "binoculars") { ObservatoryView() }
            Tab("Huis", systemImage: "house.fill") { HouseView() }
            Tab("Logboek", systemImage: "scroll.fill") { LogbookView() }
            Tab(TextKeys.Settings.header, systemImage: "gearshape.fill") { SettingsView() }
        }
        .tint(.jeevesGold)
        #endif
    }
}
