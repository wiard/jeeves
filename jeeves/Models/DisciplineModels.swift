import Foundation

struct Discipline: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var label: String?
    var color: String?
    var gapCount: Int?
    var lastRun: String?
    var avgScore: Double?
    var topScore: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case color
        case gapCount = "gap_count"
        case lastRun = "last_run"
        case avgScore = "avg_score"
        case topScore = "top_score"
        case gapCountCamel = "gapCount"
        case lastRunCamel = "lastRun"
        case avgScoreCamel = "avgScore"
        case topScoreCamel = "topScore"
    }

    init(
        id: String,
        label: String? = nil,
        color: String? = nil,
        gapCount: Int? = nil,
        lastRun: String? = nil,
        avgScore: Double? = nil,
        topScore: Double? = nil
    ) {
        self.id = id
        self.label = label
        self.color = color
        self.gapCount = gapCount
        self.lastRun = lastRun
        self.avgScore = avgScore
        self.topScore = topScore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawId = (try? container.decodeIfPresent(String.self, forKey: .id))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = rawId, !id.isEmpty else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Discipline.id is required")
            )
        }

        self.id = id
        self.label = (try? container.decodeIfPresent(String.self, forKey: .label)) ?? nil
        self.color = (try? container.decodeIfPresent(String.self, forKey: .color)) ?? nil
        self.gapCount = (try? container.decodeIfPresent(Int.self, forKey: .gapCount))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .gapCountCamel))
        self.lastRun = (try? container.decodeIfPresent(String.self, forKey: .lastRun))
            ?? (try? container.decodeIfPresent(String.self, forKey: .lastRunCamel))
        self.avgScore = (try? container.decodeIfPresent(Double.self, forKey: .avgScore))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .avgScoreCamel))
        self.topScore = (try? container.decodeIfPresent(Double.self, forKey: .topScore))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .topScoreCamel))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(gapCount, forKey: .gapCount)
        try container.encodeIfPresent(lastRun, forKey: .lastRun)
        try container.encodeIfPresent(avgScore, forKey: .avgScore)
        try container.encodeIfPresent(topScore, forKey: .topScore)
    }

    var displayLabel: String {
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false ? trimmed : nil) ?? id
    }

    var effectiveAverageScore: Double {
        let raw = avgScore ?? topScore ?? 0
        return raw > 1 ? raw / 100 : raw
    }

    var displayGapCount: Int {
        gapCount ?? 0
    }
}

struct DisciplineGap: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var hypothesis: String?
    var score: Double?
    var disciplineId: String?
    var date: String?
    var paperCount: Int?
    var opportunityLabel: String?
    var opportunityScore: Double?
    var propertyName: String?
    var propertyAxis: String?
    var propertyDescription: String?
    var title: String?
    var disciplineLabel: String?
    var color: String?
    var supportingSources: [String]?
    var componentScores: [String: Double]?

    enum CodingKeys: String, CodingKey {
        case id
        case hypothesis
        case score
        case date
        case disciplineId = "discipline_id"
        case paperCount = "paper_count"
        case opportunityLabel = "opportunity_label"
        case opportunityScore = "opportunity_score"
        case disciplineIdCamel = "disciplineId"
        case paperCountCamel = "paperCount"
        case opportunityLabelCamel = "opportunityLabel"
        case opportunityScoreCamel = "opportunityScore"
        case propertyName = "property_name"
        case propertyAxis = "property_axis"
        case propertyDescription = "property_description"
        case propertyNameCamel = "propertyName"
        case propertyAxisCamel = "propertyAxis"
        case propertyDescriptionCamel = "propertyDescription"
        case title
        case disciplineLabel
        case color
        case createdAtIso
        case supportingSources
        case componentScores
        case sourcePapers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawId = (try? container.decodeIfPresent(String.self, forKey: .id))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = rawId, !id.isEmpty else {
            throw DecodingError.keyNotFound(
                CodingKeys.id,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "DisciplineGap.id is required")
            )
        }

        let paperStubs = (try? container.decodeIfPresent([DisciplineGapPaperStub].self, forKey: .sourcePapers)) ?? nil

        self.id = id
        self.hypothesis = (try? container.decodeIfPresent(String.self, forKey: .hypothesis)) ?? nil
        self.score = (try? container.decodeIfPresent(Double.self, forKey: .score)) ?? nil
        self.disciplineId = (try? container.decodeIfPresent(String.self, forKey: .disciplineId))
            ?? (try? container.decodeIfPresent(String.self, forKey: .disciplineIdCamel))
        self.date = (try? container.decodeIfPresent(String.self, forKey: .date))
            ?? (try? container.decodeIfPresent(String.self, forKey: .createdAtIso))
        self.paperCount = (try? container.decodeIfPresent(Int.self, forKey: .paperCount))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .paperCountCamel))
            ?? paperStubs?.count
        self.opportunityLabel = (try? container.decodeIfPresent(String.self, forKey: .opportunityLabel))
            ?? (try? container.decodeIfPresent(String.self, forKey: .opportunityLabelCamel))
        self.opportunityScore = (try? container.decodeIfPresent(Double.self, forKey: .opportunityScore))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .opportunityScoreCamel))
        self.propertyName = (try? container.decodeIfPresent(String.self, forKey: .propertyName))
            ?? (try? container.decodeIfPresent(String.self, forKey: .propertyNameCamel))
        self.propertyAxis = (try? container.decodeIfPresent(String.self, forKey: .propertyAxis))
            ?? (try? container.decodeIfPresent(String.self, forKey: .propertyAxisCamel))
        self.propertyDescription = (try? container.decodeIfPresent(String.self, forKey: .propertyDescription))
            ?? (try? container.decodeIfPresent(String.self, forKey: .propertyDescriptionCamel))
        self.title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? nil
        self.disciplineLabel = (try? container.decodeIfPresent(String.self, forKey: .disciplineLabel)) ?? nil
        self.color = (try? container.decodeIfPresent(String.self, forKey: .color)) ?? nil
        self.supportingSources = (try? container.decodeIfPresent([String].self, forKey: .supportingSources)) ?? nil
        self.componentScores = (try? container.decodeIfPresent([String: Double].self, forKey: .componentScores)) ?? nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(hypothesis, forKey: .hypothesis)
        try container.encodeIfPresent(score, forKey: .score)
        try container.encodeIfPresent(disciplineId, forKey: .disciplineId)
        try container.encodeIfPresent(date, forKey: .date)
        try container.encodeIfPresent(paperCount, forKey: .paperCount)
        try container.encodeIfPresent(opportunityLabel, forKey: .opportunityLabel)
        try container.encodeIfPresent(opportunityScore, forKey: .opportunityScore)
        try container.encodeIfPresent(propertyName, forKey: .propertyName)
        try container.encodeIfPresent(propertyAxis, forKey: .propertyAxis)
        try container.encodeIfPresent(propertyDescription, forKey: .propertyDescription)
    }

    var displayTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        let hypothesis = hypothesis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return hypothesis.isEmpty ? id : hypothesis
    }

    var displayHypothesis: String {
        let trimmed = hypothesis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Deze gap heeft nog geen volledige hypothese." : trimmed
    }

    var scoreFraction: Double {
        let raw = score ?? 0
        let normalized = raw > 1 ? raw / 100 : raw
        return min(max(normalized, 0), 1)
    }

    var displayScore: String {
        String(format: "%.0f%%", scoreFraction * 100)
    }

    var displayPaperCount: Int {
        paperCount ?? 0
    }

    var evidenceChain: [String] {
        Array((supportingSources ?? []).prefix(3))
    }
}

private struct DisciplineGapPaperStub: Decodable {
    let title: String?
}
