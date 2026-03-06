import SwiftUI
import SwiftData

struct ContentView: View {
    private static let localDefaultPort = 19001
    private static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1"]

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

            if gateway.isConnected {
                poller.start(gateway: gateway)
                return
            }
            guard let conn = connections.first else { return }
            Task { @MainActor in
                await bootstrapGatewayConnection(using: conn)
            }
        }
        .onChange(of: gateway.isConnected) {
            if gateway.isConnected {
                poller.start(gateway: gateway)
                Task {
                    await poller.seedIfNeeded(gateway: gateway)
                }
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
        .overlay(alignment: .top) {
            if let toast = poller.seedToastMessage {
                Text(toast)
                    .font(.jeevesBody)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 4)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: poller.seedToastMessage)
        #endif
    }

    @MainActor
    private func bootstrapGatewayConnection(using conn: GatewayConnection) async {
        let cfg = RuntimeConfig.shared
        gateway.useMock = cfg.useMock

        let resolvedHost: String = {
            let h = (cfg.host ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return h.isEmpty ? conn.host : h
        }()

        let resolvedPort: Int = {
            if let p = cfg.port, p > 0 { return p }
            return conn.port > 0 ? conn.port : Self.localDefaultPort
        }()

        let runtimeToken = (cfg.token ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedToken: String? = {
            if !runtimeToken.isEmpty { return runtimeToken }
            if let primary = KeychainHelper.load(for: "\(resolvedHost):\(resolvedPort)"), !primary.isEmpty {
                return primary
            }
            return nil
        }()

        if cfg.useMock {
            gateway.useMock = true
            gateway.connect(
                host: "mock",
                port: Self.localDefaultPort,
                token: "mock",
                channelId: conn.channelId
            )
            return
        }

        let lowerHost = resolvedHost.lowercased()
        let isLoopback = Self.loopbackHosts.contains(lowerHost)
        let hasRuntimePortOverride = (cfg.port != nil)

        let resolution = isLoopback
            ? await gateway.resolveLocalDevelopmentGateway(
                host: resolvedHost,
                preferredPort: resolvedPort,
                preferredToken: resolvedToken,
                allowPortFallback: !hasRuntimePortOverride
            )
            : GatewayManager.LocalGatewayResolution(
                host: resolvedHost,
                port: resolvedPort,
                token: resolvedToken,
                isHealthy: false
            )

        #if DEBUG
        print("[Jeeves][ContentView] gateway resolution configured=\(resolvedHost):\(resolvedPort) discovered=\(resolution.host):\(resolution.port) healthy=\(resolution.isHealthy) token=\((resolution.token?.isEmpty == false) ? "present" : "missing")")
        #endif

        if !hasRuntimePortOverride, isLoopback, conn.port != resolution.port {
            conn.port = resolution.port
        }

        if let token = resolution.token, !token.isEmpty {
            gateway.useMock = false
            gateway.connect(
                host: resolution.host,
                port: resolution.port,
                token: token,
                channelId: conn.channelId
            )
        } else {
            gateway.useMock = true
            gateway.connect(
                host: "mock",
                port: Self.localDefaultPort,
                token: "mock",
                channelId: conn.channelId
            )
        }
    }
}
