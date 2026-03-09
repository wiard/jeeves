# JEEVES MASTER EXECUTION PROMPT

Read AGENTS.md and all documents in docs/ before making any changes.

Jeeves is not a chatbot.

Jeeves is the operator interface and orchestration layer of the Jeeves iPhone application.

The system architecture must remain aligned with the following flow:

Human Intent
→ Jeeves Orchestrator
→ Screen Directive
→ Gateway Action
→ Kernel
→ Knowledge

Jeeves controls the application by interpreting operator intent and translating it into screen navigation, inspection, or governed system actions.

The chat interface acts as the command shell of the system.

--------------------------------------------------

IMPLEMENTATION STRATEGY

Execute the following implementation phases strictly in order.

Complete and stabilize each phase before moving to the next.

1) docs/JEEVES_GATEWAY_HARDENING_PROMPT.md
2) docs/JEEVES_COMMAND_LANGUAGE_PROMPT.md
3) docs/JEEVES_MISSION_CONTROL_PROMPT.md

Do not redesign the app.

All work must remain additive to the current architecture.

--------------------------------------------------

ARCHITECTURAL CONSTRAINTS

The system must maintain the hardened gateway architecture.

Always ensure:

• single gateway endpoint
• single token flow
• single route contract
• AuthorizedRequestBuilder used for all requests
• no duplicate endpoint resolution
• no parallel gateway paths
• no direct backend shortcuts
• no governance bypass

All backend interaction must go through:

GatewayManager
→ AuthorizedRequestBuilder
→ RouteContract

--------------------------------------------------

JEEVES ROLE

Jeeves is the central control shell of the application.

The chat interface must be able to:

• navigate screens
• inspect system state
• explain system activity
• guide the operator
• later trigger governed actions

The chat layer must never bypass the gateway or kernel.

--------------------------------------------------

COMMAND LAYER (PHASE 2)

A lightweight Jeeves Command Language must be added.

Command mode activates when user input starts with:

jeeves

Command syntax:

verb target arg=value arg=value

Examples:

jeeves open browser domain=financial
jeeves show radar
jeeves inspect signals
jeeves explain pressure

Commands must translate into:

JeevesDirective
→ ScreenStatePreset
→ UI navigation

Natural language routing remains the fallback when command parsing does not apply.

--------------------------------------------------

MISSION CONTROL LAYER (PHASE 3)

Jeeves must evolve into a system awareness layer.

The system should be able to answer questions such as:

what is the system pressure
what should I approve
what changed recently
where are the strongest signals

Jeeves should use:

ScreenStateReadable
→ system summaries
→ explanation messages

This creates an operator-grade mission interface.

--------------------------------------------------

IMPLEMENTATION RULES

During implementation:

• prefer small safe changes
• maintain existing screen architecture
• avoid rewriting existing view logic
• keep orchestration separate from UI rendering
• keep code testable and composable

Each phase must:

1. compile successfully
2. maintain existing behavior
3. introduce minimal diffs
4. remain backward compatible

--------------------------------------------------

OUTPUT REQUIREMENTS

For each phase provide:

1. architecture explanation
2. files created
3. files modified
4. minimal code diffs
5. build verification
6. local testing steps

Do not move to the next phase until the current phase compiles cleanly.

--------------------------------------------------

DESIGN PHILOSOPHY

Jeeves is inspired by operator-grade control systems.

The interface should behave like a mission control shell, not a conversational chatbot.

Focus on:

• clarity
• traceability
• deterministic routing
• safe system interaction

The operator must always remain in control of the system.

--------------------------------------------------

END GOAL

Jeeves becomes the central operator console for:

• AI discovery
• system monitoring
• deployment governance
• knowledge generation

All interactions flow through:

Jeeves
→ Gateway
→ Kernel
→ Knowledge

--------------------------------------------------

HOW TO USE THIS PROMPT

Start a new AI development session and give the model the following instruction:

Read docs/JEEVES_MASTER_EXECUTION_PROMPT.md and follow the execution plan.

Then begin Phase 1.
