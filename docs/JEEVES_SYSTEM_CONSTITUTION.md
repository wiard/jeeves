# JEEVES SYSTEM CONSTITUTION

This document defines the non-negotiable architectural rules of the Jeeves system.

Every AI agent working in this repository must read this document before making any changes.

These rules override all implementation suggestions.

---

# SYSTEM PURPOSE

Jeeves is not a chatbot.

Jeeves is the operator interface of the Jeeves application.

The system is designed as a controlled orchestration layer that connects the human operator with the underlying AI infrastructure.

Jeeves acts as the command shell of the system.

---

# CORE SYSTEM FLOW

All operations in the system must follow this flow:

Human Intent
→ Jeeves Orchestrator
→ Screen Directive
→ Gateway Action
→ Kernel
→ Knowledge

This flow must never be bypassed.

---

# ARCHITECTURAL PRINCIPLES

The system is built around five stable layers.

Operator Layer
Jeeves UI and Chat Interface.

Orchestration Layer
JeevesOrchestrator and JeevesDirective.

Gateway Layer
GatewayManager, RouteContract, AuthorizedRequestBuilder.

Kernel Layer
openclashd-v2 system kernel.

Knowledge Layer
Knowledge objects stored and produced by the kernel.

Each layer has a strict responsibility and must not leak into other layers.

---

# GATEWAY RULES

The gateway model must remain hardened.

The system must always maintain:

• a single active gateway endpoint
• a single token flow
• a single route contract
• one AuthorizedRequestBuilder
• one endpoint resolution path

Forbidden patterns:

• constructing URLs manually
• duplicating endpoint resolution
• bypassing GatewayManager
• bypassing AuthorizedRequestBuilder
• sending requests without RouteContract

All network requests must use:

GatewayManager
→ AuthorizedRequestBuilder
→ RouteContract

---

# TOKEN RULES

The token system must remain deterministic.

Only GatewayManager may resolve or store tokens.

The token must flow through:

GatewayManager
→ AuthorizedRequestBuilder
→ API Client
→ Request

No other part of the system may store or manipulate tokens.

---

# JEEVES ORCHESTRATION RULES

JeevesOrchestrator is the only component allowed to interpret user intent.

ChatView must not directly control screens.

ChatView must always send messages to:

JeevesOrchestrator

The orchestrator produces:

JeevesDirective

Direct UI navigation from ChatView is forbidden.

---

# COMMAND LANGUAGE RULES

Jeeves supports two input modes.

Natural Language Mode
Standard chat interpretation.

Command Mode
Activated when a message starts with:

jeeves

Example:

jeeves open browser domain=financial

Command syntax:

verb target arg=value arg=value

Commands must map into the existing:

JeevesDirective
ScreenStatePreset

The command layer must not bypass governance or backend routing.

---

# GOVERNANCE RULES

No operation may directly trigger backend behavior without passing through the gateway.

All backend actions must go through:

GatewayManager
→ Kernel
→ Knowledge

This ensures that:

• actions are governed
• audit trails exist
• knowledge artifacts are generated

---

# SCREEN CONTROL RULES

Screens are controlled through the AppScreen registry.

Screens must never be addressed by numeric tab indexes.

Only the AppScreen enum may be used.

Example:

AppScreen.aiBrowser
AppScreen.observatory
AppScreen.house

---

# STATE INSPECTION RULES

Screens expose system summaries using:

ScreenStateReadable

This allows Jeeves to reason about system state without tightly coupling to view logic.

ScreenStateReadable must only return summaries, never raw backend structures.

---

# SAFETY RULES

AI agents modifying this repository must follow these rules:

Do not redesign the application architecture.

Do not introduce new network layers.

Do not bypass the gateway.

Do not introduce parallel endpoint resolution.

Do not modify the kernel interface without explicit operator approval.

All changes must be incremental and reversible.

---

# IMPLEMENTATION STRATEGY

All large architectural work must follow the execution phases defined in:

docs/JEEVES_MASTER_EXECUTION_PROMPT.md

Phases must be implemented in order.

Each phase must compile before the next phase begins.

---

# AI DEVELOPMENT CONTRACT

When an AI agent begins work in this repository it must:

1. Read AGENTS.md
2. Read all documents in docs/
3. Read this constitution
4. Follow the execution plan

If a suggestion conflicts with this document, the constitution takes precedence.

---

# END STATE

The final system should behave as an operator console for AI systems.

Jeeves will be able to:

• navigate screens
• inspect system state
• guide the operator
• propose governed actions
• observe system evolution

All interactions remain traceable and governed.

---

End of Constitution
