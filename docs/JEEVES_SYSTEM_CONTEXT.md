# Jeeves System Context

Jeeves is not a chatbot.

Jeeves is the operator interface and control shell of the Jeeves iPhone application.

The application is a front-end for a governed AI operating environment built around OpenClashd.

The architecture of the system is:

Human Intent
→ Jeeves Orchestrator
→ Screen Directive
→ Gateway Action
→ Kernel
→ Knowledge

Components:

Jeeves (iOS App)
Operator interface and orchestration layer.

OpenClashd
Governance kernel controlling system behavior.

CLASHD27
Research discovery radar.

SafeClash
AI configuration registry and certification layer.

The Jeeves interface contains multiple operational screens:

Mission Control (Stream)
Radar
Fabric
Knowledge
Observatory
Architecture
Jeeves Chat
AI Browser
Deployments
Marketplace

The Jeeves chat is not a conversational chatbot.

It is the command interface for navigating and operating the system.

All system actions must pass through the governed kernel.

Direct execution is not allowed.

The gateway model must remain stable:

• One active endpoint
• One token flow
• One route contract
• One authorized request builder
• No parallel gateway resolution paths

All screen changes must occur through JeevesDirective and ScreenStatePreset.

The orchestrator decides navigation.
The UI renders it.
The gateway performs actions.
The kernel governs them.
Knowledge persists outcomes.

This architecture must remain stable.
