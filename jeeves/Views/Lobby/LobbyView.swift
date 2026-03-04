import SwiftUI

struct LobbyView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @State private var showOrangeConfirm = false
    @State private var pendingDecision: (proposalId: String, decision: String)?

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
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(TextKeys.Lobby.noProposals)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var cardStack: some View {
        ZStack {
            ForEach(poller.pendingProposals.reversed()) { proposal in
                SwipeCard(
                    proposal: proposal,
                    isTop: proposal.id == poller.pendingProposals.first?.id,
                    onSwipe: { direction in
                        handleSwipe(proposal: proposal, direction: direction)
                    }
                )
            }
        }
        .padding()
    }

    private func handleSwipe(proposal: Proposal, direction: SwipeDirection) {
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
        Task {
            _ = await poller.decide(proposalId: proposalId, decision: decision, reason: reason, gateway: gateway)
        }

        pendingDecision = nil
    }
}

enum SwipeDirection {
    case left, right
}

private struct SwipeCard: View {
    let proposal: Proposal
    let isTop: Bool
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
            }

            Text(proposal.title)
                .font(.jeevesBody)

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

            Spacer()

            HStack {
                Text("\u{2190} \(TextKeys.Lobby.deny)")
                    .font(.jeevesCaption)
                    .foregroundStyle(.red)
                Spacer()
                Text("\(TextKeys.Lobby.approve) \u{2192}")
                    .font(.jeevesCaption)
                    .foregroundStyle(.green)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 280)
        .background(riskBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .opacity(opacity)
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width) / 20))
        .gesture(
            isTop ? DragGesture()
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
        .allowsHitTesting(isTop)
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
}
