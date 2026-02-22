# Implementation Plan: P2P File Transfer

**Branch**: `037-p2p-file-transfer` | **Date**: 2026-02-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/037-p2p-file-transfer/spec.md`

## Summary

Implement peer-to-peer file transfer over WebRTC DataChannel. Users in a P2P lobby can send files directly to each other with chunked transfer, progress tracking, SHA-256 integrity verification, and resume after disconnection. All file data flows exclusively through the DataChannel — no server involvement. The implementation follows the hook=wiring/lib=logic pattern with `file_transfer.js` (pure logic) and `file_transfer_hook.js` (DOM wiring).

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+ (backend, minimal changes), JavaScript ES2020+ (frontend, bulk of implementation)
**Primary Dependencies**: Phoenix 1.8+, LiveView 1.0+, retro CSS framework, existing WebRTC infrastructure (034-036)
**Storage**: No new database tables — all transfer state is ephemeral (client-side JS memory)
**Testing**: Vitest + jsdom (JS), ExUnit (Elixir — LiveView component tests)
**Target Platform**: Modern browsers with WebRTC DataChannel + crypto.subtle support
**Project Type**: Umbrella (Elixir) with JS assets
**Performance Goals**: 10 MB transfer in <30 seconds, progress updates ≥4/second, hash verification <2 seconds for 500 MB
**Constraints**: Max 500 MB file size (configurable), one transfer at a time per session, 64 KB chunks, extension-only validation
**Scale/Scope**: 2 peers per session, ephemeral state, no persistence

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Relevant? | Status | Notes |
|-----------|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | Yes | PASS | Backend in Elixir/Phoenix. JS is for browser-native WebRTC APIs (no JS frameworks). |
| II. Umbrella with Bounded Contexts | Yes | PASS | Reuses existing `RetroHexChat.P2P` context. No new bounded contexts. |
| III. OTP Process Architecture | Yes | PASS | Reuses existing SessionServer GenServer. No new processes needed. |
| IV. Test-First Development | Yes | PASS | Vitest for JS lib + hook tests. ExUnit for LiveView component tests. |
| V. Contracts and Behaviours | Minimal | PASS | No new Elixir behaviours needed (no new commands). DataChannel protocol is the contract. |
| VI. Static Analysis from Day One | Yes | PASS | ESLint, Prettier, Credo, Dialyxir all enforced. |
| VII. Lean LiveViews | Yes | PASS | LiveView handles only event routing and assigns. All transfer logic in JS lib. |
| VIII. retro Design Fidelity | Yes | PASS | Uses retro design system progress-indicator, standard buttons, window styling. |
| IX. Hot/Cold Data Separation | Yes | PASS | All state is ephemeral (hot — JS memory). No cold storage needed. |
| X. Scalable Architecture | Minimal | PASS | P2P by nature — no server scaling concerns for file data. |
| XI. User-Facing Documentation | No | N/A | Help documentation explicitly out of scope per spec. |

**Pre-Phase 0 Gate**: PASS — no violations.

## Project Structure

### Documentation (this feature)

```text
specs/037-p2p-file-transfer/
├── plan.md                          # This file
├── spec.md                          # Feature specification
├── research.md                      # Phase 0: research decisions
├── data-model.md                    # Phase 1: data model (ephemeral entities)
├── quickstart.md                    # Phase 1: development quickstart
├── contracts/
│   ├── datachannel-protocol.md      # DataChannel binary protocol
│   └── javascript-api.md            # JS module API contracts
└── checklists/
    └── requirements.md              # Spec quality checklist
```

### Source Code (repository root)

```text
apps/retro_hex_chat_web/
├── assets/
│   ├── js/
│   │   ├── lib/
│   │   │   ├── file_transfer.js     # NEW — pure transfer logic (protocol, chunking, hashing, progress)
│   │   │   └── webrtc.js            # MODIFIED — add createDataChannel() export
│   │   ├── hooks/
│   │   │   ├── file_transfer_hook.js  # NEW — DOM wiring (drag-drop, file input, progress UI, download)
│   │   │   └── webrtc_hook.js         # MODIFIED — create DataChannel, coordinate with FileTransferHook
│   │   └── app.js                     # MODIFIED — register FileTransferHook
│   ├── css/
│   │   ├── file-transfer.css          # NEW — progress bar, drop zone, file offer UI
│   │   └── app.css                    # MODIFIED — import file-transfer.css
│   └── test/
│       ├── lib/
│       │   └── file_transfer.test.js  # NEW — comprehensive lib tests
│       └── hooks/
│           └── file_transfer_hook.test.js  # NEW — hook wiring tests
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   └── p2p_lobby.ex               # MODIFIED — add file transfer UI components
│   └── live/
│       └── p2p_session_live.ex         # MODIFIED — handle ft_* events, pass config
└── ...

apps/retro_hex_chat/
├── config/
│   └── runtime.exs                    # MODIFIED — read FILE_TRANSFER_* env vars
└── ...
```

**Structure Decision**: This feature is primarily a JavaScript implementation layered on top of the existing P2P infrastructure. The Elixir changes are minimal — configuration reading and thin LiveView event handlers. No new domain modules, schemas, or migrations.

## Constitution Re-Check (Post Phase 1 Design)

| Principle | Status | Change from Pre-Check |
|-----------|--------|----------------------|
| I. Elixir & Phoenix Exclusive | PASS | No change |
| II. Umbrella with Bounded Contexts | PASS | No change |
| III. OTP Process Architecture | PASS | No change |
| IV. Test-First Development | PASS | No change — JS tests cover lib+hook, Elixir tests cover LiveView |
| V. Contracts and Behaviours | PASS | No change |
| VI. Static Analysis from Day One | PASS | No change |
| VII. Lean LiveViews | PASS | No change — LiveView only routes events and renders assigns |
| VIII. retro Design Fidelity | PASS | No change — retro design system progress-indicator used |
| IX. Hot/Cold Data Separation | PASS | No change |
| X. Scalable Architecture | PASS | No change |

**Post-Design Gate**: PASS — no violations. No entries needed in Complexity Tracking.
