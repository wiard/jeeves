import SwiftUI
import SwiftData

@main
struct JeevesApp: App {
    @State private var gatewayManager = GatewayManager()
    @State private var proposalPoller = ProposalPoller()
    @State private var orchestrator = JeevesOrchestrator()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChatMessage.self,
            GatewayConnection.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(gatewayManager)
                .environment(proposalPoller)
                .environment(orchestrator)
                .onAppear {
                    NotificationManager.shared.requestPermission()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
