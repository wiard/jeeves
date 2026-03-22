import Foundation

struct BiebLatestCell: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let gapId: String?
    let label: String
    let title: String?
    let claim: String?
    let domain: String
    let domainLabel: String?
    let score: Double
    let opportunityScore: Double?
    let opportunityLabel: String?
    let propertyName: String?
    let propertyAxis: String?
    let propertyDescription: String?
    let shortName: String?
    let hypothesis: String?
    let cellId: String?
    let positionKey: String?
    let kind: String?
    let detectedAtIso: String?

    var normalizedScore: Double {
        min(max(score, 0), 1)
    }

    var isDecisionCandidate: Bool {
        (kind?.lowercased() == "gap-packet") || (hypothesis?.isEmpty == false)
    }

    var displayTitle: String {
        if let shortName,
           let cleanedShortName = BiebPresentation.cleanTitle(shortName),
           !BiebPresentation.looksTechnical(cleanedShortName) {
            return cleanedShortName
        }

        if let hypothesisTitle = BiebPresentation.conciseTitle(from: hypothesis) {
            return hypothesisTitle
        }

        if let cleanedLabel = BiebPresentation.cleanTitle(label) {
            return cleanedLabel
        }

        return label
    }

    var displaySummary: String? {
        guard let summary = BiebPresentation.conciseSummary(from: hypothesis) else {
            return nil
        }
        guard BiebPresentation.normalize(summary) != BiebPresentation.normalize(displayTitle) else {
            return nil
        }
        return summary
    }
}

struct BiebLatestResponse: Sendable {
    let items: [BiebLatestCell]

    static func decode(from data: Data) throws -> BiebLatestResponse {
        let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])

        var rows = GovernedOperatorFeedParser.rows(
            from: json,
            arrayKeys: ["cells", "items", "latest", "data", "results"]
        )

        // API wraps cells inside "snapshot": {"runId":"…","cells":[…]}
        if rows.isEmpty, let root = json as? [String: Any] {
            let snapshot = GovernedOperatorFeedParser.dictionary(
                in: root,
                keys: ["snapshot", "run", "result"]
            )
            if !snapshot.isEmpty {
                rows = GovernedOperatorFeedParser.rows(
                    from: snapshot,
                    arrayKeys: ["cells", "items", "latest", "data", "results"]
                )
            }
        }

        let items = rows.compactMap(BiebLatestResponse.parseCell(from:))
            .sorted { $0.score > $1.score }
        return BiebLatestResponse(items: items)
    }

    private static func parseCell(from row: [String: Any]) -> BiebLatestCell? {
        let label = GovernedOperatorFeedParser.string(
            in: row,
            keys: ["label", "title", "name", "headline"]
        ) ?? GovernedOperatorFeedParser.string(
            in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["metadata", "hypothesis"]),
            keys: ["statement", "summary"]
        )

        let gapId = GovernedOperatorFeedParser.string(in: row, keys: ["gapId", "gap_id", "id"])
            ?? GovernedOperatorFeedParser.string(
                in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["gap", "proposal"]),
                keys: ["gapId", "gap_id", "id"]
            )

        guard let label, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = GovernedOperatorFeedParser.string(in: row, keys: ["title", "headline", "name"])
        let claim = GovernedOperatorFeedParser.string(
            in: row,
            keys: ["claim", "problem", "issue"]
        ) ?? GovernedOperatorFeedParser.string(
            in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["metadata", "hypothesis"]),
            keys: ["claim", "problem", "issue"]
        )
        let domain = GovernedOperatorFeedParser.string(
            in: row,
            keys: ["domain", "source", "namespace", "surface"]
        ) ?? GovernedOperatorFeedParser.string(
            in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["metadata", "origin", "source"]),
            keys: ["domain", "namespace", "surface", "source"]
        ) ?? "Onbekend domein"
        let domainLabel = GovernedOperatorFeedParser.string(
            in: row,
            keys: ["domainLabel", "domain_label"]
        ) ?? GovernedOperatorFeedParser.string(
            in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["metadata", "origin", "source"]),
            keys: ["domainLabel", "domain_label", "label", "title"]
        )

        let score = GovernedOperatorFeedParser.double(
            in: row,
            keys: ["score", "rankingScore", "confidence", "weight", "residue"]
        ) ?? GovernedOperatorFeedParser.double(
            in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["metadata", "scores", "scoringTrace"]),
            keys: ["total", "score", "gravity", "confidence"]
        ) ?? 0
        let opportunityScore = GovernedOperatorFeedParser.double(
            in: row,
            keys: ["opportunityScore", "opportunity_score"]
        ) ?? GovernedOperatorFeedParser.double(
            in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["metadata", "opportunity", "scores"]),
            keys: ["opportunityScore", "opportunity_score"]
        )
        let opportunityLabel = GovernedOperatorFeedParser.string(
            in: row,
            keys: ["opportunityLabel", "opportunity_label"]
        ) ?? GovernedOperatorFeedParser.string(
            in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["metadata", "opportunity"]),
            keys: ["label", "opportunityLabel", "opportunity_label"]
        )
        let propertyName = GovernedOperatorFeedParser.string(
            in: row,
            keys: ["propertyName", "property_name"]
        ) ?? GovernedOperatorFeedParser.string(
            in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["metadata", "property"]),
            keys: ["name", "propertyName", "property_name"]
        )
        let propertyAxis = GovernedOperatorFeedParser.string(
            in: row,
            keys: ["propertyAxis", "property_axis"]
        ) ?? GovernedOperatorFeedParser.string(
            in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["metadata", "property"]),
            keys: ["axis", "propertyAxis", "property_axis"]
        )
        let propertyDescription = GovernedOperatorFeedParser.string(
            in: row,
            keys: ["propertyDescription", "property_description"]
        ) ?? GovernedOperatorFeedParser.string(
            in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["metadata", "property"]),
            keys: ["description", "propertyDescription", "property_description"]
        )

        let cellId = GovernedOperatorFeedParser.string(in: row, keys: ["cellId", "cell_id", "cubeAddress", "address"])
        let positionKey = GovernedOperatorFeedParser.string(in: row, keys: ["positionKey", "position_key"])
        let kind = GovernedOperatorFeedParser.string(in: row, keys: ["type", "kind"])
        let detectedAtIso = GovernedOperatorFeedParser.string(
            in: row,
            keys: ["detectedAtIso", "detected_at_iso", "createdAtIso", "created_at_iso", "updatedAtIso", "updated_at_iso"]
        )
        let shortName = GovernedOperatorFeedParser.string(in: row, keys: ["shortName", "short_name"])
        let hypothesis = GovernedOperatorFeedParser.string(
            in: row,
            keys: ["hypothesis", "statement", "summary", "description"]
        ) ?? GovernedOperatorFeedParser.string(
            in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["metadata", "hypothesis"]),
            keys: ["statement", "summary", "description", "text"]
        )
        let resolvedID = positionKey
            ?? gapId
            ?? cellId
            ?? shortName?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? trimmedLabel

        return BiebLatestCell(
            id: resolvedID,
            gapId: gapId,
            label: trimmedLabel,
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines),
            claim: claim?.trimmingCharacters(in: .whitespacesAndNewlines),
            domain: domain,
            domainLabel: domainLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
            score: score,
            opportunityScore: opportunityScore,
            opportunityLabel: opportunityLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
            propertyName: propertyName?.trimmingCharacters(in: .whitespacesAndNewlines),
            propertyAxis: propertyAxis?.trimmingCharacters(in: .whitespacesAndNewlines),
            propertyDescription: propertyDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
            shortName: shortName,
            hypothesis: hypothesis?.trimmingCharacters(in: .whitespacesAndNewlines),
            cellId: cellId,
            positionKey: positionKey,
            kind: kind,
            detectedAtIso: detectedAtIso
        )
    }
}

struct RadarHeatmapCell: Identifiable, Hashable, Sendable {
    let cellNumber: Int
    let skillName: String
    let cellId: String
    let score: Double

    var id: Int { cellNumber }

    var displayNumber: String {
        String(format: "%02d", cellNumber)
    }

    var normalizedScore: Double {
        min(max(score, 0), 1)
    }

    static func skillName(for cellNumber: Int) -> String {
        let names = [
            "Kenniskloof-detector",
            "Paradigma-toetser",
            "Vergeten-onderzoek-vinder",
            "Disciplinegrens-mapper",
            "Consensus-kraker",
            "Replicatie-checker",
            "Stille-stem-detector",
            "Fundament-toetser",
            "Historische-patroonherkenner",
            "Urgentie-weger",
            "Cross-domein-linker",
            "Contradictie-vinder",
            "Kansenmeter",
            "Convergentie-detector",
            "Blind-spot-mapper",
            "Signaal-versterker",
            "Hypothese-generator",
            "Domein-vertaler",
            "Trend-extrapolator",
            "Zwakke-signaal-scanner",
            "Toekomst-gap-projecter",
            "Innovatiekans-detector",
            "Constellatie-bouwer",
            "Systeemkwetsbaarheid-scanner",
            "Waarde-gap-finder",
            "Disruptie-detector",
            "Belofte-kristallisator"
        ]

        guard names.indices.contains(cellNumber) else { return "Onbekende cel" }
        if cellNumber == 13 {
            return "\(names[cellNumber]) (kerncel)"
        }
        return names[cellNumber]
    }
}

struct RadarHeatmapResponse: Sendable {
    let cells: [RadarHeatmapCell]

    static func decode(from data: Data) throws -> RadarHeatmapResponse {
        let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let rows = GovernedOperatorFeedParser.rows(
            from: json,
            arrayKeys: ["cells", "items", "data", "heatmap", "results"]
        )

        var parsed = rows.compactMap(RadarHeatmapResponse.parseCell(from:))

        if parsed.isEmpty,
           let root = json as? [String: Any] {
            let scoreMap = GovernedOperatorFeedParser.dictionary(
                in: root,
                keys: ["scores", "heatmap", "cellsById", "cells_by_id"]
            )
            if !scoreMap.isEmpty {
                parsed = scoreMap.compactMap { key, value in
                    guard let score = GovernedOperatorFeedParser.double(value) else {
                        return nil
                    }
                    guard let number = GovernedOperatorFeedParser.cellNumber(from: key)
                        ?? GovernedOperatorFeedParser.semanticCellNumber(from: key) else {
                        return nil
                    }
                    return RadarHeatmapCell(
                        cellNumber: number,
                        skillName: RadarHeatmapCell.skillName(for: number),
                        cellId: key,
                        score: score
                    )
                }
            }
        }

        var byNumber = Dictionary(uniqueKeysWithValues: parsed.map { ($0.cellNumber, $0) })
        for index in 0..<27 {
            if byNumber[index] == nil {
                byNumber[index] = RadarHeatmapCell(
                    cellNumber: index,
                    skillName: RadarHeatmapCell.skillName(for: index),
                    cellId: "cell-\(String(format: "%02d", index))",
                    score: 0
                )
            }
        }

        var cells = byNumber.values.sorted { $0.cellNumber < $1.cellNumber }
        let maxScore = cells.map(\.score).max() ?? 0
        if maxScore > 1 {
            cells = cells.map { cell in
                RadarHeatmapCell(
                    cellNumber: cell.cellNumber,
                    skillName: cell.skillName,
                    cellId: cell.cellId,
                    score: maxScore == 0 ? 0 : (cell.score / maxScore)
                )
            }
        }
        return RadarHeatmapResponse(cells: cells)
    }

    private static func parseCell(from row: [String: Any]) -> RadarHeatmapCell? {
        let resolvedNumber = GovernedOperatorFeedParser.int(
            in: row,
            keys: ["cell", "cellNumber", "cell_number", "index", "number"]
        ) ?? GovernedOperatorFeedParser.cellNumber(
            from: GovernedOperatorFeedParser.string(
                in: row,
                keys: ["cellId", "cell_id", "cubeAddress", "address", "id"]
            )
        ) ?? GovernedOperatorFeedParser.semanticCellNumber(
            from: GovernedOperatorFeedParser.string(
                in: row,
                keys: ["cellId", "cell_id", "cubeAddress", "address", "id"]
            )
        )

        guard let number = resolvedNumber, (0..<27).contains(number) else {
            return nil
        }

        let score = GovernedOperatorFeedParser.double(
            in: row,
            keys: ["score", "residue", "residueScore", "residue_score", "totalResidue", "total_residue", "residue_level", "weight", "value", "heat"]
        ) ?? GovernedOperatorFeedParser.double(
            in: GovernedOperatorFeedParser.dictionary(in: row, keys: ["metadata", "scores"]),
            keys: ["total", "score"]
        ) ?? 0

        let cellId = GovernedOperatorFeedParser.string(
            in: row,
            keys: ["cellId", "cell_id", "cubeAddress", "address", "id"]
        ) ?? "cell-\(String(format: "%02d", number))"

        return RadarHeatmapCell(
            cellNumber: number,
            skillName: RadarHeatmapCell.skillName(for: number),
            cellId: cellId,
            score: score
        )
    }
}

private enum BiebPresentation {
    static func cleanTitle(_ value: String?) -> String? {
        guard var text = trimmed(value) else { return nil }

        text = text.replacingOccurrences(of: "Gap proposal:", with: "", options: [.caseInsensitive])
        text = text.replacingOccurrences(of: "_", with: " ")
        text = text.replacingOccurrences(of: "-", with: " ")

        if text.hasPrefix("Signals clustered in") || text.hasPrefix("Signals in") {
            return conciseTitle(from: text)
        }

        if looksTechnical(text) {
            return nil
        }

        return sentenceCase(text)
    }

    static func conciseTitle(from hypothesis: String?) -> String? {
        guard var text = trimmed(hypothesis) else { return nil }

        text = text.replacingOccurrences(of: "Gap proposal:", with: "", options: [.caseInsensitive])
        text = text.replacingOccurrences(
            of: #"^signals?\s+(clustered\s+)?in\s+.+?\s+indicat\w*\s+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: #"^evidence\s+suggests\s+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        text = text.replacingOccurrences(
            of: #"^hypothesis:\s*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        text = humanize(text)

        for prefix in ["an ", "a ", "the ", "een ", "de ", "het "] {
            if text.lowercased().hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }

        let truncated = truncate(text, limit: 54)
        return truncated.isEmpty ? nil : sentenceCase(truncated)
    }

    static func conciseSummary(from hypothesis: String?) -> String? {
        guard var text = trimmed(hypothesis) else { return nil }
        text = text.replacingOccurrences(of: "Gap proposal:", with: "", options: [.caseInsensitive])
        text = humanize(text)
        let truncated = truncate(text, limit: 110)
        return truncated.isEmpty ? nil : sentenceCase(truncated)
    }

    static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func looksTechnical(_ value: String) -> Bool {
        let normalized = normalize(value)
        if normalized.contains("/") || normalized.contains("_") {
            return true
        }
        if normalized.range(of: #"\b(surface|engine|historical|current|emerging|clustered|signals?|cell|position|interfacekern|kerncel)\b"#, options: .regularExpression) != nil {
            return true
        }
        if !normalized.contains(" "), normalized.count > 14 {
            return true
        }
        return false
    }

    private static func humanize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "ungoverned capability", with: "mogelijke onbestuurde capaciteit", options: [.caseInsensitive])
            .replacingOccurrences(of: "research gap", with: "mogelijke onderzoekskloof", options: [.caseInsensitive])
            .replacingOccurrences(of: "knowledge gap", with: "mogelijke kenniskloof", options: [.caseInsensitive])
            .replacingOccurrences(of: "collision", with: "botsing", options: [.caseInsensitive])
            .replacingOccurrences(of: "emergence", with: "opkomend patroon", options: [.caseInsensitive])
            .replacingOccurrences(of: "interfacekern", with: "interface-kern", options: [.caseInsensitive])
    }

    private static func truncate(_ value: String, limit: Int) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.count > limit else { return trimmedValue }

        let candidate = String(trimmedValue.prefix(limit))
        if let split = candidate.lastIndex(of: " ") {
            return String(candidate[..<split]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sentenceCase(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}

struct OperatorMutationAck: Decodable, Sendable {
    let ok: Bool
    let status: String?
    let reason: String?

    init(ok: Bool = true, status: String? = nil, reason: String? = nil) {
        self.ok = ok
        self.status = status
        self.reason = reason
    }
}

private enum GovernedOperatorFeedParser {
    static func rows(from json: Any, arrayKeys: [String]) -> [[String: Any]] {
        if let array = json as? [[String: Any]] {
            return array
        }
        guard let object = json as? [String: Any] else {
            return []
        }
        for key in arrayKeys {
            if let rows = object[key] as? [[String: Any]] {
                return rows
            }
        }
        return []
    }

    static func dictionary(in row: [String: Any], keys: [String]) -> [String: Any] {
        for key in keys {
            if let dictionary = row[key] as? [String: Any] {
                return dictionary
            }
        }
        return [:]
    }

    static func string(in row: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = row[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
            if let value = row[key] as? NSNumber {
                return value.stringValue
            }
        }
        return nil
    }

    static func double(in row: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = double(row[key]) {
                return value
            }
        }
        return nil
    }

    static func int(in row: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = row[key] as? Int {
                return value
            }
            if let value = row[key] as? NSNumber {
                return value.intValue
            }
            if let value = row[key] as? String,
               let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }
        return nil
    }

    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Float:
            return Double(number)
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        case let text as String:
            return Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            return nil
        }
    }

    static func cellNumber(from value: String?) -> Int? {
        guard let value, !value.isEmpty else { return nil }
        let digits = value.compactMap { $0.isNumber ? String($0) : nil }.joined()
        guard !digits.isEmpty else { return nil }
        return Int(digits)
    }

    static func semanticCellNumber(from value: String?) -> Int? {
        guard let value, !value.isEmpty else { return nil }
        let parts = value.split(separator: "/").map(String.init)
        guard parts.count == 3 else { return nil }

        let xMap = ["trust-model": 0, "surface": 1, "architecture": 2]
        let yMap = ["internal": 0, "external": 1, "engine": 2]
        let zMap = ["historical": 0, "current": 1, "emerging": 2]

        guard let x = xMap[parts[0].lowercased()],
              let y = yMap[parts[1].lowercased()],
              let z = zMap[parts[2].lowercased()] else {
            return nil
        }

        return (z * 9) + (y * 3) + x
    }
}
