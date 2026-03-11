import SwiftUI

struct OperatorHomeView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @State private var presentedDestination: OperatorHomeDestination?

    private let columns = [
        GridItem(.flexible(minimum: 220), spacing: 16),
        GridItem(.flexible(minimum: 220), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.95, green: 0.98, blue: 1.00),
                        Color(red: 0.93, green: 0.97, blue: 0.99),
                        Color(red: 0.98, green: 0.97, blue: 0.94)
                    ]
                )
                .ignoresSafeArea()

                if isBootstrapping {
                    ProgressView("Operator overview preparing...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content
                }
            }
            .navigationTitle("Overview")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .refreshable {
                await refresh()
            }
            .task {
                await refresh()
            }
            .onChange(of: gateway.isConnected) {
                if gateway.isConnected {
                    Task {
                        await refresh()
                    }
                }
            }
            .sheet(item: $presentedDestination) { destination in
                destination.view
            }
        }
    }

    private var snapshot: OperatorOverviewSnapshot {
        OperatorOverviewSnapshot(poller: poller)
    }

    private var isBootstrapping: Bool {
        !poller.hasLoadedOnce && !hasVisibleState
    }

    private var hasVisibleState: Bool {
        !poller.pendingProposals.isEmpty
            || !poller.recentKnowledgeObjects.isEmpty
            || !poller.recentActions.isEmpty
            || !poller.radarDiscoveryCandidates.isEmpty
            || poller.conductorState != nil
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                statusBar
                .calmAppear()

                OperatorLatestFlowStrip(items: snapshot.loopStages)
                    .calmAppear(delay: 0.05)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(Array(snapshot.stageCards.enumerated()), id: \.element.id) { index, card in
                        OperatorOverviewCard(card: card)
                            .calmAppear(delay: 0.08 + (Double(index) * 0.04))
                    }
                }

                deepLinksPanel
                    .calmAppear(delay: 0.32)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var statusBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SYSTEM STATUS")
                        .font(.jeevesMonoSmall)
                        .foregroundStyle(statusAccent)

                    Text("\(snapshot.statusBar.healthLabel) • Last tick \(snapshot.statusBar.lastTick)")
                        .font(.jeevesHeadline)

                    Text(snapshot.summary)
                        .font(.jeevesBody)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(snapshot.statusBar.healthLabel.uppercased())
                    .font(.jeevesMonoSmall)
                    .foregroundStyle(statusAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusAccent.opacity(0.12))
                    .clipShape(Capsule())
            }

            ViewThatFits {
                HStack(spacing: 10) {
                    statusPill(snapshot.statusBar.summary, tint: .blue)
                    statusPill(snapshot.statusBar.activeStageLine, tint: statusAccent)
                    statusPill(snapshot.statusBar.operatorLine, tint: operatorTint)
                }

                VStack(spacing: 10) {
                    statusPill(snapshot.statusBar.summary, tint: .blue)
                    statusPill(snapshot.statusBar.activeStageLine, tint: statusAccent)
                    statusPill(snapshot.statusBar.operatorLine, tint: operatorTint)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(statusAccent.opacity(0.16), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 18, y: 10)
    }

    private func statusPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.jeevesCaption)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.08))
            )
    }

    private var statusAccent: Color {
        switch snapshot.statusBar.tone {
        case .calm:
            return .green
        case .active:
            return .blue
        case .watch:
            return .orange
        case .critical:
            return .red
        }
    }

    private var operatorTint: Color {
        if snapshot.statusBar.operatorLine == "No operator decision is required right now." {
            return .green
        }
        return .orange
    }

    private var deepLinksPanel: some View {
        InstrumentSectionPanel(
            eyebrow: "Deep Links",
            title: "Enter the intact operational surfaces",
            subtitle: "This home layer is only a summary. Mission Control and the other rooms remain the places for detailed work.",
            accent: .jeevesGold
        ) {
            ForEach(OperatorHomeDestination.allCases) { destination in
                Button {
                    presentedDestination = destination
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: destination.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 34, height: 34)
                            .background(Color.jeevesGold.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(destination.title)
                                .font(.jeevesBody.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(destination.detail)
                                .font(.jeevesCaption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.jeevesCaption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func refresh() async {
        await poller.refresh(gateway: gateway)
    }
}

private enum OperatorHomeDestination: String, CaseIterable, Identifiable {
    case lobby
    case radar
    case knowledge
    case browser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lobby:
            return "Lobby / Gap Inbox"
        case .radar:
            return "Radar / Observatory"
        case .knowledge:
            return "Knowledge / Library"
        case .browser:
            return "Browser / Deployments"
        }
    }

    var detail: String {
        switch self {
        case .lobby:
            return "Pending review, governed gap intake, and the operator decision lane."
        case .radar:
            return "CLASHD27 signal, observatory, and emergence detail without moving discovery into Jeeves."
        case .knowledge:
            return "The library surface for recent objects, evidence, and knowledge attribution."
        case .browser:
            return "SafeClash browsing and deployment-facing surfaces already present in the cockpit."
        }
    }

    var icon: String {
        switch self {
        case .lobby:
            return "tray.full"
        case .radar:
            return "binoculars"
        case .knowledge:
            return "book.closed"
        case .browser:
            return "sparkle.magnifyingglass"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .lobby:
            LobbyView()
        case .radar:
            CLASHD27RadarView()
        case .knowledge:
            KnowledgeBrowserView()
        case .browser:
            AIBrowserView()
        }
    }
}
