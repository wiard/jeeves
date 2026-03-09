Jeeves is not a chatbot.

Jeeves is the operator interface for the system.

Human intent
→ Jeeves Orchestrator
→ Screen Directive
→ Gateway Action
→ Kernel
→ Knowledge
# Jeeves Orchestrator

Jeeves is the central orchestrator of the Jeeves iPhone application.

The chat interface acts as the command layer of the system.

User input is interpreted as an intent and translated into navigation
or system actions inside the app.

Architecture layers:

User input
↓
JeevesOrchestrator
↓
JeevesDirective
↓
ScreenStatePreset
↓
UI navigation
