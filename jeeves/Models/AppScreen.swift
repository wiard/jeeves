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

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .stream:      return "Mission Control"
        case .lobby:       return "Lobby"
        case .chat:        return "Jeeves"
        case .observatory: return "Observatory"
        case .house:       return "Huis"
        case .logbook:     return "Logboek"
        case .aiBrowser:   return "AI Browser"
        case .settings:    return "Instellingen"
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
        }
    }

    /// Known sub-sections addressable by the orchestrator.
    var sections: [String] {
        switch self {
        case .stream:      return ["proposals", "radar", "emergence", "signals", "discoveries", "knowledge"]
        case .lobby:       return ["extensions", "challenges", "environments"]
        case .observatory: return ["oracle", "loop", "fabric", "lobby", "signals", "knowledge", "radar", "discovery", "alerts"]
        case .house:       return ["kernel", "budget", "channels", "killSwitch"]
        case .aiBrowser:   return ["marketplace", "deployments", "myAgents"]
        case .logbook:     return []
        case .chat:        return []
        case .settings:    return ["connection", "security"]
        }
    }
}
