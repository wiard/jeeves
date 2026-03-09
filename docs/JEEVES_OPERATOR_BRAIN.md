# JEEVES OPERATOR BRAIN

The Jeeves Operator Brain is the reasoning layer that helps Jeeves interpret the current state of the system and guide the operator toward the most relevant screen or next step.

Jeeves is not a chatbot.

Jeeves is the operator interface and control shell of the system.

The Operator Brain extends this role by adding light system judgement.

--------------------------------------------------

PURPOSE

The Operator Brain does not replace JeevesOrchestrator.

It enriches JeevesOrchestrator.

It helps Jeeves answer questions such as:

• what should I do now
• where is the pressure
• what needs attention
• what is the most relevant screen
• what is the safest next step

--------------------------------------------------

POSITION IN THE ARCHITECTURE

Human Intent
→ Jeeves Orchestrator
→ Operator Brain
→ Screen Directive
→ Gateway Action
→ Kernel
→ Knowledge

The Operator Brain sits between intent interpretation and action selection.

It uses system summaries to guide Jeeves decisions.

--------------------------------------------------

INPUTS

The Operator Brain should not read raw backend payloads directly.

It should consume compact system summaries built from:

• ProposalPoller
• ObservatoryViewModel
• BrowserViewModel
• GatewayManager

These sources should be assembled into a compact OperatorSnapshot.

--------------------------------------------------

OPERATOR SNAPSHOT

OperatorSnapshot is the compact state model of the system.

Example fields:

• gatewayHealthy
• approvalsPending
• streamEvents
• radarHotspots
• emergenceClusters
• activeDeployments
• browserCertifiedCount
• browserEmergingCount
• urgency
• recommendedFocus

This structure should remain small, explainable, and stable.

--------------------------------------------------

OPERATOR ASSESSMENT

The Operator Brain transforms OperatorSnapshot into an OperatorAssessment.

OperatorAssessment should contain:

• primaryConcern
• secondaryConcern
• recommendedScreen
• recommendedAction
• explanation
• urgency

This assessment is then used by JeevesOrchestrator to produce a JeevesDirective.

--------------------------------------------------

FIRST DECISION RULES

The first version of the Operator Brain should remain simple and deterministic.

Example rules:

1. If approvalsPending is high, recommend Mission Control.
2. If radarHotspots and emergenceClusters are elevated, recommend Observatory.
3. If the user asks for AI tools, recommend AI Browser.
4. If gatewayHealthy is false, recommend connection and health review.
5. If no strong signal exists, remain in chat and provide explanation.

--------------------------------------------------

DESIGN PRINCIPLES

The Operator Brain must be:

• additive
• deterministic
• explainable
• lightweight
• compatible with governance

It must not bypass the gateway.
It must not trigger direct backend actions.
It must not replace JeevesDirective.

It only improves judgement and recommendation.

--------------------------------------------------

OUTPUT

The Operator Brain should help Jeeves produce responses such as:

"There are 26 open approvals and elevated radar pressure.
I recommend opening Mission Control first."

or:

"The strongest signal pressure is in Observatory.
I recommend inspecting radar and emergence clusters."

--------------------------------------------------

END GOAL

The Operator Brain turns Jeeves from a navigation assistant into an operator-grade mission interface.

Jeeves becomes capable of:

• seeing the state of the system
• prioritizing what matters
• guiding the operator
• explaining the next step
• staying within the governed architecture

End of document
