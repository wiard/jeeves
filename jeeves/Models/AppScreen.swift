import Foundation

/// Central screen registry for the Jeeves app.
/// Replaces magic tab indices with a type-safe enum.
enum AppScreen: Int, CaseIterable, Identifiable, Sendable, Hashable {
    case stream      = 0
    case lobby       = 1
    case chat        = 2
    case observatory = 3
    case house       = 4
    case logbook     = 5
    case aiBrowser   = 6
    case settings    = 7
    case vandaag     = 8
    case zoeker      = 9
    case beslissingen = 10
    case research    = 11
    case kanaal      = 12

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .stream:      return "Mission Control"
        case .lobby:       return "Lobby"
        case .chat:        return "Jeeves"
        case .observatory: return "Observatory"
        case .house:       return "Knowledge"
        case .logbook:     return "Logbook"
        case .aiBrowser:   return "AI Browser"
        case .settings:    return "System"
        case .vandaag:     return "Vandaag"
        case .zoeker:      return "De Zoeker"
        case .beslissingen:return "Beslissingen"
        case .research:    return "Disciplines"
        case .kanaal:      return "Kanaal"
        }
    }

    var icon: String {
        switch self {
        case .stream:      return "list.bullet"
        case .lobby:       return "tray.full"
        case .chat:        return "bubble.left.fill"
        case .observatory: return "binoculars"
        case .house:       return "house.fill"
        case .logbook:     return "scroll.fill"
        case .aiBrowser:   return "sparkle.magnifyingglass"
        case .settings:    return "gearshape.fill"
        case .vandaag:     return "house.fill"
        case .zoeker:      return "circle.grid.3x3.fill"
        case .beslissingen:return "checkmark.circle.fill"
        case .research:    return "magnifyingglass.circle.fill"
        case .kanaal:      return "message.fill"
        }
    }

    /// Known sub-sections addressable by the orchestrator.
    var sections: [String] {
        switch self {
        case .stream:      return ["discovery", "governance", "knowledge", "trust", "proposals", "radar", "emergence", "signals", "discoveries"]
        case .lobby:       return ["gaps", "extensions", "challenges", "environments"]
        case .observatory: return ["oracle", "loop", "fabric", "lobby", "signals", "knowledge", "radar", "discovery", "alerts"]
        case .house:       return ["library", "discoveries", "evidence", "codeSignals", "memory"]
        case .aiBrowser:   return ["marketplace", "deployments", "myAgents"]
        case .vandaag:     return ["bieb", "latest", "queue"]
        case .zoeker:      return ["heatmap", "cells", "radar"]
        case .beslissingen:return ["gaps", "queue", "review"]
        case .research:    return ["disciplines", "gaps", "detail"]
        case .kanaal:      return ["chat", "commands", "decisions"]
        case .logbook:     return []
        case .chat:        return []
        case .settings:    return ["connection", "security", "systemState"]
        }
    }
}
