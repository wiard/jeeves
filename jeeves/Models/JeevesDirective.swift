import Foundation

// MARK: - Intent classification

enum JeevesIntent: Sendable {
    case browse(domain: String?, subdomain: String?, risk: String?)
    case inspectSystem(aspect: SystemAspect?)
    case reviewPending
    case searchAudit(query: String?)
    case checkRadar
    case viewFabric
    case viewKnowledge
    case manageExtensions
    case conversational(text: String)

    enum SystemAspect: String, Sendable {
        case pressure, health, budget, consent, killSwitch, signals, emergence
    }

    var isConversational: Bool {
        if case .conversational = self { return true }
        return false
    }
}

// MARK: - Screen state preset

/// Tells the target screen what state to apply before showing.
struct ScreenStatePreset: Sendable {
    var browserSection: String?
    var browserDomain: String?
    var browserSubdomain: String?
    var observatorySection: String?
    var auditPeriod: String?
    var auditFilter: String?

    static let empty = ScreenStatePreset()
}

// MARK: - Screen capability descriptor

struct ScreenCapability: Sendable {
    let screen: AppScreen
    let keywords: Set<String>
    let domains: Set<String>
    let sections: [String]
    let supportedFilters: Set<String>
}

// MARK: - Directive (orchestrator output)

struct JeevesDirective: Sendable, Equatable {
    let intent: String
    let destination: AppScreen
    let section: String?
    let statePreset: ScreenStatePreset
    let explanation: String
    let reason: String
    let confidence: Double

    static func == (lhs: JeevesDirective, rhs: JeevesDirective) -> Bool {
        lhs.destination == rhs.destination
            && lhs.section == rhs.section
            && lhs.explanation == rhs.explanation
            && lhs.intent == rhs.intent
    }
}

extension ScreenStatePreset: Equatable {}
