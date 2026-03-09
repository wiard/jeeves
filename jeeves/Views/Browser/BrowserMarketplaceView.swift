import SwiftUI

struct BrowserMarketplaceView: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(GatewayManager.self) private var gateway

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                searchBar

                if viewModel.usingStaleFallbackFeed {
                    fallbackIndicator
                }

                if !viewModel.featuredCards.isEmpty {
                    featuredSection
                }

                categoriesSection

                if viewModel.selectedCategory != nil {
                    subdomainFilter
                }

                guidanceSection

                certifiedSection

                emergingSection

                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
    }

    // MARK: - Search

    @State private var searchText = ""

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search configurations...", text: $searchText)
                .font(.jeevesBody)
                .foregroundStyle(.white)
                .textFieldStyle(.plain)
                .onSubmit {
                    if !searchText.isEmpty {
                        viewModel.searchCategory(
                            domain: searchText.lowercased(),
                            subdomain: "",
                            risk: "",
                            gateway: gateway
                        )
                    }
                }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Featured

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "FEATURED", icon: "star.fill", count: viewModel.featuredCards.count, tint: .jeevesGold)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.featuredCards) { card in
                        BrowserFeaturedCard(
                            card: card,
                            isDeploying: viewModel.deployingConfigId == card.bestConfiguration.configId,
                            onInspect: { viewModel.openCard(card, gateway: gateway) },
                            onDeploy: { viewModel.requestDeployment(for: card) }
                        )
                        .frame(width: 320)
                    }
                }
            }
        }
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "CATEGORIES", icon: "square.grid.2x2", count: BrowserViewModel.BrowserDomain.allCases.count, tint: .cyan)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(BrowserViewModel.BrowserDomain.allCases) { category in
                    BrowserCategoryTile(
                        category: category,
                        certifiedCount: certifiedCount(for: category),
                        emergingCount: emergingCount(for: category),
                        isSelected: viewModel.selectedCategory == category,
                        onTap: { selectCategory(category) }
                    )
                }
            }
        }
    }

    private func selectCategory(_ category: BrowserViewModel.BrowserDomain) {
        if viewModel.selectedCategory == category {
            viewModel.selectedCategory = nil
            viewModel.selectedSubdomain = nil
        } else {
            viewModel.selectedCategory = category
            viewModel.selectedSubdomain = nil
            viewModel.searchCategory(
                domain: category.rawValue,
                subdomain: "",
                risk: category.defaultRisk,
                gateway: gateway
            )
        }
    }

    private func certifiedCount(for category: BrowserViewModel.BrowserDomain) -> Int {
        if let feedCat = viewModel.feedCategories.first(where: { $0.domain.lowercased() == category.rawValue }) {
            return feedCat.certifiedCount ?? 0
        }
        return viewModel.certifiedCards.filter { $0.domain.lowercased() == category.rawValue }.count
    }

    private func emergingCount(for category: BrowserViewModel.BrowserDomain) -> Int {
        if let feedCat = viewModel.feedCategories.first(where: { $0.domain.lowercased() == category.rawValue }) {
            return feedCat.emergingCount ?? 0
        }
        let all: [EmergingIntentionProfile]
        if let feed = viewModel.feed {
            all = feed.emerging.map(\.profile)
        } else {
            all = viewModel.emergingIntentions
        }
        return all.filter { $0.domain.lowercased() == category.rawValue }.count
    }

    // MARK: - Subdomain Filter

    private var subdomainFilter: some View {
        Group {
            if let category = viewModel.selectedCategory {
                let subdomains = resolveSubdomains(for: category)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        subdomainChip("All", isSelected: viewModel.selectedSubdomain == nil) {
                            viewModel.selectedSubdomain = nil
                        }
                        ForEach(subdomains, id: \.self) { sub in
                            subdomainChip(sub.capitalized, isSelected: viewModel.selectedSubdomain == sub) {
                                viewModel.selectedSubdomain = sub
                            }
                        }
                    }
                }
            }
        }
    }

    private func resolveSubdomains(for category: BrowserViewModel.BrowserDomain) -> [String] {
        if let feedCat = viewModel.feedCategories.first(where: { $0.domain.lowercased() == category.rawValue }) {
            return feedCat.subdomains
        }
        return category.defaultSubdomains
    }

    private func subdomainChip(_ text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.jeevesCaption.weight(.medium))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.cyan.opacity(0.28) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.cyan.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Guidance

    private var guidanceSection: some View {
        let certified = viewModel.filteredCertifiedCards
        let emerging = viewModel.filteredEmergingIntentions
        let brief = viewModel.guidanceBrief(certifiedCards: certified, emergingCards: emerging)

        return BrowserGuidanceBriefView(brief: brief)
    }

    // MARK: - Certified

    private var certifiedSection: some View {
        let cards = viewModel.filteredCertifiedCards

        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "CERTIFIED", icon: "checkmark.seal.fill", count: cards.count, tint: .consentGreen)

            if viewModel.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading certified configurations...")
                        .font(.jeevesCaption)
                        .foregroundStyle(.secondary)
                }
                .browserPanel(padding: 12)
            } else if cards.isEmpty {
                Text("No certified configurations found for current filters.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .browserPanel(padding: 12)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(cards) { card in
                        BrowserCertifiedCard(
                            card: card,
                            isBookmarked: viewModel.bookmarkedCardIds.contains(card.id),
                            onInspect: { viewModel.openCard(card, gateway: gateway) },
                            onDeploy: { viewModel.requestDeployment(for: card) },
                            onBookmark: { viewModel.toggleBookmark(card.id) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Emerging

    private var emergingSection: some View {
        let intentions = viewModel.filteredEmergingIntentions

        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "EMERGING", icon: "sparkles", count: intentions.count, tint: .consentOrange)

            if intentions.isEmpty && !viewModel.isLoading {
                Text("No emerging intentions detected for current filters.")
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
                    .browserPanel(padding: 12)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(intentions) { intention in
                        BrowserEmergingCard(
                            intention: intention,
                            isWatched: viewModel.watchedIntentionIds.contains(intention.intentionId),
                            onExplore: { viewModel.openEmerging(intention) },
                            onWatch: { viewModel.toggleWatch(intention.intentionId) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.caption)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.jeevesMono)
                .foregroundStyle(tint)
        }
    }

    // MARK: - Fallback Indicator

    private var fallbackIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundStyle(Color.consentOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Using cached data")
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Latest request failed. Showing saved browser feed.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .browserPanel(padding: 10)
    }

    // MARK: - Error

    @ViewBuilder
    var errorBanner: some View {
        if let error = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Color.consentOrange)
                Text(error)
                    .font(.jeevesCaption)
                    .foregroundStyle(.secondary)
            }
            .browserPanel(padding: 10)
        }
    }
}
