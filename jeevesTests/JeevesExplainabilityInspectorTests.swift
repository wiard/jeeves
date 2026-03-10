import Foundation
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
            timelineEntries: [],
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
            timelineEntries: [],
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
            timelineEntries: [],
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

    @Test
    func timelineExplanationIncludesRecentEntries() {
        let entries = [
            JeevesTimelineEntry(
                id: UUID(uuidString: "A0A0A0A0-A0A0-4A0A-8A0A-A0A0A0A0A0A0")!,
                timestamp: Date(timeIntervalSince1970: 100),
                eventKind: .routing,
                originalInput: "show me radar",
                matchedCapabilityId: "inspect_radar",
                policyMode: .allowed,
                policyReason: "read_only",
                recommendationReason: nil,
                finalDirectiveIntent: "checkRadar",
                finalScreen: .observatory,
                resultSummary: "Ik open de Observatory op het Radar-overzicht."
            ),
            JeevesTimelineEntry(
                id: UUID(uuidString: "B0B0B0B0-B0B0-4B0B-8B0B-B0B0B0B0B0B0")!,
                timestamp: Date(timeIntervalSince1970: 200),
                eventKind: .guidance,
                originalInput: "what should I do now",
                matchedCapabilityId: "open_stream",
                policyMode: .allowed,
                policyReason: "read_only",
                recommendationReason: "elevated approval pressure",
                finalDirectiveIntent: "guidance:nextScreen",
                finalScreen: .stream,
                resultSummary: "Ik open Mission Control voor openstaande items."
            ),
        ]

        let context = JeevesSessionContext(
            currentScreen: .chat,
            lastDirective: nil,
            lastOperatorInput: "jeeves show timeline",
            lastDecisionTrace: nil,
            timelineEntries: entries,
            currentMissionFocus: nil,
            currentBrowserPreset: nil,
            recentScreens: [.chat, .observatory, .stream]
        )

        let explanation = JeevesExplainabilityInspector.inspect(
            request: .timeline,
            session: context,
            readers: []
        ).text

        #expect(explanation.contains("Operator Timeline: recent events"))
        #expect(explanation.contains("capability: open_stream"))
        #expect(explanation.contains("policy: allowedReadOnly"))
    }

    @Test
    func allowedCapabilitiesExplanationIsExecutionAware() {
        let context = JeevesSessionContext(
            currentScreen: .chat,
            lastDirective: nil,
            lastOperatorInput: "jeeves what is allowed",
            lastDecisionTrace: nil,
            timelineEntries: [],
            currentMissionFocus: nil,
            currentBrowserPreset: nil,
            recentScreens: []
        )

        let explanation = JeevesExplainabilityInspector.inspect(
            request: .whatIsAllowed,
            session: context,
            readers: []
        ).text

        #expect(explanation.contains("Execution Awareness: allowed capabilities"))
        #expect(explanation.contains("open_browser"))
        #expect(explanation.contains("class: readOnly"))
    }

    @Test
    func recommendationAndEvidenceExplanationsUseCapabilitySummary() {
        let trace = JeevesDecisionTrace(
            originalInput: "jeeves show radar",
            matchedCommand: "show radar",
            matchedGuidanceKind: nil,
            matchedCapabilityId: "open_observatory",
            policyMode: .allowed,
            policyReason: "read_only",
            sessionSummary: JeevesDecisionSessionSummary(
                currentScreen: .chat,
                missionFocus: nil,
                browserDomain: nil,
                recentScreens: [.chat]
            ),
            recommendationReason: "elevated signal pressure",
            finalDirectiveIntent: "command:show radar",
            finalScreen: .observatory,
            finalSection: "radar",
            nextActions: []
        )
        let context = JeevesSessionContext(
            currentScreen: .observatory,
            lastDirective: nil,
            lastOperatorInput: "jeeves why do you recommend this",
            lastDecisionTrace: trace,
            timelineEntries: [],
            currentMissionFocus: "radar",
            currentBrowserPreset: nil,
            recentScreens: [.chat, .observatory]
        )

        let whyText = JeevesExplainabilityInspector.inspect(
            request: .whyRecommendThis,
            session: context,
            readers: []
        ).text
        #expect(whyText.contains("Execution Awareness: recommendation rationale"))
        #expect(whyText.contains("matched capability: open_observatory"))
        #expect(whyText.contains("execution class: readOnly"))

        let evidenceText = JeevesExplainabilityInspector.inspect(
            request: .whatEvidenceSupportsThis,
            session: context,
            readers: []
        ).text
        #expect(evidenceText.contains("Execution Awareness: evidence context"))
        #expect(evidenceText.contains("policy_layer: policy reason: read_only"))
    }
}
