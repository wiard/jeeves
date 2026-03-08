import SwiftUI

struct LobbyView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @State private var showOrangeConfirm = false
    @State private var pendingDecision: (proposalId: String, decision: String)?
    @State private var decidingProposalId: String?
    @State private var decisionErrorMessage: String?
    @State private var showDecisionError = false
    @State private var lastActionResult: ActionSummary?
    @State private var showActionReceipt = false

    var body: some View {
        NavigationStack {
            Group {
                if poller.pendingProposals.isEmpty {
                    emptyState
                } else {
                    cardStack
                }
            }
            .navigationTitle(TextKeys.Lobby.header)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
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
            .sheet(isPresented: $showActionReceipt) {
                if let action = lastActionResult {
                    ActionReceiptSheet(action: action)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: isBackendUnavailable ? "antenna.radiowaves.left.and.right.slash" : "leaf")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(isBackendUnavailable ? "Backend niet beschikbaar" : TextKeys.Lobby.noProposals)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let message = unavailableMessage {
                Text(message)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding()
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
                            .font(.jeevesHeadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(decidingProposalId != nil)

                    Button {
                        handleSwipe(proposal: topProposal, direction: .right)
                    } label: {
                        Text(TextKeys.Lobby.approve)
                            .font(.jeevesHeadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.green)
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
        .padding()
        .animation(.spring(response: 0.4), value: poller.pendingProposals.first?.id)
    }

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
                if case .failure(let message) = result {
                    decisionErrorMessage = message
                    showDecisionError = true
                }
            }
        }

        pendingDecision = nil
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

enum SwipeDirection {
    case left, right
}

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

    private var riskBackground: Color {
        switch proposal.intent.risk {
        case "green": return .green.opacity(0.15)
        case "orange": return .orange.opacity(0.15)
        case "red": return .red.opacity(0.15)
        default: return Color(.secondarySystemFill)
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
        .background(riskBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
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

private struct ActionReceiptSheet: View {
    let action: ActionSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: action.isCompleted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(action.isCompleted ? .green : .red)
                        .font(.title)
                    Text(action.isCompleted ? "Actie uitgevoerd" : "Actie mislukt")
                        .font(.jeevesHeadline)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Soort:")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                        Text(action.actionKind)
                            .font(.jeevesMono)
                    }
                    HStack {
                        Text("Status:")
                            .font(.jeevesCaption)
                            .foregroundStyle(.secondary)
                        Text(action.executionState)
                            .font(.jeevesMono)
                    }
                }

                if let receipt = action.receipt {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resultaat")
                            .font(.jeevesHeadline)
                        Text(receipt.resultSummary)
                            .font(.jeevesBody)
                        if let duration = receipt.durationMs {
                            HStack {
                                Text("Duur:")
                                    .font(.jeevesCaption)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(duration))ms")
                                    .font(.jeevesMono)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Actie-ontvangstbewijs")
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
