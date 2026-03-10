import Foundation

/// Operator-visible execution class for a capability.
enum JeevesExecutionClass: String, Sendable {
    case readOnly
    case governed
    case destructive
}

/// Compact evidence origin hint used in operator explanations.
struct JeevesEvidenceHint: Sendable {
    let source: String
    let detail: String
}

/// Execution-awareness flags for operator safety context.
struct JeevesExecutionAwareness: Sendable {
    let executionClass: JeevesExecutionClass
    let touchesMoney: Bool
    let securityRelated: Bool
}

/// Action hint tied to a capability's current policy/evaluation state.
struct JeevesOperatorActionHint: Sendable {
    let action: String
    let reason: String
}

/// Compact capability summary enriched with policy and execution awareness.
struct JeevesCapabilitySummary: Sendable {
    let capability: JeevesCapability
    let policyDecision: JeevesPolicyDecision
    let execution: JeevesExecutionAwareness
    let evidence: [JeevesEvidenceHint]
    let nextAction: JeevesOperatorActionHint
}

/// Operator-facing explanation payload for one capability summary.
struct JeevesCapabilityExplanation: Sendable {
    let summary: JeevesCapabilitySummary
    let headline: String
    let lines: [String]
}
