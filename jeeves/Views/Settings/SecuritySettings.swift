import SwiftUI
import SwiftData

struct SecuritySettings: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var connections: [GatewayConnection]
    @State private var showDeleteConfirmation = false
    @State private var showRefreshConfirmation = false

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
        // In real implementation: request new token from gateway
    }

    private func deleteToken() {
        guard let conn = connection else { return }
        try? KeychainHelper.delete(for: "\(conn.host):\(conn.port)")
    }
}
