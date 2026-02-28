import Foundation

struct AuditEntry: Identifiable, Sendable {
    var id: String
    var timestamp: Date
    var tool: String
    var status: AuditStatus
    var channel: String
    var reason: String?
    var cost: Double?
    var params: [String: String]?
}

enum AuditStatus: String, Sendable {
    case allowed, consentRequested, blocked
}

enum AuditPeriod: String, CaseIterable, Sendable {
    case today = "Vandaag"
    case week = "Week"
    case month = "Maand"
}

enum AuditFilter: String, CaseIterable, Sendable {
    case all = "Alle"
    case blocked = "Geblokkeerd"
    case costs = "Kosten"
}
