import SwiftUI

struct BrowserMyAgentsView: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(GatewayManager.self) private var gateway

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !viewModel.bookmarkedCards.isEmpty {
                    bookmarkedSection
                }

                if !viewModel.watchedIntentions.isEmpty {
                    watchingSection
                }

                if viewModel.bookmarkedCards.isEmpty && viewModel.watchedIntentions.isEmpty {
                    emptyState
                }
            }
            .padding()
        }
    }

    // MARK: - Bookmarked

    private var bookmarkedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(Color.jeevesGold)
                    .font(.jeevesCaption)
                Text("BOOKMARKED")
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.bookmarkedCards.count)")
                    .font(.jeevesMono)
                    .foregroundStyle(Color.jeevesGold)
            }

            ForEach(viewModel.bookmarkedCards) { card in
                BrowserCertifiedCard(
                    card: card,
                    isBookmarked: true,
                    onInspect: { viewModel.openCard(card, gateway: gateway) },
                    onDeploy: { viewModel.requestDeployment(for: card) },
                    onBookmark: { viewModel.toggleBookmark(card.id) }
                )
            }
        }
    }

    // MARK: - Watching

    private var watchingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .foregroundStyle(.cyan)
                    .font(.jeevesCaption)
                Text("WATCHING")
                    .font(.jeevesCaption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.watchedIntentions.count)")
                    .font(.jeevesMono)
                    .foregroundStyle(.cyan)
            }

            ForEach(viewModel.watchedIntentions) { intention in
                BrowserEmergingCard(
                    intention: intention,
                    isWatched: true,
                    onExplore: { viewModel.openEmerging(intention) },
                    onWatch: { viewModel.toggleWatch(intention.intentionId) }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        JeevesEmptyState(
            icon: "person.crop.rectangle.stack",
            title: "Nog geen agenten opgeslagen.",
            subtitle: "Voeg bookmarks toe of volg emerging intentions vanuit de Marketplace."
        )
        .frame(height: 240)
    }
}
