import SwiftUI
import SwiftData

struct SecuritySettings: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(GatewayManager.self) private var gateway
    @Query private var connections: [GatewayConnection]
    @State private var showDeleteConfirmation = false
    @State private var showRefreshConfirmation = false
    @State private var tokenInput = ""
    @State private var tokenStatus: String?

    private var connection: GatewayConnection? { connections.first }
    private var hasToken: Bool {
        guard let conn = connection else { return false }
        return KeychainHelper.load(for: "\(conn.host):\(conn.port)") != nil
    }

    var body: some View {
        Section("Beveiliging") {
            HStack {
                Text("Token")
                Spacer()
                if hasToken {
                    Text("●●●●●●●● (Keychain)")
                        .font(.jeevesMono)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Geen token")
                    .foregroundStyle(Color.consentRed)
                }
            }

            if connection != nil {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Plak operator token", text: $tokenInput, axis: .vertical)
                        .font(.jeevesMono)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    Button("Opslaan en verbinden") {
                        saveTokenAndReconnect()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let tokenStatus, !tokenStatus.isEmpty {
                        Text(tokenStatus)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if hasToken {
                Button("Vernieuw token") {
                    showRefreshConfirmation = true
                }
                .alert("Token vernieuwen?", isPresented: $showRefreshConfirmation) {
                    Button("Vernieuw", role: .destructive) { refreshToken() }
                    Button("Annuleren", role: .cancel) {}
                } message: {
                    Text("Het huidige token wordt ongeldig. U moet opnieuw verbinden met de gateway.")
                }

                Button("Verwijder token", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .alert("Token verwijderen?", isPresented: $showDeleteConfirmation) {
                    Button("Verwijder", role: .destructive) { deleteToken() }
                    Button("Annuleren", role: .cancel) {}
                } message: {
                    Text("U verliest de verbinding met de gateway en moet opnieuw configureren.")
                }
            }

            HStack {
                Text("Trust level")
                Spacer()
                Text("trusted")
                    .font(.jeevesMono)
                    .foregroundStyle(Color.consentGreen)
            }
        }
    }

    private func refreshToken() {
        tokenStatus = "Token vernieuwen via gateway CLI en opnieuw opslaan."
    }

    private func deleteToken() {
        guard let conn = connection else { return }
        try? KeychainHelper.delete(for: "\(conn.host):\(conn.port)")
        tokenStatus = "Token verwijderd"
    }

    private func saveTokenAndReconnect() {
        guard let conn = connection else { return }
        let normalizedToken = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else { return }

        var keys = Set<String>()
        keys.insert("\(conn.host):\(conn.port)")

        let normalizedHost = conn.host.lowercased()
        if normalizedHost == "localhost" || normalizedHost == "127.0.0.1" {
            for host in ["localhost", "127.0.0.1"] {
                for port in GatewayManager.localDiscoveryPorts {
                    keys.insert("\(host):\(port)")
                }
            }
        }

        if gateway.host.lowercased() != "mock", gateway.port > 0 {
            keys.insert("\(gateway.host):\(gateway.port)")
        }

        do {
            for key in keys.sorted() {
                try KeychainHelper.save(token: normalizedToken, for: key)
            }
            gateway.useMock = false
            let reconnectHost = gateway.host.lowercased() == "mock" ? conn.host : gateway.host
            let reconnectPort = gateway.port > 0 ? gateway.port : conn.port
            gateway.connect(
                host: reconnectHost,
                port: reconnectPort,
                token: normalizedToken,
                channelId: conn.channelId
            )
            tokenStatus = "Token opgeslagen en live verbinding gestart."
            tokenInput = ""
        } catch {
            tokenStatus = "Token opslaan mislukt."
        }
    }
}
