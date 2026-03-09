import SwiftUI
import SwiftData

struct ChatView: View {
    private static let localDefaultPort = 19001
    @Environment(\.modelContext) private var modelContext
    @Environment(GatewayManager.self) private var gateway
    @Environment(JeevesOrchestrator.self) private var orchestrator
    @Query(sort: \ChatMessage.timestamp) private var messages: [ChatMessage]
    @State private var streamingText: String = ""
    @State private var isStreaming = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionBanner
                messageList
                ChatInputBar(onSend: sendMessage)
            }
            .navigationTitle("Jeeves")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Jeeves")
                            .font(.jeevesHeadline)
                        Text(gateway.isConnected ? "Verbonden" : "Niet verbonden")
                            .font(.jeevesCaption)
                            .foregroundStyle(gateway.isConnected ? Color.consentGreen : Color.secondary)
                    }
                }
            }
        }
        .onAppear {
            setupMessageHandler()
            addWelcomeMessageIfNeeded()
        }
    }

    private var connectionBanner: some View {
        Group {
            if gateway.connectionState == .reconnecting {
                HStack {
                    ProgressView()
                        .tint(.white)
                    Text("Opnieuw verbinden...")
                        .font(.jeevesCaption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.orange)
                .foregroundStyle(.white)
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        messageView(for: message)
                            .id(message.id)
                    }

                    if isStreaming {
                        StreamingText(text: streamingText)
                            .id("streaming")
                    }
                }
                .padding()
            }
            .refreshable {
                if !gateway.isConnected {
                    reconnectGateway()
                }
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func messageView(for message: ChatMessage) -> some View {
        if message.isConsentRequest {
            ConsentCard(
                tool: message.consentTool ?? "",
                risk: message.consentRisk ?? .orange,
                reason: message.consentReason ?? "",
                approved: message.consentApproved,
                onApprove: { approveConsent(message) },
                onDeny: { denyConsent(message) }
            )
        } else if message.isBlocked {
            ConsentCard(
                tool: message.blockedTool ?? "",
                risk: .red,
                reason: message.blockedReason ?? "",
                approved: nil,
                onApprove: {},
                onDeny: {}
            )
        } else {
            MessageBubble(
                text: message.text,
                sender: message.sender,
                timestamp: message.timestamp
            )
        }
    }

    // MARK: - Actions

    private func sendMessage(_ text: String) {
        let userMessage = ChatMessage(text: text, sender: .user)
        modelContext.insert(userMessage)

        // Ask orchestrator first — navigate if it recognises a screen intent
        if let directive = orchestrator.resolve(text: text, readers: []) {
            let explanation = ChatMessage(text: directive.explanation, sender: .jeeves)
            modelContext.insert(explanation)
            orchestrator.navigate(to: directive)
            return
        }

        // No navigation intent — send to gateway as normal chat
        Task {
            do {
                try await gateway.send(text: text)
            } catch {
                let errorMessage = ChatMessage(
                    text: "Kon het bericht niet versturen: \(error.localizedDescription)",
                    sender: .system
                )
                modelContext.insert(errorMessage)
            }
        }
    }

    private func approveConsent(_ message: ChatMessage) {
        message.consentApproved = true
        message.consentRespondedAt = Date()
        JeevesHaptics.approved()

        Task {
            try? await gateway.respondToConsent(
                id: message.consentId ?? "",
                approved: true,
                tool: message.consentTool
            )
        }
    }

    private func denyConsent(_ message: ChatMessage) {
        message.consentApproved = false
        message.consentRespondedAt = Date()

        let deniedMessage = ChatMessage(
            text: "Verzoek geweigerd.",
            sender: .system
        )
        modelContext.insert(deniedMessage)

        Task {
            try? await gateway.respondToConsent(
                id: message.consentId ?? "",
                approved: false
            )
        }
    }

    // MARK: - Setup

    private func setupMessageHandler() {
        gateway.onMessage { [self] message in
            handleIncoming(message)
        }
    }

    private func handleIncoming(_ message: IncomingMessage) {
        switch message {
        case .response(let text, _, _, let timestamp):
            let msg = ChatMessage(text: text, sender: .jeeves, timestamp: timestamp)
            modelContext.insert(msg)

        case .consentRequest(let id, let tool, let risk, let reason, _, let timestamp):
            let msg = ChatMessage.consentRequest(
                consentId: id,
                tool: tool,
                risk: risk,
                reason: reason,
                timestamp: timestamp
            )
            modelContext.insert(msg)
            JeevesHaptics.consentPrompt()

        case .blocked(let tool, let risk, let reason, let timestamp):
            let msg = ChatMessage.blocked(
                tool: tool,
                risk: risk,
                reason: reason,
                timestamp: timestamp
            )
            modelContext.insert(msg)
            JeevesHaptics.blocked()

        case .streamDelta(let text, _):
            isStreaming = true
            streamingText += text

        case .streamEnd(let text, _, _, let timestamp):
            isStreaming = false
            streamingText = ""
            let msg = ChatMessage(text: text, sender: .jeeves, timestamp: timestamp)
            modelContext.insert(msg)

        case .status:
            break // Handled by GatewayManager

        case .error(let errorText):
            let msg = ChatMessage(text: errorText, sender: .system)
            modelContext.insert(msg)
        }
    }

    private func addWelcomeMessageIfNeeded() {
        if messages.isEmpty {
            let welcome = ChatMessage(
                text: "Welkom terug, meneer. Het huis is in orde.",
                sender: .jeeves
            )
            modelContext.insert(welcome)
        }
    }

    private func reconnectGateway() {
        if gateway.useMock || gateway.host.lowercased() == "mock" {
            gateway.useMock = true
            gateway.connect(host: "mock", port: Self.localDefaultPort, token: "mock")
            return
        }

        Task { @MainActor in
            let normalizedEndpoint = GatewayManager.normalizeEndpoint(host: gateway.host, port: gateway.port)
            let resolvedHost = normalizedEndpoint.host
            let resolvedPort = normalizedEndpoint.port
            let preferredToken = gateway.token ?? KeychainHelper.load(for: "\(resolvedHost):\(resolvedPort)")
            let resolution = GatewayManager.isLocalDevelopmentHost(resolvedHost)
                ? await gateway.resolveLocalDevelopmentGateway(
                    host: resolvedHost,
                    preferredPort: resolvedPort,
                    preferredToken: preferredToken,
                    allowPortFallback: true
                )
                : GatewayManager.LocalGatewayResolution(
                    host: resolvedHost,
                    port: resolvedPort,
                    token: preferredToken,
                    isHealthy: false
                )

            gateway.useMock = false
            gateway.connect(host: resolution.host, port: resolution.port, token: resolution.token)
        }
    }
}
