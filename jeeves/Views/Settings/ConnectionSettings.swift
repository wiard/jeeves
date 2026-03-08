import SwiftUI
import SwiftData

struct ConnectionSettings: View {
    @Environment(GatewayManager.self) private var gateway
    @Query private var connections: [GatewayConnection]

    private var saved: GatewayConnection? { connections.first }
    private let runtime = RuntimeConfig.shared

    var body: some View {
        Section("Verbinding") {
            settingRow("Databron", modeLabel)
            settingRow("Gateway", gatewayLabel)
            settingRow("Ontdekt", discoveredGatewayLabel)

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

            settingRow("Kanaal", saved?.channelId ?? "ios-app")
            settingRow("Token", tokenLabel, color: tokenLabel == "Geen token" ? .red : .secondary)
            settingRow("Mock flag", runtime.useMock ? "aan" : "uit")
        }
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
        (gateway.useMock || gateway.host.lowercased() == "mock") ? "Mock" : "Gateway"
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
        return "Niet geconfigureerd"
    }

    private var discoveredGatewayLabel: String {
        if let discovered = gateway.startupGatewayConfigFromFile() {
            let normalized = GatewayManager.normalizeEndpoint(host: discovered.host, port: discovered.port)
            return "\(normalized.host):\(normalized.port)"
        }
        if gateway.startupGatewayFileExists() {
            return "gateway.json gevonden, endpoint onleesbaar"
        }
        return "Geen gateway.json"
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
        return "Geen token"
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
            return "Verbonden"
        case .connecting:
            return "Verbinden..."
        case .reconnecting:
            return "Opnieuw verbinden..."
        case .idle, .disconnected:
            return "Niet verbonden"
        case .failed:
            return tokenLabel == "Geen token" ? "Token ontbreekt" : "Verbinding mislukt"
        }
    }
}
