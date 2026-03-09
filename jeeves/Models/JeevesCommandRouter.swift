import Foundation

/// Maps a parsed JeevesCommand into a JeevesDirective.
///
/// Commands never bypass governance. They only produce directives
/// that trigger UI navigation or gateway requests through the
/// existing orchestration pipeline.
enum JeevesCommandRouter {

    /// Route a command to a directive. Returns nil if the target is unrecognised.
    @MainActor
    static func route(
        _ command: JeevesCommand,
        readers: [ScreenStateReadable]
    ) -> JeevesDirective? {
        guard let mapping = resolveTarget(command.target) else { return nil }

        let destination = mapping.screen
        let section = command.arguments["section"] ?? mapping.section
        let preset = buildPreset(command: command, mapping: mapping)

        let reader = readers.first { $0.screenId == destination }
        let summary = reader?.summary()
        let explanation: String
        // For "inspect system" or "explain system", aggregate all reader summaries
        if (command.verb == .inspect || command.verb == .explain) && command.target == "system" {
            explanation = buildSystemExplanation(command: command, readers: readers)
        } else {
            explanation = buildExplanation(command: command, destination: destination, section: section, summary: summary)
        }

        return JeevesDirective(
            intent: "command:\(command.verb.rawValue) \(command.target)",
            destination: destination,
            section: section,
            statePreset: preset,
            explanation: explanation,
            reason: "Command: \(command.verb.rawValue) \(command.target)",
            confidence: 1.0
        )
    }

    // MARK: - Target Resolution

    private struct TargetMapping {
        let screen: AppScreen
        let section: String?
    }

    private static let targetMap: [String: TargetMapping] = [
        // AI Browser
        "browser":         TargetMapping(screen: .aiBrowser, section: "marketplace"),
        "marketplace":     TargetMapping(screen: .aiBrowser, section: "marketplace"),
        "deployments":     TargetMapping(screen: .aiBrowser, section: "deployments"),
        "agents":          TargetMapping(screen: .aiBrowser, section: "myAgents"),
        "my-agents":       TargetMapping(screen: .aiBrowser, section: "myAgents"),

        // Stream / Mission Control
        "stream":          TargetMapping(screen: .stream, section: nil),
        "mission-control": TargetMapping(screen: .stream, section: nil),
        "approvals":       TargetMapping(screen: .stream, section: "proposals"),
        "proposals":       TargetMapping(screen: .stream, section: "proposals"),

        // Observatory sections
        "observatory":     TargetMapping(screen: .observatory, section: nil),
        "radar":           TargetMapping(screen: .observatory, section: "radar"),
        "fabric":          TargetMapping(screen: .observatory, section: "fabric"),
        "knowledge":       TargetMapping(screen: .observatory, section: "knowledge"),
        "signals":         TargetMapping(screen: .observatory, section: "signals"),
        "discovery":       TargetMapping(screen: .observatory, section: "discovery"),
        "discoveries":     TargetMapping(screen: .observatory, section: "discovery"),
        "alerts":          TargetMapping(screen: .observatory, section: "alerts"),
        "oracle":          TargetMapping(screen: .observatory, section: "oracle"),
        "cube":            TargetMapping(screen: .observatory, section: "oracle"),

        // House
        "house":           TargetMapping(screen: .house, section: nil),
        "huis":            TargetMapping(screen: .house, section: nil),
        "system":          TargetMapping(screen: .house, section: nil),
        "health":          TargetMapping(screen: .house, section: "kernel"),
        "budget":          TargetMapping(screen: .house, section: "budget"),
        "kill-switch":     TargetMapping(screen: .house, section: "killSwitch"),

        // Logbook
        "logbook":         TargetMapping(screen: .logbook, section: nil),
        "logboek":         TargetMapping(screen: .logbook, section: nil),
        "audit":           TargetMapping(screen: .logbook, section: nil),

        // Lobby
        "lobby":           TargetMapping(screen: .lobby, section: nil),
        "extensions":      TargetMapping(screen: .lobby, section: "extensions"),
        "challenges":      TargetMapping(screen: .lobby, section: "challenges"),

        // Settings
        "settings":        TargetMapping(screen: .settings, section: nil),
        "instellingen":    TargetMapping(screen: .settings, section: nil),
    ]

    private static func resolveTarget(_ target: String) -> TargetMapping? {
        targetMap[target]
    }

    // MARK: - Preset

    private static func buildPreset(command: JeevesCommand, mapping: TargetMapping) -> ScreenStatePreset {
        var preset = ScreenStatePreset.empty

        switch mapping.screen {
        case .aiBrowser:
            preset.browserSection = command.arguments["section"] ?? mapping.section
            preset.browserDomain = command.arguments["domain"]
            preset.browserSubdomain = command.arguments["subdomain"]

        case .observatory:
            preset.observatorySection = command.arguments["section"] ?? mapping.section

        case .logbook:
            preset.auditPeriod = command.arguments["period"]
            preset.auditFilter = command.arguments["filter"]

        default:
            break
        }

        return preset
    }

    // MARK: - Explanation

    private static func buildExplanation(
        command: JeevesCommand,
        destination: AppScreen,
        section: String?,
        summary: ScreenStateSummary?
    ) -> String {
        let verb = command.verb

        var base: String
        switch verb {
        case .open:
            base = "Ik open \(destination.title)"
            if let section { base += " → \(section)" }
            base += "."
        case .show:
            base = "Ik toon \(destination.title)"
            if let section { base += " → \(section)" }
            base += "."
        case .inspect:
            base = "Ik inspecteer \(destination.title)"
            if let section { base += " → \(section)" }
            base += "."
        case .explain:
            base = "Ik licht \(destination.title) toe"
            if let section { base += " → \(section)" }
            base += "."
        case .why:
            base = "Ik verklaar waarom \(destination.title) is gekozen"
            if let section { base += " → \(section)" }
            base += "."
        case .what:
            base = "Ik licht toe wat matchte voor \(destination.title)"
            if let section { base += " → \(section)" }
            base += "."
        }

        // Add browser filter details
        if let domain = command.arguments["domain"] {
            base += " Domein: \(domain.capitalized)."
        }
        if let subdomain = command.arguments["subdomain"] {
            base += " Subdomein: \(subdomain.capitalized)."
        }

        // For inspect/explain, include screen state
        if (verb == .inspect || verb == .explain), let summary, !summary.isEmpty {
            base += " " + summary.headline
        }

        return base
    }

    /// Build a system-wide explanation aggregating all registered reader summaries.
    @MainActor
    private static func buildSystemExplanation(
        command: JeevesCommand,
        readers: [ScreenStateReadable]
    ) -> String {
        let verb = command.verb == .inspect ? "Systeeminspectie" : "Systeemoverzicht"
        var lines: [String] = ["\(verb):"]

        let sorted = readers.sorted { $0.screenId.rawValue < $1.screenId.rawValue }
        for reader in sorted {
            let s = reader.summary()
            let status = s.isEmpty ? "geen data" : s.headline
            lines.append("• \(s.screen.title): \(status)")
        }

        if readers.isEmpty {
            lines.append("Geen schermdata beschikbaar.")
        }

        return lines.joined(separator: "\n")
    }
}
