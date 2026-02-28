import SwiftUI
import SwiftData

struct ConnectionSettings: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [GatewayConnection]

    private var connection: GatewayConnection? { connections.first }

    var body: some View {
        Section("Verbinding") {
            HStack {
                Text("Gateway")
                Spacer()
                Text(connection.map { "\($0.host):\($0.port)" } ?? "Niet geconfigureerd")
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
                Text(connection?.channelId ?? "ios-app")
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusColor: Color {
        switch gateway.connectionState {
        case .connected: .consentGreen
        case .connecting, .reconnecting: .consentOrange
        case .disconnected: .consentRed
        }
    }

    private var statusText: String {
        switch gateway.connectionState {
        case .connected: "Verbonden"
        case .connecting: "Verbinden..."
        case .reconnecting: "Opnieuw verbinden..."
        case .disconnected: "Niet verbonden"
        }
    }
}
