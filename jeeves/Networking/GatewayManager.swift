import Foundation
import SwiftUI
import SwiftData

enum ConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

@MainActor
@Observable
final class GatewayManager {
    var connectionState: ConnectionState = .disconnected
    var currentStatus: GatewayStatus?
    var latencyMs: Int?

    // Mock mode for development
    var useMock: Bool = true

    private var webSocketTask: URLSessionWebSocketTask?
    private var messageHandler: ((IncomingMessage) -> Void)?
    private var reconnectDelay: TimeInterval = 1.0
    private var maxReconnectAttempts = 5
    private var reconnectAttempts = 0
    private var heartbeatTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var host: String = ""
    private var port: Int = 19001
    private var token: String = ""
    private var channelId: String = "ios-app"

    private let mockGateway = MockGateway()

    var isConnected: Bool { connectionState == .connected }

    func onMessage(_ handler: @escaping (IncomingMessage) -> Void) {
        self.messageHandler = handler
    }

    // MARK: - Connection

    func connect(host: String, port: Int, token: String, channelId: String = "ios-app") {
        // Clean up any existing connection
        disconnect()

        self.host = host
        self.port = port
        self.token = token
        self.channelId = channelId

        if useMock {
            connectionState = .connected
            currentStatus = mockGateway.mockStatus()
            return
        }

        connectionState = .connecting

        guard let url = URL(string: "ws://\(host):\(port)/ws/ios-app") else {
            connectionState = .disconnected
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        // Don't set .connected until we successfully receive a message
        // startReceiving will handle the state transition
        reconnectDelay = 1.0
        reconnectAttempts = 0

        startReceiving()
        startHeartbeat()
    }

    func disconnect() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
    }

    // MARK: - Sending

    func send(text: String) async throws {
        if useMock {
            let messages = await mockGateway.simulateResponse(for: text)
            for msg in messages {
                messageHandler?(msg)
            }
            return
        }

        let message = OutgoingMessage.chat(text: text, channelId: channelId)
        let data = try JSONEncoder().encode(message)
        guard let jsonString = String(data: data, encoding: .utf8) else { return }
        try await webSocketTask?.send(.string(jsonString))
    }

    func respondToConsent(id: String, approved: Bool, tool: String? = nil) async throws {
        if useMock {
            if approved, let tool = tool {
                let response = await mockGateway.simulateConsentApproval(tool: tool)
                messageHandler?(response)
            }
            return
        }

        let response = ConsentResponseMessage(id: id, approved: approved)
        let data = try JSONEncoder().encode(response)
        guard let jsonString = String(data: data, encoding: .utf8) else { return }
        try await webSocketTask?.send(.string(jsonString))
    }

    func fetchStatus() async throws -> GatewayStatus {
        if useMock {
            let status = mockGateway.mockStatus()
            currentStatus = status
            return status
        }

        if let status = currentStatus {
            return status
        }
        throw GatewayError.notConnected
    }

    func fetchAudit(period: AuditPeriod) async throws -> [AuditEntry] {
        if useMock {
            return mockGateway.mockAuditEntries()
        }

        throw GatewayError.notConnected
    }

    func activateKillSwitch(reason: String) async throws {
        if useMock {
            currentStatus?.killSwitch = KillSwitchStatus(active: true)
            return
        }

        throw GatewayError.notConnected
    }

    func deactivateKillSwitch() async throws {
        if useMock {
            currentStatus?.killSwitch = KillSwitchStatus(active: false)
            return
        }

        throw GatewayError.notConnected
    }

    // MARK: - Receiving

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                do {
                    guard let message = try await self.webSocketTask?.receive() else { return }
                    await MainActor.run {
                        // First successful receive means we're connected
                        if self.connectionState != .connected {
                            self.connectionState = .connected
                            self.reconnectAttempts = 0
                        }
                    }
                    switch message {
                    case .string(let text):
                        if let data = text.data(using: .utf8),
                           let incoming = IncomingMessageDecoder.decode(from: data) {
                            await MainActor.run {
                                self.handleMessage(incoming)
                            }
                        }
                    case .data(let data):
                        if let incoming = IncomingMessageDecoder.decode(from: data) {
                            await MainActor.run {
                                self.handleMessage(incoming)
                            }
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.handleDisconnect()
                        }
                    }
                    return
                }
            }
        }
    }

    private func handleMessage(_ message: IncomingMessage) {
        if case .status(let status) = message {
            currentStatus = status
        }
        messageHandler?(message)
    }

    private func handleDisconnect() {
        guard connectionState != .disconnected else { return }
        connectionState = .reconnecting
        scheduleReconnect()
    }

    // MARK: - Reconnect

    private func scheduleReconnect() {
        reconnectAttempts += 1
        guard reconnectAttempts <= maxReconnectAttempts else {
            connectionState = .disconnected
            return
        }

        Task {
            try? await Task.sleep(for: .seconds(reconnectDelay))
            reconnectDelay = min(reconnectDelay * 2, 30.0)
            guard connectionState == .reconnecting else { return }
            connect(host: host, port: port, token: token, channelId: channelId)
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self = self else { return }
                let ping = #"{"type":"ping"}"#
                try? await self.webSocketTask?.send(.string(ping))
            }
        }
    }
}

enum GatewayError: Error, LocalizedError {
    case notConnected
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConnected: "Niet verbonden met de gateway"
        case .invalidResponse: "Ongeldig antwoord van de gateway"
        }
    }
}
