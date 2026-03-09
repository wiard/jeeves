Read AGENTS.md and all docs in docs/ first.

Read:

docs/JEEVES_SYSTEM_CONTEXT.md
docs/JEEVES_SYSTEM_CONSTITUTION.md
docs/JEEVES_ORCHESTRATOR.md
docs/JEEVES_COMMAND_LANGUAGE.md
docs/JEEVES_OPERATOR_BRAIN.md
docs/JEEVES_CAPABILITY_REGISTRY.md
docs/JEEVES_POLICY_LAYER.md
docs/JEEVES_MEMORY_AND_SESSION_MODEL.md

Goal:

Add a lightweight Jeeves Memory and Session Model as an additive architecture layer.

Do not redesign the app.

Do not bypass governance.

Do not bypass the hardened gateway model.

The first version must focus on explicit short-lived operator session context, not uncontrolled long-term memory.

Design a small session context model that helps Jeeves preserve continuity across operator interactions.

The first phase should support remembering:

• current screen
• last directive
• current browser preset
• current mission focus
• recent operator question
• active gateway endpoint

The session model must integrate cleanly with:

• JeevesOrchestrator
• JeevesDirective
• ScreenStatePreset
• AppScreen
• ScreenStateReadable
• Operator Brain
• Capability Registry
• Policy Layer

The model must remain explicit, inspectable, and easy to reset.

Do not use an LLM for memory in this phase.

Do not create hidden autonomous behavior.

Output:

• architecture concept
• Swift types to add
• first session fields
• integration points
• minimal implementation plan
• exact files to create or modify
