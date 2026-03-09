import SwiftUI

struct AIBrowserView: View {
    @State private var viewModel = BrowserViewModel()
    @Environment(GatewayManager.self) private var gateway
    @Environment(ProposalPoller.self) private var poller

    var body: some View {
        NavigationStack {
            ZStack {
                browserBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    sectionPicker

                    Divider()
                        .overlay(Color.white.opacity(0.08))

                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    switch viewModel.selectedSection {
                    case .marketplace:
                        BrowserMarketplaceView(viewModel: viewModel)
                    case .deployments:
                        BrowserDeploymentsView(viewModel: viewModel)
                    case .myAgents:
                        BrowserMyAgentsView(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("AI Browser")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !viewModel.hasLoaded {
                    viewModel.loadFeed(gateway: gateway)
                }
            }
            .sheet(isPresented: $viewModel.showingConfigDetail) {
                if let card = viewModel.selectedCard {
                    ConfigurationDetailView(
                        card: card,
                        cachedConfig: viewModel.configurationCache[card.bestConfiguration.configId],
                        isBookmarked: viewModel.bookmarkedCardIds.contains(card.id),
                        onDeploy: {
                            viewModel.showingConfigDetail = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.requestDeployment(for: card)
                            }
                        },
                        onBookmark: { viewModel.toggleBookmark(card.id) }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showingEmergingDetail) {
                if let intention = viewModel.selectedEmergingIntention {
                    EmergingDetailView(
                        intention: intention,
                        relatedCertified: relatedCertifiedCards(for: intention),
                        isWatched: viewModel.watchedIntentionIds.contains(intention.intentionId),
                        onWatch: { viewModel.toggleWatch(intention.intentionId) },
                        onOpenCertified: { card in
                            viewModel.showingEmergingDetail = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.openCard(card, gateway: gateway)
                            }
                        }
                    )
                }
            }
            .sheet(item: $viewModel.showingDeploymentProposal) { request in
                DeploymentProposalSheet(
                    request: request,
                    isDeploying: viewModel.deployingConfigId == request.configId,
                    error: viewModel.deploymentError,
                    onSubmit: {
                        viewModel.submitDeployment(request: request, gateway: gateway, poller: poller)
                    },
                    onCancel: {
                        viewModel.showingDeploymentProposal = nil
                    }
                )
            }
            .alert("Deployment Error", isPresented: .constant(viewModel.deploymentError != nil && viewModel.showingDeploymentProposal == nil)) {
                Button("OK") { viewModel.deploymentError = nil }
            } message: {
                Text(viewModel.deploymentError ?? "")
            }
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(BrowserViewModel.Section.allCases) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedSection = section
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: sectionIcon(section))
                                .font(.caption)
                            Text(section.rawValue)
                                .font(.jeevesCaption.weight(.semibold))
                        }
                        .foregroundStyle(viewModel.selectedSection == section ? .white : .secondary)

                        Rectangle()
                            .fill(viewModel.selectedSection == section ? Color.jeevesGold : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func sectionIcon(_ section: BrowserViewModel.Section) -> String {
        switch section {
        case .marketplace: return "storefront"
        case .deployments: return "shippingbox.circle"
        case .myAgents: return "person.crop.rectangle.stack"
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Color.consentOrange)
            Text(error)
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry") {
                viewModel.loadFeed(gateway: gateway)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Related Cards

    private func relatedCertifiedCards(for intention: EmergingIntentionProfile) -> [BrowserCard] {
        viewModel.certifiedCards.filter {
            $0.domain.lowercased() == intention.domain.lowercased()
        }.prefix(5).map { $0 }
    }

    // MARK: - Background

    private var browserBackground: some View {
        ZStack {
            Color.houseDark

            LinearGradient(
                colors: [Color.black.opacity(0.3), .clear],
                startPoint: .top,
                endPoint: .center
            )

            RadialGradient(
                colors: [Color.cyan.opacity(0.06), .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 400
            )

            RadialGradient(
                colors: [Color.jeevesGold.opacity(0.04), .clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 400
            )
        }
    }
}
