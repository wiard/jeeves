import Foundation

// MARK: - Capability Kind

/// The four kinds of operator capability Jeeves can perform.
enum JeevesCapabilityKind: String, Sendable, CaseIterable {
    /// Open or focus a screen.
    case navigation
    /// Read system state without side effects.
    case inspection
    /// Explain what Jeeves sees or recommends.
    case explanation
    /// Trigger a kernel action through the governed gateway.
    case governedAction
}

// MARK: - Capability Mode

/// Current operational status of a capability.
enum JeevesCapabilityMode: String, Sendable {
    /// Active, read-only safe.
    case readOnly
    /// Active, requires governance approval.
    case governed
    /// Temporarily disabled.
    case disabled
    /// Designed but not yet implemented.
    case planned
}

// MARK: - Capability

/// A single explicit operator capability.
///
/// Capabilities are the formal contract of what Jeeves can do.
/// Every orchestrator action must map to a registered capability.
/// Capabilities never bypass governance or gateway routing.
struct JeevesCapability: Sendable, Identifiable {
    let id: String
    let title: String
    let kind: JeevesCapabilityKind
    let targetScreen: AppScreen?
    let requiresGateway: Bool
    let requiresGovernance: Bool
    let mode: JeevesCapabilityMode
    let commandAliases: [String]

    /// Whether this capability is safe to execute without approval.
    var isReadOnly: Bool {
        kind == .navigation || kind == .inspection || kind == .explanation
    }
}
