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
                    .font(.caption)
                Text("BOOKMARKED")
                    .font(.caption.weight(.semibold))
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
                    .font(.caption)
                Text("WATCHING")
                    .font(.caption.weight(.semibold))
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
        VStack(spacing: 8) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No saved agents")
                .font(.jeevesHeadline)
                .foregroundStyle(.white)
            Text("Bookmark certified configurations or watch emerging intentions from the Marketplace to see them here.")
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .browserPanel(padding: 16)
    }
}
