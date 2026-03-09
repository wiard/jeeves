import Foundation
import Observation

@MainActor
@Observable
final class BrowserViewModel {
    enum Section: String, CaseIterable, Identifiable {
        case marketplace = "Marketplace"
        case deployments = "Deployments"
        case myAgents = "My Agents"
        var id: String { rawValue }
    }

    enum BrowserDomain: String, CaseIterable, Identifiable {
        case financial, legal, research, education, automation, security, creativity
        var id: String { rawValue }

        var title: String { rawValue.capitalized }

        var icon: String {
            switch self {
            case .financial: return "chart.line.uptrend.xyaxis"
            case .legal: return "scroll"
            case .research: return "atom"
            case .education: return "graduationcap"
            case .automation: return "gearshape.2"
            case .security: return "lock.shield"
            case .creativity: return "paintbrush"
            }
        }

        var defaultSubdomains: [String] {
            switch self {
            case .financial: return ["investing", "payments", "treasury", "risk"]
            case .legal: return ["contracts", "compliance", "policy"]
            case .research: return ["literature", "benchmarking", "hypothesis"]
            case .education: return ["tutoring", "curriculum", "assessment"]
            case .automation: return ["workflow", "orchestration", "planning"]
            case .security: return ["threat-detection", "identity", "incident-response"]
            case .creativity: return ["writing", "design", "synthesis"]
            }
        }

        var defaultRisk: String {
            switch self {
            case .financial, .legal, .education: return "low"
            case .research, .automation, .creativity: return "medium"
            case .security: return "high"
            }
        }
    }

    // MARK: - Navigation

    var selectedSection: Section = .marketplace
    var selectedCategory: BrowserDomain?
    var selectedSubdomain: String?
    var selectedCard: BrowserCard?
    var selectedEmergingIntention: EmergingIntentionProfile?
    var showingDeploymentProposal: DeployConfigurationRequest?
    var showingConfigDetail = false
    var showingEmergingDetail = false

    // MARK: - Data

    var feed: SafeClashBrowserFeed?
    var searchResults: [IntentionProfile] = []
    var emergingIntentions: [EmergingIntentionProfile] = []
    var configurationCache: [String: AIConfigurationAtom] = [:]

    // MARK: - Loading State

    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var statusMessage: String?

    // MARK: - Deployment

    var deployingConfigId: String?
    var lastCreatedProposalId: String?
    var deploymentError: String?

    // MARK: - My Agents

    var watchedIntentionIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "browser.watched") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "browser.watched") }
    }

    var bookmarkedCardIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "browser.bookmarked") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "browser.bookmarked") }
    }

    // MARK: - Computed

    var featuredCards: [BrowserCard] {
        guard let feed else { return [] }
        return feed.featured.map { BrowserCard(certified: $0) }
    }

    var certifiedCards: [BrowserCard] {
        guard let feed else {
            return searchResults.map { BrowserCard(profile: $0) }
        }
        return feed.certified.map { BrowserCard(certified: $0) }
    }

    var filteredCertifiedCards: [BrowserCard] {
        let cards = certifiedCards
        guard let category = selectedCategory else { return cards }
        let domain = category.rawValue.lowercased()
        let filtered = cards.filter { $0.domain.lowercased() == domain }
        guard let sub = selectedSubdomain?.lowercased(), !sub.isEmpty else { return filtered }
        let subFiltered = filtered.filter { $0.subdomain.lowercased() == sub }
        return subFiltered.isEmpty ? filtered : subFiltered
    }

    var filteredEmergingIntentions: [EmergingIntentionProfile] {
        let all: [EmergingIntentionProfile]
        if let feed {
            all = feed.emerging.map(\.profile)
        } else {
            all = emergingIntentions
        }
        guard let category = selectedCategory else { return all }
        let domain = category.rawValue.lowercased()
        return all.filter { $0.domain.lowercased() == domain }
    }

    var feedCategories: [SafeClashBrowserCategory] {
        feed?.categories ?? []
    }

    var watchedIntentions: [EmergingIntentionProfile] {
        let all: [EmergingIntentionProfile]
        if let feed {
            all = feed.emerging.map(\.profile)
        } else {
            all = emergingIntentions
        }
        return all.filter { watchedIntentionIds.contains($0.intentionId) }
    }

    var bookmarkedCards: [BrowserCard] {
        certifiedCards.filter { bookmarkedCardIds.contains($0.id) }
    }

    // MARK: - Guidance

    func guidanceBrief(
        certifiedCards: [BrowserCard],
        emergingCards: [EmergingIntentionProfile]
    ) -> BrowserGuidanceBrief {
        var clear: [String] = []
        var uncertain: [String] = []
        var options: [String] = []
        var why: [String] = []
        var next: [String] = []

        let bestState: BrowserUncertaintyState
        if let top = certifiedCards.first {
            bestState = top.uncertaintyState
        } else if !emergingCards.isEmpty {
            bestState = .exploratory
        } else {
            bestState = .unknown
        }

        if certifiedCards.isEmpty && emergingCards.isEmpty {
            clear.append("No configurations match the current filters.")
            uncertain.append("The registry may not yet contain entries for this domain.")
            next.append("Try a broader category or check back after new discoveries.")
            return BrowserGuidanceBrief(state: .unknown, clear: clear, uncertain: uncertain, options: options, why: why, next: next)
        }

        if !certifiedCards.isEmpty {
            let top = certifiedCards.prefix(3)
            clear.append("\(certifiedCards.count) certified configuration(s) available.")
            for card in top {
                options.append("\(card.title) — \(card.uncertaintyState.rawValue), score \(String(format: "%.2f", card.rankingScore))")
            }
            why.append("Based on SafeClash certification registry and benchmark contracts.")
        }

        if !emergingCards.isEmpty {
            uncertain.append("\(emergingCards.count) emerging intention(s) detected by CLASHD27, not yet certified.")
            next.append("Watch emerging intentions for certification updates.")
        }

        if let best = certifiedCards.first, best.deployReady {
            next.insert("Deploy \(best.title) for immediate governed use.", at: 0)
        }

        return BrowserGuidanceBrief(state: bestState, clear: clear, uncertain: uncertain, options: options, why: why, next: next)
    }

    // MARK: - Actions

    func loadFeed(gateway: GatewayManager) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let client = makeSafeClashClient(gateway: gateway)

                if let browserFeed = try? await client.fetchBrowserFeed() {
                    var cache: [String: AIConfigurationAtom] = [:]
                    for item in browserFeed.certified {
                        cache[item.configId] = item.configurationAtom
                    }
                    feed = browserFeed
                    searchResults = browserFeed.certified.map(\.profile)
                    emergingIntentions = browserFeed.emerging.map(\.profile)
                    configurationCache.merge(cache) { _, new in new }
                    statusMessage = "Browser feed loaded: \(browserFeed.featured.count) featured, \(browserFeed.certified.count) certified, \(browserFeed.emerging.count) emerging."
                } else {
                    let emerging = try? await client.fetchEmergingIntentions()
                    emergingIntentions = emerging ?? []
                    statusMessage = "Emerging intentions loaded (\(emergingIntentions.count))."
                }
                hasLoaded = true
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = describeError(error, gateway: gateway)
            }
        }
    }

    func searchCategory(domain: String, subdomain: String, risk: String, gateway: GatewayManager) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let client = makeSafeClashClient(gateway: gateway)

                if let browserFeed = try? await client.fetchBrowserFeed(
                    domain: domain,
                    subdomain: subdomain,
                    risk: risk
                ) {
                    var cache: [String: AIConfigurationAtom] = [:]
                    for item in browserFeed.certified {
                        cache[item.configId] = item.configurationAtom
                    }
                    feed = browserFeed
                    searchResults = browserFeed.certified.map(\.profile)
                    emergingIntentions = browserFeed.emerging.map(\.profile)
                    configurationCache.merge(cache) { _, new in new }
                    isLoading = false
                    return
                }

                let results = try await client.searchIntentions(
                    domain: domain,
                    subdomain: subdomain,
                    risk: risk
                )
                let emerging = try? await client.fetchEmergingIntentions(
                    domain: domain,
                    subdomain: subdomain,
                    risk: risk
                )
                searchResults = results
                emergingIntentions = emerging ?? []
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = describeError(error, gateway: gateway)
            }
        }
    }

    func fetchConfiguration(configId: String, gateway: GatewayManager) {
        guard configurationCache[configId] == nil else { return }

        Task {
            let client = makeSafeClashClient(gateway: gateway)
            if let config = try? await client.getConfiguration(configId: configId) {
                configurationCache[configId] = config
            }
        }
    }

    func openCard(_ card: BrowserCard, gateway: GatewayManager) {
        selectedCard = card
        showingConfigDetail = true
        fetchConfiguration(configId: card.bestConfiguration.configId, gateway: gateway)
    }

    func openEmerging(_ intention: EmergingIntentionProfile) {
        selectedEmergingIntention = intention
        showingEmergingDetail = true
    }

    func requestDeployment(for card: BrowserCard) {
        guard card.deployReady else {
            deploymentError = "This configuration is not deploy-ready yet."
            return
        }
        let config = configurationCache[card.bestConfiguration.configId] ?? card.bestConfiguration
        showingDeploymentProposal = DeployConfigurationRequest(
            intentionId: card.intentionId,
            intentionTitle: card.title,
            domain: card.domain,
            subdomain: card.subdomain,
            riskProfile: card.riskProfile,
            configId: config.configId,
            model: config.model,
            certificationLevel: config.certificationLevel,
            certificateId: config.certificateId,
            rankingScore: card.rankingScore,
            benchmarkScore: config.benchmarkScore,
            benchmarkContractId: config.benchmarkContract,
            runtimeEnvelopeHash: config.runtimeEnvelopeHash,
            promptArchitectureReference: config.promptArchitectureReference,
            capabilities: config.capabilities,
            constraints: [:],
            whyEligible: card.whyRecommended,
            source: "ai_browser"
        )
    }

    func submitDeployment(request: DeployConfigurationRequest, gateway: GatewayManager, poller: ProposalPoller) {
        guard deployingConfigId == nil else { return }
        deployingConfigId = request.configId
        lastCreatedProposalId = nil
        deploymentError = nil

        Task {
            let host = gateway.host.isEmpty ? "localhost" : gateway.host
            let port = gateway.port > 0 ? gateway.port : 19001
            guard let token = gateway.token, !token.isEmpty else {
                deployingConfigId = nil
                deploymentError = "No token available. Add a token in Settings."
                return
            }

            let client = GatewayClient(host: host, port: port, token: token)
            do {
                let response = try await client.deployCertifiedConfiguration(deployment: request)
                await poller.refresh(gateway: gateway)
                deployingConfigId = nil
                lastCreatedProposalId = response.proposalId
                showingDeploymentProposal = nil
                statusMessage = response.summary ?? "Governed deployment proposal created."
            } catch {
                deployingConfigId = nil
                deploymentError = describeError(error, gateway: gateway)
            }
        }
    }

    func toggleWatch(_ intentionId: String) {
        if watchedIntentionIds.contains(intentionId) {
            watchedIntentionIds.remove(intentionId)
        } else {
            watchedIntentionIds.insert(intentionId)
        }
    }

    func toggleBookmark(_ cardId: String) {
        if bookmarkedCardIds.contains(cardId) {
            bookmarkedCardIds.remove(cardId)
        } else {
            bookmarkedCardIds.insert(cardId)
        }
    }

    // MARK: - Private

    private func makeSafeClashClient(gateway: GatewayManager) -> SafeClashClient {
        let token = gateway.token?.trimmingCharacters(in: .whitespacesAndNewlines)
        return SafeClashClient(
            baseURL: resolveSafeClashBaseURL(gateway: gateway),
            token: (token?.isEmpty == false) ? token : nil
        )
    }

    private func resolveSafeClashBaseURL(gateway: GatewayManager) -> URL {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["SAFECLASH_BASE_URL"] ?? env["SAFECLASH_URL"],
           let url = URL(string: raw),
           let scheme = url.scheme,
           (scheme == "http" || scheme == "https"),
           url.host != nil {
            return url
        }

        var components = URLComponents()
        components.scheme = "http"
        if !gateway.host.isEmpty, gateway.host.lowercased() != "mock" {
            components.host = gateway.host
            components.port = gateway.port > 0 ? gateway.port : 19001
        } else if let runtimeHost = RuntimeConfig.shared.host {
            components.host = runtimeHost
            components.port = RuntimeConfig.shared.port ?? 19001
        } else {
            components.host = "localhost"
            components.port = 19001
        }
        return components.url ?? URL(string: "http://localhost:19001")!
    }

    private func describeError(_ error: Error, gateway: GatewayManager) -> String {
        if case SafeClashClientError.httpStatus(let status) = error {
            return "SafeClash returned HTTP \(status)."
        }
        if gateway.useMock || gateway.host.lowercased() == "mock" {
            return "Mock mode: \(error.localizedDescription)"
        }
        return error.localizedDescription
    }
}
