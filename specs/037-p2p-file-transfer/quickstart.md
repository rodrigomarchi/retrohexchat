# Quickstart: P2P File Transfer

**Feature**: 037-p2p-file-transfer
**Date**: 2026-02-16

## Prerequisites

- Existing P2P infrastructure working (features 034-036)
- Two registered users who can create P2P sessions
- WebRTC connection establishing successfully between peers
- Development server running (`make server`)

## What Gets Built

### New Files

| File | Type | Purpose |
|------|------|---------|
| `assets/js/lib/file_transfer.js` | JS Lib | Transfer protocol, chunking, hashing, progress — pure logic |
| `assets/js/hooks/file_transfer_hook.js` | JS Hook | DOM wiring, drag-and-drop, DataChannel ↔ LiveView bridge |
| `assets/css/file-transfer.css` | CSS | Progress bar, drop zone, file offer UI |
| `assets/test/lib/file_transfer.test.js` | Test | Unit tests for file_transfer.js |
| `assets/test/hooks/file_transfer_hook.test.js` | Test | Hook wiring tests |

### Modified Files

| File | Change |
|------|--------|
| `assets/js/hooks/webrtc_hook.js` | Create DataChannel on connection, expose to FileTransferHook |
| `assets/js/lib/webrtc.js` | Add `createDataChannel()` export |
| `assets/js/app.js` | Register FileTransferHook |
| `assets/css/app.css` | Import file-transfer.css |
| `lib/retro_hex_chat_web/components/p2p_lobby.ex` | Add file transfer UI (button, drop zone, progress, offer display) |
| `lib/retro_hex_chat_web/live/p2p_session_live.ex` | Handle ft_* events, pass config assigns |
| `config/runtime.exs` | Add FILE_TRANSFER_* env var reading |

### No Changes Needed

- No new database migrations
- No new Elixir domain modules (all logic is client-side JS)
- No new GenServer processes
- No PubSub topic changes

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  Browser A (Sender)                                 │
│                                                     │
│  ┌──────────────────┐   ┌────────────────────────┐  │
│  │ file_transfer_    │   │ file_transfer.js       │  │
│  │ hook.js           │──▶│ (pure logic)           │  │
│  │ (DOM wiring)      │   │ • validateFile()       │  │
│  │ • drag-and-drop   │   │ • computeHash()        │  │
│  │ • file input      │   │ • encodeChunk()        │  │
│  │ • progress UI     │   │ • getNextChunk()       │  │
│  └────────┬─────────┘   │ • calculateProgress()  │  │
│           │              └────────────────────────┘  │
│           │ pushEvent                                │
│           ▼                                          │
│  ┌──────────────────┐                                │
│  │ P2PSessionLive   │  (LiveView — thin, delegates)  │
│  │ • ft_offer_sent  │                                │
│  │ • ft_progress    │                                │
│  └──────────────────┘                                │
│           │                                          │
│  ┌────────┴─────────┐                                │
│  │ RTCDataChannel    │◀══════════════════════════════╪══╗
│  │ "filetransfer"    │   (P2P — no server)           │  ║
│  └──────────────────┘                                │  ║
└─────────────────────────────────────────────────────┘  ║
                                                         ║
┌─────────────────────────────────────────────────────┐  ║
│  Browser B (Receiver)                               │  ║
│                                                     │  ║
│  ┌──────────────────┐   ┌────────────────────────┐  │  ║
│  │ file_transfer_    │   │ file_transfer.js       │  │  ║
│  │ hook.js           │──▶│ (pure logic)           │  │  ║
│  │ (DOM wiring)      │   │ • decodeMessage()      │  │  ║
│  │ • offer display   │   │ • receiveChunk()       │  │  ║
│  │ • accept/reject   │   │ • assembleFile()       │  │  ║
│  │ • progress UI     │   │ • computeHash()        │  │  ║
│  │ • download trigger│   │ • calculateProgress()  │  │  ║
│  └────────┬─────────┘   └────────────────────────┘  │  ║
│           │                                          │  ║
│  ┌────────┴─────────┐                                │  ║
│  │ RTCDataChannel    │═══════════════════════════════╪══╝
│  │ "filetransfer"    │   (P2P — no server)           │
│  └──────────────────┘                                │
└─────────────────────────────────────────────────────┘
```

## Transfer Flow

1. **Sender selects file** → `validateFile()` → pass/fail
2. **Sender requests action** → `request_action("file_transfer")` via LiveView
3. **Receiver consents** → `respond_action(accepted)` via LiveView
4. **WebRTC connects** → DataChannel `"filetransfer"` opens
5. **Sender sends file-offer** → fileName, size, hash via DataChannel
6. **Receiver sees offer UI** → Accept/Reject buttons
7. **Receiver accepts** → `file-accept` via DataChannel
8. **Chunked transfer** → 64 KB chunks with backpressure, progress UI on both sides
9. **Sender signals done** → `transfer-done` via DataChannel
10. **Receiver hashes & verifies** → `hash-result` via DataChannel
11. **Download triggers** → `URL.createObjectURL()` + hidden anchor click

## Development Approach

1. **Start with `file_transfer.js` lib** — all pure logic, fully testable with Vitest
2. **Add `file_transfer_hook.js`** — wire DOM events to lib functions
3. **Modify `webrtc_hook.js`** — create DataChannel, coordinate with FileTransferHook
4. **Add LiveView component UI** — file button, drop zone, offer display, progress bar
5. **Add LiveView event handlers** — thin handlers that update assigns for UI rendering
6. **Add CSS** — file-transfer.css with 98.css progress bar, drop zone styling
7. **Add configuration** — env vars in runtime.exs

## Validation

Run the full CI pipeline per CLAUDE.md before declaring complete:
1. `mix compile --warnings-as-errors`
2. Then in parallel: format, credo, lint.js, lint.css, JS tests, mix test, dialyzer
