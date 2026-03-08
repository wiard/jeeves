import Foundation

struct AIConfigurationAtom: Decodable, Identifiable, Hashable {
    let configId: String
    let model: String
    let certificationLevel: String
    let certificateId: String?
    let rankingScore: Double
    let benchmarkScore: Double
    let promptArchitectureReference: String?
    let capabilities: [String]
    let benchmarkContract: String?
    let runtimeEnvelopeHash: String?
    let publisherIdentity: String?
    let pricingPolicy: String?
    let recommendationReason: String?

    var id: String { configId }

    private enum CodingKeys: String, CodingKey {
        case configId
        case id
        case model
        case certificationLevel
        case certification_level
        case certificateId
        case certificate_id
        case certId
        case cert_id
        case rankingScore
        case ranking_score
        case benchmarkScore
        case benchmark_score
        case promptArchitectureReference
        case prompt_architecture_reference
        case capabilities
        case benchmarkContract
        case benchmark_contract
        case runtimeEnvelopeHash
        case runtime_envelope_hash
        case publisherIdentity
        case publisher_identity
        case pricingPolicy
        case pricing_policy
        case recommendationReason
        case recommendation_reason
    }

    private struct CapabilityRow: Decodable {
        let capability: String?
        let key: String?
        let title: String?
    }

    init(
        configId: String,
        model: String,
        certificationLevel: String,
        certificateId: String? = nil,
        rankingScore: Double,
        benchmarkScore: Double,
        promptArchitectureReference: String? = nil,
        capabilities: [String] = [],
        benchmarkContract: String? = nil,
        runtimeEnvelopeHash: String? = nil,
        publisherIdentity: String? = nil,
        pricingPolicy: String? = nil,
        recommendationReason: String? = nil
    ) {
        self.configId = configId
        self.model = model
        self.certificationLevel = certificationLevel
        self.certificateId = certificateId
        self.rankingScore = rankingScore
        self.benchmarkScore = benchmarkScore
        self.promptArchitectureReference = promptArchitectureReference
        self.capabilities = capabilities
        self.benchmarkContract = benchmarkContract
        self.runtimeEnvelopeHash = runtimeEnvelopeHash
        self.publisherIdentity = publisherIdentity
        self.pricingPolicy = pricingPolicy
        self.recommendationReason = recommendationReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        configId = container.decodeFirstString(for: [.configId, .id]) ?? UUID().uuidString
        model = container.decodeFirstString(for: [.model]) ?? "unknown"
        certificationLevel = container.decodeFirstString(for: [.certificationLevel, .certification_level]) ?? "Uncertified"
        certificateId = container.decodeFirstString(for: [.certificateId, .certificate_id, .certId, .cert_id])
        rankingScore = container.decodeFirstDouble(for: [.rankingScore, .ranking_score]) ?? 0
        benchmarkScore = container.decodeFirstDouble(for: [.benchmarkScore, .benchmark_score]) ?? 0
        promptArchitectureReference = container.decodeFirstString(for: [.promptArchitectureReference, .prompt_architecture_reference])

        if let rows = container.decodeFirstDecodableArray(CapabilityRow.self, for: [.capabilities]), !rows.isEmpty {
            capabilities = rows.compactMap {
                ($0.capability ?? $0.title ?? $0.key)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
        } else {
            capabilities = container.decodeFirstStringArray(for: [.capabilities])
        }

        benchmarkContract = container.decodeFirstString(for: [.benchmarkContract, .benchmark_contract])
        runtimeEnvelopeHash = container.decodeFirstString(for: [.runtimeEnvelopeHash, .runtime_envelope_hash])
        publisherIdentity = container.decodeFirstString(for: [.publisherIdentity, .publisher_identity])
        pricingPolicy = container.decodeFirstString(for: [.pricingPolicy, .pricing_policy])
        recommendationReason = container.decodeFirstString(for: [.recommendationReason, .recommendation_reason])
    }
}

struct IntentionProfile: Decodable, Identifiable, Hashable {
    let intentionId: String
    let title: String
    let description: String
    let domain: String
    let subdomain: String
    let riskProfile: String
    let rankingScore: Double
    let bestConfiguration: AIConfigurationAtom
    let explanation: String?

    var id: String { intentionId }

    private enum CodingKeys: String, CodingKey {
        case intentionId
        case id
        case intentionName
        case intention_name
        case title
        case description
        case summary
        case domain
        case subdomain
        case riskProfile
        case risk_profile
        case risk
        case rankingScore
        case ranking_score
        case bestConfiguration
        case best_configuration
        case bestConfig
        case configuration
        case explanation
        case why
        case rankingReason
        case ranking_reason
    }

    init(
        intentionId: String,
        title: String,
        description: String,
        domain: String,
        subdomain: String,
        riskProfile: String,
        rankingScore: Double,
        bestConfiguration: AIConfigurationAtom,
        explanation: String?
    ) {
        self.intentionId = intentionId
        self.title = title
        self.description = description
        self.domain = domain
        self.subdomain = subdomain
        self.riskProfile = riskProfile
        self.rankingScore = rankingScore
        self.bestConfiguration = bestConfiguration
        self.explanation = explanation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intentionId = container.decodeFirstString(for: [.intentionId, .id]) ?? UUID().uuidString
        title = container.decodeFirstString(for: [.title, .intentionName, .intention_name]) ?? intentionId
        description = container.decodeFirstString(for: [.description, .summary, .explanation]) ?? title
        domain = container.decodeFirstString(for: [.domain]) ?? "unknown"
        subdomain = container.decodeFirstString(for: [.subdomain]) ?? "unknown"
        riskProfile = container.decodeFirstString(for: [.riskProfile, .risk_profile, .risk]) ?? "unknown"

        if let configuration = container.decodeFirstDecodable(AIConfigurationAtom.self, for: [.bestConfiguration, .best_configuration, .bestConfig, .configuration]) {
            bestConfiguration = configuration
        } else {
            bestConfiguration = AIConfigurationAtom(
                configId: "unknown-config",
                model: "unknown",
                certificationLevel: "Uncertified",
                rankingScore: 0,
                benchmarkScore: 0
            )
        }

        rankingScore = container.decodeFirstDouble(for: [.rankingScore, .ranking_score]) ?? bestConfiguration.rankingScore
        explanation = container.decodeFirstString(for: [.explanation, .why, .rankingReason, .ranking_reason])
    }
}

struct BrowserCard: Identifiable, Hashable {
    let intentionId: String
    let title: String
    let shortDescription: String
    let domain: String
    let subdomain: String
    let riskProfile: String
    let rankingScore: Double
    let bestConfiguration: AIConfigurationAtom
    let benchmarkSummary: String
    let whyRecommended: String
    let rankingExplanation: String?
    let deployReady: Bool
    let intentionPath: String
    let capabilitiesSummary: String?
    let constraintsSummary: String?
    let certificateReference: String?
    let benchmarkContractReference: String?

    var id: String { intentionId + ":" + bestConfiguration.configId }

    init(profile: IntentionProfile) {
        intentionId = profile.intentionId
        title = profile.title
        shortDescription = profile.description
        domain = profile.domain
        subdomain = profile.subdomain
        riskProfile = profile.riskProfile
        rankingScore = profile.rankingScore
        bestConfiguration = profile.bestConfiguration
        benchmarkSummary = "benchmark \(String(format: "%.2f", profile.bestConfiguration.benchmarkScore))"
        whyRecommended = profile.explanation
            ?? profile.bestConfiguration.recommendationReason
            ?? "CLASHD27 signal + benchmark reliability + SafeClash certification"
        rankingExplanation = profile.explanation ?? profile.bestConfiguration.recommendationReason
        deployReady = true
        intentionPath = "\(profile.domain) / \(profile.subdomain) / \(profile.riskProfile)"
        capabilitiesSummary = profile.bestConfiguration.capabilities.isEmpty ? nil : profile.bestConfiguration.capabilities.joined(separator: ", ")
        constraintsSummary = nil
        certificateReference = profile.bestConfiguration.certificateId
        benchmarkContractReference = profile.bestConfiguration.benchmarkContract
    }

    init(certified: SafeClashCertifiedIntention) {
        intentionId = certified.intentionId
        title = certified.title
        shortDescription = certified.description
        domain = certified.domain
        subdomain = certified.subdomain
        riskProfile = certified.riskProfile
        rankingScore = certified.rankingScore
        bestConfiguration = certified.configurationAtom
        benchmarkSummary = certified.benchmarkSummary ?? "benchmark \(String(format: "%.2f", certified.benchmarkScore))"
        whyRecommended = certified.rankingExplanation
            ?? (certified.description.isEmpty ? "Certified for governed deployment based on ranking + benchmark envelope." : certified.description)
        rankingExplanation = certified.rankingExplanation
        deployReady = certified.deployReady
        intentionPath = "\(certified.domain) / \(certified.subdomain) / \(certified.riskProfile)"
        capabilitiesSummary = certified.capabilitiesSummary
        constraintsSummary = certified.constraintsSummary
        certificateReference = certified.certificateId
        benchmarkContractReference = certified.benchmarkContractId
    }
}

enum IntentionCatalogState: String, Codable, Hashable {
    case emerging
    case certified
    case promoted
}

struct EmergingIntentionProfile: Decodable, Identifiable, Hashable {
    let intentionId: String
    let title: String
    let domain: String
    let subdomain: String
    let description: String
    let riskProfile: String?
    let confidenceScore: Double
    let sourceClusters: [String]
    let linkedCells: [String]
    let clashdSignalSummary: String
    let state: IntentionCatalogState
    let discoveredAtIso: String?
    let hasCertifiedConfiguration: Bool?
    let candidateConfigurationAvailable: Bool?
    let relatedIncomingToolCount: Int?

    var id: String { intentionId }

    private enum CodingKeys: String, CodingKey {
        case intentionId
        case id
        case title
        case name
        case domain
        case subdomain
        case description
        case summary
        case riskProfile
        case risk_profile
        case risk
        case confidenceScore
        case confidence_score
        case score
        case sourceClusters
        case source_clusters
        case sourceClusterIds
        case source_cluster_ids
        case linkedCells
        case linked_cells
        case cells
        case clashdSignalSummary
        case clashd_signal_summary
        case signalSummary
        case signal_summary
        case state
        case discoveredAtIso
        case discovered_at_iso
        case hasCertifiedConfiguration
        case has_certified_configuration
        case certifiedConfigurationExists
        case certified_configuration_exists
        case candidateConfigurationAvailable
        case candidate_configuration_available
        case relatedIncomingToolCount
        case related_incoming_tool_count
        case relatedToolsCount
        case related_tools_count
    }

    init(
        intentionId: String,
        title: String? = nil,
        domain: String,
        subdomain: String,
        description: String,
        riskProfile: String? = nil,
        confidenceScore: Double,
        sourceClusters: [String],
        linkedCells: [String],
        clashdSignalSummary: String,
        state: IntentionCatalogState,
        discoveredAtIso: String? = nil,
        hasCertifiedConfiguration: Bool? = nil,
        candidateConfigurationAvailable: Bool? = nil,
        relatedIncomingToolCount: Int? = nil
    ) {
        self.intentionId = intentionId
        self.title = title ?? "\(domain) / \(subdomain)"
        self.domain = domain
        self.subdomain = subdomain
        self.description = description
        self.riskProfile = riskProfile
        self.confidenceScore = confidenceScore
        self.sourceClusters = sourceClusters
        self.linkedCells = linkedCells
        self.clashdSignalSummary = clashdSignalSummary
        self.state = state
        self.discoveredAtIso = discoveredAtIso
        self.hasCertifiedConfiguration = hasCertifiedConfiguration
        self.candidateConfigurationAvailable = candidateConfigurationAvailable
        self.relatedIncomingToolCount = relatedIncomingToolCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intentionId = container.decodeFirstString(for: [.intentionId, .id]) ?? UUID().uuidString
        let decodedDomain = container.decodeFirstString(for: [.domain]) ?? "unknown"
        let decodedSubdomain = container.decodeFirstString(for: [.subdomain]) ?? "unknown"
        domain = decodedDomain
        subdomain = decodedSubdomain
        title = container.decodeFirstString(for: [.title, .name]) ?? "\(decodedDomain) / \(decodedSubdomain)"
        description = container.decodeFirstString(for: [.description, .summary]) ?? "Emerging intention candidate."
        riskProfile = container.decodeFirstString(for: [.riskProfile, .risk_profile, .risk])
        confidenceScore = container.decodeFirstDouble(for: [.confidenceScore, .confidence_score, .score]) ?? 0

        let sourceClusters = container.decodeFirstStringArray(for: [.sourceClusters, .source_clusters, .sourceClusterIds, .source_cluster_ids])
        let linkedCells = container.decodeFirstStringArray(for: [.linkedCells, .linked_cells, .cells])
        self.sourceClusters = sourceClusters
        self.linkedCells = linkedCells

        clashdSignalSummary = container.decodeFirstString(for: [.clashdSignalSummary, .clashd_signal_summary, .signalSummary, .signal_summary]) ?? description
        state = IntentionCatalogState(rawValue: container.decodeFirstString(for: [.state])?.lowercased() ?? "emerging") ?? .emerging
        discoveredAtIso = container.decodeFirstString(for: [.discoveredAtIso, .discovered_at_iso])
        hasCertifiedConfiguration = container.decodeFirstBool(for: [.hasCertifiedConfiguration, .has_certified_configuration, .certifiedConfigurationExists, .certified_configuration_exists])
        candidateConfigurationAvailable = container.decodeFirstBool(for: [.candidateConfigurationAvailable, .candidate_configuration_available])
        relatedIncomingToolCount = container.decodeFirstInt(for: [.relatedIncomingToolCount, .related_incoming_tool_count, .relatedToolsCount, .related_tools_count])
    }
}

struct SafeClashBrowserCategory: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let domain: String
    let subdomains: [String]
    let certifiedCount: Int?
    let emergingCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case key
        case slug
        case title
        case name
        case label
        case domain
        case subdomain
        case subdomains
        case children
        case certifiedCount
        case certified_count
        case emergingCount
        case emerging_count
    }

    private struct CategoryChild: Decodable {
        let id: String?
        let slug: String?
        let key: String?
        let title: String?
        let name: String?
        let label: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawId = container.decodeFirstString(for: [.id, .key, .slug])
        let rawTitle = container.decodeFirstString(for: [.title, .name, .label])
        let rawDomain = container.decodeFirstString(for: [.domain])
        let fallbackDomain = rawTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")

        domain = rawDomain ?? fallbackDomain ?? "unknown"
        id = rawId ?? domain
        title = rawTitle ?? domain.replacingOccurrences(of: "-", with: " ").capitalized

        let values = container.decodeFirstStringArray(for: [.subdomains])
        if !values.isEmpty {
            subdomains = values
        } else if let single = container.decodeFirstString(for: [.subdomain]) {
            subdomains = [single]
        } else if let children = container.decodeFirstDecodableArray(CategoryChild.self, for: [.children]), !children.isEmpty {
            let resolved = children.compactMap { row in
                row.slug ?? row.key ?? row.id ?? row.title ?? row.name ?? row.label
            }
            subdomains = resolved.isEmpty ? ["general"] : resolved
        } else {
            subdomains = ["general"]
        }

        certifiedCount = container.decodeFirstInt(for: [.certifiedCount, .certified_count])
        emergingCount = container.decodeFirstInt(for: [.emergingCount, .emerging_count])
    }
}

struct SafeClashCertifiedIntention: Decodable, Identifiable, Hashable {
    let configId: String
    let intentionId: String
    let title: String
    let description: String
    let domain: String
    let subdomain: String
    let riskProfile: String
    let certificationLevel: String
    let rankingScore: Double
    let benchmarkSummary: String?
    let benchmarkScore: Double
    let model: String
    let capabilitiesSummary: String?
    let constraintsSummary: String?
    let runtimeEnvelopeHash: String?
    let certificateId: String?
    let benchmarkContractId: String?
    let deployReady: Bool
    let rankingExplanation: String?

    var id: String { configId }

    private enum CodingKeys: String, CodingKey {
        case configId
        case config_id
        case intentionId
        case intention_id
        case title
        case name
        case description
        case summary
        case domain
        case subdomain
        case riskProfile
        case risk_profile
        case risk
        case certificationLevel
        case certification_level
        case rankingScore
        case ranking_score
        case benchmarkSummary
        case benchmark_summary
        case benchmarkScore
        case benchmark_score
        case model
        case capabilitiesSummary
        case capabilities_summary
        case capabilities
        case constraintsSummary
        case constraints_summary
        case runtimeEnvelopeHash
        case runtime_envelope_hash
        case certificateId
        case certificate_id
        case benchmarkContractId
        case benchmark_contract_id
        case benchmarkContract
        case benchmark_contract
        case deployReady
        case deploy_ready
        case rankingExplanation
        case ranking_explanation
        case recommendationReason
        case recommendation_reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        configId = container.decodeFirstString(for: [.configId, .config_id]) ?? UUID().uuidString
        intentionId = container.decodeFirstString(for: [.intentionId, .intention_id]) ?? configId
        title = container.decodeFirstString(for: [.title, .name]) ?? intentionId
        description = container.decodeFirstString(for: [.description, .summary, .rankingExplanation, .ranking_explanation]) ?? title
        domain = container.decodeFirstString(for: [.domain]) ?? "unknown"
        subdomain = container.decodeFirstString(for: [.subdomain]) ?? "unknown"
        riskProfile = container.decodeFirstString(for: [.riskProfile, .risk_profile, .risk]) ?? "unknown"
        certificationLevel = container.decodeFirstString(for: [.certificationLevel, .certification_level]) ?? "Uncertified"
        rankingScore = container.decodeFirstDouble(for: [.rankingScore, .ranking_score]) ?? 0
        benchmarkSummary = container.decodeFirstString(for: [.benchmarkSummary, .benchmark_summary])
        benchmarkScore = container.decodeFirstDouble(for: [.benchmarkScore, .benchmark_score]) ?? 0
        model = container.decodeFirstString(for: [.model]) ?? "unknown"
        capabilitiesSummary = container.decodeFirstString(for: [.capabilitiesSummary, .capabilities_summary])
            ?? container.decodeFirstStringArray(for: [.capabilities]).joined(separator: ", ")
        constraintsSummary = container.decodeFirstString(for: [.constraintsSummary, .constraints_summary])
        runtimeEnvelopeHash = container.decodeFirstString(for: [.runtimeEnvelopeHash, .runtime_envelope_hash])
        certificateId = container.decodeFirstString(for: [.certificateId, .certificate_id])
        benchmarkContractId = container.decodeFirstString(for: [.benchmarkContractId, .benchmark_contract_id, .benchmarkContract, .benchmark_contract])
        deployReady = container.decodeFirstBool(for: [.deployReady, .deploy_ready]) ?? true
        rankingExplanation = container.decodeFirstString(for: [.rankingExplanation, .ranking_explanation, .recommendationReason, .recommendation_reason])
    }

    var configurationAtom: AIConfigurationAtom {
        AIConfigurationAtom(
            configId: configId,
            model: model,
            certificationLevel: certificationLevel,
            certificateId: certificateId,
            rankingScore: rankingScore,
            benchmarkScore: benchmarkScore,
            promptArchitectureReference: nil,
            capabilities: capabilitiesSummary?
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? [],
            benchmarkContract: benchmarkContractId,
            runtimeEnvelopeHash: runtimeEnvelopeHash,
            publisherIdentity: nil,
            pricingPolicy: nil,
            recommendationReason: rankingExplanation
        )
    }

    var profile: IntentionProfile {
        IntentionProfile(
            intentionId: intentionId,
            title: title,
            description: description,
            domain: domain,
            subdomain: subdomain,
            riskProfile: riskProfile,
            rankingScore: rankingScore,
            bestConfiguration: configurationAtom,
            explanation: rankingExplanation
        )
    }
}

struct SafeClashEmergingIntention: Decodable, Identifiable, Hashable {
    let intentionId: String
    let title: String
    let description: String
    let domain: String
    let subdomain: String
    let confidenceScore: Double
    let sourceSummary: String?
    let sourceClusters: [String]
    let linkedCells: [String]
    let relatedIncomingToolCount: Int?
    let certifiedConfigurationExists: Bool?
    let state: IntentionCatalogState

    var id: String { intentionId }

    private enum CodingKeys: String, CodingKey {
        case intentionId
        case intention_id
        case id
        case title
        case name
        case description
        case summary
        case domain
        case subdomain
        case confidenceScore
        case confidence_score
        case score
        case sourceSummary
        case source_summary
        case clashdSignalSummary
        case clashd_signal_summary
        case sourceClusters
        case source_clusters
        case linkedCells
        case linked_cells
        case relatedIncomingToolCount
        case related_incoming_tool_count
        case relatedIncomingTools
        case related_incoming_tools
        case certifiedConfigurationExists
        case certified_configuration_exists
        case hasCertifiedConfiguration
        case has_certified_configuration
        case state
        case riskProfile
        case risk_profile
    }

    private struct SourceClusterObject: Decodable {
        let cluster: String?
        let label: String?
        let id: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intentionId = container.decodeFirstString(for: [.intentionId, .intention_id, .id]) ?? UUID().uuidString
        let rawDomain = container.decodeFirstString(for: [.domain]) ?? "unknown"
        let rawSubdomain = container.decodeFirstString(for: [.subdomain]) ?? "unknown"
        domain = rawDomain
        subdomain = rawSubdomain
        title = container.decodeFirstString(for: [.title, .name]) ?? "\(rawDomain) / \(rawSubdomain)"
        description = container.decodeFirstString(for: [.description, .summary]) ?? title
        confidenceScore = container.decodeFirstDouble(for: [.confidenceScore, .confidence_score, .score]) ?? 0
        sourceSummary = container.decodeFirstString(for: [.sourceSummary, .source_summary, .clashdSignalSummary, .clashd_signal_summary])
        let sourceValues = container.decodeFirstStringArray(for: [.sourceClusters, .source_clusters])
        if !sourceValues.isEmpty {
            sourceClusters = sourceValues
        } else if let rows = container.decodeFirstDecodableArray(SourceClusterObject.self, for: [.sourceClusters, .source_clusters]), !rows.isEmpty {
            sourceClusters = rows.compactMap { $0.label ?? $0.cluster ?? $0.id }
        } else {
            sourceClusters = []
        }
        linkedCells = container.decodeFirstStringArray(for: [.linkedCells, .linked_cells])
        relatedIncomingToolCount = container.decodeFirstInt(for: [.relatedIncomingToolCount, .related_incoming_tool_count, .relatedIncomingTools, .related_incoming_tools])
        certifiedConfigurationExists = container.decodeFirstBool(for: [.certifiedConfigurationExists, .certified_configuration_exists, .hasCertifiedConfiguration, .has_certified_configuration])
        state = IntentionCatalogState(rawValue: container.decodeFirstString(for: [.state])?.lowercased() ?? "emerging") ?? .emerging
    }

    var profile: EmergingIntentionProfile {
        EmergingIntentionProfile(
            intentionId: intentionId,
            title: title,
            domain: domain,
            subdomain: subdomain,
            description: description,
            riskProfile: nil,
            confidenceScore: confidenceScore,
            sourceClusters: sourceClusters,
            linkedCells: linkedCells,
            clashdSignalSummary: sourceSummary ?? description,
            state: state,
            discoveredAtIso: nil,
            hasCertifiedConfiguration: certifiedConfigurationExists,
            candidateConfigurationAvailable: certifiedConfigurationExists,
            relatedIncomingToolCount: relatedIncomingToolCount
        )
    }
}

struct SafeClashBrowserFeed: Decodable, Hashable {
    let featured: [SafeClashCertifiedIntention]
    let categories: [SafeClashBrowserCategory]
    let certified: [SafeClashCertifiedIntention]
    let emerging: [SafeClashEmergingIntention]
}

struct SafeClashBrowserFeedEnvelope: Decodable {
    let ok: Bool?
    let feed: SafeClashBrowserFeed?
    let browser: SafeClashBrowserFeed?
    let projection: SafeClashBrowserFeed?
    let data: SafeClashBrowserFeed?
    let featured: [SafeClashCertifiedIntention]?
    let categories: [SafeClashBrowserCategory]?
    let certified: [SafeClashCertifiedIntention]?
    let emerging: [SafeClashEmergingIntention]?

    var resolved: SafeClashBrowserFeed? {
        if let nested = feed ?? browser ?? projection ?? data {
            return nested
        }

        if featured != nil || categories != nil || certified != nil || emerging != nil {
            return SafeClashBrowserFeed(
                featured: featured ?? [],
                categories: categories ?? [],
                certified: certified ?? [],
                emerging: emerging ?? []
            )
        }
        return nil
    }
}

struct EmergingIntentionsEnvelope: Decodable {
    let ok: Bool?
    let candidates: [EmergingIntentionProfile]?
    let intentions: [EmergingIntentionProfile]?
    let items: [EmergingIntentionProfile]?
    let data: [EmergingIntentionProfile]?

    var resolved: [EmergingIntentionProfile] {
        candidates ?? intentions ?? items ?? data ?? []
    }
}

struct SafeClashSearchEnvelope: Decodable {
    let ok: Bool?
    let results: [IntentionProfile]?
    let items: [IntentionProfile]?
    let data: [IntentionProfile]?
    let intentions: [IntentionProfile]?

    var resolved: [IntentionProfile] {
        results ?? items ?? data ?? intentions ?? []
    }
}

struct SafeClashConfigurationEnvelope: Decodable {
    let ok: Bool?
    let configuration: AIConfigurationAtom?
    let config: AIConfigurationAtom?
    let data: AIConfigurationAtom?

    var resolved: AIConfigurationAtom? {
        configuration ?? config ?? data
    }
}

struct DeployConfigurationRequest: Encodable, Identifiable, Hashable {
    let intentionId: String
    let intentionTitle: String
    let domain: String
    let subdomain: String
    let riskProfile: String
    let configId: String
    let model: String
    let certificationLevel: String
    let certificateId: String?
    let rankingScore: Double
    let benchmarkScore: Double
    let benchmarkContractId: String?
    let runtimeEnvelopeHash: String?
    let promptArchitectureReference: String?
    let capabilities: [String]
    let constraints: [String: String]
    let whyEligible: String
    let source: String

    var id: String { "\(intentionId):\(configId)" }
}

struct DeployConfigurationResponse: Decodable, Hashable {
    let ok: Bool?
    let proposalId: String?
    let status: String?
    let summary: String?
    let nextStep: String?
    let configId: String?
    let intentionId: String?
    let reason: String?
    let requestId: String?

    private enum CodingKeys: String, CodingKey {
        case ok
        case proposalId
        case proposal_id
        case status
        case summary
        case message
        case nextStep
        case next_step
        case configId
        case config_id
        case intentionId
        case intention_id
        case reason
        case requestId
        case request_id
    }

    init(
        ok: Bool? = nil,
        proposalId: String? = nil,
        status: String? = nil,
        summary: String? = nil,
        nextStep: String? = nil,
        configId: String? = nil,
        intentionId: String? = nil,
        reason: String? = nil,
        requestId: String? = nil
    ) {
        self.ok = ok
        self.proposalId = proposalId
        self.status = status
        self.summary = summary
        self.nextStep = nextStep
        self.configId = configId
        self.intentionId = intentionId
        self.reason = reason
        self.requestId = requestId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try? container.decodeIfPresent(Bool.self, forKey: .ok)
        proposalId = container.decodeFirstString(for: [.proposalId, .proposal_id])
        status = container.decodeFirstString(for: [.status])
        summary = container.decodeFirstString(for: [.summary, .message])
        nextStep = container.decodeFirstString(for: [.nextStep, .next_step])
        configId = container.decodeFirstString(for: [.configId, .config_id])
        intentionId = container.decodeFirstString(for: [.intentionId, .intention_id])
        reason = container.decodeFirstString(for: [.reason])
        requestId = container.decodeFirstString(for: [.requestId, .request_id])
    }
}

private extension KeyedDecodingContainer {
    func decodeFirstString(for keys: [Key]) -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    func decodeFirstDouble(for keys: [Key]) -> Double? {
        for key in keys {
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return Double(value)
            }
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }
        return nil
    }

    func decodeFirstBool(for keys: [Key]) -> Bool? {
        for key in keys {
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value != 0
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if ["true", "1", "yes"].contains(normalized) { return true }
                if ["false", "0", "no"].contains(normalized) { return false }
            }
        }
        return nil
    }

    func decodeFirstInt(for keys: [Key]) -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return Int(value.rounded())
            }
            if let value = try? decodeIfPresent(String.self, forKey: key),
               let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }
        return nil
    }

    func decodeFirstStringArray(for keys: [Key]) -> [String] {
        for key in keys {
            if let values = try? decode([String].self, forKey: key), !values.isEmpty {
                return values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
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
