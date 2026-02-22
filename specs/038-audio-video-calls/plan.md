# Implementation Plan: Audio/Video Calls

**Branch**: `038-audio-video-calls` | **Date**: 2026-02-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/038-audio-video-calls/spec.md`

## Summary

Add P2P audio and video calling over WebRTC to RetroHexChat. Create a `media.js` pure logic module for media acquisition, track management, quality monitoring, device selection, and codec preferences. Create a `MediaHook` for DOM wiring following the existing hook=wiring/lib=logic pattern. Extend the P2P lobby with call UI components and the LiveView with call event handlers. All media flows peer-to-peer through the existing RTCPeerConnection — zero bytes through the server.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+ (backend), JavaScript ES2020+ (frontend)
**Primary Dependencies**: Phoenix 1.8+, LiveView 1.0+, retro CSS framework, esbuild. Browser-native WebRTC APIs (getUserMedia, addTrack, replaceTrack, getStats, enumerateDevices, Picture-in-Picture). Zero new npm/Elixir dependencies.
**Storage**: N/A — all call state is ephemeral (LiveView assigns + JS variables). No database migrations.
**Testing**: Vitest + jsdom (JS), ExUnit (Elixir E2E). Mock navigator.mediaDevices and RTCPeerConnection.getStats().
**Target Platform**: Modern browsers (Chrome, Firefox, Safari, Edge) with WebRTC support.
**Project Type**: Web application (Phoenix umbrella)
**Performance Goals**: Audio call setup < 5s, video call setup < 8s, mute/camera toggle < 500ms, device switch < 2s, quality update < 3s.
**Constraints**: All media P2P only. Local video muted. Hook=wiring/lib=logic separation.
**Scale/Scope**: 1-to-1 calls only. ~4 new JS files, ~1 new CSS file, ~2 modified Elixir files, ~2 modified JS files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | Yes | PASS | No new frameworks. Browser-native WebRTC APIs only. |
| II. Umbrella Bounded Contexts | Yes | PASS | Media logic stays in web layer (JS). LiveView handlers delegate to P2P context for PubSub. |
| III. OTP Process Architecture | No | N/A | No new GenServers. Uses existing P2P SessionServer. |
| IV. Test-First Development | Yes | PASS | media.js unit tests + media_hook.js behavioral tests + E2E. |
| V. Contracts and Behaviours | Yes | PASS | media.js API contract defined. Hook event contract defined. |
| VI. Static Analysis | Yes | PASS | ESLint, Prettier, Credo, Dialyzer enforced. @spec on all new public Elixir functions. |
| VII. Lean LiveViews | Yes | PASS | LiveView handlers only update assigns and push events. All media logic in JS. |
| VIII. retro Design Fidelity | Yes | PASS | Call UI uses retro components and design tokens. |
| IX. Hot/Cold Data Separation | Yes | PASS | All call state is ephemeral (hot). No persistent data. |
| X. Scalable Architecture | No | N/A | 1-to-1 calls only. No scaling concerns for this feature. |
| XI. User-Facing Documentation | Yes | PASS | Help topics for audio calls, video calls, and device management. |

**Post-Phase 1 re-check**: All principles still PASS. No violations.

## Project Structure

### Documentation (this feature)

```text
specs/038-audio-video-calls/
├── plan.md              # This file
├── research.md          # Phase 0: technology decisions
├── data-model.md        # Phase 1: client-side entities
├── quickstart.md        # Phase 1: integration guide
├── contracts/           # Phase 1: API contracts
│   ├── media-js-api.md
│   ├── media-hook-events.md
│   └── liveview-events.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat_web/
├── assets/
│   ├── js/
│   │   ├── lib/
│   │   │   └── media.js              # NEW: Pure media logic
│   │   ├── hooks/
│   │   │   ├── media_hook.js         # NEW: DOM wiring for media
│   │   │   └── webrtc_hook.js        # MODIFIED: add media_pc_ready dispatch, onnegotiationneeded
│   │   └── app.js                    # MODIFIED: register MediaHook
│   ├── test/
│   │   ├── lib/
│   │   │   └── media.test.js         # NEW: Unit tests
│   │   └── hooks/
│   │       └── media_hook.test.js    # NEW: Hook behavioral tests
│   └── css/
│       ├── media-call.css            # NEW: Call UI styles
│       └── app.css                   # MODIFIED: import media-call.css
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   └── p2p_lobby.ex              # MODIFIED: add call UI components
│   └── live/
│       └── p2p_session_live.ex       # MODIFIED: add call event handlers
```

**Structure Decision**: Follows existing umbrella web application structure. All new files are in the web app's assets (JS/CSS) and components/live (Elixir). No new bounded contexts or OTP processes needed.

## Complexity Tracking

No constitution violations. No complexity justifications needed.
