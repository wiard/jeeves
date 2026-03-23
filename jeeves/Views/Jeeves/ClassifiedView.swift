import SwiftUI

struct ClassifiedView: View {
    @Environment(GatewayManager.self) private var gateway
    @StateObject private var viewModel = ClassifiedViewModel()
    @ObservedObject var beslissingenViewModel: BeslissingenViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                InstrumentBackdrop(
                    colors: [
                        Color(red: 0.97, green: 0.98, blue: 0.99),
                        Color(red: 0.96, green: 0.97, blue: 0.99),
                        Color(red: 0.95, green: 0.96, blue: 0.99)
                    ]
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        InstrumentRoleHeader(
                            eyebrow: "Radar Classification",
                            title: "Ontdekkingen",
                            summary: "Geclassificeerde ontdekkingen uit het radarsysteem, gesorteerd op kandidaatscore.",
                            accent: .jeevesSky,
                            metrics: [
                                InstrumentRoleMetric(label: "Totaal", value: "\(viewModel.items.count)"),
                                InstrumentRoleMetric(label: "Filter", value: viewModel.activeFilter)
                            ]
                        )

                        filterStrip

                        if let error = viewModel.error {
                            statusNotice(error)
                        }

                        InstrumentSectionPanel(
                            eyebrow: "Classified",
                            title: "Ontdekkingen",
                            subtitle: "Swipe rechts om goed te keuren, links om af te wijzen.",
                            accent: .jeevesSky,
                            metric: viewModel.filtered.isEmpty ? nil : "\(viewModel.filtered.count)"
                        ) {
                            if viewModel.isLoading && viewModel.items.isEmpty {
                                ProgressView("Ontdekkingen worden geladen...")
                                    .font(.jeevesBody)
                            } else if viewModel.filtered.isEmpty {
                                emptyState("Geen ontdekkingen gevonden voor dit filter.")
                            } else {
                                ForEach(viewModel.filtered) { discovery in
                                    discoveryCard(discovery)
                                        .swipeActions(edge: .trailing) {
                                            Button {
                                                Task {
                                                    await approveDiscovery(discovery)
                                                }
                                            } label: {
                                                Label("Goedkeuren", systemImage: "checkmark")
                                            }
                                            .tint(.consentGreen)
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                Task {
                                                    await dismissDiscovery(discovery)
                                                }
                                            } label: {
                                                Label("Afwijzen", systemImage: "xmark")
                                            }
                                            .tint(.consentRed)
                                        }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Ontdekkingen")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                viewModel.configure(gateway: gateway)
                if viewModel.items.isEmpty {
                    await viewModel.fetch()
                }
            }
            .refreshable {
                viewModel.configure(gateway: gateway)
                await viewModel.fetch()
            }
            .onChange(of: gateway.isConnected) {
                if gateway.isConnected {
                    Task {
                        viewModel.configure(gateway: gateway)
                        await viewModel.fetch()
                    }
                }
            }
        }
    }

    // MARK: - Filter Strip

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ClassifiedViewModel.outcomeTypes, id: \.self) { type in
                    filterChip(type, isActive: viewModel.activeFilter == type)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.activeFilter = type
                            }
                        }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func filterChip(_ label: String, isActive: Bool) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? .white : outcomeColor(label))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? outcomeColor(label) : outcomeColor(label).opacity(0.12))
            )
    }

    // MARK: - Discovery Card

    @ViewBuilder
    private func discoveryCard(_ discovery: ClassifiedDiscovery) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                outcomeBadge(discovery.outcomeType)
                domainBadge(discovery)
                Spacer()
                Text("Score: \(String(format: "%.2f", discovery.candidateScore))")
                    .font(.jeevesMono.weight(.bold))
                    .foregroundStyle(Color.jeevesInk)
            }

            Text(DiscoveryLanguage.headline(for: discovery))
                .font(.jeevesHeadline.weight(.semibold))
                .foregroundStyle(Color.jeevesInk)
                .lineLimit(2)

            Text(DiscoveryLanguage.actionHint(discovery.outcomeType))
                .font(.jeevesCaption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(outcomeColor(discovery.outcomeType).opacity(0.18), lineWidth: 1)
                )
        )
    }

    // MARK: - Badges

    @ViewBuilder
    private func outcomeBadge(_ type: String) -> some View {
        Text(type)
            .font(.caption.weight(.semibold))
            .foregroundStyle(outcomeColor(type))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(outcomeColor(type).opacity(0.12))
            )
    }

    @ViewBuilder
    private func domainBadge(_ discovery: ClassifiedDiscovery) -> some View {
        Text(DiscoveryLanguage.domainLabel(discovery.domainType))
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.jeevesTeal)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.jeevesTeal.opacity(0.12))
            )
    }

    private func outcomeColor(_ type: String) -> Color {
        switch type {
        case "GAP":         return .gray
        case "DISCOVERY":   return .blue
        case "OPPORTUNITY": return .green
        case "SURPRISE":    return .purple
        case "SURE_WIN":    return .jeevesGold
        default:            return .jeevesSky
        }
    }

    private func approveDiscovery(_ discovery: ClassifiedDiscovery) async {
        guard let api = await gateway.makeOperatorSurfacesAPI() else { return }
        _ = try? await api.decideProposal(proposalId: discovery.candidateId, decision: "approve")
        beslissingenViewModel.configure(gateway: gateway)
        await beslissingenViewModel.fetchOpenDecisions()
    }

    private func dismissDiscovery(_ discovery: ClassifiedDiscovery) async {
        guard let api = await gateway.makeOperatorSurfacesAPI() else { return }
        _ = try? await api.decideProposal(proposalId: discovery.candidateId, decision: "dismiss")
        beslissingenViewModel.configure(gateway: gateway)
        await beslissingenViewModel.fetchOpenDecisions()
    }

    @ViewBuilder
    private func statusNotice(_ message: String) -> some View {
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
                            .stroke(Color.jeevesSky.opacity(0.14), lineWidth: 1)
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
}
