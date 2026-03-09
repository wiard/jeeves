Read AGENTS.md and all docs in docs/ first.

Read:

docs/JEEVES_SYSTEM_CONTEXT.md
docs/JEEVES_SYSTEM_CONSTITUTION.md
docs/JEEVES_ORCHESTRATOR.md
docs/JEEVES_COMMAND_LANGUAGE.md
docs/JEEVES_OPERATOR_BRAIN.md
docs/JEEVES_CAPABILITY_REGISTRY.md
docs/JEEVES_POLICY_LAYER.md

Goal:

Add a lightweight Jeeves Policy Layer as an additive architecture layer.

Do not redesign the app.

Do not bypass governance.

Do not bypass the hardened gateway model.

The Policy Layer must evaluate whether a selected capability is allowed, governed, denied, or explanation-only under current system conditions.

The first version must be deterministic and rule-based.

Do not use an LLM for this phase.

Support an initial JeevesPolicyContext and JeevesPolicyDecision model.

Integrate cleanly with:

• JeevesOrchestrator
• JeevesCapabilityRegistry
• JeevesDirective
• ScreenStatePreset
• AppScreen
• ScreenStateReadable

The first phase should focus on:

• read-only capabilities
• governed-only placeholders
• gateway-health-aware restrictions
• operator-safe explanations when execution is not allowed

Output:

• architecture concept
• Swift types to add
• first policy rules
• integration points
• minimal implementation plan
• exact files to create or modify
