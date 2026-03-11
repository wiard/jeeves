
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
    @State private var selectedTab: AppScreen = .stream
    @State private var auxiliaryScreen: AppScreen?

    private var primaryTabs: Set<AppScreen> {
        [.chat, .stream, .observatory, .house, .settings]
    }

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
            if primaryTabs.contains(directive.destination) {
                selectedTab = directive.destination
            } else {
                auxiliaryScreen = directive.destination
                orchestrator.session.recordScreenChange(directive.destination)
            }
        }
        .onChange(of: selectedTab) {
            orchestrator.session.recordScreenChange(selectedTab)
        }
    }

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
                Section("Jeeves") {
                    Label("Jeeves", systemImage: "sun.max").tag(AppScreen.chat)
                    Label("Mission Control", systemImage: "scope").tag(AppScreen.stream)
                    Label("Radar", systemImage: "binoculars").tag(AppScreen.observatory)
                    Label("Knowledge", systemImage: "book.closed.fill").tag(AppScreen.house)
                }
                Section("More") {
                    Label(TextKeys.Lobby.header, systemImage: AppScreen.lobby.icon).tag(AppScreen.lobby)
                    Label("Logboek", systemImage: AppScreen.logbook.icon).tag(AppScreen.logbook)
                    Label("AI Browser", systemImage: AppScreen.aiBrowser.icon).tag(AppScreen.aiBrowser)
                }
                Section {
                    Label(TextKeys.Settings.header, systemImage: AppScreen.settings.icon).tag(AppScreen.settings)
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
            Tab("Mission Control", systemImage: "scope", value: .stream) {
                StreamView()
            }
            Tab("Jeeves", systemImage: "sun.max", value: .chat) {
                JeevesView()
            }
            Tab("Radar", systemImage: "binoculars", value: .observatory) {
                CLASHD27RadarView()
            }
            Tab("Knowledge", systemImage: "book.closed.fill", value: .house) {
                KnowledgeBrowserView()
            }
            Tab(TextKeys.Settings.header, systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }
        }
        .sheet(item: $auxiliaryScreen) { screen in
            screenView(for: screen)
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
        case .chat:        JeevesView()
        case .observatory: CLASHD27RadarView()
        case .house:       KnowledgeBrowserView()
        case .logbook:     LogbookView()
        case .aiBrowser:   AIBrowserView()
        case .settings:    SettingsView()
        }
    }
}
