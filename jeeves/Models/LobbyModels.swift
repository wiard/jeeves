import Foundation

struct Proposal: Codable, Identifiable {
    let proposalId: String
    let createdAtIso: String
    let agentId: String
    let title: String
    let intent: ProposalIntent
    let status: String
    let priorityScore: Double?
    let priorityExplanation: String?
    let rank: Int?
    let priorityFactors: ProposalPriorityFactors?
    var id: String { proposalId }

    var createdAt: Date? {
        ISO8601DateFormatter().date(from: createdAtIso)
    }

    var isPending: Bool { status == "pending" }
    var isApproved: Bool { status == "approved" }
    var isDenied: Bool { status == "denied" }

    var displayPriority: String {
        guard let score = priorityScore, score > 0 else { return "" }
        return "P\(Int(score))"
    }

    var hasAction: Bool {
        isApproved
    }
}

struct ProposalIntent: Codable {
    let kind: String
    let key: String
    let risk: String
    let requiresConsent: Bool
}

struct ProposalPriorityFactors: Codable {
    let riskScore: Double?
    let evidenceStrength: Double?
    let novelty: Double?
    let crossDomainRelevance: Double?
    let escalationSignal: Double?
    let ageUrgency: Double?
    let duplicatePressure: Double?
    let governanceValue: Double?
}

struct Challenge: Codable, Identifiable {
    let challengeId: String
    let title: String
    let description: String
    let domain: String
    let suggestedIntentKey: String
    let maxRisk: String
    let status: String
    var id: String { challengeId }
}

struct AgentRecord: Codable, Identifiable {
    let agentId: String
    let owner: String
    let trust: String
    var id: String { agentId }
}

struct FabricClock: Codable {
    let source: String?
    let tickN: Int?
    let blockHeight: Int?
}

struct EmergenceCluster: Codable, Identifiable {
    let clusterId: String
    let dimensions: [String]
    let relevanceScore: Double
    let summary: String
    let escalatesToIphone: Bool
    var id: String { clusterId }
}

struct DecideRequest: Encodable {
    let proposalId: String
    let decision: String
    let reason: String?
}

struct DecideResponse: Codable {
    let ok: Bool
    let status: String?
    let executed: Bool?
    let reason: String?
    let action: ActionSummary?
}

struct ActionSummary: Codable, Identifiable {
    let actionId: String
    let actionKind: String
    let executionState: String
    let receipt: ActionReceipt?
    var id: String { actionId }

    var isCompleted: Bool { executionState == "completed" }
    var isFailed: Bool { executionState == "failed" }
}

struct ActionReceipt: Codable, Identifiable {
    let receiptId: String
    let actionId: String
    let completedAtIso: String
    let executionState: String
    let resultSummary: String
    let durationMs: Double?
    let resultType: String?
    let outputObjectIds: [String]?
    let notes: String?
    var id: String { receiptId }
}

// MARK: - Decided Proposals

struct DecidedProposal: Codable, Identifiable {
    let proposalId: String
    let title: String
    let agentId: String
    let status: String
    let decidedAtIso: String?
    let decisionReason: String?
    let intent: ProposalIntent?
    let priorityScore: Double?
    let action: ActionSummary?
    var id: String { proposalId }

    var isApproved: Bool { status == "approved" }
    var isDenied: Bool { status == "denied" }

    var decidedAt: Date? {
        guard let iso = decidedAtIso else { return nil }
        return ISO8601DateFormatter().date(from: iso)
    }
}

struct DecidedProposalsEnvelope: Decodable {
    let proposals: [DecidedProposal]?
    let items: [DecidedProposal]?
    let data: [DecidedProposal]?
    let ok: Bool?

    var resolved: [DecidedProposal] {
        proposals ?? items ?? data ?? []
    }
}

// MARK: - Knowledge Graph

struct KnowledgeGraphResponse: Decodable {
    let ok: Bool?
    let root: KnowledgeObject?
    let linked: [KnowledgeObject]?
    let edges: [KnowledgeEdge]?
}

struct KnowledgeEdge: Codable, Identifiable {
    let fromId: String
    let toId: String
    let relation: String?
    var id: String { "\(fromId)->\(toId)" }
}

struct KnowledgeObject: Codable, Identifiable {
    let objectId: String
    let kind: String
    let createdAtIso: String
    let title: String
    let summary: String
    let sourceRefs: [KnowledgeSourceRef]?
    let linkedObjectIds: [String]?
    let metadata: [String: AnyCodableValue]?
    var id: String { objectId }

    var createdAt: Date? {
        ISO8601DateFormatter().date(from: createdAtIso)
    }

    var kindEmoji: String {
        switch kind {
        case "discovery": return "\u{1F50D}"
        case "decision": return "\u{2696}\u{FE0F}"
        case "action_receipt": return "\u{1F4CB}"
        case "investigation_outcome": return "\u{1F9EA}"
        case "evidence": return "\u{1F4CE}"
        case "proposal": return "\u{1F4DD}"
        default: return "\u{1F4E6}"
        }
    }
}

struct KnowledgeSourceRef: Codable {
    let sourceType: String
    let sourceId: String
    let url: String?
    let label: String?
}

struct KnowledgeObjectsEnvelope: Decodable {
    let ok: Bool?
    let objects: [KnowledgeObject]?
}

enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

struct ProposalsEnvelope: Decodable {
    let proposals: [Proposal]?
    let items: [Proposal]?
    let data: [Proposal]?

    var resolved: [Proposal] {
        proposals ?? items ?? data ?? []
    }
}

struct EmergenceEnvelope: Decodable {
    let clusters: [EmergenceCluster]?
    let items: [EmergenceCluster]?
    let data: [EmergenceCluster]?

    var resolved: [EmergenceCluster] {
        clusters ?? items ?? data ?? []
    }
}
