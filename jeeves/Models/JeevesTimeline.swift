import Foundation

/// Compact event classes for operator-visible timeline entries.
enum JeevesTimelineEventKind: String, Sendable, Equatable {
    case routing
    case command
    case guidance
    case followUp
    case unknownCommand
}

/// One bounded, inspectable operator event in the local timeline.
struct JeevesTimelineEntry: Identifiable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let eventKind: JeevesTimelineEventKind
    let originalInput: String
    let matchedCapabilityId: String?
    let policyMode: JeevesPolicyMode?
    let policyReason: String?
    let recommendationReason: String?
    let finalDirectiveIntent: String
    let finalScreen: AppScreen
    let resultSummary: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventKind: JeevesTimelineEventKind,
        originalInput: String,
        matchedCapabilityId: String?,
        policyMode: JeevesPolicyMode?,
        policyReason: String?,
        recommendationReason: String?,
        finalDirectiveIntent: String,
        finalScreen: AppScreen,
        resultSummary: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventKind = eventKind
        self.originalInput = originalInput
        self.matchedCapabilityId = matchedCapabilityId
        self.policyMode = policyMode
        self.policyReason = policyReason
        self.recommendationReason = recommendationReason
        self.finalDirectiveIntent = finalDirectiveIntent
        self.finalScreen = finalScreen
        self.resultSummary = resultSummary
    }
}

/// Bounded local operator timeline.
/// This stores explicit decision/action events only, not full chat history.
struct JeevesTimelineStore: Sendable {
    private(set) var entries: [JeevesTimelineEntry] = []
    let capacity: Int

    init(capacity: Int = 30) {
        self.capacity = capacity
    }

    mutating func append(_ entry: JeevesTimelineEntry) {
        entries.append(entry)
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    mutating func reset() {
        entries.removeAll()
    }
}
