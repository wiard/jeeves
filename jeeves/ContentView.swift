
import SwiftUI
import SwiftData

struct ContentView: View {
    private static let localDefaultPort = 19001
    private static let defaultHost = "178.104.55.41"
    private static let defaultPort = 19001
    private static let defaultConductorToken = "v1.eyJzY29wZSI6ImNvbmR1Y3RvciIsInNlc3Npb25JZCI6Im9yYWNsZSIsImlzc3VlZEF0SXNvIjoiMjAyNi0wMy0xOVQwNjoxOToxMy43MjNaIiwiZXhwaXJlc0F0SXNvIjoiMjAyNy0wMy0xOVQwNjoxOToxMy43MjNaIn0.nKJRvtALsboY-RWKt2sUtbwu2i0TtzbEViIh_6KU10A"

    @Environment(\.modelContext) private var modelContext
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @Environment(JeevesOrchestrator.self) private var orchestrator
    @Query private var connections: [GatewayConnection]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var hasBootstrappedStartupConnection = false
    @State private var isBootstrappingConnection = true
    @State private var needsOnboarding = false
    @State private var selectedTab: AppScreen = .vandaag
    @StateObject private var beslissingenViewModel = BeslissingenViewModel()

    private var primaryTabs: Set<AppScreen> {
        [.vandaag, .zoeker, .beslissingen, .kanaal, .classified, .research, .chat, .stream, .observatory, .house, .settings]
    }

    var body: some View {
        Group {
            if !hasCompletedOnboarding || needsOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                    needsOnboarding = false
                    isBootstrappingConnection = false
                    selectedTab = .vandaag
                }
            } else if isBootstrappingConnection {
                ProgressView("Initializing gateway connection...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mainTabView
            }
        }
        .onAppear {
            guard !hasBootstrappedStartupConnection else { return }
            hasBootstrappedStartupConnection = true

            if !hasCompletedOnboarding {
                isBootstrappingConnection = false
                return
            }

            Task { @MainActor in
                await bootstrapStartupConnection()
                isBootstrappingConnection = false
            }
        }
        .onChange(of: gateway.isConnected) {
            beslissingenViewModel.configure(gateway: gateway)
            if gateway.isConnected {
                poller.start(gateway: gateway)
                Task {
                    await beslissingenViewModel.fetchOpenDecisions()
                }
            } else {
                poller.stop()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .jeevesOpenObservatoryTab)) { _ in
            selectedTab = .observatory
        }
        .onReceive(NotificationCenter.default.publisher(for: .jeevesOpenSystemTab)) { _ in
            selectedTab = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .jeevesOpenMissionControlTab)) { _ in
            selectedTab = .stream
        }
        .onReceive(NotificationCenter.default.publisher(for: .jeevesOpenVandaagTab)) { _ in
            selectedTab = .vandaag
        }
        .onReceive(NotificationCenter.default.publisher(for: .jeevesOpenResearchTab)) { _ in
            selectedTab = .research
        }
        .onReceive(NotificationCenter.default.publisher(for: .jeevesOpenDisciplinesTab)) { _ in
            selectedTab = .research
        }
        .onChange(of: orchestrator.activeDirective) {
            guard let directive = orchestrator.activeDirective else { return }
            if primaryTabs.contains(directive.destination) {
                selectedTab = directive.destination
            }
        }
        .onChange(of: selectedTab) {
            orchestrator.session.recordScreenChange(selectedTab)
        }
        .task {
            guard hasCompletedOnboarding else { return }
            beslissingenViewModel.configure(gateway: gateway)
            await beslissingenViewModel.fetchOpenDecisions()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                beslissingenViewModel.configure(gateway: gateway)
                await beslissingenViewModel.fetchOpenDecisions()
            }
        }
    }

    /// Seeds factory defaults for host and conductor token on first launch.
    /// Only writes when no GatewayConnection and no Keychain token exist yet.
    @MainActor
    private func seedDefaultsIfNeeded() {
        guard connections.isEmpty else { return }

        let keychainKey = "\(Self.defaultHost):\(Self.defaultPort)"
        guard KeychainHelper.load(for: keychainKey) == nil else { return }

        let connection = GatewayConnection(
            host: Self.defaultHost,
            port: Self.defaultPort,
            channelId: "ios-app"
        )
        modelContext.insert(connection)
        try? KeychainHelper.save(token: Self.defaultConductorToken, for: keychainKey)
    }

    @MainActor
    private func bootstrapStartupConnection() async {
        seedDefaultsIfNeeded()

        // If we have a configured endpoint that is NOT localhost / local-network,
        // use it directly — discovery must never override an explicit remote host.
        if let existing = connections.first {
            let normalized = GatewayManager.normalizeEndpoint(host: existing.host, port: existing.port)
            if !GatewayManager.isLocalDevelopmentHost(normalized.host) {
                let keychainKey = "\(normalized.host):\(normalized.port)"
                let token = KeychainHelper.load(for: keychainKey) ?? KeychainHelper.loadAnyToken()
                gateway.useMock = false
                gateway.connect(
                    host: normalized.host,
                    port: normalized.port,
                    token: token,
                    channelId: existing.channelId
                )
                return
            }
        }

        if let discovered = gateway.startupGatewayConfigFromFile() {
            let normalized = GatewayManager.normalizeEndpoint(host: discovered.host, port: discovered.port)
            // Use discovery file when:
            // 1. It points to a local dev host (local override), OR
            // 2. It points to a remote host and the saved connection is stale-local or absent
            let savedIsStaleLocal = connections.first.map {
                GatewayManager.isLocalDevelopmentHost(
                    GatewayManager.normalizeEndpoint(host: $0.host, port: $0.port).host
                )
            } ?? true // nil = no saved connection → treat as "needs discovery"

            if GatewayManager.isLocalDevelopmentHost(normalized.host) || savedIsStaleLocal {
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

        // No gateway config found — route to onboarding
        needsOnboarding = true
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
                Section("Cockpit") {
                    Label("Vandaag", systemImage: AppScreen.vandaag.icon).tag(AppScreen.vandaag)
                    Label("De Zoeker", systemImage: AppScreen.zoeker.icon).tag(AppScreen.zoeker)
                    Label("Beslissingen", systemImage: AppScreen.beslissingen.icon).tag(AppScreen.beslissingen)
                    Label("Kanaal", systemImage: AppScreen.kanaal.icon).tag(AppScreen.kanaal)
                    Label("Ontdekkingen", systemImage: AppScreen.classified.icon).tag(AppScreen.classified)
                    Label("Disciplines", systemImage: AppScreen.research.icon).tag(AppScreen.research)
                }
                Section("Jeeves") {
                    Label("Jeeves", systemImage: "sun.max").tag(AppScreen.chat)
                    Label("Mission Control", systemImage: "scope").tag(AppScreen.stream)
                    Label("Observatory", systemImage: "binoculars").tag(AppScreen.observatory)
                    Label("Knowledge", systemImage: "book.closed.fill").tag(AppScreen.house)
                }
                Section("More") {
                    Label(TextKeys.Lobby.header, systemImage: AppScreen.lobby.icon).tag(AppScreen.lobby)
                    Label("Logbook", systemImage: AppScreen.logbook.icon).tag(AppScreen.logbook)
                    Label("AI Browser", systemImage: AppScreen.aiBrowser.icon).tag(AppScreen.aiBrowser)
                }
                Section {
                    Label("System", systemImage: AppScreen.settings.icon).tag(AppScreen.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            screenView(for: selectedTab)
        }
        .tint(Color.jeevesSky)
        #else
        TabView(selection: $selectedTab) {
            VandaagView()
                .tabItem { Label("Vandaag", systemImage: "house.fill") }
                .tag(AppScreen.vandaag)
            ZoekerView()
                .tabItem { Label("De Zoeker", systemImage: "circle.grid.3x3.fill") }
                .tag(AppScreen.zoeker)
            BeslissingenView(viewModel: beslissingenViewModel)
                .badge(beslissingenViewModel.badgeText)
                .tabItem { Label("Beslissingen", systemImage: "checkmark.circle.fill") }
                .tag(AppScreen.beslissingen)
            JeevesKanaalView()
                .tabItem { Label("Kanaal", systemImage: "message.fill") }
                .tag(AppScreen.kanaal)
            ClassifiedView(beslissingenViewModel: beslissingenViewModel)
                .tabItem { Label("Ontdekkingen", systemImage: "sparkles") }
                .tag(AppScreen.classified)
            DisciplineView()
                .tabItem { Label("Disciplines", systemImage: "magnifyingglass.circle.fill") }
                .tag(AppScreen.research)
            JeevesView()
                .tabItem { Label("Jeeves", systemImage: "sun.max") }
                .tag(AppScreen.chat)
            MissionControlDashboardView()
                .tabItem { Label("Mission Control", systemImage: "scope") }
                .tag(AppScreen.stream)
            ObservatoryView()
                .tabItem { Label("Observatory", systemImage: "binoculars") }
                .tag(AppScreen.observatory)
            KnowledgeBrowserView()
                .tabItem { Label("Knowledge", systemImage: "book.closed.fill") }
                .tag(AppScreen.house)
            SettingsView()
                .tabItem { Label("System", systemImage: "gearshape.fill") }
                .tag(AppScreen.settings)
        }
        .tint(.jeevesSky)
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
        case .vandaag:    VandaagView()
        case .zoeker:     ZoekerView()
        case .beslissingen: BeslissingenView(viewModel: beslissingenViewModel)
        case .kanaal:     JeevesKanaalView()
        case .classified: ClassifiedView(beslissingenViewModel: beslissingenViewModel)
        case .research:   DisciplineView()
        case .stream:      MissionControlDashboardView()
        case .lobby:       LobbyView()
        case .chat:        JeevesView()
        case .observatory: ObservatoryView()
        case .house:       KnowledgeBrowserView()
        case .logbook:     LogbookView()
        case .aiBrowser:   AIBrowserView()
        case .settings:    SettingsView()
        }
    }
}

extension Notification.Name {
    static let jeevesOpenVandaagTab = Notification.Name("jeeves.openVandaagTab")
    static let jeevesOpenResearchTab = Notification.Name("jeeves.openResearchTab")
    static let jeevesOpenDisciplinesTab = Notification.Name("jeeves.openDisciplinesTab")
    static let jeevesOpenSystemTab = Notification.Name("jeeves.openSystemTab")
    static let jeevesOpenMissionControlTab = Notification.Name("jeeves.openMissionControlTab")
}
