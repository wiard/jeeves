import Foundation

// MARK: - Operator Urgency

/// Urgency level for the current operator state.
/// Used by the Operator Brain to prioritize recommendations.
enum JeevesOperatorUrgency: Int, Sendable, Comparable {
    case calm     = 0
    case routine  = 1
    case elevated = 2
    case urgent   = 3

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .calm:     return "Rustig"
        case .routine:  return "Normaal"
        case .elevated: return "Verhoogd"
        case .urgent:   return "Urgent"
        }
    }
}

// MARK: - Operator Assessment

/// Compact assessment of the current system state.
/// Built from screen state readers and session context.
/// The brain uses this to produce grounded recommendations.
struct JeevesOperatorAssessment: Sendable {
    let currentScreen: AppScreen
    let gatewayConnected: Bool
    let pendingApprovals: Int
    let screenSummaries: [AppScreen: ScreenStateSummary]
    let urgency: JeevesOperatorUrgency
    let primaryFocus: String
    let secondaryFocus: String?
}

// MARK: - Operator Recommendation

/// A grounded, explainable recommendation for the operator.
/// Contains the suggested next screen, reason, and contextual information.
struct JeevesOperatorRecommendation: Sendable {
    let suggestedScreen: AppScreen
    let suggestedSection: String?
    let reason: String
    let explanation: String
    let urgency: JeevesOperatorUrgency
    let inspectableItems: [String]
    let availableCapabilities: [String]
}

// MARK: - Operator Brain

/// Deterministic, local reasoning layer for operator guidance.
///
/// The Operator Brain does not replace JeevesOrchestrator.
/// It enriches the orchestrator by transforming current state into
/// compact, explainable recommendations.
///
/// Rules are explicit, deterministic, and governance-compatible.
/// No LLM dependency. No backend calls. No hidden side effects.
@MainActor
enum JeevesOperatorBrain {

    // MARK: - Assessment

    /// Build an assessment from current session context and screen state readers.
    static func assess(
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesOperatorAssessment {
        let summaries = readers.reduce(into: [AppScreen: ScreenStateSummary]()) { dict, reader in
            dict[reader.screenId] = reader.summary()
        }

        let streamSummary = summaries[.stream]
        let houseSummary = summaries[.house]
        let observatorySummary = summaries[.observatory]

        let pendingApprovals = streamSummary?.itemCount ?? 0
        let gatewayConnected = houseSummary.map { !$0.isEmpty } ?? false

        // Determine urgency from state signals
        let urgency: JeevesOperatorUrgency
        if pendingApprovals > 10 {
            urgency = .urgent
        } else if pendingApprovals > 3 {
            urgency = .elevated
        } else if pendingApprovals > 0
                    || (observatorySummary.map { !$0.isEmpty } ?? false) {
            urgency = .routine
        } else {
            urgency = .calm
        }

        // Primary and secondary focus
        let primaryFocus: String
        let secondaryFocus: String?

        if !gatewayConnected {
            primaryFocus = "Gateway is niet verbonden."
            secondaryFocus = pendingApprovals > 0
                ? approvalLabel(pendingApprovals)
                : nil
        } else if pendingApprovals > 0 {
            primaryFocus = approvalLabel(pendingApprovals)
            secondaryFocus = observatorySummary.flatMap { $0.isEmpty ? nil : $0.headline }
        } else if let obs = observatorySummary, !obs.isEmpty {
            primaryFocus = obs.headline
            secondaryFocus = nil
        } else {
            primaryFocus = "Geen urgente items. Het systeem draait rustig."
            secondaryFocus = nil
        }

        return JeevesOperatorAssessment(
            currentScreen: session.currentScreen,
            gatewayConnected: gatewayConnected,
            pendingApprovals: pendingApprovals,
            screenSummaries: summaries,
            urgency: urgency,
            primaryFocus: primaryFocus,
            secondaryFocus: secondaryFocus
        )
    }

    // MARK: - Recommendation

    /// Produce a recommendation from an assessment.
    /// Rules are applied in priority order:
    /// 1. Gateway disconnected → House
    /// 2. Pending approvals → Mission Control
    /// 3. Observatory activity → Observatory
    /// 4. Browser activity → Browser
    /// 5. Default calm → current screen or Observatory
    static func recommend(
        assessment: JeevesOperatorAssessment
    ) -> JeevesOperatorRecommendation {

        // Rule 1: Gateway not connected → House for connection review
        if !assessment.gatewayConnected {
            return JeevesOperatorRecommendation(
                suggestedScreen: .house,
                suggestedSection: nil,
                reason: "gateway_disconnected",
                explanation: "Gateway is niet verbonden. Ik raad het Huis-overzicht aan voor verbindingsstatus.",
                urgency: .elevated,
                inspectableItems: sectionLabels(for: .house),
                availableCapabilities: capabilityLabels(for: .house)
            )
        }

        // Rule 2: Pending approvals → Mission Control
        if assessment.pendingApprovals > 0 {
            return JeevesOperatorRecommendation(
                suggestedScreen: .stream,
                suggestedSection: "proposals",
                reason: "pending_approvals",
                explanation: assessment.primaryFocus + " Ik raad Mission Control aan.",
                urgency: assessment.urgency,
                inspectableItems: sectionLabels(for: .stream),
                availableCapabilities: capabilityLabels(for: .stream)
            )
        }

        // Rule 3: Observatory has activity → Observatory
        if let obs = assessment.screenSummaries[.observatory], !obs.isEmpty {
            return JeevesOperatorRecommendation(
                suggestedScreen: .observatory,
                suggestedSection: "radar",
                reason: "observatory_activity",
                explanation: obs.headline + " Ik raad de Observatory aan.",
                urgency: max(assessment.urgency, .routine),
                inspectableItems: sectionLabels(for: .observatory),
                availableCapabilities: capabilityLabels(for: .observatory)
            )
        }

        // Rule 4: Browser has items → Browser
        if let browser = assessment.screenSummaries[.aiBrowser], !browser.isEmpty {
            return JeevesOperatorRecommendation(
                suggestedScreen: .aiBrowser,
                suggestedSection: "marketplace",
                reason: "browser_activity",
                explanation: browser.headline + " De AI Browser heeft activiteit.",
                urgency: .routine,
                inspectableItems: sectionLabels(for: .aiBrowser),
                availableCapabilities: capabilityLabels(for: .aiBrowser)
            )
        }

        // Rule 5: Calm default — stay on current screen or suggest Observatory
        let defaultScreen: AppScreen = assessment.currentScreen == .chat
            ? .observatory
            : assessment.currentScreen
        return JeevesOperatorRecommendation(
            suggestedScreen: defaultScreen,
            suggestedSection: nil,
            reason: "system_calm",
            explanation: "Het systeem draait rustig. Geen urgente aandachtspunten.",
            urgency: .calm,
            inspectableItems: sectionLabels(for: defaultScreen),
            availableCapabilities: capabilityLabels(for: defaultScreen)
        )
    }

    // MARK: - Guidance (assess + recommend)

    /// Convenience: assess current state and produce a recommendation in one step.
    static func guide(
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesOperatorRecommendation {
        let assessment = assess(session: session, readers: readers)
        return recommend(assessment: assessment)
    }

    // MARK: - Contextual Queries

    /// Inspectable items for a given screen context.
    /// From chat, shows an overview of all active screens.
    /// From a specific screen, shows that screen's sections and highlights.
    static func inspectableFromScreen(
        _ screen: AppScreen,
        readers: [ScreenStateReadable]
    ) -> [String] {
        if screen == .chat {
            return readers.compactMap { reader in
                let s = reader.summary()
                guard !s.isEmpty else { return nil }
                return "\(s.screen.title): \(s.headline)"
            }
        }

        var items = sectionLabels(for: screen)
        if let reader = readers.first(where: { $0.screenId == screen }) {
            let summary = reader.summary()
            items.append(contentsOf: summary.highlights)
        }
        return items
    }

    /// Available capabilities for a screen with their policy status.
    static func capabilitiesWithPolicy(
        for screen: AppScreen
    ) -> [(title: String, status: String)] {
        let caps = JeevesCapabilityRegistry.capabilities(for: screen)
        return caps.map { cap in
            let decision = JeevesPolicyLayer.evaluate(capability: cap)
            let status: String
            switch decision.mode {
            case .allowed:          status = "beschikbaar"
            case .readOnlyOnly:     status = "alleen-lezen"
            case .requiresApproval: status = "vereist goedkeuring"
            case .proposalOnly:     status = "alleen voorstel"
            case .blocked:          status = "geblokkeerd"
            case .planned:          status = "gepland"
            }
            return (cap.title, status)
        }
    }

    // MARK: - Helpers

    private static func sectionLabels(for screen: AppScreen) -> [String] {
        screen.sections
    }

    private static func capabilityLabels(for screen: AppScreen) -> [String] {
        JeevesCapabilityRegistry.capabilities(for: screen).map { $0.title }
    }

    private static func approvalLabel(_ count: Int) -> String {
        count == 1
            ? "Er is 1 openstaande goedkeuring."
            : "Er zijn \(count) openstaande goedkeuringen."
    }
}
