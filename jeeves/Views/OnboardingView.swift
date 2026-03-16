import SwiftUI
import SwiftData

struct OnboardingView: View {
    private static let localDefaultPort = 19001
    @Environment(\.modelContext) private var modelContext
    @Environment(GatewayManager.self) private var gateway
    @State private var currentPage = 0
    @State private var showConnectionFields = false
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
                    signalPage
                case 2:
                    decisionPage
                case 3:
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

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Image(systemName: "sun.max")
                .font(.system(size: 64, weight: .light, design: .rounded))
                .foregroundStyle(Color.jeevesGold)

            VStack(spacing: 12) {
                Text("Welcome.")
                    .font(.jeevesLargeTitle)

                Text("I am Jeeves.")
                    .font(.jeevesHeadline)

                Text("Your AI observatory.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private var signalPage: some View {
        VStack(spacing: 28) {
            Text("Jeeves watches the world for you.")
                .font(.jeevesLargeTitle)
                .multilineTextAlignment(.center)

            VStack(spacing: 14) {
                onboardingSignalRow(icon: "dot.radiowaves.left.and.right", title: "Signals")
                onboardingSignalRow(icon: "point.3.connected.trianglepath.dotted", title: "Patterns")
                onboardingSignalRow(icon: "sparkles", title: "Opportunities")
                onboardingSignalRow(icon: "exclamationmark.triangle", title: "Risks")
            }
            .padding(.horizontal, 32)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private var decisionPage: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .light, design: .rounded))
                .foregroundStyle(Color.jeevesSky)

            VStack(spacing: 12) {
                Text("When something matters, Jeeves brings it to you.")
                    .font(.jeevesLargeTitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("You decide what happens next.")
                    .font(.jeevesHeadline)

                Text("Jeeves can surface signals and research tasks, but governed actions still depend on your approval.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private var connectionPage: some View {
        VStack(spacing: 24) {
            Image(systemName: "network")
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundStyle(Color.jeevesSky)

            VStack(spacing: 8) {
                Text("Connect to your system")
                    .font(.jeevesLargeTitle)
                    .multilineTextAlignment(.center)

                Text("or explore with demo data.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            if showConnectionFields {
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
            }

            if let error = errorMessage {
                Text(error)
                    .font(.jeevesCaption)
                    .foregroundStyle(Color.consentRed)
            }

            VStack(spacing: 12) {
                Button(showConnectionFields ? "Connect gateway" : "Connect gateway") {
                    if showConnectionFields {
                        connect()
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showConnectionFields = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.jeevesGold)
                .disabled(isConnecting || (showConnectionFields && host.isEmpty))
                .accessibilityLabel("Connect gateway")
                .overlay {
                    if isConnecting {
                        ProgressView()
                            .tint(.white)
                    }
                }

                Button("Try demo mode") {
                    connectDemo()
                }
                .buttonStyle(.bordered)

                if showConnectionFields {
                    Text("Enter your gateway only after the system explanation. Demo mode keeps the experience safe and local.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Navigation

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { index in
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

            if currentPage < 3 {
                Button("Next") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage += 1
                    }
                }
                .font(.jeevesBody.weight(.semibold))
                .foregroundStyle(Color.jeevesGold)

                Button("Skip") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentPage = 3
                    }
                }
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func onboardingSignalRow(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.jeevesSky)
                .frame(width: 32)

            Text(title)
                .font(.jeevesHeadline)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
    }

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
