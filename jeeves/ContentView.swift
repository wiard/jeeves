import SwiftUI
import SwiftData

struct ContentView: View {
    private static let localDefaultPort = 19001

    @Environment(\.modelContext) private var modelContext
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @Query private var connections: [GatewayConnection]
    @State private var hasBootstrappedStartupConnection = false
    @State private var isBootstrappingConnection = true

    var body: some View {
        Group {
            if isBootstrappingConnection {
                ProgressView("Gateway verbinding initialiseren...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainTabView
            }
        }
        .onAppear {
            guard !hasBootstrappedStartupConnection else { return }
            hasBootstrappedStartupConnection = true

            Task { @MainActor in
                await bootstrapStartupConnection()
                isBootstrappingConnection = false
            }
        }
        .onChange(of: gateway.isConnected) {
            if gateway.isConnected {
                poller.start(gateway: gateway)
            } else {
                poller.stop()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .jeevesOpenObservatoryTab)) { _ in
            selectedTab = 3
        }
    }

    @State private var selectedTab = 0

    @MainActor
    private func bootstrapStartupConnection() async {
        if let discovered = gateway.startupGatewayConfigFromFile() {
            let normalized = GatewayManager.normalizeEndpoint(host: discovered.host, port: discovered.port)
            let connection = upsertConnection(
                host: normalized.host,
                port: normalized.port,
                channelId: "ios-app"
            )
            gateway.useMock = false
            gateway.connect(
                host: normalized.host,
                port: normalized.port,
                token: discovered.token,
                channelId: connection.channelId
            )
            return
        }

        if gateway.startupGatewayFileExists() {
            let existing = connections.first
            let preferredHost = existing?.host ?? "localhost"
            let preferredPort = existing?.port ?? Self.localDefaultPort
            let normalized = GatewayManager.normalizeEndpoint(host: preferredHost, port: preferredPort)
            let connection = upsertConnection(
                host: normalized.host,
                port: normalized.port,
                channelId: existing?.channelId ?? "ios-app"
            )
            gateway.useMock = false
            gateway.connect(
                host: normalized.host,
                port: normalized.port,
                token: nil,
                channelId: connection.channelId
            )
            return
        }

        let connection = upsertConnection(
            host: "mock",
            port: Self.localDefaultPort,
            channelId: "ios-app"
        )
        gateway.useMock = true
        gateway.connect(
            host: "mock",
            port: Self.localDefaultPort,
            token: "mock",
            channelId: connection.channelId
        )
    }

    @MainActor
    private func upsertConnection(host: String, port: Int, channelId: String) -> GatewayConnection {
        if let existing = connections.first {
            existing.host = host
            existing.port = port
            existing.channelId = channelId
            return existing
        }
        let created = GatewayConnection(host: host, port: port, channelId: channelId)
        modelContext.insert(created)
        return created
    }

    private var mainTabView: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Mission Control") {
                    Label(TextKeys.Stream.header, systemImage: "list.bullet").tag(0)
                    Label(TextKeys.Lobby.header, systemImage: "tray.full").tag(1)
                    Label("Jeeves", systemImage: "bubble.left.fill").tag(2)
                    Label(TextKeys.Observatory.header, systemImage: "binoculars").tag(3)
                    Label("Huis", systemImage: "house.fill").tag(4)
                    Label("Logboek", systemImage: "scroll.fill").tag(5)
                    Label(TextKeys.Settings.header, systemImage: "gearshape.fill").tag(6)
                }
                Section("AI Browser") {
                    Label("AI Browser", systemImage: "sparkle.magnifyingglass").tag(7)
                }
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
            case 7: AIBrowserView()
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
            Tab("AI Browser", systemImage: "sparkle.magnifyingglass") { AIBrowserView() }
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
}
