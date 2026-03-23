import Foundation

private enum LossyJSONScalar: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: LossyJSONScalar])
    case array([LossyJSONScalar])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode([String: LossyJSONScalar].self) {
            self = .object(value)
            return
        }
        if let value = try? container.decode([LossyJSONScalar].self) {
            self = .array(value)
            return
        }
        throw DecodingError.typeMismatch(
            LossyJSONScalar.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported scalar")
        )
    }

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object(let value):
            let keys = value.keys.sorted().joined(separator: ",")
            return "{\(keys)}"
        case .array(let value):
            return "[\(value.map(\.stringValue).joined(separator: ","))]"
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(LossyJSONScalar.self, forKey: key) {
            return value.stringValue
        }
        return nil
    }
}

struct ObservatoryDashboardSnapshot: Sendable {
    let conductor: ConductorState?
    let alerts: [ObservatoryAlert]
    let fabricClock: FabricClockState?
    let fabricEmergence: FabricEmergence?
    let lobbyOpenChallenges: [LobbyChallenge]
    let signals: SignalsState?
    let knowledgeStatus: KnowledgeStatus?
    let knowledgeEmergence: KnowledgeEmergence?
    let signalsRuntime: SignalsRuntimeSnapshot?
    let stream: ObservatoryStreamFeed?
    let radarStatus: RadarStatusSnapshot?
    let radarActivations: [RadarActivation]
    let radarCollisions: [RadarCollision]
    let radarEmergence: [RadarCollision]
    let radarClusters: [RadarClusterSummary]
    let radarSources: [RadarSourceStats]
    let radarGravityHotspots: [RadarGravityHotspot]
    let radarDiscoveryCandidates: [RadarDiscoveryCandidate]
    let fetchedAt: Date
}

struct SystemIntelligenceSnapshot: Decodable, Sendable {
    let entropy: Double
    let stage: String
    let residueStrength: Double
    let discoveryRate: Double
    let approvalRate: Double
    let patternCount: Int

    private enum CodingKeys: String, CodingKey {
        case entropy
        case stage
        case residueStrength = "residue_strength"
        case discoveryRate = "discovery_rate"
        case approvalRate = "approval_rate"
        case patternCount = "pattern_count"
    }

    var stagePhase: IntelligencePhaseStage {
        IntelligencePhaseStage(phase: stage) ?? .safety
    }

    static let demo = SystemIntelligenceSnapshot(
        entropy: 0.412,
        stage: "Define",
        residueStrength: 0.58,
        discoveryRate: 2.4,
        approvalRate: 0.76,
        patternCount: 6
    )
}

struct SystemEntropySnapshot: Decodable, Sendable {
    let entropyScore: Double
    let trend: String
    let signalVolume: Int
    let proposalCount: Int
    let residueStrength: Double

    private enum CodingKeys: String, CodingKey {
        case entropyScore = "entropy_score"
        case trend
        case signalVolume = "signal_volume"
        case proposalCount = "proposal_count"
        case residueStrength = "residue_strength"
    }

    static let demo = SystemEntropySnapshot(
        entropyScore: 0.342,
        trend: "improving",
        signalVolume: 18,
        proposalCount: 5,
        residueStrength: 0.58
    )
}

struct SystemResidueFieldRegionSummary: Decodable, Sendable, Identifiable {
    let region: String
    let residueStrength: Double
    let approvalDensity: Double
    let signalVolume: Int
    let patternCount: Int

    var id: String { region }

    private enum CodingKeys: String, CodingKey {
        case region
        case residueStrength = "residue_strength"
        case approvalDensity = "approval_density"
        case signalVolume = "signal_volume"
        case patternCount = "pattern_count"
    }
}

struct SystemResidueFieldSignalTypeSummary: Decodable, Sendable, Identifiable {
    let signalType: String
    let residueStrength: Double
    let approvalDensity: Double
    let patternCount: Int

    var id: String { signalType }

    private enum CodingKeys: String, CodingKey {
        case signalType = "signal_type"
        case residueStrength = "residue_strength"
        case approvalDensity = "approval_density"
        case patternCount = "pattern_count"
    }
}

struct SystemResidueFieldSnapshot: Decodable, Sendable {
    let regions: [SystemResidueFieldRegionSummary]
    let signalTypes: [SystemResidueFieldSignalTypeSummary]
    let fieldStrength: Double

    private enum CodingKeys: String, CodingKey {
        case regions
        case signalTypes = "signal_types"
        case fieldStrength = "field_strength"
    }

    static let demo = SystemResidueFieldSnapshot(
        regions: [
            SystemResidueFieldRegionSummary(
                region: "nl-ijmuiden",
                residueStrength: 1,
                approvalDensity: 0.86,
                signalVolume: 12,
                patternCount: 4
            ),
            SystemResidueFieldRegionSummary(
                region: "eu-west",
                residueStrength: 0.63,
                approvalDensity: 0.71,
                signalVolume: 8,
                patternCount: 2
            )
        ],
        signalTypes: [
            SystemResidueFieldSignalTypeSummary(
                signalType: "degradation",
                residueStrength: 1,
                approvalDensity: 0.82,
                patternCount: 4
            ),
            SystemResidueFieldSignalTypeSummary(
                signalType: "latency_spike",
                residueStrength: 0.44,
                approvalDensity: 0.58,
                patternCount: 1
            )
        ],
        fieldStrength: 0.61
    )
}

struct SystemGapFinderMatch: Decodable, Sendable, Identifiable {
    let matchId: String
    let signalIds: [String]
    let sources: [String]
    let involvedDomains: [String]
    let sharedMethods: [String]
    let sharedCauses: [String]
    let sharedEffects: [String]
    let entropyRelation: String
    let strengthScore: Double
    let explanation: String
    let evidenceRefs: [String]

    var id: String { matchId }
}

struct SystemGapFinderGap: Decodable, Sendable, Identifiable {
    let gapId: String
    let title: String
    let involvedDomains: [String]
    let basedOnMatchId: String
    let whyMatched: String
    let whyGap: String
    let sharedMethods: [String]
    let sharedCauses: [String]
    let sharedEffects: [String]
    let entropyNote: String
    let evidenceRefs: [String]
    let suggestedQuestion: String
    let score: Double

    var id: String { gapId }
}

struct SystemGapFinderCounts: Decodable, Sendable {
    let fingerprints: Int
    let matches: Int
    let gaps: Int
}

struct SystemGapFinderSnapshot: Decodable, Sendable {
    let ok: Bool
    let updatedAt: String
    let counts: SystemGapFinderCounts
    let topMatches: [SystemGapFinderMatch]
    let topGaps: [SystemGapFinderGap]

    static let demo = SystemGapFinderSnapshot(
        ok: true,
        updatedAt: "now",
        counts: SystemGapFinderCounts(
            fingerprints: 18,
            matches: 6,
            gaps: 3
        ),
        topMatches: [
            SystemGapFinderMatch(
                matchId: "demo-gap-match-1",
                signalIds: ["signal-medical", "signal-cyber"],
                sources: ["pubmed", "github"],
                involvedDomains: ["medical-imaging", "cybersecurity", "diagnostics", "operations"],
                sharedMethods: ["anomaly-detection"],
                sharedCauses: ["uncertainty", "overload"],
                sharedEffects: ["false-negative"],
                entropyRelation: "contradiction",
                strengthScore: 0.79,
                explanation: "This overlap is surfaced because research and software signals show the same method pattern, similar underlying causes, and matching downstream effects. Their entropy behavior diverges, which makes the bridge especially worth review.",
                evidenceRefs: ["https://example.org/paper-1", "https://example.org/repo-incident"]
            )
        ],
        topGaps: [
            SystemGapFinderGap(
                gapId: "demo-gap-1",
                title: "Medical Imaging x Cybersecurity",
                involvedDomains: ["medical-imaging", "cybersecurity"],
                basedOnMatchId: "demo-gap-match-1",
                whyMatched: "This overlap is surfaced because research and software signals show the same method pattern, similar underlying causes, and matching downstream effects.",
                whyGap: "The structure repeats across different domains, but the linked systems move in opposite entropy directions and no clear bridge is visible yet.",
                sharedMethods: ["anomaly-detection"],
                sharedCauses: ["uncertainty", "overload"],
                sharedEffects: ["false-negative"],
                entropyNote: "The domains are structurally similar, but their entropy directions diverge.",
                evidenceRefs: ["https://example.org/paper-1", "https://example.org/repo-incident"],
                suggestedQuestion: "Why does the same Anomaly Detection method behave differently across Medical Imaging and Cybersecurity?",
                score: 0.88
            )
        ]
    )
}

struct SystemOperatorMemorySignalFamilyEntry: Decodable, Sendable, Identifiable {
    let signalType: String
    let weight: Double
    let recentApprovals: Int
    let recentRejections: Int
    let linkedKnowledge: Int
    let explanation: String

    var id: String { signalType }

    private enum CodingKeys: String, CodingKey {
        case signalType = "signal_type"
        case weight
        case recentApprovals = "recent_approvals"
        case recentRejections = "recent_rejections"
        case linkedKnowledge = "linked_knowledge"
        case explanation
    }
}

struct SystemOperatorMemoryRegionEntry: Decodable, Sendable, Identifiable {
    let region: String
    let weight: Double
    let recentAttention: Int
    let recentApprovals: Int
    let recentRejections: Int
    let explanation: String

    var id: String { region }

    private enum CodingKeys: String, CodingKey {
        case region
        case weight
        case recentAttention = "recent_attention"
        case recentApprovals = "recent_approvals"
        case recentRejections = "recent_rejections"
        case explanation
    }
}

struct SystemOperatorMemoryPatternEntry: Decodable, Sendable, Identifiable {
    let patternType: String
    let weight: Double
    let recurrence: Int
    let recentApprovals: Int
    let recentRejections: Int
    let explanation: String

    var id: String { patternType }

    private enum CodingKeys: String, CodingKey {
        case patternType = "pattern_type"
        case weight
        case recurrence
        case recentApprovals = "recent_approvals"
        case recentRejections = "recent_rejections"
        case explanation
    }
}

struct SystemOperatorMemoryKnowledgeEntry: Decodable, Sendable, Identifiable {
    let knowledgeKind: String
    let weight: Double
    let recentObjects: Int
    let linkedApprovals: Int
    let explanation: String

    var id: String { knowledgeKind }

    private enum CodingKeys: String, CodingKey {
        case knowledgeKind = "knowledge_kind"
        case weight
        case recentObjects = "recent_objects"
        case linkedApprovals = "linked_approvals"
        case explanation
    }
}

struct SystemOperatorFocusMemory: Decodable, Sendable {
    let strongestFocus: String
    let explanation: String

    private enum CodingKeys: String, CodingKey {
        case strongestFocus = "strongest_focus"
        case explanation
    }
}

struct SystemOperatorMemorySnapshot: Decodable, Sendable {
    let signalFamilyMemory: [SystemOperatorMemorySignalFamilyEntry]
    let regionMemory: [SystemOperatorMemoryRegionEntry]
    let patternMemory: [SystemOperatorMemoryPatternEntry]
    let knowledgeMemory: [SystemOperatorMemoryKnowledgeEntry]
    let operatorFocusMemory: SystemOperatorFocusMemory

    private enum CodingKeys: String, CodingKey {
        case signalFamilyMemory = "signal_family_memory"
        case regionMemory = "region_memory"
        case patternMemory = "pattern_memory"
        case knowledgeMemory = "knowledge_memory"
        case operatorFocusMemory = "operator_focus_memory"
    }

    static let demo = SystemOperatorMemorySnapshot(
        signalFamilyMemory: [
            SystemOperatorMemorySignalFamilyEntry(
                signalType: "degradation",
                weight: 1,
                recentApprovals: 3,
                recentRejections: 1,
                linkedKnowledge: 4,
                explanation: "This signal family mattered because it was approved 3 times recently and linked to 4 knowledge objects."
            )
        ],
        regionMemory: [
            SystemOperatorMemoryRegionEntry(
                region: "nl-ijmuiden",
                weight: 1,
                recentAttention: 5,
                recentApprovals: 3,
                recentRejections: 0,
                explanation: "This region is highlighted because similar signals were approved here 3 times recently."
            )
        ],
        patternMemory: [
            SystemOperatorMemoryPatternEntry(
                patternType: "grid correlation",
                weight: 1,
                recurrence: 4,
                recentApprovals: 3,
                recentRejections: 1,
                explanation: "This pattern type keeps returning and was approved 3 times recently."
            )
        ],
        knowledgeMemory: [
            SystemOperatorMemoryKnowledgeEntry(
                knowledgeKind: "decision",
                weight: 1,
                recentObjects: 3,
                linkedApprovals: 3,
                explanation: "This knowledge structure matches prior operator-approved work 3 times."
            )
        ],
        operatorFocusMemory: SystemOperatorFocusMemory(
            strongestFocus: "nl-ijmuiden",
            explanation: "This region is highlighted because similar signals were approved here 3 times recently."
        )
    )
}

struct SystemCollectiveSignalFamilyMemoryEntry: Decodable, Sendable, Identifiable {
    let signalType: String
    let weight: Double
    let approvals: Int
    let rejections: Int
    let usefulnessScore: Double
    let explanation: String

    var id: String { signalType }

    private enum CodingKeys: String, CodingKey {
        case signalType = "signal_type"
        case weight
        case approvals
        case rejections
        case usefulnessScore = "usefulness_score"
        case explanation
    }
}

struct SystemCollectiveRegionMemoryEntry: Decodable, Sendable, Identifiable {
    let region: String
    let weight: Double
    let approvals: Int
    let residueStrength: Double
    let knowledgeCount: Int
    let explanation: String

    var id: String { region }

    private enum CodingKeys: String, CodingKey {
        case region
        case weight
        case approvals
        case residueStrength = "residue_strength"
        case knowledgeCount = "knowledge_count"
        case explanation
    }
}

struct SystemCollectivePatternMemoryEntry: Decodable, Sendable, Identifiable {
    let patternType: String
    let weight: Double
    let recurrence: Int
    let predictiveValue: Double
    let explanation: String

    var id: String { patternType }

    private enum CodingKeys: String, CodingKey {
        case patternType = "pattern_type"
        case weight
        case recurrence
        case predictiveValue = "predictive_value"
        case explanation
    }
}

struct SystemCollectiveKnowledgeStructureMemoryEntry: Decodable, Sendable, Identifiable {
    let structureType: String
    let weight: Double
    let persistence: Double
    let linkedResidueCount: Int
    let explanation: String

    var id: String { structureType }

    private enum CodingKeys: String, CodingKey {
        case structureType = "structure_type"
        case weight
        case persistence
        case linkedResidueCount = "linked_residue_count"
        case explanation
    }
}

struct SystemCollectiveCollisionMemoryEntry: Decodable, Sendable, Identifiable {
    let cubeZone: String
    let weight: Double
    let recurrence: Int
    let crossDomainStrength: Double
    let explanation: String

    var id: String { cubeZone }

    private enum CodingKeys: String, CodingKey {
        case cubeZone = "cube_zone"
        case weight
        case recurrence
        case crossDomainStrength = "cross_domain_strength"
        case explanation
    }
}

struct SystemCollectiveExecutionOutcomeMemoryEntry: Decodable, Sendable, Identifiable {
    let actionType: String
    let weight: Double
    let outcomeQuality: Double
    let receiptCount: Int
    let explanation: String

    var id: String { actionType }

    private enum CodingKeys: String, CodingKey {
        case actionType = "action_type"
        case weight
        case outcomeQuality = "outcome_quality"
        case receiptCount = "receipt_count"
        case explanation
    }
}

struct SystemCollectiveEntropyReductionRegionEntry: Decodable, Sendable, Identifiable {
    let region: String
    let entropyReduction: Double
    let explanation: String

    var id: String { region }

    private enum CodingKeys: String, CodingKey {
        case region
        case entropyReduction = "entropy_reduction"
        case explanation
    }
}

struct SystemCollectiveEntropyReductionSignalFamilyEntry: Decodable, Sendable, Identifiable {
    let signalType: String
    let entropyReduction: Double
    let explanation: String

    var id: String { signalType }

    private enum CodingKeys: String, CodingKey {
        case signalType = "signal_type"
        case entropyReduction = "entropy_reduction"
        case explanation
    }
}

struct SystemCollectiveEntropyReductionMemory: Decodable, Sendable {
    let averageEntropyReduction: Double
    let strongestRegions: [SystemCollectiveEntropyReductionRegionEntry]
    let strongestSignalFamilies: [SystemCollectiveEntropyReductionSignalFamilyEntry]

    private enum CodingKeys: String, CodingKey {
        case averageEntropyReduction = "average_entropy_reduction"
        case strongestRegions = "strongest_regions"
        case strongestSignalFamilies = "strongest_signal_families"
    }
}

struct SystemCollectiveMemorySnapshot: Decodable, Sendable {
    let signalFamilyMemory: [SystemCollectiveSignalFamilyMemoryEntry]
    let regionMemory: [SystemCollectiveRegionMemoryEntry]
    let patternMemory: [SystemCollectivePatternMemoryEntry]
    let knowledgeStructureMemory: [SystemCollectiveKnowledgeStructureMemoryEntry]
    let collisionMemory: [SystemCollectiveCollisionMemoryEntry]
    let executionOutcomeMemory: [SystemCollectiveExecutionOutcomeMemoryEntry]
    let entropyReductionMemory: SystemCollectiveEntropyReductionMemory

    private enum CodingKeys: String, CodingKey {
        case signalFamilyMemory = "signal_family_memory"
        case regionMemory = "region_memory"
        case patternMemory = "pattern_memory"
        case knowledgeStructureMemory = "knowledge_structure_memory"
        case collisionMemory = "collision_memory"
        case executionOutcomeMemory = "execution_outcome_memory"
        case entropyReductionMemory = "entropy_reduction_memory"
    }

    static let demo = SystemCollectiveMemorySnapshot(
        signalFamilyMemory: [
            SystemCollectiveSignalFamilyMemoryEntry(
                signalType: "degradation",
                weight: 1,
                approvals: 4,
                rejections: 1,
                usefulnessScore: 0.88,
                explanation: "This signal family has repeatedly led to approved outcomes, residue formation, and durable knowledge."
            )
        ],
        regionMemory: [
            SystemCollectiveRegionMemoryEntry(
                region: "nl-ijmuiden",
                weight: 1,
                approvals: 4,
                residueStrength: 0.86,
                knowledgeCount: 5,
                explanation: "This region is highlighted because governed activity here repeatedly produced useful knowledge."
            )
        ],
        patternMemory: [
            SystemCollectivePatternMemoryEntry(
                patternType: "grid correlation",
                weight: 1,
                recurrence: 5,
                predictiveValue: 0.82,
                explanation: "This pattern recurs and has repeatedly become durable enough to support approved work."
            )
        ],
        knowledgeStructureMemory: [
            SystemCollectiveKnowledgeStructureMemoryEntry(
                structureType: "action_receipt",
                weight: 1,
                persistence: 0.84,
                linkedResidueCount: 4,
                explanation: "This structure is considered stable because it kept linking back to residue across governed outcomes."
            )
        ],
        collisionMemory: [
            SystemCollectiveCollisionMemoryEntry(
                cubeZone: "111 · 112",
                weight: 1,
                recurrence: 3,
                crossDomainStrength: 0.79,
                explanation: "This collision pattern recurs across domains and has become structurally significant."
            )
        ],
        executionOutcomeMemory: [
            SystemCollectiveExecutionOutcomeMemoryEntry(
                actionType: "create_investigation_dossier",
                weight: 1,
                outcomeQuality: 0.81,
                receiptCount: 3,
                explanation: "This action type is anchored by receipt-linked outcomes and keeps producing attributable results."
            )
        ],
        entropyReductionMemory: SystemCollectiveEntropyReductionMemory(
            averageEntropyReduction: 0.21,
            strongestRegions: [
                SystemCollectiveEntropyReductionRegionEntry(
                    region: "nl-ijmuiden",
                    entropyReduction: 0.24,
                    explanation: "This region repeatedly reduced uncertainty through approved residue formation."
                )
            ],
            strongestSignalFamilies: [
                SystemCollectiveEntropyReductionSignalFamilyEntry(
                    signalType: "degradation",
                    entropyReduction: 0.24,
                    explanation: "This signal family repeatedly helped lower entropy through approved outcomes."
                )
            ]
        )
    )
}

struct SystemCivilizationCivicRiskStructure: Decodable, Sendable, Identifiable {
    let region: String
    let signalFamily: String
    let persistence: Double
    let linkedResidueCount: Int
    let explanation: String

    var id: String { "\(region)-\(signalFamily)" }

    private enum CodingKeys: String, CodingKey {
        case region
        case signalFamily = "signal_family"
        case persistence
        case linkedResidueCount = "linked_residue_count"
        case explanation
    }
}

struct SystemCivilizationDurableKnowledgeZone: Decodable, Sendable, Identifiable {
    let region: String
    let knowledgeWeight: Double
    let persistence: Double
    let entropyReductionScore: Double
    let explanation: String

    var id: String { region }

    private enum CodingKeys: String, CodingKey {
        case region
        case knowledgeWeight = "knowledge_weight"
        case persistence
        case entropyReductionScore = "entropy_reduction_score"
        case explanation
    }
}

struct SystemCivilizationInfrastructureMemoryEntry: Decodable, Sendable, Identifiable {
    let infrastructureType: String
    let recurrence: Int
    let usefulnessScore: Double
    let linkedReceipts: Int
    let explanation: String

    var id: String { infrastructureType }

    private enum CodingKeys: String, CodingKey {
        case infrastructureType = "infrastructure_type"
        case recurrence
        case usefulnessScore = "usefulness_score"
        case linkedReceipts = "linked_receipts"
        case explanation
    }
}

struct SystemCivilizationRecurringCoordinationPattern: Decodable, Sendable, Identifiable {
    let patternType: String
    let recurrence: Int
    let explanation: String

    var id: String { patternType }

    private enum CodingKeys: String, CodingKey {
        case patternType = "pattern_type"
        case recurrence
        case explanation
    }
}

struct SystemCivilizationTrustedActionTemplate: Decodable, Sendable, Identifiable {
    let actionType: String
    let boundedUsefulness: Double
    let receiptCount: Int
    let explanation: String

    var id: String { actionType }

    private enum CodingKeys: String, CodingKey {
        case actionType = "action_type"
        case boundedUsefulness = "bounded_usefulness"
        case receiptCount = "receipt_count"
        case explanation
    }
}

struct SystemCivilizationLongHorizonResearchField: Decodable, Sendable, Identifiable {
    let domain: String
    let persistence: Double
    let crossDomainStrength: Double
    let explanation: String

    var id: String { domain }

    private enum CodingKeys: String, CodingKey {
        case domain
        case persistence
        case crossDomainStrength = "cross_domain_strength"
        case explanation
    }
}

struct SystemCivilizationResilienceStructure: Decodable, Sendable, Identifiable {
    let region: String
    let resilienceScore: Double
    let explanation: String

    var id: String { region }

    private enum CodingKeys: String, CodingKey {
        case region
        case resilienceScore = "resilience_score"
        case explanation
    }
}

struct SystemCivilizationSnapshot: Decodable, Sendable {
    let civicRiskStructures: [SystemCivilizationCivicRiskStructure]
    let durableKnowledgeZones: [SystemCivilizationDurableKnowledgeZone]
    let infrastructureMemory: [SystemCivilizationInfrastructureMemoryEntry]
    let recurringCoordinationPatterns: [SystemCivilizationRecurringCoordinationPattern]
    let trustedActionTemplates: [SystemCivilizationTrustedActionTemplate]
    let longHorizonResearchFields: [SystemCivilizationLongHorizonResearchField]
    let resilienceStructures: [SystemCivilizationResilienceStructure]

    private enum CodingKeys: String, CodingKey {
        case civicRiskStructures = "civic_risk_structures"
        case durableKnowledgeZones = "durable_knowledge_zones"
        case infrastructureMemory = "infrastructure_memory"
        case recurringCoordinationPatterns = "recurring_coordination_patterns"
        case trustedActionTemplates = "trusted_action_templates"
        case longHorizonResearchFields = "long_horizon_research_fields"
        case resilienceStructures = "resilience_structures"
    }

    static let demo = SystemCivilizationSnapshot(
        civicRiskStructures: [
            SystemCivilizationCivicRiskStructure(
                region: "nl-ijmuiden",
                signalFamily: "degradation",
                persistence: 0.82,
                linkedResidueCount: 4,
                explanation: "This region has become civically important because governed degradation activity here repeatedly produced durable residue and knowledge."
            )
        ],
        durableKnowledgeZones: [
            SystemCivilizationDurableKnowledgeZone(
                region: "nl-ijmuiden",
                knowledgeWeight: 0.86,
                persistence: 0.84,
                entropyReductionScore: 0.24,
                explanation: "This region remains visible beyond the moment because governed knowledge here kept lowering uncertainty and held together over time."
            )
        ],
        infrastructureMemory: [
            SystemCivilizationInfrastructureMemoryEntry(
                infrastructureType: "Edge Infrastructure",
                recurrence: 5,
                usefulnessScore: 0.83,
                linkedReceipts: 4,
                explanation: "This infrastructure memory is trusted because receipt-backed outcomes kept proving useful under bounded execution."
            )
        ],
        recurringCoordinationPatterns: [
            SystemCivilizationRecurringCoordinationPattern(
                patternType: "grid correlation",
                recurrence: 5,
                explanation: "This pattern is no longer isolated; it now functions as a stable coordination structure."
            )
        ],
        trustedActionTemplates: [
            SystemCivilizationTrustedActionTemplate(
                actionType: "create_investigation_dossier",
                boundedUsefulness: 0.81,
                receiptCount: 3,
                explanation: "This action template is trusted because bounded executions repeatedly led to receipt-backed useful outcomes."
            )
        ],
        longHorizonResearchFields: [
            SystemCivilizationLongHorizonResearchField(
                domain: "Infrastructure",
                persistence: 0.79,
                crossDomainStrength: 0.76,
                explanation: "This research field persists across time and domains, suggesting long-horizon relevance for governed discovery."
            )
        ],
        resilienceStructures: [
            SystemCivilizationResilienceStructure(
                region: "nl-ijmuiden",
                resilienceScore: 0.81,
                explanation: "This region looks resilient because governed work here repeatedly turned uncertainty into attributable, inspectable outcomes."
            )
        ]
    )
}

struct SystemPlanetaryRiskStructure: Decodable, Sendable, Identifiable {
    let regions: [String]
    let signalFamily: String
    let persistence: Double
    let linkedResidueCount: Int
    let explanation: String

    var id: String { "\(signalFamily)-\(regions.joined(separator: ":"))" }

    private enum CodingKeys: String, CodingKey {
        case regions
        case signalFamily = "signal_family"
        case persistence
        case linkedResidueCount = "linked_residue_count"
        case explanation
    }
}

struct SystemPlanetaryCrossRegionKnowledgeField: Decodable, Sendable, Identifiable {
    let regions: [String]
    let knowledgeWeight: Double
    let persistence: Double
    let entropyReductionScore: Double
    let explanation: String

    var id: String { regions.joined(separator: ":") }

    private enum CodingKeys: String, CodingKey {
        case regions
        case knowledgeWeight = "knowledge_weight"
        case persistence
        case entropyReductionScore = "entropy_reduction_score"
        case explanation
    }
}

struct SystemPlanetaryGlobalInfrastructurePattern: Decodable, Sendable, Identifiable {
    let infrastructureType: String
    let regions: [String]
    let recurrence: Int
    let usefulnessScore: Double
    let linkedReceipts: Int
    let explanation: String

    var id: String { infrastructureType }

    private enum CodingKeys: String, CodingKey {
        case infrastructureType = "infrastructure_type"
        case regions
        case recurrence
        case usefulnessScore = "usefulness_score"
        case linkedReceipts = "linked_receipts"
        case explanation
    }
}

struct SystemPlanetaryCoordinationBottleneck: Decodable, Sendable, Identifiable {
    let patternType: String
    let regions: [String]
    let recurrence: Int
    let explanation: String

    var id: String { patternType }

    private enum CodingKeys: String, CodingKey {
        case patternType = "pattern_type"
        case regions
        case recurrence
        case explanation
    }
}

struct SystemPlanetaryTrustedActionTemplate: Decodable, Sendable, Identifiable {
    let actionType: String
    let crossRegionUsefulness: Double
    let receiptCount: Int
    let explanation: String

    var id: String { actionType }

    private enum CodingKeys: String, CodingKey {
        case actionType = "action_type"
        case crossRegionUsefulness = "cross_region_usefulness"
        case receiptCount = "receipt_count"
        case explanation
    }
}

struct SystemPlanetaryLongHorizonResearchField: Decodable, Sendable, Identifiable {
    let domain: String
    let regions: [String]
    let persistence: Double
    let crossDomainStrength: Double
    let explanation: String

    var id: String { domain }

    private enum CodingKeys: String, CodingKey {
        case domain
        case regions
        case persistence
        case crossDomainStrength = "cross_domain_strength"
        case explanation
    }
}

struct SystemPlanetaryResilienceGradient: Decodable, Sendable, Identifiable {
    let regionGroup: [String]
    let resilienceScore: Double
    let explanation: String

    var id: String { regionGroup.joined(separator: ":") }

    private enum CodingKeys: String, CodingKey {
        case regionGroup = "region_group"
        case resilienceScore = "resilience_score"
        case explanation
    }
}

struct SystemPlanetarySnapshot: Decodable, Sendable {
    let planetaryRiskStructures: [SystemPlanetaryRiskStructure]
    let crossRegionKnowledgeFields: [SystemPlanetaryCrossRegionKnowledgeField]
    let globalInfrastructurePatterns: [SystemPlanetaryGlobalInfrastructurePattern]
    let planetaryCoordinationBottlenecks: [SystemPlanetaryCoordinationBottleneck]
    let trustedActionTemplates: [SystemPlanetaryTrustedActionTemplate]
    let longHorizonResearchFields: [SystemPlanetaryLongHorizonResearchField]
    let resilienceGradients: [SystemPlanetaryResilienceGradient]

    private enum CodingKeys: String, CodingKey {
        case planetaryRiskStructures = "planetary_risk_structures"
        case crossRegionKnowledgeFields = "cross_region_knowledge_fields"
        case globalInfrastructurePatterns = "global_infrastructure_patterns"
        case planetaryCoordinationBottlenecks = "planetary_coordination_bottlenecks"
        case trustedActionTemplates = "trusted_action_templates"
        case longHorizonResearchFields = "long_horizon_research_fields"
        case resilienceGradients = "resilience_gradients"
    }

    static let demo = SystemPlanetarySnapshot(
        planetaryRiskStructures: [
            SystemPlanetaryRiskStructure(
                regions: ["eu-west", "nl-ijmuiden"],
                signalFamily: "degradation",
                persistence: 0.81,
                linkedResidueCount: 6,
                explanation: "This pattern now appears across multiple regions and has become globally relevant."
            )
        ],
        crossRegionKnowledgeFields: [
            SystemPlanetaryCrossRegionKnowledgeField(
                regions: ["eu-west", "nl-ijmuiden"],
                knowledgeWeight: 0.78,
                persistence: 0.8,
                entropyReductionScore: 0.22,
                explanation: "This structure is no longer local; it persists across regions and domains."
            )
        ],
        globalInfrastructurePatterns: [
            SystemPlanetaryGlobalInfrastructurePattern(
                infrastructureType: "Edge Infrastructure",
                regions: ["eu-west", "nl-ijmuiden"],
                recurrence: 6,
                usefulnessScore: 0.82,
                linkedReceipts: 4,
                explanation: "This infrastructure pattern now spans multiple regions, suggesting planetary relevance without centralizing authority."
            )
        ],
        planetaryCoordinationBottlenecks: [
            SystemPlanetaryCoordinationBottleneck(
                patternType: "grid correlation",
                regions: ["eu-west", "nl-ijmuiden"],
                recurrence: 5,
                explanation: "This coordination pattern now recurs across regions and may require multi-region human attention."
            )
        ],
        trustedActionTemplates: [
            SystemPlanetaryTrustedActionTemplate(
                actionType: "create_investigation_dossier",
                crossRegionUsefulness: 0.8,
                receiptCount: 4,
                explanation: "This action template is trusted in multiple contexts and may have planetary usefulness."
            )
        ],
        longHorizonResearchFields: [
            SystemPlanetaryLongHorizonResearchField(
                domain: "Infrastructure",
                regions: ["eu-west", "kenya-west", "nl-ijmuiden"],
                persistence: 0.79,
                crossDomainStrength: 0.75,
                explanation: "This research field now shows cross-region persistence, suggesting long-horizon significance."
            )
        ],
        resilienceGradients: [
            SystemPlanetaryResilienceGradient(
                regionGroup: ["eu-west", "nl-ijmuiden"],
                resilienceScore: 0.77,
                explanation: "These regions form a visible resilience gradient because governed work keeps turning uncertainty into stable outcomes across contexts."
            )
        ]
    )
}

struct SystemCosmicEnduringHumanQuestion: Decodable, Sendable, Identifiable {
    let theme: String
    let persistence: Double
    let linkedKnowledgeCount: Int
    let explanation: String

    var id: String { theme }

    private enum CodingKeys: String, CodingKey {
        case theme
        case persistence
        case linkedKnowledgeCount = "linked_knowledge_count"
        case explanation
    }
}

struct SystemCosmicLongHorizonKnowledgeField: Decodable, Sendable, Identifiable {
    let domain: String
    let persistence: Double
    let crossDomainStrength: Double
    let entropyReductionScore: Double
    let explanation: String

    var id: String { domain }

    private enum CodingKeys: String, CodingKey {
        case domain
        case persistence
        case crossDomainStrength = "cross_domain_strength"
        case entropyReductionScore = "entropy_reduction_score"
        case explanation
    }
}

struct SystemCosmicDeepResilienceStructure: Decodable, Sendable, Identifiable {
    let structureType: String
    let persistence: Double
    let usefulnessScore: Double
    let explanation: String

    var id: String { structureType }

    private enum CodingKeys: String, CodingKey {
        case structureType = "structure_type"
        case persistence
        case usefulnessScore = "usefulness_score"
        case explanation
    }
}

struct SystemCosmicRecurringExplorationFrontier: Decodable, Sendable, Identifiable {
    let frontier: String
    let recurrence: Int
    let linkedDiscoveries: Int
    let explanation: String

    var id: String { frontier }

    private enum CodingKeys: String, CodingKey {
        case frontier
        case recurrence
        case linkedDiscoveries = "linked_discoveries"
        case explanation
    }
}

struct SystemCosmicTruthPreservingStructure: Decodable, Sendable, Identifiable {
    let structureType: String
    let trustWeight: Double
    let provenanceDepth: Double
    let explanation: String

    var id: String { structureType }

    private enum CodingKeys: String, CodingKey {
        case structureType = "structure_type"
        case trustWeight = "trust_weight"
        case provenanceDepth = "provenance_depth"
        case explanation
    }
}

struct SystemCosmicStewardshipPattern: Decodable, Sendable, Identifiable {
    let patternType: String
    let persistence: Double
    let governanceSafety: Double
    let explanation: String

    var id: String { patternType }

    private enum CodingKeys: String, CodingKey {
        case patternType = "pattern_type"
        case persistence
        case governanceSafety = "governance_safety"
        case explanation
    }
}

struct SystemCosmicCivilizationPlanetaryBridge: Decodable, Sendable, Identifiable {
    let bridgeType: String
    let recurrence: Int
    let significance: Double
    let explanation: String

    var id: String { bridgeType }

    private enum CodingKeys: String, CodingKey {
        case bridgeType = "bridge_type"
        case recurrence
        case significance
        case explanation
    }
}

struct SystemCosmicFutureSignificanceSignal: Decodable, Sendable, Identifiable {
    let signalFamily: String
    let longHorizonScore: Double
    let uncertainty: Double
    let explanation: String

    var id: String { signalFamily }

    private enum CodingKeys: String, CodingKey {
        case signalFamily = "signal_family"
        case longHorizonScore = "long_horizon_score"
        case uncertainty
        case explanation
    }
}

struct SystemCosmicSnapshot: Decodable, Sendable {
    let enduringHumanQuestions: [SystemCosmicEnduringHumanQuestion]
    let longHorizonKnowledgeFields: [SystemCosmicLongHorizonKnowledgeField]
    let deepResilienceStructures: [SystemCosmicDeepResilienceStructure]
    let recurringExplorationFrontiers: [SystemCosmicRecurringExplorationFrontier]
    let truthPreservingStructures: [SystemCosmicTruthPreservingStructure]
    let stewardshipPatterns: [SystemCosmicStewardshipPattern]
    let civilizationToPlanetaryBridges: [SystemCosmicCivilizationPlanetaryBridge]
    let futureSignificanceSignals: [SystemCosmicFutureSignificanceSignal]

    private enum CodingKeys: String, CodingKey {
        case enduringHumanQuestions = "enduring_human_questions"
        case longHorizonKnowledgeFields = "long_horizon_knowledge_fields"
        case deepResilienceStructures = "deep_resilience_structures"
        case recurringExplorationFrontiers = "recurring_exploration_frontiers"
        case truthPreservingStructures = "truth_preserving_structures"
        case stewardshipPatterns = "stewardship_patterns"
        case civilizationToPlanetaryBridges = "civilization_to_planetary_bridges"
        case futureSignificanceSignals = "future_significance_signals"
    }

    static let demo = SystemCosmicSnapshot(
        enduringHumanQuestions: [
            SystemCosmicEnduringHumanQuestion(
                theme: "Resilience",
                persistence: 0.83,
                linkedKnowledgeCount: 6,
                explanation: "This theme remains significant because it persists across governed knowledge, residue, and discovery pressure, while still requiring human stewardship and interpretation."
            )
        ],
        longHorizonKnowledgeFields: [
            SystemCosmicLongHorizonKnowledgeField(
                domain: "Infrastructure",
                persistence: 0.81,
                crossDomainStrength: 0.77,
                entropyReductionScore: 0.72,
                explanation: "This field appears to matter beyond immediate operations because it keeps reducing uncertainty across regions, domains, and governed outcomes."
            )
        ],
        deepResilienceStructures: [
            SystemCosmicDeepResilienceStructure(
                structureType: "Governed resilience",
                persistence: 0.8,
                usefulnessScore: 0.79,
                explanation: "This resilience structure remains visible because governed work keeps turning uncertainty into stable, inspectable outcomes across changing contexts."
            )
        ],
        recurringExplorationFrontiers: [
            SystemCosmicRecurringExplorationFrontier(
                frontier: "Research frontier",
                recurrence: 5,
                linkedDiscoveries: 7,
                explanation: "This is not a resolved structure, but a frontier that keeps returning as governed discovery crosses domains and deepens the question."
            )
        ],
        truthPreservingStructures: [
            SystemCosmicTruthPreservingStructure(
                structureType: "Receipt continuity",
                trustWeight: 0.82,
                provenanceDepth: 0.76,
                explanation: "This structure remains trustworthy because receipt-linked outcomes keep preserving attribution and continuity across governed action."
            )
        ],
        stewardshipPatterns: [
            SystemCosmicStewardshipPattern(
                patternType: "Grid Correlation",
                persistence: 0.79,
                governanceSafety: 0.88,
                explanation: "This pattern suggests long-horizon relevance, but still requires human judgment, bounded action, and care at every step."
            )
        ],
        civilizationToPlanetaryBridges: [
            SystemCosmicCivilizationPlanetaryBridge(
                bridgeType: "Ijmuiden To Planetary Knowledge",
                recurrence: 4,
                significance: 0.74,
                explanation: "This bridge matters because knowledge that first stabilized locally is now persisting across regions and starting to matter at broader human scale."
            )
        ],
        futureSignificanceSignals: [
            SystemCosmicFutureSignificanceSignal(
                signalFamily: "degradation",
                longHorizonScore: 0.78,
                uncertainty: 0.24,
                explanation: "This signal family keeps returning with widening relevance, but it remains a prompt for human attention rather than a directive."
            )
        ]
    )
}

struct ObservatoryAlert: Decodable, Sendable, Identifiable {
    let id: String
    let title: String?
    let summary: String?
    let timestampIso: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case alertId
        case title
        case summary
        case message
        case timestampIso
        case timestamp
        case escalatedAtIso
        case createdAtIso
    }

    init(id: String, title: String?, summary: String?, timestampIso: String?) {
        self.id = id
        self.title = title
        self.summary = summary
        self.timestampIso = timestampIso
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
            ?? c.decodeIfPresent(String.self, forKey: .alertId)
            ?? UUID().uuidString
        title = try c.decodeIfPresent(String.self, forKey: .title)
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
            ?? c.decodeIfPresent(String.self, forKey: .message)
        timestampIso = try c.decodeIfPresent(String.self, forKey: .timestampIso)
            ?? c.decodeIfPresent(String.self, forKey: .timestamp)
            ?? c.decodeIfPresent(String.self, forKey: .escalatedAtIso)
            ?? c.decodeIfPresent(String.self, forKey: .createdAtIso)
    }
}

struct FabricEmergence: Decodable, Sendable {
    let strongestCell: String?
    let warmLayer: String?
    let suggestions: [String]
    let clusters: [KnowledgeEmergenceCluster]

    private enum CodingKeys: String, CodingKey {
        case strongestCell
        case warmLayer
        case suggestions
        case clusters
    }

    init(strongestCell: String?, warmLayer: String?, suggestions: [String], clusters: [KnowledgeEmergenceCluster]) {
        self.strongestCell = strongestCell
        self.warmLayer = warmLayer
        self.suggestions = suggestions
        self.clusters = clusters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        strongestCell = try c.decodeIfPresent(String.self, forKey: .strongestCell)
        warmLayer = try c.decodeIfPresent(String.self, forKey: .warmLayer)
        suggestions = try c.decodeIfPresent([String].self, forKey: .suggestions) ?? []
        clusters = try c.decodeIfPresent([KnowledgeEmergenceCluster].self, forKey: .clusters) ?? []
    }
}

struct LobbyChallenge: Decodable, Sendable, Identifiable {
    let id: String
    let title: String?
    let key: String?
    let createdAtIso: String?
    let status: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case challengeId
        case title
        case key
        case suggestedIntentKey
        case createdAtIso
        case status
    }

    init(id: String, title: String?, key: String?, createdAtIso: String?, status: String?) {
        self.id = id
        self.title = title
        self.key = key
        self.createdAtIso = createdAtIso
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
            ?? c.decodeIfPresent(String.self, forKey: .challengeId)
            ?? UUID().uuidString
        title = try c.decodeIfPresent(String.self, forKey: .title)
        key = try c.decodeIfPresent(String.self, forKey: .key)
            ?? c.decodeIfPresent(String.self, forKey: .suggestedIntentKey)
        createdAtIso = try c.decodeIfPresent(String.self, forKey: .createdAtIso)
        status = try c.decodeIfPresent(String.self, forKey: .status)
    }
}

struct SignalsState: Decodable, Sendable {
    let signalsToday: Int?
    let challengesToday: Int?
    let proposalsToday: Int?
    let executedActions: Int?
    let runCount: Int?
    let activeSourceCount: Int?
    let totalSignals: Int?
    let lastRunAtIso: String?
    let lastError: String?

    private enum CodingKeys: String, CodingKey {
        case signalsToday
        case challengesToday
        case proposalsToday
        case executedActions
        case signals
        case challenges
        case proposals
        case executed
        case runCount
        case activeSourceCount
        case totalSignals
        case lastRunAtIso
        case lastError
    }

    init(
        signalsToday: Int?,
        challengesToday: Int?,
        proposalsToday: Int?,
        executedActions: Int?,
        runCount: Int? = nil,
        activeSourceCount: Int? = nil,
        totalSignals: Int? = nil,
        lastRunAtIso: String? = nil,
        lastError: String? = nil
    ) {
        self.signalsToday = signalsToday
        self.challengesToday = challengesToday
        self.proposalsToday = proposalsToday
        self.executedActions = executedActions
        self.runCount = runCount
        self.activeSourceCount = activeSourceCount
        self.totalSignals = totalSignals
        self.lastRunAtIso = lastRunAtIso
        self.lastError = lastError
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        signalsToday = try c.decodeIfPresent(Int.self, forKey: .signalsToday)
            ?? c.decodeIfPresent(Int.self, forKey: .signals)
        challengesToday = try c.decodeIfPresent(Int.self, forKey: .challengesToday)
            ?? c.decodeIfPresent(Int.self, forKey: .challenges)
        proposalsToday = try c.decodeIfPresent(Int.self, forKey: .proposalsToday)
            ?? c.decodeIfPresent(Int.self, forKey: .proposals)
        executedActions = try c.decodeIfPresent(Int.self, forKey: .executedActions)
            ?? c.decodeIfPresent(Int.self, forKey: .executed)
        runCount = try c.decodeIfPresent(Int.self, forKey: .runCount)
        activeSourceCount = try c.decodeIfPresent(Int.self, forKey: .activeSourceCount)
        totalSignals = try c.decodeIfPresent(Int.self, forKey: .totalSignals)
        lastRunAtIso = try c.decodeIfPresent(String.self, forKey: .lastRunAtIso)
        lastError = try c.decodeIfPresent(String.self, forKey: .lastError)
    }
}

struct ResearchLaneSourceSummary: Decodable, Sendable, Identifiable {
    let source: String
    let signalCount: Int

    var id: String { source }
}

struct ResearchLaneSummary: Decodable, Sendable {
    let signalCount24h: Int
    let sourceCount: Int
    let highConfidenceCount: Int
    let activitySpikeCount: Int
    let topDomains: [String]
    let topCategories: [String]
    let sourceBreakdown: [ResearchLaneSourceSummary]
    let latestDetectedAtIso: String?

    private enum CodingKeys: String, CodingKey {
        case signalCount24h
        case sourceCount
        case highConfidenceCount
        case activitySpikeCount
        case topDomains
        case topCategories
        case sourceBreakdown
        case latestDetectedAtIso
    }
}

struct DiscoveryGravityStrongestEdge: Decodable, Sendable {
    let edgeId: String
    let score: Double
    let explanation: String
    let crossDomain: Bool

    private enum CodingKeys: String, CodingKey {
        case edgeId = "edge_id"
        case score
        case explanation
        case crossDomain = "cross_domain"
    }
}

struct DiscoveryGravitySummary: Decodable, Sendable {
    let activeEdgeCount: Int
    let crossDomainPullCount: Int
    let strongestEdge: DiscoveryGravityStrongestEdge?
    let persistenceTrend: String
    let anomalyMagnetScore: Double

    private enum CodingKeys: String, CodingKey {
        case activeEdgeCount = "active_edge_count"
        case crossDomainPullCount = "cross_domain_pull_count"
        case strongestEdge = "strongest_edge"
        case persistenceTrend = "persistence_trend"
        case anomalyMagnetScore = "anomaly_magnet_score"
    }
}

struct DiscoveryGravityFactors: Decodable, Sendable {
    let semantic: Double
    let temporal: Double
    let regional: Double
    let evidence: Double
    let humanAttention: Double
    let residue: Double

    private enum CodingKeys: String, CodingKey {
        case semantic
        case temporal
        case regional
        case evidence
        case humanAttention = "human_attention"
        case residue
    }
}

struct DiscoveryGravityEdge: Decodable, Sendable, Identifiable {
    let edgeId: String
    let fromId: String
    let toId: String
    let fromType: String
    let toType: String
    let score: Double
    let factors: DiscoveryGravityFactors
    let timestamp: String?
    let active: Bool
    let domainTags: [String]
    let region: String
    let crossDomain: Bool
    let explanation: String
    let recurrenceCount: Int

    var id: String { edgeId }

    private enum CodingKeys: String, CodingKey {
        case edgeId = "edge_id"
        case fromId = "from_id"
        case toId = "to_id"
        case fromType = "from_type"
        case toType = "to_type"
        case score
        case factors
        case timestamp
        case active
        case domainTags = "domain_tags"
        case region
        case crossDomain = "cross_domain"
        case explanation
        case recurrenceCount = "recurrence_count"
    }
}

struct SignalsRuntimeSnapshot: Decodable, Sendable {
    let started: Bool?
    let startedAtIso: String?
    let lastRunAtIso: String?
    let runCount: Int
    let totalSignals: Int
    let activeSourceCount: Int
    let lastError: String?
    let lastSignals: [SignalsRuntimeSignal]
    let lastChallenges: [SignalsRuntimeChallenge]
    let emergenceClusters: [SignalsRuntimeEmergenceCluster]
    let gravityHotspots: [RadarGravityHotspot]
    let discoveryCandidates: [RadarDiscoveryCandidate]
    let researchLane: ResearchLaneSummary?
    let gravityEdges: [DiscoveryGravityEdge]
    let gravitySummary: DiscoveryGravitySummary?

    private enum CodingKeys: String, CodingKey {
        case started
        case startedAtIso
        case lastRunAtIso
        case runCount
        case totalSignals
        case activeSourceCount
        case lastError
        case lastSignals
        case lastChallenges
        case emergenceClusters
        case gravityHotspots
        case discoveryCandidates
        case researchLane
        case gravityEdges
        case gravitySummary
    }

    init(
        started: Bool?,
        startedAtIso: String?,
        lastRunAtIso: String?,
        runCount: Int,
        totalSignals: Int,
        activeSourceCount: Int,
        lastError: String?,
        lastSignals: [SignalsRuntimeSignal],
        lastChallenges: [SignalsRuntimeChallenge],
        emergenceClusters: [SignalsRuntimeEmergenceCluster],
        gravityHotspots: [RadarGravityHotspot],
        discoveryCandidates: [RadarDiscoveryCandidate],
        researchLane: ResearchLaneSummary? = nil,
        gravityEdges: [DiscoveryGravityEdge] = [],
        gravitySummary: DiscoveryGravitySummary? = nil
    ) {
        self.started = started
        self.startedAtIso = startedAtIso
        self.lastRunAtIso = lastRunAtIso
        self.runCount = runCount
        self.totalSignals = totalSignals
        self.activeSourceCount = activeSourceCount
        self.lastError = lastError
        self.lastSignals = lastSignals
        self.lastChallenges = lastChallenges
        self.emergenceClusters = emergenceClusters
        self.gravityHotspots = gravityHotspots
        self.discoveryCandidates = discoveryCandidates
        self.researchLane = researchLane
        self.gravityEdges = gravityEdges
        self.gravitySummary = gravitySummary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        started = try c.decodeIfPresent(Bool.self, forKey: .started)
        startedAtIso = try c.decodeIfPresent(String.self, forKey: .startedAtIso)
        lastRunAtIso = try c.decodeIfPresent(String.self, forKey: .lastRunAtIso)
        runCount = try c.decodeIfPresent(Int.self, forKey: .runCount) ?? 0
        totalSignals = try c.decodeIfPresent(Int.self, forKey: .totalSignals) ?? 0
        activeSourceCount = try c.decodeIfPresent(Int.self, forKey: .activeSourceCount) ?? 0
        lastError = try c.decodeIfPresent(String.self, forKey: .lastError)
        lastSignals = try c.decodeIfPresent([SignalsRuntimeSignal].self, forKey: .lastSignals) ?? []
        lastChallenges = try c.decodeIfPresent([SignalsRuntimeChallenge].self, forKey: .lastChallenges) ?? []
        emergenceClusters = try c.decodeIfPresent([SignalsRuntimeEmergenceCluster].self, forKey: .emergenceClusters) ?? []
        gravityHotspots = try c.decodeIfPresent([RadarGravityHotspot].self, forKey: .gravityHotspots) ?? []
        discoveryCandidates = try c.decodeIfPresent([RadarDiscoveryCandidate].self, forKey: .discoveryCandidates) ?? []
        researchLane = try c.decodeIfPresent(ResearchLaneSummary.self, forKey: .researchLane)
        gravityEdges = try c.decodeIfPresent([DiscoveryGravityEdge].self, forKey: .gravityEdges) ?? []
        gravitySummary = try c.decodeIfPresent(DiscoveryGravitySummary.self, forKey: .gravitySummary)
    }
}

struct SignalsRuntimeSignal: Decodable, Sendable, Identifiable {
    let signalId: String
    let sourceId: String?
    let detectedAtIso: String?
    let summary: String?

    var id: String { signalId }

    private enum CodingKeys: String, CodingKey {
        case signalId
        case id
        case sourceId
        case source
        case detectedAtIso
        case timestamp
        case summary
        case title
    }

    init(signalId: String, sourceId: String?, detectedAtIso: String?, summary: String?) {
        self.signalId = signalId
        self.sourceId = sourceId
        self.detectedAtIso = detectedAtIso
        self.summary = summary
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        signalId = c.decodeLossyString(forKey: .signalId)
            ?? c.decodeLossyString(forKey: .id)
            ?? UUID().uuidString
        sourceId = c.decodeLossyString(forKey: .sourceId)
            ?? c.decodeLossyString(forKey: .source)
        detectedAtIso = c.decodeLossyString(forKey: .detectedAtIso)
            ?? c.decodeLossyString(forKey: .timestamp)
        summary = c.decodeLossyString(forKey: .summary)
            ?? c.decodeLossyString(forKey: .title)
    }
}

struct SignalsRuntimeChallenge: Decodable, Sendable, Identifiable {
    let challengeId: String
    let createdAtIso: String?
    let title: String?
    let status: String?

    var id: String { challengeId }

    private enum CodingKeys: String, CodingKey {
        case challengeId
        case id
        case createdAtIso
        case timestamp
        case title
        case status
    }

    init(challengeId: String, createdAtIso: String?, title: String?, status: String?) {
        self.challengeId = challengeId
        self.createdAtIso = createdAtIso
        self.title = title
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        challengeId = c.decodeLossyString(forKey: .challengeId)
            ?? c.decodeLossyString(forKey: .id)
            ?? UUID().uuidString
        createdAtIso = c.decodeLossyString(forKey: .createdAtIso)
            ?? c.decodeLossyString(forKey: .timestamp)
        title = c.decodeLossyString(forKey: .title)
        status = c.decodeLossyString(forKey: .status)
    }
}

struct SignalsRuntimeEmergenceCluster: Decodable, Sendable, Identifiable {
    let clusterId: String
    let dimensions: [String]
    let relevanceScore: Double
    let summary: String?
    let escalatesToIphone: Bool

    var id: String { clusterId }

    private enum CodingKeys: String, CodingKey {
        case clusterId
        case id
        case dimensions
        case sourceTypes
        case relevanceScore
        case densityScore
        case score
        case summary
        case escalatesToIphone
        case isEmergence
    }

    init(
        clusterId: String,
        dimensions: [String],
        relevanceScore: Double,
        summary: String?,
        escalatesToIphone: Bool
    ) {
        self.clusterId = clusterId
        self.dimensions = dimensions
        self.relevanceScore = relevanceScore
        self.summary = summary
        self.escalatesToIphone = escalatesToIphone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clusterId = c.decodeLossyString(forKey: .clusterId)
            ?? c.decodeLossyString(forKey: .id)
            ?? UUID().uuidString
        dimensions = try c.decodeIfPresent([String].self, forKey: .dimensions)
            ?? c.decodeIfPresent([String].self, forKey: .sourceTypes)
            ?? []
        relevanceScore = try c.decodeIfPresent(Double.self, forKey: .relevanceScore)
            ?? c.decodeIfPresent(Double.self, forKey: .densityScore)
            ?? c.decodeIfPresent(Double.self, forKey: .score)
            ?? 0
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        escalatesToIphone = try c.decodeIfPresent(Bool.self, forKey: .escalatesToIphone)
            ?? c.decodeIfPresent(Bool.self, forKey: .isEmergence)
            ?? (relevanceScore >= 0.7)
    }
}

struct KnowledgeEmergence: Decodable, Sendable {
    let clusters: [KnowledgeEmergenceCluster]

    private enum CodingKeys: String, CodingKey {
        case clusters
    }

    init(clusters: [KnowledgeEmergenceCluster]) {
        self.clusters = clusters
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clusters = try c.decodeIfPresent([KnowledgeEmergenceCluster].self, forKey: .clusters) ?? []
    }
}

struct KnowledgeEmergenceCluster: Decodable, Sendable, Identifiable {
    let id: String
    let summary: String?
    let score: Double?

    private enum CodingKeys: String, CodingKey {
        case id
        case clusterId
        case summary
        case score
        case relevanceScore
        case densityScore
    }

    init(id: String, summary: String?, score: Double?) {
        self.id = id
        self.summary = summary
        self.score = score
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
            ?? c.decodeIfPresent(String.self, forKey: .clusterId)
            ?? UUID().uuidString
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        score = try c.decodeIfPresent(Double.self, forKey: .score)
            ?? c.decodeIfPresent(Double.self, forKey: .relevanceScore)
            ?? c.decodeIfPresent(Double.self, forKey: .densityScore)
    }
}

struct ObservatoryStreamFeed: Decodable, Sendable {
    let ok: Bool?
    let events: [ObservatoryStreamEvent]
    let pendingCount: Int

    enum CodingKeys: String, CodingKey {
        case ok
        case events
        case items
        case data
        case pendingCount
    }

    init(ok: Bool?, events: [ObservatoryStreamEvent], pendingCount: Int) {
        self.ok = ok
        self.events = events
        self.pendingCount = pendingCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        // Try strict decode first, then lossy decode per-element to survive bad entries
        events = (try? c.decodeIfPresent([ObservatoryStreamEvent].self, forKey: .events))
            ?? (try? c.decodeIfPresent([ObservatoryStreamEvent].self, forKey: .items))
            ?? (try? c.decodeIfPresent([ObservatoryStreamEvent].self, forKey: .data))
            ?? Self.decodeLossyEvents(from: c, forKey: .events)
            ?? Self.decodeLossyEvents(from: c, forKey: .items)
            ?? Self.decodeLossyEvents(from: c, forKey: .data)
            ?? []
        pendingCount = try c.decodeIfPresent(Int.self, forKey: .pendingCount) ?? 0
    }

    /// Decode events lossily — skips individual elements that fail to decode.
    private static func decodeLossyEvents(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> [ObservatoryStreamEvent]? {
        guard var arrayContainer = try? container.nestedUnkeyedContainer(forKey: key) else {
            return nil
        }
        var events: [ObservatoryStreamEvent] = []
        while !arrayContainer.isAtEnd {
            if let event = try? arrayContainer.decode(ObservatoryStreamEvent.self) {
                events.append(event)
            } else {
                _ = try? arrayContainer.decode(LossyJSONScalarPublic.self)
            }
        }
        return events.isEmpty ? nil : events
    }
}

struct ObservatoryStreamEvent: Decodable, Sendable, Identifiable {
    let id: String
    let type: String
    let timestampIso: String?
    let event: String?
    let clusterId: String?
    let proposalId: String?
    let agentId: String?
    let title: String?
    let summary: String?
    let signalId: String?
    let sourceId: String?
    let challengeId: String?
    let decision: String?
    let reason: String?
    let risk: String?
    let peerId: String?
    let explanation: String?
    let gravityScore: Double?
    let band: String?
    let candidateScore: Double?
    let candidateType: String?
    let candidateId: String?
    let crossDomain: Bool?
    let rank: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case eventId
        case type
        case timestampIso
        case timestamp
        case event
        case clusterId
        case proposalId
        case agentId
        case title
        case summary
        case signalId
        case sourceId
        case challengeId
        case decision
        case reason
        case risk
        case peerId
        case explanation
        case gravityScore
        case band
        case candidateScore
        case candidateType
        case candidateId
        case crossDomain
        case rank
    }

    /// The best display text for this event.
    var displayTitle: String {
        if let explanation, !explanation.isEmpty { return explanation }
        if let title, !title.isEmpty { return title }
        if let summary, !summary.isEmpty { return summary }
        if let proposalId, !proposalId.isEmpty { return proposalId }
        if let clusterId, !clusterId.isEmpty { return clusterId }
        if let challengeId, !challengeId.isEmpty { return challengeId }
        if let signalId, !signalId.isEmpty { return signalId }
        if let eventName = event, !eventName.isEmpty { return eventName }
        return "event"
    }

    var isGravityHotspot: Bool { type == "gravity_hotspot" }
    var isDiscoveryCandidate: Bool { type == "discovery_candidate" }

    init(
        id: String,
        type: String,
        timestampIso: String?,
        event: String?,
        clusterId: String? = nil,
        proposalId: String?,
        agentId: String?,
        title: String?,
        summary: String? = nil,
        signalId: String? = nil,
        sourceId: String? = nil,
        challengeId: String? = nil,
        decision: String?,
        reason: String?,
        risk: String?,
        peerId: String?,
        explanation: String? = nil,
        gravityScore: Double? = nil,
        band: String? = nil,
        candidateScore: Double? = nil,
        candidateType: String? = nil,
        candidateId: String? = nil,
        crossDomain: Bool? = nil,
        rank: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.timestampIso = timestampIso
        self.event = event
        self.clusterId = clusterId
        self.proposalId = proposalId
        self.agentId = agentId
        self.title = title
        self.summary = summary
        self.signalId = signalId
        self.sourceId = sourceId
        self.challengeId = challengeId
        self.decision = decision
        self.reason = reason
        self.risk = risk
        self.peerId = peerId
        self.explanation = explanation
        self.gravityScore = gravityScore
        self.band = band
        self.candidateScore = candidateScore
        self.candidateType = candidateType
        self.candidateId = candidateId
        self.crossDomain = crossDomain
        self.rank = rank
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = c.decodeLossyString(forKey: .type) ?? "event"
        timestampIso = c.decodeLossyString(forKey: .timestampIso)
            ?? c.decodeLossyString(forKey: .timestamp)
        event = c.decodeLossyString(forKey: .event)
        clusterId = c.decodeLossyString(forKey: .clusterId)
        proposalId = c.decodeLossyString(forKey: .proposalId)
        agentId = c.decodeLossyString(forKey: .agentId)
        title = c.decodeLossyString(forKey: .title)
        summary = c.decodeLossyString(forKey: .summary)
        signalId = c.decodeLossyString(forKey: .signalId)
        sourceId = c.decodeLossyString(forKey: .sourceId)
        challengeId = c.decodeLossyString(forKey: .challengeId)
        decision = c.decodeLossyString(forKey: .decision)
        reason = c.decodeLossyString(forKey: .reason)
        risk = c.decodeLossyString(forKey: .risk)
        peerId = c.decodeLossyString(forKey: .peerId)
        explanation = c.decodeLossyString(forKey: .explanation)
        gravityScore = try c.decodeIfPresent(Double.self, forKey: .gravityScore)
        band = c.decodeLossyString(forKey: .band)
        candidateScore = try c.decodeIfPresent(Double.self, forKey: .candidateScore)
        candidateType = c.decodeLossyString(forKey: .candidateType)
        candidateId = c.decodeLossyString(forKey: .candidateId)
        crossDomain = try c.decodeIfPresent(Bool.self, forKey: .crossDomain)
        rank = try c.decodeIfPresent(Int.self, forKey: .rank)

        let decodedId: String? = c.decodeLossyString(forKey: .id)
            ?? c.decodeLossyString(forKey: .eventId)
        if let decodedId {
            id = decodedId
        } else {
            let parts: [String] = [
                type,
                timestampIso ?? "",
                clusterId ?? "",
                proposalId ?? "",
                signalId ?? "",
                challengeId ?? "",
                candidateId ?? "",
                event ?? "",
                agentId ?? "",
                decision ?? "",
                reason ?? ""
            ]
            id = parts.joined(separator: "|")
        }
    }

}

/// Public version of LossyJSONScalar for use in lossy array decoding.
struct LossyJSONScalarPublic: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let _ = try? container.decode(String.self) { return }
        if let _ = try? container.decode(Int.self) { return }
        if let _ = try? container.decode(Double.self) { return }
        if let _ = try? container.decode(Bool.self) { return }
        if let _ = try? container.decode([String: LossyJSONScalarPublic].self) { return }
        if let _ = try? container.decode([LossyJSONScalarPublic].self) { return }
        // Accept anything
    }
}

struct RadarStatusSnapshot: Decodable, Sendable {
    let store: RadarStoreStatus?
    let collector: RadarCollectorStatus?
}

struct RadarStoreStatus: Decodable, Sendable {
    let activationCount: Int
    let collisionCount: Int
    let emergenceCount: Int
    let lastFetchBySource: [String: String]
    let hotClusters: [RadarHotCluster]
    let topSignals: [RadarTopSignal]

    private enum CodingKeys: String, CodingKey {
        case activationCount
        case collisionCount
        case emergenceCount
        case lastFetchBySource
        case hotClusters
        case topSignals
    }

    init(
        activationCount: Int,
        collisionCount: Int,
        emergenceCount: Int,
        lastFetchBySource: [String: String],
        hotClusters: [RadarHotCluster],
        topSignals: [RadarTopSignal]
    ) {
        self.activationCount = activationCount
        self.collisionCount = collisionCount
        self.emergenceCount = emergenceCount
        self.lastFetchBySource = lastFetchBySource
        self.hotClusters = hotClusters
        self.topSignals = topSignals
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activationCount = try c.decodeIfPresent(Int.self, forKey: .activationCount) ?? 0
        collisionCount = try c.decodeIfPresent(Int.self, forKey: .collisionCount) ?? 0
        emergenceCount = try c.decodeIfPresent(Int.self, forKey: .emergenceCount) ?? 0
        lastFetchBySource = try c.decodeIfPresent([String: String].self, forKey: .lastFetchBySource) ?? [:]
        hotClusters = try c.decodeIfPresent([RadarHotCluster].self, forKey: .hotClusters) ?? []
        topSignals = try c.decodeIfPresent([RadarTopSignal].self, forKey: .topSignals) ?? []
    }
}

struct RadarCollectorStatus: Decodable, Sendable {
    let isRunning: Bool
    let lastRun: String?

    private enum CodingKeys: String, CodingKey {
        case isRunning
        case lastRun
    }

    init(isRunning: Bool, lastRun: String?) {
        self.isRunning = isRunning
        self.lastRun = lastRun
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isRunning = try c.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false
        lastRun = try c.decodeIfPresent(String.self, forKey: .lastRun)
    }
}

struct RadarHotCluster: Decodable, Sendable, Identifiable {
    let cluster: String
    let count: Int

    var id: String { cluster }

    private enum CodingKeys: String, CodingKey {
        case cluster
        case count
    }

    init(cluster: String, count: Int) {
        self.cluster = cluster
        self.count = count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cluster = try c.decodeIfPresent(String.self, forKey: .cluster) ?? "unknown"
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

struct RadarTopSignal: Decodable, Sendable, Identifiable {
    let title: String
    let source: String
    let residue: Double

    var id: String { "\(source)|\(title)" }

    private enum CodingKeys: String, CodingKey {
        case title
        case source
        case residue
    }

    init(title: String, source: String, residue: Double) {
        self.title = title
        self.source = source
        self.residue = residue
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled signal"
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "unknown"
        residue = try c.decodeIfPresent(Double.self, forKey: .residue) ?? 0
    }
}

struct RadarActivation: Decodable, Sendable, Identifiable {
    let id: String
    let source: String
    let title: String
    let summary: String
    let residue: Double
    let timestampIso: String?
    let clusters: [String]
    let cellIds: [String]

    private enum CodingKeys: String, CodingKey {
        case activationId
        case id
        case signal
        case source
        case title
        case summary
        case residue
        case residueValue
        case timestamp
        case timestampIso
        case activatedClusters
        case clusters
        case cells
    }

    private struct SignalPayload: Decodable {
        let source: String?
        let title: String?
        let summary: String?
        let fetchedAtIso: String?
        let timestamp: String?
    }

    private struct ClusterPayload: Decodable {
        let cluster: String?
        let label: String?
    }

    private struct CellPayload: Decodable {
        let cellId: String?
    }

    init(
        id: String,
        source: String,
        title: String,
        summary: String,
        residue: Double,
        timestampIso: String?,
        clusters: [String],
        cellIds: [String]
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.summary = summary
        self.residue = residue
        self.timestampIso = timestampIso
        self.clusters = clusters
        self.cellIds = cellIds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let signal = try c.decodeIfPresent(SignalPayload.self, forKey: .signal)

        source = try c.decodeIfPresent(String.self, forKey: .source)
            ?? signal?.source
            ?? "unknown"
        title = try c.decodeIfPresent(String.self, forKey: .title)
            ?? signal?.title
            ?? "Untitled signal"
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
            ?? signal?.summary
            ?? ""
        residue = try c.decodeIfPresent(Double.self, forKey: .residueValue)
            ?? c.decodeIfPresent(Double.self, forKey: .residue)
            ?? 0
        timestampIso = try c.decodeIfPresent(String.self, forKey: .timestampIso)
            ?? c.decodeIfPresent(String.self, forKey: .timestamp)
            ?? signal?.fetchedAtIso
            ?? signal?.timestamp

        if let raw = (try? c.decodeIfPresent([String].self, forKey: .activatedClusters)) ?? nil {
            clusters = raw.sorted()
        } else if let raw = (try? c.decodeIfPresent([String].self, forKey: .clusters)) ?? nil {
            clusters = raw.sorted()
        } else if let raw = (try? c.decodeIfPresent([ClusterPayload].self, forKey: .clusters)) ?? nil {
            clusters = raw
                .compactMap { item in
                    let value = item.label ?? item.cluster
                    guard let value, !value.isEmpty else { return nil }
                    return value
                }
                .sorted()
        } else {
            clusters = []
        }

        if let raw = (try? c.decodeIfPresent([CellPayload].self, forKey: .cells)) ?? nil {
            cellIds = raw.compactMap(\.cellId).sorted()
        } else if let raw = (try? c.decodeIfPresent([String].self, forKey: .cells)) ?? nil {
            cellIds = raw.sorted()
        } else {
            cellIds = []
        }

        id = try c.decodeIfPresent(String.self, forKey: .activationId)
            ?? c.decodeIfPresent(String.self, forKey: .id)
            ?? "\(source)|\(title)|\(timestampIso ?? "")"
    }
}

struct RadarCollision: Decodable, Sendable, Identifiable {
    let id: String
    let sources: [String]
    let density: Double
    let isEmergence: Bool
    let detectedAtIso: String?
    let cellIds: [String]
    let signalTitles: [String]

    private enum CodingKeys: String, CodingKey {
        case collisionId
        case id
        case cells
        case signals
        case sources
        case density
        case score
        case densityScore
        case isEmergence
        case detectedAtIso
        case timestamp
    }

    private struct CellPayload: Decodable {
        let cellId: String?
    }

    private struct SignalPayload: Decodable {
        let signalId: String?
        let title: String?
    }

    init(
        id: String,
        sources: [String],
        density: Double,
        isEmergence: Bool,
        detectedAtIso: String?,
        cellIds: [String],
        signalTitles: [String]
    ) {
        self.id = id
        self.sources = sources
        self.density = density
        self.isEmergence = isEmergence
        self.detectedAtIso = detectedAtIso
        self.cellIds = cellIds
        self.signalTitles = signalTitles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sources = (try c.decodeIfPresent([String].self, forKey: .sources) ?? []).sorted()
        density = try c.decodeIfPresent(Double.self, forKey: .density)
            ?? c.decodeIfPresent(Double.self, forKey: .densityScore)
            ?? c.decodeIfPresent(Double.self, forKey: .score)
            ?? 0
        isEmergence = try c.decodeIfPresent(Bool.self, forKey: .isEmergence) ?? false
        detectedAtIso = try c.decodeIfPresent(String.self, forKey: .detectedAtIso)
            ?? c.decodeIfPresent(String.self, forKey: .timestamp)

        if let raw = (try? c.decodeIfPresent([CellPayload].self, forKey: .cells)) ?? nil {
            cellIds = raw.compactMap(\.cellId).sorted()
        } else if let raw = (try? c.decodeIfPresent([String].self, forKey: .cells)) ?? nil {
            cellIds = raw.sorted()
        } else {
            cellIds = []
        }

        if let raw = (try? c.decodeIfPresent([SignalPayload].self, forKey: .signals)) ?? nil {
            signalTitles = raw
                .compactMap { item in
                    let value = item.title ?? item.signalId
                    guard let value, !value.isEmpty else { return nil }
                    return value
                }
                .sorted()
        } else {
            signalTitles = []
        }

        id = try c.decodeIfPresent(String.self, forKey: .collisionId)
            ?? c.decodeIfPresent(String.self, forKey: .id)
            ?? "\(sources.joined(separator: ","))|\(cellIds.joined(separator: ","))|\(detectedAtIso ?? "")"
    }
}

struct RadarClusterSummary: Decodable, Sendable, Identifiable {
    let cluster: String
    let label: String
    let count: Int

    var id: String { cluster }

    private enum CodingKeys: String, CodingKey {
        case cluster
        case label
        case count
    }

    init(cluster: String, label: String, count: Int) {
        self.cluster = cluster
        self.label = label
        self.count = count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cluster = try c.decodeIfPresent(String.self, forKey: .cluster) ?? "unknown"
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? cluster
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

struct RadarSourceStats: Decodable, Sendable, Identifiable {
    let source: String
    let signalCount: Int
    let avgResidue: Double
    let lastFetch: String?

    var id: String { source }

    private enum CodingKeys: String, CodingKey {
        case source
        case signalCount
        case avgResidue
        case lastFetch
    }

    init(source: String, signalCount: Int, avgResidue: Double, lastFetch: String?) {
        self.source = source
        self.signalCount = signalCount
        self.avgResidue = avgResidue
        self.lastFetch = lastFetch
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "unknown"
        signalCount = try c.decodeIfPresent(Int.self, forKey: .signalCount) ?? 0
        avgResidue = try c.decodeIfPresent(Double.self, forKey: .avgResidue) ?? 0
        lastFetch = try c.decodeIfPresent(String.self, forKey: .lastFetch)
    }
}

struct RadarGravityHotspot: Decodable, Sendable, Identifiable {
    let cell: Int
    let axes: RadarAxes
    let gravityScore: Double
    let band: String
    let rank: Int
    let contributors: [String]
    let explanation: String

    var id: String { "\(cell)-\(rank)" }

    private enum CodingKeys: String, CodingKey {
        case cell
        case axes
        case gravityScore
        case band
        case rank
        case contributors
        case explanation
    }

    init(
        cell: Int,
        axes: RadarAxes,
        gravityScore: Double,
        band: String,
        rank: Int,
        contributors: [String],
        explanation: String
    ) {
        self.cell = cell
        self.axes = axes
        self.gravityScore = gravityScore
        self.band = band
        self.rank = rank
        self.contributors = contributors
        self.explanation = explanation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cell = try c.decodeIfPresent(Int.self, forKey: .cell) ?? 0
        axes = try c.decodeIfPresent(RadarAxes.self, forKey: .axes) ?? RadarAxes(what: "trust-model", whereValue: "internal", time: "historical")
        gravityScore = try c.decodeIfPresent(Double.self, forKey: .gravityScore) ?? 0
        band = try c.decodeIfPresent(String.self, forKey: .band) ?? "blue"
        rank = try c.decodeIfPresent(Int.self, forKey: .rank) ?? 0
        contributors = try c.decodeIfPresent([String].self, forKey: .contributors) ?? []
        explanation = try c.decodeIfPresent(String.self, forKey: .explanation) ?? ""
    }
}

struct RadarDiscoveryCandidate: Decodable, Sendable, Identifiable {
    let candidateId: String
    let candidateType: String
    let candidateScore: Double
    let rank: Int
    let crossDomain: Bool
    let axes: [RadarAxes]
    let sources: [String]
    let explanation: String

    var id: String { candidateId }

    private enum CodingKeys: String, CodingKey {
        case candidateId
        case candidateType
        case candidateScore
        case rank
        case crossDomain
        case axes
        case sources
        case explanation
    }

    init(
        candidateId: String,
        candidateType: String,
        candidateScore: Double,
        rank: Int,
        crossDomain: Bool,
        axes: [RadarAxes] = [],
        sources: [String],
        explanation: String
    ) {
        self.candidateId = candidateId
        self.candidateType = candidateType
        self.candidateScore = candidateScore
        self.rank = rank
        self.crossDomain = crossDomain
        self.axes = axes
        self.sources = sources
        self.explanation = explanation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        candidateId = try c.decodeIfPresent(String.self, forKey: .candidateId) ?? UUID().uuidString
        candidateType = try c.decodeIfPresent(String.self, forKey: .candidateType) ?? "unknown"
        candidateScore = try c.decodeIfPresent(Double.self, forKey: .candidateScore) ?? 0
        rank = try c.decodeIfPresent(Int.self, forKey: .rank) ?? 0
        crossDomain = try c.decodeIfPresent(Bool.self, forKey: .crossDomain) ?? false
        axes = try c.decodeIfPresent([RadarAxes].self, forKey: .axes) ?? []
        sources = try c.decodeIfPresent([String].self, forKey: .sources) ?? []
        explanation = try c.decodeIfPresent(String.self, forKey: .explanation) ?? ""
    }
}

struct RadarAxes: Decodable, Sendable {
    let what: String
    let whereValue: String
    let time: String

    private enum CodingKeys: String, CodingKey {
        case what
        case whereValue = "where"
        case time
    }

    init(what: String, whereValue: String, time: String) {
        self.what = what
        self.whereValue = whereValue
        self.time = time
    }
}

struct CubePosition: Hashable, Codable, Sendable {
    let x: Int
    let y: Int
    let z: Int

    init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    var id: String { "\(x)-\(y)-\(z)" }
}

struct ClashdCell: Identifiable, Sendable {
    let position: CubePosition
    let residue: Double
    let highlightedClusterId: String?
    let routeArrows: [String]

    var id: String { position.id }
}

struct ClashdRoute: Identifiable, Sendable {
    let id: String
    let from: CubePosition
    let to: CubePosition
    let strength: Double
}

struct KnowledgeCollisionCluster: Identifiable, Sendable {
    let clusterId: String
    let sourceTypes: [String]
    let densityScore: Double
    let cubePosition: CubePosition
    let summary: String
    let isEmergence: Bool

    var id: String { clusterId }
}

struct LoopMetrics: Sendable {
    let lastCycleDuration: TimeInterval
    let averageCycleDuration: TimeInterval
    let signalsToday: Int
    let challengesToday: Int
    let proposalsToday: Int
    let executedActions: Int

    static let empty = LoopMetrics(
        lastCycleDuration: 0,
        averageCycleDuration: 0,
        signalsToday: 0,
        challengesToday: 0,
        proposalsToday: 0,
        executedActions: 0
    )
}

enum JeevesDecisionKind: String, Sendable {
    case autoApproved = "auto-approved"
    case autoDenied = "auto-denied"
    case escalated = "escalated"
}

struct JeevesDecisionEvent: Identifiable, Sendable {
    let id: String
    let kind: JeevesDecisionKind
    let title: String
    let timestamp: Date
}

struct EmergenceAlert: Identifiable, Sendable {
    let id: String
    let title: String
    let summary: String
    let clusterId: String
    let timestamp: Date

    static func fromCluster(_ cluster: KnowledgeCollisionCluster, now: Date = Date()) -> EmergenceAlert {
        EmergenceAlert(
            id: "alert-\(cluster.clusterId)",
            title: "Unexpected connection detected",
            summary: cluster.summary,
            clusterId: cluster.clusterId,
            timestamp: now
        )
    }
}

struct ClashdCubeField: Sendable {
    let cells: [ClashdCell]
    let activeRoutes: [ClashdRoute]
    let clusters: [KnowledgeCollisionCluster]

    static let empty = ClashdCubeField(cells: [], activeRoutes: [], clusters: [])
}

struct ObservatorySnapshot: Sendable {
    let loop: LoopMetrics
    let field: ClashdCubeField
    let collisions: [KnowledgeCollisionCluster]
    let decisions: [JeevesDecisionEvent]
    let updatedAt: Date

    static let empty = ObservatorySnapshot(
        loop: .empty,
        field: .empty,
        collisions: [],
        decisions: [],
        updatedAt: Date()
    )

    static func demo(tick: Int, now: Date = Date()) -> ObservatorySnapshot {
        let clusters = [
            KnowledgeCollisionCluster(
                clusterId: "demo-\(tick)",
                sourceTypes: ["signal", "knowledge"],
                densityScore: 0.6,
                cubePosition: CubePosition(x: 1, y: 1, z: 1),
                summary: "Demo cluster",
                isEmergence: tick % 2 == 0
            )
        ]

        let cells = (0..<27).map { index in
            ClashdCell(
                position: CubePosition(x: index % 3, y: (index / 3) % 3, z: (index / 9) % 3),
                residue: Double(index % 10) / 10.0,
                highlightedClusterId: nil,
                routeArrows: []
            )
        }

        let decisions = [
            JeevesDecisionEvent(
                id: "decision-\(tick)",
                kind: tick % 2 == 0 ? .escalated : .autoApproved,
                title: "Demo decision",
                timestamp: now
            )
        ]

        return ObservatorySnapshot(
            loop: LoopMetrics(
                lastCycleDuration: 5.0,
                averageCycleDuration: 6.0,
                signalsToday: 10 + tick,
                challengesToday: 2,
                proposalsToday: 3,
                executedActions: 1
            ),
            field: ClashdCubeField(cells: cells, activeRoutes: [], clusters: clusters),
            collisions: clusters,
            decisions: decisions,
            updatedAt: now
        )
    }
}
