import Foundation
import Observation

@MainActor
@Observable
final class JeevesOrchestrator {

    /// The most recent directive. ContentView observes this to switch tabs.
    var activeDirective: JeevesDirective?

    /// Minimum confidence to trigger navigation. Below this, stay in chat.
    private let confidenceThreshold: Double = 0.5

    // MARK: - Public API

    /// Resolve user text into a navigation directive.
    /// Returns nil if the message is purely conversational.
    func resolve(
        text: String,
        readers: [ScreenStateReadable]
    ) -> JeevesDirective? {
        let intent = classifyIntent(text)
        guard !intent.isConversational else { return nil }

        let destination = bestScreen(for: intent)
        guard destination != .chat else { return nil }

        let statePreset = buildPreset(for: intent)
        let section = targetSection(for: intent, in: destination)
        let reader = readers.first { $0.screenId == destination }
        let stateSummary = reader?.summary()
        let explanation = buildExplanation(
            intent: intent,
            destination: destination,
            summary: stateSummary
        )

        return JeevesDirective(
            intent: describeIntent(intent),
            destination: destination,
            section: section,
            statePreset: statePreset,
            explanation: explanation,
            reason: "Matched intent to \(destination.title)",
            confidence: 0.9
        )
    }

    /// Navigate to a directive. Sets activeDirective so ContentView reacts.
    func navigate(to directive: JeevesDirective) {
        activeDirective = directive
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

        return .conversational(text: text)
    }

    // MARK: - Screen Routing

    private func bestScreen(for intent: JeevesIntent) -> AppScreen {
        switch intent {
        case .browse:           return .aiBrowser
        case .checkRadar:       return .observatory
        case .viewFabric:       return .observatory
        case .viewKnowledge:    return .observatory
        case .inspectSystem:    return .house
        case .reviewPending:    return .stream
        case .searchAudit:      return .logbook
        case .manageExtensions: return .lobby
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

        default:
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
        default: return nil
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
            let aspectLabel = aspect?.rawValue.capitalized ?? "systeemstatus"
            base = "Ik open het Huis-overzicht voor \(aspectLabel)."

        case .reviewPending:
            base = "Ik open Mission Control voor openstaande items."

        case .searchAudit:
            base = "Ik open het Logboek."

        case .manageExtensions:
            base = "Ik open de Lobby voor extensies en challenges."

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
}
