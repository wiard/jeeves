# Jeeves iPhone App — App Overview

Updated: 2026-03-01

## 1) Repository map

Top-level:

- `jeeves/` — App source (SwiftUI views, models, networking, theme)
- `jeeves.xcodeproj/` — Xcode project
- `jeevesTests/` — Unit test target (placeholder)
- `jeevesUITests/` — UI test target (default scaffold)
- `README.md` — Product/readme summary
- `AI_CONTEXT.md` — architecture/security constitution

Key app folders:

- `jeeves/Views/Chat/` — Chat UI + consent cards
- `jeeves/Views/House/` — House/kernel status UI
- `jeeves/Views/Logbook/` — Audit log UI
- `jeeves/Views/Settings/` — Connection + security settings
- `jeeves/Networking/` — Gateway manager, mock gateway, keychain helper
- `jeeves/Models/` — SwiftData models + protocol DTOs
- `jeeves/Theme/` — app colors/typography/haptics

## 2) iOS framework and technical stack

Detected framework and project type:

- Native Apple app (`jeeves.xcodeproj`)
- **SwiftUI** for UI
- **SwiftData** for local persistence
- **URLSession WebSocket** for gateway transport
- **Keychain** for token storage
- No external package manager in repo (`Package.swift`, `Podfile`, `package.json` not present in app repo)

Main entry points:

- `jeeves/jeevesApp.swift` — app bootstrap + shared `ModelContainer`
- `jeeves/ContentView.swift` — onboarding gate + tab/split navigation

## 3) Networking layer

Current gateway integration is in:

- `jeeves/Networking/GatewayManager.swift`
- `jeeves/Models/GatewayProtocol.swift`
- `jeeves/Networking/MockGateway.swift`

Current behavior:

- Default is **mock mode enabled** (`useMock = true`)
- WebSocket target when enabled: `ws://<host>:<port>/ws/ios-app`
- Message send path exists (`OutgoingMessage.chat(...)`)
- Consent response send path exists (`ConsentResponseMessage`)
- Status/audit/kill-switch fetch methods are currently mock-only (non-mock paths return `notConnected`)

## 4) Persistence model

Persistence is local SwiftData:

- `ChatMessage` (chat + consent + blocked states)
- `GatewayConnection` (host/port/channel config)

Security storage:

- Token read/write/delete in Keychain via `jeeves/Networking/KeychainHelper.swift`

## 5) Build and run instructions (exact commands)

From repo root:

```bash
cd /Users/wiardvasen/jeeves
xcodebuild -list
```

Detected project/scheme output summary:

- Project: `jeeves`
- Targets: `jeeves`, `jeevesTests`, `jeevesUITests`
- Scheme: `jeeves`

Command-line build attempt used:

```bash
cd /Users/wiardvasen/jeeves
xcodebuild -project jeeves.xcodeproj -scheme jeeves -destination 'generic/platform=iOS' -derivedDataPath /Users/wiardvasen/jeeves/.derivedData build
```

Current CLI build status:

- Fails at signing step: `Signing for "jeeves" requires a development team`
- Meaning: project compiles far enough to generate build graph, but cannot produce signed app artifact without team provisioning

Recommended local run path (Xcode):

1. `cd /Users/wiardvasen/jeeves && open jeeves.xcodeproj`
2. Select scheme `jeeves`
3. Set Signing Team under target `jeeves` -> Signing & Capabilities
4. Run on simulator/device

Optional local test command:

```bash
cd /Users/wiardvasen/jeeves
xcodebuild -project jeeves.xcodeproj -scheme jeeves -destination 'platform=iOS Simulator,name=iPhone 16' test
```

(Will also require a working simulator runtime and signing/provisioning alignment.)

## 6) Current screens/features

Implemented screens:

- **Jeeves** (`ChatView`)
  - Message list
  - Streaming text placeholder
  - Consent cards (approve/deny)
  - Blocked-action cards
- **Huis** (`HouseView`)
  - Kernel consent status
  - Budget cards
  - Channel trust/connection list
  - Kill switch toggle
- **Logboek** (`LogbookView`)
  - Audit list
  - Filters (period/status)
  - Search + detail sheet
- **Instellingen** (`SettingsView`)
  - Connection status
  - Token management UI
  - Display/security options

Onboarding:

- First-run host/port capture
- Mock mode quick path

## 7) Existing architecture (app-level)

```text
JeevesApp (SwiftUI App)
  -> ContentView
      -> OnboardingView (if no saved connection)
      -> Main Tabs
          1) ChatView
          2) HouseView
          3) LogbookView
          4) SettingsView

GatewayManager (@Observable, MainActor)
  -> MockGateway (default path)
  -> WebSocket transport (non-mock path)
  -> Decodes IncomingMessage protocol events

Persistence
  -> SwiftData ModelContainer
      - ChatMessage
      - GatewayConnection

Security
  -> KeychainHelper for gateway token
```

## 8) Current status and gaps

Status now:

- App structure is coherent and modular
- Mock mode experience is functional
- Security posture aligns with explicit consent UI pattern in chat

Gaps against production OpenClashd integration:

- Live WebSocket path in iOS points to `/ws/ios-app`, but current OpenClashd v2 gateway exposes HTTP/SSE routes (`/health`, `/api/message`, `/api/consent`, `/events`) in `src/gateway/server.ts`
- No implemented report-list/report-view API consumption in iOS yet
- No House Model 3-section UX (Huiskamer/Buitenwereld/Machinekamer) yet
- No local text-first cache for status/reports/report content yet
- Tests are mostly scaffold/basic in iOS repo

## 9) TODO marker scan

Search for `TODO`/`FIXME` in app repo returned no explicit markers.

## 10) OpenClashd v2 integration facts discovered (for next step)

From `/Users/wiardvasen/openclashd-v2`:

- Gateway server entrypoint: `src/gateway/server.ts`
- Default port: `19001` (`OPENCLASHD_PORT`/`PORT` override)
- Implemented routes now:
  - `GET /`
  - `GET /chat`
  - `GET /events` (SSE)
  - `GET /health`
  - `POST /api/message`
  - `POST /api/consent`
- Office/report generation exists in scripts:
  - `scripts/office/daily-briefing.mjs`
  - Writes markdown reports to `~/.jeeves-office/reports`

This means Jeeves can integrate immediately via existing HTTP + report files, with a later migration to dedicated iOS-focused API endpoints.
