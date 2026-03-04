import SwiftUI
import SwiftData

struct ConnectionSettings: View {
    @Environment(GatewayManager.self) private var gateway
    @Query private var connections: [GatewayConnection]

    private var saved: GatewayConnection? { connections.first }
    private let runtime = RuntimeConfig.shared

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 0) {



            HStack {
                Text("Gateway")
                Spacer()
                Text(gatewayLabel)
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
            }

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
                HStack {
                    Text("Latency")
                    Spacer()
                    Text("\(latency)ms")
                        .font(.jeevesMono)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Kanaal")
                Spacer()
                Text(saved?.channelId ?? "ios-app")
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
            }

            Section("Beveiliging") {
                HStack {
                    Text("Token")
                    Spacer()
                    Text(tokenLabel)
                        .font(.jeevesMono)
                        .foregroundStyle(tokenLabel == "Geen token" ? .red : .secondary)
                }

                HStack {
                    Text("Mock")
                    Spacer()
                    Text(runtime.useMock ? "aan" : "uit")
                        .font(.jeevesMono)
                        .foregroundStyle(.secondary)
                }
            }
        
            }
        } header: {
            Text("Verbinding")
        }
    }

    private var gatewayLabel: String {
        // 1) toon runtime als die er is (dit is je “echte” run)
        if let h = runtime.host, let p = runtime.port {
            return "\(h):\(p)"
        }
        // 2) anders toon wat in DB staat
        if let c = saved {
            return "\(c.host):\(c.port)"
        }
        return "Niet geconfigureerd"
    }

    private var tokenLabel: String {
        // 1) runtime token (ENV of /tmp file)
        if let t = runtime.token, !t.isEmpty {
            return "\(t.prefix(10))…"
        }
        // 2) keychain fallback
        if let h = saved?.host, let p = saved?.port,
           let t = KeychainHelper.load(for: "\(h):\(p)"),
           !t.isEmpty, t != "mock" {
            return "\(t.prefix(10))…"
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
        case .connected: "Verbonden"
        case .connecting: "Verbinden..."
        case .reconnecting: "Opnieuw verbinden..."
        case .idle, .disconnected: "Niet verbonden"
        case .failed: "Verbinding mislukt"
        }
    }
}
