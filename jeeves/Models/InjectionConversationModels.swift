import Foundation

// MARK: - Conversation request / response

struct InjectionConversationRequest: Encodable, Sendable {
    let message: String
}

struct InjectionConversationEnvelope: Decodable, Sendable {
    let ok: Bool?
    let reply: InjectionConversationReply
    let findings: [InjectionFindingSnapshot]?
}

struct InjectionConversationReply: Decodable, Sendable, Identifiable {
    let id: String
    let text: String
    let timestamp: String

    private enum CodingKeys: String, CodingKey {
        case id, text, timestamp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        text = try c.decode(String.self, forKey: .text)
        timestamp = (try? c.decode(String.self, forKey: .timestamp)) ?? ISO8601DateFormatter().string(from: Date())
    }

    init(id: String, text: String, timestamp: String) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - Chat bubble model

struct InjectionChatMessage: Identifiable {
    enum Role { case operator_, robot }

    let id: String
    let role: Role
    let text: String
    let timestamp: Date

    init(role: Role, text: String) {
        self.id = UUID().uuidString
        self.role = role
        self.text = text
        self.timestamp = Date()
    }

    init(reply: InjectionConversationReply) {
        self.id = reply.id
        self.role = .robot
        self.text = reply.text
        self.timestamp = ISO8601DateFormatter().date(from: reply.timestamp) ?? Date()
    }
}
