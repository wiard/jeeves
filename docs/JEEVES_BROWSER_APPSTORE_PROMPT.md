Read AGENTS.md and docs/ first.

Goal:

Design a Jeeves AI Browser that behaves like an App Store for AI configurations.

Important constraint:

The existing Mission Control UI must remain intact.

Current pages that must NOT be replaced:

Mission Control
Radar
Fabric
Knowledge
Observatory
Architecture
Jeeves

These represent the operator cockpit.

The new AI Browser must be an additional section.

Example navigation structure:

Mission Control
Radar
Fabric
Knowledge
Observatory
Architecture
Jeeves

AI Browser
Marketplace
Deployments
My Agents

--------------------------------------------------

CONTEXT

Jeeves is the interface of a multi-layer AI platform.

CLASHD27
Discovery radar that scans research papers and repositories.

SafeClash
AI registry and certification layer.

openclashd
Governance kernel controlling the lifecycle:

Discovery → Proposal → Approval → Action → Knowledge

Jeeves
User interface for discovery and deployment.

--------------------------------------------------

BROWSER PURPOSE

The AI Browser allows users to:

discover AI configurations
compare them
inspect certification
deploy them safely

Deployment always happens through proposal and approval.

--------------------------------------------------

BROWSER STRUCTURE

The AI Browser should contain:

FEATURED
Curated AI recommendations.

BROWSE BY CATEGORY
Financial
Legal
Research
Education
Automation
Security
Creativity

CERTIFIED
SafeClash certified configurations.

EMERGING
Ideas discovered by CLASHD27.

DETAIL PAGE
Shows description, capabilities, constraints, benchmarks, certificate.

--------------------------------------------------

LIFECYCLE VISIBILITY

When a configuration is deployed show the lifecycle:

SafeClash registry
↓
Proposal created
↓
Approval granted
↓
Governed action
↓
Knowledge artifact stored

This must appear as a timeline.

--------------------------------------------------

DESIGN STYLE

The UI must feel:

calm
legible
trustworthy
operator-centered

Avoid:

busy dashboards
chatbot-like interfaces
marketing visuals

Prefer:

structured cards
clear categories
explainable rankings
timeline views

--------------------------------------------------

YOUR TASK

Design the Jeeves AI Browser.

Provide:

layout structure
main components
card types
navigation flow
interaction model
textual wireframes

Do not write code yet.

Focus on designing the experience.
