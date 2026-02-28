import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GatewayManager.self) private var gateway
    @State private var host = "192.168.1."
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

        isConnecting = true
        errorMessage = nil

        let connection = GatewayConnection(host: host, port: portNum)
        modelContext.insert(connection)

        // For development: use mock mode since no gateway is running yet
        gateway.useMock = true
        gateway.connect(host: host, port: portNum, token: "mock", channelId: "ios-app")
        isConnecting = false
        onComplete()
    }

    private func connectMock() {
        let connection = GatewayConnection(host: "mock", port: 19001)
        modelContext.insert(connection)

        gateway.useMock = true
        gateway.connect(host: "mock", port: 19001, token: "mock", channelId: "ios-app")
        onComplete()
    }
}
