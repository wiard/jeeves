import Foundation
import Observation

@MainActor
@Observable
final class GatewayManager {

    enum ConnectionState {
        case disconnected
        case connecting
        case reconnecting
        case connected
        case failed

        static var idle: ConnectionState { .disconnected }
    }

    var connectionState: ConnectionState = .disconnected
    var latencyMs: Int?
    var currentStatus: GatewayStatus?

    var useMock: Bool = false
    var host: String = "mock"
    var port: Int = 19001
    var channelId: String = "ios-app"
    private(set) var token: String?

    var isConnected: Bool { connectionState == .connected }

    private let mock = MockGateway()
    private var connectivityTask: Task<Void, Never>?
    private var messageHandler: ((IncomingMessage) -> Void)?
    private let iso8601 = ISO8601DateFormatter()

    func onMessage(_ handler: @escaping (IncomingMessage) -> Void) {
        messageHandler = handler
    }

    func connect(host: String, port: Int, token: String?) {
        connect(host: host, port: port, token: token, channelId: channelId)
    }

    func connect(host: String, port: Int, token: String?, channelId: String) {
        connectivityTask?.cancel()
        connectivityTask = nil

        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedChannel = channelId.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedHost = normalizedHost.isEmpty ? self.host : normalizedHost
        let resolvedPort = port > 0 ? port : self.port
        let resolvedChannel = normalizedChannel.isEmpty ? self.channelId : normalizedChannel

        self.host = resolvedHost
        self.port = resolvedPort
        self.channelId = resolvedChannel
        self.latencyMs = nil

        if useMock || resolvedHost.lowercased() == "mock" {
            self.token = token
            self.connectionState = .connected
            self.currentStatus = mock.mockStatus()
            return
        }

        let key = "\(resolvedHost):\(resolvedPort)"
        let rawToken = (token ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedToken = rawToken.isEmpty ? KeychainHelper.load(for: key) : rawToken

        guard let resolvedToken, !resolvedToken.isEmpty else {
            self.token = nil
            self.connectionState = .failed
            return
        }

        self.token = resolvedToken

        do {
            try KeychainHelper.save(token: resolvedToken, for: key)
        } catch {
            self.connectionState = .failed
            return
        }

        let previous = connectionState
        self.connectionState = (previous == .connected || previous == .reconnecting) ? .reconnecting : .connecting

        connectivityTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshConnectivityAndStatus(host: resolvedHost, port: resolvedPort, token: resolvedToken)
        }
    }

    func disconnect() {
        connectivityTask?.cancel()
        connectivityTask = nil
        connectionState = .disconnected
        latencyMs = nil
        currentStatus = nil
    }

    func fetchStatus() async throws -> GatewayStatus {
        if useMock || host.lowercased() == "mock" {
            let status = mock.mockStatus()
            currentStatus = status
            return status
        }

        let token = try requireToken()
        let state = try await ConductorAPI.state(host: host, port: port, token: token)

        let status = GatewayStatus(
            budget: BudgetStatus(
                daily: BudgetPeriod(used: 0, limit: state.budget.remaining),
                weekly: BudgetPeriod(used: 0, limit: state.budget.remaining),
                monthly: BudgetPeriod(used: 0, limit: state.budget.remaining),
                hardStop: state.budget.hardStop
            ),
            consent: ConsentStatus(pending: state.consentPending, active: 0),
            killSwitch: KillSwitchStatus(active: state.killSwitch.active),
            channels: [
                ChannelInfo(id: channelId, trust: .trusted, connected: true)
            ]
        )

        currentStatus = status
        return status
    }

    func fetchAudit(period: AuditPeriod) async throws -> [AuditEntry] {
        if useMock || host.lowercased() == "mock" {
            return mock.mockAuditEntries()
        }

        let token = try requireToken()
        let remotePeriod: String
        switch period {
        case .today:
            remotePeriod = "daily"
        case .week:
            remotePeriod = "weekly"
        case .month:
            remotePeriod = "monthly"
        }

        let events = try await ConductorAPI.audit(host: host, port: port, token: token, period: remotePeriod)

        return events.enumerated().map { index, event in
            let timestampString = event.timestamp ?? ""
            let date = iso8601.date(from: timestampString) ?? Date()

            let statusValue: AuditStatus
            let decision = (event.decision ?? event.status ?? "").lowercased()
            switch decision {
            case "block", "blocked", "deny", "denied":
                statusValue = .blocked
            case "consent", "consent_requested", "pending":
                statusValue = .consentRequested
            default:
                statusValue = .allowed
            }

            let toolName = event.toolName ?? event.event ?? "unknown"

            return AuditEntry(
                id: event.id ?? "audit-\(index)-\(timestampString)",
                timestamp: date,
                tool: toolName,
                status: statusValue,
                channel: event.channel ?? channelId,
                reason: event.reason,
                cost: event.cost,
                params: event.params
            )
        }
    }

    func activateKillSwitch(reason: String) async throws {
        if useMock || host.lowercased() == "mock" {
            var status = currentStatus ?? mock.mockStatus()
            status.killSwitch.active = true
            currentStatus = status
            return
        }

        let token = try requireToken()
        try await ConductorAPI.killActivate(host: host, port: port, token: token, reason: reason)
        _ = try? await fetchStatus()
    }

    func deactivateKillSwitch() async throws {
        if useMock || host.lowercased() == "mock" {
            var status = currentStatus ?? mock.mockStatus()
            status.killSwitch.active = false
            currentStatus = status
            return
        }

        let token = try requireToken()
        try await ConductorAPI.killDeactivate(host: host, port: port, token: token)
        _ = try? await fetchStatus()
    }

    func send(text: String) async throws {
        if useMock || host.lowercased() == "mock" {
            let messages = await mock.simulateResponse(for: text)
            messages.forEach { handleIncoming($0) }
            return
        }

        let token = try requireToken()
        let body = try JSONEncoder().encode(OutgoingMessage.chat(text: text, channelId: channelId))
        let response = try await ConductorAPI.postIntent(host: host, port: port, token: token, body: body)

        if let incoming = IncomingMessageDecoder.decode(from: response) {
            handleIncoming(incoming)
        }
    }

    func respondToConsent(id: String, approved: Bool, tool: String? = nil) async throws {
        if useMock || host.lowercased() == "mock" {
            guard approved, let tool else { return }
            let response = await mock.simulateConsentApproval(tool: tool)
            handleIncoming(response)
            return
        }

        let token = try requireToken()
        let body = try JSONEncoder().encode(ConsentResponseMessage(id: id, approved: approved))
        let response = try await ConductorAPI.postIntent(host: host, port: port, token: token, body: body)

        if let incoming = IncomingMessageDecoder.decode(from: response) {
            handleIncoming(incoming)
        }
    }

    private func refreshConnectivityAndStatus(host: String, port: Int, token: String) async {
        let startedNs = DispatchTime.now().uptimeNanoseconds

        do {
            let health = try await ConductorAPI.health(host: host, port: port, token: token)
            let elapsedMs = Int((DispatchTime.now().uptimeNanoseconds - startedNs) / 1_000_000)
            latencyMs = health.responseTimeMs ?? elapsedMs
            connectionState = health.ok ? .connected : .failed

            if health.ok {
                _ = try? await fetchStatus()
            }
        } catch {
            latencyMs = nil
            connectionState = .failed
        }
    }

    private func requireToken() throws -> String {
        if let token, !token.isEmpty {
            return token
        }

        if let stored = KeychainHelper.load(for: "\(host):\(port)"), !stored.isEmpty {
            self.token = stored
            return stored
        }

        throw NSError(domain: "Gateway", code: 401, userInfo: [NSLocalizedDescriptionKey: "Missing token"])
    }

    private func handleIncoming(_ message: IncomingMessage) {
        if case .status(let status) = message {
            currentStatus = status
        }
        messageHandler?(message)
    }
}
