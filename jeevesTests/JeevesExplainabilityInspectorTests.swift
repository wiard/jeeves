import Testing
@testable import jeeves

@MainActor
struct JeevesExplainabilityInspectorTests {

    @Test
    func decisionExplanationIncludesTraceFields() {
        let trace = JeevesDecisionTrace(
            originalInput: "jeeves show radar",
            matchedCommand: "show radar",
            matchedGuidanceKind: nil,
            matchedCapabilityId: "inspect_radar",
            policyMode: .allowed,
            policyReason: "read_only",
            sessionSummary: JeevesDecisionSessionSummary(
                currentScreen: .chat,
                missionFocus: "radar",
                browserDomain: nil,
                recentScreens: [.chat, .observatory]
            ),
            recommendationReason: "elevated signal pressure",
            finalDirectiveIntent: "checkRadar",
            finalScreen: .observatory,
            finalSection: "radar",
            nextActions: ["Inspecteer Radar (beschikbaar)"]
        )
        let context = JeevesSessionContext(
            currentScreen: .observatory,
            lastDirective: nil,
            lastOperatorInput: "jeeves explain decision",
            lastDecisionTrace: trace,
            currentMissionFocus: "radar",
            currentBrowserPreset: nil,
            recentScreens: [.chat, .observatory]
        )

        let explanation = JeevesExplainabilityInspector.inspect(
            request: .decision,
            session: context,
            readers: []
        ).text

        #expect(explanation.contains("original input: jeeves show radar"))
        #expect(explanation.contains("matched capability: inspect_radar"))
        #expect(explanation.contains("policy: allowedReadOnly"))
        #expect(explanation.contains("final screen: Observatory"))
    }

    @Test
    func suggestionExplanationUsesTraceRecommendationReason() {
        let trace = JeevesDecisionTrace(
            originalInput: "what should I do now",
            matchedCommand: nil,
            matchedGuidanceKind: "nextScreen",
            matchedCapabilityId: "open_stream",
            policyMode: .allowed,
            policyReason: "read_only",
            sessionSummary: JeevesDecisionSessionSummary(
                currentScreen: .chat,
                missionFocus: nil,
                browserDomain: nil,
                recentScreens: [.chat]
            ),
            recommendationReason: "elevated approval pressure",
            finalDirectiveIntent: "guidance:nextScreen",
            finalScreen: .stream,
            finalSection: "proposals",
            nextActions: ["Open Mission Control (beschikbaar)"]
        )
        let context = JeevesSessionContext(
            currentScreen: .chat,
            lastDirective: nil,
            lastOperatorInput: "jeeves why this suggestion",
            lastDecisionTrace: trace,
            currentMissionFocus: nil,
            currentBrowserPreset: nil,
            recentScreens: [.chat]
        )

        let explanation = JeevesExplainabilityInspector.inspect(
            request: .whySuggestion,
            session: context,
            readers: []
        ).text

        #expect(explanation.contains("recommendation reason: elevated approval pressure"))
        #expect(explanation.contains("final screen: Mission Control"))
    }

    @Test
    func matchExplanationHandlesEmptyHistory() {
        let context = JeevesSessionContext(
            currentScreen: .chat,
            lastDirective: nil,
            lastOperatorInput: nil,
            lastDecisionTrace: nil,
            currentMissionFocus: nil,
            currentBrowserPreset: nil,
            recentScreens: []
        )

        let explanation = JeevesExplainabilityInspector.inspect(
            request: .matched,
            session: context,
            readers: []
        ).text

        #expect(explanation.contains("no decision trace available in this session."))
    }
}
