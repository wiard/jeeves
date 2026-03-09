# JEEVES CAPABILITY REGISTRY

The Jeeves Capability Registry defines what Jeeves is formally allowed to do.

Jeeves is not a chatbot.

Jeeves is the operator interface and control shell of the system.

To remain stable, safe, and explainable, Jeeves must not rely on implicit behavior alone.

Its abilities must be represented explicitly as capabilities.

--------------------------------------------------

PURPOSE

The Capability Registry exists to define:

• what Jeeves can navigate to
• what Jeeves can inspect
• what Jeeves can explain
• what Jeeves can trigger as a governed action

This prevents hidden logic and makes the system transparent.

--------------------------------------------------

POSITION IN THE ARCHITECTURE

Human Intent
→ Jeeves Orchestrator
→ Capability Registry
→ Screen Directive / Gateway Action
→ Kernel
→ Knowledge

The Capability Registry sits between intent interpretation and execution.

It provides a formal map of what the system can do.

--------------------------------------------------

CAPABILITY TYPES

The registry should support four capability kinds.

1. Navigation
Open or focus screens.

Examples:
• open_browser
• open_observatory
• open_mission_control
• open_deployments

2. Inspection
Inspect current system state.

Examples:
• inspect_pending_approvals
• inspect_radar_pressure
• inspect_gateway_health
• inspect_browser_results

3. Explanation
Provide explanations of what Jeeves sees.

Examples:
• explain_current_focus
• explain_system_state
• explain_browser_ranking

4. Governed Action
Trigger actions through the gateway and kernel.

Examples:
• propose_deployment
• approve_proposal
• reject_proposal
• watch_intention

--------------------------------------------------

CAPABILITY FIELDS

Each capability should include:

• id
• title
• description
• kind
• targetScreen
• requiresGateway
• requiresGovernance
• mode
• commandAliases

Mode should support:

• readOnly
• governed
• disabled
• planned

--------------------------------------------------

RULES

Capabilities must remain explicit.

No direct backend behavior may be triggered without a matching capability.

No command may bypass the capability registry.

Commands and natural language routing should both resolve into capabilities.

The registry must remain compatible with:

JeevesDirective
ScreenStatePreset
AppScreen
ScreenStateReadable

--------------------------------------------------

FIRST VERSION

The first version of the Capability Registry should remain small.

It only needs to cover the first operator surfaces:

• browser
• observatory
• mission control
• deployments
• gateway health

The first version can also mark future actions as planned or disabled.

--------------------------------------------------

DESIGN PRINCIPLES

The registry must be:

• explicit
• stable
• small
• additive
• explainable
• governance-compatible

It must not redesign the app.

It must not introduce direct execution.

It should only formalize what Jeeves already can do and what Jeeves will later be allowed to do.

--------------------------------------------------

END GOAL

The Capability Registry makes Jeeves understandable as an operator system.

Jeeves can reason about capabilities, select capabilities, explain capabilities, and later govern capabilities.

This makes the system transparent and future-proof.

End of document
