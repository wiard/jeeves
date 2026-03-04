import Foundation

struct Proposal: Codable, Identifiable {
    let proposalId: String
    let createdAtIso: String
    let agentId: String
    let title: String
    let intent: ProposalIntent
    let status: String
    var id: String { proposalId }

    var createdAt: Date? {
        ISO8601DateFormatter().date(from: createdAtIso)
    }

    var isPending: Bool { status == "pending" }
    var isApproved: Bool { status == "approved" }
    var isDenied: Bool { status == "denied" }
}

struct ProposalIntent: Codable {
    let kind: String
    let key: String
    let risk: String
    let requiresConsent: Bool
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
