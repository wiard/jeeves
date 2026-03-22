import SwiftUI
import SwiftData

struct ConnectionSettings: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [GatewayConnection]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showResetConfirmation = false

    private var saved: GatewayConnection? { connections.first }
    private let runtime = RuntimeConfig.shared

    var body: some View {
        Section("Connection") {
            settingRow("Mode", modeLabel)
            settingRow("Endpoint", gatewayLabel)
            settingRow("Discovered", discoveredGatewayLabel)

            HStack {
                Text("Status")
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .foregroundStyle(.secondary)
                }
            }

            if let latency = gateway.latencyMs {
                settingRow("Latency", "\(latency)ms")
            }

            settingRow("Channel", saved?.channelId ?? "ios-app")
            settingRow("Token", tokenLabel, color: tokenLabel == "No token" ? .red : .secondary)
            settingRow("Mock flag", runtime.useMock ? "on" : "off")

            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Reset verbinding")
                }
                .frame(maxWidth: .infinity)
            }
            .confirmationDialog(
                "Weet je het zeker?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset verbinding", role: .destructive) {
                    resetConnection()
                }
                Button("Annuleer", role: .cancel) {}
            } message: {
                Text("Alle opgeslagen verbindingen en tokens worden verwijderd. Je keert terug naar het onboarding scherm.")
            }
        }
    }

    private func resetConnection() {
        // 1. Delete all GatewayConnections from SwiftData
        for connection in connections {
            modelContext.delete(connection)
        }
        try? modelContext.save()

        // 2. Delete all conductor tokens from Keychain
        KeychainHelper.deleteAll()

        // 3. Disconnect the active gateway
        gateway.disconnect()

        // 4. Return to onboarding
        hasCompletedOnboarding = false
    }

    @ViewBuilder
    private func settingRow(_ label: String, _ value: String, color: Color = .secondary) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.jeevesMono)
                .foregroundStyle(color)
        }
    }

    private var modeLabel: String {
        (gateway.useMock || gateway.host.lowercased() == "mock") ? "Demo preview" : "Governed gateway"
    }

    private var gatewayLabel: String {
        if gateway.host.lowercased() == "mock" {
            return "mock"
        }
        if !gateway.host.isEmpty, gateway.port > 0 {
            return "\(gateway.host):\(gateway.port)"
        }
        if let h = runtime.host, let p = runtime.port {
            let normalized = GatewayManager.normalizeEndpoint(host: h, port: p)
            return "\(normalized.host):\(normalized.port)"
        }
        if let discovered = gateway.startupGatewayConfigFromFile() {
            let normalized = GatewayManager.normalizeEndpoint(host: discovered.host, port: discovered.port)
            return "\(normalized.host):\(normalized.port)"
        }
        if let c = saved {
            let normalized = GatewayManager.normalizeEndpoint(host: c.host, port: c.port)
            return "\(normalized.host):\(normalized.port)"
        }
        return "Not configured"
    }

    private var discoveredGatewayLabel: String {
        if let discovered = gateway.startupGatewayConfigFromFile() {
            let normalized = GatewayManager.normalizeEndpoint(host: discovered.host, port: discovered.port)
            return "\(normalized.host):\(normalized.port)"
        }
        if gateway.startupGatewayFileExists() {
            return "gateway.json found, endpoint unreadable"
        }
        if let c = saved, !GatewayManager.isLocalDevelopmentHost(c.host) {
            return "Skipped (remote connection active)"
        }
        return "No gateway.json"
    }

    private var tokenLabel: String {
        if let t = runtime.token, !t.isEmpty {
            return "\(t.prefix(10))…"
        }

        let liveKey: String? = {
            guard !gateway.host.isEmpty, gateway.port > 0 else { return nil }
            return "\(gateway.host):\(gateway.port)"
        }()
        let savedKey: String? = {
            guard let c = saved else { return nil }
            return "\(c.host):\(c.port)"
        }()

        for key in [liveKey, savedKey].compactMap({ $0 }) {
            if let token = KeychainHelper.load(for: key), !token.isEmpty, token != "mock" {
                return "\(token.prefix(10))…"
            }
        }
        return "No token"
    }

    private var statusColor: Color {
        switch gateway.connectionState {
        case .connected: .consentGreen
        case .connecting, .reconnecting: .consentOrange
        case .idle, .disconnected, .failed: .consentRed
        }
    }

    private var statusText: String {
        switch gateway.connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .reconnecting:
            return "Reconnecting..."
        case .idle, .disconnected:
            return "Not connected"
        case .failed:
            return tokenLabel == "No token" ? "Token missing" : "Connection failed"
        }
    }
}
