# Jeeves

A native iOS app for OpenClashd — your personal AI butler in your pocket.

## What it does

Jeeves connects to your OpenClashd gateway via WebSocket and gives you a secure, consent-aware interface to your AI butler. Every action goes through the SafeClash kernel: consent, channel trust, budget, and audit.

```
iPhone (Jeeves app)
    ↓ WebSocket
OpenClashd Gateway (your Mac)
    ↓
SafeClash Kernel → Consent × Trust × Budget
    ↓
Jeeves (agent) → Tools (with permission)
```

## Screens

**Jeeves** — Chat with your butler. Consent prompts appear as orange cards. Blocked actions appear as red cards. You approve or deny from your phone.

**Huis** — The Great Room in your pocket. Kernel status, budget progress bars, connected channels with trust levels, and a kill switch.

**Logboek** — Full audit trail. Every action Jeeves took, which channel, what it cost, whether it was approved or blocked.

**Instellingen** — Gateway connection, token management, display preferences.

## Architecture

- **SwiftUI** — native iOS interface
- **SwiftData** — local chat history
- **URLSession WebSocket** — native connection to gateway
- **Keychain** — token storage (never in UserDefaults)
- **Zero dependencies** — only Apple frameworks

## Security

- No credentials stored on device (only gateway token in Keychain)
- No direct tool access — everything goes through the gateway
- No internet traffic to third parties
- No analytics, no tracking, no telemetry
- Channel trust level: `trusted` (your device, your app)

## Current Status

- [x] Chat UI with message bubbles
- [x] Consent cards (orange/red)
- [x] Mock gateway for development
- [x] Onboarding flow
- [x] Dark theme (Jeeves gold accent)
- [x] House status tab
- [x] Logbook tab
- [x] Settings tab
- [ ] Live WebSocket connection to OpenClashd gateway
- [ ] Speech input
- [ ] Bonjour gateway discovery
- [ ] Real iPhone deployment

## Requirements

- Xcode 16.4+ (Xcode 26.3 recommended for Claude Agent)
- iOS 18.0+
- An OpenClashd v2 gateway running on your local network (or mock mode)

## Related

- [OpenClashd v2](https://github.com/wiard/openclashd-v2) — the kernel
- [Angelopp](https://github.com/wiard/angelopp) — USSD platform for Kenya

## Philosophy

"Not Jarvis. Jeeves. An AI that can do anything — and asks permission first."

Your butler. Your house. Your rules.
