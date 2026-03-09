import Foundation

/// Compact session state included in a deterministic decision trace.
struct JeevesDecisionSessionSummary: Sendable, Equatable {
    let currentScreen: AppScreen
    let missionFocus: String?
    let browserDomain: String?
    let recentScreens: [AppScreen]
}

/// Explicit, inspectable trace of one Jeeves routing/recommendation decision.
struct JeevesDecisionTrace: Sendable, Equatable {
    let originalInput: String
    let matchedCommand: String?
    let matchedGuidanceKind: String?
    let matchedCapabilityId: String?
    let policyMode: JeevesPolicyMode?
    let policyReason: String?
    let sessionSummary: JeevesDecisionSessionSummary
    let recommendationReason: String?
    let finalDirectiveIntent: String
    let finalScreen: AppScreen
    let finalSection: String?
    let nextActions: [String]
}
