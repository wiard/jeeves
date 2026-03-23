import Foundation

struct ChipRun: Identifiable, Sendable {
    let id: String
    let status: String
    let designName: String?
    let platform: String?
    let startedAtIso: String?
    let completedAtIso: String?
    let criticalPathCount: Int?
    let blockingPathCount: Int?
    let improvementDelta: Double?
    let summary: String?

    static func decodeMany(from data: Data) throws -> [ChipRun] {
        let rows = try ChipPayload.array(from: data, candidateKeys: ["runs", "items", "data", "recent"])
        return rows.compactMap(ChipRun.init(json:))
    }

    private init?(json: [String: Any]) {
        let startedAtIso = ChipPayload.string(in: json, keys: ["startedAtIso", "started_at", "createdAtIso", "created_at", "timestamp"])
        let completedAtIso = ChipPayload.string(in: json, keys: ["completedAtIso", "completed_at", "finishedAtIso", "finished_at", "endedAtIso", "ended_at"])
        let summary = ChipPayload.string(in: json, keys: ["summary", "headline", "description", "result"])
        let resolvedId = ChipPayload.string(in: json, keys: ["id", "runId", "run_id", "jobId", "job_id"])
            ?? startedAtIso
            ?? summary

        guard let resolvedId, !resolvedId.isEmpty else { return nil }

        id = resolvedId
        status = ChipPayload.string(in: json, keys: ["status", "state", "phase"]) ?? "unknown"
        designName = ChipPayload.string(in: json, keys: ["designName", "design_name", "design", "chip", "target"])
        platform = ChipPayload.string(in: json, keys: ["platform", "platform_name", "targetPlatform", "target_platform"])
        self.startedAtIso = startedAtIso
        self.completedAtIso = completedAtIso
        criticalPathCount = ChipPayload.int(in: json, keys: ["criticalPathCount", "critical_path_count", "criticalPaths", "critical_paths"])
        blockingPathCount = ChipPayload.int(in: json, keys: ["blockingPathCount", "blocking_path_count", "blockingCount", "blocking_count", "violatingPathCount", "violating_path_count"])
        improvementDelta = ChipPayload.double(in: json, keys: ["improvementDelta", "improvement_delta", "delta", "slackImprovement", "slack_improvement"])
        self.summary = summary
    }
}

struct ChipActionRequest: Encodable, Sendable {
    let pathKey: String
    let classification: String
    let proposedAction: String
    let runId: String?
    let design: String?
    let platform: String?

    enum CodingKeys: String, CodingKey {
        case pathKey = "path_key"
        case proposedAction = "proposed_action"
        case runId = "run_id"
        case design
        case platform
    }
}

struct ChipOutcome: Identifiable, Sendable {
    let id: String
    let runId: String?
    let pathKey: String
    let classification: String
    let blocking: Bool
    let severity: Double?
    let slack: Double?
    let suggestedAction: String?
    let rationale: String?
    let observedAtIso: String?

    static func decodeMany(from data: Data) throws -> [ChipOutcome] {
        let rows = try ChipPayload.array(from: data, candidateKeys: ["outcomes", "items", "data", "recent"])
        return rows.compactMap(ChipOutcome.init(json:))
    }

    private init?(json: [String: Any]) {
        let pathKey = ChipPayload.string(in: json, keys: ["pathKey", "path_key", "path", "criticalPath", "critical_path"]) ?? "unknown-path"
        let observedAtIso = ChipPayload.string(in: json, keys: ["observedAtIso", "observed_at", "createdAtIso", "created_at", "timestamp"])
        let classification = ChipPayload.string(in: json, keys: ["classification", "violationType", "violation_type", "type"]) ?? "unclassified"
        let resolvedId = ChipPayload.string(in: json, keys: ["id", "outcomeId", "outcome_id"])
            ?? "\(pathKey)|\(observedAtIso ?? classification)"

        id = resolvedId
        runId = ChipPayload.string(in: json, keys: ["runId", "run_id", "jobId", "job_id"])
        self.pathKey = pathKey
        self.classification = classification
        slack = ChipPayload.double(in: json, keys: ["slack", "worstSlack", "worst_slack", "currentSlack", "current_slack"])
        severity = ChipPayload.double(in: json, keys: ["severity", "score", "impactScore", "impact_score"])
        blocking = ChipPayload.bool(in: json, keys: ["blocking", "isBlocking", "is_blocking"])
            ?? ((slack ?? 0) < 0)
        suggestedAction = ChipPayload.string(in: json, keys: ["suggestedAction", "suggested_action", "action", "repairClass", "repair_class"])
        rationale = ChipPayload.string(in: json, keys: ["rationale", "reason", "why", "summary", "description"])
        self.observedAtIso = observedAtIso
    }
}

struct ChipHypothesis: Identifiable, Sendable {
    let id: String
    let runId: String?
    let pathKey: String?
    let suggestedAction: String
    let rationale: String?
    let confidence: Double?
    let createdAtIso: String?
    let learningContext: String?

    static func decodeMany(from data: Data) throws -> [ChipHypothesis] {
        let rows = try ChipPayload.array(from: data, candidateKeys: ["hypotheses", "items", "data", "recent"])
        return rows.compactMap(ChipHypothesis.init(json:))
    }

    private init?(json: [String: Any]) {
        let suggestedAction = ChipPayload.string(in: json, keys: ["suggestedAction", "suggested_action", "action", "recommendation", "proposal"])
        let rationale = ChipPayload.string(in: json, keys: ["rationale", "reason", "why", "summary", "description", "statement"])
        let resolvedId = ChipPayload.string(in: json, keys: ["id", "hypothesisId", "hypothesis_id"])
            ?? suggestedAction
            ?? rationale

        guard let resolvedId, !resolvedId.isEmpty else { return nil }

        id = resolvedId
        runId = ChipPayload.string(in: json, keys: ["runId", "run_id", "jobId", "job_id"])
        pathKey = ChipPayload.string(in: json, keys: ["pathKey", "path_key", "path"])
        self.suggestedAction = suggestedAction ?? "Observeer dit pad opnieuw"
        self.rationale = rationale
        confidence = ChipPayload.double(in: json, keys: ["confidence", "score", "priority", "priority_score"])
        createdAtIso = ChipPayload.string(in: json, keys: ["createdAtIso", "created_at", "timestamp"])
        learningContext = ChipPayload.string(in: json, keys: ["learningContext", "learning_context", "memoryContext", "memory_context", "context"])
    }
}

struct ChipSummary: Sendable {
    let headline: String?
    let runCount: Int?
    let blockingPathCount: Int?
    let criticalPathCount: Int?
    let improvedPathCount: Int?
    let bestNextAction: String?
    let lastUpdatedIso: String?

    static func decode(from data: Data) throws -> ChipSummary {
        let object = try ChipPayload.object(from: data, candidateKeys: ["summary", "item", "data"])
        return ChipSummary(json: object)
    }

    private init(json: [String: Any]) {
        headline = ChipPayload.string(in: json, keys: ["headline", "summary", "learningSummary", "learning_summary", "description"])
        runCount = ChipPayload.int(in: json, keys: ["runCount", "run_count", "recentRuns", "recent_runs"])
        blockingPathCount = ChipPayload.int(in: json, keys: ["blockingPathCount", "blocking_path_count", "blockingCount", "blocking_count"])
        criticalPathCount = ChipPayload.int(in: json, keys: ["criticalPathCount", "critical_path_count", "criticalCount", "critical_count"])
        improvedPathCount = ChipPayload.int(in: json, keys: ["improvedPathCount", "improved_path_count", "improvedCount", "improved_count"])
        bestNextAction = ChipPayload.string(in: json, keys: ["bestNextAction", "best_next_action", "recommendedNextAction", "recommended_next_action", "nextAction"])
        lastUpdatedIso = ChipPayload.string(in: json, keys: ["lastUpdatedIso", "last_updated_iso", "updatedAtIso", "updated_at", "timestamp"])
    }
}

private enum ChipPayload {
    static func array(from data: Data, candidateKeys: [String]) throws -> [[String: Any]] {
        let json = try JSONSerialization.jsonObject(with: data)

        if let direct = json as? [[String: Any]] {
            return direct
        }

        if let object = json as? [String: Any] {
            for key in candidateKeys {
                if let array = object[key] as? [[String: Any]] {
                    return array
                }
            }

            if let result = object["result"] as? [String: Any] {
                for key in candidateKeys {
                    if let array = result[key] as? [[String: Any]] {
                        return array
                    }
                }
            }
        }

        throw URLError(.cannotParseResponse)
    }

    static func object(from data: Data, candidateKeys: [String]) throws -> [String: Any] {
        let json = try JSONSerialization.jsonObject(with: data)

        if let direct = json as? [String: Any] {
            for key in candidateKeys {
                if let object = direct[key] as? [String: Any] {
                    return object
                }
            }

            if let result = direct["result"] as? [String: Any] {
                for key in candidateKeys {
                    if let object = result[key] as? [String: Any] {
                        return object
                    }
                }
            }

            return direct
        }

        throw URLError(.cannotParseResponse)
    }

    static func string(in object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let value = object[key] else { continue }
            switch value {
            case let string as String:
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            case let number as NSNumber:
                return number.stringValue
            default:
                continue
            }
        }
        return nil
    }

    static func int(in object: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            guard let value = object[key] else { continue }
            switch value {
            case let int as Int:
                return int
            case let number as NSNumber:
                return number.intValue
            case let string as String:
                if let int = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    return int
                }
            case let array as [Any]:
                return array.count
            default:
                continue
            }
        }
        return nil
    }

    static func double(in object: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            guard let value = object[key] else { continue }
            switch value {
            case let double as Double:
                return double
            case let float as Float:
                return Double(float)
            case let int as Int:
                return Double(int)
            case let number as NSNumber:
                return number.doubleValue
            case let string as String:
                if let double = Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    return double
                }
            default:
                continue
            }
        }
        return nil
    }

    static func bool(in object: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            guard let value = object[key] else { continue }
            switch value {
            case let bool as Bool:
                return bool
            case let number as NSNumber:
                return number.boolValue
            case let string as String:
                switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "yes", "1", "blocking":
                    return true
                case "false", "no", "0":
                    return false
                default:
                    continue
                }
            default:
                continue
            }
        }
        return nil
    }
}
