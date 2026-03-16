import Foundation

enum OperatorAttentionLevel: Int, Comparable, Sendable {
    case informational = 0
    case noteworthy = 1
    case needsAttention = 2

    static func < (lhs: OperatorAttentionLevel, rhs: OperatorAttentionLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .informational:
            return "Informational"
        case .noteworthy:
            return "Noteworthy"
        case .needsAttention:
            return "Needs attention"
        }
    }

    var operatorPrompt: String {
        switch self {
        case .informational:
            return "For awareness"
        case .noteworthy:
            return "Worth watching"
        case .needsAttention:
            return "This may need your attention"
        }
    }
}

enum OperatorSignalRoute: Sendable {
    case observatory
    case missionControl
    case radar
    case knowledge

    var label: String {
        switch self {
        case .observatory:
            return "Open Observatory"
        case .missionControl:
            return "Open Mission Control"
        case .radar:
            return "Read more in Radar"
        case .knowledge:
            return "Read more in Knowledge"
        }
    }
}

struct OperatorBriefingItem: Identifiable, Sendable {
    let id: String
    let title: String
    let sourceLabel: String
    let summary: String
    let whyItMatters: String
    let attention: OperatorAttentionLevel
    let recencyLabel: String
    let route: OperatorSignalRoute
    let detailItem: DailyBriefingItem
}

struct ObservatorySignalCardModel: Identifiable, Sendable {
    let id: String
    let headline: String
    let sourceLabel: String
    let detectedPattern: String
    let summary: String
    let whyItMatters: String
    let evidenceSummary: String
    let confidenceLabel: String
    let attention: OperatorAttentionLevel
    let recencyLabel: String
    let route: OperatorSignalRoute
}

struct OperatorDecisionAttentionItem: Identifiable, Sendable {
    let id: String
    let title: String
    let message: String
    let whyItMatters: String
    let attention: OperatorAttentionLevel
    let recencyLabel: String
    let route: OperatorSignalRoute
}

enum OperatorSignalPresentation {
    static func briefingItems(from briefing: DailyBriefing) -> [OperatorBriefingItem] {
        var items = briefing.attention.map {
            mapBriefingItem($0, generatedAtIso: briefing.generatedAtIso)
        }

        if items.count < 3 {
            items.append(contentsOf: briefing.signals.map {
                mapSignalGroup($0, generatedAtIso: briefing.generatedAtIso)
            })
        }

        if items.count < 3 {
            items.append(contentsOf: briefing.evidence.map {
                mapEvidence($0, generatedAtIso: briefing.generatedAtIso)
            })
        }

        return items
            .sorted {
                if $0.attention != $1.attention {
                    return $0.attention > $1.attention
                }
                if $0.recencyLabel != $1.recencyLabel {
                    return $0.recencyLabel < $1.recencyLabel
                }
                return $0.title < $1.title
            }
    }

    static func decisionAttention(from briefing: DailyBriefing) -> OperatorDecisionAttentionItem? {
        if let proposal = briefing.pendingProposals.first {
            return OperatorDecisionAttentionItem(
                id: proposal.proposalId,
                title: "This may need your attention",
                message: proposal.title,
                whyItMatters: plainLanguage(
                    proposal.priorityExplanation
                        ?? "The system has enough signal evidence to ask for human approval before it can continue."
                ),
                attention: .needsAttention,
                recencyLabel: recencyLabel(proposal.createdAtIso, referenceIso: briefing.generatedAtIso),
                route: .missionControl
            )
        }

        guard let first = briefingItems(from: briefing).first,
              first.attention == .needsAttention else {
            return nil
        }

        return OperatorDecisionAttentionItem(
            id: first.id,
            title: first.attention.operatorPrompt,
            message: first.title,
            whyItMatters: first.whyItMatters,
            attention: first.attention,
            recencyLabel: first.recencyLabel,
            route: first.route
        )
    }

    static func observatorySignals(
        runtime: SignalsRuntimeSnapshot?,
        stream: ObservatoryStreamFeed?,
        radarStatus: RadarStatusSnapshot?,
        recentKnowledgeCount: Int
    ) -> [ObservatorySignalCardModel] {
        var cards: [ScoredObservatoryCard] = []

        if let runtime {
            cards.append(contentsOf: runtime.discoveryCandidates.prefix(2).map { candidate in
                let attention: OperatorAttentionLevel = candidate.candidateScore >= 0.78 ? .needsAttention : .noteworthy
                let sourceLabel = candidate.sources.isEmpty
                    ? "CLASHD27 discovery radar"
                    : candidate.sources.prefix(3).map(humanizeSource).joined(separator: " + ")

                return ScoredObservatoryCard(
                    score: candidate.candidateScore,
                    card: ObservatorySignalCardModel(
                        id: candidate.id,
                        headline: headline(for: candidate),
                        sourceLabel: sourceLabel,
                        detectedPattern: candidate.crossDomain
                            ? "Multiple signal areas are converging on the same topic."
                            : "A new pattern is building inside one signal area.",
                        summary: plainLanguage(candidate.explanation),
                        whyItMatters: attention == .needsAttention
                            ? "The system sees enough alignment that this could turn into proposal pressure soon."
                            : "The system is gathering related evidence before it decides whether this is operator-relevant.",
                        evidenceSummary: "\(candidate.sources.count) sources aligned · rank \(max(candidate.rank, 1))",
                        confidenceLabel: confidenceLabel(score: candidate.candidateScore),
                        attention: attention,
                        recencyLabel: latestSignalRecency(from: runtime),
                        route: .radar
                    )
                )
            })

            if let research = runtime.researchLane, research.signalCount24h > 0 {
                let attention: OperatorAttentionLevel = research.activitySpikeCount > 1 ? .noteworthy : .informational
                let domainLine = research.topDomains.prefix(2).map(humanizePhrase).joined(separator: ", ")
                let sourceLine = research.sourceBreakdown.prefix(3).map {
                    "\(humanizeSource($0.source)) \($0.signalCount)"
                }.joined(separator: " · ")

                cards.append(
                    ScoredObservatoryCard(
                        score: Double(research.signalCount24h + research.highConfidenceCount),
                        card: ObservatorySignalCardModel(
                            id: "research-lane",
                            headline: domainLine.isEmpty
                                ? "Research activity is increasing"
                                : "Research activity is increasing around \(domainLine)",
                            sourceLabel: sourceLine.isEmpty ? "Research lane" : sourceLine,
                            detectedPattern: "\(research.activitySpikeCount) area\(research.activitySpikeCount == 1 ? "" : "s") showed a clear increase in activity.",
                            summary: "\(research.signalCount24h) research signals were detected in the last 24 hours.",
                            whyItMatters: research.highConfidenceCount > 0
                                ? "This gives the operator an early read on outside-world movement before it becomes a governed decision."
                                : "This is still early, but the system is seeing enough change to keep it visible.",
                            evidenceSummary: "\(research.highConfidenceCount) high-confidence signals · \(research.sourceCount) active source\(research.sourceCount == 1 ? "" : "s")",
                            confidenceLabel: research.highConfidenceCount >= 3 ? "High confidence" : "Building confidence",
                            attention: attention,
                            recencyLabel: recencyLabel(research.latestDetectedAtIso, referenceIso: runtime.lastRunAtIso ?? runtime.startedAtIso),
                            route: .radar
                        )
                    )
                )
            }

            if let signal = runtime.lastSignals.first {
                cards.append(
                    ScoredObservatoryCard(
                        score: 0.55,
                        card: ObservatorySignalCardModel(
                            id: "recent-signal-\(signal.id)",
                            headline: compactTitle(signal.summary ?? "New outside-world signal detected"),
                            sourceLabel: humanizeSource(signal.sourceId ?? "external signal intake"),
                            detectedPattern: "The system recorded a fresh signal from the outside world.",
                            summary: plainLanguage(signal.summary ?? "A new signal entered the governed intake."),
                            whyItMatters: recentKnowledgeCount > 0
                                ? "Recent knowledge already exists, so this signal can be compared against earlier evidence."
                                : "This gives the operator a first look at what changed before deeper interpretation finishes.",
                            evidenceSummary: "Latest intake from the governed signal stream",
                            confidenceLabel: "Early signal",
                            attention: .informational,
                            recencyLabel: recencyLabel(signal.detectedAtIso, referenceIso: runtime.lastRunAtIso ?? runtime.startedAtIso),
                            route: .knowledge
                        )
                    )
                )
            }
        }

        if let stream {
            cards.append(contentsOf: stream.events.prefix(2).map { event in
                let attention = attentionLevel(for: event)
                return ScoredObservatoryCard(
                    score: score(for: event),
                    card: ObservatorySignalCardModel(
                        id: "stream-\(event.id)",
                        headline: streamHeadline(for: event),
                        sourceLabel: streamSourceLabel(for: event),
                        detectedPattern: streamPattern(for: event),
                        summary: streamSummary(for: event),
                        whyItMatters: streamWhyItMatters(for: event, pendingCount: stream.pendingCount),
                        evidenceSummary: streamEvidence(for: event, fallbackPendingCount: stream.pendingCount),
                        confidenceLabel: confidenceLabel(for: event),
                        attention: attention,
                        recencyLabel: recencyLabel(event.timestampIso, referenceIso: nil),
                        route: event.proposalId == nil ? .radar : .missionControl
                    )
                )
            })
        }

        if cards.isEmpty, let radarStatus {
            let activationCount = radarStatus.store?.activationCount ?? 0
            let topSignalTitle = radarStatus.store?.topSignals.first?.title ?? "No clear outside-world signal is visible yet"
            cards.append(
                ScoredObservatoryCard(
                    score: Double(activationCount),
                    card: ObservatorySignalCardModel(
                        id: "radar-fallback",
                        headline: compactTitle(topSignalTitle),
                        sourceLabel: "CLASHD27 radar",
                        detectedPattern: activationCount > 0
                            ? "The radar is still seeing outside-world movement."
                            : "The radar is currently calm.",
                        summary: activationCount > 0
                            ? "The strongest currently visible signal is being kept readable for the operator."
                            : "No strong outside-world signal is rising above the noise right now.",
                        whyItMatters: "This keeps the operator grounded in what the system is seeing, even before deeper signal detail is available.",
                        evidenceSummary: "\(activationCount) recent activation\(activationCount == 1 ? "" : "s")",
                        confidenceLabel: activationCount > 0 ? "Moderate confidence" : "Awaiting signal",
                        attention: activationCount > 0 ? .informational : .informational,
                        recencyLabel: recencyLabel(radarStatus.collector?.lastRun, referenceIso: nil),
                        route: .radar
                    )
                )
            )
        }

        return cards
            .sorted {
                if $0.card.attention != $1.card.attention {
                    return $0.card.attention > $1.card.attention
                }
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                return $0.card.headline < $1.card.headline
            }
            .map(\.card)
    }

    static func observatoryAttention(
        runtime: SignalsRuntimeSnapshot?,
        stream: ObservatoryStreamFeed?
    ) -> OperatorDecisionAttentionItem? {
        if let stream, stream.pendingCount > 0 {
            return OperatorDecisionAttentionItem(
                id: "observatory-pending",
                title: "The system detected a change worth reviewing",
                message: "\(stream.pendingCount) governed follow-up\(stream.pendingCount == 1 ? "" : "s") are visible in the observatory stream.",
                whyItMatters: "A discovery signal is beginning to turn into downstream system activity.",
                attention: .needsAttention,
                recencyLabel: recencyLabel(stream.events.first?.timestampIso, referenceIso: nil),
                route: .missionControl
            )
        }

        guard let candidate = runtime?.discoveryCandidates.first,
              candidate.candidateScore >= 0.78 else {
            return nil
        }

        return OperatorDecisionAttentionItem(
            id: candidate.id,
            title: "This may need your attention",
            message: headline(for: candidate),
            whyItMatters: plainLanguage(candidate.explanation),
            attention: .needsAttention,
            recencyLabel: latestSignalRecency(from: runtime),
            route: .radar
        )
    }

    private static func mapBriefingItem(_ item: DailyBriefingItem, generatedAtIso: String) -> OperatorBriefingItem {
        OperatorBriefingItem(
            id: item.id,
            title: compactTitle(item.title),
            sourceLabel: briefingSourceLabel(for: item),
            summary: plainLanguage(item.summary),
            whyItMatters: plainLanguage(item.why),
            attention: attentionLevel(for: item),
            recencyLabel: recencyLabel(item.createdAtIso, referenceIso: generatedAtIso),
            route: item.proposalId == nil ? .observatory : .missionControl,
            detailItem: item
        )
    }

    private static func mapSignalGroup(_ signal: DailyBriefingSignalGroup, generatedAtIso: String) -> OperatorBriefingItem {
        let detailItem = DailyBriefingItem(
            itemId: signal.groupId,
            kind: "signal",
            title: signal.title,
            summary: signal.summary,
            why: signal.why,
            score: Double(signal.signalCount),
            createdAtIso: signal.latestDetectedAtIso,
            sourceCount: signal.sourceCount,
            objectId: nil,
            proposalId: nil,
            relatedObjectIds: signal.relatedObjectIds
        )

        let sources = signal.sources.prefix(3).map(humanizeSource).joined(separator: " + ")
        return OperatorBriefingItem(
            id: signal.id,
            title: compactTitle(signal.title),
            sourceLabel: sources.isEmpty ? "\(signal.sourceCount) connected sources" : sources,
            summary: plainLanguage(signal.summary),
            whyItMatters: plainLanguage(signal.why),
            attention: signal.signalCount >= 4 ? .noteworthy : .informational,
            recencyLabel: recencyLabel(signal.latestDetectedAtIso, referenceIso: generatedAtIso),
            route: .observatory,
            detailItem: detailItem
        )
    }

    private static func mapEvidence(_ object: KnowledgeObject, generatedAtIso: String) -> OperatorBriefingItem {
        let detailItem = DailyBriefingItem(
            itemId: object.objectId,
            kind: object.kind,
            title: object.title,
            summary: object.summary,
            why: "The system stored this as governed knowledge so it can explain future signals.",
            score: 40,
            createdAtIso: object.createdAtIso,
            sourceCount: object.sourceRefs?.count ?? 0,
            objectId: object.objectId,
            proposalId: nil,
            relatedObjectIds: object.linkedObjectIds ?? []
        )

        return OperatorBriefingItem(
            id: object.id,
            title: compactTitle(object.title),
            sourceLabel: "Knowledge store",
            summary: plainLanguage(object.summary),
            whyItMatters: "The system can now reuse this evidence when similar signals appear again.",
            attention: .informational,
            recencyLabel: recencyLabel(object.createdAtIso, referenceIso: generatedAtIso),
            route: .observatory,
            detailItem: detailItem
        )
    }

    private static func attentionLevel(for item: DailyBriefingItem) -> OperatorAttentionLevel {
        if item.kind == "approval" || item.proposalId != nil {
            return .needsAttention
        }
        if item.score >= 75 {
            return .needsAttention
        }
        if item.score >= 55 || item.kind == "signal" {
            return .noteworthy
        }
        return .informational
    }

    private static func attentionLevel(for event: ObservatoryStreamEvent) -> OperatorAttentionLevel {
        if event.proposalId != nil {
            return .needsAttention
        }
        if let risk = event.risk?.lowercased(), risk == "high" || risk == "critical" {
            return .needsAttention
        }
        if event.isDiscoveryCandidate || event.isGravityHotspot {
            return .noteworthy
        }
        return .informational
    }

    private static func score(for event: ObservatoryStreamEvent) -> Double {
        if let candidateScore = event.candidateScore {
            return candidateScore
        }
        if let gravityScore = event.gravityScore {
            return gravityScore
        }
        return event.proposalId == nil ? 0.45 : 0.85
    }

    private static func streamHeadline(for event: ObservatoryStreamEvent) -> String {
        if let title = event.title, !title.isEmpty {
            return compactTitle(title)
        }
        return compactTitle(event.displayTitle)
    }

    private static func streamSourceLabel(for event: ObservatoryStreamEvent) -> String {
        if let sourceId = event.sourceId, !sourceId.isEmpty {
            return humanizeSource(sourceId)
        }
        if let agentId = event.agentId, !agentId.isEmpty {
            return humanizePhrase(agentId)
        }
        return event.isDiscoveryCandidate ? "CLASHD27 discovery radar" : "Governed observatory stream"
    }

    private static func streamPattern(for event: ObservatoryStreamEvent) -> String {
        if event.isDiscoveryCandidate {
            return "The system detected a pattern that could grow into a governed follow-up."
        }
        if event.isGravityHotspot {
            return "Signals from different areas are starting to pull together."
        }
        if event.proposalId != nil {
            return "A signal has become specific enough to create downstream system activity."
        }
        return "The observatory recorded a meaningful change in the outside-world signal flow."
    }

    private static func streamSummary(for event: ObservatoryStreamEvent) -> String {
        let text = event.summary ?? event.reason ?? event.explanation ?? event.displayTitle
        return plainLanguage(text)
    }

    private static func streamWhyItMatters(for event: ObservatoryStreamEvent, pendingCount: Int) -> String {
        if event.proposalId != nil {
            return "The signal has crossed into the governed queue, so the operator may need to review what happens next."
        }
        if pendingCount > 0 {
            return "The system is already carrying follow-up pressure alongside this signal."
        }
        if event.isDiscoveryCandidate {
            return "This is still read-only, but it is strong enough to stay visible."
        }
        return "This helps the operator understand what changed before digging into lower-level system detail."
    }

    private static func streamEvidence(for event: ObservatoryStreamEvent, fallbackPendingCount: Int) -> String {
        var parts: [String] = []
        if let proposalId = event.proposalId, !proposalId.isEmpty {
            parts.append("proposal \(compactIdentifier(proposalId))")
        }
        if let clusterId = event.clusterId, !clusterId.isEmpty {
            parts.append("pattern \(compactIdentifier(clusterId))")
        }
        if let signalId = event.signalId, !signalId.isEmpty {
            parts.append("signal \(compactIdentifier(signalId))")
        }
        if let risk = event.risk, !risk.isEmpty {
            parts.append("risk \(humanizePhrase(risk))")
        }
        if parts.isEmpty, fallbackPendingCount > 0 {
            parts.append("\(fallbackPendingCount) governed follow-up\(fallbackPendingCount == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "Read-only observatory evidence" : parts.joined(separator: " · ")
    }

    private static func confidenceLabel(for event: ObservatoryStreamEvent) -> String {
        if let score = event.candidateScore {
            return confidenceLabel(score: score)
        }
        if let score = event.gravityScore {
            return confidenceLabel(score: score)
        }
        return event.proposalId == nil ? "Building confidence" : "High confidence"
    }

    private static func headline(for candidate: RadarDiscoveryCandidate) -> String {
        let base = humanizePhrase(candidate.candidateType)
        if candidate.crossDomain {
            return "Cross-domain pattern emerging in \(base)"
        }
        return compactTitle(base.isEmpty ? candidate.candidateId : base)
    }

    private static func briefingSourceLabel(for item: DailyBriefingItem) -> String {
        switch item.kind.lowercased() {
        case "approval":
            return "Governance queue"
        case "knowledge", "evidence":
            return "Knowledge store"
        case "signal":
            return item.sourceCount > 0
                ? "\(item.sourceCount) connected signal source\(item.sourceCount == 1 ? "" : "s")"
                : "Discovery radar"
        default:
            return humanizePhrase(item.kind)
        }
    }

    private static func confidenceLabel(score: Double) -> String {
        switch score {
        case 0.8...:
            return "High confidence"
        case 0.6..<0.8:
            return "Building confidence"
        default:
            return "Early signal"
        }
    }

    private static func latestSignalRecency(from runtime: SignalsRuntimeSnapshot?) -> String {
        guard let runtime else {
            return "Recently"
        }
        return recencyLabel(
            runtime.lastSignals.first?.detectedAtIso ?? runtime.lastRunAtIso ?? runtime.startedAtIso,
            referenceIso: runtime.lastRunAtIso ?? runtime.startedAtIso
        )
    }

    private static func recencyLabel(_ iso: String?, referenceIso: String?) -> String {
        let formatter = ISO8601DateFormatter()
        let referenceDate = referenceIso.flatMap(formatter.date(from:)) ?? Date()
        guard let iso, let date = formatter.date(from: iso) else {
            return "Recently"
        }

        let delta = max(0, Int(referenceDate.timeIntervalSince(date)))
        if delta < 300 {
            return "Just now"
        }
        if delta < 3600 {
            return "\(max(1, delta / 60)) min ago"
        }
        if delta < 86_400 {
            return "\(max(1, delta / 3600))h ago"
        }
        if delta < 172_800 {
            return "Yesterday"
        }
        return "\(max(2, delta / 86_400))d ago"
    }

    private static func compactTitle(_ text: String) -> String {
        compactSentence(plainLanguage(text), maxLength: 70)
    }

    private static func plainLanguage(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "cross-domain", with: "cross-topic", options: .caseInsensitive)
            .replacingOccurrences(of: "cluster", with: "pattern", options: .caseInsensitive)
            .replacingOccurrences(of: "gravity", with: "signal pull", options: .caseInsensitive)
            .replacingOccurrences(of: "discovery candidate", with: "emerging signal", options: .caseInsensitive)
            .replacingOccurrences(of: "emergence candidate", with: "emerging signal", options: .caseInsensitive)
            .replacingOccurrences(of: "runtime", with: "system", options: .caseInsensitive)
            .replacingOccurrences(of: "residue", with: "memory trace", options: .caseInsensitive)
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return compactSentence(cleaned, maxLength: 150)
    }

    private static func compactSentence(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        return String(text.prefix(maxLength - 1)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func humanizePhrase(_ value: String) -> String {
        value
            .split(whereSeparator: { $0 == "_" || $0 == "-" || $0 == "." || $0 == "/" })
            .map { chunk in
                switch chunk.lowercased() {
                case "openalex":
                    return "OpenAlex"
                case "pubmed":
                    return "PubMed"
                case "europepmc":
                    return "Europe PMC"
                case "rss":
                    return "RSS"
                case "api":
                    return "API"
                case "ai":
                    return "AI"
                default:
                    return chunk.capitalized
                }
            }
            .joined(separator: " ")
    }

    private static func humanizeSource(_ value: String) -> String {
        humanizePhrase(value)
    }

    private static func compactIdentifier(_ value: String) -> String {
        if value.count <= 12 {
            return value
        }
        return String(value.prefix(12))
    }
}

private struct ScoredObservatoryCard {
    let score: Double
    let card: ObservatorySignalCardModel
}
