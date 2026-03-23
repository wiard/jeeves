import Foundation

@MainActor
final class ChipLearningViewModel: ObservableObject {
    struct Recommendation: Identifiable, Sendable {
        let id: String
        let pathKey: String
        let classification: String
        let classificationLabel: String
        let runId: String?
        let design: String?
        let platform: String?
        let severityLabel: String
        let isBlocking: Bool
        let recommendationLabel: String
        let suggestedAction: String
        let rationale: String
        let learningContext: String?
        let usesHeuristic: Bool
        let priority: Int
    }

    struct RunChange: Identifiable, Sendable {
        let id: String
        let title: String
        let summary: String
        let badge: String
        let tone: Tone
        let isHighlighted: Bool

        enum Tone: Sendable {
            case improved
            case steady
            case urgent
        }
    }

    struct SummaryCard: Sendable {
        let headline: String
        let supportingLine: String
        let runCountText: String
        let blockingText: String
        let hypothesisText: String
        let updatedText: String
    }

    struct ActionState: Sendable {
        enum Phase: Sendable, Equatable {
            case sending
            case pending
            case success
            case failed
        }

        let phase: Phase
        let message: String
    }

    struct ActionBanner: Identifiable, Sendable {
        enum Tone: Sendable {
            case pending
            case success
            case failed
        }

        let id: UUID
        let title: String
        let detail: String
        let tone: Tone

        init(title: String, detail: String, tone: Tone) {
            id = UUID()
            self.title = title
            self.detail = detail
            self.tone = tone
        }
    }

    @Published var runs: [ChipRun] = []
    @Published var outcomes: [ChipOutcome] = []
    @Published var hypotheses: [ChipHypothesis] = []
    @Published var summary: ChipSummary?
    @Published var recommendations: [Recommendation] = []
    @Published var runChanges: [RunChange] = []
    @Published var actionStates: [String: ActionState] = [:]
    @Published var latestActionBanner: ActionBanner?
    @Published var highlightedRunId: String?
    @Published var isLoading = false
    @Published var errorText: String?

    private weak var gateway: GatewayManager?
    private let iso8601 = ISO8601DateFormatter()

    var hasAnyData: Bool {
        !runs.isEmpty || !outcomes.isEmpty || !hypotheses.isEmpty || summary != nil
    }

    var summaryCard: SummaryCard {
        let latestRun = sortedRuns.first
        let headline = summary?.headline?.nilIfEmpty
            ?? latestRun?.summary?.nilIfEmpty
            ?? "De chip learning-laag vat samen wat recente runs hebben geleerd."
        let supportingLine = summary?.bestNextAction?.nilIfEmpty
            ?? recommendations.first?.recommendationLabel
            ?? "Jeeves toont hier wat nog blokkeert en wat waarschijnlijk de beste volgende stap is."

        return SummaryCard(
            headline: headline,
            supportingLine: supportingLine,
            runCountText: "\(summary?.runCount ?? runs.count) runs",
            blockingText: "\(summary?.blockingPathCount ?? currentBlockingCount) blockers",
            hypothesisText: "\(hypotheses.count) hypotheses",
            updatedText: lastUpdatedLabel
        )
    }

    private var sortedRuns: [ChipRun] {
        runs.sorted { lhs, rhs in
            parseDate(lhs.startedAtIso ?? lhs.completedAtIso) > parseDate(rhs.startedAtIso ?? rhs.completedAtIso)
        }
    }

    private var currentBlockingCount: Int {
        outcomes.filter(\.blocking).count
    }

    private var lastUpdatedLabel: String {
        if let iso = summary?.lastUpdatedIso ?? sortedRuns.first?.completedAtIso ?? sortedRuns.first?.startedAtIso,
           let date = iso8601.date(from: iso) {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "nl_NL")
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        return "Net bijgewerkt"
    }

    func configure(gateway: GatewayManager) {
        self.gateway = gateway
    }

    func refresh() async {
        guard let gateway else {
            errorText = "De gateway is nog niet ingesteld."
            return
        }

        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        guard let api = await gateway.makeOperatorSurfacesAPI() else {
            clearData()
            errorText = gateway.useMock ? nil : "Geen conductor-token beschikbaar voor chip learning."
            return
        }

        async let runsTask = fetchResult { try await api.fetchChipRecentRuns() }
        async let outcomesTask = fetchResult { try await api.fetchChipRecentOutcomes() }
        async let hypothesesTask = fetchResult { try await api.fetchChipRecentHypotheses() }
        async let summaryTask = fetchResult { try await api.fetchChipSummary() }

        let (runsResult, outcomesResult, hypothesesResult, summaryResult) = await (runsTask, outcomesTask, hypothesesTask, summaryTask)

        runs = (try? runsResult.get()) ?? []
        outcomes = (try? outcomesResult.get()) ?? []
        hypotheses = (try? hypothesesResult.get()) ?? []
        summary = try? summaryResult.get()

        if let highlightedRunId, !runs.contains(where: { $0.id == highlightedRunId }) {
            self.highlightedRunId = nil
        }

        recommendations = buildRecommendations(
            runs: runs,
            outcomes: outcomes,
            hypotheses: hypotheses,
            summary: summary
        )
        runChanges = buildRunChanges(runs: runs, outcomes: outcomes)

        if hasAnyData {
            errorText = nil
        } else {
            let messages: [String] = [
                errorMessage(from: runsResult),
                errorMessage(from: outcomesResult),
                errorMessage(from: hypothesesResult),
                errorMessage(from: summaryResult)
            ].compactMap { $0 }

            errorText = messages.contains(where: { $0.lowercased().contains("not_found") || $0.lowercased().contains("404") })
                ? "Chip learning is nog niet zichtbaar vanaf deze gateway."
                : "Chip learning kon niet worden geladen."
        }
    }

    private func clearData() {
        runs = []
        outcomes = []
        hypotheses = []
        summary = nil
        recommendations = []
        runChanges = []
    }

    private func buildRecommendations(
        runs: [ChipRun],
        outcomes: [ChipOutcome],
        hypotheses: [ChipHypothesis],
        summary: ChipSummary?
    ) -> [Recommendation] {
        let grouped = Dictionary(grouping: outcomes) { $0.pathKey }
        let newestRun = runs.max(by: { parseDate($0.startedAtIso ?? $0.completedAtIso) < parseDate($1.startedAtIso ?? $1.completedAtIso) })
        let runsById = Dictionary(uniqueKeysWithValues: runs.map { ($0.id, $0) })

        return grouped.compactMap { pathKey, pathOutcomes in
            let ordered = pathOutcomes.sorted { lhs, rhs in
                parseDate(lhs.observedAtIso) > parseDate(rhs.observedAtIso)
            }

            guard let latest = ordered.first else { return nil }
            let previous = ordered.dropFirst().first
            let matchingHypothesis = bestHypothesis(for: pathKey, classification: latest.classification, hypotheses: hypotheses)
            let associatedRun = latest.runId.flatMap { runsById[$0] } ?? newestRun

            let classification = latest.classification.lowercased()
            let improved = {
                guard let previousSlack = previous?.slack, let latestSlack = latest.slack else { return false }
                return latestSlack > previousSlack + 0.005
            }()
            let unchangedBlocking = latest.blocking
                && (previous?.blocking == true)
                && abs((latest.slack ?? 0) - (previous?.slack ?? 0)) < 0.005
            let smallPositiveSlack = !latest.blocking && (latest.slack ?? 0) > 0 && (latest.slack ?? 0) < 0.03

            let recommendationLabel: String
            let suggestedAction: String
            let heuristicRationale: String
            let priority: Int

            if smallPositiveSlack {
                recommendationLabel = "Marge volgen voor volgende run"
                suggestedAction = matchingHypothesis?.suggestedAction ?? "Laat de marge eerst nog een run staan"
                heuristicRationale = "Heuristiek: het pad is niet meer blokkerend, maar de positieve slack is nog klein."
                priority = 1
            } else if latest.blocking && classification.contains("setup") {
                recommendationLabel = unchangedBlocking
                    ? "Urgentie omhoog: retiming of bufferwerk blijft nodig"
                    : "Retiming waarschijnlijk beste volgende stap"
                suggestedAction = matchingHypothesis?.suggestedAction ?? "Probeer retiming of gerichte bufferplaatsing"
                heuristicRationale = improved && previous != nil
                    ? "Heuristiek: dit pad verbetert, maar blokkeert nog steeds. Dezelfde reparatieklasse lijkt nog het meest logisch."
                    : "Heuristiek: blokkerende setup-paden reageren meestal het best op retiming of bufferwerk."
                priority = unchangedBlocking ? 5 : 4
            } else if latest.blocking && classification.contains("hold") {
                recommendationLabel = unchangedBlocking
                    ? "Urgentie omhoog: extra vertraging blijft nodig"
                    : "Buffer of extra vertraging aanbevolen"
                suggestedAction = matchingHypothesis?.suggestedAction ?? "Voeg vertraging of een bufferstap toe"
                heuristicRationale = improved && previous != nil
                    ? "Heuristiek: hold-gedrag verbetert, maar is nog niet weg. Dezelfde reparatierichting verdient nog een run."
                    : "Heuristiek: blokkerende hold-paden vragen meestal om extra vertraging of bufferwerk."
                priority = unchangedBlocking ? 5 : 4
            } else if latest.blocking {
                recommendationLabel = unchangedBlocking
                    ? "Urgentie omhoog: pad blijft blokkeren"
                    : "Vertragingsgerichte reparatie aanbevolen"
                suggestedAction = matchingHypothesis?.suggestedAction ?? "Onderzoek een vertraging- of buffergerichte reparatie"
                heuristicRationale = improved && previous != nil
                    ? "Heuristiek: er is vooruitgang, maar nog geen vrijgave. Houd dezelfde reparatieklasse vast."
                    : "Heuristiek: dit pad blijft blokkeren en vraagt om een directe herstelactie."
                priority = unchangedBlocking ? 5 : 3
            } else {
                recommendationLabel = "Marge volgen voor volgende run"
                suggestedAction = matchingHypothesis?.suggestedAction ?? "Observeer eerst nog een extra run"
                heuristicRationale = "Heuristiek: dit pad blokkeert niet meer, dus directe ingreep is minder dringend."
                priority = 0
            }

            let rationale = [matchingHypothesis?.rationale?.nilIfEmpty, heuristicRationale]
                .compactMap { $0 }
                .joined(separator: " ")
            let learningContext = matchingHypothesis?.learningContext?.nilIfEmpty
                ?? summary?.headline?.nilIfEmpty
                ?? previousContext(previous: previous, latest: latest)

            return Recommendation(
                id: pathKey,
                pathKey: pathKey,
                classification: latest.classification,
                classificationLabel: classificationLabel(latest.classification),
                runId: latest.runId,
                design: associatedRun?.designName,
                platform: associatedRun?.platform,
                severityLabel: severityLabel(for: latest, unchangedBlocking: unchangedBlocking, smallPositiveSlack: smallPositiveSlack),
                isBlocking: latest.blocking,
                recommendationLabel: recommendationLabel,
                suggestedAction: suggestedAction,
                rationale: rationale,
                learningContext: learningContext,
                usesHeuristic: matchingHypothesis == nil,
                priority: priority
            )
        }
        .sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.pathKey < rhs.pathKey
            }
            return lhs.priority > rhs.priority
        }
    }

    private func buildRunChanges(runs: [ChipRun], outcomes: [ChipOutcome]) -> [RunChange] {
        let orderedRuns = runs.sorted { lhs, rhs in
            parseDate(lhs.startedAtIso ?? lhs.completedAtIso) > parseDate(rhs.startedAtIso ?? rhs.completedAtIso)
        }

        return orderedRuns.enumerated().prefix(3).map { index, run in
            let previous = orderedRuns.dropFirst(index + 1).first
            let title = run.designName?.nilIfEmpty ?? "Chip run \(index + 1)"
            let runBlocking = run.blockingPathCount ?? blockingCount(for: run, outcomes: outcomes)
            let runCritical = run.criticalPathCount ?? criticalCount(for: run, outcomes: outcomes)
            let delta = deltaSummary(current: runBlocking, previous: previous?.blockingPathCount)

            return RunChange(
                id: run.id,
                title: title,
                summary: "\(run.status.capitalized) · \(runCritical) kritieke paden · \(runBlocking) blockers. \(delta)",
                badge: run.id == highlightedRunId ? "Nieuwe run" : runBadge(for: run, comparedTo: previous),
                tone: run.id == highlightedRunId ? .steady : runTone(for: run, comparedTo: previous),
                isHighlighted: run.id == highlightedRunId
            )
        }
    }

    func actionState(for recommendation: Recommendation) -> ActionState? {
        actionStates[recommendation.id]
    }

    func triggerRecommendation(_ recommendation: Recommendation) async {
        guard let gateway else {
            setFailedState(for: recommendation, message: "De gateway is nog niet ingesteld.")
            return
        }

        guard let api = await gateway.makeOperatorSurfacesAPI() else {
            setFailedState(for: recommendation, message: "Geen conductor-token beschikbaar voor chipacties.")
            return
        }

        let request = ChipActionRequest(
            pathKey: recommendation.pathKey,
            classification: recommendation.classification,
            proposedAction: recommendation.suggestedAction,
            runId: recommendation.runId,
            design: recommendation.design,
            platform: recommendation.platform
        )
        let knownRunIds = Set(runs.map(\.id))

        actionStates[recommendation.id] = ActionState(
            phase: .sending,
            message: "Actie wordt verzonden."
        )

        do {
            let ack = try await api.triggerChipAction(request)
            let status = ack.status?.lowercased() ?? ""

            if !ack.ok || status.contains("failed") || status.contains("error") || status.contains("rejected") {
                let message = ack.reason?.nilIfEmpty ?? "De chipactie werd niet geaccepteerd."
                setFailedState(for: recommendation, message: message)
                return
            }

            highlightedRunId = nil
            actionStates[recommendation.id] = ActionState(
                phase: .pending,
                message: "Nieuwe run gestart. Wachten op resultaten."
            )
            latestActionBanner = ActionBanner(
                title: "Nieuwe run gestart",
                detail: "Wachten op resultaten",
                tone: .pending
            )

            await refresh()
            await pollForNewRun(afterKnownRunIds: knownRunIds, for: recommendation)
        } catch {
            setFailedState(for: recommendation, message: actionErrorMessage(error))
        }
    }

    private func bestHypothesis(
        for pathKey: String,
        classification: String,
        hypotheses: [ChipHypothesis]
    ) -> ChipHypothesis? {
        let exact = hypotheses.filter { $0.pathKey?.trimmingCharacters(in: .whitespacesAndNewlines) == pathKey }
        if let first = exact.sorted(by: newestHypothesisFirst).first {
            return first
        }

        let fallback = hypotheses.filter {
            let text = ($0.rationale ?? "") + " " + ($0.suggestedAction)
            return text.localizedCaseInsensitiveContains(classification)
        }
        return fallback.sorted(by: newestHypothesisFirst).first
    }

    private func newestHypothesisFirst(_ lhs: ChipHypothesis, _ rhs: ChipHypothesis) -> Bool {
        parseDate(lhs.createdAtIso) > parseDate(rhs.createdAtIso)
    }

    private func previousContext(previous: ChipOutcome?, latest: ChipOutcome) -> String? {
        guard let previous else { return nil }
        guard let latestSlack = latest.slack, let previousSlack = previous.slack else { return nil }
        let delta = latestSlack - previousSlack
        if abs(delta) < 0.005 {
            return "Het pad veranderde nauwelijks ten opzichte van de vorige run."
        }
        let direction = delta > 0 ? "verbeterde" : "verslechterde"
        return "De slack \(direction) met \(String(format: "%.3f", abs(delta))) ten opzichte van de vorige run."
    }

    private func classificationLabel(_ value: String) -> String {
        switch value.lowercased() {
        case "setup-violation":
            return "Setup-violation"
        case "hold-violation":
            return "Hold-violation"
        default:
            return value.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    private func severityLabel(for outcome: ChipOutcome, unchangedBlocking: Bool, smallPositiveSlack: Bool) -> String {
        if unchangedBlocking {
            return "Blijft blokkeren"
        }
        if outcome.blocking {
            return "Blokkerend"
        }
        if smallPositiveSlack {
            return "Kleine marge"
        }
        return "Niet blokkerend"
    }

    private func blockingCount(for run: ChipRun, outcomes: [ChipOutcome]) -> Int {
        guard let runId = run.id.nilIfEmpty else { return 0 }
        let filtered = outcomes.filter { $0.runId == runId }
        return filtered.isEmpty ? 0 : filtered.filter(\.blocking).count
    }

    private func criticalCount(for run: ChipRun, outcomes: [ChipOutcome]) -> Int {
        guard let runId = run.id.nilIfEmpty else { return 0 }
        let filtered = outcomes.filter { $0.runId == runId }
        return filtered.isEmpty ? 0 : filtered.count
    }

    private func deltaSummary(current: Int, previous: Int?) -> String {
        guard let previous else {
            return "Eerste zichtbare run in Jeeves."
        }

        let delta = current - previous
        if delta == 0 {
            return "Zelfde blocker-niveau als de vorige run."
        }
        if delta < 0 {
            return "\(-delta) blockers minder dan de vorige run."
        }
        return "\(delta) blockers meer dan de vorige run."
    }

    private func runBadge(for run: ChipRun, comparedTo previous: ChipRun?) -> String {
        let currentBlocking = run.blockingPathCount ?? 0
        let previousBlocking = previous?.blockingPathCount ?? currentBlocking

        if currentBlocking < previousBlocking {
            return "Verbeterd"
        }
        if currentBlocking > previousBlocking {
            return "Meer druk"
        }
        return "Stabiel"
    }

    private func runTone(for run: ChipRun, comparedTo previous: ChipRun?) -> RunChange.Tone {
        let currentBlocking = run.blockingPathCount ?? 0
        let previousBlocking = previous?.blockingPathCount ?? currentBlocking

        if currentBlocking < previousBlocking {
            return .improved
        }
        if currentBlocking > previousBlocking {
            return .urgent
        }
        return .steady
    }

    private func pollForNewRun(afterKnownRunIds knownRunIds: Set<String>, for recommendation: Recommendation) async {
        for _ in 0..<4 {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await refresh()

            guard let newRun = sortedRuns.first(where: { !knownRunIds.contains($0.id) }) else {
                continue
            }

            highlightedRunId = newRun.id

            let active = runIsActive(newRun.status)
            let detail = comparisonDetail(for: newRun) ?? (active ? "Wachten op resultaten" : "Vergelijking met de vorige run bijgewerkt.")

            latestActionBanner = ActionBanner(
                title: "Nieuwe run gestart",
                detail: detail,
                tone: active ? .pending : .success
            )
            actionStates[recommendation.id] = ActionState(
                phase: active ? .pending : .success,
                message: active ? "Nieuwe run zichtbaar. Wachten op resultaten." : "Nieuwe run zichtbaar. Vergelijking bijgewerkt."
            )
            return
        }
    }

    private func comparisonDetail(for run: ChipRun) -> String? {
        let orderedRuns = sortedRuns
        guard let index = orderedRuns.firstIndex(where: { $0.id == run.id }) else { return nil }
        guard let previous = orderedRuns.dropFirst(index + 1).first else {
            return "Eerste zichtbare run in Jeeves."
        }

        let currentBlocking = run.blockingPathCount ?? blockingCount(for: run, outcomes: outcomes)
        let previousBlocking = previous.blockingPathCount ?? blockingCount(for: previous, outcomes: outcomes)
        let delta = currentBlocking - previousBlocking

        if delta == 0 {
            return "Zelfde blocker-niveau als de vorige run."
        }
        if delta < 0 {
            return "\(-delta) blockers minder dan de vorige run."
        }
        return "\(delta) blockers meer dan de vorige run."
    }

    private func runIsActive(_ status: String) -> Bool {
        let normalized = status.lowercased()
        return normalized == "queued"
            || normalized == "pending"
            || normalized == "running"
            || normalized == "in_progress"
            || normalized == "started"
    }

    private func setFailedState(for recommendation: Recommendation, message: String) {
        actionStates[recommendation.id] = ActionState(phase: .failed, message: message)
        latestActionBanner = ActionBanner(
            title: "Actie mislukt",
            detail: message,
            tone: .failed
        )
    }

    private func actionErrorMessage(_ error: Error) -> String {
        let message = error.localizedDescription
        let normalized = message.lowercased()

        if normalized.contains("not_found") || normalized.contains("404") {
            return "Deze gateway publiceert /api/chip/action nog niet."
        }
        return message
    }

    private func parseDate(_ iso: String?) -> Date {
        guard let iso, let date = iso8601.date(from: iso) else {
            return .distantPast
        }
        return date
    }

    private func fetchResult<T>(_ operation: @escaping () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private func errorMessage<T>(from result: Result<T, Error>) -> String? {
        guard case let .failure(error) = result else { return nil }
        return error.localizedDescription
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
