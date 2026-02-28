import Foundation
import SwiftData

enum MessageSender: String, Codable {
    case user, jeeves, system
}

@Model
final class ChatMessage {
    var id: UUID
    var text: String
    var senderRaw: String
    var timestamp: Date
    // Consent request fields (nil if not a consent message)
    var consentId: String?
    var consentTool: String?
    var consentRiskRaw: String?
    var consentReason: String?
    var consentApproved: Bool?
    var consentRespondedAt: Date?
    // Blocked action fields (nil if not a blocked message)
    var blockedTool: String?
    var blockedRisk: String?
    var blockedReason: String?

    var sender: MessageSender {
        get { MessageSender(rawValue: senderRaw) ?? .system }
        set { senderRaw = newValue.rawValue }
    }

    var consentRisk: RiskLevel? {
        get { consentRiskRaw.flatMap { RiskLevel(rawValue: $0) } }
        set { consentRiskRaw = newValue?.rawValue }
    }

    var isConsentRequest: Bool { consentId != nil }
    var isBlocked: Bool { blockedTool != nil }
    var isConsentPending: Bool { consentId != nil && consentApproved == nil }

    init(
        text: String,
        sender: MessageSender,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.text = text
        self.senderRaw = sender.rawValue
        self.timestamp = timestamp
    }

    /// Create a consent request message
    static func consentRequest(
        consentId: String,
        tool: String,
        risk: RiskLevel,
        reason: String,
        timestamp: Date = Date()
    ) -> ChatMessage {
        let msg = ChatMessage(text: reason, sender: .system, timestamp: timestamp)
        msg.consentId = consentId
        msg.consentTool = tool
        msg.consentRisk = risk
        msg.consentReason = reason
        return msg
    }

    /// Create a blocked action message
    static func blocked(
        tool: String,
        risk: String,
        reason: String,
        timestamp: Date = Date()
    ) -> ChatMessage {
        let msg = ChatMessage(text: reason, sender: .system, timestamp: timestamp)
        msg.blockedTool = tool
        msg.blockedRisk = risk
        msg.blockedReason = reason
        return msg
    }
}
