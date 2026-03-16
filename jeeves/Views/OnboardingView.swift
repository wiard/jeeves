import SwiftUI
import SwiftData

struct OnboardingView: View {
    private static let localDefaultPort = 19001
    @Environment(\.modelContext) private var modelContext
    @Environment(GatewayManager.self) private var gateway
    @State private var currentPage = 0
    @State private var host = "localhost"
    @State private var port = "19001"
    @State private var isConnecting = false
    @State private var errorMessage: String?

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            InstrumentBackdrop(
                colors: [
                    Color(red: 0.96, green: 0.97, blue: 0.99),
                    Color(red: 0.94, green: 0.96, blue: 0.99),
                    Color(red: 0.98, green: 0.96, blue: 0.93)
                ]
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                switch currentPage {
                case 0:
                    welcomePage
                case 1:
                    tabsPage
                case 2:
                    connectionPage
                default:
                    welcomePage
                }

                Spacer()

                pageIndicator
                    .padding(.bottom, 16)

                navigationButtons
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Page 1: Meet Jeeves

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Image(systemName: "sun.max")
                .font(.system(size: 64, weight: .light, design: .rounded))
                .foregroundStyle(Color.jeevesGold)

            VStack(spacing: 12) {
                Text("Meet Jeeves")
                    .font(.jeevesLargeTitle)

                Text("Jeeves monitors intelligence signals, surfaces what needs your decision, and tracks what your system learns.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Page 2: Tabs Explained

    private var tabsPage: some View {
        VStack(spacing: 28) {
            Text("Three views, one picture")
                .font(.jeevesLargeTitle)

            VStack(alignment: .leading, spacing: 20) {
                tabExplanation(
                    icon: "sun.max",
                    title: "Jeeves",
                    description: "Your daily briefing. World signals, AI developments, and emerging patterns — summarized each morning."
                )

                tabExplanation(
                    icon: "scope",
                    title: "Mission Control",
                    description: "The full dashboard. System status, pending decisions, research tasks, and live signal activity."
                )

                tabExplanation(
                    icon: "binoculars",
                    title: "Observatory",
                    description: "Incoming signals and discovery patterns as they arrive from your connected sources."
                )
            }
            .padding(.horizontal, 32)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Page 3: Connection

    private var connectionPage: some View {
        VStack(spacing: 24) {
            Image(systemName: "network")
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundStyle(Color.jeevesSky)

            VStack(spacing: 8) {
                Text("Connect your gateway")
                    .font(.jeevesLargeTitle)

                Text("Enter the address of your gateway to see live data. Or try the demo to explore the interface first.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 12) {
                TextField("Gateway address", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .accessibilityLabel("Gateway address")

                TextField("Port", text: $port)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .accessibilityLabel("Gateway port")
            }
            .padding(.horizontal, 40)

            if let error = errorMessage {
                Text(error)
                    .font(.jeevesCaption)
                    .foregroundStyle(Color.consentRed)
            }

            VStack(spacing: 12) {
                Button(action: connect) {
                    if isConnecting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.jeevesGold)
                .disabled(host.isEmpty || isConnecting)
                .accessibilityLabel("Connect to gateway")

                Button("Try with demo data") {
                    connectDemo()
                }
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Navigation

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index == currentPage ? Color.jeevesGold : Color.jeevesGold.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var navigationButtons: some View {
        HStack {
            if currentPage > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage -= 1
                    }
                }
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if currentPage < 2 {
                Button("Next") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage += 1
                    }
                }
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(Color.jeevesGold)

                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage = 2
                    }
                }
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func tabExplanation(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.jeevesGold)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.jeevesHeadline)
                Text(description)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Connection Logic

    private func connect() {
        guard let portNum = Int(port), portNum > 0 else {
            errorMessage = "Invalid port number"
            return
        }
        let normalizedInputHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEndpoint = GatewayManager.normalizeEndpoint(host: normalizedInputHost, port: portNum)
        let normalizedHost = normalizedEndpoint.host
        let normalizedPort = normalizedEndpoint.port
        let isLocalDev = GatewayManager.isLocalDevelopmentHost(normalizedHost)

        isConnecting = true
        errorMessage = nil

        let connection = GatewayConnection(host: normalizedHost, port: normalizedPort)
        modelContext.insert(connection)

        Task { @MainActor in
            let directToken = KeychainHelper.load(for: "\(normalizedHost):\(normalizedPort)")
            let resolution = isLocalDev
                ? await gateway.resolveLocalDevelopmentGateway(
                    host: normalizedHost,
                    preferredPort: normalizedPort,
                    preferredToken: directToken,
                    allowPortFallback: true
                )
                : GatewayManager.LocalGatewayResolution(
                    host: normalizedHost,
                    port: normalizedPort,
                    token: directToken,
                    isHealthy: false
                )

            if isLocalDev, connection.port != resolution.port {
                connection.port = resolution.port
            }
            if isLocalDev, connection.host != resolution.host {
                connection.host = resolution.host
            }

            gateway.useMock = false
            gateway.connect(host: resolution.host, port: resolution.port, token: resolution.token, channelId: "ios-app")
            isConnecting = false
            onComplete()
        }
    }

    private func connectDemo() {
        let connection = GatewayConnection(host: "mock", port: Self.localDefaultPort)
        modelContext.insert(connection)

        gateway.useMock = true
        gateway.connect(host: "mock", port: Self.localDefaultPort, token: "mock", channelId: "ios-app")
        onComplete()
    }
}
