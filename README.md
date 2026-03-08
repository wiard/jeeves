# Jeeves iOS

Native iOS companion for OpenClashd. Jeeves now uses the same real gateway APIs as the web frontend for proposals and observatory data.

## Connection Modes

- `Mock` (explicit only): enabled by user choice (`Gebruik mock modus`) or runtime `MOCK=1`.
- `Lokale gateway (echt)`: local/OpenClashd host (localhost, LAN IP, `.local`).
- `Website backend (echt)`: non-local host using the same HTTP API surface.

Default runtime behavior is real backend mode when host/token config exists. Jeeves no longer silently falls back to mock when token/backend is missing.

## Shared API Surface (Web + iOS)

Jeeves iOS uses the same proposal and observatory endpoints as the web UI in `openclashd-v2`:

- `GET /api/agents/proposals`
- `POST /api/agents/proposals/decide`
- `GET /api/observatory/stream?limit=...`
- `GET /api/signals/state`
- `GET /api/radar/status`
- `GET /api/radar/activations`
- `GET /api/radar/collisions`
- `GET /api/radar/emergence`
- `GET /api/radar/clusters`
- `GET /api/radar/sources`
- `GET /api/radar/gravity`
- `GET /api/radar/discoveries`
- `GET /api/fabric/state`
- `GET /api/fabric/clock`
- `GET /api/fabric/emergence`
- `GET /api/lobby/challenges`
- `GET /api/knowledge/status`
- `GET /api/knowledge/emergence`
- `GET /api/observatory/alerts`
- `GET /api/conductor/health`
- `GET /api/conductor/state`
- `POST /api/conductor/intent`
- `GET /api/conductor/audit`

Auth model matches web:

- token as query param `?token=...`
- plus `Authorization: Bearer <token>` header where applicable

Approval contract:

- request body: `{ "proposalId": "...", "decision": "approve|deny", "reason": "..." }`
- backend status result: `approved|denied`

## Real Mode Setup (Local)

1. Run OpenClashd gateway.
2. Configure Jeeves host/port in onboarding or runtime config.
3. Provide a valid conductor token (Keychain/runtime file/env).

Optional runtime file in app Documents sandbox:

```json
{
  "host": "192.168.1.23",
  "port": 19001,
  "token": "YOUR_TOKEN"
}
```

Environment overrides:

- `HOST`
- `PORT`
- `TOKEN`
- `MOCK=1` (explicit mock)

## Intentional Mock Mode (Development)

Mock/demo proposal generation is kept for development previews only. To use mock intentionally:

- select `Gebruik mock modus` in onboarding, or
- run with `MOCK=1`, or
- connect to host `mock`

## Notes

- Proposal cards keep existing UI/UX but now render real backend proposals in real mode.
- Approve/Reject (`Goedkeuren` / `Afwijzen`) calls the real backend in real mode.
- If backend is unavailable, Jeeves shows disconnected/unavailable state instead of fake data.
