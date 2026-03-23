import SwiftUI

struct VandaagView: View {
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller
    @AppStorage("jeeves_intro_dismissed") private var introDismissed = false
    @AppStorage("vandaag_cache_bieb") private var cachedBieb = ""
    @StateObject private var viewModel = VandaagViewModel()
    @StateObject private var decisionsViewModel = BeslissingenViewModel()
    @StateObject private var disciplineViewModel = DisciplineViewModel()
    @StateObject private var disciplineSelection = DisciplineSelectionStore.shared
    @State private var selectedItem: BiebLatestCell?
    @State private var showGlossary = false
    @State private var showIntroOnRequest = false
    @State private var showPendingProposals = false
    @State private var showMeaningHistory = false

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.99, green: 0.97, blue: 0.96),
                        Color(red: 0.98, green: 0.95, blue: 0.93),
                        Color(red: 0.97, green: 0.97, blue: 0.99)
                    ]
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard

                        if shouldShowIntroCard {
                            introCard
                        }

                        if let error = viewModel.error {
                            statusNotice(error, accent: .jeevesLogoRed)
                        }

                        newspaperFrontPage

                        radarNewsSection

                        if let topDiscipline = disciplineViewModel.featuredDiscipline {
                            Button {
                                disciplineSelection.requestedDisciplineId = topDiscipline.id
                                NotificationCenter.default.post(name: .jeevesOpenDisciplinesTab, object: nil)
                            } label: {
                                HStack {
                                    Text(disciplineBannerText(topDiscipline))
                                        .font(.jeevesBody.weight(.semibold))
                                        .foregroundStyle(Color.jeevesInk)
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundStyle(Color.jeevesLogoRed)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.92))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(Color.jeevesLogoRed.opacity(0.16), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                overviewStatCard(label: "SIGNALEN", value: dailySignalsValue)
                                overviewStatCard(label: "COLLISIES", value: dailyCollisionsValue)
                                overviewStatCard(label: "KENNISBANK", value: dailyKnowledgeValue)
                            }

                            Text(dailyBriefingLine)
                                .font(.jeevesBody)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        InstrumentSectionPanel(
                            eyebrow: "Bieb",
                            title: "Wat nu bovenaan ligt",
                            subtitle: "De top 5 cellen uit de Bieb, gesorteerd op score. Swipe naar rechts om goed te keuren of naar links om weg te zetten.",
                            accent: .jeevesLogoRed,
                            metric: viewModel.isLoading ? "Laden" : nil
                        ) {
                            if viewModel.isLoading && viewModel.items.isEmpty {
                                ForEach(0..<3, id: \.self) { _ in
                                    biebSkeletonCard
                                }
                            } else if viewModel.topItems.isEmpty {
                                emptyState("De Bieb is stil. Kom later terug.")
                            } else {
                                ForEach(viewModel.topItems) { item in
                                    biebCard(item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = viewModel.toast {
                    toastBanner(toast)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showGlossary = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.jeevesLogoRed)
                    }
                    .accessibilityLabel("Wat zijn gaps en opportunities?")
                }
            }
            .task {
                await loadInitialContent()
            }
            .refreshable {
                await refreshContent()
            }
            .onChange(of: gateway.isConnected) {
                if gateway.isConnected {
                    Task {
                        await refreshContent()
                    }
                }
            }
            .sheet(item: $selectedItem) { item in
                BiebDetailView(item: item, viewModel: viewModel)
            }
            .sheet(isPresented: $showPendingProposals) {
                NavigationStack {
                    PendingProposalSheet(proposals: viewModel.pendingProposals)
                }
            }
            .sheet(isPresented: $showMeaningHistory) {
                NavigationStack {
                    MeaningHistorySheet(items: viewModel.jacobMeaningItems)
                }
            }
            .sheet(isPresented: $showGlossary) {
                GlossaryView()
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.toast)
        }
    }

    private var datumLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: Date()).capitalized
    }

    private var shouldShowIntroCard: Bool {
        !introDismissed || showIntroOnRequest
    }

    private var approvedCountToday: Int {
        poller.decidedProposals.filter(\.isApproved).count
    }

    private var deniedCountToday: Int {
        poller.decidedProposals.filter(\.isDenied).count
    }

    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    private var greetingEyebrow: String {
        switch currentHour {
        case 6..<12:
            return "GOEDEMORGEN"
        case 12..<18:
            return "GOEDEMIDDAG"
        case 18..<24:
            return "GOEDENAVOND"
        default:
            return "NACHTDIENST"
        }
    }

    private var headerTitle: String {
        switch currentHour {
        case 6..<12:
            return "Het systeem heeft vannacht \(activeSignalsCount) signal\(activeSignalsCount == 1 ? "" : "en") verzameld."
        case 12..<18:
            return "\(viewModel.waitingCount) signal\(viewModel.waitingCount == 1 ? "" : "en") wachten op jouw beslissing."
        case 18..<24:
            return "Vandaag goedgekeurd: \(approvedCountToday). Afgewezen: \(deniedCountToday)."
        default:
            return "Het systeem observeert. Jij slaapt. Dat klopt zo."
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(greetingEyebrow)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.jeevesLogoRed)
                    .tracking(0.9)

                Spacer(minLength: 12)

                Text(datumLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.jeevesSubtleText)
                    .multilineTextAlignment(.trailing)
            }

            Text(headerTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.jeevesInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 12) {
                Text("Jeeves bewaakt het veld.\nJij beslist wat er gebeurt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if introDismissed {
                    Button("Wat is Jeeves?") {
                        showIntroOnRequest = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.jeevesLogoRed)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 1.0, green: 0.96, blue: 0.96))
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(red: 0.78, green: 0.06, blue: 0.18))
                .frame(height: 2)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        topTrailingRadius: 20
                    )
                )
        }
    }

    private var activeSignalsCount: Int {
        poller.radarStatus?.store?.activationCount ?? 0
    }

    private var collisionsCount: Int {
        max(poller.radarCollisions.count, poller.radarStatus?.store?.collisionCount ?? 0)
    }

    private var emergenceCount: Int {
        max(
            poller.radarEmergence.count,
            poller.radarStatus?.store?.emergenceCount ?? 0,
            poller.knowledgeStatus?.emergenceClustersCount ?? 0
        )
    }

    private var knowledgeObjectsTodayCount: Int {
        let calendar = Calendar.current
        let formatter = ISO8601DateFormatter()
        return poller.recentKnowledgeObjects.reduce(into: 0) { count, object in
            guard let date = formatter.date(from: object.createdAtIso),
                  calendar.isDateInToday(date) else {
                return
            }
            count += 1
        }
    }

    private var hasDailyOverviewData: Bool {
        poller.radarStatus != nil
            || poller.knowledgeStatus != nil
            || !poller.radarCollisions.isEmpty
            || !poller.radarEmergence.isEmpty
            || !poller.recentKnowledgeObjects.isEmpty
    }

    private var dailySignalsValue: String {
        hasDailyOverviewData ? "\(activeSignalsCount)" : "---"
    }

    private var dailyCollisionsValue: String {
        hasDailyOverviewData ? "\(collisionsCount)" : "---"
    }

    private var dailyKnowledgeValue: String {
        hasDailyOverviewData ? "\(knowledgeObjectsTodayCount)" : "---"
    }

    private var dailyBriefingLine: String {
        if collisionsCount > 0 {
            return "Het systeem detecteerde \(collisionsCount) collision\(collisionsCount == 1 ? "" : "s"). Bekijk de Bieb."
        }
        if emergenceCount > 0 {
            return "Emergentie gedetecteerd. \(emergenceCount) \(emergenceCount == 1 ? "cel reageert" : "cellen reageren") simultaan."
        }
        return "Het systeem observeert. \(activeSignalsCount) signalen actief."
    }

    private var newspaperFrontPage: some View {
        HStack(alignment: .top, spacing: 10) {
            frontPageBlock(
                eyebrow: "WACHT OP U",
                title: waitBlockTitle,
                detail: waitBlockDetail,
                primaryButtonTitle: "Bekijk eerste →",
                primaryAction: {
                    showPendingProposals = true
                }
            )

            frontPageBlock(
                eyebrow: "STERKSTE SIGNAAL",
                title: strongestSignalTitle,
                detail: strongestSignalDetail,
                actionRow: {
                    strongestSignalActions
                }
            )
            .modifier(DiscoveryDecisionSwipeModifier(
                gap: strongestSignalDecision,
                decisionsViewModel: decisionsViewModel,
                refresh: refreshFrontPageOnly
            ))

            frontPageBlock(
                eyebrow: "WAT ER TOE DEED",
                title: jacobMeaningTitle,
                detail: jacobMeaningDetail,
                primaryButtonTitle: "Zie geschiedenis",
                primaryAction: {
                    showMeaningHistory = true
                }
            )
        }
    }

    private var radarNewsSection: some View {
        InstrumentSectionPanel(
            eyebrow: "Nieuwslaag",
            title: "Wat vandaag oplicht",
            subtitle: "De vijf sterkste radar candidates in leesbare volgorde. Keur goed of wijs af via de governed frontier-flow.",
            accent: .jeevesLogoRed,
            metric: viewModel.isFrontPageLoading && viewModel.topDiscoveryDisplayItems.isEmpty ? "Laden" : nil
        ) {
            if viewModel.isFrontPageLoading && viewModel.topDiscoveryDisplayItems.isEmpty {
                ForEach(0..<3, id: \.self) { _ in
                    newspaperSkeletonCard
                }
            } else if viewModel.topDiscoveryDisplayItems.isEmpty {
                emptyState("De radar meldt nu geen nieuwe candidates.")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.topDiscoveryDisplayItems) { item in
                        radarNewsCard(item)
                    }
                }
            }
        }
    }

    private var waitBlockTitle: String {
        let count = viewModel.pendingProposals.count
        if count == 0 {
            return "Geen proposals in de queue"
        }
        return "\(count) proposal\(count == 1 ? "" : "s") open"
    }

    private var waitBlockDetail: String {
        viewModel.firstPendingProposal?.title ?? "De governance-queue is rustig."
    }

    private var strongestSignalTitle: String {
        guard let item = viewModel.strongestDiscoveryDisplay else {
            return "Nog geen sterk signaal"
        }
        return item.title
    }

    private var strongestSignalDetail: String {
        guard let item = viewModel.strongestDiscoveryDisplay else {
            return "De radar wacht op een nieuwe candidate."
        }
        return item.subtitle
    }

    private var jacobMeaningTitle: String {
        viewModel.firstMeaningItem?.title ?? "Jacob: nog geen beslissingen"
    }

    private var jacobMeaningDetail: String {
        viewModel.firstMeaningItem?.summary ?? "Er is nog geen impactvolle verschuiving geregistreerd."
    }

    private var strongestSignalDecision: GapProposal? {
        guard let strongest = viewModel.strongestDiscoveryDisplay?.candidate else { return nil }
        return viewModel.matchedDecision(for: strongest, from: decisionsViewModel.openDecisions)
    }

    @ViewBuilder
    private var strongestSignalActions: some View {
        if let strongest = viewModel.strongestDiscoveryDisplay?.candidate,
           let gap = viewModel.matchedDecision(for: strongest, from: decisionsViewModel.openDecisions) {
            HStack(spacing: 6) {
                newspaperDecisionButton(
                    systemImage: "checkmark",
                    tint: .consentGreen,
                    isLoading: decisionsViewModel.activeDecisionId == gap.id,
                    action: {
                        Task {
                            await decisionsViewModel.decide(gap, decision: "approve")
                            await refreshFrontPageOnly()
                        }
                    }
                )
                newspaperDecisionButton(
                    systemImage: "xmark",
                    tint: .consentRed,
                    isLoading: decisionsViewModel.activeDecisionId == gap.id,
                    action: {
                        Task {
                            await decisionsViewModel.decide(gap, decision: "deny")
                            await refreshFrontPageOnly()
                        }
                    }
                )
            }
        } else {
            Text("Nog niet in review")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func disciplineBannerText(_ discipline: Discipline) -> String {
        "\(discipline.displayLabel) actief · \(discipline.displayGapCount) gaps · score \(scoreLabel(discipline.effectiveAverageScore))"
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WAT IS JEEVES")
                .font(.system(size: 10, weight: .bold, design: .default))
                .foregroundStyle(Color.jeevesLogoRed)
                .tracking(0.8)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Jeeves scant onderzoek · detecteert collisies · wacht op jouw beslissing")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button("Begrepen →") {
                    introDismissed = true
                    showIntroOnRequest = false
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 0, maxHeight: 60, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.97, green: 0.98, blue: 0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.jeevesLogoRed.opacity(0.08), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private func frontPageBlock(
        eyebrow: String,
        title: String,
        detail: String,
        primaryButtonTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        @ViewBuilder actionRow: () -> some View = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.jeevesLogoRed)
                .tracking(0.8)

            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.jeevesInk)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.42, green: 0.42, blue: 0.42))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let primaryButtonTitle, let primaryAction {
                Button(primaryButtonTitle, action: primaryAction)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.jeevesLogoRed)
                    .buttonStyle(.plain)
            } else {
                actionRow()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.jeevesLogoRed.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func loadInitialContent() async {
        viewModel.configure(gateway: gateway)
        viewModel.loadCachedBieb(from: cachedBieb)
        decisionsViewModel.configure(gateway: gateway)

        async let latestLoad: String? = loadLatestIfNeeded()
        async let frontPageLoad: Void = loadFrontPageIfNeeded()
        async let decisionLoad: Void = loadDecisionsIfNeeded()
        async let disciplineLoad: Void = loadDisciplinesIfNeeded()
        let (latestPayload, _, _, _) = await (latestLoad, frontPageLoad, decisionLoad, disciplineLoad)
        if let latestPayload {
            cachedBieb = latestPayload
        }
    }

    private func refreshContent() async {
        viewModel.configure(gateway: gateway)
        decisionsViewModel.configure(gateway: gateway)

        async let latestRefresh: String? = viewModel.fetchLatest()
        async let frontPageRefresh: Void = viewModel.fetchFrontPage()
        async let decisionsRefresh: Void = decisionsViewModel.fetchOpenDecisions()
        async let disciplineRefresh: Void = disciplineViewModel.loadDisciplines()
        let (latestPayload, _, _, _) = await (latestRefresh, frontPageRefresh, decisionsRefresh, disciplineRefresh)
        if let latestPayload {
            cachedBieb = latestPayload
        }
    }

    private func loadLatestIfNeeded() async -> String? {
        guard viewModel.items.isEmpty else { return nil }
        return await viewModel.fetchLatest()
    }

    private func loadDisciplinesIfNeeded() async {
        guard disciplineViewModel.disciplines.isEmpty else { return }
        await disciplineViewModel.loadDisciplines()
    }

    private func loadFrontPageIfNeeded() async {
        guard viewModel.pendingProposals.isEmpty,
              viewModel.radarDiscoveries.isEmpty,
              viewModel.jacobMeaningItems.isEmpty else {
            return
        }
        await viewModel.fetchFrontPage()
    }

    private func loadDecisionsIfNeeded() async {
        guard decisionsViewModel.gaps.isEmpty else { return }
        await decisionsViewModel.fetchOpenDecisions()
    }

    private func refreshFrontPageOnly() async {
        async let frontPageRefresh: Void = viewModel.fetchFrontPage()
        async let decisionsRefresh: Void = decisionsViewModel.fetchOpenDecisions()
        _ = await (frontPageRefresh, decisionsRefresh)
    }

    @ViewBuilder
    private func biebCard(_ item: BiebLatestCell) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(gapHeadline(for: item))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.jeevesInk)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(contextLine(for: item))
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if viewModel.activeDecisionId == item.id {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.jeevesLogoRed)
                    }
                }
            }

            HStack {
                Spacer()

                HStack(spacing: 6) {
                    if let opportunityText = opportunityBadgeText(for: item) {
                        Text(opportunityText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(opportunityColor(for: item.opportunityLabel ?? ""))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(opportunityColor(for: item.opportunityLabel ?? "").opacity(0.14))
                            )
                    }

                    if let propertyText = propertyBadgeText(for: item) {
                        Text(propertyText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(propertyAxisColor(for: item.propertyAxis ?? ""))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(propertyAxisColor(for: item.propertyAxis ?? "").opacity(0.14))
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.jeevesLogoRed.opacity(0.12), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            selectedItem = item
        }
        .modifier(BiebDecisionSwipeModifier(item: item, viewModel: viewModel))
    }

    @ViewBuilder
    private func radarNewsCard(_ item: VandaagViewModel.DiscoveryDisplayItem) -> some View {
        let candidate = item.candidate
        let linkedDecision = viewModel.matchedDecision(for: candidate, from: decisionsViewModel.openDecisions)

        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.jeevesInk)
                .lineLimit(2)

            Text(item.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.4))
                .lineLimit(2)

            Text(relativeTimestampLabel(for: candidate))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let linkedDecision {
                HStack(spacing: 8) {
                    newspaperDecisionButton(
                        systemImage: "checkmark",
                        tint: .consentGreen,
                        isLoading: decisionsViewModel.activeDecisionId == linkedDecision.id,
                        action: {
                            Task {
                                await decisionsViewModel.decide(linkedDecision, decision: "approve")
                                await refreshFrontPageOnly()
                            }
                        }
                    )

                    newspaperDecisionButton(
                        systemImage: "xmark",
                        tint: .consentRed,
                        isLoading: decisionsViewModel.activeDecisionId == linkedDecision.id,
                        action: {
                            Task {
                                await decisionsViewModel.decide(linkedDecision, decision: "deny")
                                await refreshFrontPageOnly()
                            }
                        }
                    )
                }
            } else {
                Text("Nog niet in review")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.jeevesLogoRed.opacity(0.12), lineWidth: 1)
                )
        )
        .modifier(DiscoveryDecisionSwipeModifier(
            gap: linkedDecision,
            decisionsViewModel: decisionsViewModel,
            refresh: refreshFrontPageOnly
        ))
    }

    @ViewBuilder
    private func statusNotice(_ message: String, accent: Color) -> some View {
        Text(message)
            .font(.jeevesBody)
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(accent.opacity(0.14), lineWidth: 1)
                    )
            )
    }

    private func newspaperDecisionButton(
        systemImage: String,
        tint: Color,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    @ViewBuilder
    private func toastBanner(_ toast: VandaagViewModel.ToastMessage) -> some View {
        Text(toast.text)
            .font(.jeevesBody.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(toast.tone == .success ? Color.consentGreen : Color.consentRed)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
    }

    @ViewBuilder
    private func overviewStatCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.jeevesSubtleText)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.jeevesLogoRed)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.jeevesLogoRed.opacity(0.12), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.jeevesBody)
            .foregroundStyle(.secondary)
            .padding(.vertical, 10)
    }

    private var biebSkeletonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.gray.opacity(0.18))
                .frame(width: 176, height: 18)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.gray.opacity(0.14))
                .frame(maxWidth: .infinity)
                .frame(height: 14)

            HStack {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.gray.opacity(0.14))
                    .frame(width: 86, height: 24)
                Spacer()
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.gray.opacity(0.14))
                    .frame(width: 72, height: 24)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.jeevesLogoRed.opacity(0.08), lineWidth: 1)
                )
        )
        .redacted(reason: .placeholder)
    }

    private var newspaperSkeletonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.gray.opacity(0.18))
                .frame(width: 160, height: 18)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.gray.opacity(0.14))
                .frame(width: 124, height: 14)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.gray.opacity(0.12))
                .frame(width: 72, height: 12)

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.gray.opacity(0.14))
                    .frame(height: 28)
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.gray.opacity(0.14))
                    .frame(height: 28)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.jeevesLogoRed.opacity(0.08), lineWidth: 1)
                )
        )
        .redacted(reason: .placeholder)
    }

    private func scoreLabel(_ score: Double) -> String {
        String(format: "%.0f%%", min(max(score, 0), 1) * 100)
    }

    private func scoreText(for score: Double) -> String {
        String(format: "%.2f", score)
    }

    private func gapHeadline(for item: BiebLatestCell) -> String {
        let source = item.claim?.nilIfEmpty
            ?? item.hypothesis?.nilIfEmpty
            ?? item.title?.nilIfEmpty
            ?? item.label.nilIfEmpty
            ?? ""

        if isGenericTemplate(source) {
            return "\((item.domainLabel?.nilIfEmpty ?? item.domain.nilIfEmpty ?? "Onderzoek").capitalized) · Gap gedetecteerd"
        }

        let firstPart = source
            .components(separatedBy: CharacterSet(charactersIn: ".,"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? source

        let cleaned = firstPart
            .replacingOccurrences(of: "Signals clustered in ", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "Signals in ", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "indicate an ", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "indicates an ", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "indicate a ", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "indicates a ", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "ungoverned capability or ", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "ungoverned capability", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return truncate(cleaned.nilIfEmpty ?? item.displayTitle, maxLength: 60)
    }

    private func contextLine(for item: BiebLatestCell) -> String {
        let domain = (item.domainLabel?.nilIfEmpty ?? item.domain.nilIfEmpty ?? "ONDERZOEK").uppercased()

        if isGenericTemplate(item.claim?.nilIfEmpty ?? item.hypothesis?.nilIfEmpty ?? item.label) {
            return "\(domain) · Gap gedetecteerd · \(scoreLabel(item.score))"
        }

        let opportunity = item.opportunityLabel?.nilIfEmpty ?? "In beoordeling"
        return "\(domain) · \(scoreLabel(item.score)) · \(opportunity)"
    }

    private func isGenericTemplate(_ text: String?) -> Bool {
        guard let normalized = text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !normalized.isEmpty else {
            return true
        }

        return normalized.hasPrefix("signals clustered in")
            || normalized.hasPrefix("signals in")
    }

    private func relativeTimestampLabel(for candidate: RadarDiscoveryCandidate) -> String {
        guard let iso = poller.streamEvents.first(where: {
            $0.candidateId == candidate.candidateId || $0.id == candidate.candidateId
        })?.timestampIso,
              let date = ISO8601DateFormatter().date(from: iso) else {
            return "zojuist"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func truncate(_ value: String, maxLength: Int) -> String {
        guard value.count > maxLength else { return value }
        let prefix = String(value.prefix(maxLength))
        if let split = prefix.lastIndex(of: " ") {
            return String(prefix[..<split]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func domainColor(for domain: String) -> Color {
        let palette: [Color] = [.jeevesLogoRed, .jeevesSky, .jeevesMint, .jeevesGold, .jeevesTeal]
        let index = abs(domain.lowercased().hashValue) % palette.count
        return palette[index]
    }

    private func opportunityColor(for label: String) -> Color {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "vroeg stadium":
            return .consentGreen
        case "opkomend":
            return .orange
        case "verzadigd":
            return .gray
        default:
            return .jeevesSubtleText
        }
    }

    private func opportunityBadgeText(for item: BiebLatestCell) -> String? {
        guard let label = item.opportunityLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !label.isEmpty else {
            return nil
        }
        guard let score = item.opportunityScore else {
            return label
        }
        return "\(label) \(scoreLabel(score))"
    }

    private func propertyBadgeText(for item: BiebLatestCell) -> String? {
        let trimmed = item.propertyName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    private func propertyAxisColor(for axis: String) -> Color {
        switch axis.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "movement":
            return Color(red: 0.16, green: 0.50, blue: 0.73)
        case "structure":
            return Color(red: 0.56, green: 0.27, blue: 0.68)
        case "potential":
            return Color(red: 0.15, green: 0.68, blue: 0.38)
        default:
            return .jeevesSubtleText
        }
    }
}

private struct PendingProposalSheet: View {
    let proposals: [Proposal]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if proposals.isEmpty {
                Text("Er wachten nu geen proposals op uw oordeel.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(proposals) { proposal in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(proposal.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.jeevesInk)
                        if let score = proposal.priorityScore {
                            Text(String(format: "Prioriteit %.2f", score))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(proposal.status.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Wacht op u")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sluit") { dismiss() }
            }
        }
    }
}

private struct MeaningHistorySheet: View {
    let items: [JeevesKanaalMeaningItem]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if items.isEmpty {
                Text("Jacob heeft nog geen betekenisvolle verschuiving geregistreerd.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.jeevesInk)
                        Text(item.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Wat er toe deed")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sluit") { dismiss() }
            }
        }
    }
}

private struct DiscoveryDecisionSwipeModifier: ViewModifier {
    let gap: GapProposal?
    @ObservedObject var decisionsViewModel: BeslissingenViewModel
    let refresh: () async -> Void

    func body(content: Content) -> some View {
        if let gap {
            content
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Task {
                            await decisionsViewModel.decide(gap, decision: "approve")
                            await refresh()
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        Task {
                            await decisionsViewModel.decide(gap, decision: "deny")
                            await refresh()
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(.red)
                }
        } else {
            content
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct BiebDecisionSwipeModifier: ViewModifier {
    let item: BiebLatestCell
    @ObservedObject var viewModel: VandaagViewModel

    @State private var dragOffset: CGFloat = 0

    private let threshold: CGFloat = 80
    private let flingDistance: CGFloat = 420

    func body(content: Content) -> some View {
        if item.isDecisionCandidate {
            content
                .overlay {
                    swipeOverlay
                }
                .offset(x: dragOffset)
                .simultaneousGesture(dragGesture)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: dragOffset)
                .allowsHitTesting(viewModel.activeDecisionId != item.id)
        } else {
            content
        }
    }

    @ViewBuilder
    private var swipeOverlay: some View {
        if dragOffset != 0 {
            let isApprove = dragOffset > 0
            let tint = isApprove ? Color.consentGreen : Color.consentRed
            let alignment: Alignment = isApprove ? .leading : .trailing
            let progress = min(abs(dragOffset) / threshold, 1)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.16 + (0.16 * progress)))
                .overlay(alignment: alignment) {
                    Image(systemName: isApprove ? "checkmark" : "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.white)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(tint.opacity(0.9))
                        )
                        .padding(.horizontal, 16)
                        .opacity(max(0.35, progress))
                }
                .allowsHitTesting(false)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        dragOffset = 0
                    }
                    return
                }

                let finalOffset = value.translation.width
                guard abs(finalOffset) > threshold else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        dragOffset = 0
                    }
                    return
                }

                let decision = finalOffset > 0 ? "approve" : "deny"
                let targetOffset = finalOffset > 0 ? flingDistance : -flingDistance

                withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                    dragOffset = targetOffset
                }

                Task {
                    let succeeded = await viewModel.decide(item, decision: decision)
                    if !succeeded {
                        await MainActor.run {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                dragOffset = 0
                            }
                        }
                    }
                }
            }
    }
}
