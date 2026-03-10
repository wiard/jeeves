import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @Query private var connections: [GatewayConnection]
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.96, green: 0.97, blue: 0.99),
                        Color(red: 0.95, green: 0.96, blue: 0.97),
                        Color(red: 0.97, green: 0.96, blue: 0.94)
                    ]
                )
                .ignoresSafeArea()

                List {
                    Section {
                        InstrumentRoleHeader(
                            eyebrow: "Settings",
                            title: "System",
                            summary: "Connection, queue state, and knowledge flow for the Jeeves cockpit.",
                            accent: .jeevesGold,
                            metrics: [
                                InstrumentRoleMetric(label: "Gateway", value: gateway.isConnected ? "Live" : "Idle"),
                                InstrumentRoleMetric(label: "Queue", value: "\(poller.pendingCount)"),
                                InstrumentRoleMetric(label: "Knowledge", value: "\(poller.recentKnowledgeObjects.count)")
                            ]
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }

                    Section {
                        VStack(spacing: 12) {
                            SystemStatusCard(
                                title: "Gateway status",
                                value: gateway.isConnected ? "Healthy" : "Waiting",
                                detail: gatewayStatusDetail,
                                accent: gateway.isConnected ? .green : .orange
                            )

                            SystemStatusCard(
                                title: "Queue",
                                value: "\(poller.pendingCount)",
                                detail: poller.pendingCount == 0 ? "No approvals are waiting." : "Governed decisions are queued for consent.",
                                accent: poller.pendingCount == 0 ? .green : .orange
                            )

                            SystemStatusCard(
                                title: "Knowledge state",
                                value: "\(poller.recentKnowledgeObjects.count)",
                                detail: knowledgeStatusDetail,
                                accent: .blue
                            )
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }

                    ConnectionSettings()
                    SecuritySettings()
                    tokenInfoSection
                    actionsSection
                    displaySection
                    infoSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Jeeves")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var tokenInfoSection: some View {
        Section("Token details") {
            if let conn = connections.first,
               let token = KeychainHelper.load(for: "\(conn.host):\(conn.port)") {
                let decoded = TokenDecoder.decode(token)
                if let decoded {
                    HStack {
                        Text("Scope")
                        Spacer()
                        Text(decoded.scope)
                            .font(.jeevesMono)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Session")
                        Spacer()
                        Text(String(decoded.sessionId.prefix(12)) + "...")
                            .font(.jeevesMono)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Status")
                        Spacer()
                        if decoded.isExpired {
                            Text(TextKeys.Settings.tokenExpired)
                                .font(.jeevesCaption)
                                .foregroundStyle(.red)
                        } else {
                            Text(TextKeys.Settings.tokenValid)
                                .font(.jeevesMono)
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    HStack {
                        Text("Formaat")
                        Spacer()
                        Text("Niet-standaard token")
                            .font(.jeevesMono)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Geen token opgeslagen")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section("Acties") {
            Button {
                testConnection()
            } label: {
                HStack {
                    Text(TextKeys.Settings.testConnection)
                    Spacer()
                    if isTesting {
                        ProgressView()
                    } else if let result = testResult {
                        Text(result)
                            .font(.jeevesMono)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(isTesting)

            Button {
                reseed()
            } label: {
                HStack {
                    Text(TextKeys.Seed.button)
                    Spacer()
                    if poller.isSeeding {
                        ProgressView()
                    }
                }
            }
            .disabled(poller.isSeeding)
        }
    }

    private var displaySection: some View {
        Section("Weergave") {
            HStack {
                Text("Taal")
                Spacer()
                Text("Nederlands")
                    .foregroundStyle(.secondary)
            }

            Toggle("Spraak input", isOn: .constant(true))

            Toggle("Haptic feedback", isOn: .constant(true))

            HStack {
                Text("Donkere modus")
                Spacer()
                Text("Automatisch")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var infoSection: some View {
        Section("Info") {
            HStack {
                Text("Versie")
                Spacer()
                Text("Jeeves v0.1.0")
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Gateway")
                Spacer()
                Text("OpenClashd v2")
                    .font(.jeevesMono)
                    .foregroundStyle(.secondary)
            }

            Text("\"Not Jarvis. Jeeves.\"")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .italic()
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            guard let token = gateway.token else {
                testResult = TextKeys.Settings.disconnected
                isTesting = false
                return
            }
            let client = GatewayClient(host: gateway.host, port: gateway.port, token: token)
            do {
                let proposals = try await client.fetchProposals()
                testResult = "\(proposals.count) \(TextKeys.Settings.proposalsFound)"
            } catch {
                testResult = TextKeys.Settings.disconnected
            }
            isTesting = false
        }
    }

    private func reseed() {
        Task {
            await poller.seedIfNeeded(gateway: gateway, force: true)
        }
    }

    private var gatewayStatusDetail: String {
        guard let connection = connections.first else {
            return "No gateway connection is configured."
        }
        return "\(connection.host):\(connection.port)"
    }

    private var knowledgeStatusDetail: String {
        if let refresh = poller.lastSuccessfulRefreshAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "Last refreshed at \(formatter.string(from: refresh))."
        }
        if let error = poller.lastRefreshError, !error.isEmpty {
            return error
        }
        return "Knowledge objects will appear here as the system observes them."
    }
}

private struct SystemStatusCard: View {
    let title: String
    let value: String
    let detail: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.jeevesHeadline)
                Text(detail)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(value)
                .font(.jeevesMetric)
                .foregroundStyle(accent)
        }
        .briefingPanel()
    }
}

enum TokenDecoder {
    struct DecodedToken {
        let scope: String
        let sessionId: String
        let expiresAt: Date?

        var isExpired: Bool {
            guard let expiresAt else { return false }
            return expiresAt < Date()
        }
    }

    static func decode(_ token: String) -> DecodedToken? {
        let payload: String
        if token.hasPrefix("v1.") {
            payload = String(token.dropFirst(3))
        } else {
            payload = token
        }

        guard let data = Data(base64Encoded: payload) ??
              Data(base64Encoded: padBase64(payload)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let scope = json["scope"] as? String ?? "unknown"
        let sessionId = json["sessionId"] as? String ?? json["session_id"] as? String ?? "unknown"
        let expiresIso = json["expiresAtIso"] as? String ?? json["expires_at"] as? String
        let expiresAt = expiresIso.flatMap { ISO8601DateFormatter().date(from: $0) }

        return DecodedToken(scope: scope, sessionId: sessionId, expiresAt: expiresAt)
    }

    private static func padBase64(_ string: String) -> String {
        let remainder = string.count % 4
        if remainder == 0 { return string }
        return string + String(repeating: "=", count: 4 - remainder)
    }
}
