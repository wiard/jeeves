import SwiftUI
import SwiftData

struct OnboardingView: View {
    private static let localDefaultPort = 19001
    @Environment(\.modelContext) private var modelContext
    @Environment(GatewayManager.self) private var gateway
    @State private var host = "localhost"
    @State private var port = "19001"
    @State private var isConnecting = false
    @State private var errorMessage: String?

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Butler hat icon
            Text("\u{1f3a9}")
                .font(.system(size: 80))

            VStack(spacing: 8) {
                Text("Welkom, meneer.")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Ik ben Jeeves, uw persoonlijke butler.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)

                Text("Om te beginnen heb ik het adres van uw gateway nodig.")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            VStack(spacing: 12) {
                TextField("Gateway adres", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .accessibilityLabel("Gateway IP adres")

                TextField("Poort", text: $port)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .accessibilityLabel("Gateway poort")
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
                        Text("Verbind")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.jeevesGold)
                .disabled(host.isEmpty || isConnecting)
                .accessibilityLabel("Verbind met gateway")

                Button("Gebruik mock modus") {
                    connectMock()
                }
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private func connect() {
        guard let portNum = Int(port), portNum > 0 else {
            errorMessage = "Ongeldig poortnummer"
            return
        }
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLocalDev = GatewayManager.isLocalDevelopmentHost(normalizedHost)
        let normalizedPort = portNum

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

            if let token = resolution.token, !token.isEmpty {
                gateway.useMock = false
                gateway.connect(host: resolution.host, port: resolution.port, token: token, channelId: "ios-app")
            } else {
                gateway.useMock = true
                gateway.connect(host: "mock", port: Self.localDefaultPort, token: "mock", channelId: "ios-app")
            }
            isConnecting = false
            onComplete()
        }
    }

    private func connectMock() {
        let connection = GatewayConnection(host: "mock", port: Self.localDefaultPort)
        modelContext.insert(connection)

        gateway.useMock = true
        gateway.connect(host: "mock", port: Self.localDefaultPort, token: "mock", channelId: "ios-app")
        onComplete()
    }
}
