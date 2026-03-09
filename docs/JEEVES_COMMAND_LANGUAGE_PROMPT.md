Read AGENTS.md and docs first.

Read:

docs/JEEVES_SYSTEM_CONTEXT.md
docs/JEEVES_ORCHESTRATOR.md
docs/JEEVES_COMMAND_LANGUAGE.md

Goal:

Extend Jeeves from a natural-language screen orchestrator into a lightweight AI Command Language.

Jeeves is not a chatbot.

Jeeves is the operator interface and control shell of the app.

The chat layer acts as the command interface.

Command Mode

Command mode activates when a message begins with:

"jeeves "

Example:

jeeves open browser domain=financial
jeeves show radar
jeeves inspect system
jeeves explain signals

Command Format

verb target arg=value arg=value

Example:

open browser domain=financial
show radar
inspect system
explain signals

First Command Set (read-only)

open
show
inspect
explain

Commands must map into existing flows:

JeevesDirective
ScreenStatePreset
AppScreen
ScreenStateReadable

The command layer must remain additive.

Natural language routing must remain the fallback.

Architecture rules:

• Commands never bypass governance
• Commands never call backend routes directly
• Commands only produce directives
• Directives trigger UI navigation or gateway requests
• Gateway requests go through AuthorizedRequestBuilder

The command system must remain compatible with:

Human Intent
→ Jeeves Orchestrator
→ Screen Directive
→ Gateway Action
→ Kernel
→ Knowledge

Output:

• command parser design
• command model
• command-to-directive mapper
• integration with JeevesOrchestrator
• minimal Swift types
• minimal implementation plan
