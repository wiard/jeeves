# JEEVES MEMORY AND SESSION MODEL

This document defines how Jeeves should hold context over time like a real operator assistant.

Jeeves is not a chatbot.

Jeeves is the operator interface and control shell of the system.

To become a real operator assistant, Jeeves must not only route, inspect, and explain. It must also remember relevant session context safely and explicitly.

--------------------------------------------------

PURPOSE

The Memory and Session Model defines:

• what Jeeves should remember
• what Jeeves should not remember
• what belongs to a short-lived session
• what belongs to durable operator context
• how memory supports orchestration without bypassing governance

--------------------------------------------------

POSITION IN THE ARCHITECTURE

Human Intent
→ Jeeves Orchestrator
→ Capability Registry
→ Policy Layer
→ Session Context
→ Screen Directive / Gateway Action
→ Kernel
→ Knowledge

Session context enriches orchestration.
It must not replace the gateway, kernel, or knowledge layer.

--------------------------------------------------

TWO TYPES OF MEMORY

1. Session Memory
Short-lived working context for the current operator session.

2. Persistent Operator Memory
Longer-lived preferences and recurring context that help Jeeves behave consistently for the operator.

--------------------------------------------------

SESSION MEMORY

Session memory should contain temporary operational context such as:

• current screen
• last directive
• last recommended focus
• current browser filters
• last inspected system area
• recent operator questions
• current mission context
• recent command results

Examples:

• user asked to inspect radar pressure
• user is currently focused on AI Browser / financial / investing
• Jeeves recently recommended Mission Control because approvals were high
• current session is operating against gateway 192.168.64.1:19001

Session memory should remain lightweight and easy to reset.

--------------------------------------------------

PERSISTENT OPERATOR MEMORY

Persistent memory should be narrow and useful.

Examples:

• preferred screen language
• preferred default browser domain
• preferred operator mode
• trusted gateway preference
• recurring workflow patterns
• preferred summary style

Persistent memory must not become a hidden black box.

It must remain:

• inspectable
• limited
• explainable

--------------------------------------------------

WHAT JEEVES SHOULD NOT STORE

Jeeves should not silently store everything.

Do not store:

• raw entire chats by default as operator memory
• hidden speculative beliefs
• broad uncontrolled personal profiling
• duplicate copies of backend knowledge objects
• arbitrary private data unrelated to operation

Backend knowledge remains the canonical system record.

Jeeves memory is only operator-assistance context.

--------------------------------------------------

SESSION MODEL

A session should have a formal model.

Suggested fields:

• sessionId
• startedAt
• currentScreen
• lastDirective
• activeGateway
• currentMissionFocus
• currentBrowserPreset
• lastOperatorQuestion
• recentCapabilitiesUsed
• recentPolicyDecision
• recentAssessmentSummary

This session object should help Jeeves remain coherent during active use.

--------------------------------------------------

MEMORY MODEL

Suggested memory object categories:

1. Navigation Memory
What screen the operator has been using.

2. Focus Memory
What Jeeves recently considered important.

3. Preference Memory
Stable user preferences.

4. Workflow Memory
Small recurring operator patterns.

These categories should remain compact and explicit.

--------------------------------------------------

DESIGN PRINCIPLES

The memory model must be:

• additive
• explicit
• inspectable
• minimal
• explainable
• governance-compatible

It must not create hidden autonomous behavior.

It must not bypass the existing architecture.

It must support Jeeves as an operator assistant.

--------------------------------------------------

RULES FOR USE

Session context may influence:

• recommendations
• explanations
• default screen suggestions
• default browser presets
• continuity of operator interaction

Session context may not directly authorize actions.

Memory does not replace policy.

Memory does not replace capability selection.

Memory only enriches the operator experience.

--------------------------------------------------

FIRST VERSION

The first version should remain simple.

It only needs:

• session context object
• current screen memory
• last directive memory
• current browser preset memory
• current mission focus memory
• recent operator input memory

Do not build long-term autonomous memory first.

Start with a clear session model.

--------------------------------------------------

END GOAL

The Memory and Session Model makes Jeeves feel like a real operator assistant.

Jeeves will be able to:

• remember what the operator is doing
• preserve continuity across steps
• suggest the next useful screen
• keep context without becoming uncontrolled
• remain aligned with the governed architecture

End of document
