import Foundation

@MainActor
final class ResearchViewModel: ObservableObject {
    @Published var domains: [ResearchDomain] = []
    @Published var domainInsights: [String: ResearchDomainInsight] = [:]
    @Published var activeJob: ResearchJob?
    @Published var jobStatus: ResearchJobStatus?
    @Published var isRunning: Bool = false
    @Published var error: String?
    @Published var exportingGapId: String?
    @Published var isExportingAllPDFs = false

    private weak var gateway: GatewayManager?
    private var pollingTask: Task<Void, Never>?
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration)
    }

    var canExportPDFs: Bool {
        !resultGaps.isEmpty
    }

    var resultGaps: [ResearchGapCard] {
        let domainId = jobStatus?.domainId ?? activeJob?.domainId
        guard let domainId else { return [] }
        return domainInsights[domainId]?.topGaps ?? []
    }

    func configure(gateway: GatewayManager) {
        self.gateway = gateway
    }

    func loadDomains() async {
        do {
            let token = await operatorToken()
            let data = try await fetchData(
                urls: [
                    Self.domainsURL,
                    Self.domainsFallbackURL
                ],
                token: token,
                requiresToken: false
            )
            let fetchedDomains = try ResearchDomainsResponse.decode(from: data)
            domains = fetchedDomains
            error = nil
            await refreshDomainInsights(for: fetchedDomains)
        } catch {
            domains = []
            domainInsights = [:]
            self.error = friendlyError(error, fallback: "De onderzoeksdomeinen konden niet worden geladen.")
        }
    }

    func startResearch(domainId: String) async {
        stopPolling()

        guard let gateway else {
            error = "De gateway is nog niet ingesteld."
            return
        }

        let token = await gateway.resolveEndpoint().token
        guard let token, !token.isEmpty else {
            error = "Geen conductor-token beschikbaar voor onderzoek."
            return
        }

        do {
            let body = try JSONEncoder().encode(ResearchStartBody(domainId: domainId))
            let data = try await fetchData(
                url: Self.startResearchURL,
                method: "POST",
                token: token,
                body: body,
                requiresToken: true
            )
            let job = try ResearchJob.decode(from: data, fallbackDomainId: domainId)
            activeJob = job
            jobStatus = ResearchJobStatus(
                jobId: job.id,
                status: "running",
                phaseText: "Collecting papers...",
                foundGapCount: domainInsights[domainId]?.gapCount ?? 0,
                domainId: job.domainId,
                domainName: job.domainName,
                gapIds: []
            )
            isRunning = true
            error = nil
            updateActivitySummary()
            startPollingLoop()
            await pollStatus()
        } catch {
            self.error = friendlyError(error, fallback: "Het onderzoek kon niet worden gestart.")
            isRunning = false
            ResearchActivityStore.shared.summary = nil
        }
    }

    func pollStatus() async {
        guard let job = activeJob else { return }
        guard let gateway else {
            error = "De gateway is nog niet ingesteld."
            stopPolling()
            return
        }

        let token = await gateway.resolveEndpoint().token
        guard let token, !token.isEmpty else {
            error = "Geen conductor-token beschikbaar voor onderzoek."
            stopPolling()
            return
        }

        do {
            let url = Self.statusBaseURL.appendingPathComponent(job.id)
            let data = try await fetchData(url: url, token: token, requiresToken: true)
            let status = try ResearchJobStatus.decode(from: data, jobId: job.id)
            jobStatus = status
            error = nil
            if let domainId = status.domainId ?? activeJob?.domainId {
                await refreshDomainInsight(for: domainId)
            }
            if status.isComplete {
                isRunning = false
                stopPolling()
                ResearchActivityStore.shared.summary = nil
            } else {
                isRunning = true
                updateActivitySummary()
            }
        } catch {
            self.error = friendlyError(error, fallback: "De onderzoeksstatus kon niet worden bijgewerkt.")
        }
    }

    func cancelTracking() {
        stopPolling()
        activeJob = nil
        jobStatus = nil
        isRunning = false
        error = nil
        ResearchActivityStore.shared.summary = nil
    }

    func exportAllPDFs() async throws -> [URL] {
        let gaps = resultGaps
        guard !gaps.isEmpty else {
            throw OperatorSurfacesError(message: "Nog geen PDFs beschikbaar voor dit onderzoek.")
        }

        isExportingAllPDFs = true
        defer { isExportingAllPDFs = false }

        let exportDirectory = try makeExportDirectory(named: "ResearchExports")
        let baseName = sanitizedFilename(jobStatus?.displayDomainName ?? activeJob?.domainName ?? "research-export")
        var exportedURLs: [URL] = []

        for (index, gap) in gaps.enumerated() {
            let data = try await fetchGapPDFData(gapId: gap.id)
            let fileURL = exportDirectory.appendingPathComponent("\(baseName)-\(index + 1).pdf")
            try data.write(to: fileURL, options: [.atomic])
            exportedURLs.append(fileURL)
        }

        return exportedURLs
    }

    func exportPDF(for gap: ResearchGapCard) async throws -> URL {
        exportingGapId = gap.id
        defer { exportingGapId = nil }

        let data = try await fetchGapPDFData(gapId: gap.id)
        let directory = try makeExportDirectory(named: "ResearchExports")
        let baseName = sanitizedFilename(gap.title)
        let fileURL = directory.appendingPathComponent("\(baseName)-\(gap.id).pdf")
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    deinit {
        pollingTask?.cancel()
        session.invalidateAndCancel()
    }

    private func updateActivitySummary() {
        guard isRunning else {
            ResearchActivityStore.shared.summary = nil
            return
        }

        let domainId = jobStatus?.domainId ?? activeJob?.domainId
        let domainLabel = jobStatus?.domainName ?? activeJob?.domainName ?? domains.first(where: { $0.id == domainId })?.displayName
        guard let domainId, let domainLabel else {
            ResearchActivityStore.shared.summary = nil
            return
        }

        let insight = domainInsights[domainId]
        let gapCount = max(jobStatus?.foundGapCount ?? 0, insight?.gapCount ?? 0)
        ResearchActivityStore.shared.summary = ResearchActivitySummary(
            domainId: domainId,
            domainLabel: domainLabel,
            gapCount: gapCount,
            lastGapDate: insight?.lastGapDate
        )
    }

    private func refreshDomainInsights(for domains: [ResearchDomain]) async {
        var updated: [String: ResearchDomainInsight] = [:]
        for domain in domains {
            if let insight = try? await fetchDomainInsight(domainId: domain.id) {
                updated[domain.id] = insight
            }
        }
        domainInsights = updated
        updateActivitySummary()
    }

    private func refreshDomainInsight(for domainId: String) async {
        guard let insight = try? await fetchDomainInsight(domainId: domainId) else { return }
        domainInsights[domainId] = insight
        updateActivitySummary()
    }

    private func fetchDomainInsight(domainId: String) async throws -> ResearchDomainInsight {
        let components = [
            URLQueryItem(name: "domain", value: domainId),
            URLQueryItem(name: "count", value: "true")
        ]
        let data = try await fetchData(url: Self.gapsURL, queryItems: components)
        return try parseDomainInsight(from: data, domainId: domainId)
    }

    private func parseDomainInsight(from data: Data, domainId: String) throws -> ResearchDomainInsight {
        let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard let root = json as? [String: Any] else {
            throw OperatorSurfacesError(message: "De gap-pipeline gaf een onleesbaar antwoord terug.")
        }

        let rows = (root["gaps"] as? [[String: Any]]) ?? []
        let cards = rows.compactMap(parseResearchGap)
            .sorted { $0.scoreFraction > $1.scoreFraction }
        let total = (root["total"] as? NSNumber)?.intValue ?? cards.count
        let lastDate = cards.compactMap(\.detectedAt).max()
        let averageScore = cards.isEmpty
            ? 0
            : cards.map(\.scoreFraction).reduce(0, +) / Double(cards.count)

        return ResearchDomainInsight(
            domainId: domainId,
            gapCount: total,
            lastGapDate: lastDate,
            averageScore: averageScore,
            topGaps: Array(cards.prefix(3))
        )
    }

    private func parseResearchGap(row: [String: Any]) -> ResearchGapCard? {
        guard let id = string(in: row, keys: ["id", "gapId", "gap_id"]),
              let title = string(in: row, keys: ["title", "label", "name"]) else {
            return nil
        }

        let hypothesis = string(in: row, keys: ["claim", "hypothesis", "summary", "description"])
            ?? "Deze gap heeft nog geen hypothese-preview."
        let score = number(in: row, keys: ["score", "confidence", "weight"]) ?? 0

        return ResearchGapCard(
            id: id,
            title: title,
            hypothesis: hypothesis,
            score: score,
            domainId: string(in: row, keys: ["domainId", "domain_id", "corridor"]),
            domainLabel: string(in: row, keys: ["domainLabel", "domain_label", "corridor"]),
            detectedAt: string(in: row, keys: ["date", "detectedAtIso", "detected_at_iso", "createdAtIso"])
        )
    }

    private func fetchGapPDFData(gapId: String) async throws -> Data {
        while true {
            do {
                return try await fetchData(url: Self.gapsURL.appendingPathComponent("\(gapId)/pdf"))
            } catch let error as HTTPStatusError where error.statusCode == 404 {
                try await Task.sleep(for: .seconds(3))
                continue
            }
        }
    }

    private func fetchData(
        urls: [URL],
        method: String = "GET",
        token: String? = nil,
        body: Data? = nil,
        requiresToken: Bool = false
    ) async throws -> Data {
        var lastError: Error = OperatorSurfacesError(message: "De research-feed is niet bereikbaar.")
        for url in urls {
            do {
                return try await fetchData(url: url, method: method, token: token, body: body, requiresToken: requiresToken)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private func fetchData(
        url: URL,
        method: String = "GET",
        token: String? = nil,
        body: Data? = nil,
        requiresToken: Bool = false,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = queryItems
        if requiresToken, let token, !token.isEmpty {
            items.insert(URLQueryItem(name: "token", value: token), at: 0)
        }
        components?.queryItems = items.isEmpty ? nil : items

        guard let resolvedURL = components?.url else {
            throw OperatorSurfacesError(message: "De research-route kon niet worden opgebouwd.")
        }

        var request = URLRequest(url: resolvedURL, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token, requiresToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OperatorSurfacesError(message: "Geen geldig antwoord van de server.")
        }
        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw HTTPStatusError(statusCode: http.statusCode, message: text?.nilIfEmpty ?? "De server weigerde deze actie.")
        }
        return data
    }

    private func operatorToken() async -> String? {
        guard let gateway else { return nil }
        return await gateway.resolveEndpoint().token
    }

    private func startPollingLoop() {
        stopPolling()
        pollingTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if Task.isCancelled || !self.isRunning {
                    break
                }
                await self.pollStatus()
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
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
        return cleaned.isEmpty ? "research-export" : cleaned
    }

    private func string(in row: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = row[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private func number(in row: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            switch row[key] {
            case let value as NSNumber:
                return value.doubleValue
            case let value as Double:
                return value
            case let value as Int:
                return Double(value)
            case let value as String:
                if let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    return parsed
                }
            default:
                continue
            }
        }
        return nil
    }

    private static let domainsURL = URL(string: "https://openclashd.com/api/research/domains")!
    private static let domainsFallbackURL = URL(string: "https://clashd27.com/api/research/domains")!
    private static let startResearchURL = URL(string: "https://openclashd.com/api/research/start")!
    private static let statusBaseURL = URL(string: "https://openclashd.com/api/research/status/")!
    private static let gapsURL = URL(string: "https://clashd27.com/api/gaps")!

    private func friendlyError(_ error: Error, fallback: String) -> String {
        if let operatorError = error as? OperatorSurfacesError {
            return operatorError.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return "De onderzoeksserver reageert te langzaam. Probeer het zo opnieuw."
            case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
                return "De onderzoeksserver is nu niet bereikbaar."
            default:
                break
            }
        }
        let localized = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return localized.isEmpty ? fallback : localized
    }
}

@MainActor
final class ResearchActivityStore: ObservableObject {
    static let shared = ResearchActivityStore()

    @Published var summary: ResearchActivitySummary?

    private init() {}
}

private struct HTTPStatusError: LocalizedError {
    let statusCode: Int
    let message: String

    var errorDescription: String? {
        message
    }
}

private struct ResearchStartBody: Encodable {
    let domainId: String
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
