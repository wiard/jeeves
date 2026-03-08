import SwiftUI

struct LobbyView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @State private var showOrangeConfirm = false
    @State private var pendingDecision: (proposalId: String, decision: String)?
    @State private var decidingProposalId: String?
    @State private var decisionErrorMessage: String?
    @State private var showDecisionError = false
    @State private var showActionReceipt = false
    @State private var selectedDecision: DecidedProposal?
    @State private var selectedKnowledgeObjectId: String?
    @State private var knowledgeGraphData: KnowledgeGraphResponse?
    @State private var showKnowledgeGraph = false
    @State private var loadingKnowledgeGraph = false
    @State private var decidingExtensionId: String?
    @State private var loadingManifestExtensionId: String?
    @State private var extensionActionErrorMessage: String?
    @State private var showExtensionActionError = false
    @State private var selectedExtensionManifest: ExtensionManifest?
    @State private var extensionDecisions: [String: ExtensionDecision] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        topStatusBar
                        pendingQueueSection
                        extensionProposalsSection
                        recentDecisionsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Control Room")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .alert(TextKeys.Lobby.confirmOrange, isPresented: $showOrangeConfirm) {
                Button(TextKeys.Lobby.confirmYes) {
                    if let decision = pendingDecision {
                        executeDecision(proposalId: decision.proposalId, decision: decision.decision)
                    }
                }
                Button(TextKeys.Lobby.confirmNo, role: .cancel) {
                    pendingDecision = nil
                }
            }
            .alert("Actie niet uitgevoerd", isPresented: $showDecisionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(decisionErrorMessage ?? "Onbekende fout.")
            }
            .alert("Extension actie niet uitgevoerd", isPresented: $showExtensionActionError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(extensionActionErrorMessage ?? "Onbekende fout.")
            }
            .sheet(isPresented: $showActionReceipt) {
                if let action = poller.lastActionReceipt {
                    ActionReceiptSheet(
                        action: action,
                        linkedKnowledge: poller.lastDecideLinkedKnowledge,
                        onKnowledgeTap: { objectId in
                            showActionReceipt = false
                            fetchAndShowKnowledgeGraph(objectId: objectId)
                        }
                    )
                }
            }
            .sheet(item: $selectedDecision) { decision in
                DecisionDetailSheet(
                    decision: decision,
                    onKnowledgeTap: { objectId in
                        selectedDecision = nil
                        fetchAndShowKnowledgeGraph(objectId: objectId)
                    }
                )
            }
            .sheet(isPresented: $showKnowledgeGraph) {
                KnowledgeGraphSheet(
                    graphData: knowledgeGraphData,
                    isLoading: loadingKnowledgeGraph
                )
            }
            .sheet(item: $selectedExtensionManifest) { manifest in
                ExtensionDetailSheet(
                    manifest: manifest,
                    onKnowledgeTap: { objectId in
                        selectedExtensionManifest = nil
                        fetchAndShowKnowledgeGraph(objectId: objectId)
                    },
                    onGraphTap: { extensionId in
                        selectedExtensionManifest = nil
                        fetchAndShowExtensionGraph(extensionId: extensionId)
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topStatusBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jeeves")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                    Text("Personal AI Control Room")
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                statusChip(
                    label: isMockMode ? "Mock" : "Live",
                    systemImage: isMockMode ? "sparkles" : "bolt.horizontal.circle.fill",
                    tint: isMockMode ? .orange : .consentGreen
                )
            }

            HStack(spacing: 8) {
                statusChip(
                    label: gateway.isConnected ? "Verbonden" : "Offline",
                    systemImage: gateway.isConnected ? "dot.radiowaves.left.and.right" : "wifi.slash",
                    tint: gateway.isConnected ? .consentGreen : .consentRed
                )
                statusChip(
                    label: "Queue \(poller.pendingProposals.count)",
                    systemImage: "tray.full.fill",
                    tint: .jeevesGold
                )
                statusChip(
                    label: "Besluiten \(poller.decidedProposals.count)",
                    systemImage: "checkmark.seal.fill",
                    tint: .blue
                )
            }
        }
        .controlRoomPanel()
    }

    // MARK: - Pending Queue

    @ViewBuilder
    private var pendingQueueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: TextKeys.Lobby.pendingQueue,
                icon: "tray.full",
                count: poller.pendingProposals.count
            )

            if isBackendUnavailable {
                backendUnavailableCard
            } else if poller.pendingProposals.isEmpty {
                emptyQueueCard
            } else {
                cardStack
            }
        }
    }

    private var emptyQueueCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(TextKeys.Lobby.noProposals)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlRoomPanel()
    }

    private var backendUnavailableCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Backend niet beschikbaar")
                    .font(.jeevesBody)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let message = unavailableMessage {
                Text(message)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .controlRoomPanel()
    }

    private var cardStack: some View {
        VStack(spacing: 20) {
            if let topProposal = poller.pendingProposals.first {
                SwipeCard(
                    proposal: topProposal,
                    isTop: true,
                    isDecisionInFlight: decidingProposalId != nil,
                    onSwipe: { direction in
                        handleSwipe(proposal: topProposal, direction: direction)
                    }
                )
                .id(topProposal.id)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                HStack(spacing: 16) {
                    Button {
                        handleSwipe(proposal: topProposal, direction: .left)
                    } label: {
                        Text(TextKeys.Lobby.deny)
                            .font(.jeevesHeadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.consentRed.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(decidingProposalId != nil)

                    Button {
                        handleSwipe(proposal: topProposal, direction: .right)
                    } label: {
                        Text(TextKeys.Lobby.approve)
                            .font(.jeevesHeadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.consentGreen.opacity(0.88))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(decidingProposalId != nil)
                }

                if decidingProposalId != nil {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Beslissing wordt bevestigd bij backend...")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .animation(.spring(response: 0.4), value: poller.pendingProposals.first?.id)
    }

    // MARK: - Extension Proposals

    @ViewBuilder
    private var extensionProposalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: TextKeys.Lobby.extensionProposals,
                icon: "puzzlepiece.extension",
                count: poller.extensionProposals.count
            )

            if poller.extensionProposals.isEmpty {
                extensionEmptyCard
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(poller.extensionProposals) { proposal in
                        ExtensionProposalCard(
                            proposal: proposal,
                            isActionInFlight: decidingExtensionId == proposal.extensionId || loadingManifestExtensionId == proposal.extensionId,
                            onApprove: { approveExtension(proposal) },
                            onReject: { rejectExtension(proposal) },
                            onInspectManifest: { inspectExtensionManifest(proposal) }
                        )
                    }
                }
            }

            if poller.extensionUsesDemoFallback {
                Text(TextKeys.Lobby.extensionDemoFallback)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var extensionEmptyCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(TextKeys.Lobby.noExtensionProposals)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlRoomPanel()
    }

    // MARK: - Recent Decisions

    @ViewBuilder
    private var recentDecisionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: TextKeys.Lobby.recentDecisions,
                icon: "checkmark.rectangle.stack",
                count: nil
            )

            if poller.decidedProposals.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(TextKeys.Lobby.noDecisions)
                        .font(.jeevesBody)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .controlRoomPanel()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(poller.decidedProposals) { decision in
                        DecidedProposalRow(decision: decision)
                            .onTapGesture {
                                selectedDecision = decision
                            }
                    }
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String, count: Int?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.jeevesGold)
            Text(title)
                .font(.jeevesHeadline.weight(.semibold))
                .foregroundStyle(.white)
            if let count, count > 0 {
                Text("\(count)")
                    .font(.jeevesCaption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.jeevesGold)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    private func statusChip(label: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(label)
        }
        .font(.jeevesCaption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.18))
        .foregroundStyle(tint)
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func handleSwipe(proposal: Proposal, direction: SwipeDirection) {
        guard decidingProposalId == nil else { return }
        let decision = direction == .right ? "approve" : "deny"

        if proposal.intent.risk == "orange" {
            pendingDecision = (proposal.proposalId, decision)
            showOrangeConfirm = true
            return
        }

        executeDecision(proposalId: proposal.proposalId, decision: decision)
    }

    private func executeDecision(proposalId: String, decision: String) {
        if decision == "approve" {
            JeevesHaptics.approved()
        } else {
            JeevesHaptics.swipeDeny()
        }

        let reason = decision == "approve" ? TextKeys.Lobby.approveReason : TextKeys.Lobby.denyReason
        decidingProposalId = proposalId
        Task {
            let result = await poller.decide(
                proposalId: proposalId,
                decision: decision,
                reason: reason,
                gateway: gateway
            )
            await MainActor.run {
                decidingProposalId = nil
                switch result {
                case .success:
                    if decision == "approve" && poller.lastActionReceipt != nil {
                        showActionReceipt = true
                    }
                case .failure(let message):
                    decisionErrorMessage = message
                    showDecisionError = true
                }
            }
        }

        pendingDecision = nil
    }

    private func approveExtension(_ proposal: ExtensionProposal) {
        performExtensionDecision(proposal: proposal, approve: true)
    }

    private func rejectExtension(_ proposal: ExtensionProposal) {
        performExtensionDecision(proposal: proposal, approve: false)
    }

    private func performExtensionDecision(proposal: ExtensionProposal, approve: Bool) {
        guard decidingExtensionId == nil else { return }
        decidingExtensionId = proposal.extensionId

        Task {
            let resolved = await resolveEndpoint()
            guard let token = resolved.token, !token.isEmpty else {
                await MainActor.run {
                    decidingExtensionId = nil
                    extensionActionErrorMessage = "Geen token beschikbaar. Voeg een token toe in Instellingen."
                    showExtensionActionError = true
                }
                return
            }

            let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)
            do {
                let decision = try await (approve
                    ? client.approveExtension(id: proposal.extensionId)
                    : client.rejectExtension(id: proposal.extensionId))
                await poller.refresh(gateway: gateway)
                await MainActor.run {
                    extensionDecisions[proposal.extensionId] = decision
                    decidingExtensionId = nil
                }
                await MainActor.run {
                    inspectExtensionManifest(proposal)
                }
            } catch {
                await MainActor.run {
                    decidingExtensionId = nil
                    extensionActionErrorMessage = describeExtensionActionFailure(
                        error,
                        host: resolved.host,
                        port: resolved.port
                    )
                    showExtensionActionError = true
                }
            }
        }
    }

    private func inspectExtensionManifest(_ proposal: ExtensionProposal) {
        guard loadingManifestExtensionId == nil else { return }
        loadingManifestExtensionId = proposal.extensionId

        Task {
            let fallbackDecision = extensionDecisions[proposal.extensionId]
            let fallbackManifest = ExtensionManifest(
                proposal: proposal,
                receipt: fallbackDecision?.receipt,
                auditTrail: fallbackDecision.map { [$0] } ?? []
            )

            if isMockMode || poller.extensionUsesDemoFallback {
                await MainActor.run {
                    selectedExtensionManifest = fallbackManifest
                    loadingManifestExtensionId = nil
                }
                return
            }

            let resolved = await resolveEndpoint()
            guard let token = resolved.token, !token.isEmpty else {
                await MainActor.run {
                    selectedExtensionManifest = fallbackManifest
                    loadingManifestExtensionId = nil
                }
                return
            }

            let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)
            do {
                let fetched = try await client.fetchExtension(id: proposal.extensionId)
                let merged = mergeManifestWithCachedDecision(fetched)
                await MainActor.run {
                    selectedExtensionManifest = merged
                    loadingManifestExtensionId = nil
                }
            } catch {
                await MainActor.run {
                    selectedExtensionManifest = fallbackManifest
                    loadingManifestExtensionId = nil
                }
            }
        }
    }

    private func mergeManifestWithCachedDecision(_ manifest: ExtensionManifest) -> ExtensionManifest {
        guard let cached = extensionDecisions[manifest.extensionId] else { return manifest }
        let mergedAuditTrail = manifest.auditTrail.isEmpty ? [cached] : manifest.auditTrail
        let mergedReceipt = manifest.receipt ?? cached.receipt
        return ExtensionManifest(
            extensionId: manifest.extensionId,
            title: manifest.title,
            purpose: manifest.purpose,
            capabilities: manifest.capabilities,
            risk: manifest.risk,
            codeHash: manifest.codeHash,
            entrypoint: manifest.entrypoint,
            status: manifest.status,
            approvedAtIso: manifest.approvedAtIso ?? cached.approvedAtIso,
            loadedAtIso: manifest.loadedAtIso ?? cached.loadedAtIso,
            sourceType: manifest.sourceType,
            knowledgeLinks: manifest.knowledgeLinks,
            auditTrail: mergedAuditTrail,
            receipt: mergedReceipt
        )
    }

    private func fetchAndShowKnowledgeGraph(objectId: String) {
        loadingKnowledgeGraph = true
        knowledgeGraphData = nil
        showKnowledgeGraph = true

        Task {
            guard !isMockMode else {
                await MainActor.run {
                    knowledgeGraphData = KnowledgeGraphResponse(
                        ok: true,
                        root: KnowledgeObject(
                            objectId: objectId,
                            kind: "decision",
                            createdAtIso: ISO8601DateFormatter().string(from: Date()),
                            title: "Demo kennisgraaf object",
                            summary: "Dit is een demo object uit de kennisgraaf.",
                            sourceRefs: nil,
                            linkedObjectIds: ["linked-1", "linked-2"],
                            metadata: nil
                        ),
                        linked: [
                            KnowledgeObject(
                                objectId: "linked-1",
                                kind: "action_receipt",
                                createdAtIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-300)),
                                title: "Actie-ontvangstbewijs: residue analyse",
                                summary: "Analyse van residue patronen voltooid met 8 signalen.",
                                sourceRefs: nil,
                                linkedObjectIds: nil,
                                metadata: nil
                            ),
                            KnowledgeObject(
                                objectId: "linked-2",
                                kind: "investigation_outcome",
                                createdAtIso: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-600)),
                                title: "Onderzoeksresultaat: anomalie patroon",
                                summary: "Cross-domain anomalie onderzocht, geen escalatie nodig.",
                                sourceRefs: nil,
                                linkedObjectIds: nil,
                                metadata: nil
                            ),
                        ],
                        edges: nil
                    )
                    loadingKnowledgeGraph = false
                }
                return
            }

            let resolved = await resolveEndpoint()
            guard let token = resolved.token, !token.isEmpty else {
                await MainActor.run { loadingKnowledgeGraph = false }
                return
            }

            let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)
            do {
                let graph = try await client.fetchKnowledgeGraph(objectId: objectId)
                await MainActor.run {
                    knowledgeGraphData = graph
                    loadingKnowledgeGraph = false
                }
            } catch {
                await MainActor.run { loadingKnowledgeGraph = false }
            }
        }
    }

    private func fetchAndShowExtensionGraph(extensionId: String) {
        loadingKnowledgeGraph = true
        knowledgeGraphData = nil
        showKnowledgeGraph = true

        Task {
            guard !isMockMode else {
                await MainActor.run {
                    knowledgeGraphData = demoExtensionGraph(extensionId: extensionId)
                    loadingKnowledgeGraph = false
                }
                return
            }

            let resolved = await resolveEndpoint()
            guard let token = resolved.token, !token.isEmpty else {
                await MainActor.run {
                    knowledgeGraphData = demoExtensionGraph(extensionId: extensionId)
                    loadingKnowledgeGraph = false
                }
                return
            }

            let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)
            do {
                let graph = try await client.fetchExtensionGraph(id: extensionId)
                await MainActor.run {
                    knowledgeGraphData = graph
                    loadingKnowledgeGraph = false
                }
            } catch {
                await MainActor.run {
                    knowledgeGraphData = demoExtensionGraph(extensionId: extensionId)
                    loadingKnowledgeGraph = false
                }
            }
        }
    }

    private func demoExtensionGraph(extensionId: String) -> KnowledgeGraphResponse {
        let now = ISO8601DateFormatter().string(from: Date())
        let root = KnowledgeObject(
            objectId: "extension-proposal-\(extensionId)",
            kind: "extension_proposal",
            createdAtIso: now,
            title: "Extension proposal \(extensionId)",
            summary: "Demo kennisgraaf voor extension review.",
            sourceRefs: nil,
            linkedObjectIds: [
                "extension-decision-\(extensionId)",
                "extension-manifest-\(extensionId)",
                "extension-receipt-\(extensionId)"
            ],
            metadata: nil
        )
        let linked: [KnowledgeObject] = [
            KnowledgeObject(
                objectId: "extension-decision-\(extensionId)",
                kind: "extension_decision",
                createdAtIso: now,
                title: "Decision \(extensionId)",
                summary: "Beslissing geregistreerd in demo modus.",
                sourceRefs: nil,
                linkedObjectIds: nil,
                metadata: nil
            ),
            KnowledgeObject(
                objectId: "extension-manifest-\(extensionId)",
                kind: "extension_manifest",
                createdAtIso: now,
                title: "Manifest \(extensionId)",
                summary: "Manifest geannoteerd met capabilities en risico.",
                sourceRefs: nil,
                linkedObjectIds: nil,
                metadata: nil
            ),
            KnowledgeObject(
                objectId: "extension-receipt-\(extensionId)",
                kind: "extension_receipt",
                createdAtIso: now,
                title: "Receipt \(extensionId)",
                summary: "Uitvoering niet automatisch geladen; alleen goedkeuring vastgelegd.",
                sourceRefs: nil,
                linkedObjectIds: nil,
                metadata: nil
            ),
        ]
        return KnowledgeGraphResponse(ok: true, root: root, linked: linked, edges: nil)
    }

    private func describeExtensionActionFailure(_ error: Error, host: String, port: Int) -> String {
        if case GatewayClientError.httpStatus(let status) = error {
            switch status {
            case 401:
                return "Token ongeldig of verlopen voor \(host):\(port)."
            case 404:
                return "Extension niet gevonden of al verwerkt."
            default:
                return "Backend fout (\(status)) op \(host):\(port)."
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotFindHost, .cannotConnectToHost, .timedOut, .networkConnectionLost:
                return "Backend onbereikbaar op \(host):\(port)."
            default:
                break
            }
        }
        return "Extension actie mislukt."
    }

    private func resolveEndpoint() async -> (host: String, port: Int, token: String?) {
        let host = gateway.host.isEmpty ? "localhost" : gateway.host
        let port = gateway.port > 0 ? gateway.port : 19001
        let token = gateway.token
        return (host, port, token)
    }

    private var isBackendUnavailable: Bool {
        !isMockMode && !gateway.isConnected
    }

    private var isMockMode: Bool {
        gateway.useMock || gateway.host.lowercased() == "mock"
    }

    private var unavailableMessage: String? {
        if isBackendUnavailable {
            return poller.lastRefreshError ?? "Geen actieve verbinding met de echte backend."
        }
        return nil
    }
}

private struct ExtensionProposalCard: View {
    let proposal: ExtensionProposal
    let isActionInFlight: Bool
    let onApprove: () -> Void
    let onReject: () -> Void
    let onInspectManifest: () -> Void

    private var riskColor: Color {
        switch proposal.risk.lowercased() {
        case "green":
            return .green
        case "orange":
            return .orange
        case "red":
            return .red
        default:
            return .secondary
        }
    }

    private var capabilitySummary: String {
        if proposal.capabilities.isEmpty {
            return "Geen capabilities"
        }
        return proposal.capabilities.map(\.title).joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(proposal.title)
                    .font(.jeevesHeadline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
                Text(proposal.risk.uppercased())
                    .font(.jeevesCaption)
                    .foregroundStyle(riskColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(riskColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            detailRow(label: TextKeys.Lobby.extensionPurpose, value: proposal.purpose)
            detailRow(label: TextKeys.Lobby.extensionCapabilities, value: capabilitySummary)
            detailRow(label: TextKeys.Lobby.extensionSource, value: proposal.sourceType ?? "unknown")
            detailRow(label: TextKeys.Lobby.extensionCodeHash, value: proposal.codeHash)

            HStack(spacing: 8) {
                Button(TextKeys.Lobby.approve, action: onApprove)
                    .buttonStyle(.borderedProminent)
                    .tint(.consentGreen)
                    .disabled(isActionInFlight)

                Button(TextKeys.Lobby.deny, action: onReject)
                    .buttonStyle(.bordered)
                    .tint(.consentRed)
                    .disabled(isActionInFlight)

                Button(TextKeys.Lobby.inspectManifest, action: onInspectManifest)
                    .buttonStyle(.bordered)
                    .disabled(isActionInFlight)

                if isActionInFlight {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .controlRoomPanel(padding: 14)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
                .lineLimit(2)
        }
    }
}

// MARK: - SwipeDirection

enum SwipeDirection {
    case left, right
}

// MARK: - Decided Proposal Row

private struct DecidedProposalRow: View {
    let decision: DecidedProposal

    private var statusIcon: String {
        decision.isApproved ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var statusColor: Color {
        decision.isApproved ? .green : .red
    }

    private var statusLabel: String {
        decision.isApproved ? TextKeys.Lobby.approved : TextKeys.Lobby.denied
    }

    private var timeSince: String {
        guard let date = decision.decidedAt else { return "" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s geleden" }
        if seconds < 3600 { return "\(seconds / 60)m geleden" }
        if seconds < 86400 { return "\(seconds / 3600)u geleden" }
        return "\(seconds / 86400)d geleden"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(decision.title)
                    .font(.jeevesBody)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(statusLabel)
                        .font(.jeevesCaption)
                        .foregroundStyle(statusColor)

                    if !timeSince.isEmpty {
                        Text(timeSince)
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let reason = decision.decisionReason, !reason.isEmpty {
                    Text(reason)
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if decision.action != nil {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.body)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .controlRoomPanel(padding: 12)
    }
}

// MARK: - Decision Detail Sheet

private struct DecisionDetailSheet: View {
    let decision: DecidedProposal
    let onKnowledgeTap: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        decisionHeader
                        decisionMetadata
                        if decision.action != nil {
                            Divider().overlay(Color.white.opacity(0.12))
                            decisionActionSection
                        }
                    }
                    .controlRoomPanel()
                    .padding()
                }
            }
            .navigationTitle(TextKeys.Lobby.recentDecisions)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private var decisionHeader: some View {
        let icon = decision.isApproved ? "checkmark.circle.fill" : "xmark.circle.fill"
        let color: Color = decision.isApproved ? .green : .red
        let label = decision.isApproved ? TextKeys.Lobby.approved : TextKeys.Lobby.denied
        return HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(decision.title)
                    .font(.jeevesHeadline)
                    .foregroundStyle(.white)
                Text(label)
                    .font(.jeevesCaption)
                    .foregroundStyle(color)
            }
        }
    }

    private var decisionMetadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataRow(label: "Agent", value: decision.agentId)
            if let decidedAt = decision.decidedAt {
                metadataRow(label: "Beslist", value: formatDate(decidedAt))
            }
            if let reason = decision.decisionReason {
                metadataRow(label: "Reden", value: reason)
            }
            if let intent = decision.intent {
                metadataRow(label: "Intent", value: intent.key)
                metadataRow(label: "Risico", value: intent.risk)
            }
            if let score = decision.priorityScore, score > 0 {
                metadataRow(label: "Prioriteit", value: "P\(Int(score))")
            }
        }
    }

    @ViewBuilder
    private var decisionActionSection: some View {
        if let action = decision.action {
            let actionIcon = action.isCompleted ? "checkmark.seal.fill" : "xmark.seal.fill"
            let actionColor: Color = action.isCompleted ? .green : .red
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: actionIcon)
                        .foregroundStyle(actionColor)
                    Text(TextKeys.Lobby.actionReceipt)
                        .font(.jeevesHeadline)
                }

                metadataRow(label: TextKeys.Lobby.actionKind, value: action.actionKind)
                metadataRow(label: TextKeys.Lobby.actionStatus, value: action.executionState)

                if let receipt = action.receipt {
                    decisionReceiptDetails(receipt: receipt)
                }
            }
        }
    }

    @ViewBuilder
    private func decisionReceiptDetails(receipt: ActionReceipt) -> some View {
        Text(receipt.resultSummary)
            .font(.jeevesBody)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        if let duration = receipt.durationMs {
            metadataRow(label: TextKeys.Lobby.actionDuration, value: "\(Int(duration))ms")
        }
        if let resultType = receipt.resultType {
            metadataRow(label: TextKeys.Lobby.actionResultType, value: resultType)
        }
        if let notes = receipt.notes, !notes.isEmpty {
            metadataRow(label: TextKeys.Lobby.actionNotes, value: notes)
        }
        if let outputIds = receipt.outputObjectIds, !outputIds.isEmpty {
            Divider()
            Text(TextKeys.Lobby.actionOutputObjects)
                .font(.jeevesHeadline)
            ForEach(outputIds, id: \.self) { objId in
                Button {
                    onKnowledgeTap(objId)
                } label: {
                    knowledgeLinkRow(objId: objId)
                }
            }
        }
    }

    private func knowledgeLinkRow(objId: String) -> some View {
        HStack {
            Image(systemName: "link")
                .foregroundStyle(Color.jeevesGold)
            Text(objId)
                .font(.jeevesMono)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Swipe Card

private struct SwipeCard: View {
    let proposal: Proposal
    let isTop: Bool
    let isDecisionInFlight: Bool
    let onSwipe: (SwipeDirection) -> Void

    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1.0

    private var riskColor: Color {
        switch proposal.intent.risk {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        default: return .secondary
        }
    }

    private var riskEmoji: String {
        switch proposal.intent.risk {
        case "green": return "\u{1F7E2}"
        case "orange": return "\u{1F7E0}"
        case "red": return "\u{1F534}"
        default: return "\u{26AA}"
        }
    }

    private var timeSince: String {
        guard let created = proposal.createdAt else { return "" }
        let seconds = Int(Date().timeIntervalSince(created))
        if seconds < 60 { return "\(seconds)s geleden" }
        if seconds < 3600 { return "\(seconds / 60)m geleden" }
        return "\(seconds / 3600)u geleden"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(riskEmoji)
                Text(proposal.agentId)
                    .font(.jeevesHeadline)
                    .foregroundStyle(.white)
                Spacer()
                if let score = proposal.priorityScore, score > 0 {
                    Text("P\(Int(score))")
                        .font(.jeevesMono)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor(score))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                if let rank = proposal.rank, rank > 0 {
                    Text("#\(rank)")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(proposal.title)
                .font(.jeevesBody)
                .foregroundStyle(.white)

            if let explanation = proposal.priorityExplanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.jeevesCaption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Text("Intent:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Text(proposal.intent.key)
                    .font(.jeevesMono)
            }

            HStack {
                Text("Risico:")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                Text(riskEmoji)
                Text(proposal.intent.risk)
                    .font(.jeevesMono)
                    .foregroundStyle(riskColor)
            }

            Text(timeSince)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(riskColor.opacity(0.55), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .opacity(opacity)
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width) / 20))
        .gesture(
            (isTop && !isDecisionInFlight) ? DragGesture()
                .onChanged { value in
                    offset = value.translation
                }
                .onEnded { value in
                    let threshold: CGFloat = 100
                    if value.translation.width > threshold {
                        swipeAway(direction: .right)
                    } else if value.translation.width < -threshold {
                        swipeAway(direction: .left)
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            offset = .zero
                        }
                    }
                }
            : nil
        )
        .allowsHitTesting(isTop && !isDecisionInFlight)
    }

    private func swipeAway(direction: SwipeDirection) {
        let offscreenX: CGFloat = direction == .right ? 500 : -500
        withAnimation(.easeOut(duration: 0.3)) {
            offset = CGSize(width: offscreenX, height: 0)
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSwipe(direction)
        }
    }

    private func priorityColor(_ score: Double) -> Color {
        if score >= 70 { return .red }
        if score >= 40 { return .orange }
        return .green
    }
}

// MARK: - Enhanced Action Receipt Sheet

private struct ActionReceiptSheet: View {
    let action: ActionSummary
    let linkedKnowledge: [KnowledgeObject]
    let onKnowledgeTap: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        receiptHeader
                        receiptMetadata
                        if action.receipt != nil {
                            Divider().overlay(Color.white.opacity(0.12))
                            receiptDetailsSection
                        }
                        if !linkedKnowledge.isEmpty {
                            Divider().overlay(Color.white.opacity(0.12))
                            linkedKnowledgeSection
                        }
                    }
                    .controlRoomPanel()
                    .padding()
                }
            }
            .navigationTitle(TextKeys.Lobby.actionReceipt)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private var receiptHeader: some View {
        let icon = action.isCompleted ? "checkmark.circle.fill" : "xmark.circle.fill"
        let color: Color = action.isCompleted ? .green : .red
        let label = action.isCompleted ? TextKeys.Lobby.actionCompleted : TextKeys.Lobby.actionFailed
        return HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title)
            Text(label)
                .font(.jeevesHeadline)
                .foregroundStyle(.white)
        }
    }

    private var receiptMetadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            metadataRow(label: TextKeys.Lobby.actionKind, value: action.actionKind)
            metadataRow(label: TextKeys.Lobby.actionStatus, value: action.executionState)
        }
    }

    @ViewBuilder
    private var receiptDetailsSection: some View {
        if let receipt = action.receipt {
            VStack(alignment: .leading, spacing: 8) {
                Text(TextKeys.Lobby.actionResult)
                    .font(.jeevesHeadline)

                Text(receipt.resultSummary)
                    .font(.jeevesBody)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                receiptExtraFields(receipt: receipt)
                receiptOutputObjects(receipt: receipt)
            }
        }
    }

    @ViewBuilder
    private func receiptExtraFields(receipt: ActionReceipt) -> some View {
        if let duration = receipt.durationMs {
            metadataRow(label: TextKeys.Lobby.actionDuration, value: "\(Int(duration))ms")
        }
        if let resultType = receipt.resultType {
            metadataRow(label: TextKeys.Lobby.actionResultType, value: resultType)
        }
        if let notes = receipt.notes, !notes.isEmpty {
            metadataRow(label: TextKeys.Lobby.actionNotes, value: notes)
        }
    }

    @ViewBuilder
    private func receiptOutputObjects(receipt: ActionReceipt) -> some View {
        if let outputIds = receipt.outputObjectIds, !outputIds.isEmpty {
            Divider()
            Text(TextKeys.Lobby.actionOutputObjects)
                .font(.jeevesHeadline)
            ForEach(outputIds, id: \.self) { objId in
                Button {
                    onKnowledgeTap(objId)
                } label: {
                    outputObjectRow(objId: objId)
                }
            }
        }
    }

    private func outputObjectRow(objId: String) -> some View {
        HStack {
            Image(systemName: "link")
                .foregroundStyle(Color.jeevesGold)
            Text(objId)
                .font(.jeevesMono)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var linkedKnowledgeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TextKeys.Lobby.knowledgeObjects)
                .font(.jeevesHeadline)
            ForEach(linkedKnowledge) { obj in
                KnowledgeObjectCard(object: obj) {
                    onKnowledgeTap(obj.objectId)
                }
            }
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.jeevesMono)
        }
    }
}

// MARK: - Knowledge Object Card

private struct KnowledgeObjectCard: View {
    let object: KnowledgeObject
    let onTap: () -> Void

    private var kindColor: Color {
        switch object.kind {
        case "decision": return .blue
        case "investigation_outcome": return .purple
        case "action_receipt": return .green
        case "discovery": return .orange
        case "evidence": return .teal
        default: return .secondary
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(object.kindEmoji)
                    Text(object.kind.replacingOccurrences(of: "_", with: " "))
                        .font(.jeevesCaption)
                        .foregroundStyle(kindColor)
                        .textCase(.uppercase)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }

                Text(object.title)
                    .font(.jeevesBody)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(object.summary)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(kindColor.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Knowledge Graph Sheet

private struct KnowledgeGraphSheet: View {
    let graphData: KnowledgeGraphResponse?
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ControlRoomBackdrop()

                Group {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Kennisgraaf laden...")
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let graph = graphData {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if let root = graph.root {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(TextKeys.Lobby.rootObject)
                                            .font(.jeevesHeadline)
                                            .foregroundStyle(.white)
                                        KnowledgeObjectCard(object: root, onTap: {})
                                    }
                                }

                                if let linked = graph.linked, !linked.isEmpty {
                                    Divider().overlay(Color.white.opacity(0.12))

                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(TextKeys.Lobby.linkedObjects)
                                                .font(.jeevesHeadline)
                                                .foregroundStyle(.white)
                                            Text("\(linked.count)")
                                                .font(.jeevesCaption)
                                                .foregroundStyle(.secondary)
                                        }

                                        ForEach(linked) { obj in
                                            KnowledgeObjectCard(object: obj, onTap: {})
                                        }
                                    }
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "circle.dotted")
                                            .font(.title2)
                                            .foregroundStyle(.secondary)
                                        Text(TextKeys.Lobby.noLinkedObjects)
                                            .font(.jeevesBody)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                }
                            }
                            .controlRoomPanel()
                            .padding()
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("Kennisgraaf niet beschikbaar.")
                                .font(.jeevesBody)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle(TextKeys.Lobby.knowledgeGraph)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

private struct ControlRoomBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.07, blue: 0.11),
                    Color(red: 0.02, green: 0.03, blue: 0.06),
                    Color(red: 0.01, green: 0.02, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.jeevesGold.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 420
            )

            RadialGradient(
                colors: [Color.blue.opacity(0.14), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }
}

private struct ControlRoomPanelModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
    }
}

private extension View {
    func controlRoomPanel(padding: CGFloat = 16) -> some View {
        modifier(ControlRoomPanelModifier(padding: padding))
    }
}
