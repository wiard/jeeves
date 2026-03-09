Read AGENTS.md and all docs in docs/ first.

Read:

docs/JEEVES_SYSTEM_CONTEXT.md
docs/JEEVES_SYSTEM_CONSTITUTION.md
docs/JEEVES_ORCHESTRATOR.md
docs/JEEVES_COMMAND_LANGUAGE.md
docs/JEEVES_OPERATOR_BRAIN.md
docs/JEEVES_CAPABILITY_REGISTRY.md

Goal:

Add a lightweight Jeeves Capability Registry as an additive architecture layer.

Do not redesign the app.

Do not bypass governance.

Do not bypass the hardened gateway model.

The Capability Registry must define what Jeeves is formally allowed to do.

Add a first version of the registry with explicit capabilities for:

• navigation
• inspection
• explanation

Do not implement governed execution in this phase, but allow the model to represent future governed capabilities as planned or disabled.

The registry must integrate cleanly with:

• JeevesOrchestrator
• JeevesDirective
• ScreenStatePreset
• AppScreen
• ScreenStateReadable

Natural language routing and command language should both resolve into capabilities.

The first version must remain small, deterministic, and testable.

Output:

• architecture concept
• Swift types to add
• first capability kinds
• first capability fields
• integration points
• minimal implementation plan
• exact files to create or modify
