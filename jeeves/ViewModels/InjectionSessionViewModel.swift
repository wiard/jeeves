import Foundation
import Observation

@MainActor
@Observable
final class InjectionSessionViewModel {
    let sessionId: String

    var messages: [InjectionChatMessage] = []
    var findings: [InjectionFindingSnapshot] = []
    var session: InjectionSessionSnapshot?
    var isSending = false
    var isLoading = false
    var errorText: String?

    init(sessionId: String) {
        self.sessionId = sessionId
    }

    func load(gateway: GatewayManager) async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let client = try await makeClient(gateway: gateway)
            let session = try await client.fetchSession(id: sessionId)
            self.session = session
            let (findings, _) = try await client.fetchFindings(id: sessionId)
            self.findings = findings
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    func send(_ text: String, gateway: GatewayManager) async {
        if isSending { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(InjectionChatMessage(role: .operator_, text: trimmed))
        isSending = true
        defer { isSending = false }

        do {
            let client = try await makeClient(gateway: gateway)
            let envelope = try await client.sendConversation(sessionId: sessionId, message: trimmed)
            messages.append(InjectionChatMessage(reply: envelope.reply))
            if let newFindings = envelope.findings {
                for f in newFindings where !findings.contains(where: { $0.id == f.id }) {
                    findings.append(f)
                }
            }
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func makeClient(gateway: GatewayManager) async throws -> ClashInjectionClient {
        let endpoint = await gateway.resolveEndpoint()
        guard let token = endpoint.token, !token.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        let builder = AuthorizedRequestBuilder(host: endpoint.host, port: endpoint.port, token: token)
        return ClashInjectionClient(builder: builder)
    }
}
