import Foundation

/// Mock gateway for development and previews — simulates gateway responses
@MainActor
final class MockGateway {

    func simulateResponse(for text: String) async -> [IncomingMessage] {
        let lower = text.lowercased()

        // Simulate some network delay
        try? await Task.sleep(for: .milliseconds(300))

        if lower.contains("email") || lower.contains("mail") || lower.contains("inbox") {
            return [
                .consentRequest(
                    id: "consent-\(UUID().uuidString.prefix(8))",
                    tool: "gmail_read",
                    risk: .orange,
                    reason: "Mag ik uw inbox lezen?",
                    params: ["query": "is:unread"],
                    timestamp: Date()
                )
            ]
        }

        if lower.contains("agenda") || lower.contains("calendar") || lower.contains("afspraken") {
            return [
                .consentRequest(
                    id: "consent-\(UUID().uuidString.prefix(8))",
                    tool: "calendar_read",
                    risk: .orange,
                    reason: "Mag ik uw agenda raadplegen?",
                    params: nil,
                    timestamp: Date()
                )
            ]
        }

        if lower.contains("verwijder") || lower.contains("delete") || lower.contains("rm ") {
            return [
                .blocked(
                    tool: "exec",
                    risk: "red",
                    reason: "Destructieve shell commands zijn geblokkeerd op dit trust level.",
                    timestamp: Date()
                )
            ]
        }

        if lower.contains("status") || lower.contains("huis") {
            return [
                .response(
                    text: "Het huis is in orde, meneer. Alle systemen functioneren naar behoren.",
                    agent: "jeeves",
                    cost: 0.01,
                    timestamp: Date()
                )
            ]
        }

        if lower.contains("weer") || lower.contains("weather") {
            return [
                .response(
                    text: "Het is momenteel 14 graden met bewolking, meneer. Een paraplu zou wellicht verstandig zijn.",
                    agent: "jeeves",
                    cost: 0.01,
                    timestamp: Date()
                )
            ]
        }

        return [
            .response(
                text: "Tot uw dienst, meneer.",
                agent: "jeeves",
                cost: 0.01,
                timestamp: Date()
            )
        ]
    }

    /// Simulate approving a consent request
    func simulateConsentApproval(tool: String) async -> IncomingMessage {
        try? await Task.sleep(for: .milliseconds(500))

        switch tool {
        case "gmail_read":
            return .response(
                text: "U heeft 3 ongelezen berichten. Eén van uw bank betreffende een transactie, één van uw collega over het project, en een nieuwsbrief.",
                agent: "jeeves",
                cost: 0.02,
                timestamp: Date()
            )
        case "calendar_read":
            return .response(
                text: "U heeft vandaag twee afspraken: een vergadering om 14:00 en een diner om 19:30.",
                agent: "jeeves",
                cost: 0.02,
                timestamp: Date()
            )
        default:
            return .response(
                text: "De actie is uitgevoerd, meneer.",
                agent: "jeeves",
                cost: 0.01,
                timestamp: Date()
            )
        }
    }

    /// Mock status
    func mockStatus() -> GatewayStatus {
        GatewayStatus(
            budget: BudgetStatus(
                daily: BudgetPeriod(used: 0.42, limit: 1.00),
                weekly: BudgetPeriod(used: 2.10, limit: 5.00),
                monthly: BudgetPeriod(used: 8.50, limit: 15.00),
                hardStop: false
            ),
            consent: ConsentStatus(pending: 0, active: 2),
            killSwitch: KillSwitchStatus(active: false),
            channels: [
                ChannelInfo(id: "ios-app", trust: .trusted, connected: true),
                ChannelInfo(id: "webchat", trust: .trusted, connected: true),
                ChannelInfo(id: "whatsapp", trust: .trusted, connected: false),
                ChannelInfo(id: "ussd", trust: .semi, connected: false),
                ChannelInfo(id: "telegram", trust: .untrusted, connected: false)
            ]
        )
    }

    /// Mock audit entries
    func mockAuditEntries() -> [AuditEntry] {
        let now = Date()
        return [
            AuditEntry(id: "a1", timestamp: now.addingTimeInterval(-120), tool: "gmail_read", status: .allowed, channel: "ios-app", cost: 0.02),
            AuditEntry(id: "a2", timestamp: now.addingTimeInterval(-180), tool: "gmail_read", status: .consentRequested, channel: "ios-app"),
            AuditEntry(id: "a3", timestamp: now.addingTimeInterval(-1200), tool: "exec", status: .allowed, channel: "webchat", reason: "git log --oneline -5", cost: 0.01),
            AuditEntry(id: "a4", timestamp: now.addingTimeInterval(-3600), tool: "file_write", status: .blocked, channel: "telegram", reason: "Untrusted channel"),
            AuditEntry(id: "a5", timestamp: now.addingTimeInterval(-4500), tool: "calendar_read", status: .consentRequested, channel: "whatsapp"),
            AuditEntry(id: "a6", timestamp: now.addingTimeInterval(-7200), tool: "web_fetch", status: .allowed, channel: "ios-app", cost: 0.01),
            AuditEntry(id: "a7", timestamp: now.addingTimeInterval(-10800), tool: "exec", status: .blocked, channel: "telegram", reason: "Untrusted channel"),
        ]
    }
}
