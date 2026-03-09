import SwiftUI
import SwiftData

struct ContentView: View {
    private static let localDefaultPort = 19001

    @Environment(\.modelContext) private var modelContext
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @Environment(JeevesOrchestrator.self) private var orchestrator
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
            selectedTab = .observatory
        }
        .onChange(of: orchestrator.activeDirective) {
            guard let directive = orchestrator.activeDirective else { return }
            selectedTab = directive.destination
        }
        .onChange(of: selectedTab) {
            orchestrator.session.recordScreenChange(selectedTab)
        }
    }

    @State private var selectedTab: AppScreen = .stream

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
                    Label(TextKeys.Stream.header, systemImage: AppScreen.stream.icon).tag(AppScreen.stream)
                    Label(TextKeys.Lobby.header, systemImage: AppScreen.lobby.icon).tag(AppScreen.lobby)
                    Label("Jeeves", systemImage: AppScreen.chat.icon).tag(AppScreen.chat)
                    Label(TextKeys.Observatory.header, systemImage: AppScreen.observatory.icon).tag(AppScreen.observatory)
                    Label("Huis", systemImage: AppScreen.house.icon).tag(AppScreen.house)
                    Label("Logboek", systemImage: AppScreen.logbook.icon).tag(AppScreen.logbook)
                    Label(TextKeys.Settings.header, systemImage: AppScreen.settings.icon).tag(AppScreen.settings)
                }
                Section("AI Browser") {
                    Label("AI Browser", systemImage: AppScreen.aiBrowser.icon).tag(AppScreen.aiBrowser)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            screenView(for: selectedTab)
        }
        .tint(Color.jeevesGold)
        #else
        TabView(selection: $selectedTab) {
            Tab(TextKeys.Stream.header, systemImage: AppScreen.stream.icon, value: .stream) { StreamView() }
            Tab(TextKeys.Lobby.header, systemImage: AppScreen.lobby.icon, value: .lobby) { LobbyView() }
                .badge(poller.pendingCount)
            Tab("Jeeves", systemImage: AppScreen.chat.icon, value: .chat) { ChatView() }
            Tab(TextKeys.Observatory.header, systemImage: AppScreen.observatory.icon, value: .observatory) { ObservatoryView() }
            Tab("Huis", systemImage: AppScreen.house.icon, value: .house) { HouseView() }
            Tab("Logboek", systemImage: AppScreen.logbook.icon, value: .logbook) { LogbookView() }
            Tab("AI Browser", systemImage: AppScreen.aiBrowser.icon, value: .aiBrowser) { AIBrowserView() }
            Tab(TextKeys.Settings.header, systemImage: AppScreen.settings.icon, value: .settings) { SettingsView() }
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

    @ViewBuilder
    private func screenView(for screen: AppScreen) -> some View {
        switch screen {
        case .stream:      StreamView()
        case .lobby:       LobbyView()
        case .chat:        ChatView()
        case .observatory: ObservatoryView()
        case .house:       HouseView()
        case .logbook:     LogbookView()
        case .aiBrowser:   AIBrowserView()
        case .settings:    SettingsView()
        }
    }
}
