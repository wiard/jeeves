# JEEVES AI ENGINEERING MANUAL

This document tells any AI coding agent how to work safely inside the Jeeves repository.

Every AI working on this project must read this document before making changes.

--------------------------------------------------

IDENTITY OF THE SYSTEM

Jeeves is not a chatbot.

Jeeves is the operator interface and control shell of the Jeeves iPhone application.

The app is the front-end of a governed AI operating environment.

Jeeves must remain aligned with this core flow:

Human Intent
→ Jeeves Orchestrator
→ Capability Registry
→ Policy Layer
→ Screen Directive
→ Gateway Action
→ Kernel
→ Knowledge

--------------------------------------------------

PRIMARY RULE

Do not redesign the architecture.

Extend it additively.

Do not replace stable components unless explicitly instructed.

--------------------------------------------------

WHAT THE SYSTEM ALREADY HAS

The repository already contains or is evolving toward:

• Jeeves Orchestrator
• JeevesDirective
• ScreenStatePreset
• AppScreen
• ScreenStateReadable
• Gateway hardening
• RouteContract
• AuthorizedRequestBuilder
• GatewayManager.resolveEndpoint()
• AI Browser
• Mission Control surfaces
• Capability Registry
• Policy Layer
• Operator Brain
• Governed backend via openclashd

Work with these, not around them.

--------------------------------------------------

NON-NEGOTIABLE CONSTRAINTS

1. No direct backend shortcuts.
All backend interaction must pass through the hardened gateway model.

2. No duplicate endpoint resolution.
Only GatewayManager may resolve endpoints.

3. No scattered route literals.
Use RouteContract.

4. No ad hoc URL building.
Use AuthorizedRequestBuilder.

5. No direct screen switching from arbitrary views.
Navigation must flow through JeevesDirective and AppScreen.

6. No governance bypass.
High-impact actions must remain governed.

7. No giant refactors unless explicitly approved.
Prefer small, reversible changes.

--------------------------------------------------

HOW TO WORK

When given a task:

1. Read AGENTS.md
2. Read all relevant docs in docs/
3. Summarize the current architecture briefly
4. Propose the smallest additive design
5. List files to create or modify
6. Make minimal diffs
7. Verify build
8. Describe local test steps

Do not jump straight into large edits.

--------------------------------------------------

EXPECTED OUTPUT STYLE

For each implementation task, provide:

• architecture concept
• files to create
• files to modify
• exact integration points
• minimal implementation plan
• build/test verification steps

When editing code:
• preserve naming consistency
• preserve existing behavior unless intentionally extending it
• avoid hidden architectural drift

--------------------------------------------------

PREFERRED DESIGN STYLE

The system should feel:

• operator-grade
• explainable
• deterministic where possible
• additive
• governance-aware
• stable under iteration

Jeeves should behave like a mission control shell.

Not like a generic assistant chat app.

--------------------------------------------------

HOW TO THINK ABOUT JEEVES

Jeeves has multiple roles:

1. Orchestrator
Interprets intent and routes the app.

2. Command Shell
Accepts structured commands like:
jeeves open browser domain=financial

3. Mission Control Guide
Explains what deserves attention.

4. Operator Assistant
Later holds memory, context, and recommendations.

AI agents must preserve this direction.

--------------------------------------------------

SAFE IMPLEMENTATION ORDER

When working on major features, use this order unless explicitly overridden:

1. Gateway hardening
2. Command language
3. Mission control
4. Operator brain
5. Capability registry
6. Policy layer
7. Memory and session model

Do not build higher-level intelligence on unstable transport.

--------------------------------------------------

ANTI-PATTERNS

Do not do the following:

• create a second networking system
• create a second orchestration system
• bypass RouteContract
• bypass AuthorizedRequestBuilder
• introduce direct kernel calls from views
• hardcode random tabs or screen indices
• let chat directly mutate unrelated UI state
• let command parsing bypass policy

--------------------------------------------------

SUCCESS CONDITION

A good change makes Jeeves more:

• aligned
• inspectable
• stable
• governed
• capable
• operator-friendly

without breaking the existing architecture.

End of manual
