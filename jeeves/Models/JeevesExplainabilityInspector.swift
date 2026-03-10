import Foundation

/// Explicit explainability intents supported by the Decision Inspector layer.
enum JeevesExplainabilityRequest: String, Sendable {
    case context
    case decision
    case whyScreen = "why_screen"
    case whySuggestion = "why_suggestion"
    case whyRecommendThis = "why_recommend_this"
    case matched
    case timeline
    case recentDecisions = "recent_decisions"
    case whatHappened = "what_happened"
    case recentMatches = "recent_matches"
    case recentPolicyChecks = "recent_policy_checks"
    case whatCanIDo = "what_can_i_do"
    case whatIsAllowed = "what_is_allowed"
    case whatRequiresApproval = "what_requires_approval"
    case whatIsBlocked = "what_is_blocked"
    case whatIsDestructive = "what_is_destructive"
    case whatTouchesMoney = "what_touches_money"
    case whatIsSecurityRelated = "what_is_security_related"
    case whatEvidenceSupportsThis = "what_evidence_supports_this"
}

/// Deterministic inspector for compact routing and recommendation explanations.
/// Uses local app-side truth only and never calls the backend.
@MainActor
enum JeevesExplainabilityInspector {

    // MARK: - Trace Builder

    static func buildTrace(
        originalInput: String,
        matchedCommand: String?,
        matchedGuidanceKind: String?,
        recommendationReason: String?,
        finalDirective: JeevesDirective,
        capability: JeevesCapability?,
        policyDecision: JeevesPolicyDecision?,
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDecisionTrace {
        let summary = JeevesDecisionSessionSummary(
            currentScreen: session.currentScreen,
            missionFocus: session.currentMissionFocus,
            browserDomain: session.currentBrowserPreset?.browserDomain,
            recentScreens: session.recentScreens
        )

        return JeevesDecisionTrace(
            originalInput: originalInput,
            matchedCommand: matchedCommand,
            matchedGuidanceKind: matchedGuidanceKind,
            matchedCapabilityId: capability?.id,
            policyMode: policyDecision?.mode,
            policyReason: policyDecision?.reason,
            sessionSummary: summary,
            recommendationReason: recommendationReason.map(recommendationReasonLabel),
            finalDirectiveIntent: finalDirective.intent,
            finalScreen: finalDirective.destination,
            finalSection: finalDirective.section,
            nextActions: nextActions(for: finalDirective.destination, readers: readers)
        )
    }

    // MARK: - Explanation Builder

    static func inspect(
        request: JeevesExplainabilityRequest,
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDecisionExplanation {
        switch request {
        case .context:
            return explainContext(session: session, readers: readers)
        case .decision:
            return explainDecision(session: session)
        case .whyScreen:
            return explainWhyScreen(session: session)
        case .whySuggestion:
            return explainWhySuggestion(session: session, readers: readers)
        case .whyRecommendThis:
            return explainWhyRecommendThis(session: session, readers: readers)
        case .matched:
            return explainMatch(session: session)
        case .timeline:
            return explainTimeline(session: session, readers: readers)
        case .recentDecisions:
            return explainRecentDecisions(session: session, readers: readers)
        case .whatHappened:
            return explainWhatHappened(session: session, readers: readers)
        case .recentMatches:
            return explainRecentMatches(session: session, readers: readers)
        case .recentPolicyChecks:
            return explainRecentPolicyChecks(session: session, readers: readers)
        case .whatCanIDo:
            return explainWhatCanIDo(session: session)
        case .whatIsAllowed:
            return explainAllowedCapabilities(session: session)
        case .whatRequiresApproval:
            return explainRequiresApprovalCapabilities(session: session)
        case .whatIsBlocked:
            return explainBlockedCapabilities(session: session)
        case .whatIsDestructive:
            return explainDestructiveCapabilities(session: session)
        case .whatTouchesMoney:
            return explainMoneyCapabilities(session: session)
        case .whatIsSecurityRelated:
            return explainSecurityCapabilities(session: session)
        case .whatEvidenceSupportsThis:
            return explainEvidenceSupportsThis(session: session, readers: readers)
        }
    }

    // MARK: - Explainability Views

    private static func explainContext(
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDecisionExplanation {
        let assessment = JeevesOperatorBrain.assess(session: session, readers: readers)

        var sessionLines: [String] = [
            "current screen: \(session.currentScreen.title)",
            "recent screens: \(recentScreensLabel(session.recentScreens))"
        ]
        if let input = session.lastOperatorInput {
            sessionLines.append("last operator input: \(input)")
        }
        if let focus = session.currentMissionFocus {
            sessionLines.append("session focus: \(focus)")
        }
        if let browserDomain = session.currentBrowserPreset?.browserDomain {
            sessionLines.append("browser preset: \(browserDomain)")
        }

        let systemLines: [String] = [
            "gateway connected: \(assessment.gatewayConnected ? "yes" : "no")",
            "pending approvals: \(assessment.pendingApprovals)",
            "urgency: \(assessment.urgency.label)",
            "primary concern: \(assessment.primaryFocus)"
        ]

        let traceLines: [String]
        if let trace = session.lastDecisionTrace {
            traceLines = [
                "final screen: \(trace.finalScreen.title)",
                "matched capability: \(trace.matchedCapabilityId ?? "none")",
                "policy: \(policyCode(for: trace))"
            ]
        } else {
            traceLines = ["no decision trace available in this session."]
        }

        return JeevesDecisionExplanation(
            headline: "Decision Inspector: current context",
            sections: [
                JeevesExplanationSection(title: "Session", lines: sessionLines),
                JeevesExplanationSection(title: "System", lines: systemLines),
                JeevesExplanationSection(title: "Latest decision trace", lines: traceLines),
                JeevesExplanationSection(
                    title: "Next useful actions",
                    lines: nextActions(for: session.currentScreen, readers: readers)
                )
            ]
        )
    }

    private static func explainDecision(session: JeevesSessionContext) -> JeevesDecisionExplanation {
        guard let trace = session.lastDecisionTrace else {
            return JeevesDecisionExplanation(
                headline: "Decision Inspector: no routing decision yet",
                sections: [
                    JeevesExplanationSection(
                        title: "Trace",
                        lines: ["no decision trace available in this session."]
                    )
                ]
            )
        }

        return JeevesDecisionExplanation(
            headline: "Decision Inspector: latest routing decision",
            sections: decisionSections(from: trace)
        )
    }

    private static func explainWhyScreen(session: JeevesSessionContext) -> JeevesDecisionExplanation {
        guard let trace = session.lastDecisionTrace else {
            return JeevesDecisionExplanation(
                headline: "Decision Inspector: why this screen",
                sections: [
                    JeevesExplanationSection(
                        title: "Routing",
                        lines: [
                            "current screen: \(session.currentScreen.title)",
                            "no decision trace available in this session."
                        ]
                    )
                ]
            )
        }

        var routingLines: [String] = [
            "current screen: \(session.currentScreen.title)",
            "final screen from trace: \(trace.finalScreen.title)"
        ]
        if session.currentScreen != trace.finalScreen {
            routingLines.append("current screen differs from last traced directive screen.")
        }

        return JeevesDecisionExplanation(
            headline: "Decision Inspector: why this screen",
            sections: [
                JeevesExplanationSection(title: "Routing", lines: routingLines),
                JeevesExplanationSection(
                    title: "Trace",
                    lines: [
                        "original input: \(trace.originalInput)",
                        "matched capability: \(trace.matchedCapabilityId ?? "none")",
                        "policy: \(policyCode(for: trace))"
                    ]
                ),
                JeevesExplanationSection(title: "Next useful actions", lines: trace.nextActions)
            ]
        )
    }

    private static func explainWhySuggestion(
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDecisionExplanation {
        if let trace = session.lastDecisionTrace, let reason = trace.recommendationReason {
            return JeevesDecisionExplanation(
                headline: "Decision Inspector: why this suggestion",
                sections: [
                    JeevesExplanationSection(
                        title: "Recommendation",
                        lines: [
                            "recommendation reason: \(reason)",
                            "final screen: \(trace.finalScreen.title)"
                        ]
                    ),
                    JeevesExplanationSection(
                        title: "Trace",
                        lines: [
                            "original input: \(trace.originalInput)",
                            "matched capability: \(trace.matchedCapabilityId ?? "none")",
                            "policy: \(policyCode(for: trace))"
                        ]
                    ),
                    JeevesExplanationSection(
                        title: "Next useful actions",
                        lines: trace.nextActions
                    )
                ]
            )
        }

        let assessment = JeevesOperatorBrain.assess(session: session, readers: readers)
        let recommendation = JeevesOperatorBrain.recommend(assessment: assessment)
        let navigationCapability = JeevesCapabilityRegistry
            .capabilities(for: recommendation.suggestedScreen)
            .first(where: { $0.kind == .navigation })
        let policy = navigationCapability.map { JeevesPolicyLayer.evaluate(capability: $0) }

        var screenLine = "final screen: \(recommendation.suggestedScreen.title)"
        if let section = recommendation.suggestedSection {
            screenLine += " (\(section))"
        }

        return JeevesDecisionExplanation(
            headline: "Decision Inspector: why this suggestion",
            sections: [
                JeevesExplanationSection(
                    title: "Recommendation",
                    lines: [
                        "recommendation reason: \(recommendationReasonLabel(recommendation.reason))",
                        screenLine
                    ]
                ),
                JeevesExplanationSection(
                    title: "Match",
                    lines: [
                        "matched capability: \(navigationCapability?.id ?? "none")",
                        "policy: \(policyCode(capability: navigationCapability, decision: policy))"
                    ]
                ),
                JeevesExplanationSection(
                    title: "Session context",
                    lines: [
                        "current screen: \(session.currentScreen.title)",
                        "session focus: \(session.currentMissionFocus ?? "none")"
                    ]
                ),
                JeevesExplanationSection(
                    title: "Next useful actions",
                    lines: nextActions(for: recommendation.suggestedScreen, readers: readers)
                )
            ]
        )
    }

    private static func explainWhyRecommendThis(
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDecisionExplanation {
        if let trace = session.lastDecisionTrace,
           let capabilityId = trace.matchedCapabilityId,
           let summary = JeevesCapabilityRegistry.capabilitySummary(for: capabilityId) {
            var recommendationLines: [String] = [
                "matched capability: \(summary.capability.id)",
                "recommendation reason: \(trace.recommendationReason ?? "none")",
                "execution class: \(summary.execution.executionClass.rawValue)",
                "policy: \(policyCode(capability: summary.capability, decision: summary.policyDecision))"
            ]
            if summary.execution.touchesMoney {
                recommendationLines.append("value path: SafeClash-relevant")
            }
            if summary.execution.securityRelated {
                recommendationLines.append("security relevance: CLASHD27-linked")
            }

            return JeevesDecisionExplanation(
                headline: "Execution Awareness: recommendation rationale",
                sections: [
                    JeevesExplanationSection(
                        title: "Recommendation",
                        lines: recommendationLines
                    ),
                    JeevesExplanationSection(
                        title: "Evidence",
                        lines: evidenceLines(for: summary, session: session, readers: readers)
                    ),
                    JeevesExplanationSection(
                        title: "Next operator action",
                        lines: [summary.nextAction.action + " (\(summary.nextAction.reason))"]
                    )
                ]
            )
        }

        let assessment = JeevesOperatorBrain.assess(session: session, readers: readers)
        let recommendation = JeevesOperatorBrain.recommend(assessment: assessment)
        let capability = JeevesCapabilityRegistry
            .capabilities(for: recommendation.suggestedScreen)
            .first(where: { $0.kind == .navigation })
        let summary = capability.flatMap { JeevesCapabilityRegistry.capabilitySummary(for: $0.id) }

        var lines = [
            "recommendation reason: \(recommendationReasonLabel(recommendation.reason))",
            "suggested screen: \(recommendation.suggestedScreen.title)"
        ]
        if let section = recommendation.suggestedSection {
            lines.append("suggested section: \(section)")
        }
        if let summary {
            lines.append("execution class: \(summary.execution.executionClass.rawValue)")
            lines.append("policy: \(policyCode(capability: summary.capability, decision: summary.policyDecision))")
        }

        return JeevesDecisionExplanation(
            headline: "Execution Awareness: recommendation rationale",
            sections: [
                JeevesExplanationSection(title: "Recommendation", lines: lines),
                JeevesExplanationSection(
                    title: "Next useful actions",
                    lines: nextActions(for: recommendation.suggestedScreen, readers: readers)
                )
            ]
        )
    }

    private static func explainMatch(session: JeevesSessionContext) -> JeevesDecisionExplanation {
        guard let trace = session.lastDecisionTrace else {
            return JeevesDecisionExplanation(
                headline: "Decision Inspector: what matched",
                sections: [
                    JeevesExplanationSection(
                        title: "Match",
                        lines: ["no decision trace available in this session."]
                    )
                ]
            )
        }

        return JeevesDecisionExplanation(
            headline: "Decision Inspector: what matched",
            sections: [
                JeevesExplanationSection(
                    title: "Input",
                    lines: [
                        "original input: \(trace.originalInput)",
                        "matched command: \(trace.matchedCommand ?? "none")",
                        "matched guidance kind: \(trace.matchedGuidanceKind ?? "none")"
                    ]
                ),
                JeevesExplanationSection(
                    title: "Match",
                    lines: [
                        "matched capability: \(trace.matchedCapabilityId ?? "none")",
                        "policy: \(policyCode(for: trace))"
                    ]
                ),
                JeevesExplanationSection(
                    title: "Directive",
                    lines: directiveLines(from: trace)
                ),
                JeevesExplanationSection(
                    title: "Next useful actions",
                    lines: trace.nextActions
                )
            ]
        )
    }

    private static func explainTimeline(
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDecisionExplanation {
        let entries = recentTimelineEntries(session.timelineEntries, limit: 8)
        guard !entries.isEmpty else {
            return JeevesDecisionExplanation(
                headline: "Operator Timeline: no recent events",
                sections: [
                    JeevesExplanationSection(
                        title: "Timeline",
                        lines: ["no operator timeline entries in this session."]
                    )
                ]
            )
        }

        return JeevesDecisionExplanation(
            headline: "Operator Timeline: recent events",
            sections: [
                JeevesExplanationSection(
                    title: "Events",
                    lines: entries.map(timelineEventLine)
                ),
                JeevesExplanationSection(
                    title: "Next useful actions",
                    lines: nextActions(for: session.currentScreen, readers: readers)
                )
            ]
        )
    }

    private static func explainRecentDecisions(
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDecisionExplanation {
        let entries = recentTimelineEntries(session.timelineEntries, limit: 5)
        guard !entries.isEmpty else {
            return JeevesDecisionExplanation(
                headline: "Operator Timeline: recent decisions",
                sections: [
                    JeevesExplanationSection(
                        title: "Decisions",
                        lines: ["no recent decisions in this session timeline."]
                    )
                ]
            )
        }

        let lines = entries.map { entry in
            "\(timestampLabel(entry.timestamp)) | \(entry.finalScreen.title) | capability: \(entry.matchedCapabilityId ?? "none") | policy: \(policyLabel(for: entry))"
        }

        return JeevesDecisionExplanation(
            headline: "Operator Timeline: recent decisions",
            sections: [
                JeevesExplanationSection(title: "Decisions", lines: lines),
                JeevesExplanationSection(
                    title: "Next useful actions",
                    lines: nextActions(for: session.currentScreen, readers: readers)
                )
            ]
        )
    }

    private static func explainWhatHappened(
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDecisionExplanation {
        let entries = recentTimelineEntries(session.timelineEntries, limit: 6)
        guard !entries.isEmpty else {
            return JeevesDecisionExplanation(
                headline: "Operator Timeline: what happened",
                sections: [
                    JeevesExplanationSection(
                        title: "Events",
                        lines: ["no recent operator events in this session."]
                    )
                ]
            )
        }

        let lines = entries.map { entry in
            "\(timestampLabel(entry.timestamp)) | \(entry.eventKind.rawValue) | screen: \(entry.finalScreen.title) | result: \(entry.resultSummary)"
        }

        return JeevesDecisionExplanation(
            headline: "Operator Timeline: what happened",
            sections: [
                JeevesExplanationSection(title: "Events", lines: lines),
                JeevesExplanationSection(
                    title: "Next useful actions",
                    lines: nextActions(for: session.currentScreen, readers: readers)
                )
            ]
        )
    }

    private static func explainRecentMatches(
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDecisionExplanation {
        let entries = recentTimelineEntries(session.timelineEntries, limit: 12)
            .filter { $0.matchedCapabilityId != nil }
            .prefix(6)
        guard !entries.isEmpty else {
            return JeevesDecisionExplanation(
                headline: "Operator Timeline: recent matches",
                sections: [
                    JeevesExplanationSection(
                        title: "Matches",
                        lines: ["no capability matches in the recent timeline."]
                    )
                ]
            )
        }

        let lines = entries.map { entry in
            "\(timestampLabel(entry.timestamp)) | capability: \(entry.matchedCapabilityId ?? "none") | policy: \(policyLabel(for: entry)) | screen: \(entry.finalScreen.title)"
        }

        return JeevesDecisionExplanation(
            headline: "Operator Timeline: recent matches",
            sections: [
                JeevesExplanationSection(title: "Matches", lines: lines),
                JeevesExplanationSection(
                    title: "Next useful actions",
                    lines: nextActions(for: session.currentScreen, readers: readers)
                )
            ]
        )
    }

    private static func explainRecentPolicyChecks(
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDecisionExplanation {
        let entries = recentTimelineEntries(session.timelineEntries, limit: 12)
            .filter { $0.policyMode != nil }
            .prefix(6)
        guard !entries.isEmpty else {
            return JeevesDecisionExplanation(
                headline: "Operator Timeline: recent policy checks",
                sections: [
                    JeevesExplanationSection(
                        title: "Policy checks",
                        lines: ["no policy checks in the recent timeline."]
                    )
                ]
            )
        }

        let lines = entries.map { entry in
            "\(timestampLabel(entry.timestamp)) | capability: \(entry.matchedCapabilityId ?? "none") | policy: \(policyLabel(for: entry)) | reason: \(entry.policyReason ?? "none")"
        }

        return JeevesDecisionExplanation(
            headline: "Operator Timeline: recent policy checks",
            sections: [
                JeevesExplanationSection(title: "Policy checks", lines: lines),
                JeevesExplanationSection(
                    title: "Next useful actions",
                    lines: nextActions(for: session.currentScreen, readers: readers)
                )
            ]
        )
    }

    private static func explainWhatCanIDo(session: JeevesSessionContext) -> JeevesDecisionExplanation {
        let summaries = JeevesCapabilityRegistry.capabilitySummaries()
        let allowed = summaries.filter { isAllowedNow($0.policyDecision) }
        let approvalRequired = summaries.filter { requiresApproval($0.policyDecision) }
        let blocked = summaries.filter { isBlocked($0.policyDecision) }

        return JeevesDecisionExplanation(
            headline: "Execution Awareness: what can I do",
            sections: [
                JeevesExplanationSection(
                    title: "Allowed now",
                    lines: linesOrFallback(
                        capabilityLines(
                            for: Array(allowed.prefix(8)),
                            includeEvidenceTags: true
                        ),
                        fallback: "no allowed capabilities."
                    )
                ),
                JeevesExplanationSection(
                    title: "Requires approval",
                    lines: linesOrFallback(
                        capabilityLines(
                            for: Array(approvalRequired.prefix(6)),
                            includeEvidenceTags: true
                        ),
                        fallback: "no approval-gated capabilities."
                    )
                ),
                JeevesExplanationSection(
                    title: "Blocked / planned",
                    lines: linesOrFallback(
                        capabilityLines(
                            for: Array(blocked.prefix(6)),
                            includeEvidenceTags: false
                        ),
                        fallback: "no blocked capabilities."
                    )
                ),
            ]
        )
    }

    private static func explainAllowedCapabilities(session: JeevesSessionContext) -> JeevesDecisionExplanation {
        let summaries = JeevesCapabilityRegistry
            .capabilitySummaries()
            .filter { isAllowedNow($0.policyDecision) }
        return capabilityListExplanation(
            headline: "Execution Awareness: allowed capabilities",
            sectionTitle: "Allowed",
            summaries: summaries,
            emptyMessage: "no allowed capabilities.",
            includeEvidenceTags: true
        )
    }

    private static func explainRequiresApprovalCapabilities(session: JeevesSessionContext) -> JeevesDecisionExplanation {
        let summaries = JeevesCapabilityRegistry
            .capabilitySummaries()
            .filter { requiresApproval($0.policyDecision) }
        return capabilityListExplanation(
            headline: "Execution Awareness: capabilities requiring approval",
            sectionTitle: "Approval required",
            summaries: summaries,
            emptyMessage: "no capabilities currently require approval.",
            includeEvidenceTags: true
        )
    }

    private static func explainBlockedCapabilities(session: JeevesSessionContext) -> JeevesDecisionExplanation {
        let summaries = JeevesCapabilityRegistry
            .capabilitySummaries()
            .filter { isBlocked($0.policyDecision) }
        return capabilityListExplanation(
            headline: "Execution Awareness: blocked capabilities",
            sectionTitle: "Blocked / planned",
            summaries: summaries,
            emptyMessage: "no blocked capabilities.",
            includeEvidenceTags: false
        )
    }

    private static func explainDestructiveCapabilities(session: JeevesSessionContext) -> JeevesDecisionExplanation {
        let summaries = JeevesCapabilityRegistry
            .capabilitySummaries()
            .filter { $0.execution.executionClass == .destructive }
        return capabilityListExplanation(
            headline: "Execution Awareness: destructive capabilities",
            sectionTitle: "Destructive",
            summaries: summaries,
            emptyMessage: "no destructive capabilities registered.",
            includeEvidenceTags: true
        )
    }

    private static func explainMoneyCapabilities(session: JeevesSessionContext) -> JeevesDecisionExplanation {
        let summaries = JeevesCapabilityRegistry
            .capabilitySummaries()
            .filter { $0.execution.touchesMoney }
        return capabilityListExplanation(
            headline: "Execution Awareness: capabilities touching money",
            sectionTitle: "SafeClash relevance",
            summaries: summaries,
            emptyMessage: "no money-touching capabilities registered.",
            includeEvidenceTags: true
        )
    }

    private static func explainSecurityCapabilities(session: JeevesSessionContext) -> JeevesDecisionExplanation {
        let summaries = JeevesCapabilityRegistry
            .capabilitySummaries()
            .filter { $0.execution.securityRelated }
        return capabilityListExplanation(
            headline: "Execution Awareness: security-related capabilities",
            sectionTitle: "CLASHD27 relevance",
            summaries: summaries,
            emptyMessage: "no security-related capabilities registered.",
            includeEvidenceTags: true
        )
    }

    private static func explainEvidenceSupportsThis(
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> JeevesDecisionExplanation {
        guard let trace = session.lastDecisionTrace,
              let capabilityId = trace.matchedCapabilityId,
              let summary = JeevesCapabilityRegistry.capabilitySummary(for: capabilityId) else {
            return JeevesDecisionExplanation(
                headline: "Execution Awareness: evidence context",
                sections: [
                    JeevesExplanationSection(
                        title: "Evidence",
                        lines: ["no recent matched capability available for evidence summary."]
                    )
                ]
            )
        }

        return JeevesDecisionExplanation(
            headline: "Execution Awareness: evidence context",
            sections: [
                JeevesExplanationSection(
                    title: "Capability",
                    lines: [
                        "matched capability: \(summary.capability.id)",
                        "policy: \(policyCode(capability: summary.capability, decision: summary.policyDecision))",
                        "execution class: \(summary.execution.executionClass.rawValue)"
                    ]
                ),
                JeevesExplanationSection(
                    title: "Evidence",
                    lines: evidenceLines(for: summary, session: session, readers: readers)
                ),
                JeevesExplanationSection(
                    title: "Next operator action",
                    lines: [summary.nextAction.action + " (\(summary.nextAction.reason))"]
                )
            ]
        )
    }

    // MARK: - Helpers

    private static func capabilityListExplanation(
        headline: String,
        sectionTitle: String,
        summaries: [JeevesCapabilitySummary],
        emptyMessage: String,
        includeEvidenceTags: Bool
    ) -> JeevesDecisionExplanation {
        let orderedSummaries = prioritizedSummaries(summaries)
        let lines = capabilityLines(
            for: Array(orderedSummaries.prefix(10)),
            includeEvidenceTags: includeEvidenceTags
        )
        return JeevesDecisionExplanation(
            headline: headline,
            sections: [
                JeevesExplanationSection(
                    title: sectionTitle,
                    lines: linesOrFallback(lines, fallback: emptyMessage)
                )
            ]
        )
    }

    private static func capabilityLines(
        for summaries: [JeevesCapabilitySummary],
        includeEvidenceTags: Bool
    ) -> [String] {
        summaries.map { summary in
            var line = "\(summary.capability.id) | \(summary.capability.kind.rawValue) | policy: \(policyCode(capability: summary.capability, decision: summary.policyDecision)) | class: \(summary.execution.executionClass.rawValue)"
            if includeEvidenceTags {
                if summary.execution.touchesMoney {
                    line += " | value: SafeClash"
                }
                if summary.execution.securityRelated {
                    line += " | security: CLASHD27"
                }
            }
            return line
        }
    }

    private static func evidenceLines(
        for summary: JeevesCapabilitySummary,
        session: JeevesSessionContext,
        readers: [ScreenStateReadable]
    ) -> [String] {
        var lines = summary.evidence.map { "\($0.source): \($0.detail)" }

        if let trace = session.lastDecisionTrace {
            lines.append("decision_trace: input=\(trace.originalInput)")
            lines.append("decision_trace: final_screen=\(trace.finalScreen.title)")
        }

        if !session.timelineEntries.isEmpty {
            lines.append("timeline: \(session.timelineEntries.count) local events")
        }

        if let target = summary.capability.targetScreen,
           let reader = readers.first(where: { $0.screenId == target }) {
            let screenSummary = reader.summary()
            if !screenSummary.isEmpty {
                lines.append("screen_summary: \(screenSummary.headline)")
            }
        }

        return lines
    }

    private static func isAllowedNow(_ decision: JeevesPolicyDecision) -> Bool {
        decision.mode == .allowed || decision.mode == .readOnlyOnly
    }

    private static func requiresApproval(_ decision: JeevesPolicyDecision) -> Bool {
        decision.mode == .requiresApproval || decision.mode == .proposalOnly
    }

    private static func isBlocked(_ decision: JeevesPolicyDecision) -> Bool {
        decision.mode == .blocked || decision.mode == .planned
    }

    private static func linesOrFallback(_ lines: [String], fallback: String) -> [String] {
        lines.isEmpty ? [fallback] : lines
    }

    private static func prioritizedSummaries(
        _ summaries: [JeevesCapabilitySummary]
    ) -> [JeevesCapabilitySummary] {
        summaries.sorted { lhs, rhs in
            let lhsPriority = capabilityKindPriority(lhs.capability.kind)
            let rhsPriority = capabilityKindPriority(rhs.capability.kind)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.capability.id < rhs.capability.id
        }
    }

    private static func capabilityKindPriority(_ kind: JeevesCapabilityKind) -> Int {
        switch kind {
        case .navigation:
            return 0
        case .inspection:
            return 1
        case .explanation:
            return 2
        case .governedAction:
            return 3
        }
    }

    private static func decisionSections(from trace: JeevesDecisionTrace) -> [JeevesExplanationSection] {
        [
            JeevesExplanationSection(
                title: "Input",
                lines: [
                    "original input: \(trace.originalInput)",
                    "matched command: \(trace.matchedCommand ?? "none")",
                    "matched guidance kind: \(trace.matchedGuidanceKind ?? "none")"
                ]
            ),
            JeevesExplanationSection(
                title: "Match",
                lines: [
                    "matched capability: \(trace.matchedCapabilityId ?? "none")",
                    "policy: \(policyCode(for: trace))"
                ]
            ),
            JeevesExplanationSection(
                title: "Session context",
                lines: [
                    "screen at decision time: \(trace.sessionSummary.currentScreen.title)",
                    "session focus: \(trace.sessionSummary.missionFocus ?? "none")",
                    "browser preset: \(trace.sessionSummary.browserDomain ?? "none")",
                    "recent screens: \(recentScreensLabel(trace.sessionSummary.recentScreens))"
                ]
            ),
            JeevesExplanationSection(title: "Directive", lines: directiveLines(from: trace)),
            JeevesExplanationSection(title: "Next useful actions", lines: trace.nextActions)
        ]
    }

    private static func directiveLines(from trace: JeevesDecisionTrace) -> [String] {
        var lines: [String] = [
            "final intent: \(trace.finalDirectiveIntent)",
            "final screen: \(trace.finalScreen.title)"
        ]
        if let section = trace.finalSection {
            lines.append("final section: \(section)")
        }
        if let reason = trace.recommendationReason {
            lines.append("recommendation reason: \(reason)")
        }
        return lines
    }

    private static func nextActions(for screen: AppScreen, readers: [ScreenStateReadable]) -> [String] {
        let capabilities = JeevesOperatorBrain.capabilitiesWithPolicy(for: screen)
        if !capabilities.isEmpty {
            return Array(capabilities.prefix(3)).map { "\($0.title) (\($0.status))" }
        }

        if let reader = readers.first(where: { $0.screenId == screen }) {
            let summary = reader.summary()
            if !summary.highlights.isEmpty {
                return Array(summary.highlights.prefix(3))
            }
        }

        return ["inspect \(screen.title.lowercased())"]
    }

    private static func recentScreensLabel(_ screens: [AppScreen]) -> String {
        let tail = screens.suffix(3).map(\.title)
        if tail.isEmpty { return "none" }
        return tail.joined(separator: " -> ")
    }

    private static func recommendationReasonLabel(_ reason: String) -> String {
        switch reason {
        case "pending_approvals":
            return "elevated approval pressure"
        case "observatory_activity":
            return "elevated signal pressure"
        case "gateway_disconnected":
            return "gateway disconnected"
        case "browser_activity":
            return "browser activity detected"
        case "system_calm":
            return "system calm"
        default:
            return reason
        }
    }

    private static func recentTimelineEntries(
        _ entries: [JeevesTimelineEntry],
        limit: Int
    ) -> [JeevesTimelineEntry] {
        Array(entries.suffix(limit).reversed())
    }

    private static func timelineEventLine(_ entry: JeevesTimelineEntry) -> String {
        var fields: [String] = [
            timestampLabel(entry.timestamp),
            entry.eventKind.rawValue,
            "capability: \(entry.matchedCapabilityId ?? "none")",
            "policy: \(policyLabel(for: entry))",
            "screen: \(entry.finalScreen.title)"
        ]
        if let reason = entry.recommendationReason {
            fields.append("recommendation: \(reason)")
        }
        fields.append("result: \(entry.resultSummary)")
        return fields.joined(separator: " | ")
    }

    private static func timestampLabel(_ date: Date) -> String {
        timelineDateFormatter.string(from: date)
    }

    private static func policyLabel(for entry: JeevesTimelineEntry) -> String {
        guard let mode = entry.policyMode else { return "notEvaluated" }
        if mode == .allowed,
           let id = entry.matchedCapabilityId,
           let cap = JeevesCapabilityRegistry.capability(for: id),
           cap.isReadOnly {
            return "allowedReadOnly"
        }
        return mode.rawValue
    }

    private static let timelineDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static func policyCode(for trace: JeevesDecisionTrace) -> String {
        guard let mode = trace.policyMode else { return "notEvaluated" }
        if mode == .allowed,
           let id = trace.matchedCapabilityId,
           let cap = JeevesCapabilityRegistry.capability(for: id),
           cap.isReadOnly {
            return "allowedReadOnly"
        }

        switch mode {
        case .allowed: return "allowed"
        case .readOnlyOnly: return "readOnlyOnly"
        case .requiresApproval: return "requiresApproval"
        case .proposalOnly: return "proposalOnly"
        case .blocked: return "blocked"
        case .planned: return "planned"
        }
    }

    private static func policyCode(
        capability: JeevesCapability?,
        decision: JeevesPolicyDecision?
    ) -> String {
        guard let decision else { return "notEvaluated" }
        if decision.mode == .allowed, capability?.isReadOnly == true {
            return "allowedReadOnly"
        }
        switch decision.mode {
        case .allowed: return "allowed"
        case .readOnlyOnly: return "readOnlyOnly"
        case .requiresApproval: return "requiresApproval"
        case .proposalOnly: return "proposalOnly"
        case .blocked: return "blocked"
        case .planned: return "planned"
        }
    }
}
