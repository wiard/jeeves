Read AGENTS.md and all docs in docs/ first.

Read:

docs/JEEVES_SYSTEM_CONTEXT.md
docs/JEEVES_SYSTEM_CONSTITUTION.md
docs/JEEVES_ORCHESTRATOR.md
docs/JEEVES_COMMAND_LANGUAGE.md
docs/JEEVES_OPERATOR_BRAIN.md

Goal:

Add a lightweight Jeeves Operator Brain as an additive reasoning layer on top of the existing JeevesOrchestrator.

Do not redesign the app.

Do not bypass governance.

Do not bypass the hardened gateway model.

The Operator Brain must consume compact system summaries from ProposalPoller, ObservatoryViewModel, BrowserViewModel, and GatewayManager, then assemble them into an OperatorSnapshot.

From OperatorSnapshot it should derive an OperatorAssessment with:

• primaryConcern
• secondaryConcern
• recommendedScreen
• recommendedAction
• explanation
• urgency

Then integrate this into JeevesOrchestrator so that Jeeves can answer operator questions such as:

• what should I do now
• where is the pressure
• what needs attention

The first version must be deterministic and rule-based.

Do not use an LLM for this phase.

Keep the architecture additive and testable.

Maintain compatibility with:

Human Intent
→ Jeeves Orchestrator
→ Screen Directive
→ Gateway Action
→ Kernel
→ Knowledge

Output:

• architecture concept
• Swift types to add
• integration points
• first OperatorSnapshot fields
• first OperatorAssessment rules
• minimal implementation plan
• exact files to create or modify
