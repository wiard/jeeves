import Foundation

/// Explicit explainability intents supported by the Decision Inspector layer.
enum JeevesExplainabilityRequest: String, Sendable {
    case context
    case decision
    case whyScreen = "why_screen"
    case whySuggestion = "why_suggestion"
    case matched
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
        case .matched:
            return explainMatch(session: session)
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

    // MARK: - Helpers

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
