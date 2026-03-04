import Foundation
import Combine

@MainActor
final class ObservatoryViewModel: ObservableObject {
    enum Section: CaseIterable {
        case loop
        case fabric
        case lobby
        case signals
        case knowledge
        case alerts
    }

    enum SectionStatus: Equatable {
        case ok
        case unavailable
    }

    @Published var snapshot: ObservatoryDashboardSnapshot?
    @Published var isLoading = false
    @Published var errorText: String?

    private var sectionStatuses: [Section: SectionStatus] = {
        var statuses: [Section: SectionStatus] = [:]
        for section in Section.allCases {
            statuses[section] = .unavailable
        }
        return statuses
    }()

    func status(for section: Section) -> SectionStatus {
        sectionStatuses[section] ?? .unavailable
    }

    func refresh(gateway: GatewayManager, connection: GatewayConnection?) async {
        isLoading = true
        errorText = nil

        let resolvedHost = resolveHost(gateway: gateway, connection: connection)
        let resolvedPort = resolvePort(gateway: gateway, connection: connection)
        let resolvedToken = resolveToken(host: resolvedHost, port: resolvedPort, gateway: gateway)

        guard let token = resolvedToken, !token.isEmpty else {
            snapshot = nil
            markAllUnavailable()
            errorText = "Missing token"
            isLoading = false
            return
        }

        var conductor: ConductorState?
        var alerts: [ObservatoryAlert] = []
        var fabricClock: FabricClockState?
        var fabricEmergence: FabricEmergence?
        var challenges: [LobbyChallenge] = []
        var signals: SignalsState?
        var knowledgeStatus: KnowledgeStatus?
        var knowledgeEmergence: KnowledgeEmergence?

        var hasConductor = false
        var hasAlerts = false
        var hasFabric = false
        var hasLobby = false
        var hasSignals = false
        var hasKnowledge = false

        do {
            conductor = try await ObservatoryAPI.conductorState(host: resolvedHost, port: resolvedPort, token: token)
            hasConductor = true
        } catch {}

        do {
            alerts = try await ObservatoryAPI.observatoryAlerts(host: resolvedHost, port: resolvedPort, token: token)
            hasAlerts = true
        } catch {}

        do {
            fabricClock = try await ObservatoryAPI.fabricClock(host: resolvedHost, port: resolvedPort, token: token)
            hasFabric = true
        } catch {}

        do {
            fabricEmergence = try await ObservatoryAPI.fabricEmergence(host: resolvedHost, port: resolvedPort, token: token)
            hasFabric = true
        } catch {}

        do {
            challenges = try await ObservatoryAPI.lobbyChallenges(host: resolvedHost, port: resolvedPort, token: token)
            hasLobby = true
        } catch {}

        do {
            signals = try await ObservatoryAPI.signalsState(host: resolvedHost, port: resolvedPort, token: token)
            hasSignals = true
        } catch {}

        do {
            knowledgeStatus = try await ObservatoryAPI.knowledgeStatus(host: resolvedHost, port: resolvedPort, token: token)
            hasKnowledge = true
        } catch {}

        do {
            knowledgeEmergence = try await ObservatoryAPI.knowledgeEmergence(host: resolvedHost, port: resolvedPort, token: token)
            hasKnowledge = true
        } catch {}

        let sortedAlerts = Self.sortAlerts(alerts)
        let sortedChallenges = Self.sortChallenges(challenges)
            .filter { ($0.status ?? "").lowercased() == "open" || $0.status == nil }
        let sortedEmergence = knowledgeEmergence.map { Self.sortKnowledgeEmergence($0) }

        snapshot = ObservatoryDashboardSnapshot(
            conductor: conductor,
            alerts: sortedAlerts,
            fabricClock: fabricClock,
            fabricEmergence: fabricEmergence,
            lobbyOpenChallenges: sortedChallenges,
            signals: signals,
            knowledgeStatus: knowledgeStatus,
            knowledgeEmergence: sortedEmergence,
            fetchedAt: Date()
        )

        sectionStatuses[.loop] = hasConductor ? .ok : .unavailable
        sectionStatuses[.fabric] = hasFabric ? .ok : .unavailable
        sectionStatuses[.lobby] = hasLobby ? .ok : .unavailable
        sectionStatuses[.signals] = hasSignals ? .ok : .unavailable
        sectionStatuses[.knowledge] = hasKnowledge ? .ok : .unavailable
        sectionStatuses[.alerts] = hasAlerts ? .ok : .unavailable

        isLoading = false
    }

    nonisolated static func sortAlerts(_ alerts: [ObservatoryAlert]) -> [ObservatoryAlert] {
        alerts.sorted { lhs, rhs in
            let lDate = parsedIso(lhs.timestampIso)
            let rDate = parsedIso(rhs.timestampIso)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.id < rhs.id
        }
    }

    nonisolated static func sortChallenges(_ challenges: [LobbyChallenge]) -> [LobbyChallenge] {
        challenges.sorted { lhs, rhs in
            let lDate = parsedIso(lhs.createdAtIso)
            let rDate = parsedIso(rhs.createdAtIso)
            if lDate != rDate {
                return lDate > rDate
            }
            return lhs.id < rhs.id
        }
    }

    nonisolated static func sortKnowledgeEmergence(_ emergence: KnowledgeEmergence) -> KnowledgeEmergence {
        let sorted = emergence.clusters.sorted { lhs, rhs in
            let lScore = lhs.score ?? 0
            let rScore = rhs.score ?? 0
            if lScore != rScore {
                return lScore > rScore
            }
            return lhs.id < rhs.id
        }
        return KnowledgeEmergence(clusters: sorted)
    }

    private func resolveHost(gateway: GatewayManager, connection: GatewayConnection?) -> String {
        let runtimeHost = RuntimeConfig.shared.host?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let runtimeHost, !runtimeHost.isEmpty {
            return runtimeHost
        }

        if let connectionHost = connection?.host.trimmingCharacters(in: .whitespacesAndNewlines),
           !connectionHost.isEmpty {
            return connectionHost
        }

        let gatewayHost = gateway.host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !gatewayHost.isEmpty, gatewayHost.lowercased() != "mock" {
            return gatewayHost
        }

        return "localhost"
    }

    private func resolvePort(gateway: GatewayManager, connection: GatewayConnection?) -> Int {
        if let runtimePort = RuntimeConfig.shared.port, runtimePort > 0 {
            return runtimePort
        }
        if let connectionPort = connection?.port, connectionPort > 0 {
            return connectionPort
        }
        if gateway.port > 0 {
            return gateway.port
        }
        return 19001
    }

    private func resolveToken(host: String, port: Int, gateway: GatewayManager) -> String? {
        if let runtimeToken = RuntimeConfig.shared.token?.trimmingCharacters(in: .whitespacesAndNewlines),
           !runtimeToken.isEmpty {
            return runtimeToken
        }

        if let stored = KeychainHelper.load(for: "\(host):\(port)"), !stored.isEmpty {
            return stored
        }

        if let gatewayToken = gateway.token?.trimmingCharacters(in: .whitespacesAndNewlines),
           !gatewayToken.isEmpty {
            return gatewayToken
        }

        return nil
    }

    private func markAllUnavailable() {
        for section in Section.allCases {
            sectionStatuses[section] = .unavailable
        }
    }

    nonisolated private static func parsedIso(_ value: String?) -> Date {
        guard let value else { return .distantPast }
        return ISO8601DateFormatter().date(from: value) ?? .distantPast
    }
}
