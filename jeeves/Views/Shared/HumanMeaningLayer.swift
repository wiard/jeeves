import SwiftUI

struct HumanMeaningExplanation: Sendable {
    let summary: String
    let whySurfaced: String
    let whyItMattersNow: String
    let uncertainty: String
    let operatorFocus: String
}

@MainActor
enum HumanMeaningBuilder {
    static func missionControl(poller: ProposalPoller, gateway: GatewayManager) -> HumanMeaningExplanation {
        let pendingApprovalCount = max(
            poller.pendingProposals.count,
            poller.conductorState?.consentPending ?? gateway.currentStatus?.consent.pending ?? 0
        )
        let discoveryCount = max(
            poller.radarDiscoveryCandidates.count,
            (poller.radarStatus?.store?.collisionCount ?? poller.radarCollisions.count)
                + (poller.radarStatus?.store?.emergenceCount ?? poller.radarEmergence.count)
        )
        let knowledgeCount = max(
            poller.recentKnowledgeObjects.count,
            poller.knowledgeStatus?.last24hSignalsCount ?? 0
        )
        let topRegion = poller.gridResidueSummary?.regions.first?.region
        let latestSignalTitle = poller.radarStatus?.store?.topSignals.first?.title
        let latestKnowledgeTitle = poller.recentKnowledgeObjects.first?.title

        if pendingApprovalCount > 0 {
            return HumanMeaningExplanation(
                summary: "\(pendingApprovalCount) governed proposal\(pendingApprovalCount == 1 ? " is" : "s are") waiting for human review before the loop can move forward.",
                whySurfaced: "Approval is the current bottleneck, so Jeeves is surfacing the queue before any bounded action can continue.",
                whyItMattersNow: "A single operator decision will determine whether the strongest signals remain observation only or become accountable work.",
                uncertainty: discoveryCount > 0
                    ? "Discovery pressure is still active, so the eventual value of these proposals is not fully proven yet."
                    : "The proposals are structured, but their downstream value is still unproven until reviewed.",
                operatorFocus: focusLine(
                    primary: topRegion.map { "Check whether \($0) still deserves attention before approving new scope." },
                    fallback: "Start with the highest-priority proposal and confirm the requested scope still fits today's risk posture."
                )
            )
        }

        if discoveryCount > 0 {
            return HumanMeaningExplanation(
                summary: "\(discoveryCount) live discovery signal\(discoveryCount == 1 ? " is" : "s are") active, but they have not yet become operator work.",
                whySurfaced: focusLine(
                    primary: latestSignalTitle.map { "The field is repeating around \($0), so Mission Control is keeping that pressure visible." },
                    fallback: "CLASHD27 is surfacing collisions and emergence that may soon enter the governed queue."
                ),
                whyItMattersNow: "Repeated discovery pressure is often the first sign that a clearer proposal or research gap is forming.",
                uncertainty: "These patterns are visible, but they have not yet been validated through approval and residue.",
                operatorFocus: focusLine(
                    primary: topRegion.map { "Watch \($0) for repeated signals before treating this as a stable structure." },
                    fallback: "Watch for the same region, family, or collision pattern to reappear before escalating attention."
                )
            )
        }

        if knowledgeCount > 0 {
            return HumanMeaningExplanation(
                summary: "Recent governed work is already settling into operator-visible knowledge.",
                whySurfaced: focusLine(
                    primary: latestKnowledgeTitle.map { "\"\($0)\" is one of the newest knowledge objects now anchoring the picture." },
                    fallback: "Recent approvals and residue have produced fresh knowledge objects that are ready for inspection."
                ),
                whyItMattersNow: "Visible knowledge reduces uncertainty for the next proposal and helps you review with more context.",
                uncertainty: "The knowledge layer is growing, but its broader predictive value still depends on future repetition.",
                operatorFocus: "Open the newest knowledge object and inspect its linked evidence before treating it as settled guidance."
            )
        }

        return HumanMeaningExplanation(
            summary: "The governed loop is calm right now, with no urgent pressure demanding immediate operator action.",
            whySurfaced: "Mission Control is quiet because no part of the loop currently exceeds its normal attention threshold.",
            whyItMattersNow: "A calm state gives you room to review the field before new pressure arrives.",
            uncertainty: "Low activity may mean the system is quiet, or simply that the next meaningful signal has not arrived yet.",
            operatorFocus: "Keep an eye on discovery pressure and the approval queue for the next change in tempo."
        )
    }

    static func observatory(
        intelligence: SystemIntelligenceSnapshot,
        entropy: SystemEntropySnapshot?,
        residueField: SystemResidueFieldSnapshot?,
        recentKnowledgeCount: Int,
        stream: ObservatoryStreamFeed?,
        radar: RadarStatusSnapshot?
    ) -> HumanMeaningExplanation {
        let topRegion = residueField?.regions.first?.region
        let topSignalFamily = humanizeSignalType(residueField?.signalTypes.first?.signalType)
        let streamReason = leadingStreamReason(stream)
        let collisionCount = radar?.store?.collisionCount ?? 0

        let summary: String
        switch intelligence.stagePhase {
        case .safety:
            summary = "The system is still separating real signal from risk before it asks more of you."
        case .define:
            summary = "The field is becoming more structured, and noisy signals are starting to support clearer proposals."
        case .investigate:
            if recentKnowledgeCount > 0 {
                summary = "Approved interactions are reducing uncertainty and landing as visible knowledge."
            } else {
                summary = "Residue is accumulating, and the system is starting to hold a clearer shape."
            }
        }

        return HumanMeaningExplanation(
            summary: summary,
            whySurfaced: focusLine(
                primary: streamReason,
                secondary: topRegion.map { "Signals in \($0) are repeating and now align with earlier governed outcomes." },
                fallback: "Repeated patterns are now strong enough to be legible without changing who decides."
            ),
            whyItMattersNow: focusLine(
                primary: topSignalFamily.map { "This matters now because \($0.lowercased()) signals are accumulating enough residue to improve future prioritization." },
                secondary: entropy.map { entropy in
                    "This matters now because entropy is \(entropy.trend.lowercased()), which changes how much trust you can place in the current structure."
                },
                fallback: "This matters now because repeated structure is beginning to compete with raw noise."
            ),
            uncertainty: focusLine(
                primary: entropy.map { entropy in
                    if entropy.trend.lowercased() == "worsening" {
                        return "The system sees a possible structure, but entropy is still worsening and proof remains incomplete."
                    }
                    if entropy.entropyScore > 0.45 {
                        return "The field is readable, but uncertainty remains elevated and the pattern is still thin."
                    }
                    return "Uncertainty is easing, but the pattern still needs more governed repetition before it feels stable."
                },
                fallback: "The field is visible, but it still needs more governed repetition before it becomes stable knowledge."
            ),
            operatorFocus: focusLine(
                primary: topRegion.flatMap { region in
                    topSignalFamily.map { family in
                        "Watch \(region) and \(family.lowercased()) for repeat signals before treating this as a stable structure."
                    }
                },
                secondary: collisionCount > 0 ? "Watch the recent collision field for repeated overlap before escalating confidence." : nil,
                fallback: "Watch for the same region, family, or event explanation to keep repeating."
            )
        )
    }

    static func knowledge(
        objects: [KnowledgeObject],
        intelligence: SystemIntelligenceSnapshot?,
        residueField: SystemResidueFieldSnapshot?
    ) -> HumanMeaningExplanation {
        guard let lead = objects.first else {
            return HumanMeaningExplanation(
                summary: "The library is quiet, so there is no fresh knowledge object to explain yet.",
                whySurfaced: "Nothing new has crossed the threshold into operator-visible knowledge.",
                whyItMattersNow: "A quiet library means the loop is still gathering or validating earlier signals.",
                uncertainty: "The next meaningful object may still be forming in residue or waiting on approval.",
                operatorFocus: "Check the Observatory for fresh structure if the library remains quiet."
            )
        }

        let sourceCount = lead.sourceRefs?.count ?? 0
        let linkedCount = lead.linkedObjectIds?.count ?? 0
        let topRegion = residueField?.regions.first?.region
        let stage = intelligence?.stagePhase ?? .define

        return HumanMeaningExplanation(
            summary: "\"\(cleanTitle(lead.title))\" is leading the current knowledge view, with \(objects.count) recent object\(objects.count == 1 ? "" : "s") available for inspection.",
            whySurfaced: sourceCount > 0 || linkedCount > 0
                ? "It was surfaced because it is recent and already linked to \(max(sourceCount, linkedCount)) supporting \(max(sourceCount, linkedCount) == 1 ? "reference" : "references")."
                : "It was surfaced because it is one of the newest governed knowledge objects now available to you.",
            whyItMattersNow: stage == .investigate
                ? "This matters now because the system is already converting approved interaction into visible structure."
                : "This matters now because recent knowledge gives you more context before the next approval decision.",
            uncertainty: sourceCount == 0 && linkedCount == 0
                ? "The object is visible, but its supporting context is still thin."
                : "The object is linked, but the broader pattern may still widen as more residue arrives.",
            operatorFocus: focusLine(
                primary: topRegion.map { "Open this object and compare it with the strongest residue region, currently \($0)." },
                fallback: "Open the top object and inspect its linked evidence before treating it as a settled conclusion."
            )
        )
    }

    static func morning(briefing: DailyBriefing) -> HumanMeaningExplanation {
        if let pending = briefing.pendingProposals.first {
            return HumanMeaningExplanation(
                summary: "The morning brief is already surfacing governed work that needs a human decision.",
                whySurfaced: "The brief prioritizes items that cannot move without operator approval, led by \(cleanTitle(pending.title)).",
                whyItMattersNow: "A decision here will determine whether today's strongest signal becomes bounded work or stays in observation.",
                uncertainty: "The signal is strong enough to queue, but its eventual value is still unproven.",
                operatorFocus: "Start with \(cleanTitle(pending.title)) and confirm the requested scope still matches the evidence."
            )
        }

        if let firstAttention = briefing.attention.first {
            return HumanMeaningExplanation(
                summary: cleanSentence(firstAttention.summary),
                whySurfaced: cleanSentence(firstAttention.why),
                whyItMattersNow: "This matters now because it is one of the clearest signals shaping today's operating picture.",
                uncertainty: briefing.counts.stale
                    ? "The brief is aging, so some context may already have shifted."
                    : "The signal is visible, but downstream impact is still forming.",
                operatorFocus: "Keep this item in view while scanning the rest of the brief for reinforcing evidence."
            )
        }

        let discoverySummary = briefing.discoveryPulse?.summary ?? "No strong discovery pulse is active yet."
        return HumanMeaningExplanation(
            summary: cleanSentence(discoverySummary),
            whySurfaced: "The brief is highlighting the clearest discovery pressure currently visible across the system.",
            whyItMattersNow: "This matters now because early structure often appears here before it reaches the governed queue.",
            uncertainty: "The morning view is still directional rather than conclusive.",
            operatorFocus: "Watch for repeated discovery hints before treating the brief as settled guidance."
        )
    }

    private static func leadingStreamReason(_ stream: ObservatoryStreamFeed?) -> String? {
        guard let stream else { return nil }
        for event in stream.events {
            if let explanation = cleanOptional(event.explanation) { return explanation }
            if let reason = cleanOptional(event.reason) { return reason }
            if let summary = cleanOptional(event.summary) { return summary }
        }
        return nil
    }

    private static func cleanOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : cleanSentence(trimmed)
    }

    private static func cleanSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "No explanation is available yet." }
        return trimmed.hasSuffix(".") ? trimmed : "\(trimmed)."
    }

    private static func cleanTitle(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func humanizeSignalType(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private static func focusLine(primary: String?, secondary: String? = nil, fallback: String) -> String {
        if let primary, !primary.isEmpty { return cleanSentence(primary) }
        if let secondary, !secondary.isEmpty { return cleanSentence(secondary) }
        return cleanSentence(fallback)
    }
}

struct HumanMeaningPanel: View {
    let title: String
    let accent: Color
    let explanation: HumanMeaningExplanation

    var body: some View {
        InstrumentSectionPanel(
            eyebrow: "Context",
            title: title,
            subtitle: "What this means for you right now.",
            accent: accent
        ) {
            meaningRow("Summary", explanation.summary)
            meaningRow("Why surfaced", explanation.whySurfaced)
            meaningRow("Why it matters now", explanation.whyItMattersNow)
            meaningRow("Uncertainty", explanation.uncertainty)
            meaningRow("Your focus", explanation.operatorFocus)
        }
    }

    private func meaningRow(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.jeevesMonoSmall)
                .foregroundStyle(accent)

            Text(text)
                .font(.jeevesBody)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
