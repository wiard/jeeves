import Foundation
import Observation

@MainActor
@Observable
final class JeevesOrchestrator {

    /// The most recent directive. ContentView observes this to switch tabs.
    var activeDirective: JeevesDirective?

    /// Session context for operator continuity across messages.
    let session = JeevesSession()

    /// Registered screen state readers for Mission Control.
    /// Screens register here so the orchestrator can inspect any screen's state.
    private(set) var registeredReaders: [ScreenStateReadable] = []

    /// Minimum confidence to trigger navigation. Below this, stay in chat.
    private let confidenceThreshold: Double = 0.5

    /// Register a screen state reader. Replaces any existing reader for the same screenId.
    func register(_ reader: ScreenStateReadable) {
        registeredReaders.removeAll { $0.screenId == reader.screenId }
        registeredReaders.append(reader)
    }

    /// Aggregate summaries from all registered readers into one system overview.
    func systemSummary() -> String {
        guard !registeredReaders.isEmpty else { return "Geen schermdata beschikbaar." }

        var lines: [String] = []
        for reader in registeredReaders.sorted(by: { $0.screenId.rawValue < $1.screenId.rawValue }) {
            let s = reader.summary()
            let status = s.isEmpty ? "leeg" : s.headline
            lines.append("[\(s.screen.title)] \(status)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Public API

    /// Resolve user text into a navigation directive.
    /// Returns nil if the message is purely conversational.
    ///
    /// Priority: structured command → follow-up → NL classification → nil.
    /// All directives pass through the policy layer before being returned.
    func resolve(
        text: String,
        readers: [ScreenStateReadable]
    ) -> JeevesDirective? {
        // Merge passed readers with registered readers (passed take precedence)
        let allReaders = mergedReaders(passed: readers)
        let ctx = session.context()

        // 1. Try structured command parse first
        if let command = JeevesCommandParser.parse(text) {
            // Check if this is a guidance command targeting the Operator Brain
            if let guidanceKind = guidanceCommandKind(for: command) {
                return applyPolicy(
                    to: resolveGuidance(kind: guidanceKind, context: ctx, readers: allReaders)
                )
            }
            if let directive = JeevesCommandRouter.route(command, readers: allReaders) {
                return applyPolicy(to: directive)
            }
        }

        // 2. Fall back to natural language classification
        let intent = classifyIntent(text)

        // 3. Handle guidance intents via the Operator Brain
        if case .seekGuidance(let kind) = intent {
            return applyPolicy(
                to: resolveGuidance(kind: kind, context: ctx, readers: allReaders)
            )
        }

        // 4. If conversational but we have a previous directive, check for
        //    narrow screen-based follow-up ("meer details", "vertel meer")
        if intent.isConversational, ctx.hasDirectiveContext {
            if let followUp = resolveFollowUp(text: text, context: ctx, readers: allReaders) {
                return applyPolicy(to: followUp)
            }
            return nil
        }

        guard !intent.isConversational else { return nil }

        let destination = bestScreen(for: intent)
        guard destination != .chat else { return nil }

        let statePreset = buildPreset(for: intent)
        let section = targetSection(for: intent, in: destination)
        let reader = allReaders.first { $0.screenId == destination }
        let stateSummary = reader?.summary()
        let explanation = buildExplanation(
            intent: intent,
            destination: destination,
            summary: stateSummary
        )

        let directive = JeevesDirective(
            intent: describeIntent(intent),
            destination: destination,
            section: section,
            statePreset: statePreset,
            explanation: explanation,
            reason: "Matched intent to \(destination.title)",
            confidence: 0.9
        )
        return applyPolicy(to: directive)
    }

    /// Navigate to a directive. Sets activeDirective so ContentView reacts.
    func navigate(to directive: JeevesDirective) {
        session.recordDirective(directive)
        activeDirective = directive
    }

    // MARK: - Policy Enforcement

    /// Single policy enforcement point for all directives.
    /// Looks up the implied capability and evaluates the policy layer.
    /// Returns the directive unchanged if allowed, or a modified directive
    /// with an explanation if blocked/planned/governed.
    private func applyPolicy(to directive: JeevesDirective) -> JeevesDirective? {
        guard let capability = JeevesCapabilityRegistry.resolve(directive: directive) else {
            return directive // Unknown capability, pass through
        }

        let decision = JeevesPolicyLayer.evaluate(capability: capability)

        switch decision.mode {
        case .allowed, .readOnlyOnly:
            return directive

        case .blocked, .planned:
            // Stay in chat, show explanation instead of navigating
            return JeevesDirective(
                intent: directive.intent,
                destination: .chat,
                section: nil,
                statePreset: .empty,
                explanation: decision.operatorMessage,
                reason: decision.reason,
                confidence: 1.0
            )

        case .requiresApproval, .proposalOnly:
            // Navigate to the screen but append governance notice
            return JeevesDirective(
                intent: directive.intent,
                destination: directive.destination,
                section: directive.section,
                statePreset: directive.statePreset,
                explanation: directive.explanation + " " + decision.operatorMessage,
                reason: decision.reason,
                confidence: directive.confidence
            )
        }
    }

    // MARK: - Intent Classification (keyword-based, v1)

    private func classifyIntent(_ text: String) -> JeevesIntent {
        let lower = text.lowercased()

        // Browse / AI Browser patterns
        if matchesAny(lower, patterns: browserPatterns) {
            let domain = extractDomain(from: lower)
            let subdomain = extractSubdomain(from: lower, domain: domain)
            let risk = extractRisk(from: lower)
            return .browse(domain: domain, subdomain: subdomain, risk: risk)
        }

        // Radar patterns
        if matchesAny(lower, patterns: radarPatterns) {
            return .checkRadar
        }

        // Fabric patterns
        if matchesAny(lower, patterns: fabricPatterns) {
            return .viewFabric
        }

        // Knowledge patterns
        if matchesAny(lower, patterns: knowledgePatterns) {
            return .viewKnowledge
        }

        // Pending / approval patterns
        if matchesAny(lower, patterns: pendingPatterns) {
            return .reviewPending
        }

        // System inspection patterns
        if matchesAny(lower, patterns: systemPatterns) {
            let aspect = extractSystemAspect(from: lower)
            return .inspectSystem(aspect: aspect)
        }

        // Audit / log patterns
        if matchesAny(lower, patterns: auditPatterns) {
            return .searchAudit(query: nil)
        }

        // Extension / lobby patterns
        if matchesAny(lower, patterns: lobbyPatterns) {
            return .manageExtensions
        }

        // Operator guidance patterns (Operator Brain)
        if let kind = classifyGuidanceKind(lower) {
            return .seekGuidance(kind: kind)
        }

        return .conversational(text: text)
    }

    // MARK: - Screen Routing

    private func bestScreen(for intent: JeevesIntent) -> AppScreen {
        switch intent {
        case .browse:           return .aiBrowser
        case .checkRadar:       return .observatory
        case .viewFabric:       return .observatory
        case .viewKnowledge:    return .observatory
        case .inspectSystem(let aspect):
            switch aspect {
            case .pressure, .signals, .emergence: return .observatory
            default: return .house
            }
        case .reviewPending:    return .stream
        case .searchAudit:      return .logbook
        case .manageExtensions: return .lobby
        case .seekGuidance:     return .chat   // handled before this point
        case .conversational:   return .chat
        }
    }

    // MARK: - State Preset

    private func buildPreset(for intent: JeevesIntent) -> ScreenStatePreset {
        var preset = ScreenStatePreset.empty

        switch intent {
        case .browse(let domain, let subdomain, _):
            preset.browserSection = "marketplace"
            preset.browserDomain = domain
            preset.browserSubdomain = subdomain

        case .checkRadar:
            preset.observatorySection = "radar"

        case .viewFabric:
            preset.observatorySection = "fabric"

        case .viewKnowledge:
            preset.observatorySection = "knowledge"

        case .inspectSystem(let aspect):
            switch aspect {
            case .budget:    break // house shows budget by default
            case .killSwitch: break
            case .pressure, .signals, .emergence:
                preset.observatorySection = "signals"
            default: break
            }

        case .searchAudit:
            preset.auditPeriod = "daily"

        case .reviewPending, .manageExtensions,
             .seekGuidance, .conversational:
            break
        }

        return preset
    }

    private func targetSection(for intent: JeevesIntent, in screen: AppScreen) -> String? {
        switch intent {
        case .checkRadar:    return "radar"
        case .viewFabric:    return "fabric"
        case .viewKnowledge: return "knowledge"
        case .inspectSystem(let aspect):
            switch aspect {
            case .budget:    return "budget"
            case .killSwitch: return "killSwitch"
            case .consent:   return "kernel"
            default: return nil
            }
        case .browse, .reviewPending, .searchAudit,
             .manageExtensions, .seekGuidance, .conversational:
            return nil
        }
    }

    // MARK: - Explanation

    private func buildExplanation(
        intent: JeevesIntent,
        destination: AppScreen,
        summary: ScreenStateSummary?
    ) -> String {
        let base: String
        switch intent {
        case .browse(let domain, let subdomain, let risk):
            var parts = ["Ik open de AI Browser"]
            if let d = domain { parts.append("gefilterd op \(d.capitalized)") }
            if let s = subdomain { parts.append("→ \(s.capitalized)") }
            if let r = risk { parts.append("met \(r) risico") }
            base = parts.joined(separator: " ") + "."

        case .checkRadar:
            base = "Ik open de Observatory op het Radar-overzicht."

        case .viewFabric:
            base = "Ik open de Observatory op de Fabric-sectie."

        case .viewKnowledge:
            base = "Ik open de Observatory op de Knowledge-sectie."

        case .inspectSystem(let aspect):
            switch aspect {
            case .pressure, .signals, .emergence:
                let label = aspect?.rawValue.capitalized ?? "druk"
                base = "Ik open de Observatory voor \(label)-signalen."
            default:
                let label = aspect?.rawValue.capitalized ?? "systeemstatus"
                base = "Ik open het Huis-overzicht voor \(label)."
            }

        case .reviewPending:
            base = "Ik open Mission Control voor openstaande items."

        case .searchAudit:
            base = "Ik open het Logboek."

        case .manageExtensions:
            base = "Ik open de Lobby voor extensies en challenges."

        case .seekGuidance:
            base = ""  // handled by resolveGuidance before this point

        case .conversational:
            base = ""
        }

        if let summary, !summary.isEmpty {
            return base + " " + summary.headline
        }
        return base
    }

    private func describeIntent(_ intent: JeevesIntent) -> String {
        switch intent {
        case .browse(let d, let s, let r):
            return "browse(\(d ?? "-"), \(s ?? "-"), \(r ?? "-"))"
        case .inspectSystem(let a):
            return "inspectSystem(\(a?.rawValue ?? "-"))"
        case .reviewPending:      return "reviewPending"
        case .searchAudit:        return "searchAudit"
        case .checkRadar:         return "checkRadar"
        case .viewFabric:         return "viewFabric"
        case .viewKnowledge:      return "viewKnowledge"
        case .manageExtensions:   return "manageExtensions"
        case .seekGuidance(let k): return "guidance:\(k.rawValue)"
        case .conversational:     return "conversational"
        }
    }

    // MARK: - Keyword patterns

    private let browserPatterns: [String] = [
        "browser", "marketplace", "deploy", "agent zoeken",
        "ai zoeken", "configuratie", "invest", "beleggen",
        "financial", "low risk", "laag risico", "certified",
        "emerging", "best ai", "beste ai", "which ai", "welke ai",
        "find me an ai", "zoek een ai", "show agents", "toon agents",
        "my agents", "mijn agents"
    ]

    private let radarPatterns: [String] = [
        "radar", "collision", "botsing", "activations", "activatie",
        "gravity", "hotspot", "hot spot"
    ]

    private let fabricPatterns: [String] = [
        "fabric", "emergence", "cube", "residue", "route",
        "heatmap", "heat map", "cells", "cellen"
    ]

    private let knowledgePatterns: [String] = [
        "knowledge", "kennis", "challenge", "collision",
        "kennisbotsing", "scan"
    ]

    private let pendingPatterns: [String] = [
        "pending", "openstaand", "approval", "goedkeuring",
        "wacht op", "needs approval", "nog goedkeuren",
        "wat moet ik", "proposals", "voorstellen"
    ]

    private let systemPatterns: [String] = [
        "budget", "kill switch", "killswitch", "noodstop",
        "consent", "status", "health", "gezondheid",
        "pressure", "druk", "system", "systeem",
        "hoe gaat het", "huis"
    ]

    private let auditPatterns: [String] = [
        "audit", "log", "logboek", "history", "geschiedenis",
        "wat is er gebeurd", "what happened", "blocked", "geblokkeerd"
    ]

    private let lobbyPatterns: [String] = [
        "extension", "extensie", "sandbox", "lobby",
        "challenge", "environment", "omgeving"
    ]

    // MARK: - Extraction helpers

    private func matchesAny(_ text: String, patterns: [String]) -> Bool {
        patterns.contains { text.contains($0) }
    }

    private func extractDomain(from text: String) -> String? {
        let domainMap: [(keywords: [String], domain: String)] = [
            (["financ", "invest", "beleg", "trading", "payment", "treasury"], "financial"),
            (["legal", "juridisch", "contract", "compliance"], "legal"),
            (["research", "onderzoek", "literature", "hypothesis"], "research"),
            (["education", "onderwijs", "tutoring", "curriculum"], "education"),
            (["automation", "automatiser", "workflow", "orchestrat"], "automation"),
            (["security", "beveiliging", "threat", "identity"], "security"),
            (["creativ", "writing", "design", "synthes"], "creativity"),
        ]
        for entry in domainMap {
            if entry.keywords.contains(where: { text.contains($0) }) {
                return entry.domain
            }
        }
        return nil
    }

    private func extractSubdomain(from text: String, domain: String?) -> String? {
        guard let domain else { return nil }
        let subdomainMap: [String: [(keywords: [String], subdomain: String)]] = [
            "financial": [
                (["invest", "beleg"], "investing"),
                (["payment", "betal"], "payments"),
                (["treasury"], "treasury"),
                (["risk", "risico"], "risk"),
            ],
            "security": [
                (["threat", "bedreig"], "threat-detection"),
                (["identity", "identiteit"], "identity"),
                (["incident"], "incident-response"),
            ],
        ]
        guard let candidates = subdomainMap[domain] else { return nil }
        for entry in candidates {
            if entry.keywords.contains(where: { text.contains($0) }) {
                return entry.subdomain
            }
        }
        return nil
    }

    private func extractRisk(from text: String) -> String? {
        if text.contains("low risk") || text.contains("laag risico") { return "low" }
        if text.contains("high risk") || text.contains("hoog risico") { return "high" }
        if text.contains("medium risk") || text.contains("gemiddeld risico") { return "medium" }
        return nil
    }

    private func extractSystemAspect(from text: String) -> JeevesIntent.SystemAspect? {
        if text.contains("budget") { return .budget }
        if text.contains("kill") || text.contains("noodstop") { return .killSwitch }
        if text.contains("consent") || text.contains("toestemming") { return .consent }
        if text.contains("pressure") || text.contains("druk") { return .pressure }
        if text.contains("signal") || text.contains("signaal") || text.contains("signalen") { return .signals }
        if text.contains("emergence") || text.contains("emergentie") { return .emergence }
        return .health
    }

    /// Merge passed readers with registered readers. Passed readers take precedence per screenId.
    private func mergedReaders(passed: [ScreenStateReadable]) -> [ScreenStateReadable] {
        var byScreen: [AppScreen: ScreenStateReadable] = [:]
        for reader in registeredReaders {
            byScreen[reader.screenId] = reader
        }
        for reader in passed {
            byScreen[reader.screenId] = reader
        }
        return Array(byScreen.values)
    }

    // MARK: - Follow-up Resolution

    /// Narrow patterns for screen-based follow-up.
    /// Only explicit "show me more" phrases — no broad conversational words.
    private let followUpPatterns: [String] = [
        "meer details", "more details", "vertel meer", "tell me more",
        "meer info", "more info"
    ]

    /// Resolve a screen-based follow-up using the previous directive.
    /// Only triggers when the message is an explicit "show me more" phrase
    /// and there is a previous directive to continue from.
    private func resolveFollowUp(
        text: String,
        context: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDirective? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        guard followUpPatterns.contains(where: { lower.contains($0) }) else { return nil }
        guard let previous = context.lastDirective else { return nil }

        let reader = readers.first { $0.screenId == previous.destination }
        let summary = reader?.summary()

        var explanation = "Ik toon meer over \(previous.destination.title)"
        if let section = previous.section {
            explanation += " → \(section)"
        }
        explanation += "."
        if let summary, !summary.isEmpty {
            explanation += " " + summary.headline
        }

        return JeevesDirective(
            intent: "followUp:\(previous.intent)",
            destination: previous.destination,
            section: previous.section,
            statePreset: previous.statePreset,
            explanation: explanation,
            reason: "Follow-up on previous directive",
            confidence: 0.85
        )
    }

    // MARK: - Operator Brain Integration

    /// Guidance keyword patterns for the Operator Brain.
    /// These are checked after all specific screen-targeted patterns.
    private let attentionPatterns: [String] = [
        "wat verdient aandacht", "what deserves attention",
        "wat is belangrijk nu", "what matters now",
        "wat is urgent", "what is urgent",
        "prioriteit", "priority"
    ]

    private let nextScreenPatterns: [String] = [
        "waar moet ik heen", "waar ga ik heen", "where should i go",
        "welk scherm", "which screen", "volgende scherm", "next screen"
    ]

    private let inspectPatterns: [String] = [
        "wat kan ik inspecteren", "what can i inspect",
        "wat kan ik bekijken", "what can i view here",
        "wat is er te zien", "what is there to see"
    ]

    private let availablePatterns: [String] = [
        "wat kan ik hier doen", "what can i do here",
        "welke mogelijkheden", "which capabilities",
        "wat is beschikbaar", "what is available"
    ]

    private let fullGuidancePatterns: [String] = [
        "guide me", "begeleid me", "geef advies", "give guidance",
        "geef een overzicht", "give an overview",
        "wat raad je aan", "what do you recommend"
    ]

    /// Classify NL text into a guidance kind, or nil if not a guidance request.
    private func classifyGuidanceKind(_ text: String) -> JeevesIntent.GuidanceKind? {
        if matchesAny(text, patterns: attentionPatterns)     { return .attention }
        if matchesAny(text, patterns: nextScreenPatterns)    { return .nextScreen }
        if matchesAny(text, patterns: inspectPatterns)       { return .inspect }
        if matchesAny(text, patterns: availablePatterns)     { return .available }
        if matchesAny(text, patterns: fullGuidancePatterns)  { return .full }
        return nil
    }

    /// Map a structured command to a guidance kind for the Operator Brain.
    /// Supports: `jeeves explain focus`, `jeeves show guidance`, `jeeves inspect here`.
    private func guidanceCommandKind(for command: JeevesCommand) -> JeevesIntent.GuidanceKind? {
        switch command.target {
        case "focus", "attention", "aandacht":
            return .attention
        case "guidance", "begeleiding", "advies":
            return .full
        case "here", "hier":
            return command.verb == .inspect ? .inspect : .available
        case "capabilities", "mogelijkheden":
            return .available
        default:
            return nil
        }
    }

    /// Resolve a guidance request via the Operator Brain.
    /// The brain assesses current state and produces a grounded recommendation.
    private func resolveGuidance(
        kind: JeevesIntent.GuidanceKind,
        context: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDirective {
        switch kind {
        case .attention, .nextScreen:
            let rec = JeevesOperatorBrain.guide(session: context, readers: readers)
            return JeevesDirective(
                intent: "guidance:\(kind.rawValue)",
                destination: rec.suggestedScreen,
                section: rec.suggestedSection,
                statePreset: .empty,
                explanation: rec.explanation,
                reason: rec.reason,
                confidence: 0.95
            )

        case .inspect:
            let items = JeevesOperatorBrain.inspectableFromScreen(
                context.currentScreen,
                readers: readers
            )
            let list = items.isEmpty
                ? "Geen inspectiepunten beschikbaar."
                : items.joined(separator: ", ")
            return JeevesDirective(
                intent: "guidance:inspect",
                destination: .chat,
                section: nil,
                statePreset: .empty,
                explanation: "Vanuit \(context.currentScreen.title) kun je inspecteren: \(list).",
                reason: "inspectable_items",
                confidence: 1.0
            )

        case .available:
            let caps = JeevesOperatorBrain.capabilitiesWithPolicy(
                for: context.currentScreen
            )
            let list = caps.isEmpty
                ? "Geen mogelijkheden beschikbaar."
                : caps.map { "\($0.title) (\($0.status))" }.joined(separator: ", ")
            return JeevesDirective(
                intent: "guidance:available",
                destination: .chat,
                section: nil,
                statePreset: .empty,
                explanation: "Beschikbare mogelijkheden op \(context.currentScreen.title): \(list).",
                reason: "available_capabilities",
                confidence: 1.0
            )

        case .full:
            let assessment = JeevesOperatorBrain.assess(
                session: context,
                readers: readers
            )
            let rec = JeevesOperatorBrain.recommend(assessment: assessment)

            var lines: [String] = []
            lines.append("Systeem: \(assessment.gatewayConnected ? "verbonden" : "niet verbonden"). Urgentie: \(assessment.urgency.label).")
            lines.append(assessment.primaryFocus)
            if let secondary = assessment.secondaryFocus {
                lines.append(secondary)
            }
            lines.append("Aanbeveling: \(rec.suggestedScreen.title).")
            if let section = rec.suggestedSection {
                lines.append("Sectie: \(section).")
            }

            return JeevesDirective(
                intent: "guidance:full",
                destination: rec.suggestedScreen,
                section: rec.suggestedSection,
                statePreset: .empty,
                explanation: lines.joined(separator: " "),
                reason: rec.reason,
                confidence: 0.95
            )
        }
    }
}
