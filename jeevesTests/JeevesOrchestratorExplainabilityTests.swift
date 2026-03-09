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
}
