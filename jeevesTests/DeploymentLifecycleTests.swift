import Testing
@testable import jeeves

struct DeploymentLifecycleTests {

    @Test
    func lifecycleStagesReflectGovernanceProgress() {
        let complete = DeploymentLifecycle(
            source: "SafeClash Registry",
            configId: "cfg-1",
            intentionId: "intent-1",
            certificateId: "CERT-1",
            runtimeEnvelopeHash: "abc123",
            benchmarkContractId: "BC-1",
            proposalId: "proposal-1",
            proposalCreatedAtIso: "2026-03-08T10:00:00Z",
            approvalDecision: "approved",
            approvalActor: "operator",
            approvalAtIso: "2026-03-08T10:01:00Z",
            actionKind: "deploy_configuration",
            actionId: "action-1",
            actionState: "completed",
            actionAtIso: "2026-03-08T10:02:00Z",
            knowledgeKind: "configuration_deployment",
            knowledgeId: "ko-1",
            knowledgeAtIso: "2026-03-08T10:03:00Z"
        )

        #expect(complete.steps.map(\.state) == [.complete, .complete, .complete, .complete, .complete])

        let pending = DeploymentLifecycle(
            source: "SafeClash Registry",
            configId: "cfg-2",
            intentionId: "intent-2",
            certificateId: nil,
            runtimeEnvelopeHash: nil,
            benchmarkContractId: nil,
            proposalId: "proposal-2",
            proposalCreatedAtIso: nil,
            approvalDecision: nil,
            approvalActor: nil,
            approvalAtIso: nil,
            actionKind: nil,
            actionId: nil,
            actionState: nil,
            actionAtIso: nil,
            knowledgeKind: nil,
            knowledgeId: nil,
            knowledgeAtIso: nil
        )

        #expect(pending.steps[1].state == .complete)
        #expect(pending.steps[2].state == .pending)
        #expect(pending.steps[3].state == .missing)
        #expect(pending.steps[4].state == .missing)
    }
}
