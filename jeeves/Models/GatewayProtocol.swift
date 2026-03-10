import Foundation

// MARK: - Outgoing messages (app → gateway)

struct OutgoingMessage: Codable, Sendable {
    var type: String
    var channel: String
    var channelId: String
    var sender: String
    var text: String
    var timestamp: String

    static func chat(text: String, channelId: String) -> OutgoingMessage {
        OutgoingMessage(
            type: "message",
            channel: "ios-app",
            channelId: channelId,
            sender: "owner",
            text: text,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
    }
}

struct ConsentResponseMessage: Codable, Sendable {
    var type: String = "consent_response"
    var id: String
    var approved: Bool
}

// MARK: - Incoming messages (gateway → app)

enum IncomingMessage: Sendable {
    case response(text: String, agent: String, cost: Double?, timestamp: Date)
    case consentRequest(id: String, tool: String, risk: RiskLevel, reason: String, params: [String: String]?, timestamp: Date)
    case blocked(tool: String, risk: String, reason: String, timestamp: Date)
    case status(GatewayStatus)
    case streamDelta(text: String, agent: String)
    case streamEnd(text: String, agent: String, cost: Double?, timestamp: Date)
    case error(message: String)
}

// MARK: - JSON decoding

struct IncomingMessageDecoder {
    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    static func decode(from data: Data) -> IncomingMessage? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Some gateway chat handlers return compact payloads without a "type" field.
        // Accept common plain-chat shapes so successful 2xx responses are never dropped.
        if json["type"] == nil {
            if let ok = json["ok"] as? Bool, ok {
                return .response(
                    text: (json["message"] as? String)
                        ?? (json["status"] as? String)
                        ?? "Bericht ontvangen. Antwoordverwerking gestart.",
                    agent: json["agent"] as? String ?? "gateway",
                    cost: nil,
                    timestamp: Date()
                )
            }
            if let text = (json["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return .response(
                    text: text,
                    agent: json["agent"] as? String ?? "jeeves",
                    cost: json["cost"] as? Double,
                    timestamp: Date()
                )
            }
            if let text = (json["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return .response(
                    text: text,
                    agent: json["agent"] as? String ?? "jeeves",
                    cost: json["cost"] as? Double,
                    timestamp: Date()
                )
            }
            if let error = (json["error"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !error.isEmpty {
                return .error(message: error)
            }
            return nil
        }

        guard let type = json["type"] as? String else { return nil }

        let timestamp = (json["timestamp"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date()

        switch type {
        case "response":
            return .response(
                text: json["text"] as? String ?? "",
                agent: json["agent"] as? String ?? "jeeves",
                cost: json["cost"] as? Double,
                timestamp: timestamp
            )

        case "consent_request":
            guard let id = json["id"] as? String,
                  let tool = json["tool"] as? String,
                  let riskStr = json["risk"] as? String,
                  let risk = RiskLevel(rawValue: riskStr) else {
                return nil
            }
            return .consentRequest(
                id: id,
                tool: tool,
                risk: risk,
                reason: json["reason"] as? String ?? "",
                params: json["params"] as? [String: String],
                timestamp: timestamp
            )

        case "blocked":
            return .blocked(
                tool: json["tool"] as? String ?? "",
                risk: json["risk"] as? String ?? "red",
                reason: json["reason"] as? String ?? "",
                timestamp: timestamp
            )

        case "status":
            return decodeStatus(json)

        case "stream_delta":
            return .streamDelta(
                text: json["text"] as? String ?? "",
                agent: json["agent"] as? String ?? "jeeves"
            )

        case "stream_end":
            return .streamEnd(
                text: json["text"] as? String ?? "",
                agent: json["agent"] as? String ?? "jeeves",
                cost: json["cost"] as? Double,
                timestamp: timestamp
            )

        default:
            return nil
        }
    }

    private static func decodeStatus(_ json: [String: Any]) -> IncomingMessage? {
        guard let budgetDict = json["budget"] as? [String: Any] else { return nil }

        func parsePeriod(_ dict: [String: Any]?) -> BudgetPeriod {
            BudgetPeriod(
                used: dict?["used"] as? Double ?? 0,
                limit: dict?["limit"] as? Double ?? 0
            )
        }

        let budget = BudgetStatus(
            daily: parsePeriod(budgetDict["daily"] as? [String: Any]),
            weekly: parsePeriod(budgetDict["weekly"] as? [String: Any]),
            monthly: parsePeriod(budgetDict["monthly"] as? [String: Any]),
            hardStop: budgetDict["hardStop"] as? Bool ?? false
        )

        let consentDict = json["consent"] as? [String: Any]
        let consent = ConsentStatus(
            pending: consentDict?["pending"] as? Int ?? 0,
            active: consentDict?["active"] as? Int ?? 0
        )

        let killDict = json["killSwitch"] as? [String: Any]
        let killSwitch = KillSwitchStatus(active: killDict?["active"] as? Bool ?? false)

        let channelsArray = json["channels"] as? [[String: Any]] ?? []
        let channels = channelsArray.compactMap { ch -> ChannelInfo? in
            guard let id = ch["id"] as? String,
                  let trustStr = ch["trust"] as? String,
                  let trust = TrustLevel(rawValue: trustStr) else { return nil }
            return ChannelInfo(id: id, trust: trust, connected: ch["connected"] as? Bool ?? false)
        }

        return .status(GatewayStatus(
            budget: budget,
            consent: consent,
            killSwitch: killSwitch,
            channels: channels
        ))
    }
}
