import Foundation

// MARK: - Policy Mode

/// The outcome of a policy evaluation.
enum JeevesPolicyMode: String, Sendable {
    /// Capability is allowed and safe to execute.
    case allowed
    /// Capability is restricted to read-only operations.
    case readOnlyOnly
    /// Capability requires explicit operator approval before execution.
    case requiresApproval
    /// Capability can only generate a proposal, not execute directly.
    case proposalOnly
    /// Capability is blocked in the current state.
    case blocked
    /// Capability is designed but not yet implemented.
    case planned
}

// MARK: - Policy Decision

/// The result of evaluating a capability against the policy layer.
///
/// Contains the decision mode, a machine-readable reason, and
/// a human-readable operator message (in Dutch).
struct JeevesPolicyDecision: Sendable {
    let mode: JeevesPolicyMode
    let reason: String
    let operatorMessage: String
}

// MARK: - Policy Layer

/// Deterministic, local policy evaluation for Jeeves capabilities.
///
/// The policy layer classifies whether a capability is safe to route.
/// It does not execute actions, bypass governance, or contact the backend.
/// All rules are explicit and deterministic.
///
/// Rules (in order):
/// 1. Planned capabilities → planned (not yet available)
/// 2. Disabled capabilities → blocked
/// 3. Read-only capabilities (navigation, inspection, explanation) → allowed
/// 4. Governed capabilities → requiresApproval (never executed directly)
enum JeevesPolicyLayer {

    /// Evaluate a capability and return a policy decision.
    static func evaluate(capability: JeevesCapability) -> JeevesPolicyDecision {
        // Rule 1: planned capabilities are not yet available
        if capability.mode == .planned {
            return JeevesPolicyDecision(
                mode: .planned,
                reason: "capability_planned",
                operatorMessage: "\(capability.title) is nog niet beschikbaar."
            )
        }

        // Rule 2: disabled capabilities are blocked
        if capability.mode == .disabled {
            return JeevesPolicyDecision(
                mode: .blocked,
                reason: "capability_disabled",
                operatorMessage: "\(capability.title) is momenteel uitgeschakeld."
            )
        }

        // Rule 3: read-only capabilities are always allowed
        if capability.isReadOnly {
            return JeevesPolicyDecision(
                mode: .allowed,
                reason: "read_only",
                operatorMessage: ""
            )
        }

        // Rule 4: governed capabilities require approval
        if capability.requiresGovernance {
            return JeevesPolicyDecision(
                mode: .requiresApproval,
                reason: "requires_governance",
                operatorMessage: "\(capability.title) vereist goedkeuring via het governance-systeem."
            )
        }

        // Fallback: allow
        return JeevesPolicyDecision(
            mode: .allowed,
            reason: "default_allow",
            operatorMessage: ""
        )
    }
}
