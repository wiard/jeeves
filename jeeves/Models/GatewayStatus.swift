import Foundation

struct GatewayStatus: Sendable {
    var budget: BudgetStatus
    var consent: ConsentStatus
    var killSwitch: KillSwitchStatus
    var channels: [ChannelInfo]
}

struct BudgetStatus: Sendable {
    var daily: BudgetPeriod
    var weekly: BudgetPeriod
    var monthly: BudgetPeriod
    var hardStop: Bool
}

struct BudgetPeriod: Sendable {
    var used: Double
    var limit: Double

    var ratio: Double {
        guard limit > 0 else { return 0 }
        return used / limit
    }
}

struct ConsentStatus: Sendable {
    var pending: Int
    var active: Int
}

struct KillSwitchStatus: Sendable {
    var active: Bool
}

struct ChannelInfo: Identifiable, Sendable {
    var id: String
    var trust: TrustLevel
    var connected: Bool
}

enum TrustLevel: String, Codable, Sendable {
    case trusted, semi, untrusted
}
