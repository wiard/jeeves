import Foundation
import Observation

// MARK: - Memory Entry

/// A single entry in the session's operational trail.
/// Tracks screen navigation and directives only — not raw operator text.
enum JeevesMemoryEntry: Sendable {
    case screenVisit(AppScreen)
    case directive(String, AppScreen)
}

// MARK: - Memory Store

/// Ring-buffer store for recent session entries.
/// Keeps the last `capacity` entries and discards older ones.
struct JeevesMemoryStore: Sendable {
    private(set) var entries: [JeevesMemoryEntry] = []
    let capacity: Int

    init(capacity: Int = 20) {
        self.capacity = capacity
    }

    mutating func append(_ entry: JeevesMemoryEntry) {
        entries.append(entry)
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    mutating func reset() {
        entries.removeAll()
    }

    var recentScreens: [AppScreen] {
        entries.map {
            switch $0 {
            case .screenVisit(let s): return s
            case .directive(_, let s): return s
            }
        }
    }
}

// MARK: - Session Context

/// Read-only view of the current operator session state for orchestrator use.
/// Contains only screen/directive state — no raw operator text.
struct JeevesSessionContext: Sendable {
    let currentScreen: AppScreen
    let lastDirective: JeevesDirective?
    let currentMissionFocus: String?
    let currentBrowserPreset: ScreenStatePreset?
    let recentScreens: [AppScreen]

    /// True only when there is a previous directive to continue from.
    var hasDirectiveContext: Bool {
        lastDirective != nil
    }

    static let empty = JeevesSessionContext(
        currentScreen: .chat,
        lastDirective: nil,
        currentMissionFocus: nil,
        currentBrowserPreset: nil,
        recentScreens: []
    )
}

// MARK: - Context Snapshot

/// Frozen, inspectable snapshot of the operator session state.
struct JeevesContextSnapshot: Sendable {
    let sessionId: String
    let startedAt: Date
    let currentScreen: AppScreen
    let lastDirectiveIntent: String?
    let lastDirectiveDestination: AppScreen?
    let currentMissionFocus: String?
    let entryCount: Int

    var summary: String {
        var lines: [String] = ["Sessie: \(sessionId.prefix(8))"]
        lines.append("Scherm: \(currentScreen.title)")
        if let d = lastDirectiveIntent { lines.append("Laatste directief: \(d)") }
        if let s = lastDirectiveDestination { lines.append("Doelscherm: \(s.title)") }
        if let f = currentMissionFocus { lines.append("Focus: \(f)") }
        lines.append("Geheugenentries: \(entryCount)")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Session

/// Lightweight session-scoped context for operator continuity.
///
/// Tracks current screen, recent directives, and mission focus.
/// Designed to be explicit, inspectable, and easy to reset.
/// Does not bypass governance or gateway routing.
@MainActor
@Observable
final class JeevesSession {
    let sessionId: String
    let startedAt: Date

    private(set) var currentScreen: AppScreen = .chat
    private(set) var lastDirective: JeevesDirective?
    private(set) var currentMissionFocus: String?
    private(set) var currentBrowserPreset: ScreenStatePreset?
    private(set) var memory = JeevesMemoryStore()

    init() {
        self.sessionId = UUID().uuidString
        self.startedAt = Date()
    }

    // MARK: - Recording

    func recordScreenChange(_ screen: AppScreen) {
        currentScreen = screen
        memory.append(.screenVisit(screen))
    }

    func recordDirective(_ directive: JeevesDirective) {
        lastDirective = directive
        currentScreen = directive.destination

        if directive.destination == .stream {
            currentMissionFocus = directive.section
        }
        if directive.destination == .aiBrowser {
            currentBrowserPreset = directive.statePreset
        }

        memory.append(.directive(directive.intent, directive.destination))
    }

    // MARK: - Context & Snapshot

    func context() -> JeevesSessionContext {
        JeevesSessionContext(
            currentScreen: currentScreen,
            lastDirective: lastDirective,
            currentMissionFocus: currentMissionFocus,
            currentBrowserPreset: currentBrowserPreset,
            recentScreens: memory.recentScreens
        )
    }

    func snapshot() -> JeevesContextSnapshot {
        JeevesContextSnapshot(
            sessionId: sessionId,
            startedAt: startedAt,
            currentScreen: currentScreen,
            lastDirectiveIntent: lastDirective?.intent,
            lastDirectiveDestination: lastDirective?.destination,
            currentMissionFocus: currentMissionFocus,
            entryCount: memory.entries.count
        )
    }

    // MARK: - Reset

    func reset() {
        lastDirective = nil
        currentMissionFocus = nil
        currentBrowserPreset = nil
        memory.reset()
    }
}
