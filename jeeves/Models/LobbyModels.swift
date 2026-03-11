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
    let proposalType: String?
    let gapDetails: GapProposalDetails?
    var id: String { proposalId }

    init(
        proposalId: String,
        createdAtIso: String,
        agentId: String,
        title: String,
        intent: ProposalIntent,
        status: String,
        priorityScore: Double?,
        priorityExplanation: String?,
        rank: Int?,
        priorityFactors: ProposalPriorityFactors?,
        proposalType: String? = nil,
        gapDetails: GapProposalDetails? = nil
    ) {
        self.proposalId = proposalId
        self.createdAtIso = createdAtIso
        self.agentId = agentId
        self.title = title
        self.intent = intent
        self.status = status
        self.priorityScore = priorityScore
        self.priorityExplanation = priorityExplanation
        self.rank = rank
        self.priorityFactors = priorityFactors
        self.proposalType = proposalType
        self.gapDetails = gapDetails
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        proposalId = container.decodeFirstString(for: ["proposalId", "proposal_id", "id"]) ?? UUID().uuidString
        createdAtIso = container.decodeFirstString(for: ["createdAtIso", "created_at_iso", "createdAt", "created_at"])
            ?? ISO8601DateFormatter().string(from: Date())
        agentId = container.decodeFirstString(for: ["agentId", "agent_id", "sourceAgentId", "source_agent_id", "agent"])
            ?? "unknown-agent"
        title = container.decodeFirstString(for: ["title", "name"]) ?? "Untitled proposal"

        if let decodedIntent = container.decodeFirstDecodable(ProposalIntent.self, for: ["intent"]) {
            intent = decodedIntent
        } else {
            intent = ProposalIntent(
                kind: container.decodeFirstString(for: ["kind", "intentKind", "intent_kind"]) ?? "proposal",
                key: container.decodeFirstString(for: ["key", "intentKey", "intent_key"]) ?? "proposal.review",
                risk: container.decodeFirstString(for: ["risk", "riskLevel", "risk_level"]) ?? "unknown",
                requiresConsent: container.decodeFirstBool(for: ["requiresConsent", "requires_consent"]) ?? true
            )
        }

        status = container.decodeFirstString(for: ["status"]) ?? "pending"
        priorityScore = container.decodeFirstDouble(for: ["priorityScore", "priority_score", "score"])
        priorityExplanation = container.decodeFirstString(
            for: ["priorityExplanation", "priority_explanation", "summary", "why", "reason"]
        )
        rank = container.decodeFirstInt(for: ["rank"])
        priorityFactors = container.decodeFirstDecodable(
            ProposalPriorityFactors.self,
            for: ["priorityFactors", "priority_factors"]
        )
        proposalType = container.decodeFirstString(
            for: ["proposalType", "proposal_type", "type", "proposalClass", "proposal_class"]
        )

        let metadata = container.decodeFirstDictionary(
            for: ["gap", "gapDetails", "gap_details", "metadata", "details", "payload"]
        )
        gapDetails = container.decodeFirstDecodable(
            GapProposalDetails.self,
            for: ["gap", "gapDetails", "gap_details"]
        ) ?? GapProposalDetails.fromContainer(
            container,
            metadata: metadata,
            priorityFactors: priorityFactors,
            fallbackSummary: priorityExplanation,
            title: title
        )
    }

    var createdAt: Date? {
        ISO8601DateFormatter().date(from: createdAtIso)
    }

    var isPending: Bool { status == "pending" }
    var isApproved: Bool { status == "approved" }
    var isDenied: Bool { status == "denied" }
    var isDeferred: Bool { status == "deferred" || status == "defer" }

    var isGapDiscovery: Bool {
        if let proposalType, proposalType.lowercased().contains("gap") {
            return true
        }
        if gapDetails != nil {
            return true
        }
        let gapSignals = "\(intent.kind) \(intent.key) \(title)".lowercased()
        return gapSignals.contains("gap")
            || gapSignals.contains("hypothesis")
            || gapSignals.contains("verification")
    }

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

    init(kind: String, key: String, risk: String, requiresConsent: Bool) {
        self.kind = kind
        self.key = key
        self.risk = risk
        self.requiresConsent = requiresConsent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        kind = container.decodeFirstString(for: ["kind", "type"]) ?? "proposal"
        key = container.decodeFirstString(for: ["key", "intentKey", "intent_key", "name"]) ?? "proposal.review"
        risk = container.decodeFirstString(for: ["risk", "riskLevel", "risk_level"]) ?? "unknown"
        requiresConsent = container.decodeFirstBool(for: ["requiresConsent", "requires_consent"]) ?? true
    }
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
    let entropy: Double?
    let serendipity: Double?
}

struct GapProposalDetails: Codable {
    let summary: String
    let sourceEvidence: [GapEvidenceReference]
    let cubeCell: String
    let scores: GapProposalScores
    let hypothesis: String
    let verificationPlan: [String]
    let killTests: [String]
    let recommendedAction: String

    init(
        summary: String,
        sourceEvidence: [GapEvidenceReference],
        cubeCell: String,
        scores: GapProposalScores,
        hypothesis: String,
        verificationPlan: [String],
        killTests: [String],
        recommendedAction: String
    ) {
        self.summary = summary
        self.sourceEvidence = sourceEvidence
        self.cubeCell = cubeCell
        self.scores = scores
        self.hypothesis = hypothesis
        self.verificationPlan = verificationPlan
        self.killTests = killTests
        self.recommendedAction = recommendedAction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        let summary = container.decodeFirstString(for: ["summary", "why", "operatorSummary", "operator_summary"])
            ?? "Governed gap proposal awaiting operator review."
        let sourceEvidence = container.decodeFirstDecodableArray(
            GapEvidenceReference.self,
            for: ["sourceEvidence", "source_evidence", "evidence", "evidenceRefs", "evidence_refs"]
        ) ?? []
        let cubeCell = container.decodeFirstString(for: ["cubeCell", "cube_cell", "cell"]) ?? "Unmapped"
        let scores = container.decodeFirstDecodable(GapProposalScores.self, for: ["scores", "scorecard"])
            ?? GapProposalScores(
                novelty: container.decodeFirstDouble(for: ["novelty"]) ?? 0,
                collision: container.decodeFirstDouble(for: ["collision"]) ?? 0,
                residue: container.decodeFirstDouble(for: ["residue"]) ?? 0,
                gravity: container.decodeFirstDouble(for: ["gravity"]) ?? 0,
                evidence: container.decodeFirstDouble(for: ["evidence"]) ?? 0,
                entropy: container.decodeFirstDouble(for: ["entropy"]) ?? 0,
                serendipity: container.decodeFirstDouble(for: ["serendipity"]) ?? 0
            )
        let hypothesis = container.decodeFirstString(for: ["hypothesis", "thesis"])
            ?? "This gap may warrant a bounded investigation through governance."
        let verificationPlan = container.decodeFirstStringArray(
            for: ["verificationPlan", "verification_plan", "verificationSteps", "verification_steps"]
        )
        let killTests = container.decodeFirstStringArray(for: ["killTests", "kill_tests", "falsifiers"])
        let recommendedAction = container.decodeFirstString(
            for: ["recommendedAction", "recommended_action", "recommendation"]
        ) ?? "Open a bounded verification action through openclashd-v2."

        self.init(
            summary: summary,
            sourceEvidence: sourceEvidence,
            cubeCell: cubeCell,
            scores: scores,
            hypothesis: hypothesis,
            verificationPlan: verificationPlan,
            killTests: killTests,
            recommendedAction: recommendedAction
        )
    }

    fileprivate static func fromContainer(
        _ container: KeyedDecodingContainer<FlexibleCodingKey>,
        metadata: [String: AnyCodableValue]?,
        priorityFactors: ProposalPriorityFactors?,
        fallbackSummary: String?,
        title: String
    ) -> GapProposalDetails? {
        let summary = container.decodeFirstString(
            for: ["gapSummary", "gap_summary", "summary", "why", "operatorSummary", "operator_summary"]
        ) ?? metadataString(
            metadata,
            keys: ["gap_summary", "summary", "operator_summary", "why_matters", "why"]
        ) ?? fallbackSummary

        let cubeCell = container.decodeFirstString(for: ["cubeCell", "cube_cell", "cell"])
            ?? metadataString(metadata, keys: ["cube_cell", "cubeCell", "cell", "linked_cell"])
        let hypothesis = container.decodeFirstString(for: ["hypothesis", "thesis"])
            ?? metadataString(metadata, keys: ["hypothesis", "thesis"])
        let recommendedAction = container.decodeFirstString(
            for: ["recommendedAction", "recommended_action", "recommendation"]
        ) ?? metadataString(metadata, keys: ["recommended_action", "recommendedAction", "recommendation"])

        let verificationPlan = container.decodeFirstStringArray(
            for: ["verificationPlan", "verification_plan", "verificationSteps", "verification_steps"]
        )
        let metadataVerification = metadataStrings(
            metadata,
            keys: ["verification_plan", "verificationPlan", "verification_steps"]
        )
        let killTests = container.decodeFirstStringArray(for: ["killTests", "kill_tests", "falsifiers"])
        let metadataKillTests = metadataStrings(metadata, keys: ["kill_tests", "killTests", "falsifiers", "kill_switch_tests"])
        let evidence = container.decodeFirstDecodableArray(
            GapEvidenceReference.self,
            for: ["sourceEvidence", "source_evidence", "evidence", "evidenceRefs", "evidence_refs"]
        ) ?? metadataEvidence(metadata)

        let scores = container.decodeFirstDecodable(GapProposalScores.self, for: ["scores", "scorecard"])
            ?? GapProposalScores.fromMetadata(metadata, priorityFactors: priorityFactors)

        guard let summary else { return nil }

        return GapProposalDetails(
            summary: summary,
            sourceEvidence: evidence.isEmpty ? [
                GapEvidenceReference(label: "Source", value: title)
            ] : evidence,
            cubeCell: cubeCell ?? "Unmapped",
            scores: scores,
            hypothesis: hypothesis ?? "Investigate whether this gap blocks trustworthy action or knowledge creation.",
            verificationPlan: verificationPlan.isEmpty ? metadataVerification : verificationPlan,
            killTests: killTests.isEmpty ? metadataKillTests : killTests,
            recommendedAction: recommendedAction ?? "Defer execution until an operator approves bounded verification."
        )
    }
}

struct GapEvidenceReference: Codable, Identifiable {
    let label: String
    let value: String
    let url: String?
    var id: String { "\(label)|\(value)" }

    init(label: String, value: String, url: String? = nil) {
        self.label = label
        self.value = value
        self.url = url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        label = container.decodeFirstString(for: ["label", "title", "name"]) ?? "Evidence"
        value = container.decodeFirstString(for: ["value", "reference", "summary", "id", "source"]) ?? "Unknown evidence"
        url = container.decodeFirstString(for: ["url", "href"])
    }
}

struct GapProposalScores: Codable {
    let novelty: Double
    let collision: Double
    let residue: Double
    let gravity: Double
    let evidence: Double
    let entropy: Double
    let serendipity: Double

    init(
        novelty: Double,
        collision: Double,
        residue: Double,
        gravity: Double,
        evidence: Double,
        entropy: Double,
        serendipity: Double
    ) {
        self.novelty = novelty
        self.collision = collision
        self.residue = residue
        self.gravity = gravity
        self.evidence = evidence
        self.entropy = entropy
        self.serendipity = serendipity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        novelty = container.decodeFirstDouble(for: ["novelty"]) ?? 0
        collision = container.decodeFirstDouble(for: ["collision"]) ?? 0
        residue = container.decodeFirstDouble(for: ["residue"]) ?? 0
        gravity = container.decodeFirstDouble(for: ["gravity"]) ?? 0
        evidence = container.decodeFirstDouble(for: ["evidence"]) ?? 0
        entropy = container.decodeFirstDouble(for: ["entropy"]) ?? 0
        serendipity = container.decodeFirstDouble(for: ["serendipity"]) ?? 0
    }

    static func fromMetadata(
        _ metadata: [String: AnyCodableValue]?,
        priorityFactors: ProposalPriorityFactors?
    ) -> GapProposalScores {
        if let scoreObject = metadataObject(metadata, keys: ["scores", "scorecard"]) {
            return GapProposalScores(
                novelty: normalizedScore(metadataDouble(scoreObject, keys: ["novelty"])),
                collision: normalizedScore(metadataDouble(scoreObject, keys: ["collision"])),
                residue: normalizedScore(metadataDouble(scoreObject, keys: ["residue"])),
                gravity: normalizedScore(metadataDouble(scoreObject, keys: ["gravity"])),
                evidence: normalizedScore(metadataDouble(scoreObject, keys: ["evidence"])),
                entropy: normalizedScore(metadataDouble(scoreObject, keys: ["entropy"])),
                serendipity: normalizedScore(metadataDouble(scoreObject, keys: ["serendipity"]))
            )
        }

        return GapProposalScores(
            novelty: normalizedScore(priorityFactors?.novelty),
            collision: normalizedScore(priorityFactors?.duplicatePressure),
            residue: normalizedScore(priorityFactors?.crossDomainRelevance),
            gravity: normalizedScore(priorityFactors?.governanceValue ?? priorityFactors?.riskScore),
            evidence: normalizedScore(priorityFactors?.evidenceStrength),
            entropy: normalizedScore(priorityFactors?.entropy ?? priorityFactors?.escalationSignal),
            serendipity: normalizedScore(priorityFactors?.serendipity ?? priorityFactors?.ageUrgency)
        )
    }

    private static func normalizedScore(_ raw: Double?) -> Double {
        guard let raw else { return 0.5 }
        if raw > 1 { return min(max(raw / 100, 0), 1) }
        return min(max(raw, 0), 1)
    }
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

struct DecideResponse: Decodable {
    let ok: Bool
    let status: String?
    let executed: Bool?
    let reason: String?
    let action: ActionSummary?
}

struct ActionSummary: Decodable, Identifiable {
    let actionId: String
    let actionKind: String
    let executionState: String
    let receipt: ActionReceipt?
    var id: String { actionId }

    init(actionId: String, actionKind: String, executionState: String, receipt: ActionReceipt?) {
        self.actionId = actionId
        self.actionKind = actionKind
        self.executionState = executionState
        self.receipt = receipt
    }

    private enum CodingKeys: String, CodingKey {
        case actionId
        case actionKind
        case executionState
        case receipt
        case action_id
        case action_kind
        case execution_state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        actionId = (try? container.decode(String.self, forKey: .actionId))
            ?? (try? container.decode(String.self, forKey: .action_id))
            ?? UUID().uuidString
        actionKind = (try? container.decode(String.self, forKey: .actionKind))
            ?? (try? container.decode(String.self, forKey: .action_kind))
            ?? "unknown"
        executionState = (try? container.decode(String.self, forKey: .executionState))
            ?? (try? container.decode(String.self, forKey: .execution_state))
            ?? "unknown"
        receipt = try? container.decodeIfPresent(ActionReceipt.self, forKey: .receipt)
    }

    var isCompleted: Bool { executionState == "completed" }
    var isFailed: Bool { executionState == "failed" }
}

struct ActionReceipt: Decodable, Identifiable {
    let receiptId: String
    let actionId: String
    let completedAtIso: String
    let executionState: String
    let resultSummary: String
    let durationMs: Double?
    let resultType: String?
    let outputObjectIds: [String]?
    let notes: String?
    let actor: String?
    let reason: String?
    let correlationId: String?
    let requestId: String?
    let eventType: String?
    var id: String { receiptId }

    init(
        receiptId: String,
        actionId: String,
        completedAtIso: String,
        executionState: String,
        resultSummary: String,
        durationMs: Double?,
        resultType: String?,
        outputObjectIds: [String]?,
        notes: String?,
        actor: String? = nil,
        reason: String? = nil,
        correlationId: String? = nil,
        requestId: String? = nil,
        eventType: String? = nil
    ) {
        self.receiptId = receiptId
        self.actionId = actionId
        self.completedAtIso = completedAtIso
        self.executionState = executionState
        self.resultSummary = resultSummary
        self.durationMs = durationMs
        self.resultType = resultType
        self.outputObjectIds = outputObjectIds
        self.notes = notes
        self.actor = actor
        self.reason = reason
        self.correlationId = correlationId
        self.requestId = requestId
        self.eventType = eventType
    }

    private enum CodingKeys: String, CodingKey {
        case receiptId
        case actionId
        case completedAtIso
        case executionState
        case resultSummary
        case durationMs
        case resultType
        case outputObjectIds
        case notes
        case actor
        case reason
        case correlationId
        case requestId
        case eventType
        case receipt_id
        case action_id
        case completed_at_iso
        case execution_state
        case result_summary
        case duration_ms
        case result_type
        case output_object_ids
        case correlation_id
        case request_id
        case event_type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        receiptId = (try? container.decode(String.self, forKey: .receiptId))
            ?? (try? container.decode(String.self, forKey: .receipt_id))
            ?? UUID().uuidString
        actionId = (try? container.decode(String.self, forKey: .actionId))
            ?? (try? container.decode(String.self, forKey: .action_id))
            ?? "unknown-action"
        completedAtIso = (try? container.decode(String.self, forKey: .completedAtIso))
            ?? (try? container.decode(String.self, forKey: .completed_at_iso))
            ?? ISO8601DateFormatter().string(from: Date())
        executionState = (try? container.decode(String.self, forKey: .executionState))
            ?? (try? container.decode(String.self, forKey: .execution_state))
            ?? "unknown"
        resultSummary = (try? container.decode(String.self, forKey: .resultSummary))
            ?? (try? container.decode(String.self, forKey: .result_summary))
            ?? "Geen samenvatting beschikbaar."
        durationMs = (try? container.decodeIfPresent(Double.self, forKey: .durationMs))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .duration_ms))
        resultType = (try? container.decodeIfPresent(String.self, forKey: .resultType))
            ?? (try? container.decodeIfPresent(String.self, forKey: .result_type))
        outputObjectIds = (try? container.decodeIfPresent([String].self, forKey: .outputObjectIds))
            ?? (try? container.decodeIfPresent([String].self, forKey: .output_object_ids))
        notes = try? container.decodeIfPresent(String.self, forKey: .notes)
        actor = try? container.decodeIfPresent(String.self, forKey: .actor)
        reason = try? container.decodeIfPresent(String.self, forKey: .reason)
        correlationId = (try? container.decodeIfPresent(String.self, forKey: .correlationId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .correlation_id))
        requestId = (try? container.decodeIfPresent(String.self, forKey: .requestId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .request_id))
        eventType = (try? container.decodeIfPresent(String.self, forKey: .eventType))
            ?? (try? container.decodeIfPresent(String.self, forKey: .event_type))
    }
}

// MARK: - Decided Proposals

struct DecidedProposal: Decodable, Identifiable {
    let proposalId: String
    let title: String
    let agentId: String
    let status: String
    let decidedAtIso: String?
    let decisionReason: String?
    let intent: ProposalIntent?
    let priorityScore: Double?
    let action: ActionSummary?
    let proposalType: String?
    let gapDetails: GapProposalDetails?
    var id: String { proposalId }

    init(
        proposalId: String,
        title: String,
        agentId: String,
        status: String,
        decidedAtIso: String?,
        decisionReason: String?,
        intent: ProposalIntent?,
        priorityScore: Double?,
        action: ActionSummary?,
        proposalType: String? = nil,
        gapDetails: GapProposalDetails? = nil
    ) {
        self.proposalId = proposalId
        self.title = title
        self.agentId = agentId
        self.status = status
        self.decidedAtIso = decidedAtIso
        self.decisionReason = decisionReason
        self.intent = intent
        self.priorityScore = priorityScore
        self.action = action
        self.proposalType = proposalType
        self.gapDetails = gapDetails
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexibleCodingKey.self)
        proposalId = container.decodeFirstString(for: ["proposalId", "proposal_id", "id"]) ?? UUID().uuidString
        title = container.decodeFirstString(for: ["title", "name"]) ?? proposalId
        agentId = container.decodeFirstString(for: ["agentId", "agent_id", "sourceAgentId", "source_agent_id", "agent"])
            ?? "unknown-agent"
        status = container.decodeFirstString(for: ["status"]) ?? "unknown"
        decidedAtIso = container.decodeFirstString(for: ["decidedAtIso", "decided_at_iso", "decisionAtIso", "decision_at_iso"])
        decisionReason = container.decodeFirstString(for: ["decisionReason", "decision_reason", "reason"])
        intent = container.decodeFirstDecodable(ProposalIntent.self, for: ["intent"])
        priorityScore = container.decodeFirstDouble(for: ["priorityScore", "priority_score", "score"])
        action = container.decodeFirstDecodable(ActionSummary.self, for: ["action", "result"])
        proposalType = container.decodeFirstString(
            for: ["proposalType", "proposal_type", "type", "proposalClass", "proposal_class"]
        )
        let metadata = container.decodeFirstDictionary(
            for: ["gap", "gapDetails", "gap_details", "metadata", "details", "payload"]
        )
        gapDetails = container.decodeFirstDecodable(
            GapProposalDetails.self,
            for: ["gap", "gapDetails", "gap_details"]
        ) ?? GapProposalDetails.fromContainer(
            container,
            metadata: metadata,
            priorityFactors: nil,
            fallbackSummary: decisionReason,
            title: title
        )
    }

    var isApproved: Bool { status == "approved" }
    var isDenied: Bool { status == "denied" }
    var isDeferred: Bool { status == "deferred" || status == "defer" }

    var isGapDiscovery: Bool {
        if let proposalType, proposalType.lowercased().contains("gap") {
            return true
        }
        if gapDetails != nil {
            return true
        }
        let gapSignals = "\(intent?.kind ?? "") \(intent?.key ?? "") \(title)".lowercased()
        return gapSignals.contains("gap")
            || gapSignals.contains("hypothesis")
            || gapSignals.contains("verification")
    }

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

enum DeploymentLifecycleStepState: String, Hashable {
    case complete
    case pending
    case missing
}

struct DeploymentLifecycleStep: Identifiable, Hashable {
    let id: String
    let title: String
    let primary: String
    let secondary: String?
    let state: DeploymentLifecycleStepState
}

struct DeploymentLifecycle: Identifiable, Hashable {
    let source: String
    let configId: String
    let intentionId: String
    let certificateId: String?
    let runtimeEnvelopeHash: String?
    let benchmarkContractId: String?
    let proposalId: String?
    let proposalCreatedAtIso: String?
    let approvalDecision: String?
    let approvalActor: String?
    let approvalAtIso: String?
    let actionKind: String?
    let actionId: String?
    let actionState: String?
    let actionAtIso: String?
    let knowledgeKind: String?
    let knowledgeId: String?
    let knowledgeAtIso: String?

    var id: String { configId }

    var steps: [DeploymentLifecycleStep] {
        [
            DeploymentLifecycleStep(
                id: "source",
                title: "SafeClash Registry",
                primary: source,
                secondary: nil,
                state: .complete
            ),
            DeploymentLifecycleStep(
                id: "proposal",
                title: "Proposal Created",
                primary: proposalId ?? "No proposal linked",
                secondary: proposalCreatedAtIso,
                state: stageState(value: proposalId)
            ),
            DeploymentLifecycleStep(
                id: "approval",
                title: "Approval",
                primary: approvalDecision ?? "Awaiting approval",
                secondary: approvalAtIso ?? approvalActor,
                state: approvalState
            ),
            DeploymentLifecycleStep(
                id: "action",
                title: "Governed Action",
                primary: actionKind ?? "No action recorded",
                secondary: actionLineSecondary,
                state: actionStageState
            ),
            DeploymentLifecycleStep(
                id: "knowledge",
                title: "Knowledge Artifact",
                primary: knowledgeKind ?? "No knowledge artifact",
                secondary: knowledgeLineSecondary,
                state: stageState(value: knowledgeId)
            )
        ]
    }

    private var approvalState: DeploymentLifecycleStepState {
        guard let decision = approvalDecision?.lowercased() else {
            if proposalId != nil { return .pending }
            return .missing
        }
        if decision.contains("approve") || decision.contains("granted") {
            return .complete
        }
        if decision.contains("deny") || decision.contains("reject") {
            return .missing
        }
        return .pending
    }

    private var actionStageState: DeploymentLifecycleStepState {
        guard actionId != nil || actionKind != nil else {
            if approvalState == .complete { return .pending }
            return .missing
        }
        let normalized = actionState?.lowercased() ?? ""
        if normalized == "completed" || normalized == "success" || normalized == "ok" {
            return .complete
        }
        if normalized == "failed" || normalized == "denied" {
            return .missing
        }
        return .pending
    }

    private var actionLineSecondary: String? {
        if let actionId, let actionState {
            if let actionAtIso {
                return "\(actionId) · \(actionState) · \(actionAtIso)"
            }
            return "\(actionId) · \(actionState)"
        }
        if let actionId { return actionId }
        if let actionState { return actionState }
        return actionAtIso
    }

    private var knowledgeLineSecondary: String? {
        if let knowledgeId, let knowledgeAtIso {
            return "\(knowledgeId) · \(knowledgeAtIso)"
        }
        if let knowledgeId { return knowledgeId }
        return knowledgeAtIso
    }

    private func stageState(value: String?) -> DeploymentLifecycleStepState {
        if let value, !value.isEmpty { return .complete }
        return .missing
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

    private enum CodingKeys: String, CodingKey {
        case objectId, kind, createdAtIso, title, summary
        case sourceRefs, linkedObjectIds, metadata
        // snake_case alternatives the backend may use
        case object_id, created_at_iso, source_refs, linked_object_ids
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        objectId = (try? c.decode(String.self, forKey: .objectId))
            ?? (try? c.decode(String.self, forKey: .object_id))
            ?? UUID().uuidString
        kind = (try? c.decode(String.self, forKey: .kind)) ?? "unknown"
        createdAtIso = (try? c.decode(String.self, forKey: .createdAtIso))
            ?? (try? c.decode(String.self, forKey: .created_at_iso))
            ?? ISO8601DateFormatter().string(from: Date())
        title = (try? c.decode(String.self, forKey: .title)) ?? "Untitled"
        summary = (try? c.decode(String.self, forKey: .summary)) ?? ""
        sourceRefs = (try? c.decodeIfPresent([KnowledgeSourceRef].self, forKey: .sourceRefs))
            ?? (try? c.decodeIfPresent([KnowledgeSourceRef].self, forKey: .source_refs))
        linkedObjectIds = (try? c.decodeIfPresent([String].self, forKey: .linkedObjectIds))
            ?? (try? c.decodeIfPresent([String].self, forKey: .linked_object_ids))
        metadata = try? c.decodeIfPresent([String: AnyCodableValue].self, forKey: .metadata)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(objectId, forKey: .objectId)
        try c.encode(kind, forKey: .kind)
        try c.encode(createdAtIso, forKey: .createdAtIso)
        try c.encode(title, forKey: .title)
        try c.encode(summary, forKey: .summary)
        try c.encodeIfPresent(sourceRefs, forKey: .sourceRefs)
        try c.encodeIfPresent(linkedObjectIds, forKey: .linkedObjectIds)
        try c.encodeIfPresent(metadata, forKey: .metadata)
    }

    init(
        objectId: String,
        kind: String,
        createdAtIso: String,
        title: String,
        summary: String,
        sourceRefs: [KnowledgeSourceRef]?,
        linkedObjectIds: [String]?,
        metadata: [String: AnyCodableValue]?
    ) {
        self.objectId = objectId
        self.kind = kind
        self.createdAtIso = createdAtIso
        self.title = title
        self.summary = summary
        self.sourceRefs = sourceRefs
        self.linkedObjectIds = linkedObjectIds
        self.metadata = metadata
    }
}

struct KnowledgeSourceRef: Codable {
    let sourceType: String
    let sourceId: String
    let url: String?
    let label: String?

    private enum CodingKeys: String, CodingKey {
        case sourceType, sourceId, url, label
        case source_type, source_id
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sourceType = (try? c.decode(String.self, forKey: .sourceType))
            ?? (try? c.decode(String.self, forKey: .source_type))
            ?? "unknown"
        sourceId = (try? c.decode(String.self, forKey: .sourceId))
            ?? (try? c.decode(String.self, forKey: .source_id))
            ?? ""
        url = try? c.decodeIfPresent(String.self, forKey: .url)
        label = try? c.decodeIfPresent(String.self, forKey: .label)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sourceType, forKey: .sourceType)
        try c.encode(sourceId, forKey: .sourceId)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(label, forKey: .label)
    }

    init(sourceType: String, sourceId: String, url: String?, label: String?) {
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.url = url
        self.label = label
    }
}

struct KnowledgeObjectsEnvelope: Decodable {
    let ok: Bool?
    let objects: [KnowledgeObject]?
    let data: [KnowledgeObject]?
    let items: [KnowledgeObject]?
    let error: String?

    var resolved: [KnowledgeObject] {
        objects ?? data ?? items ?? []
    }
}

struct IncomingToolEvidenceRef: Identifiable, Hashable {
    let id: String
    let label: String
    let value: String
    let url: String?

    init(label: String, value: String, url: String? = nil, id: String? = nil) {
        self.label = label
        self.value = value
        self.url = url
        self.id = id ?? "\(label.lowercased())-\(value.lowercased())"
    }
}

enum IncomingToolActionKind: String, CaseIterable, Hashable {
    case reject
    case sandbox
    case refine
    case promote
}

struct IncomingToolActionState: Hashable {
    let available: Bool
    let endpoint: String?
    let hint: String?

    init(available: Bool = false, endpoint: String? = nil, hint: String? = nil) {
        self.available = available
        self.endpoint = endpoint
        self.hint = hint
    }
}

struct IncomingToolActionSet: Hashable {
    let reject: IncomingToolActionState
    let sandbox: IncomingToolActionState
    let refine: IncomingToolActionState
    let promote: IncomingToolActionState
    let approveProposal: IncomingToolActionState

    init(
        reject: IncomingToolActionState = .init(),
        sandbox: IncomingToolActionState = .init(),
        refine: IncomingToolActionState = .init(available: true),
        promote: IncomingToolActionState = .init(),
        approveProposal: IncomingToolActionState = .init()
    ) {
        self.reject = reject
        self.sandbox = sandbox
        self.refine = refine
        self.promote = promote
        self.approveProposal = approveProposal
    }

    func state(for kind: IncomingToolActionKind) -> IncomingToolActionState {
        switch kind {
        case .reject:
            return reject
        case .sandbox:
            return sandbox
        case .refine:
            return refine
        case .promote:
            return promote
        }
    }
}

struct IncomingToolActionHistoryItem: Identifiable, Hashable {
    let action: String
    let atIso: String
    let state: String?

    var id: String {
        "\(action)-\(atIso)-\(state ?? "unknown")"
    }
}

struct IncomingToolSummary: Identifiable, Hashable {
    let id: String
    let extensionId: String
    let proposalId: String?
    let status: String
    let discoveredAtIso: String?
    let objectId: String
    let title: String
    let source: String
    let intentSummary: String
    let capabilitySummary: String
    let capabilities: [String]
    let risk: String
    let suggestedRefinement: String
    let suggestedRefinedTool: String?
    let refinementSuggestions: [String]
    let linkedCells: [String]
    let explanation: String
    let discoveryOrigin: String
    let weakPoints: String
    let weakPointsList: [String]
    let evidenceRefs: [IncomingToolEvidenceRef]
    let forensicsReportId: String?
    let actionHistory: [IncomingToolActionHistoryItem]
    let actions: IncomingToolActionSet
    let promotionReady: Bool
    let refinementState: String?
    let sandboxState: String?
    let lineageHint: String

    init(
        id: String? = nil,
        extensionId: String,
        proposalId: String? = nil,
        status: String = "proposed",
        discoveredAtIso: String? = nil,
        objectId: String? = nil,
        title: String,
        source: String,
        intentSummary: String,
        capabilitySummary: String,
        capabilities: [String],
        risk: String,
        suggestedRefinement: String,
        suggestedRefinedTool: String? = nil,
        refinementSuggestions: [String] = [],
        linkedCells: [String],
        explanation: String,
        discoveryOrigin: String,
        weakPoints: String,
        weakPointsList: [String] = [],
        evidenceRefs: [IncomingToolEvidenceRef],
        forensicsReportId: String? = nil,
        actionHistory: [IncomingToolActionHistoryItem] = [],
        actions: IncomingToolActionSet = IncomingToolActionSet(),
        promotionReady: Bool = false,
        refinementState: String? = nil,
        sandboxState: String? = nil,
        lineageHint: String
    ) {
        self.extensionId = extensionId
        self.proposalId = proposalId
        self.status = status
        self.discoveredAtIso = discoveredAtIso
        self.objectId = objectId ?? extensionId
        self.id = id ?? extensionId
        self.title = title
        self.source = source
        self.intentSummary = intentSummary
        self.capabilitySummary = capabilitySummary
        self.capabilities = capabilities
        self.risk = risk
        self.suggestedRefinement = suggestedRefinement
        self.suggestedRefinedTool = suggestedRefinedTool
        self.refinementSuggestions = refinementSuggestions
        self.linkedCells = linkedCells
        self.explanation = explanation
        self.discoveryOrigin = discoveryOrigin
        self.weakPoints = weakPoints
        self.weakPointsList = weakPointsList
        self.evidenceRefs = evidenceRefs
        self.forensicsReportId = forensicsReportId
        self.actionHistory = actionHistory
        self.actions = actions
        self.promotionReady = promotionReady
        self.refinementState = refinementState
        self.sandboxState = sandboxState
        self.lineageHint = lineageHint
    }
}

indirect enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode([AnyCodableValue].self) { self = .array(v) }
        else if let v = try? container.decode([String: AnyCodableValue].self) { self = .object(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

extension AnyCodableValue {
    var scalarStringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return "\(value)"
        case .double(let value):
            return String(format: "%.2f", value)
        case .bool(let value):
            return value ? "true" : "false"
        case .array, .object, .null:
            return nil
        }
    }

    var stringArrayValue: [String]? {
        switch self {
        case .array(let values):
            let normalized = values.compactMap(\.scalarStringValue).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return normalized.filter { !$0.isEmpty }
        case .string(let value):
            let chunks = value
                .replacingOccurrences(of: "|", with: ",")
                .replacingOccurrences(of: "/", with: ",")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return chunks.isEmpty ? nil : chunks
        case .int(let value):
            return ["\(value)"]
        case .double(let value):
            return [String(format: "%.2f", value)]
        case .bool(let value):
            return [value ? "true" : "false"]
        case .object(let object):
            let flattened = object.values.compactMap(\.scalarStringValue)
            return flattened.isEmpty ? nil : flattened
        case .null:
            return nil
        }
    }
}

private struct FlexibleCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == FlexibleCodingKey {
    func decodeFirstString(for keys: [String]) -> String? {
        for key in keys {
            guard let codingKey = FlexibleCodingKey(stringValue: key) else { continue }
            if let value = try? decodeIfPresent(String.self, forKey: codingKey) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    func decodeFirstDouble(for keys: [String]) -> Double? {
        for key in keys {
            guard let codingKey = FlexibleCodingKey(stringValue: key) else { continue }
            if let value = try? decodeIfPresent(Double.self, forKey: codingKey) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: codingKey) {
                return Double(value)
            }
            if let value = try? decodeIfPresent(String.self, forKey: codingKey),
               let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }
        return nil
    }

    func decodeFirstInt(for keys: [String]) -> Int? {
        for key in keys {
            guard let codingKey = FlexibleCodingKey(stringValue: key) else { continue }
            if let value = try? decodeIfPresent(Int.self, forKey: codingKey) {
                return value
            }
            if let value = try? decodeIfPresent(Double.self, forKey: codingKey) {
                return Int(value.rounded())
            }
            if let value = try? decodeIfPresent(String.self, forKey: codingKey),
               let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }
        return nil
    }

    func decodeFirstBool(for keys: [String]) -> Bool? {
        for key in keys {
            guard let codingKey = FlexibleCodingKey(stringValue: key) else { continue }
            if let value = try? decodeIfPresent(Bool.self, forKey: codingKey) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: codingKey) {
                return value != 0
            }
            if let value = try? decodeIfPresent(String.self, forKey: codingKey) {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if ["true", "1", "yes"].contains(normalized) { return true }
                if ["false", "0", "no"].contains(normalized) { return false }
            }
        }
        return nil
    }

    func decodeFirstStringArray(for keys: [String]) -> [String] {
        for key in keys {
            guard let codingKey = FlexibleCodingKey(stringValue: key) else { continue }
            if let values = try? decode([String].self, forKey: codingKey), !values.isEmpty {
                return values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
            if let value = try? decodeIfPresent(String.self, forKey: codingKey) {
                let chunks = value
                    .replacingOccurrences(of: "|", with: ",")
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !chunks.isEmpty { return chunks }
            }
        }
        return []
    }

    func decodeFirstDecodable<T: Decodable>(_ type: T.Type, for keys: [String]) -> T? {
        for key in keys {
            guard let codingKey = FlexibleCodingKey(stringValue: key) else { continue }
            if let value = try? decode(T.self, forKey: codingKey) {
                return value
            }
        }
        return nil
    }

    func decodeFirstDecodableArray<T: Decodable>(_ type: T.Type, for keys: [String]) -> [T]? {
        for key in keys {
            guard let codingKey = FlexibleCodingKey(stringValue: key) else { continue }
            if let value = try? decode([T].self, forKey: codingKey) {
                return value
            }
        }
        return nil
    }

    func decodeFirstDictionary(for keys: [String]) -> [String: AnyCodableValue]? {
        for key in keys {
            guard let codingKey = FlexibleCodingKey(stringValue: key) else { continue }
            if let value = try? decode([String: AnyCodableValue].self, forKey: codingKey) {
                return value
            }
        }
        return nil
    }
}

private func metadataString(_ metadata: [String: AnyCodableValue]?, keys: [String]) -> String? {
    guard let metadata else { return nil }
    let normalized = Dictionary(uniqueKeysWithValues: metadata.map { ($0.key.lowercased(), $0.value) })
    for key in keys {
        if let value = normalized[key.lowercased()]?.scalarStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }
    }
    return nil
}

private func metadataStrings(_ metadata: [String: AnyCodableValue]?, keys: [String]) -> [String] {
    guard let metadata else { return [] }
    let normalized = Dictionary(uniqueKeysWithValues: metadata.map { ($0.key.lowercased(), $0.value) })
    for key in keys {
        if let values = normalized[key.lowercased()]?.stringArrayValue, !values.isEmpty {
            return values
        }
    }
    return []
}

private func metadataDouble(_ metadata: [String: AnyCodableValue]?, keys: [String]) -> Double? {
    guard let metadata else { return nil }
    let normalized = Dictionary(uniqueKeysWithValues: metadata.map { ($0.key.lowercased(), $0.value) })
    for key in keys {
        guard let value = normalized[key.lowercased()] else { continue }
        switch value {
        case .double(let raw):
            return raw
        case .int(let raw):
            return Double(raw)
        case .string(let raw):
            if let parsed = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        default:
            continue
        }
    }
    return nil
}

private func metadataObject(_ metadata: [String: AnyCodableValue]?, keys: [String]) -> [String: AnyCodableValue]? {
    guard let metadata else { return nil }
    let normalized = Dictionary(uniqueKeysWithValues: metadata.map { ($0.key.lowercased(), $0.value) })
    for key in keys {
        if case .object(let object) = normalized[key.lowercased()] {
            return object
        }
    }
    return nil
}

private func metadataEvidence(_ metadata: [String: AnyCodableValue]?) -> [GapEvidenceReference] {
    guard let metadata else { return [] }
    let normalized = Dictionary(uniqueKeysWithValues: metadata.map { ($0.key.lowercased(), $0.value) })
    let evidenceKeys = ["source_evidence", "sourceevidence", "evidence", "evidence_refs", "evidencerefs"]

    for key in evidenceKeys {
        guard let value = normalized[key] else { continue }
        switch value {
        case .array(let rows):
            let mapped = rows.compactMap { row -> GapEvidenceReference? in
                switch row {
                case .object(let object):
                    let label = metadataString(object, keys: ["label", "title", "name"]) ?? "Evidence"
                    let ref = metadataString(object, keys: ["value", "reference", "summary", "source"]) ?? "Unknown evidence"
                    let url = metadataString(object, keys: ["url", "href"])
                    return GapEvidenceReference(label: label, value: ref, url: url)
                case .string(let line):
                    return GapEvidenceReference(label: "Evidence", value: line)
                default:
                    return nil
                }
            }
            if !mapped.isEmpty { return mapped }
        case .string(let line):
            return [GapEvidenceReference(label: "Evidence", value: line)]
        default:
            continue
        }
    }

    return []
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
