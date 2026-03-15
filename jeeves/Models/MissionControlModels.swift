import Foundation

enum GovernedBootstrapPhase: Int, Sendable {
    case coldStart = 0
    case kernelFirst = 1
    case firstNode = 2
    case correlatedNetwork = 3
    case learningActive = 4

    var title: String {
        switch self {
        case .coldStart: return "Cold Start"
        case .kernelFirst: return "Kernel First"
        case .firstNode: return "First Node"
        case .correlatedNetwork: return "Correlated Network"
        case .learningActive: return "Learning Active"
        }
    }

    var displayLabel: String {
        "Phase \(rawValue) · \(title)"
    }
}

struct GovernedBootstrapSnapshot: Sendable {
    let phase: GovernedBootstrapPhase
    let proofAchieved: String
    let nextProof: String

    static func derive(
        status: GatewayStatus?,
        proposals: [Proposal],
        residue: GridResidueSummarySnapshot?
    ) -> GovernedBootstrapSnapshot {
        let kernelVisible = status != nil
        let firstNodeVisible = proposals.contains { proposal in
            proposal.isGridProposal
                && !proposal.isCorrelatedGridEvent
                && (proposal.gridNodeId != nil || proposal.gridOriginSignalId != nil)
        }
        let correlatedVisible = proposals.contains(where: { $0.isCorrelatedGridEvent })
        let learningVisible = (residue?.totalEntries ?? 0) > 0

        let phase: GovernedBootstrapPhase
        if learningVisible {
            phase = .learningActive
        } else if correlatedVisible {
            phase = .correlatedNetwork
        } else if firstNodeVisible {
            phase = .firstNode
        } else if kernelVisible {
            phase = .kernelFirst
        } else {
            phase = .coldStart
        }

        switch phase {
        case .coldStart:
            return .init(
                phase: phase,
                proofAchieved: "No governed bootstrap proof is visible yet.",
                nextProof: "Make the kernel visible so status is live."
            )
        case .kernelFirst:
            return .init(
                phase: phase,
                proofAchieved: "The kernel is visible and already valuable locally.",
                nextProof: "Accept the first node signal so one [GRID] proposal appears."
            )
        case .firstNode:
            return .init(
                phase: phase,
                proofAchieved: "A first node has already produced a governed [GRID] proposal.",
                nextProof: "Correlate three related node signals into one stronger proposal."
            )
        case .correlatedNetwork:
            return .init(
                phase: phase,
                proofAchieved: "The kernel has already grouped a real multi-node grid event.",
                nextProof: "Approve proposals so residue starts to accumulate."
            )
        case .learningActive:
            return .init(
                phase: phase,
                proofAchieved: "Residue is active, so approved decisions now inform later interpretation.",
                nextProof: "Continue governed approvals and let the loop compound."
            )
        }
    }
}

struct RecentGridSignal: Decodable, Identifiable, Hashable, Sendable {
    let signalId: String
    let nodeId: String
    let region: String
    let signalType: String
    let severity: String
    let timestamp: String

    var id: String { signalId }

    private enum CodingKeys: String, CodingKey {
        case signalId
        case signal_id
        case nodeId
        case node_id
        case region
        case signalType
        case signal_type
        case severity
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        signalId = (try? container.decodeIfPresent(String.self, forKey: .signalId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .signal_id))
            ?? ""
        nodeId = (try? container.decodeIfPresent(String.self, forKey: .nodeId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .node_id))
            ?? ""
        region = (try? container.decodeIfPresent(String.self, forKey: .region)) ?? ""
        signalType = (try? container.decodeIfPresent(String.self, forKey: .signalType))
            ?? (try? container.decodeIfPresent(String.self, forKey: .signal_type))
            ?? ""
        severity = (try? container.decodeIfPresent(String.self, forKey: .severity)) ?? ""
        timestamp = (try? container.decodeIfPresent(String.self, forKey: .timestamp)) ?? ""
    }
}

struct RecentGridSignalsEnvelope: Decodable {
    let signals: [RecentGridSignal]
}

struct GridResidueNodeSummary: Decodable, Hashable, Sendable {
    let nodeId: String
    let residue: Double

    private enum CodingKeys: String, CodingKey {
        case nodeId
        case node_id
        case residue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodeId = (try? container.decodeIfPresent(String.self, forKey: .nodeId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .node_id))
            ?? ""
        residue = (try? container.decodeIfPresent(Double.self, forKey: .residue)) ?? 0
    }
}

struct GridResidueRegionSummary: Decodable, Hashable, Sendable {
    let region: String
    let residue: Double
}

struct GridResidueSignalTypeSummary: Decodable, Hashable, Sendable {
    let type: String
    let residue: Double

    private enum CodingKeys: String, CodingKey {
        case type
        case signalType
        case signal_type
        case residue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? container.decodeIfPresent(String.self, forKey: .type))
            ?? (try? container.decodeIfPresent(String.self, forKey: .signalType))
            ?? (try? container.decodeIfPresent(String.self, forKey: .signal_type))
            ?? ""
        residue = (try? container.decodeIfPresent(Double.self, forKey: .residue)) ?? 0
    }
}

struct GridResidueSummarySnapshot: Decodable, Sendable {
    let nodes: [GridResidueNodeSummary]
    let regions: [GridResidueRegionSummary]
    let signalTypes: [GridResidueSignalTypeSummary]
    let totalEntries: Int

    private enum CodingKeys: String, CodingKey {
        case nodes
        case regions
        case signalTypes
        case signal_types
        case totalEntries
        case total_entries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = (try? container.decodeIfPresent([GridResidueNodeSummary].self, forKey: .nodes)) ?? []
        regions = (try? container.decodeIfPresent([GridResidueRegionSummary].self, forKey: .regions)) ?? []
        signalTypes = (try? container.decodeIfPresent([GridResidueSignalTypeSummary].self, forKey: .signalTypes))
            ?? (try? container.decodeIfPresent([GridResidueSignalTypeSummary].self, forKey: .signal_types))
            ?? []
        totalEntries = (try? container.decodeIfPresent(Int.self, forKey: .totalEntries))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .total_entries))
            ?? 0
    }
}

struct GridResidueHistoryEvent: Decodable, Identifiable, Hashable, Sendable {
    let timestamp: String
    let region: String
    let nodeId: String
    let residueValue: Double

    var id: String { "\(timestamp):\(region):\(nodeId)" }

    private enum CodingKeys: String, CodingKey {
        case timestamp
        case region
        case nodeId
        case node_id
        case residueValue
        case residue_value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = (try? container.decodeIfPresent(String.self, forKey: .timestamp)) ?? ""
        region = (try? container.decodeIfPresent(String.self, forKey: .region)) ?? ""
        nodeId = (try? container.decodeIfPresent(String.self, forKey: .nodeId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .node_id))
            ?? ""
        residueValue = (try? container.decodeIfPresent(Double.self, forKey: .residueValue))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .residue_value))
            ?? 0
    }
}

struct GridResidueHistoryEnvelope: Decodable {
    let events: [GridResidueHistoryEvent]
}

struct GridResidueFieldSignalFamilySummary: Decodable, Hashable, Sendable {
    let family: String
    let residue: Double
}

struct GridResidueRepeatedPatternSummary: Decodable, Identifiable, Hashable, Sendable {
    let patternId: String
    let region: String
    let signalFamily: String
    let occurrenceCount: Int
    let confirmedCount: Int
    let averageConfidence: Double

    var id: String { patternId }

    private enum CodingKeys: String, CodingKey {
        case patternId
        case pattern_id
        case region
        case signalFamily
        case signal_family
        case occurrenceCount
        case occurrence_count
        case confirmedCount
        case confirmed_count
        case averageConfidence
        case average_confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        patternId = (try? container.decodeIfPresent(String.self, forKey: .patternId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .pattern_id))
            ?? UUID().uuidString
        region = (try? container.decodeIfPresent(String.self, forKey: .region)) ?? ""
        signalFamily = (try? container.decodeIfPresent(String.self, forKey: .signalFamily))
            ?? (try? container.decodeIfPresent(String.self, forKey: .signal_family))
            ?? ""
        occurrenceCount = (try? container.decodeIfPresent(Int.self, forKey: .occurrenceCount))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .occurrence_count))
            ?? 0
        confirmedCount = (try? container.decodeIfPresent(Int.self, forKey: .confirmedCount))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .confirmed_count))
            ?? 0
        averageConfidence = (try? container.decodeIfPresent(Double.self, forKey: .averageConfidence))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .average_confidence))
            ?? 0
    }
}

struct GridResidueFieldSnapshot: Decodable, Sendable {
    let activeNodeCount: Int
    let activeRegionCount: Int
    let activeSignalFamilyCount: Int
    let fieldMaturity: String
    let topNodes: [GridResidueNodeSummary]
    let topRegions: [GridResidueRegionSummary]
    let topSignalFamilies: [GridResidueFieldSignalFamilySummary]
    let repeatedPatterns: [GridResidueRepeatedPatternSummary]

    private enum CodingKeys: String, CodingKey {
        case activeNodeCount
        case active_node_count
        case activeRegionCount
        case active_region_count
        case activeSignalFamilyCount
        case active_signal_family_count
        case fieldMaturity
        case field_maturity
        case topNodes
        case top_nodes
        case topRegions
        case top_regions
        case topSignalFamilies
        case top_signal_families
        case repeatedPatterns
        case repeated_patterns
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeNodeCount = (try? container.decodeIfPresent(Int.self, forKey: .activeNodeCount))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .active_node_count))
            ?? 0
        activeRegionCount = (try? container.decodeIfPresent(Int.self, forKey: .activeRegionCount))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .active_region_count))
            ?? 0
        activeSignalFamilyCount = (try? container.decodeIfPresent(Int.self, forKey: .activeSignalFamilyCount))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .active_signal_family_count))
            ?? 0
        fieldMaturity = (try? container.decodeIfPresent(String.self, forKey: .fieldMaturity))
            ?? (try? container.decodeIfPresent(String.self, forKey: .field_maturity))
            ?? "sparse"
        topNodes = (try? container.decodeIfPresent([GridResidueNodeSummary].self, forKey: .topNodes))
            ?? (try? container.decodeIfPresent([GridResidueNodeSummary].self, forKey: .top_nodes))
            ?? []
        topRegions = (try? container.decodeIfPresent([GridResidueRegionSummary].self, forKey: .topRegions))
            ?? (try? container.decodeIfPresent([GridResidueRegionSummary].self, forKey: .top_regions))
            ?? []
        topSignalFamilies = (try? container.decodeIfPresent([GridResidueFieldSignalFamilySummary].self, forKey: .topSignalFamilies))
            ?? (try? container.decodeIfPresent([GridResidueFieldSignalFamilySummary].self, forKey: .top_signal_families))
            ?? []
        repeatedPatterns = (try? container.decodeIfPresent([GridResidueRepeatedPatternSummary].self, forKey: .repeatedPatterns))
            ?? (try? container.decodeIfPresent([GridResidueRepeatedPatternSummary].self, forKey: .repeated_patterns))
            ?? []
    }
}

struct AutonomousDecisionRecordSnapshot: Decodable, Identifiable, Hashable, Sendable {
    let decisionId: String
    let candidateId: String
    let candidateType: String
    let decisionType: String
    let theme: String
    let region: String?
    let signalFamily: String?
    let decidedAt: String
    let outcomeStatus: String
    let outcomeSignal: String
    let residueValue: Double
    let summary: String

    var id: String { decisionId }

    private enum CodingKeys: String, CodingKey {
        case decisionId
        case decision_id
        case candidateId
        case candidate_id
        case candidateType
        case candidate_type
        case decisionType
        case decision_type
        case theme
        case region
        case signalFamily
        case signal_family
        case decidedAt
        case decided_at
        case outcomeStatus
        case outcome_status
        case outcomeSignal
        case outcome_signal
        case residueValue
        case residue_value
        case summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        decisionId = (try? container.decodeIfPresent(String.self, forKey: .decisionId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .decision_id))
            ?? UUID().uuidString
        candidateId = (try? container.decodeIfPresent(String.self, forKey: .candidateId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .candidate_id))
            ?? ""
        candidateType = (try? container.decodeIfPresent(String.self, forKey: .candidateType))
            ?? (try? container.decodeIfPresent(String.self, forKey: .candidate_type))
            ?? ""
        decisionType = (try? container.decodeIfPresent(String.self, forKey: .decisionType))
            ?? (try? container.decodeIfPresent(String.self, forKey: .decision_type))
            ?? ""
        theme = (try? container.decodeIfPresent(String.self, forKey: .theme)) ?? ""
        region = (try? container.decodeIfPresent(String.self, forKey: .region)) ?? nil
        signalFamily = (try? container.decodeIfPresent(String.self, forKey: .signalFamily))
            ?? (try? container.decodeIfPresent(String.self, forKey: .signal_family))
            ?? nil
        decidedAt = (try? container.decodeIfPresent(String.self, forKey: .decidedAt))
            ?? (try? container.decodeIfPresent(String.self, forKey: .decided_at))
            ?? ""
        outcomeStatus = (try? container.decodeIfPresent(String.self, forKey: .outcomeStatus))
            ?? (try? container.decodeIfPresent(String.self, forKey: .outcome_status))
            ?? "pending"
        outcomeSignal = (try? container.decodeIfPresent(String.self, forKey: .outcomeSignal))
            ?? (try? container.decodeIfPresent(String.self, forKey: .outcome_signal))
            ?? ""
        residueValue = (try? container.decodeIfPresent(Double.self, forKey: .residueValue))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .residue_value))
            ?? 0
        summary = (try? container.decodeIfPresent(String.self, forKey: .summary)) ?? ""
    }
}

struct DecisionAutonomyStateSnapshot: Decodable, Sendable {
    let generatedAt: String
    let recentAutonomousDecisions: [AutonomousDecisionRecordSnapshot]
    let successRate: Double
    let autonomousResidue: Double
    let domainsCurrentlyAllowed: [String]
    let stillRequiresHumanApproval: [String]

    private enum CodingKeys: String, CodingKey {
        case generatedAt
        case generated_at
        case recentAutonomousDecisions
        case recent_autonomous_decisions
        case successRate
        case success_rate
        case autonomousResidue
        case autonomous_residue
        case domainsCurrentlyAllowed
        case domains_currently_allowed
        case stillRequiresHumanApproval
        case still_requires_human_approval
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = (try? container.decodeIfPresent(String.self, forKey: .generatedAt))
            ?? (try? container.decodeIfPresent(String.self, forKey: .generated_at))
            ?? ""
        recentAutonomousDecisions = (try? container.decodeIfPresent([AutonomousDecisionRecordSnapshot].self, forKey: .recentAutonomousDecisions))
            ?? (try? container.decodeIfPresent([AutonomousDecisionRecordSnapshot].self, forKey: .recent_autonomous_decisions))
            ?? []
        successRate = (try? container.decodeIfPresent(Double.self, forKey: .successRate))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .success_rate))
            ?? 0
        autonomousResidue = (try? container.decodeIfPresent(Double.self, forKey: .autonomousResidue))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .autonomous_residue))
            ?? 0
        domainsCurrentlyAllowed = (try? container.decodeIfPresent([String].self, forKey: .domainsCurrentlyAllowed))
            ?? (try? container.decodeIfPresent([String].self, forKey: .domains_currently_allowed))
            ?? []
        stillRequiresHumanApproval = (try? container.decodeIfPresent([String].self, forKey: .stillRequiresHumanApproval))
            ?? (try? container.decodeIfPresent([String].self, forKey: .still_requires_human_approval))
            ?? []
    }
}

struct RealityAuditSnapshot: Decodable, Identifiable, Hashable, Sendable {
    let auditId: String
    let targetDecisionId: String
    let anomalyScore: Double
    let entropyDelta: Double
    let contradictionSignals: [String]
    let adjustedConfidence: Double
    let auditSummary: String
    let decisionType: String
    let theme: String
    let region: String?
    let signalFamily: String?
    let originalConfidence: Double

    var id: String { auditId }

    private enum CodingKeys: String, CodingKey {
        case auditId
        case audit_id
        case targetDecisionId
        case target_decision_id
        case anomalyScore
        case anomaly_score
        case entropyDelta
        case entropy_delta
        case contradictionSignals
        case contradiction_signals
        case adjustedConfidence
        case adjusted_confidence
        case auditSummary
        case audit_summary
        case decisionType
        case decision_type
        case theme
        case region
        case signalFamily
        case signal_family
        case originalConfidence
        case original_confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        auditId = (try? container.decodeIfPresent(String.self, forKey: .auditId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .audit_id))
            ?? UUID().uuidString
        targetDecisionId = (try? container.decodeIfPresent(String.self, forKey: .targetDecisionId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .target_decision_id))
            ?? ""
        anomalyScore = (try? container.decodeIfPresent(Double.self, forKey: .anomalyScore))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .anomaly_score))
            ?? 0
        entropyDelta = (try? container.decodeIfPresent(Double.self, forKey: .entropyDelta))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .entropy_delta))
            ?? 0
        contradictionSignals = (try? container.decodeIfPresent([String].self, forKey: .contradictionSignals))
            ?? (try? container.decodeIfPresent([String].self, forKey: .contradiction_signals))
            ?? []
        adjustedConfidence = (try? container.decodeIfPresent(Double.self, forKey: .adjustedConfidence))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .adjusted_confidence))
            ?? 0
        auditSummary = (try? container.decodeIfPresent(String.self, forKey: .auditSummary))
            ?? (try? container.decodeIfPresent(String.self, forKey: .audit_summary))
            ?? ""
        decisionType = (try? container.decodeIfPresent(String.self, forKey: .decisionType))
            ?? (try? container.decodeIfPresent(String.self, forKey: .decision_type))
            ?? ""
        theme = (try? container.decodeIfPresent(String.self, forKey: .theme)) ?? ""
        region = (try? container.decodeIfPresent(String.self, forKey: .region)) ?? nil
        signalFamily = (try? container.decodeIfPresent(String.self, forKey: .signalFamily))
            ?? (try? container.decodeIfPresent(String.self, forKey: .signal_family))
            ?? nil
        originalConfidence = (try? container.decodeIfPresent(Double.self, forKey: .originalConfidence))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .original_confidence))
            ?? 0
    }
}

struct RealityAuditTrendSnapshot: Decodable, Sendable {
    let direction: String
    let averageEntropyDelta: Double
    let averageAdjustedConfidence: Double

    private enum CodingKeys: String, CodingKey {
        case direction
        case averageEntropyDelta
        case average_entropy_delta
        case averageAdjustedConfidence
        case average_adjusted_confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        direction = (try? container.decodeIfPresent(String.self, forKey: .direction)) ?? "stable"
        averageEntropyDelta = (try? container.decodeIfPresent(Double.self, forKey: .averageEntropyDelta))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .average_entropy_delta))
            ?? 0
        averageAdjustedConfidence = (try? container.decodeIfPresent(Double.self, forKey: .averageAdjustedConfidence))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .average_adjusted_confidence))
            ?? 0
    }

    init(direction: String, averageEntropyDelta: Double, averageAdjustedConfidence: Double) {
        self.direction = direction
        self.averageEntropyDelta = averageEntropyDelta
        self.averageAdjustedConfidence = averageAdjustedConfidence
    }
}

struct RealityAuditStateSnapshot: Decodable, Sendable {
    let generatedAt: String
    let recentAudits: [RealityAuditSnapshot]
    let highestAnomalyDecisions: [RealityAuditSnapshot]
    let entropyTrend: RealityAuditTrendSnapshot

    private enum CodingKeys: String, CodingKey {
        case generatedAt
        case generated_at
        case recentAudits
        case recent_audits
        case highestAnomalyDecisions
        case highest_anomaly_decisions
        case entropyTrend
        case entropy_trend
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = (try? container.decodeIfPresent(String.self, forKey: .generatedAt))
            ?? (try? container.decodeIfPresent(String.self, forKey: .generated_at))
            ?? ""
        recentAudits = (try? container.decodeIfPresent([RealityAuditSnapshot].self, forKey: .recentAudits))
            ?? (try? container.decodeIfPresent([RealityAuditSnapshot].self, forKey: .recent_audits))
            ?? []
        highestAnomalyDecisions = (try? container.decodeIfPresent([RealityAuditSnapshot].self, forKey: .highestAnomalyDecisions))
            ?? (try? container.decodeIfPresent([RealityAuditSnapshot].self, forKey: .highest_anomaly_decisions))
            ?? []
        entropyTrend = (try? container.decodeIfPresent(RealityAuditTrendSnapshot.self, forKey: .entropyTrend))
            ?? (try? container.decodeIfPresent(RealityAuditTrendSnapshot.self, forKey: .entropy_trend))
            ?? RealityAuditTrendSnapshot(direction: "stable", averageEntropyDelta: 0, averageAdjustedConfidence: 0)
    }

    init(generatedAt: String, recentAudits: [RealityAuditSnapshot], highestAnomalyDecisions: [RealityAuditSnapshot], entropyTrend: RealityAuditTrendSnapshot) {
        self.generatedAt = generatedAt
        self.recentAudits = recentAudits
        self.highestAnomalyDecisions = highestAnomalyDecisions
        self.entropyTrend = entropyTrend
    }
}

struct MissionControlTrustSnapshot: Sendable {
    let attestationCount: Int
    let attestations: [MissionControlAttestation]
    let capabilityStatuses: [MissionControlCapabilityStatus]
    let operatorNote: String?
    let isPlaceholder: Bool

    static let placeholder = MissionControlTrustSnapshot(
        attestationCount: 0,
        attestations: [],
        capabilityStatuses: [],
        operatorNote: "SafeClash trust data is not available yet. Showing a read-only placeholder.",
        isPlaceholder: true
    )

    static let mock = MissionControlTrustSnapshot(
        attestationCount: 3,
        attestations: [
            MissionControlAttestation(
                id: "mock-attestation-1",
                title: "Certified research synthesis",
                detail: "Level A2 · deploy ready",
                certificateId: "cert-research-001"
            ),
            MissionControlAttestation(
                id: "mock-attestation-2",
                title: "Governed evidence summarizer",
                detail: "Level A1 · bounded output",
                certificateId: "cert-evidence-014"
            ),
            MissionControlAttestation(
                id: "mock-attestation-3",
                title: "Operator logbook classifier",
                detail: "Level B1 · review only",
                certificateId: "cert-logbook-021"
            )
        ],
        capabilityStatuses: [
            MissionControlCapabilityStatus(id: "research", title: "Research", detail: "2 certified configurations", emphasis: "ready"),
            MissionControlCapabilityStatus(id: "evidence", title: "Evidence", detail: "2 certified configurations", emphasis: "ready"),
            MissionControlCapabilityStatus(id: "audit", title: "Audit", detail: "1 certified configuration", emphasis: "watch")
        ],
        operatorNote: "Mock trust snapshot. SafeClash remains read-only from the Jeeves cockpit.",
        isPlaceholder: false
    )
}

struct MissionControlAttestation: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let certificateId: String?
}

struct MissionControlCapabilityStatus: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let emphasis: String
}

struct MissionControlDiscoveryCube: Sendable {
    let cells: [MissionControlCubeCellState]
    let topCellIndex: Int?
    let topZoneSummary: String
    let topZoneDetail: String
    let isPlaceholder: Bool

    var topCell: MissionControlCubeCellState? {
        guard let topCellIndex else { return nil }
        return cells.first { $0.index == topCellIndex }
    }

    var planes: [MissionControlCubePlane] {
        stride(from: 2, through: 0, by: -1).map { z in
            MissionControlCubePlane(
                z: z,
                title: String(format: "Plane %02d", z + 1),
                cells: cells.filter { $0.position.z == z }.sorted { lhs, rhs in
                    if lhs.position.y == rhs.position.y {
                        return lhs.position.x < rhs.position.x
                    }
                    return lhs.position.y < rhs.position.y
                }
            )
        }
    }

    var activeCellCount: Int {
        cells.filter(\.isActive).count
    }

    static func derive(
        topSignal: RadarTopSignal?,
        radarStatus: RadarStatusSnapshot?,
        collisions: [RadarCollision],
        emergence: [RadarCollision],
        hotspots: [RadarGravityHotspot],
        activations: [RadarActivation],
        discoveries: [RadarDiscoveryCandidate],
        knowledgeStatus: KnowledgeStatus?,
        pendingGapCount: Int
    ) -> MissionControlDiscoveryCube {
        var accumulators = (0..<27).map { index in
            DiscoveryAccumulator(index: index, position: position(for: index))
        }

        for hotspot in hotspots {
            guard let index = normalizedIndex(for: hotspot.cell) else { continue }
            accumulators[index].gravityScore = max(accumulators[index].gravityScore, hotspot.gravityScore)
            accumulators[index].hotspotBand = hotspot.band
            accumulators[index].contributors.formUnion(hotspot.contributors)
            if !hotspot.explanation.isEmpty && accumulators[index].note == nil {
                accumulators[index].note = hotspot.explanation
            }
        }

        for activation in activations {
            let indices = cellIndices(from: activation.cellIds)
            for index in indices {
                accumulators[index].residue += activation.residue
                accumulators[index].persistence += 1
                accumulators[index].sources.insert(activation.source)
                if accumulators[index].note == nil {
                    accumulators[index].note = activation.summary.isEmpty ? activation.title : activation.summary
                }
            }
        }

        for collision in collisions {
            let indices = cellIndices(from: collision.cellIds)
            for index in indices {
                accumulators[index].collisionCount += 1
                accumulators[index].collisionDensity = max(accumulators[index].collisionDensity, collision.density)
                accumulators[index].sources.formUnion(collision.sources)
                if accumulators[index].note == nil {
                    accumulators[index].note = collision.signalTitles.first
                }
            }
        }

        for event in emergence {
            let indices = cellIndices(from: event.cellIds)
            for index in indices {
                accumulators[index].emergenceCount += 1
                accumulators[index].collisionDensity = max(accumulators[index].collisionDensity, event.density)
                accumulators[index].sources.formUnion(event.sources)
                if accumulators[index].note == nil {
                    accumulators[index].note = event.signalTitles.first
                }
            }
        }

        let aggregateCollisionCount = max(radarStatus?.store?.collisionCount ?? 0, collisions.count)
        let aggregateEmergenceCount = max(radarStatus?.store?.emergenceCount ?? 0, emergence.count)
        let aggregateGapCount = max(discoveries.count, pendingGapCount)

        applyDerivedCoverage(
            to: &accumulators,
            currentValue: accumulators.reduce(0) { $0 + $1.collisionCount },
            targetCount: aggregateCollisionCount,
            indices: [13, 14, 10, 16, 12, 4, 22, 1, 25]
        ) { accumulator, order in
            accumulator.collisionCount += 1
            accumulator.collisionDensity = max(accumulator.collisionDensity, 0.62 - (Double(order) * 0.06))
            accumulator.note = accumulator.note ?? "Derived collision pressure from radar aggregate counts."
            accumulator.isDerived = true
        }

        applyDerivedCoverage(
            to: &accumulators,
            currentValue: accumulators.reduce(0) { $0 + $1.emergenceCount },
            targetCount: aggregateEmergenceCount,
            indices: [13, 14, 10, 16, 4, 22]
        ) { accumulator, order in
            accumulator.emergenceCount += 1
            accumulator.collisionDensity = max(accumulator.collisionDensity, 0.72 - (Double(order) * 0.07))
            accumulator.note = accumulator.note ?? "Derived emergence focus from radar aggregate counts."
            accumulator.isDerived = true
        }

        let preferredGapCells = preferredGapIndices(
            accumulators: accumulators,
            knowledgeStatus: knowledgeStatus
        )

        for (offset, candidate) in discoveries.prefix(6).enumerated() {
            guard let index = preferredGapCells[safe: offset] else { break }
            accumulators[index].gapCandidateCount += 1
            if accumulators[index].gapFocusRank == nil || candidate.rank < (accumulators[index].gapFocusRank ?? Int.max) {
                accumulators[index].gapFocusRank = candidate.rank == 0 ? offset + 1 : candidate.rank
            }
            accumulators[index].sources.formUnion(candidate.sources)
            accumulators[index].note = accumulators[index].note ?? candidate.explanation
        }

        applyDerivedCoverage(
            to: &accumulators,
            currentValue: accumulators.filter { $0.gapCandidateCount > 0 || $0.gapFocusRank != nil }.count,
            targetCount: aggregateGapCount,
            indices: preferredGapCells
        ) { accumulator, order in
            accumulator.gapCandidateCount = max(accumulator.gapCandidateCount, 1)
            accumulator.gapFocusRank = accumulator.gapFocusRank ?? (order + 1)
            accumulator.note = accumulator.note ?? "Derived gap focus while awaiting explicit cube placement from CLASHD27."
            accumulator.isDerived = true
        }

        if let topSignal {
            let targetIndex = preferredGapCells.first ?? 13
            if accumulators.allSatisfy({ $0.residue <= 0 }) {
                accumulators[targetIndex].residue = max(accumulators[targetIndex].residue, topSignal.residue)
                accumulators[targetIndex].persistence = max(accumulators[targetIndex].persistence, 1)
                accumulators[targetIndex].sources.insert(topSignal.source)
                accumulators[targetIndex].note = accumulators[targetIndex].note ?? topSignal.title
                accumulators[targetIndex].isDerived = true
            }
        }

        let maxCollisionDensity = max(accumulators.map(\.collisionDensity).max() ?? 0, 1)
        let maxGravityScore = max(accumulators.map(\.gravityScore).max() ?? 0, 1)
        let maxResidue = max(accumulators.map(\.residue).max() ?? topSignal?.residue ?? 0, 1)
        let maxPersistence = max(accumulators.map(\.persistence).max() ?? 0, 1)

        let provisionalCells = accumulators.map { accumulator in
            MissionControlCubeCellState(
                index: accumulator.index,
                position: accumulator.position,
                collisionCount: accumulator.collisionCount,
                emergenceCount: accumulator.emergenceCount,
                gravityScore: accumulator.gravityScore,
                residue: accumulator.residue,
                persistence: accumulator.persistence,
                gapCandidateCount: accumulator.gapCandidateCount,
                gapFocusRank: accumulator.gapFocusRank,
                hotspotBand: accumulator.hotspotBand,
                contributorCount: accumulator.contributors.count,
                sourceCount: accumulator.sources.count,
                pressure: pressure(
                    for: accumulator,
                    maxCollisionDensity: maxCollisionDensity,
                    maxGravityScore: maxGravityScore,
                    maxResidue: maxResidue,
                    maxPersistence: maxPersistence
                ),
                isTopCell: false,
                isPlaceholder: accumulator.isDerived,
                note: accumulator.note
            )
        }

        let sortedTopCells = provisionalCells.sorted { lhs, rhs in
            if lhs.pressure == rhs.pressure {
                if lhs.emergenceCount == rhs.emergenceCount {
                    if lhs.gapCandidateCount == rhs.gapCandidateCount {
                        return lhs.index < rhs.index
                    }
                    return lhs.gapCandidateCount > rhs.gapCandidateCount
                }
                return lhs.emergenceCount > rhs.emergenceCount
            }
            return lhs.pressure > rhs.pressure
        }

        let topCell = sortedTopCells.first(where: \.isActive)
        let cells = provisionalCells.map { cell in
            MissionControlCubeCellState(
                index: cell.index,
                position: cell.position,
                collisionCount: cell.collisionCount,
                emergenceCount: cell.emergenceCount,
                gravityScore: cell.gravityScore,
                residue: cell.residue,
                persistence: cell.persistence,
                gapCandidateCount: cell.gapCandidateCount,
                gapFocusRank: cell.gapFocusRank,
                hotspotBand: cell.hotspotBand,
                contributorCount: cell.contributorCount,
                sourceCount: cell.sourceCount,
                pressure: cell.pressure,
                isTopCell: cell.index == topCell?.index,
                isPlaceholder: cell.isPlaceholder,
                note: cell.note
            )
        }

        let topSummary: String
        let topDetail: String
        if let topCell {
            topSummary = "Top discovery zone \(topCell.coordinateLabel)"
            topDetail = zoneDetail(for: topCell, topSignal: topSignal)
        } else if let topSignal {
            topSummary = "Top discovery zone pending placement"
            topDetail = "\(topSignal.title) is visible from \(topSignal.source), but CLASHD27 has not attached it to a cube cell yet."
        } else {
            topSummary = "Cube standing by"
            topDetail = "The 27-cell shell is visible, but CLASHD27 has not surfaced enough localized pressure to rank a discovery zone."
        }

        return MissionControlDiscoveryCube(
            cells: cells,
            topCellIndex: topCell?.index,
            topZoneSummary: topSummary,
            topZoneDetail: topDetail,
            isPlaceholder: cells.allSatisfy { !$0.isActive || $0.isPlaceholder }
        )
    }

    private static func preferredGapIndices(
        accumulators: [DiscoveryAccumulator],
        knowledgeStatus: KnowledgeStatus?
    ) -> [Int] {
        var ordered: [Int] = accumulators
            .sorted { lhs, rhs in
                let leftScore = lhs.gravityScore + lhs.collisionDensity + lhs.residue
                let rightScore = rhs.gravityScore + rhs.collisionDensity + rhs.residue
                if leftScore == rightScore {
                    return lhs.index < rhs.index
                }
                return leftScore > rightScore
            }
            .map(\.index)

        let knowledge = (knowledgeStatus?.topCubeCells ?? []).compactMap(parseCellReference)
        ordered.insert(contentsOf: knowledge, at: 0)
        ordered.insert(contentsOf: [13, 14, 10, 16, 12, 4, 22, 1, 25], at: 0)
        return unique(ordered)
    }

    private static func applyDerivedCoverage(
        to accumulators: inout [DiscoveryAccumulator],
        currentValue: Int,
        targetCount: Int,
        indices: [Int],
        update: (inout DiscoveryAccumulator, Int) -> Void
    ) {
        guard targetCount > currentValue else { return }
        let needed = min(targetCount - currentValue, indices.count)
        for order in 0..<needed {
            let index = indices[order]
            guard accumulators.indices.contains(index) else { continue }
            update(&accumulators[index], order)
        }
    }

    private static func pressure(
        for accumulator: DiscoveryAccumulator,
        maxCollisionDensity: Double,
        maxGravityScore: Double,
        maxResidue: Double,
        maxPersistence: Int
    ) -> Double {
        let collision = accumulator.collisionDensity / maxCollisionDensity
        let gravity = accumulator.gravityScore / maxGravityScore
        let residue = accumulator.residue / maxResidue
        let persistence = Double(accumulator.persistence) / Double(maxPersistence)
        let emergence = accumulator.emergenceCount > 0 ? 1.0 : 0.0
        let gap = accumulator.gapCandidateCount > 0 ? 1.0 : 0.0
        let score = (collision * 0.28)
            + (gravity * 0.24)
            + (residue * 0.18)
            + (persistence * 0.12)
            + (emergence * 0.12)
            + (gap * 0.10)
        return min(max(score, 0), 1)
    }

    private static func zoneDetail(for cell: MissionControlCubeCellState, topSignal: RadarTopSignal?) -> String {
        var fragments: [String] = []
        if cell.hasCollision {
            fragments.append("\(cell.collisionCount) collision\(cell.collisionCount == 1 ? "" : "s")")
        }
        if cell.hasEmergence {
            fragments.append("\(cell.emergenceCount) emergence")
        }
        if cell.hasGravity {
            fragments.append("gravity \(String(format: "%.2f", cell.gravityScore))")
        }
        if cell.hasResidue {
            fragments.append("residue \(String(format: "%.2f", cell.residue))")
        }
        if cell.hasGapFocus {
            fragments.append("gap focus")
        }
        if fragments.isEmpty, let topSignal {
            return "\(topSignal.title) is the leading visible signal, but cell-level instrumentation is still sparse."
        }
        let headline = fragments.joined(separator: " · ")
        if let note = cell.note, !note.isEmpty {
            return headline + ". " + note
        }
        return headline.capitalized + "."
    }

    private static func position(for index: Int) -> CubePosition {
        CubePosition(x: index % 3, y: (index / 3) % 3, z: index / 9)
    }

    private static func normalizedIndex(for rawValue: Int) -> Int? {
        if (0..<27).contains(rawValue) {
            return rawValue
        }
        if (1...27).contains(rawValue) {
            return rawValue - 1
        }
        return nil
    }

    private static func cellIndices(from values: [String]) -> [Int] {
        unique(values.compactMap(parseCellReference))
    }

    private static func parseCellReference(_ rawValue: String) -> Int? {
        let normalized = rawValue
            .lowercased()
            .replacingOccurrences(of: "[^0-9]+", with: " ", options: .regularExpression)
            .split(separator: " ")
            .compactMap { Int($0) }

        if normalized.count >= 3 {
            let x = normalized[0]
            let y = normalized[1]
            let z = normalized[2]
            if (0...2).contains(x), (0...2).contains(y), (0...2).contains(z) {
                return x + (y * 3) + (z * 9)
            }
            if (1...3).contains(x), (1...3).contains(y), (1...3).contains(z) {
                return (x - 1) + ((y - 1) * 3) + ((z - 1) * 9)
            }
        }

        guard let first = normalized.first else { return nil }
        return normalizedIndex(for: first)
    }

    private static func unique(_ values: [Int]) -> [Int] {
        var seen: Set<Int> = []
        var result: [Int] = []
        for value in values where (0..<27).contains(value) {
            if seen.insert(value).inserted {
                result.append(value)
            }
        }
        return result
    }

    private struct DiscoveryAccumulator {
        let index: Int
        let position: CubePosition
        var collisionCount = 0
        var emergenceCount = 0
        var collisionDensity = 0.0
        var gravityScore = 0.0
        var residue = 0.0
        var persistence = 0
        var gapCandidateCount = 0
        var gapFocusRank: Int?
        var hotspotBand: String?
        var contributors: Set<String> = []
        var sources: Set<String> = []
        var isDerived = false
        var note: String?
    }
}

struct MissionControlCubePlane: Identifiable, Hashable, Sendable {
    let z: Int
    let title: String
    let cells: [MissionControlCubeCellState]

    var id: Int { z }
}

struct MissionControlCubeCellState: Identifiable, Hashable, Sendable {
    let index: Int
    let position: CubePosition
    let collisionCount: Int
    let emergenceCount: Int
    let gravityScore: Double
    let residue: Double
    let persistence: Int
    let gapCandidateCount: Int
    let gapFocusRank: Int?
    let hotspotBand: String?
    let contributorCount: Int
    let sourceCount: Int
    let pressure: Double
    let isTopCell: Bool
    let isPlaceholder: Bool
    let note: String?

    var id: Int { index }

    var hasCollision: Bool { collisionCount > 0 }
    var hasEmergence: Bool { emergenceCount > 0 }
    var hasGravity: Bool { gravityScore > 0.01 }
    var hasResidue: Bool { residue > 0.01 || persistence > 0 }
    var hasGapFocus: Bool { gapCandidateCount > 0 || gapFocusRank != nil }
    var isActive: Bool {
        hasCollision || hasEmergence || hasGravity || hasResidue || hasGapFocus || pressure > 0.08
    }

    var coordinateLabel: String {
        "C\(index + 1)"
    }
}

struct MissionControlCubeEvidenceSummary: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let kind: String
    let summary: String
}

struct MissionControlCubeCellDetailState: Identifiable, Hashable, Sendable {
    let cell: MissionControlCubeCellState
    let planeLabel: String
    let layerLabel: String
    let label: String
    let collisionSummary: String
    let emergenceSummary: String
    let gravitySummary: String
    let residueSummary: String
    let topGapCandidateTitle: String
    let topGapCandidateDetail: String
    let topDiscoverySignalSummary: String
    let confidenceSummary: String
    let prioritySummary: String
    let evidenceItems: [MissionControlCubeEvidenceSummary]
    let evidencePosture: String
    let representationSummary: String
    let operatorGuidance: String
    let attentionBand: String
    let governanceSummary: String
    let hasGovernanceFollowUp: Bool

    var id: Int { cell.index }
    var cellId: String { cell.coordinateLabel }
}

extension MissionControlDiscoveryCube {
    func detailState(
        for cellIndex: Int,
        topSignal: RadarTopSignal?,
        collisions: [RadarCollision],
        emergence: [RadarCollision],
        hotspots: [RadarGravityHotspot],
        activations: [RadarActivation],
        discoveries: [RadarDiscoveryCandidate],
        knowledgeObjects: [KnowledgeObject],
        pendingProposals: [Proposal]
    ) -> MissionControlCubeCellDetailState? {
        guard let cell = cells.first(where: { $0.index == cellIndex }) else { return nil }

        let linkedCollisions = collisions
            .filter { Self.cellIndices(from: $0.cellIds).contains(cell.index) }
            .sorted { $0.density > $1.density }
        let linkedEmergence = emergence
            .filter { Self.cellIndices(from: $0.cellIds).contains(cell.index) }
            .sorted { $0.density > $1.density }
        let linkedHotspot = hotspots
            .filter { Self.normalizedIndex(for: $0.cell) == cell.index }
            .sorted { lhs, rhs in
                if lhs.rank == rhs.rank {
                    return lhs.gravityScore > rhs.gravityScore
                }
                return lhs.rank < rhs.rank
            }
            .first
        let linkedActivations = activations
            .filter { Self.cellIndices(from: $0.cellIds).contains(cell.index) }
            .sorted { $0.residue > $1.residue }

        let sortedDiscoveries = discoveries.sorted { lhs, rhs in
            let leftRank = lhs.rank == 0 ? Int.max : lhs.rank
            let rightRank = rhs.rank == 0 ? Int.max : rhs.rank
            if leftRank == rightRank {
                return lhs.candidateScore > rhs.candidateScore
            }
            return leftRank < rightRank
        }
        let linkedGapCandidate = Self.discoveryCandidate(for: cell, discoveries: sortedDiscoveries)

        let linkedEvidence = knowledgeObjects
            .filter { Self.knowledgeObjectCellIndices($0).contains(cell.index) }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        let evidenceItems = Array(linkedEvidence.prefix(3)).map { object in
            MissionControlCubeEvidenceSummary(
                id: object.objectId,
                title: object.title,
                kind: object.kind.uppercased(),
                summary: object.summary.isEmpty ? "No summary available." : object.summary
            )
        }

        let directlyLinkedGovernance = pendingProposals
            .filter { $0.isGapDiscovery }
            .filter { Self.proposalCellIndices($0).contains(cell.index) }
            .sorted { ($0.priorityScore ?? 0) > ($1.priorityScore ?? 0) }
        let fallbackGovernance = pendingProposals.filter(\.isGapDiscovery)

        let attentionBand = Self.attentionBand(for: cell, governanceCount: directlyLinkedGovernance.count)

        let collisionSummary: String
        if let strongest = linkedCollisions.first {
            let sourceLine = strongest.sources.prefix(2).joined(separator: ", ")
            collisionSummary = "\(linkedCollisions.count) localized collision trace(s). Strongest density \(String(format: "%.2f", strongest.density)) across \(sourceLine.isEmpty ? "multiple sources" : sourceLine)."
        } else if cell.hasCollision {
            collisionSummary = "Collision pressure is visible in this cell, but the current CLASHD27 payload only exposes aggregate placement."
        } else {
            collisionSummary = "No localized collision cluster is attached to this cell."
        }

        let emergenceSummary: String
        if let strongest = linkedEmergence.first {
            emergenceSummary = "\(linkedEmergence.count) emergence trace(s) are centered here. Strongest density \(String(format: "%.2f", strongest.density))."
        } else if cell.hasEmergence {
            emergenceSummary = "Emergence pressure is present, but Jeeves is currently inferring this cell from aggregate CLASHD27 heat."
        } else {
            emergenceSummary = "No explicit emergence cluster is pinned to this cell yet."
        }

        let gravitySummary: String
        if let hotspot = linkedHotspot {
            let contributors = hotspot.contributors.prefix(3).joined(separator: ", ")
            let contributorText = contributors.isEmpty ? "contributors not listed" : contributors
            gravitySummary = "Gravity hotspot \(hotspot.band.uppercased()) with score \(String(format: "%.2f", hotspot.gravityScore)). \(contributorText)."
        } else if cell.hasGravity {
            gravitySummary = "Gravity or hotspot pressure is visible in this cell, but the detailed hotspot record is not attached."
        } else {
            gravitySummary = "No hotspot pressure is currently localized to this cell."
        }

        let residueSummary: String
        if let activation = linkedActivations.first {
            residueSummary = "Residue \(String(format: "%.2f", cell.residue)) with \(max(cell.persistence, linkedActivations.count)) persistence mark(s). Latest source: \(activation.source)."
        } else if cell.hasResidue {
            residueSummary = "Residue \(String(format: "%.2f", cell.residue)) is visible with persistence \(cell.persistence)."
        } else {
            residueSummary = "No residue or persistence trace is currently attached to this cell."
        }

        let topGapCandidateTitle: String
        let topGapCandidateDetail: String
        if let candidate = linkedGapCandidate {
            topGapCandidateTitle = candidate.candidateType.replacingOccurrences(of: "_", with: " ").capitalized
            let rank = candidate.rank > 0 ? "rank \(candidate.rank)" : "unranked"
            let score = candidate.candidateScore > 0 ? "score \(String(format: "%.2f", candidate.candidateScore))" : "score pending"
            let base = candidate.explanation.isEmpty ? candidate.sources.joined(separator: ", ") : candidate.explanation
            topGapCandidateDetail = "\(rank) · \(score). \(base.isEmpty ? "CLASHD27 has not published an explanation yet." : base)"
        } else if cell.hasGapFocus {
            topGapCandidateTitle = "Gap focus warming"
            topGapCandidateDetail = "This cell is carrying gap pressure, but CLASHD27 has not yet attached a cell-specific candidate payload."
        } else {
            topGapCandidateTitle = "No gap candidate pinned"
            topGapCandidateDetail = "This cell does not currently have a localized gap candidate."
        }

        let topDiscoverySignalSummary: String
        if let topSignal, cell.isTopCell || cell.hasResidue || cell.hasEmergence {
            topDiscoverySignalSummary = "Top visible signal: \(topSignal.title) from \(topSignal.source), residue \(String(format: "%.2f", topSignal.residue))."
        } else if let topSignal {
            topDiscoverySignalSummary = "\(topSignal.title) is the strongest global signal, but it is not yet pinned to this cell."
        } else {
            topDiscoverySignalSummary = "No top discovery signal is available from CLASHD27 right now."
        }

        let confidenceSummary: String
        if !linkedCollisions.isEmpty || !linkedEmergence.isEmpty || linkedHotspot != nil || !linkedEvidence.isEmpty {
            confidenceSummary = "Confidence is stronger here because Jeeves has direct localized discovery or evidence signals for this cell."
        } else if cell.isPlaceholder {
            confidenceSummary = "Confidence is medium. This cell is partially derived from aggregate CLASHD27 radar counts while richer cell payloads are still sparse."
        } else {
            confidenceSummary = "Confidence is early. The cell is visible, but its signal stack is still thin."
        }

        let prioritySummary: String
        if cell.isTopCell || !directlyLinkedGovernance.isEmpty {
            prioritySummary = "Priority is elevated because this cell is either the current top zone or already has downstream governance pressure."
        } else if cell.hasGapFocus || cell.hasEmergence || cell.hasGravity {
            prioritySummary = "Priority is medium because the cell is heating, but governance follow-up is not yet explicit."
        } else {
            prioritySummary = "Priority is low for now; this is primarily an observation point."
        }

        let evidencePosture: String
        if evidenceItems.isEmpty {
            evidencePosture = "No linked knowledge or evidence objects are pinned to this cell yet. The cell currently represents live discovery posture only."
        } else {
            evidencePosture = "\(evidenceItems.count) linked knowledge or evidence object(s) reinforce this cell. Jeeves is exposing their summaries without altering attribution."
        }

        let representationSummary: String
        if let note = cell.note, !note.isEmpty {
            representationSummary = note
        } else if let hotspot = linkedHotspot, !hotspot.explanation.isEmpty {
            representationSummary = hotspot.explanation
        } else if let candidate = linkedGapCandidate, !candidate.explanation.isEmpty {
            representationSummary = candidate.explanation
        } else {
            representationSummary = "This cell represents the current localized blend of collision, emergence, gravity, residue, and gap attention visible from CLASHD27."
        }

        let governanceSummary: String
        if let proposal = directlyLinkedGovernance.first {
            let priority = proposal.priorityScore.map { "P\(Int($0.rounded()))" } ?? proposal.intent.risk.uppercased()
            governanceSummary = "A downstream governance follow-up is already visible: \(proposal.title) (\(priority)). openclashd-v2 remains the only execution authority."
        } else if cell.hasGapFocus && !fallbackGovernance.isEmpty {
            governanceSummary = "Gap-related governance follow-up exists elsewhere in the queue, but it is not explicitly pinned to this cell yet."
        } else {
            governanceSummary = "No downstream governance follow-up is currently linked to this cell."
        }

        return MissionControlCubeCellDetailState(
            cell: cell,
            planeLabel: String(format: "Plane %02d", cell.position.z + 1),
            layerLabel: Self.layerLabel(for: cell.position.z),
            label: Self.label(for: cell, hotspot: linkedHotspot, candidate: linkedGapCandidate),
            collisionSummary: collisionSummary,
            emergenceSummary: emergenceSummary,
            gravitySummary: gravitySummary,
            residueSummary: residueSummary,
            topGapCandidateTitle: topGapCandidateTitle,
            topGapCandidateDetail: topGapCandidateDetail,
            topDiscoverySignalSummary: topDiscoverySignalSummary,
            confidenceSummary: confidenceSummary,
            prioritySummary: prioritySummary,
            evidenceItems: evidenceItems,
            evidencePosture: evidencePosture,
            representationSummary: representationSummary,
            operatorGuidance: Self.operatorGuidance(
                for: cell,
                attentionBand: attentionBand,
                evidenceCount: evidenceItems.count,
                governanceCount: directlyLinkedGovernance.count,
                gapCandidate: linkedGapCandidate
            ),
            attentionBand: attentionBand,
            governanceSummary: governanceSummary,
            hasGovernanceFollowUp: !directlyLinkedGovernance.isEmpty
        )
    }

    private static func discoveryCandidate(
        for cell: MissionControlCubeCellState,
        discoveries: [RadarDiscoveryCandidate]
    ) -> RadarDiscoveryCandidate? {
        guard !discoveries.isEmpty, cell.hasGapFocus else { return nil }
        if let exactRank = cell.gapFocusRank,
           exactRank > 0,
           let ranked = discoveries.first(where: { $0.rank == exactRank }) {
            return ranked
        }
        if let rank = cell.gapFocusRank, rank > 0 {
            return discoveries[safe: min(rank - 1, discoveries.count - 1)]
        }
        return discoveries.first
    }

    private static func proposalCellIndices(_ proposal: Proposal) -> [Int] {
        var rawValues: [String] = []
        if let cubeCell = proposal.gapDetails?.cubeCell, !cubeCell.isEmpty {
            rawValues.append(cubeCell)
        }
        return unique(rawValues.compactMap(parseCellReference))
    }

    private static func knowledgeObjectCellIndices(_ object: KnowledgeObject) -> [Int] {
        var rawValues: [String] = []

        if let metadata = object.metadata {
            let normalized = Dictionary(uniqueKeysWithValues: metadata.map { ($0.key.lowercased(), $0.value) })
            for key in ["linked_cells", "cube_cells", "cells", "cell", "cube_cell", "linked_cell"] {
                guard let value = normalized[key] else { continue }
                if let list = value.stringArrayValue {
                    rawValues.append(contentsOf: list)
                } else if let scalar = value.scalarStringValue {
                    rawValues.append(scalar)
                }
            }
        }

        if let refs = object.sourceRefs {
            for ref in refs {
                rawValues.append(ref.sourceId)
                if let label = ref.label {
                    rawValues.append(label)
                }
            }
        }

        if let linked = object.linkedObjectIds {
            rawValues.append(contentsOf: linked)
        }

        return unique(rawValues.compactMap(parseCellReference))
    }

    private static func label(
        for cell: MissionControlCubeCellState,
        hotspot: RadarGravityHotspot?,
        candidate: RadarDiscoveryCandidate?
    ) -> String {
        if let hotspot {
            return hotspot.axes.what.replacingOccurrences(of: "-", with: " ").capitalized
        }
        if let candidate {
            return candidate.candidateType.replacingOccurrences(of: "_", with: " ").capitalized
        }
        if cell.hasEmergence { return "Emergence watch" }
        if cell.hasCollision { return "Collision watch" }
        if cell.hasResidue { return "Residue corridor" }
        return "Observation cell"
    }

    private static func layerLabel(for z: Int) -> String {
        switch z {
        case 2:
            return "Upper layer"
        case 1:
            return "Middle layer"
        default:
            return "Lower layer"
        }
    }

    private static func attentionBand(for cell: MissionControlCubeCellState, governanceCount: Int) -> String {
        if cell.isTopCell || governanceCount > 0 || cell.pressure >= 0.72 {
            return "STRONG"
        }
        if cell.pressure >= 0.40 || cell.hasEmergence || cell.hasGapFocus || cell.hasGravity {
            return "MEDIUM"
        }
        return "EARLY"
    }

    private static func operatorGuidance(
        for cell: MissionControlCubeCellState,
        attentionBand: String,
        evidenceCount: Int,
        governanceCount: Int,
        gapCandidate: RadarDiscoveryCandidate?
    ) -> String {
        var reasons: [String] = []
        if cell.isTopCell {
            reasons.append("it is the current top discovery zone")
        }
        if cell.hasEmergence {
            reasons.append("emergence pressure is visible")
        }
        if cell.hasGapFocus {
            reasons.append("gap focus is accumulating")
        }
        if evidenceCount > 0 {
            reasons.append("knowledge objects are already linked")
        }
        if governanceCount > 0 {
            reasons.append("governance follow-up already exists downstream")
        }

        let reasonLine = reasons.isEmpty
            ? "This cell is primarily worth watching for change rather than action."
            : "This cell deserves attention because " + reasons.joined(separator: ", ") + "."

        let gapLine: String
        if let gapCandidate {
            gapLine = "The leading opportunity is \(gapCandidate.candidateType.replacingOccurrences(of: "_", with: " "))."
        } else if cell.hasGapFocus {
            gapLine = "Opportunity pressure is visible, but the candidate payload is still partial."
        } else {
            gapLine = "No opportunity candidate is localized yet."
        }

        return "\(reasonLine) Signal strength is \(attentionBand.lowercased()). \(gapLine)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
