import Foundation

/// Static catalog of all known Jeeves operator capabilities.
///
/// The registry is the single source of truth for what Jeeves can do.
/// Every capability is explicit, inspectable, and governance-compatible.
/// No backend behavior exists without a matching registered capability.
enum JeevesCapabilityRegistry {

    // MARK: - Lookup

    /// Find a capability by ID.
    static func capability(for id: String) -> JeevesCapability? {
        catalog.first { $0.id == id }
    }

    /// All capabilities targeting a specific screen.
    static func capabilities(for screen: AppScreen) -> [JeevesCapability] {
        catalog.filter { $0.targetScreen == screen }
    }

    /// Find the capability implied by a directive.
    static func resolve(directive: JeevesDirective) -> JeevesCapability? {
        let intent = directive.intent

        // Direct intent prefix match
        for (prefix, capId) in intentMap {
            if intent.hasPrefix(prefix) {
                return capability(for: capId)
            }
        }

        // Command/follow-up: match by destination screen
        if intent.hasPrefix("command:") || intent.hasPrefix("followUp:") {
            return catalog.first {
                $0.targetScreen == directive.destination && $0.kind == .navigation
            }
        }

        return nil
    }

    /// All registered capabilities.
    static var allCapabilities: [JeevesCapability] { catalog }

    // MARK: - Intent → Capability mapping

    private static let intentMap: [String: String] = [
        "browse":            "open_browser",
        "checkRadar":        "inspect_radar",
        "viewFabric":        "inspect_fabric",
        "viewKnowledge":     "inspect_knowledge",
        "inspectSystem":     "inspect_system",
        "reviewPending":     "inspect_approvals",
        "searchAudit":       "inspect_audit",
        "manageExtensions":  "open_lobby",
        "guidance:":         "explain_focus",
    ]

    // MARK: - Catalog

    private static let catalog: [JeevesCapability] = [

        // — Navigation —

        JeevesCapability(
            id: "open_browser",
            title: "Open AI Browser",
            kind: .navigation,
            targetScreen: .aiBrowser,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["browser", "marketplace"]
        ),
        JeevesCapability(
            id: "open_observatory",
            title: "Open Observatory",
            kind: .navigation,
            targetScreen: .observatory,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["observatory"]
        ),
        JeevesCapability(
            id: "open_stream",
            title: "Open Mission Control",
            kind: .navigation,
            targetScreen: .stream,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["stream", "mission-control"]
        ),
        JeevesCapability(
            id: "open_house",
            title: "Open Huis",
            kind: .navigation,
            targetScreen: .house,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["house", "huis"]
        ),
        JeevesCapability(
            id: "open_logbook",
            title: "Open Logboek",
            kind: .navigation,
            targetScreen: .logbook,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["logbook", "logboek", "audit"]
        ),
        JeevesCapability(
            id: "open_lobby",
            title: "Open Lobby",
            kind: .navigation,
            targetScreen: .lobby,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["lobby", "extensions"]
        ),
        JeevesCapability(
            id: "open_settings",
            title: "Open Instellingen",
            kind: .navigation,
            targetScreen: .settings,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["settings", "instellingen"]
        ),

        // — Inspection —

        JeevesCapability(
            id: "inspect_radar",
            title: "Inspecteer Radar",
            kind: .inspection,
            targetScreen: .observatory,
            requiresGateway: true,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["radar"]
        ),
        JeevesCapability(
            id: "inspect_fabric",
            title: "Inspecteer Fabric",
            kind: .inspection,
            targetScreen: .observatory,
            requiresGateway: true,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["fabric"]
        ),
        JeevesCapability(
            id: "inspect_knowledge",
            title: "Inspecteer Knowledge",
            kind: .inspection,
            targetScreen: .observatory,
            requiresGateway: true,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["knowledge", "kennis"]
        ),
        JeevesCapability(
            id: "inspect_system",
            title: "Inspecteer Systeem",
            kind: .inspection,
            targetScreen: .house,
            requiresGateway: true,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["system", "systeem", "health"]
        ),
        JeevesCapability(
            id: "inspect_approvals",
            title: "Inspecteer Goedkeuringen",
            kind: .inspection,
            targetScreen: .stream,
            requiresGateway: true,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["approvals", "proposals"]
        ),
        JeevesCapability(
            id: "inspect_audit",
            title: "Inspecteer Logboek",
            kind: .inspection,
            targetScreen: .logbook,
            requiresGateway: true,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["audit", "log"]
        ),

        // — Explanation —

        JeevesCapability(
            id: "explain_system",
            title: "Leg Systeem Uit",
            kind: .explanation,
            targetScreen: nil,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["explain system"]
        ),
        JeevesCapability(
            id: "explain_focus",
            title: "Verklaar Focus",
            kind: .explanation,
            targetScreen: nil,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["focus", "guidance", "attention", "advies"]
        ),
        JeevesCapability(
            id: "inspect_here",
            title: "Inspecteer Hier",
            kind: .explanation,
            targetScreen: nil,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["here", "hier", "capabilities", "mogelijkheden"]
        ),

        // — Governed Actions (planned) —

        JeevesCapability(
            id: "propose_deployment",
            title: "Stel Deployment Voor",
            kind: .governedAction,
            targetScreen: .aiBrowser,
            requiresGateway: true,
            requiresGovernance: true,
            mode: .planned,
            commandAliases: ["deploy"]
        ),
        JeevesCapability(
            id: "approve_proposal",
            title: "Keur Voorstel Goed",
            kind: .governedAction,
            targetScreen: .stream,
            requiresGateway: true,
            requiresGovernance: true,
            mode: .planned,
            commandAliases: ["approve"]
        ),
        JeevesCapability(
            id: "reject_proposal",
            title: "Wijs Voorstel Af",
            kind: .governedAction,
            targetScreen: .stream,
            requiresGateway: true,
            requiresGovernance: true,
            mode: .planned,
            commandAliases: ["reject"]
        ),
        JeevesCapability(
            id: "activate_kill_switch",
            title: "Activeer Noodstop",
            kind: .governedAction,
            targetScreen: .house,
            requiresGateway: true,
            requiresGovernance: true,
            mode: .planned,
            commandAliases: ["kill-switch", "noodstop"]
        ),
    ]
}
