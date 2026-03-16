import Foundation

struct GapProposalResponse: Decodable {
    let ok: Bool
    let gaps: [GapProposal]
    let statusSummary: GapStatusSummary

    private enum CodingKeys: String, CodingKey {
        case ok
        case gaps
        case statusSummary
    }

    init(ok: Bool = true, gaps: [GapProposal], statusSummary: GapStatusSummary) {
        self.ok = ok
        self.gaps = gaps
        self.statusSummary = statusSummary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedGaps = try container.decodeIfPresent([GapProposal].self, forKey: .gaps) ?? []
        ok = try container.decodeIfPresent(Bool.self, forKey: .ok) ?? true
        gaps = decodedGaps
        statusSummary = try container.decodeIfPresent(GapStatusSummary.self, forKey: .statusSummary)
            ?? GapStatusSummary.from(gaps: decodedGaps)
    }
}

struct GapProposal: Decodable, Identifiable, Hashable {
    let gapId: String
    let gapProposalId: String
    let title: String
    let status: String
    let summary: String?
    let source: String?
    let gapType: String?
    let risk: String?
    let detectedAtIso: String?
    let proposedAtIso: String?
    let metadata: Metadata?
    let reviewProposal: ReviewProposal?

    var id: String { gapId }
    var hypothesis: String? { metadata?.hypothesis?.statement }
    var score: Double? { metadata?.scores?.total }
    var trustBoundary: String? { metadata?.trust?.boundary }
    var reviewStatus: String? { reviewProposal?.status }
    var priorityScore: Int? { reviewProposal?.priorityScore }

    var displayTitle: String {
        let stripped = title.replacingOccurrences(
            of: "Gap proposal: ",
            with: "",
            options: [.caseInsensitive]
        )
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled research frontier" : trimmed
    }

    var displayHypothesis: String {
        let candidate = (hypothesis ?? summary ?? "The system found a research frontier that may be worth your attention.")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return candidate.isEmpty ? "The system found a research frontier that may be worth your attention." : candidate
    }

    var displayScore: String {
        guard let score else { return "No score" }
        return String(format: "%.2f", score)
    }

    var confidenceLabel: String {
        switch score ?? 0 {
        case 0.7...:
            return "Strong signal"
        case 0.5..<0.7:
            return "Worth a look"
        default:
            return "Weak signal"
        }
    }

    var isPendingReview: Bool {
        let normalizedStatus = status.lowercased()
        let normalizedReview = reviewStatus?.lowercased() ?? ""
        return normalizedStatus == "proposed" || normalizedReview == "pending"
    }

    struct Metadata: Decodable, Hashable {
        let hypothesis: Hypothesis?
        let scores: Scores?
        let trust: Trust?
    }

    struct Hypothesis: Decodable, Hashable {
        let statement: String?
    }

    struct Scores: Decodable, Hashable {
        let total: Double?
    }

    struct Trust: Decodable, Hashable {
        let boundary: String?
    }

    struct ReviewProposal: Decodable, Hashable {
        let status: String?
        let priorityScore: Int?
    }
}

struct GapStatusSummary: Decodable, Hashable {
    let detected: Int
    let proposed: Int
    let approved: Int
    let denied: Int
    let executed: Int
    let archived: Int

    init(
        detected: Int = 0,
        proposed: Int = 0,
        approved: Int = 0,
        denied: Int = 0,
        executed: Int = 0,
        archived: Int = 0
    ) {
        self.detected = detected
        self.proposed = proposed
        self.approved = approved
        self.denied = denied
        self.executed = executed
        self.archived = archived
    }

    static func from(gaps: [GapProposal]) -> GapStatusSummary {
        var summary = GapStatusSummary()

        for gap in gaps {
            switch gap.status.lowercased() {
            case "detected":
                summary = GapStatusSummary(
                    detected: summary.detected + 1,
                    proposed: summary.proposed,
                    approved: summary.approved,
                    denied: summary.denied,
                    executed: summary.executed,
                    archived: summary.archived
                )
            case "approved":
                summary = GapStatusSummary(
                    detected: summary.detected,
                    proposed: summary.proposed,
                    approved: summary.approved + 1,
                    denied: summary.denied,
                    executed: summary.executed,
                    archived: summary.archived
                )
            case "denied":
                summary = GapStatusSummary(
                    detected: summary.detected,
                    proposed: summary.proposed,
                    approved: summary.approved,
                    denied: summary.denied + 1,
                    executed: summary.executed,
                    archived: summary.archived
                )
            case "executed":
                summary = GapStatusSummary(
                    detected: summary.detected,
                    proposed: summary.proposed,
                    approved: summary.approved,
                    denied: summary.denied,
                    executed: summary.executed + 1,
                    archived: summary.archived
                )
            case "archived":
                summary = GapStatusSummary(
                    detected: summary.detected,
                    proposed: summary.proposed,
                    approved: summary.approved,
                    denied: summary.denied,
                    executed: summary.executed,
                    archived: summary.archived + 1
                )
            default:
                summary = GapStatusSummary(
                    detected: summary.detected,
                    proposed: summary.proposed + 1,
                    approved: summary.approved,
                    denied: summary.denied,
                    executed: summary.executed,
                    archived: summary.archived
                )
            }
        }

        return summary
    }
}

struct GapProposalDecisionRequest: Encodable {
    let gapProposalId: String
    let decision: String
}

struct GapProposalDecisionResponse: Decodable {
    let ok: Bool
    let status: String?
    let reason: String?
}
