import Foundation
import SwiftUI

protocol JeevesKanaalAPIClient: Sendable {
    func fetchAgentProposals() async throws -> [Proposal]
    func fetchJacobMeaning() async throws -> [JeevesKanaalMeaningItem]
    func fetchConductorState() async throws -> ConductorState
    func fetchRadarDiscoveries() async throws -> [RadarDiscoveryCandidate]
    func decideProposal(proposalId: String, decision: String) async throws -> OperatorMutationAck
}

struct JeevesKanaalMeaningItem: Decodable, Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let summary: String
    let impactScore: Double?

    init(id: String, title: String, summary: String, impactScore: Double?) {
        self.id = id
        self.title = title
        self.summary = summary
        self.impactScore = impactScore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .proposalId)
            ?? container.decodeIfPresent(String.self, forKey: .decisionId)
            ?? UUID().uuidString
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .label)
            ?? container.decodeIfPresent(String.self, forKey: .headline)
            ?? "Betekenisvolle verschuiving"
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .meaning)
            ?? container.decodeIfPresent(String.self, forKey: .explanation)
            ?? container.decodeIfPresent(String.self, forKey: .description)
            ?? title
        impactScore = try container.decodeIfPresent(Double.self, forKey: .impactScore)
            ?? container.decodeIfPresent(Double.self, forKey: .score)
    }

    init?(json: Any) {
        guard let dictionary = json as? [String: Any] else { return nil }
        let resolvedId = Self.string(in: dictionary, keys: ["id", "proposalId", "proposal_id", "decisionId", "decision_id"])
            ?? UUID().uuidString
        let resolvedTitle = Self.string(in: dictionary, keys: ["title", "label", "headline", "name"])
            ?? "Betekenisvolle verschuiving"
        let resolvedSummary = Self.string(in: dictionary, keys: ["summary", "meaning", "explanation", "description"])
            ?? resolvedTitle
        let resolvedScore = Self.double(in: dictionary, keys: ["impactScore", "impact_score", "score"])
        self.init(id: resolvedId, title: resolvedTitle, summary: resolvedSummary, impactScore: resolvedScore)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case proposalId
        case decisionId
        case title
        case label
        case headline
        case summary
        case meaning
        case explanation
        case description
        case impactScore
        case score
    }

    private static func string(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func double(in dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            switch dictionary[key] {
            case let value as Double:
                return value
            case let value as Int:
                return Double(value)
            case let value as String:
                if let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    return parsed
                }
            default:
                continue
            }
        }
        return nil
    }
}

enum JeevesKanaalAuthor: String, Sendable {
    case operatorUser
    case jeeves
}

struct JeevesKanaalMessage: Identifiable, Sendable, Equatable {
    let id: UUID
    let author: JeevesKanaalAuthor
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), author: JeevesKanaalAuthor, text: String, timestamp: Date = Date()) {
        self.id = id
        self.author = author
        self.text = text
        self.timestamp = timestamp
    }
}

enum JeevesKanaalIntent: Equatable, Sendable {
    case pendingApprovals
    case jacobMeaning
    case status
    case radar
    case approve(reference: String)
    case dismiss(reference: String)
    case unknown
}

@MainActor
final class JeevesKanaalViewModel: ObservableObject {
    @Published var messages: [JeevesKanaalMessage]
    @Published var draft: String = ""
    @Published var isSending = false

    private let injectedClient: (any JeevesKanaalAPIClient)?
    private var lastOpenProposals: [Proposal] = []

    init(apiClient: (any JeevesKanaalAPIClient)? = nil) {
        self.injectedClient = apiClient
        self.messages = [
            JeevesKanaalMessage(
                author: .jeeves,
                text: "Ik luister naar opdrachten voor OpenClashd. Vraag wat op u wacht, wat Jacob zag, de status, toon radar, of geef een beslissing."
            )
        ]
    }

    func sendCurrentMessage(using gateway: GatewayManager) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        await send(text, using: gateway)
    }

    func send(_ text: String, using gateway: GatewayManager? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(JeevesKanaalMessage(author: .operatorUser, text: trimmed))

        let intent = Self.parseIntent(from: trimmed)
        guard intent != .unknown else {
            messages.append(
                JeevesKanaalMessage(
                    author: .jeeves,
                    text: "Ik begrijp deze opdracht nog niet. U kunt vragen wat op u wacht, wat Jacob zag, de status opvragen, radar tonen, of een voorstel goed- of afwijzen."
                )
            )
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            let reply = try await handle(intent: intent, using: gateway)
            messages.append(JeevesKanaalMessage(author: .jeeves, text: reply))
        } catch {
            let message: String
            if let localized = error as? LocalizedError,
               let description = localized.errorDescription,
               !description.isEmpty {
                message = description
            } else {
                message = "Ik kan OpenClashd nu niet bereiken."
            }
            messages.append(JeevesKanaalMessage(author: .jeeves, text: message))
        }
    }

    static func parseIntent(from text: String) -> JeevesKanaalIntent {
        let normalized = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.contains("wat wacht op mij") {
            return .pendingApprovals
        }
        if normalized.contains("wat heeft jacob gezien") {
            return .jacobMeaning
        }
        if normalized.contains("wat is de status") {
            return .status
        }
        if normalized.contains("toon radar") {
            return .radar
        }
        if normalized.hasPrefix("keur goed ") {
            let reference = String(normalized.dropFirst("keur goed ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return reference.isEmpty ? .unknown : .approve(reference: reference)
        }
        if normalized.hasPrefix("wijs af ") {
            let reference = String(normalized.dropFirst("wijs af ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return reference.isEmpty ? .unknown : .dismiss(reference: reference)
        }
        return .unknown
    }

    static func formatPendingProposals(_ proposals: [Proposal]) -> String {
        let openProposals = Self.openProposals(from: proposals)
        guard !openProposals.isEmpty else {
            return "Er wachten nu geen proposals op uw oordeel."
        }

        var lines = ["Er zijn \(openProposals.count) proposals die uw oordeel vragen."]
        let rankedScores = openProposals
            .compactMap(\.priorityScore)
            .sorted(by: >)
            .prefix(3)
            .map(Self.scoreText)

        if !rankedScores.isEmpty {
            let joined = rankedScores.joined(separator: ", ")
            lines.append("De sterkste signalen scoren \(joined).")
        }

        let previews = openProposals.prefix(2).map { proposal in
            "\(proposal.proposalId) · \(Self.cleanLine(proposal.title))"
        }
        if !previews.isEmpty {
            lines.append(contentsOf: previews)
        }

        return lines.joined(separator: "\n")
    }

    static func formatStatus(_ state: ConductorState) -> String {
        let budget = Self.decimalFormatter.string(from: NSNumber(value: state.budget.remaining))
            ?? String(format: "%.2f", state.budget.remaining)
        let killSwitch = state.killSwitch.active ? "actief" : "uit"
        return [
            "Status: \(state.cycleStage).",
            "Budget resterend: \(budget).",
            "Kill switch: \(killSwitch).",
            "Open consent: \(state.consentPending)."
        ].joined(separator: "\n")
    }

    private func handle(intent: JeevesKanaalIntent, using gateway: GatewayManager?) async throws -> String {
        switch intent {
        case .unknown:
            return "Ik begrijp deze opdracht nog niet."
        case .pendingApprovals:
            let client = try await resolveClient(using: gateway)
            let proposals = try await client.fetchAgentProposals()
            lastOpenProposals = Self.openProposals(from: proposals)
            return Self.formatPendingProposals(proposals)
        case .jacobMeaning:
            let client = try await resolveClient(using: gateway)
            let items = try await client.fetchJacobMeaning().sorted {
                ($0.impactScore ?? 0) > ($1.impactScore ?? 0)
            }
            guard !items.isEmpty else {
                return "Jacob meldt nu geen nieuwe betekenisvolle verschuivingen."
            }
            let lines = items.prefix(3).map { item in
                let score = item.impactScore.map { " (\(Self.scoreText($0)))" } ?? ""
                return "\(Self.cleanLine(item.title))\(score)\n\(Self.cleanLine(item.summary))"
            }
            return "Jacob ziet \(items.count) betekenisvolle verschuivingen.\n" + lines.joined(separator: "\n\n")
        case .status:
            let client = try await resolveClient(using: gateway)
            let state = try await client.fetchConductorState()
            return Self.formatStatus(state)
        case .radar:
            let client = try await resolveClient(using: gateway)
            let discoveries = try await client.fetchRadarDiscoveries().sorted { $0.candidateScore > $1.candidateScore }
            guard !discoveries.isEmpty else {
                return "Er zijn nu geen recente radarontdekkingen."
            }
            let lines = discoveries.prefix(3).map { candidate in
                let summary = Self.cleanLine(candidate.explanation).nilIfEmpty
                    ?? Self.cleanLine(candidate.candidateType)
                return "\(summary) (\(Self.scoreText(candidate.candidateScore)))"
            }
            return "Ik zie \(discoveries.count) recente ontdekkingen.\n" + lines.joined(separator: "\n")
        case .approve(let reference):
            let client = try await resolveClient(using: gateway)
            let proposal = try await resolveProposal(reference: reference, client: client)
            _ = try await client.decideProposal(proposalId: proposal.proposalId, decision: "approve")
            lastOpenProposals.removeAll { $0.proposalId == proposal.proposalId }
            return "Goedgekeurd. Jacob registreert de verschuiving."
        case .dismiss(let reference):
            let client = try await resolveClient(using: gateway)
            let proposal = try await resolveProposal(reference: reference, client: client)
            _ = try await client.decideProposal(proposalId: proposal.proposalId, decision: "dismiss")
            lastOpenProposals.removeAll { $0.proposalId == proposal.proposalId }
            return "Afgewezen. Het voorstel blijft buiten uitvoering."
        }
    }

    private func resolveClient(using gateway: GatewayManager?) async throws -> any JeevesKanaalAPIClient {
        if let injectedClient {
            return injectedClient
        }

        guard let gateway else {
            throw OperatorSurfacesError(message: "Ik kan OpenClashd nu niet bereiken.")
        }
        guard let api = await gateway.makeOperatorSurfacesAPI() else {
            throw OperatorSurfacesError(message: "Ik kan OpenClashd nu niet bereiken.")
        }
        return api
    }

    private func resolveProposal(reference: String, client: any JeevesKanaalAPIClient) async throws -> Proposal {
        let proposals = try await client.fetchAgentProposals()
        let openProposals = Self.openProposals(from: proposals)
        lastOpenProposals = openProposals

        if let match = Self.matchProposal(reference: reference, in: openProposals) {
            return match
        }

        throw OperatorSurfacesError(message: "Ik kan dit proposal niet plaatsen. Vraag eerst wat op u wacht of gebruik een concreet id.")
    }

    private static func matchProposal(reference: String, in proposals: [Proposal]) -> Proposal? {
        let normalized = reference
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        switch normalized {
        case "eerste", "1":
            return proposals.first
        case "tweede", "2":
            return proposals.dropFirst().first
        case "derde", "3":
            return proposals.dropFirst(2).first
        case "laatste":
            return proposals.last
        default:
            return proposals.first { proposal in
                proposal.proposalId.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .lowercased() == normalized
            }
        }
    }

    private static func openProposals(from proposals: [Proposal]) -> [Proposal] {
        proposals.filter { proposal in
            let status = proposal.status.lowercased()
            return ["pending", "proposed", "awaiting_review", "awaitingreview"].contains(status)
        }
    }

    private static func scoreText(_ score: Double) -> String {
        String(format: "%.2f", score)
    }

    private static func cleanLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
