import Foundation

struct ExtensionCapability: Decodable, Hashable, Identifiable {
    let key: String
    let title: String
    let details: String?
    let sourceType: String?

    var id: String { key }

    init(key: String, title: String? = nil, details: String? = nil, sourceType: String? = nil) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        self.key = trimmed.isEmpty ? "unknown_capability" : trimmed
        self.title = (title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? title!.trimmingCharacters(in: .whitespacesAndNewlines)
            : self.key
        self.details = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceType = sourceType?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case name
        case capability
        case details
        case description
        case sourceType = "source_type"
        case source
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let value = try? single.decode(String.self) {
            self.init(key: value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = container.decodeFirstString(for: [.key, .name, .capability]) ?? "unknown_capability"
        let title = container.decodeFirstString(for: [.title, .name, .capability, .key])
        let details = container.decodeFirstString(for: [.details, .description])
        let sourceType = container.decodeFirstString(for: [.sourceType, .source])
        self.init(key: key, title: title, details: details, sourceType: sourceType)
    }
}

struct ExtensionReceipt: Decodable, Identifiable {
    let extensionId: String
    let status: String
    let approvedAtIso: String?
    let loadedAtIso: String?
    let receiptId: String?
    let summary: String?
    let codeHash: String?

    var id: String { receiptId ?? "\(extensionId)-receipt" }
}

struct ExtensionDecision: Decodable, Identifiable {
    let extensionId: String
    let status: String
    let approvedAtIso: String?
    let loadedAtIso: String?
    let decisionAtIso: String?
    let reason: String?
    let actor: String?
    let receipt: ExtensionReceipt?

    var id: String { "\(extensionId)-\(status)-\(decisionAtIso ?? "decision")" }
}

struct ExtensionProposal: Decodable, Identifiable {
    let extensionId: String
    let title: String
    let purpose: String
    let capabilities: [ExtensionCapability]
    let risk: String
    let codeHash: String
    let entrypoint: String
    let status: String
    let approvedAtIso: String?
    let loadedAtIso: String?
    let sourceType: String?
    let linkedCells: [String]
    let reasoningTrace: String?

    var id: String { extensionId }

    var isPending: Bool {
        let normalized = status.lowercased()
        return normalized == "pending" || normalized == "proposed" || normalized == "proposal" || normalized == "review"
    }

    init(
        extensionId: String,
        title: String,
        purpose: String,
        capabilities: [ExtensionCapability],
        risk: String,
        codeHash: String,
        entrypoint: String,
        status: String,
        approvedAtIso: String? = nil,
        loadedAtIso: String? = nil,
        sourceType: String? = nil,
        linkedCells: [String] = [],
        reasoningTrace: String? = nil
    ) {
        self.extensionId = extensionId
        self.title = title
        self.purpose = purpose
        self.capabilities = capabilities
        self.risk = risk
        self.codeHash = codeHash
        self.entrypoint = entrypoint
        self.status = status
        self.approvedAtIso = approvedAtIso
        self.loadedAtIso = loadedAtIso
        self.sourceType = sourceType
        self.linkedCells = linkedCells
        self.reasoningTrace = reasoningTrace
    }

    private enum CodingKeys: String, CodingKey {
        case extensionId
        case id
        case title
        case name
        case purpose
        case summary
        case description
        case capabilities
        case risk
        case riskLevel = "risk_level"
        case codeHash = "code_hash"
        case codeHashCamel = "codeHash"
        case entrypoint
        case entryPoint = "entry_point"
        case status
        case approvedAtIso
        case loadedAtIso
        case sourceType = "source_type"
        case linkedCells = "linked_cells"
        case cubeCells = "cube_cells"
        case reasoningTrace = "reasoning_trace"
        case trace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let extensionId = container.decodeFirstString(for: [.extensionId, .id]) ?? UUID().uuidString
        let title = container.decodeFirstString(for: [.title, .name]) ?? extensionId
        let purpose = container.decodeFirstString(for: [.purpose, .summary, .description]) ?? "Geen doel opgegeven"
        let capabilities = container.decodeCapabilities(for: [.capabilities])
        let risk = container.decodeFirstString(for: [.risk, .riskLevel]) ?? "unknown"
        let codeHash = container.decodeFirstString(for: [.codeHash, .codeHashCamel]) ?? "onbekend"
        let entrypoint = container.decodeFirstString(for: [.entrypoint, .entryPoint]) ?? "onbekend"
        let status = container.decodeFirstString(for: [.status]) ?? "pending"
        let approvedAtIso = container.decodeFirstString(for: [.approvedAtIso])
        let loadedAtIso = container.decodeFirstString(for: [.loadedAtIso])
        let sourceType = container.decodeFirstString(for: [.sourceType])
        let linkedCells = container.decodeFirstStringArray(for: [.linkedCells, .cubeCells])
        let reasoningTrace = container.decodeFirstString(for: [.reasoningTrace, .trace])

        self.init(
            extensionId: extensionId,
            title: title,
            purpose: purpose,
            capabilities: capabilities,
            risk: risk,
            codeHash: codeHash,
            entrypoint: entrypoint,
            status: status,
            approvedAtIso: approvedAtIso,
            loadedAtIso: loadedAtIso,
            sourceType: sourceType,
            linkedCells: linkedCells,
            reasoningTrace: reasoningTrace
        )
    }
}

struct ExtensionManifest: Decodable, Identifiable {
    let extensionId: String
    let title: String
    let purpose: String
    let capabilities: [ExtensionCapability]
    let risk: String
    let codeHash: String
    let entrypoint: String
    let status: String
    let approvedAtIso: String?
    let loadedAtIso: String?
    let sourceType: String?
    let linkedCells: [String]
    let reasoningTrace: String?
    let knowledgeLinks: [String]
    let auditTrail: [ExtensionDecision]
    let receipt: ExtensionReceipt?

    var id: String { extensionId }

    init(
        extensionId: String,
        title: String,
        purpose: String,
        capabilities: [ExtensionCapability],
        risk: String,
        codeHash: String,
        entrypoint: String,
        status: String,
        approvedAtIso: String? = nil,
        loadedAtIso: String? = nil,
        sourceType: String? = nil,
        linkedCells: [String] = [],
        reasoningTrace: String? = nil,
        knowledgeLinks: [String] = [],
        auditTrail: [ExtensionDecision] = [],
        receipt: ExtensionReceipt? = nil
    ) {
        self.extensionId = extensionId
        self.title = title
        self.purpose = purpose
        self.capabilities = capabilities
        self.risk = risk
        self.codeHash = codeHash
        self.entrypoint = entrypoint
        self.status = status
        self.approvedAtIso = approvedAtIso
        self.loadedAtIso = loadedAtIso
        self.sourceType = sourceType
        self.linkedCells = linkedCells
        self.reasoningTrace = reasoningTrace
        self.knowledgeLinks = knowledgeLinks
        self.auditTrail = auditTrail
        self.receipt = receipt
    }

    init(proposal: ExtensionProposal, receipt: ExtensionReceipt? = nil, auditTrail: [ExtensionDecision] = []) {
        self.init(
            extensionId: proposal.extensionId,
            title: proposal.title,
            purpose: proposal.purpose,
            capabilities: proposal.capabilities,
            risk: proposal.risk,
            codeHash: proposal.codeHash,
            entrypoint: proposal.entrypoint,
            status: proposal.status,
            approvedAtIso: proposal.approvedAtIso,
            loadedAtIso: proposal.loadedAtIso,
            sourceType: proposal.sourceType,
            linkedCells: proposal.linkedCells,
            reasoningTrace: proposal.reasoningTrace,
            knowledgeLinks: [],
            auditTrail: auditTrail,
            receipt: receipt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case extensionId
        case id
        case title
        case name
        case purpose
        case summary
        case description
        case capabilities
        case risk
        case riskLevel = "risk_level"
        case codeHash = "code_hash"
        case codeHashCamel = "codeHash"
        case entrypoint
        case entryPoint = "entry_point"
        case status
        case approvedAtIso
        case loadedAtIso
        case sourceType = "source_type"
        case linkedCells = "linked_cells"
        case cubeCells = "cube_cells"
        case reasoningTrace = "reasoning_trace"
        case trace
        case knowledgeLinks = "knowledge_links"
        case linkedObjectIds = "linked_object_ids"
        case auditTrail = "audit_trail"
        case decisions
        case receipt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let extensionId = container.decodeFirstString(for: [.extensionId, .id]) ?? UUID().uuidString
        let title = container.decodeFirstString(for: [.title, .name]) ?? extensionId
        let purpose = container.decodeFirstString(for: [.purpose, .summary, .description]) ?? "Geen doel opgegeven"
        let capabilities = container.decodeCapabilities(for: [.capabilities])
        let risk = container.decodeFirstString(for: [.risk, .riskLevel]) ?? "unknown"
        let codeHash = container.decodeFirstString(for: [.codeHash, .codeHashCamel]) ?? "onbekend"
        let entrypoint = container.decodeFirstString(for: [.entrypoint, .entryPoint]) ?? "onbekend"
        let status = container.decodeFirstString(for: [.status]) ?? "unknown"
        let approvedAtIso = container.decodeFirstString(for: [.approvedAtIso])
        let loadedAtIso = container.decodeFirstString(for: [.loadedAtIso])
        let sourceType = container.decodeFirstString(for: [.sourceType])
        let linkedCells = container.decodeFirstStringArray(for: [.linkedCells, .cubeCells])
        let reasoningTrace = container.decodeFirstString(for: [.reasoningTrace, .trace])
        let knowledgeLinks = container.decodeFirstStringArray(for: [.knowledgeLinks, .linkedObjectIds])
        let auditTrail = container.decodeFirstDecodableArray(ExtensionDecision.self, for: [.auditTrail, .decisions]) ?? []
        let receipt = container.decodeFirstDecodable(ExtensionReceipt.self, for: [.receipt])

        self.init(
            extensionId: extensionId,
            title: title,
            purpose: purpose,
            capabilities: capabilities,
            risk: risk,
            codeHash: codeHash,
            entrypoint: entrypoint,
            status: status,
            approvedAtIso: approvedAtIso,
            loadedAtIso: loadedAtIso,
            sourceType: sourceType,
            linkedCells: linkedCells,
            reasoningTrace: reasoningTrace,
            knowledgeLinks: knowledgeLinks,
            auditTrail: auditTrail,
            receipt: receipt
        )
    }
}

struct ExtensionProposalsEnvelope: Decodable {
    let proposals: [ExtensionProposal]?
    let extensions: [ExtensionProposal]?
    let items: [ExtensionProposal]?
    let data: [ExtensionProposal]?

    var resolved: [ExtensionProposal] {
        proposals ?? extensions ?? items ?? data ?? []
    }
}

struct ExtensionManifestEnvelope: Decodable {
    let manifest: ExtensionManifest?
    let `extension`: ExtensionManifest?
    let data: ExtensionManifest?

    var resolved: ExtensionManifest? {
        manifest ?? `extension` ?? data
    }
}

struct ExtensionDecisionEnvelope: Decodable {
    let decision: ExtensionDecision?
    let receipt: ExtensionReceipt?
    let data: ExtensionDecision?
    let status: String?
    let extensionId: String?
    let approvedAtIso: String?
    let loadedAtIso: String?
}

private extension KeyedDecodingContainer {
    func decodeFirstString(for keys: [Key]) -> String? {
        for key in keys {
            if let value = try? decode(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    func decodeFirstStringArray(for keys: [Key]) -> [String] {
        for key in keys {
            if let values = try? decode([String].self, forKey: key) {
                let normalized = values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !normalized.isEmpty {
                    return normalized
                }
            }
        }
        return []
    }

    func decodeCapabilities(for keys: [Key]) -> [ExtensionCapability] {
        for key in keys {
            if let objects = try? decode([ExtensionCapability].self, forKey: key),
               !objects.isEmpty {
                return objects
            }
            if let strings = try? decode([String].self, forKey: key),
               !strings.isEmpty {
                return strings.map { ExtensionCapability(key: $0) }
            }
        }
        return []
    }

    func decodeFirstDecodable<T: Decodable>(_ type: T.Type, for keys: [Key]) -> T? {
        for key in keys {
            if let value = try? decode(T.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    func decodeFirstDecodableArray<T: Decodable>(_ type: T.Type, for keys: [Key]) -> [T]? {
        for key in keys {
            if let value = try? decode([T].self, forKey: key) {
                return value
            }
        }
        return nil
    }
}
