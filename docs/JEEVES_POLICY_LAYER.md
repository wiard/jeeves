# JEEVES POLICY LAYER

The Jeeves Policy Layer defines what Jeeves is allowed to do under current conditions.

Jeeves is not a chatbot.

Jeeves is the operator interface and control shell of the system.

To remain safe, governed, and explainable, Jeeves must not only know what it can do, but also what it is allowed to do.

--------------------------------------------------

PURPOSE

The Policy Layer determines:

• whether a capability is allowed
• whether a capability is read-only
• whether a capability requires governance
• whether Jeeves should explain instead of execute
• whether the current system state allows the action

The Policy Layer sits between capability selection and execution.

--------------------------------------------------

POSITION IN THE ARCHITECTURE

Human Intent
→ Jeeves Orchestrator
→ Capability Registry
→ Policy Layer
→ Screen Directive / Gateway Action
→ Kernel
→ Knowledge

The Policy Layer evaluates the selected capability before Jeeves acts.

--------------------------------------------------

POLICY CONTEXT

The Policy Layer should evaluate capabilities using a compact JeevesPolicyContext.

This context may include:

• capability
• capability kind
• gatewayHealthy
• requiresGovernance
• operatorTrustLevel
• currentScreen
• commandMode
• readOnlyRequest

The context should remain deterministic and explainable.

--------------------------------------------------

POLICY DECISION

The result of policy evaluation should be a JeevesPolicyDecision.

This decision may contain:

• allowed
• mode
• reason
• requiresGovernance
• fallbackDirective
• operatorMessage

Mode should support:

• allowed
• readOnlyOnly
• governedOnly
• denied
• planned

--------------------------------------------------

FIRST RULES

The first version of the Policy Layer should remain simple and deterministic.

Example rules:

1. Read-only capabilities are allowed.
2. Governed capabilities are not executed directly.
3. Governed capabilities may return explanation or proposal guidance.
4. If gateway is unhealthy, only navigation and explanation are allowed.
5. If a capability is planned but not implemented, Jeeves explains that it is not yet available.
6. High-impact actions require trusted operator context.

--------------------------------------------------

DESIGN PRINCIPLES

The Policy Layer must be:

• explicit
• deterministic
• explainable
• additive
• governance-compatible

It must not redesign the app.

It must not bypass the gateway.

It must not replace capability selection.

It must only decide whether and how a selected capability may proceed.

--------------------------------------------------

RELATION TO CAPABILITY REGISTRY

Capability defines what exists.

Policy defines what is currently permitted.

The registry and policy layer must work together.

Commands and natural language intents should resolve into capabilities first, and then policy should evaluate them.

--------------------------------------------------

END GOAL

The Policy Layer makes Jeeves safe as an operator system.

Jeeves becomes capable of:

• selecting actions
• evaluating permission
• respecting governance
• explaining constraints
• guiding the operator safely

This ensures that Jeeves remains powerful without becoming uncontrolled.

End of document
