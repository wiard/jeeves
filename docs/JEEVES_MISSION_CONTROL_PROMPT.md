Read AGENTS.md and docs first.

Read:

docs/JEEVES_SYSTEM_CONTEXT.md
docs/JEEVES_ORCHESTRATOR.md
docs/JEEVES_COMMAND_LANGUAGE.md

Goal:

Turn Jeeves into the central Mission Control interface of the entire system.

The Jeeves chat becomes the operational command layer.

Users should be able to control the application through intent.

Examples:

show radar pressure
show discoveries
open ai browser
inspect deployments
explain signals
show system health

The orchestrator should:

interpret user intent
generate JeevesDirective
apply ScreenStatePreset
navigate the UI

The UI must remain stable.

Existing screens must not be redesigned.

Mission Control screens:

Stream
Radar
Fabric
Knowledge
Observatory
Architecture
AI Browser
Deployments

The orchestrator can:

navigate to screens
focus sections
explain screen state
summarize system status

Later phases may allow governed actions.

But in this phase the system must remain read-only.

Design inspiration should follow operator consoles similar to large-scale AI systems.

But do not describe those systems.

Focus on:

clear routing
screen directives
state inspection
system summaries

Output:

• Mission Control architecture
• JeevesOrchestrator extensions
• screen inspection patterns
• integration with ScreenStateReadable
• minimal Swift implementation plan
