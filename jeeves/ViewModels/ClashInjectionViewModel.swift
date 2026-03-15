import Foundation
import Observation

@MainActor
@Observable
final class ClashInjectionViewModel {
    var readiness: SystemReadinessSnapshot?
    var computer: Clashd27ComputerSnapshot?
    var session: InjectionSessionSnapshot?
    var cycle: InjectionCycleSnapshot?
    var findings: [InjectionFindingSnapshot] = []
    var consequences: [InjectionConsequenceSnapshot] = []
    var residue: [InjectionResidueSnapshot] = []
    var residueMemory: [TuringResidueMemoryEntrySnapshot] = []
    var selectedTargetId: String?
    var selectedIntent: String = "inspect"
    var notes: String = ""
    var isLoading = false
    var isStarting = false
    var errorText: String?

    func refresh(gateway: GatewayManager) async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let client = try await makeClient(gateway: gateway)
            async let readinessTask = client.fetchReadiness()
            async let computerTask = client.fetchComputer()
            let readiness = try await readinessTask
            let computer = try await computerTask
            self.readiness = readiness
            self.computer = computer
            if selectedTargetId == nil {
                selectedTargetId = readiness.targetOptions.first(where: { $0.status == "ready" })?.id
            }

            if let sessionId = session?.id {
                try await refreshSession(client: client, sessionId: sessionId)
                errorText = nil
                return
            }

            let sessions = try await client.fetchSessions()
            if let latest = sessions.first {
                try await refreshSession(client: client, sessionId: latest.id)
            }
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    func startInvestigation(gateway: GatewayManager) async {
        if isStarting { return }
        isStarting = true
        defer { isStarting = false }

        do {
            let client = try await makeClient(gateway: gateway)
            if readiness == nil {
                readiness = try await client.fetchReadiness()
            }
            guard let target = readiness?.targetOptions.first(where: { $0.id == selectedTargetId }) else {
                errorText = "Kies eerst een doel om te onderzoeken."
                return
            }

            let request = ClashInjectionCommandRequest(
                target: ClashInjectionTargetRequest(
                    id: target.id,
                    type: target.type,
                    location: target.location,
                    label: target.label
                ),
                intent: selectedIntent,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            let session = try await client.startCommand(request)
            self.session = session
            self.cycle = session.cycle
            self.computer = session.computer
            self.findings = []
            self.consequences = []
            self.residue = []
            self.residueMemory = session.residueMemory
            self.errorText = nil

            await pollUntilSettled(client: client, sessionId: session.id)
        } catch {
            errorText = error.localizedDescription
        }
    }

    var availableTargets: [InjectionTargetOption] {
        readiness?.targetOptions ?? []
    }

    var demoTarget: InjectionTargetOption? {
        availableTargets.first(where: { $0.mode == "demo" && $0.status == "ready" })
    }

    func startDemoInvestigation(gateway: GatewayManager) async {
        guard let demoTarget else {
            errorText = "De demo-investigatie is nog niet beschikbaar."
            return
        }

        let previousTarget = selectedTargetId
        let previousIntent = selectedIntent
        let previousNotes = notes

        selectedTargetId = demoTarget.id
        selectedIntent = "investigate"
        notes = "Deterministic demo investigation"
        await startInvestigation(gateway: gateway)

        if session == nil {
            selectedTargetId = previousTarget
            selectedIntent = previousIntent
            notes = previousNotes
        }
    }

    private func pollUntilSettled(client: ClashInjectionClient, sessionId: String) async {
        for _ in 0..<30 {
            do {
                try await refreshSession(client: client, sessionId: sessionId)
                guard let session else { return }
                if session.status == "completed" || session.status == "failed" {
                    return
                }
            } catch {
                errorText = error.localizedDescription
                return
            }

            try? await Task.sleep(nanoseconds: 350_000_000)
        }
    }

    private func refreshSession(client: ClashInjectionClient, sessionId: String) async throws {
        async let sessionTask = client.fetchSession(id: sessionId)
        async let cycleTask = client.fetchCycle(id: sessionId)
        async let findingsTask = client.fetchFindings(id: sessionId)
        async let residueTask = client.fetchResidue(id: sessionId)
        async let computerTask = client.fetchComputer()

        let session = try await sessionTask
        let cycle = try await cycleTask
        let (findings, consequences) = try await findingsTask
        let residue = try await residueTask
        let computer = try await computerTask

        self.session = session
        self.cycle = cycle
        self.findings = findings
        self.consequences = consequences
        self.residue = residue
        self.residueMemory = session.residueMemory
        self.computer = session.computer ?? computer
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
