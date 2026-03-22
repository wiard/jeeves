import Foundation

struct ResearchDomain: Identifiable, Hashable, Sendable, Codable {
    let id: String
    var label: String?
    var keywords: [String]?
    var gapCount: Int?
    var lastRun: String?
    var description: String?

    init(
        id: String,
        label: String? = nil,
        keywords: [String]? = nil,
        gapCount: Int? = nil,
        lastRun: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.label = label
        self.keywords = keywords
        self.gapCount = gapCount
        self.lastRun = lastRun
        self.description = description
    }

    var displayName: String {
        let preferred = [label, id]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return preferred ?? id
    }

    var displaySummary: String {
        if let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }
        return "Nieuw onderzoek starten in dit domein."
    }

    var displayGapsCount: Int {
        gapCount ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case label
        case keywords
        case gapCount = "gap_count"
        case lastRun = "last_run"
        case description
        case domainId
        case slug
        case key
        case title
        case name
        case gapsCount
        case gaps
        case gapsFound
        case summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawId = [
            try? container.decodeIfPresent(String.self, forKey: .id),
            try? container.decodeIfPresent(String.self, forKey: .domainId),
            try? container.decodeIfPresent(String.self, forKey: .slug),
            try? container.decodeIfPresent(String.self, forKey: .key),
            try? container.decodeIfPresent(String.self, forKey: .name),
            try? container.decodeIfPresent(String.self, forKey: .label),
            try? container.decodeIfPresent(String.self, forKey: .title)
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }

        guard let id = rawId, !id.isEmpty else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "ResearchDomain.id is required")
            )
        }

        let decodedGapsCount = try? container.decodeIfPresent(Int.self, forKey: .gapsCount)
        let decodedGapCount = try? container.decodeIfPresent(Int.self, forKey: .gapCount)
        let decodedGapsFound = try? container.decodeIfPresent(Int.self, forKey: .gapsFound)
        let decodedGaps = try? container.decodeIfPresent(Int.self, forKey: .gaps)
        let resolvedGapCount = decodedGapCount
            ?? decodedGapsCount
            ?? decodedGapsFound
            ?? decodedGaps

        self.id = id
        self.label = [
            try? container.decodeIfPresent(String.self, forKey: .label),
            try? container.decodeIfPresent(String.self, forKey: .name),
            try? container.decodeIfPresent(String.self, forKey: .title)
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
        self.keywords = try? container.decodeIfPresent([String].self, forKey: .keywords)
        self.gapCount = resolvedGapCount
        self.lastRun = try? container.decodeIfPresent(String.self, forKey: .lastRun)
        self.description = [
            try? container.decodeIfPresent(String.self, forKey: .description),
            try? container.decodeIfPresent(String.self, forKey: .summary)
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(keywords, forKey: .keywords)
        try container.encodeIfPresent(gapCount, forKey: .gapCount)
        try container.encodeIfPresent(lastRun, forKey: .lastRun)
        try container.encodeIfPresent(description, forKey: .description)
    }
}

struct ResearchGapCard: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let hypothesis: String
    let score: Double
    let domainId: String?
    let domainLabel: String?
    let detectedAt: String?

    var scoreFraction: Double {
        let bounded = score > 1 ? score / 100 : score
        return min(max(bounded, 0), 1)
    }

    var scoreBadge: String {
        String(format: "%.0f%%", scoreFraction * 100)
    }
}

struct ResearchDomainInsight: Hashable, Sendable {
    let domainId: String
    let gapCount: Int
    let lastGapDate: String?
    let averageScore: Double
    let topGaps: [ResearchGapCard]
}

struct ResearchActivitySummary: Equatable, Sendable {
    let domainId: String
    let domainLabel: String
    let gapCount: Int
    let lastGapDate: String?
}

struct ResearchJob: Identifiable, Hashable, Sendable {
    let id: String
    let domainId: String
    let domainName: String

    static func decode(from data: Data, fallbackDomainId: String) throws -> ResearchJob {
        let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let root = ResearchPayloadParser.dictionary(from: json)
        let payload = ResearchPayloadParser.dictionary(in: root, keys: ["job", "data", "result"])
        let source = payload.isEmpty ? root : payload

        let domainId = ResearchPayloadParser.string(in: source, keys: ["domainId", "domain_id"])
            ?? ResearchPayloadParser.string(
                in: ResearchPayloadParser.dictionary(in: source, keys: ["domain"]),
                keys: ["id", "domainId", "domain_id"]
            )
            ?? fallbackDomainId

        let domainName = ResearchPayloadParser.string(in: source, keys: ["domainName", "domain_name"])
            ?? ResearchPayloadParser.string(
                in: ResearchPayloadParser.dictionary(in: source, keys: ["domain"]),
                keys: ["name", "title", "label"]
            )
            ?? fallbackDomainId

        let id = ResearchPayloadParser.string(in: source, keys: ["jobId", "job_id", "id"])
            ?? ResearchPayloadParser.string(in: root, keys: ["jobId", "job_id", "id"])
            ?? UUID().uuidString

        return ResearchJob(id: id, domainId: domainId, domainName: domainName)
    }
}

struct ResearchJobStatus: Hashable, Sendable {
    let jobId: String
    let status: String
    let phaseText: String
    let foundGapCount: Int
    let domainId: String?
    let domainName: String?
    let gapIds: [String]

    var isComplete: Bool {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["complete", "completed", "done", "succeeded", "success"].contains(normalized)
    }

    var displayDomainName: String {
        if let domainName, !domainName.isEmpty {
            return domainName
        }
        if let domainId, !domainId.isEmpty {
            return domainId
        }
        return "dit domein"
    }

    static func decode(from data: Data, jobId fallbackJobId: String) throws -> ResearchJobStatus {
        let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let root = ResearchPayloadParser.dictionary(from: json)
        let payload = ResearchPayloadParser.dictionary(in: root, keys: ["status", "jobStatus", "job", "data", "result"])
        let source = payload.isEmpty ? root : payload

        let gapIds = ResearchPayloadParser.strings(in: source, keys: ["gapIds", "gap_ids"])
        let nestedGapIDs = ResearchPayloadParser.rows(
            from: source,
            arrayKeys: ["gaps", "items", "results"]
        ).compactMap { row in
            ResearchPayloadParser.string(in: row, keys: ["gapId", "gap_id", "id"])
        }
        let allGapIds = Array(NSOrderedSet(array: gapIds + nestedGapIDs)) as? [String] ?? []

        let foundGapCount = ResearchPayloadParser.int(in: source, keys: ["foundGapCount", "found_gap_count", "gapsCount", "gaps_count", "gapCount", "gap_count"])
            ?? ResearchPayloadParser.int(in: root, keys: ["foundGapCount", "found_gap_count", "gapsCount", "gaps_count", "gapCount", "gap_count"])
            ?? max(allGapIds.count, ResearchPayloadParser.rows(from: source, arrayKeys: ["gaps", "items", "results"]).count)

        let status = ResearchPayloadParser.string(in: source, keys: ["status", "state"])
            ?? ResearchPayloadParser.string(in: root, keys: ["status", "state"])
            ?? "running"

        let phaseText = ResearchPayloadParser.string(
            in: source,
            keys: ["phase", "phaseText", "phase_text", "currentPhase", "current_phase", "stage", "message"]
        ) ?? ResearchPayloadParser.string(
            in: root,
            keys: ["phase", "phaseText", "phase_text", "currentPhase", "current_phase", "stage", "message"]
        ) ?? "Collecting papers..."

        let domainId = ResearchPayloadParser.string(in: source, keys: ["domainId", "domain_id"])
            ?? ResearchPayloadParser.string(
                in: ResearchPayloadParser.dictionary(in: source, keys: ["domain"]),
                keys: ["id", "domainId", "domain_id"]
            )

        let domainName = ResearchPayloadParser.string(in: source, keys: ["domainName", "domain_name"])
            ?? ResearchPayloadParser.string(
                in: ResearchPayloadParser.dictionary(in: source, keys: ["domain"]),
                keys: ["name", "title", "label"]
            )

        let jobId = ResearchPayloadParser.string(in: source, keys: ["jobId", "job_id", "id"])
            ?? ResearchPayloadParser.string(in: root, keys: ["jobId", "job_id", "id"])
            ?? fallbackJobId

        return ResearchJobStatus(
            jobId: jobId,
            status: status,
            phaseText: phaseText,
            foundGapCount: foundGapCount,
            domainId: domainId,
            domainName: domainName,
            gapIds: allGapIds
        )
    }
}

enum ResearchDomainsResponse {
    static func decode(from data: Data) throws -> [ResearchDomain] {
        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            if text.hasPrefix("<!doctype html") || text.hasPrefix("<html") {
                throw OperatorSurfacesError(message: "De research-domeinfeed antwoordde met HTML in plaats van JSON.")
            }
        }

        let decoder = JSONDecoder()
        if let errorEnvelope = try? decoder.decode(ResearchErrorEnvelope.self, from: data) {
            let errorMessage = [
                errorEnvelope.error,
                errorEnvelope.message
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

            if let errorMessage {
                throw OperatorSurfacesError(message: errorMessage)
            }
        }

        if let envelope = try? decoder.decode(ResearchDomainsEnvelope.self, from: data),
           let domains = envelope.domains,
           !domains.isEmpty {
            return domains
        }

        if let domains = try? decoder.decode([ResearchDomain].self, from: data),
           !domains.isEmpty {
            return domains
        }

        let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let rows = ResearchPayloadParser.rows(from: json, arrayKeys: ["domains", "items", "results", "data"])

        return rows.compactMap { row in
            let id = ResearchPayloadParser.string(in: row, keys: ["domainId", "domain_id", "id", "slug", "key"])
                ?? ResearchPayloadParser.string(in: row, keys: ["name", "title", "label"])
            let name = ResearchPayloadParser.string(in: row, keys: ["name", "title", "label"]) ?? id

            guard let resolvedId = id?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let resolvedName = name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !resolvedId.isEmpty,
                  !resolvedName.isEmpty else {
                return nil
            }

            let summary = ResearchPayloadParser.string(in: row, keys: ["description", "summary", "subtitle"])
                ?? "Nieuw onderzoek starten in dit domein."
            let gapsCount = ResearchPayloadParser.int(in: row, keys: ["gapsCount", "gaps_count", "gapCount", "gap_count", "count"])
                ?? ResearchPayloadParser.rows(from: row, arrayKeys: ["gaps", "results"]).count
            return ResearchDomain(
                id: resolvedId,
                label: ResearchPayloadParser.string(in: row, keys: ["label", "title", "name"]) ?? resolvedName,
                keywords: row["keywords"] as? [String],
                gapCount: gapsCount,
                lastRun: ResearchPayloadParser.string(in: row, keys: ["last_run", "lastRun"]),
                description: summary.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}

private struct ResearchDomainsEnvelope: Decodable {
    let domains: [ResearchDomain]?
}

private struct ResearchErrorEnvelope: Decodable {
    let error: String?
    let message: String?
}

private enum ResearchPayloadParser {
    static func dictionary(from json: Any) -> [String: Any] {
        json as? [String: Any] ?? [:]
    }

    static func dictionary(in root: [String: Any], keys: [String]) -> [String: Any] {
        for key in keys {
            if let dict = root[key] as? [String: Any] {
                return dict
            }
        }
        return [:]
    }

    static func rows(from json: Any, arrayKeys: [String]) -> [[String: Any]] {
        if let rows = json as? [[String: Any]] {
            return rows
        }

        let root = dictionary(from: json)
        for key in arrayKeys {
            if let rows = root[key] as? [[String: Any]] {
                return rows
            }
        }

        for key in arrayKeys {
            if let nested = root[key] as? [String: Any] {
                let nestedRows = rows(from: nested, arrayKeys: arrayKeys)
                if !nestedRows.isEmpty {
                    return nestedRows
                }
            }
        }

        return []
    }

    static func string(in root: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = root[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    static func int(in root: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = root[key] as? Int {
                return value
            }
            if let value = root[key] as? Double {
                return Int(value)
            }
            if let value = root[key] as? String, let parsed = Int(value) {
                return parsed
            }
        }
        return nil
    }

    static func strings(in root: [String: Any], keys: [String]) -> [String] {
        for key in keys {
            if let values = root[key] as? [String] {
                return values
            }
            if let values = root[key] as? [[String: Any]] {
                let parsed = values.compactMap { string(in: $0, keys: ["gapId", "gap_id", "id"]) }
                if !parsed.isEmpty {
                    return parsed
                }
            }
        }
        return []
    }
}
