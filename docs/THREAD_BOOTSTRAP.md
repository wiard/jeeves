# JEEVES SYSTEM BOOTSTRAP

You are joining an existing system. Do not redesign it.

First read:

docs/JEEVES_SYSTEM_CONTEXT.md
docs/JEEVES_SYSTEM_CONSTITUTION.md
docs/JEEVES_ORCHESTRATOR.md
docs/JEEVES_COMMAND_LANGUAGE.md
docs/JEEVES_CAPABILITY_REGISTRY.md
docs/JEEVES_POLICY_LAYER.md
docs/JEEVES_GATEWAY_HARDENING_PROMPT.md
docs/JEEVES_MISSION_CONTROL_PROMPT.md

--------------------------------------------------

SYSTEM OVERVIEW

Jeeves is not a chatbot.

Jeeves is the operator interface and control shell of the system.

The system consists of:

Jeeves iPhone App
→ operator interface and mission control

OpenClashd Gateway
→ deterministic gateway and governance layer

Kernel
→ deterministic execution layer

Knowledge
→ immutable system memory

--------------------------------------------------

CORE SYSTEM FLOW

Human Intent
→ Jeeves Orchestrator
→ Capability Registry
→ Policy Layer
→ Screen Directive
→ Gateway Action
→ Kernel
→ Knowledge

--------------------------------------------------

JEEVES RESPONSIBILITIES

Jeeves does three things:

1) Interpret operator intent
2) Navigate and control screens
3) Trigger governed system actions

Jeeves does NOT bypass the gateway.

Jeeves does NOT directly execute backend logic.

All execution must go through:

Gateway → Kernel → Knowledge.

--------------------------------------------------

CURRENT ARCHITECTURE

Major components:

JeevesOrchestrator
→ interprets intent and produces directives

JeevesDirective
→ navigation or system action instruction

ScreenStatePreset
→ screen configuration state

ScreenStateReadable
→ screen introspection interface

JeevesCapabilityRegistry
→ what the system can do

JeevesPolicyLayer
→ what the system is allowed to do

--------------------------------------------------

GATEWAY HARDENING

The networking layer has been hardened.

Requirements:

• single gateway endpoint
• single token flow
• RouteContract defines all routes
• AuthorizedRequestBuilder constructs all requests
• GatewayManager.resolveEndpoint() is the only resolution path
• no duplicate endpoint discovery
• no parallel gateways

--------------------------------------------------

COMMAND LANGUAGE

Jeeves supports a command mode.

Command mode activates when the user types:

jeeves <command>

Example:

jeeves open browser domain=financial
jeeves show radar
jeeves inspect system
jeeves explain signals

Commands are parsed as:

verb target arg=value arg=value

Commands map into:

JeevesDirective + ScreenStatePreset.

--------------------------------------------------

MISSION CONTROL

Jeeves Mission Control contains multiple screens:

Stream
Lobby
Jeeves
Observatory
House
Logbook
AI Browser
Marketplace
Deployments
My Agents

The orchestrator navigates between these screens.

--------------------------------------------------

DEVELOPMENT RULES

When modifying the system:

Do NOT redesign architecture.

Do NOT bypass the gateway.

Do NOT introduce duplicate networking layers.

All changes must be:

• additive
• minimal
• testable
• compatible with the existing architecture.

--------------------------------------------------

TASK EXECUTION

When implementing new features:

1) propose architecture
2) list files to create/modify
3) produce minimal diffs
4) preserve existing flows

--------------------------------------------------

You are now aware of the Jeeves system architecture.
Continue from the current state of the repository.
