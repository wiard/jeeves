
import Foundation

struct DailyBriefing: Codable, Identifiable {
    var id: String { generatedAtIso }

    let generatedAtIso: String
    let headline: String
    let statusLine: String
    let quiet: Bool
    let overview: [String]
    let counts: DailyBriefingCounts
    let system: DailyBriefingSystem
    let attention: [DailyBriefingItem]
    let signals: [DailyBriefingSignalGroup]
    let pendingProposals: [Proposal]
    let evidence: [KnowledgeObject]
    let lastSignalAtIso: String?
    let lastKnowledgeAtIso: String?
    let discoveryPulse: BriefingDiscoveryPulse?
}

struct DailyBriefingCounts: Codable, Hashable {
    let pendingApprovals: Int
    let groupedSignals: Int
    let recentEvidence: Int
    let knowledgeSignals24h: Int
    let stale: Bool
}

struct DailyBriefingSystem: Codable, Hashable {
    let conductor: DailyBriefingSubsystemStatus
    let signalRuntime: DailyBriefingSignalRuntimeStatus
    let knowledge: DailyBriefingKnowledgeStatus
    let freshness: DailyBriefingFreshnessStatus
}

struct DailyBriefingSubsystemStatus: Codable, Hashable {
    let status: String
    let pendingApprovals: Int?
}

struct DailyBriefingSignalRuntimeStatus: Codable, Hashable {
    let status: String
    let started: Bool?
    let lastRunAtIso: String?
    let lastError: String?
}

struct DailyBriefingKnowledgeStatus: Codable, Hashable {
    let status: String
    let lastScanAtIso: String?
    let last24hSignalsCount: Int?
    let topCubeCells: [String]
}

struct DailyBriefingFreshnessStatus: Codable, Hashable {
    let status: String
    let lastSignalAtIso: String?
    let lastKnowledgeAtIso: String?
}

struct DailyBriefingItem: Codable, Identifiable, Hashable {
    let itemId: String
    let kind: String
    let title: String
    let summary: String
    let why: String
    let score: Double
    let createdAtIso: String?
    let sourceCount: Int
    let objectId: String?
    let proposalId: String?
    let relatedObjectIds: [String]

    var id: String { itemId }

    var createdAt: Date? {
        guard let createdAtIso else { return nil }
        return ISO8601DateFormatter().date(from: createdAtIso)
    }
}

struct DailyBriefingSignalGroup: Codable, Identifiable, Hashable {
    let groupId: String
    let title: String
    let summary: String
    let why: String
    let latestDetectedAtIso: String
    let signalCount: Int
    let sourceCount: Int
    let sources: [String]
    let relatedObjectIds: [String]

    var id: String { groupId }
}

struct BriefingDiscoveryPulseCell: Codable, Hashable {
    let cellId: String
    let title: String
    let intensity: String
    let clusterCount: Int
    let topHint: String?
}

struct BriefingDiscoveryPulse: Codable, Hashable {
    let cells: [BriefingDiscoveryPulseCell]
    let summary: String
}

struct DailyBriefingEnvelope: Decodable {
    let ok: Bool?
    let briefing: DailyBriefing?
    let data: DailyBriefing?
}
