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
