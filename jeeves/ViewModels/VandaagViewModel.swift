import Foundation

@MainActor
final class VandaagViewModel: ObservableObject {
    struct ToastMessage: Equatable {
        enum Tone {
            case success
            case rejection
        }

        let text: String
        let tone: Tone
    }

    @Published var items: [BiebLatestCell] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var activeDecisionId: String?
    @Published var toast: ToastMessage?

    private weak var gateway: GatewayManager?
    private var gapProposalCache: [GapProposal] = []
    private var decisionTargetCache: [String: String] = [:]
    private var resolvedGapCache: [String: GapProposal] = [:]
    private var unavailableDecisionItems: Set<String> = []
    private let iso8601 = ISO8601DateFormatter()
    private let pdfSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()

    var topItems: [BiebLatestCell] {
        Array(items.sorted { $0.score > $1.score }.prefix(5))
    }

    var waitingCount: Int {
        items.count
    }

    func configure(gateway: GatewayManager) {
        self.gateway = gateway
    }

    func loadCachedBieb(from cachedValue: String) {
        guard !cachedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = cachedValue.data(using: .utf8),
              let cachedItems = try? JSONDecoder().decode([BiebLatestCell].self, from: data),
              !cachedItems.isEmpty else {
            return
        }

        items = cachedItems.sorted { $0.score > $1.score }
    }

    @discardableResult
    func fetchLatest() async -> String? {
        guard let gateway else {
            error = "De gateway is nog niet ingesteld."
            return nil
        }

        if isLoading {
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        guard let api = await gateway.makeOperatorSurfacesAPI() else {
            items = []
            error = gateway.useMock ? nil : "Geen conductor-token beschikbaar voor de Bieb."
            return nil
        }

        do {
            let response = try await api.fetchBiebLatest(limit: 12)
            let sortedItems = response.items.sorted { $0.score > $1.score }
            items = sortedItems
#if DEBUG
            if let first = sortedItems.first {
                print(
                    """
                    [Vandaag][Bieb] first item
                    hypothesis=\(first.hypothesis ?? "nil")
                    claim=\(first.claim ?? "nil")
                    title=\(first.title ?? "nil")
                    domainLabel=\(first.domainLabel ?? "nil")
                    opportunityLabel=\(first.opportunityLabel ?? "nil")
                    propertyName=\(first.propertyName ?? "nil")
                    score=\(first.score)
                    """
                )
            }
#endif
            gapProposalCache = []
            decisionTargetCache = [:]
            resolvedGapCache = [:]
            unavailableDecisionItems = []
            error = nil
            let data = try JSONEncoder().encode(sortedItems)
            return String(decoding: data, as: UTF8.self)
        } catch {
            if items.isEmpty {
                items = []
            }
            self.error = "De Bieb kon niet worden geladen."
            return nil
        }
    }

    @discardableResult
    func decide(_ item: BiebLatestCell, decision: String, reason: String? = nil) async -> Bool {
        guard let gateway else {
            error = "De gateway is nog niet ingesteld."
            return false
        }

        guard let api = await gateway.makeOperatorSurfacesAPI() else {
            error = "Geen conductor-token beschikbaar voor deze beslissing."
            return false
        }

        activeDecisionId = item.id
        defer { activeDecisionId = nil }

        do {
            guard let gapProposalId = try await resolveDecisionTarget(for: item, api: api) else {
                error = "Beslissing via Beslissingen tab."
                return false
            }

            let ack = try await api.decideGapProposal(
                gapProposalId: gapProposalId,
                decision: decision,
                reason: reason
            )
            guard ack.ok else {
                error = ack.reason ?? "De beslissing werd niet bevestigd."
                return false
            }

            items.removeAll { $0.id == item.id }
            error = nil
            showToast(for: decision)
            await fetchLatest()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func canAttemptDecision(for item: BiebLatestCell) -> Bool {
        item.isDecisionCandidate
    }

    func hasResolvedDecisionTarget(for item: BiebLatestCell) -> Bool {
        decisionTargetCache[item.id] != nil
    }

    func hasUnavailableDecisionTarget(for item: BiebLatestCell) -> Bool {
        unavailableDecisionItems.contains(item.id)
    }

    func resolveDecisionTarget(for item: BiebLatestCell) async -> String? {
        guard let gateway else { return nil }
        guard let api = await gateway.makeOperatorSurfacesAPI() else { return nil }
        return try? await resolveDecisionTarget(for: item, api: api)
    }

    func exportPDF(for item: BiebLatestCell) async throws -> URL {
        let gapId = try await resolveGapIdentifier(for: item)
        let data = try await fetchGapPDFData(gapId: gapId)
        let directory = try makeExportDirectory(named: "BiebExports")
        let baseName = sanitizedFilename(item.shortName?.nilIfEmpty ?? item.label)
        let fileURL = directory.appendingPathComponent("\(baseName)-\(gapId).pdf")
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func clearError() {
        error = nil
    }

    func dismissToast() {
        toast = nil
    }

    private func showToast(for decision: String) {
        let isApproval = decision == "approve"
        toast = ToastMessage(
            text: isApproval ? "Goedgekeurd" : "Afgewezen",
            tone: isApproval ? .success : .rejection
        )

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if toast?.text == (isApproval ? "Goedgekeurd" : "Afgewezen") {
                toast = nil
            }
        }
    }

    private func resolveDecisionTarget(for item: BiebLatestCell, api: OperatorSurfacesAPI) async throws -> String? {
        if let cached = decisionTargetCache[item.id] {
            return cached
        }
        if unavailableDecisionItems.contains(item.id) || !item.isDecisionCandidate {
            return nil
        }

        let gaps = try await loadGapProposals(api: api)

        let pendingGaps = gaps.filter(isResolvableGap)

        guard let match = matchGap(for: item, in: pendingGaps) else {
            unavailableDecisionItems.insert(item.id)
            return nil
        }

        decisionTargetCache[item.id] = match.gapProposalId
        return match.gapProposalId
    }

    private func resolveGap(for item: BiebLatestCell, api: OperatorSurfacesAPI) async throws -> GapProposal? {
        if let cached = resolvedGapCache[item.id] {
            return cached
        }

        let gaps = try await loadGapProposals(api: api)
        guard let match = matchGap(for: item, in: gaps) else {
            return nil
        }

        resolvedGapCache[item.id] = match
        return match
    }

    private func resolveGapIdentifier(for item: BiebLatestCell) async throws -> String {
        if let gapId = item.gapId?.trimmingCharacters(in: .whitespacesAndNewlines), !gapId.isEmpty {
            return gapId
        }
        guard let gateway else {
            throw OperatorSurfacesError(message: "De gateway is nog niet ingesteld.")
        }
        guard let api = await gateway.makeOperatorSurfacesAPI() else {
            throw OperatorSurfacesError(message: "Geen conductor-token beschikbaar voor PDF-export.")
        }
        guard let gap = try await resolveGap(for: item, api: api) else {
            throw OperatorSurfacesError(message: "PDF-export niet beschikbaar voor deze kaart.")
        }
        return gap.gapId
    }

    private func fetchGapPDFData(gapId: String) async throws -> Data {
        let url = URL(string: "http://clashd27.com/api/gaps/\(gapId)/pdf")!

        while true {
            var request = URLRequest(url: url, timeoutInterval: 30)
            request.httpMethod = "GET"
            request.setValue("application/pdf", forHTTPHeaderField: "Accept")

            let (data, response) = try await pdfSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw OperatorSurfacesError(message: "Geen geldig antwoord van de PDF-server.")
            }

            if (200...299).contains(http.statusCode) {
                return data
            }

            if http.statusCode == 404 {
                try await Task.sleep(for: .seconds(3))
                continue
            }

            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw OperatorSurfacesError(message: message?.nilIfEmpty ?? "De PDF kon niet worden opgehaald.")
        }
    }

    private func loadGapProposals(api: OperatorSurfacesAPI) async throws -> [GapProposal] {
        if gapProposalCache.isEmpty {
            let response = try await api.fetchGapProposals(limit: 150)
            gapProposalCache = response.gaps
        }
        return gapProposalCache
    }

    private func matchGap(for item: BiebLatestCell, in gaps: [GapProposal]) -> GapProposal? {
        let normalizedLabel = normalize(item.label)
        let normalizedHypothesis = normalize(item.hypothesis)

        if let sourceGapId = item.gapId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sourceGapId.isEmpty {
            let sourceMatches = gaps.filter { $0.sourcePacketId == sourceGapId }
            if let best = freshestGap(in: sourceMatches) {
                return best
            }
        }

        let titleMatches = gaps.filter { normalize($0.displayTitle) == normalizedLabel }
        if !titleMatches.isEmpty {
            let hypothesisMatches = titleMatches.filter { normalize($0.hypothesis) == normalizedHypothesis }
            return freshestGap(in: hypothesisMatches.isEmpty ? titleMatches : hypothesisMatches)
        }

        let hypothesisMatches = gaps.filter { normalize($0.hypothesis) == normalizedHypothesis }
        return freshestGap(in: hypothesisMatches)
    }

    private func freshestGap(in gaps: [GapProposal]) -> GapProposal? {
        gaps.max { lhs, rhs in
            let leftDate = parseDate(lhs.proposedAtIso ?? lhs.detectedAtIso)
            let rightDate = parseDate(rhs.proposedAtIso ?? rhs.detectedAtIso)
            if leftDate == rightDate {
                return (lhs.score ?? 0) < (rhs.score ?? 0)
            }
            return leftDate < rightDate
        }
    }

    private func isResolvableGap(_ gap: GapProposal) -> Bool {
        let normalizedStatus = gap.status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return normalizedStatus == "proposed" || normalizedStatus == "pending"
    }

    private func parseDate(_ isoString: String?) -> Date {
        guard let isoString,
              let date = iso8601.date(from: isoString) else {
            return .distantPast
        }
        return date
    }

    private func makeExportDirectory(named folderName: String) throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }

    private func sanitizedFilename(_ value: String) -> String {
        let invalid = CharacterSet.alphanumerics.inverted
        let cleaned = value
            .components(separatedBy: invalid)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .lowercased()
        return cleaned.isEmpty ? "bieb-export" : cleaned
    }

    private func normalize(_ text: String?) -> String {
        guard let text else { return "" }
        return text
            .replacingOccurrences(of: "Gap proposal:", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
