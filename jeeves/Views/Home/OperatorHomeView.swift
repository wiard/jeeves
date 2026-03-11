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
                    ProgressView("Overview preparing...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content
                }
            }
            .navigationTitle("Overview")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mission Control") {
                        presentedDestination = .missionControl
                    }
                }
            }
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
                InstrumentRoleHeader(
                    eyebrow: "Entry Layer",
                    title: "Governed System Overview",
                    summary: snapshot.summary,
                    accent: .blue,
                    metrics: snapshot.headerMetrics.map { metric in
                        InstrumentRoleMetric(label: metric.label, value: metric.value)
                    }
                )
                .calmAppear()

                loopCard
                    .calmAppear(delay: 0.05)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(Array(snapshot.overviewCards.enumerated()), id: \.element.id) { index, card in
                        OperatorOverviewCard(card: card)
                            .calmAppear(delay: 0.08 + (Double(index) * 0.04))
                    }
                }

                OperatorLatestFlowStrip(items: snapshot.flowItems)
                    .calmAppear(delay: 0.24)

                deepLinksPanel
                    .calmAppear(delay: 0.28)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var loopCard: some View {
        InstrumentSectionPanel(
            eyebrow: "Governed Loop",
            title: "The system stays legible at first glance",
            subtitle: snapshot.focusLine,
            accent: .blue
        ) {
            Text(OperatorOverviewSnapshot.loopLine)
                .font(.jeevesMono)
                .foregroundStyle(.primary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.55))
                )

            Text(snapshot.updatedLine)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
        }
    }

    private var deepLinksPanel: some View {
        InstrumentSectionPanel(
            eyebrow: "Deep Links",
            title: "Enter the intact operational surfaces",
            subtitle: "This home layer is only a summary. The existing rooms remain the places for detailed work.",
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
    case missionControl
    case lobby
    case radar
    case knowledge
    case browser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .missionControl:
            return "Mission Control"
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
        case .missionControl:
            return "The deeper operational room for discovery, governance, knowledge, and trust detail."
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
        case .missionControl:
            return "scope"
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
        case .missionControl:
            MissionControlDashboardView()
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
