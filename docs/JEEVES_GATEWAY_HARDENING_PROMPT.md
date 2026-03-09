Read AGENTS.md and docs first.

Read:

docs/JEEVES_SYSTEM_CONTEXT.md
docs/JEEVES_ORCHESTRATOR.md
docs/JEEVES_COMMAND_LANGUAGE.md

Goal:

Harden the Jeeves gateway connection model so that the app never suffers from route drift, token mismatches, duplicate gateway resolution, or inconsistent HTTP request behavior.

Current problems:

Multiple files construct URLRequests.
Token usage is inconsistent.
Routes are scattered across files.
Several ViewModels resolve the gateway independently.

This must be consolidated.

Requirements:

The Jeeves networking layer must use:

• one active gateway endpoint
• one token flow
• one route contract
• one authorized request builder

Discovery may suggest endpoints but must never create parallel gateways.

Add a health validation system for:

core
chat
browser
observatory
deployments

Design:

Create the following networking primitives:

RouteContract
AuthorizedRequestBuilder
ResolvedGatewayEndpoint
GatewayHealthValidator

Then migrate all networking code to use them.

Files to update include:

GatewayManager
GatewayClient
SafeClashClient
ConductorAPI
ObservatoryAPI
CubeOracleAPI

ViewModels must stop resolving gateway endpoints independently.

Only GatewayManager resolves endpoints.

All HTTP requests must go through AuthorizedRequestBuilder.

Do not redesign the UI.

Do not change app behavior.

Only stabilize the networking architecture.

Output:

• new files
• modified files
• migration order
• minimal diff implementation plan
