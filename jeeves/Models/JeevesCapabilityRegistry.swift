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

    /// Operator-facing capability summaries enriched with policy and
    /// execution-awareness metadata. Uses local deterministic rules only.
    static func capabilitySummaries() -> [JeevesCapabilitySummary] {
        catalog
            .map { capability in
                let policy = JeevesPolicyLayer.evaluate(capability: capability)
                let execution = executionAwareness(for: capability, policy: policy)
                return JeevesCapabilitySummary(
                    capability: capability,
                    policyDecision: policy,
                    execution: execution,
                    evidence: evidenceHints(for: capability, policy: policy, execution: execution),
                    nextAction: nextActionHint(for: capability, policy: policy)
                )
            }
            .sorted { $0.capability.id < $1.capability.id }
    }

    static func capabilitySummary(for id: String) -> JeevesCapabilitySummary? {
        capabilitySummaries().first(where: { $0.capability.id == id })
    }

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
        "explainability:context":       "explain_context",
        "explainability:decision":      "explain_decision",
        "explainability:why_screen":    "explain_screen_route",
        "explainability:why_suggestion":"explain_suggestion",
        "explainability:matched":       "explain_match",
        "timeline:timeline":            "timeline_show",
        "timeline:recent_decisions":    "timeline_recent_decisions",
        "timeline:what_happened":       "timeline_what_happened",
        "timeline:recent_matches":      "timeline_recent_matches",
        "timeline:recent_policy_checks":"timeline_recent_policy_checks",
        "execution_awareness:what_can_i_do":          "capabilities_available",
        "execution_awareness:what_is_allowed":        "capabilities_allowed",
        "execution_awareness:what_requires_approval": "capabilities_requires_approval",
        "execution_awareness:what_is_blocked":        "capabilities_blocked",
        "execution_awareness:what_is_destructive":    "capabilities_destructive",
        "execution_awareness:what_touches_money":     "capabilities_touches_money",
        "execution_awareness:what_is_security_related":"capabilities_security_related",
        "execution_awareness:why_recommend_this":     "explain_recommendation_reason",
        "execution_awareness:what_evidence_supports_this":"explain_evidence_context",
    ]

    private static let moneyCapabilityIds: Set<String> = [
        "propose_deployment",
        "approve_proposal",
        "reject_proposal",
    ]

    private static let securityCapabilityIds: Set<String> = [
        "inspect_radar",
        "inspect_fabric",
        "inspect_system",
        "open_observatory",
        "activate_kill_switch",
    ]

    private static func executionAwareness(
        for capability: JeevesCapability,
        policy: JeevesPolicyDecision
    ) -> JeevesExecutionAwareness {
        let executionClass: JeevesExecutionClass
        if capability.kind == .governedAction {
            executionClass = .destructive
        } else if policy.mode == .requiresApproval || policy.mode == .proposalOnly {
            executionClass = .governed
        } else {
            executionClass = .readOnly
        }

        return JeevesExecutionAwareness(
            executionClass: executionClass,
            touchesMoney: moneyCapabilityIds.contains(capability.id),
            securityRelated: securityCapabilityIds.contains(capability.id)
        )
    }

    private static func evidenceHints(
        for capability: JeevesCapability,
        policy: JeevesPolicyDecision,
        execution: JeevesExecutionAwareness
    ) -> [JeevesEvidenceHint] {
        var hints: [JeevesEvidenceHint] = [
            JeevesEvidenceHint(
                source: "policy_layer",
                detail: "policy reason: \(policy.reason)"
            )
        ]

        if let screen = capability.targetScreen {
            hints.append(
                JeevesEvidenceHint(
                    source: "screen_state",
                    detail: "targets \(screen.title)"
                )
            )
        }

        if capability.requiresGateway {
            hints.append(
                JeevesEvidenceHint(
                    source: "gateway_contract",
                    detail: "requires governed gateway path"
                )
            )
        }

        if execution.touchesMoney {
            hints.append(
                JeevesEvidenceHint(
                    source: "safeclash_context",
                    detail: "value settlement relevance"
                )
            )
        }

        if execution.securityRelated {
            hints.append(
                JeevesEvidenceHint(
                    source: "clashd27_context",
                    detail: "security and anomaly relevance"
                )
            )
        }

        return hints
    }

    private static func nextActionHint(
        for capability: JeevesCapability,
        policy: JeevesPolicyDecision
    ) -> JeevesOperatorActionHint {
        let alias = capability.commandAliases.first ?? capability.id
        switch policy.mode {
        case .allowed, .readOnlyOnly:
            return JeevesOperatorActionHint(
                action: "jeeves show \(alias)",
                reason: "allowed now"
            )
        case .requiresApproval, .proposalOnly:
            return JeevesOperatorActionHint(
                action: "review governance queue",
                reason: "requires approval"
            )
        case .blocked:
            return JeevesOperatorActionHint(
                action: "inspect policy constraints",
                reason: "currently blocked"
            )
        case .planned:
            return JeevesOperatorActionHint(
                action: "track planned capability rollout",
                reason: "not implemented"
            )
        }
    }

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
        JeevesCapability(
            id: "explain_context",
            title: "Verklaar Context",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["explain context"]
        ),
        JeevesCapability(
            id: "explain_decision",
            title: "Verklaar Beslissing",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["explain decision"]
        ),
        JeevesCapability(
            id: "explain_screen_route",
            title: "Waarom Dit Scherm",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["why this screen"]
        ),
        JeevesCapability(
            id: "explain_suggestion",
            title: "Waarom Deze Suggestie",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["why this suggestion"]
        ),
        JeevesCapability(
            id: "explain_match",
            title: "Wat Matchte",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["what matched"]
        ),
        JeevesCapability(
            id: "timeline_show",
            title: "Toon Operator Timeline",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["show timeline"]
        ),
        JeevesCapability(
            id: "timeline_recent_decisions",
            title: "Toon Recente Beslissingen",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["recent decisions"]
        ),
        JeevesCapability(
            id: "timeline_what_happened",
            title: "Wat Gebeurde Er",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["what happened"]
        ),
        JeevesCapability(
            id: "timeline_recent_matches",
            title: "Toon Recente Matches",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["show recent matches"]
        ),
        JeevesCapability(
            id: "timeline_recent_policy_checks",
            title: "Toon Recente Policy Checks",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["show recent policy checks"]
        ),
        JeevesCapability(
            id: "capabilities_available",
            title: "Toon Beschikbare Mogelijkheden",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["what can i do"]
        ),
        JeevesCapability(
            id: "capabilities_allowed",
            title: "Toon Toegestane Mogelijkheden",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["what is allowed"]
        ),
        JeevesCapability(
            id: "capabilities_requires_approval",
            title: "Toon Goedkeuringspaden",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["what requires approval"]
        ),
        JeevesCapability(
            id: "capabilities_blocked",
            title: "Toon Geblokkeerde Mogelijkheden",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["what is blocked"]
        ),
        JeevesCapability(
            id: "capabilities_destructive",
            title: "Toon Destructieve Mogelijkheden",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["what is destructive"]
        ),
        JeevesCapability(
            id: "capabilities_touches_money",
            title: "Toon Waardepaden",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["what touches money"]
        ),
        JeevesCapability(
            id: "capabilities_security_related",
            title: "Toon Security-Relevante Mogelijkheden",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["what is security-related"]
        ),
        JeevesCapability(
            id: "explain_recommendation_reason",
            title: "Verklaar Aanbeveling",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["why do you recommend this"]
        ),
        JeevesCapability(
            id: "explain_evidence_context",
            title: "Verklaar Evidentiecontext",
            kind: .explanation,
            targetScreen: .chat,
            requiresGateway: false,
            requiresGovernance: false,
            mode: .readOnly,
            commandAliases: ["what evidence supports this"]
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
