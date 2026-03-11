# Gap Discovery Workflow

## Purpose

Jeeves is the operator cockpit for governed gap discovery.

The client does not execute gap remediation.
It renders proposals produced by CLASHD27 and routed through openclashd-v2 so a human can decide what happens next.

Canonical loop:

`signal -> proposal -> human approval -> bounded execution -> knowledge`

## Insertion Point

The feature lives in Mission Control / Lobby because that screen already owns governed review surfaces.

Existing architecture used:

- `ProposalPoller`
  refreshes proposals, decided proposals, receipts, and recent knowledge
- `GatewayClient.decideProposal`
  relays operator intent to openclashd-v2
- `LobbyView`
  remains the Mission Control surface for operator review

No new client-side execution path was introduced.

## UI Flow

### 1. Gap Inbox panel

Location:

- `Mission Control -> Gap Inbox`

Behavior:

- shows pending governed gap proposals
- shows tracked historical outcomes
- highlights why the gap matters instead of listing raw backend fields

Each gap card renders:

- title
- summary
- cube cell
- score strip
- audit hint

### 2. Gap detail view

Opening a card shows a dedicated detail sheet with:

- source evidence
- cube cell
- novelty / collision / residue / gravity / evidence / entropy / serendipity scores
- hypothesis
- verification plan
- kill tests
- recommended action
- current status
- downstream audit / execution / knowledge timeline
- explicit trust-boundary explanation

### 3. Operator actions

Pending proposals expose:

- approve
- deny
- defer

All three actions call the governed proposal decision endpoint.

Orange-risk approvals still use the existing confirmation path.

## Mock-first behavior

Demo mode now includes gap proposals and decided gap history so the workflow is reviewable without backend changes.

Live mode will render richer gap detail when proposal payloads include:

- `proposalType` or equivalent gap marker
- nested `gap` / `gapDetails`
- gap metadata inside `metadata` / `details` / `payload`

## Files

- `/Users/wiardvasen/jeeves/jeeves/Models/LobbyModels.swift`
- `/Users/wiardvasen/jeeves/jeeves/Polling/ProposalPoller.swift`
- `/Users/wiardvasen/jeeves/jeeves/Views/Lobby/LobbyView.swift`
- `/Users/wiardvasen/jeeves/jeeves/Views/Lobby/GapInboxView.swift`
- `/Users/wiardvasen/jeeves/jeeves/TextKeys.swift`
- `/Users/wiardvasen/jeeves/jeeves/Models/AppScreen.swift`

## Local Verification

1. Launch Jeeves in mock mode or against a gateway that exposes proposals.
2. Open Mission Control / Lobby.
3. Confirm the Gap Inbox panel appears between Radar and Incoming Tools.
4. Open a pending gap card and verify all required fields render.
5. Approve, deny, and defer a mock gap proposal.
6. Confirm status and downstream audit hints update after refresh.

## Rules

- Jeeves does not execute actions
- Jeeves does not bypass governance
- Jeeves is the human review layer

## UX Problem Solved

Before this change, governed discovery gaps were not surfaced as a first-class operator workflow.

Now the operator can:

- understand why a gap matters
- inspect supporting evidence before deciding
- act without bypassing governance
- track whether approval led to execution receipts and knowledge artifacts
