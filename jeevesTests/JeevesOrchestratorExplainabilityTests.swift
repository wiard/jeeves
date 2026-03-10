import Testing
@testable import jeeves

@MainActor
struct JeevesOrchestratorExplainabilityTests {

    @Test
    func explainDecisionRoutesToChatDirective() {
        let orchestrator = JeevesOrchestrator()
        let routed = orchestrator.resolve(text: "jeeves show radar", readers: [])
        #expect(routed != nil)
        if let routed {
            orchestrator.navigate(to: routed)
        }

        let directive = orchestrator.resolve(text: "jeeves explain decision", readers: [])
        #expect(directive != nil)
        #expect(directive?.destination == .chat)
        #expect(directive?.intent == "explainability:decision")
        #expect(directive?.explanation.contains("original input: jeeves show radar") == true)
        #expect(directive?.explanation.contains("matched capability: open_observatory") == true)
    }

    @Test
    func whyThisScreenIsRecognizedAsExplainabilityCommand() {
        let orchestrator = JeevesOrchestrator()
        let directive = orchestrator.resolve(text: "jeeves why this screen", readers: [])

        #expect(directive != nil)
        #expect(directive?.destination == .chat)
        #expect(directive?.intent == "explainability:why_screen")
    }

    @Test
    func routingStoresDecisionTraceWithOriginalInput() {
        let orchestrator = JeevesOrchestrator()
        _ = orchestrator.resolve(text: "jeeves show radar", readers: [])

        let trace = orchestrator.session.context().lastDecisionTrace
        #expect(trace != nil)
        #expect(trace?.originalInput == "jeeves show radar")
        #expect(trace?.matchedCommand == "show radar")
        #expect(trace?.matchedCapabilityId == "open_observatory")
        #expect(trace?.finalScreen == .observatory)
    }

    @Test
    func routingAppendsOperatorTimelineEntry() {
        let orchestrator = JeevesOrchestrator()
        _ = orchestrator.resolve(text: "jeeves show radar", readers: [])

        let timeline = orchestrator.session.context().timelineEntries
        #expect(timeline.count == 1)
        #expect(timeline.first?.originalInput == "jeeves show radar")
        #expect(timeline.first?.matchedCapabilityId == "open_observatory")
        #expect(timeline.first?.policyMode == .allowed)
        #expect(timeline.first?.finalScreen == .observatory)
    }

    @Test
    func showTimelineCommandReturnsTimelineDirective() {
        let orchestrator = JeevesOrchestrator()
        _ = orchestrator.resolve(text: "jeeves show radar", readers: [])

        let directive = orchestrator.resolve(text: "jeeves show timeline", readers: [])
        #expect(directive != nil)
        #expect(directive?.destination == .chat)
        #expect(directive?.intent == "timeline:timeline")
        #expect(directive?.explanation.contains("Operator Timeline: recent events") == true)
    }

    @Test
    func timelinePromptVariantsMapToExpectedTimelineIntents() {
        let orchestrator = JeevesOrchestrator()
        _ = orchestrator.resolve(text: "jeeves show radar", readers: [])

        let recent = orchestrator.resolve(text: "jeeves recent decisions", readers: [])
        #expect(recent?.destination == .chat)
        #expect(recent?.intent == "timeline:recent_decisions")

        let happened = orchestrator.resolve(text: "jeeves what happened", readers: [])
        #expect(happened?.destination == .chat)
        #expect(happened?.intent == "timeline:what_happened")

        let matches = orchestrator.resolve(text: "jeeves show recent matches", readers: [])
        #expect(matches?.destination == .chat)
        #expect(matches?.intent == "timeline:recent_matches")

        let policy = orchestrator.resolve(text: "jeeves show recent policy checks", readers: [])
        #expect(policy?.destination == .chat)
        #expect(policy?.intent == "timeline:recent_policy_checks")
    }

    @Test
    func executionAwarenessPromptsMapToExecutionAwarenessIntents() {
        let orchestrator = JeevesOrchestrator()
        _ = orchestrator.resolve(text: "jeeves show radar", readers: [])

        let canDo = orchestrator.resolve(text: "jeeves what can i do", readers: [])
        #expect(canDo?.destination == .chat)
        #expect(canDo?.intent == "execution_awareness:what_can_i_do")

        let allowed = orchestrator.resolve(text: "jeeves what is allowed", readers: [])
        #expect(allowed?.destination == .chat)
        #expect(allowed?.intent == "execution_awareness:what_is_allowed")

        let recommendation = orchestrator.resolve(text: "jeeves why do you recommend this", readers: [])
        #expect(recommendation?.destination == .chat)
        #expect(recommendation?.intent == "execution_awareness:why_recommend_this")

        let evidence = orchestrator.resolve(text: "jeeves what evidence supports this", readers: [])
        #expect(evidence?.destination == .chat)
        #expect(evidence?.intent == "execution_awareness:what_evidence_supports_this")
    }
}
