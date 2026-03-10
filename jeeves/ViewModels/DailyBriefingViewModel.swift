
import Foundation
import Observation

@MainActor
@Observable
final class DailyBriefingViewModel {
    var briefing: DailyBriefing?
    var isLoading = false
    var hasLoaded = false
    var usingCachedFallback = false
    var errorMessage: String?

    func load() async {
        isLoading = true
        usingCachedFallback = false
        errorMessage = nil
        briefing = Self.mockBriefing()
        hasLoaded = true
        isLoading = false
    }

    func load(gateway: GatewayManager, force: Bool = false) async {
        if isLoading && !force {
            return
        }
        if hasLoaded && !force {
            return
        }

        isLoading = true
        usingCachedFallback = false
        errorMessage = nil

        defer {
            hasLoaded = true
            isLoading = false
        }

        if gateway.useMock || gateway.host.lowercased() == "mock" {
            briefing = Self.mockBriefing()
            return
        }

        let resolved = await gateway.resolveEndpoint()
        guard let token = resolved.token, !token.isEmpty else {
            errorMessage = "Geen geldige gateway-token beschikbaar voor de dagelijkse briefing."
            return
        }

        let client = GatewayClient(host: resolved.host, port: resolved.port, token: token)

        do {
            briefing = try await client.fetchDailyBriefing()
        } catch {
            errorMessage = "Kon briefing niet laden."
        }
    }

    func reload() async {
        await load()
    }

    private static func mockBriefing() -> DailyBriefing {
        let formatter = ISO8601DateFormatter()
        let now = Date()
        let nowIso = formatter.string(from: now)

        return DailyBriefing(
            generatedAtIso: nowIso,
            headline: "Goedemorgen. Drie dingen zijn veranderd.",
            statusLine: "2 signalen verdienen aandacht • 2 goedkeuringen wachten • kennis is vers",
            quiet: false,
            overview: [
                "AI-infrastructuur beweegt richting lichtere execution layers en runtimes.",
                "Geopolitieke druk rond chips en exportcontrole blijft relevant voor AI-capaciteit.",
                "Twee voorstellen wachten op operator-goedkeuring."
            ],
            counts: DailyBriefingCounts(
                pendingApprovals: 2,
                groupedSignals: 4,
                recentEvidence: 6,
                knowledgeSignals24h: 9,
                stale: false
            ),
            system: DailyBriefingSystem(
                conductor: DailyBriefingSubsystemStatus(status: "attention", pendingApprovals: 2),
                signalRuntime: DailyBriefingSignalRuntimeStatus(
                    status: "healthy",
                    started: true,
                    lastRunAtIso: nowIso,
                    lastError: nil
                ),
                knowledge: DailyBriefingKnowledgeStatus(
                    status: "healthy",
                    lastScanAtIso: nowIso,
                    last24hSignalsCount: 9,
                    topCubeCells: ["ai_infrastructure/technology/code", "ai_research/technology/papers"]
                ),
                freshness: DailyBriefingFreshnessStatus(
                    status: "healthy",
                    lastSignalAtIso: nowIso,
                    lastKnowledgeAtIso: nowIso
                )
            ),
            attention: [
                DailyBriefingItem(
                    itemId: "signal-execution-layers",
                    kind: "signal",
                    title: "Execution-layer discussie versnelt",
                    summary: "Code, research en infra-discussies convergeren op lichtere agent-runtimes.",
                    why: "Dit raakt direct de architectuurkeuzes voor het persoonlijke operator-systeem.",
                    score: 83,
                    createdAtIso: nowIso,
                    sourceCount: 4,
                    objectId: "ko-exec-runtime",
                    proposalId: nil,
                    relatedObjectIds: ["ko-exec-runtime", "ko-agent-paper"]
                ),
                DailyBriefingItem(
                    itemId: "approval-deep-research",
                    kind: "approval",
                    title: "Verdiep onderzoek naar chip-exportdruk",
                    summary: "Een voorstel wacht op toestemming om geopolitieke chip-signalen verder uit te werken.",
                    why: "Uitvoering blijft geblokkeerd totdat de operator toestemming geeft.",
                    score: 72,
                    createdAtIso: nowIso,
                    sourceCount: 1,
                    objectId: nil,
                    proposalId: "proposal-geopolitics-1",
                    relatedObjectIds: []
                ),
                DailyBriefingItem(
                    itemId: "knowledge-inference-stack",
                    kind: "knowledge",
                    title: "Nieuwe kennis over inference-stacks opgeslagen",
                    summary: "Recente kennisobjecten wijzen op verschuivingen in serving, compilers en coding agents.",
                    why: "Het systeem heeft nu immutabele evidence klaar voor verdere analyse.",
                    score: 68,
                    createdAtIso: nowIso,
                    sourceCount: 3,
                    objectId: "ko-inference-stack",
                    proposalId: nil,
                    relatedObjectIds: ["ko-inference-stack", "ko-compiler-runtime"]
                )
            ],
            signals: [
                DailyBriefingSignalGroup(
                    groupId: "signal-group-execution-layers",
                    title: "AI execution layers",
                    summary: "Een groeiend cluster rond agent-runtimes, orchestration en tooling.",
                    why: "Signalen verschijnen tegelijk in code, research en bredere discussies.",
                    latestDetectedAtIso: nowIso,
                    signalCount: 4,
                    sourceCount: 3,
                    sources: ["github", "research", "rss"],
                    relatedObjectIds: ["ko-exec-runtime", "ko-agent-paper"]
                ),
                DailyBriefingSignalGroup(
                    groupId: "signal-group-chip-controls",
                    title: "Chip export controls",
                    summary: "Beleid en infrastructuur blijven op elkaar drukken in de AI-keten.",
                    why: "Beschikbaarheid van compute beïnvloedt direct strategie en timing.",
                    latestDetectedAtIso: nowIso,
                    signalCount: 3,
                    sourceCount: 2,
                    sources: ["rss", "research"],
                    relatedObjectIds: ["ko-chip-policy"]
                )
            ],
            pendingProposals: [
                Proposal(
                    proposalId: "proposal-geopolitics-1",
                    createdAtIso: nowIso,
                    agentId: "openclashd.briefing",
                    title: "Run deeper chip-policy analysis",
                    intent: ProposalIntent(kind: "analysis", key: "chip_policy_analysis", risk: "low", requiresConsent: true),
                    status: "pending",
                    priorityScore: 2,
                    priorityExplanation: "Cross-domain signal overlap",
                    rank: 1,
                    priorityFactors: nil
                ),
                Proposal(
                    proposalId: "proposal-infra-1",
                    createdAtIso: nowIso,
                    agentId: "openclashd.sources",
                    title: "Fetch additional inference infrastructure sources",
                    intent: ProposalIntent(kind: "fetch", key: "inference_sources_refresh", risk: "low", requiresConsent: true),
                    status: "pending",
                    priorityScore: 1,
                    priorityExplanation: "New infra topic cluster detected",
                    rank: 2,
                    priorityFactors: nil
                )
            ],
            evidence: [
                KnowledgeObject(
                    objectId: "ko-exec-runtime",
                    kind: "evidence",
                    createdAtIso: nowIso,
                    title: "Execution runtime repository activity",
                    summary: "Recent repository changes suggest more modular execution layers for agent systems.",
                    sourceRefs: nil,
                    linkedObjectIds: ["ko-agent-paper"],
                    metadata: nil
                ),
                KnowledgeObject(
                    objectId: "ko-agent-paper",
                    kind: "evidence",
                    createdAtIso: formatter.string(from: now.addingTimeInterval(-1800)),
                    title: "Research on modular agent orchestration",
                    summary: "A new paper describes lighter coordination layers for model-driven tools.",
                    sourceRefs: nil,
                    linkedObjectIds: ["ko-exec-runtime"],
                    metadata: nil
                ),
                KnowledgeObject(
                    objectId: "ko-chip-policy",
                    kind: "evidence",
                    createdAtIso: formatter.string(from: now.addingTimeInterval(-3600)),
                    title: "Chip policy and export control update",
                    summary: "Structured evidence record captured from recent geopolitics coverage.",
                    sourceRefs: nil,
                    linkedObjectIds: nil,
                    metadata: nil
                )
            ],
            lastSignalAtIso: nowIso,
            lastKnowledgeAtIso: nowIso,
            discoveryPulse: BriefingDiscoveryPulse(
                cells: [
                    BriefingDiscoveryPulseCell(cellId: "0-0", title: "Trust × Internal", intensity: "normal", clusterCount: 1, topHint: nil),
                    BriefingDiscoveryPulseCell(cellId: "0-1", title: "Trust × External", intensity: "quiet", clusterCount: 0, topHint: nil),
                    BriefingDiscoveryPulseCell(cellId: "0-2", title: "Trust × Engine", intensity: "rising", clusterCount: 2, topHint: "Execution runtime gravity rising"),
                    BriefingDiscoveryPulseCell(cellId: "1-0", title: "Surface × Internal", intensity: "quiet", clusterCount: 0, topHint: nil),
                    BriefingDiscoveryPulseCell(cellId: "1-1", title: "Surface × External", intensity: "hot", clusterCount: 3, topHint: "Cross-domain convergence in AI infrastructure"),
                    BriefingDiscoveryPulseCell(cellId: "1-2", title: "Surface × Engine", intensity: "normal", clusterCount: 1, topHint: nil),
                    BriefingDiscoveryPulseCell(cellId: "2-0", title: "Core × Internal", intensity: "quiet", clusterCount: 0, topHint: nil),
                    BriefingDiscoveryPulseCell(cellId: "2-1", title: "Core × External", intensity: "rising", clusterCount: 2, topHint: "Chip export policy pressure building"),
                    BriefingDiscoveryPulseCell(cellId: "2-2", title: "Core × Engine", intensity: "quiet", clusterCount: 0, topHint: nil)
                ],
                summary: "Surface × External — elevated activity."
            )
        )
    }
}
