import Foundation
import Observation

// MARK: - Memory Entry

/// A single entry in the session's short-term memory ring buffer.
enum JeevesMemoryEntry: Sendable {
    case screenVisit(AppScreen)
    case directive(String, AppScreen)
    case question(String)
    case explanation(String)

    var timestamp: Date { Date() }
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
        entries.compactMap {
            switch $0 {
            case .screenVisit(let s): return s
            case .directive(_, let s): return s
            default: return nil
            }
        }
    }

    var recentQuestions: [String] {
        entries.compactMap {
            if case .question(let q) = $0 { return q }
            return nil
        }
    }
}

// MARK: - Conversation Context

/// Read-only view of the current session state for orchestrator use.
struct JeevesConversationContext: Sendable {
    let currentScreen: AppScreen
    let lastDirective: JeevesDirective?
    let currentMissionFocus: String?
    let currentBrowserPreset: ScreenStatePreset?
    let lastOperatorQuestion: String?
    let recentScreens: [AppScreen]

    var hasContext: Bool {
        lastDirective != nil || lastOperatorQuestion != nil
    }

    static let empty = JeevesConversationContext(
        currentScreen: .chat,
        lastDirective: nil,
        currentMissionFocus: nil,
        currentBrowserPreset: nil,
        lastOperatorQuestion: nil,
        recentScreens: []
    )
}

// MARK: - Context Snapshot

/// Frozen, inspectable snapshot of the session state.
struct JeevesContextSnapshot: Sendable {
    let sessionId: String
    let startedAt: Date
    let currentScreen: AppScreen
    let lastDirectiveIntent: String?
    let lastDirectiveDestination: AppScreen?
    let currentMissionFocus: String?
    let lastOperatorQuestion: String?
    let entryCount: Int

    var summary: String {
        var lines: [String] = ["Sessie: \(sessionId.prefix(8))"]
        lines.append("Scherm: \(currentScreen.title)")
        if let d = lastDirectiveIntent { lines.append("Laatste directief: \(d)") }
        if let s = lastDirectiveDestination { lines.append("Doelscherm: \(s.title)") }
        if let f = currentMissionFocus { lines.append("Focus: \(f)") }
        if let q = lastOperatorQuestion { lines.append("Laatste vraag: \(q)") }
        lines.append("Geheugenentries: \(entryCount)")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Session

/// Lightweight session-scoped context for operator continuity.
///
/// Tracks current screen, recent directives, operator questions, and
/// mission focus. Designed to be explicit, inspectable, and easy to reset.
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
    private(set) var lastOperatorQuestion: String?
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

    func recordQuestion(_ text: String) {
        lastOperatorQuestion = text
        memory.append(.question(text))
    }

    func recordExplanation(_ text: String) {
        memory.append(.explanation(text))
    }

    // MARK: - Context & Snapshot

    func context() -> JeevesConversationContext {
        JeevesConversationContext(
            currentScreen: currentScreen,
            lastDirective: lastDirective,
            currentMissionFocus: currentMissionFocus,
            currentBrowserPreset: currentBrowserPreset,
            lastOperatorQuestion: lastOperatorQuestion,
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
            lastOperatorQuestion: lastOperatorQuestion,
            entryCount: memory.entries.count
        )
    }

    // MARK: - Reset

    func reset() {
        lastDirective = nil
        currentMissionFocus = nil
        currentBrowserPreset = nil
        lastOperatorQuestion = nil
        memory.reset()
    }
}
