# E2E Test Backlog

Desktop/browser journeys that the suite does **not** cover yet. What the suite
*does* cover lives in [`TEST_CATALOG.md`](TEST_CATALOG.md), generated from the
`@flow` headers in the specs themselves.

An entry leaves this file the moment a spec covers it: give that spec an `@flow`
line with this id, run `make e2e.catalog`, and delete the row here. `make ci`
fails if an id appears in both places, so the two cannot both claim it.

**Created:** 2026-05-29. Pruned on 2026-08-07: 117 of the 157 entries had already
shipped and were still listed as pending work.

## Status Legend

- `unverified` - the row claimed `done`, but no spec carries its id and the
  suggested file does not exist. Either a spec covers the journey under another
  name (give it an `@flow` and remove the row) or it does not (treat as todo).
  These were inherited: the file recorded intent to implement and was never
  reconciled with what shipped.
- `block` - intentionally not runnable until a safe black-box strategy exists.

## Z - P2P, File, Call, Game, Arcade

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| Z1 | P2P/call/sendfile/game to offline but registered user shows clear offline/unavailable error | `tests/chat-p2p-availability.spec.ts` | P1 | unverified |
| Z2 | P2P target ignores sender and does not receive invite card or notification | `tests/chat-p2p-ignore.spec.ts` | P1 | unverified |
| Z3 | P2P invite expires or is cancelled and both users' lobby/chat state clears | `tests/chat-p2p-expiry-cancel.spec.ts` | P2 | unverified |
| Z4 | Double-clicking P2P lobby accept/decline actions is idempotent and does not create duplicate state | `tests/chat-p2p-idempotency.spec.ts` | P1 | unverified |
| Z5 | Closing one side of a P2P lobby/session updates the other side's state and does not steal chat focus | `tests/chat-p2p-session-lifecycle.spec.ts` | P1 | unverified |
| Z6 | Media permission denied path for `/call` shows actionable error and leaves chat usable | `tests/chat-p2p-call-permissions.spec.ts` | P1 | unverified |
| Z7 | Audio/video mute toggles in call session update local UI and remote indicators if present | `tests/chat-p2p-call-controls.spec.ts` | P2 | unverified |
| Z8 | File transfer cancel before upload and cancel during upload cleanly update both peers | `tests/chat-p2p-file-cancel.spec.ts` | P1 | unverified |
| Z9 | File transfer rejects oversized or disallowed file according to product limits | `tests/chat-p2p-file-limits.spec.ts` | P1 | unverified |
| Z10 | Game invite decline and game selection cancellation return both users to chat/lobby state cleanly | `tests/chat-p2p-game-lifecycle.spec.ts` | P2 | unverified |
| Z11 | Shared game shell exchanges at least one state update between peers, beyond simply opening the lobby | `tests/chat-p2p-game-state.spec.ts` | P2 | unverified |
| Z13 | Nicklist-started P2P session exercises lobby chat, declined action retry, and reverse-direction file transfer | `tests/chat-p2p-complete-flows.spec.ts` | P1 | unverified |
| Z14 | Audio call exercises video-upgrade decline, retry, accepted media tracks, layout, and peer indicators | `tests/chat-p2p-complete-flows.spec.ts` | P1 | unverified |
| Z15 | Game lobby declines a selection, retries, and still reaches shared playable canvas state | `tests/chat-p2p-complete-flows.spec.ts` | P2 | unverified |
| Z16 | Pending P2P action blocks competing requests and requester self-accept | `tests/chat-p2p-complete-flows.spec.ts` | P1 | unverified |
| Z17 | Cancelled incoming file offer can be retried through a new clean file-transfer session | `tests/chat-p2p-complete-flows.spec.ts` | P1 | unverified |
| Z18 | Chat-message nickname context menu can start P2P send-file invite and consent decline path | `tests/chat-p2p-complete-flows.spec.ts` | P1 | unverified |
| Z19 | P2P lobby messages and filenames with HTML-like content remain inert escaped text | `tests/chat-p2p-complete-flows.spec.ts` | P1 | unverified |
| Z20 | Adding invites ignore during an open P2P lobby closes both peers and records ended-session status | `tests/chat-p2p-complete-flows.spec.ts` | P1 | unverified |
| Z21 | Direct video call with denied camera shows camera-specific guidance and leaves lobby usable | `tests/chat-p2p-call-media-edges.spec.ts` | P1 | unverified |
| Z22 | Audio-to-video upgrade camera denial rolls both peers back to a live audio call | `tests/chat-p2p-call-media-edges.spec.ts` | P1 | unverified |
| Z23 | Ending an active audio call closes local popup and ends peer session with call-ended status | `tests/chat-p2p-call-media-edges.spec.ts` | P1 | unverified |
| Z24 | Closing popup during active audio call disconnects peer coherently | `tests/chat-p2p-call-media-edges.spec.ts` | P1 | unverified |
| Z25 | Nicklist-started video call reaches full video media with local and remote tracks | `tests/chat-p2p-call-media-edges.spec.ts` | P1 | unverified |
| Z26 | Browser offline/online during an active audio call restores coherent media controls | `tests/chat-p2p-call-resilience.spec.ts` | P1 | unverified |
| Z27 | Browser offline/online during an active video call restores video tracks and controls | `tests/chat-p2p-call-resilience.spec.ts` | P1 | unverified |
| Z28 | Closing peer popup while video upgrade is pending ends the requester coherently | `tests/chat-p2p-call-resilience.spec.ts` | P1 | unverified |
| Z29 | Adding invites ignore during an active video call closes both peers and clears media state | `tests/chat-p2p-call-resilience.spec.ts` | P1 | unverified |
| Z30 | Same users can start a fresh audio call after ending the previous call | `tests/chat-p2p-call-resilience.spec.ts` | P1 | unverified |
| Z31 | Double-clicking video-upgrade accept settles once and reaches a single video call | `tests/chat-p2p-call-resilience.spec.ts` | P1 | unverified |
| Z32 | Audio call with missing microphone shows microphone-specific missing-device guidance | `tests/chat-p2p-call-device-errors.spec.ts` | P1 | unverified |
| Z33 | Video call with missing camera shows missing-camera guidance | `tests/chat-p2p-call-device-errors.spec.ts` | P1 | unverified |
| Z34 | Video call with busy camera shows not-readable camera guidance | `tests/chat-p2p-call-device-errors.spec.ts` | P1 | unverified |
| Z35 | Chat-message nickname context menu starts a full video call with media tracks | `tests/chat-p2p-call-device-errors.spec.ts` | P1 | unverified |
| Z36 | Active game voice call upgrades to video and delivers local and remote media tracks | `tests/chat-p2p-game-media-edges.spec.ts` | P1 | unverified |
| Z37 | Camera denial inside active game media leaves the canvas playable and media idle | `tests/chat-p2p-game-media-edges.spec.ts` | P1 | unverified |
| Z38 | Ending an active game while video media is running closes the peer coherently | `tests/chat-p2p-game-media-edges.spec.ts` | P1 | unverified |
| Z39 | Closing popup during active game video media disconnects the peer coherently | `tests/chat-p2p-game-media-edges.spec.ts` | P1 | unverified |

## AA - Reconnect, Multi-Context, Browser State, And Destructive Safety

| # | Scenario | Suggested spec file | Priority | Status |
|---|----------|---------------------|----------|--------|
| AA3 | Reconnect during P2P invite/lobby/session produces coherent state for both peers | `tests/chat-reconnect-p2p.spec.ts` | P2 | unverified |
| AA9 | Confirmed `/admin nuke --confirm` remains blocked until disposable isolated profile exists | `tests/chat-admin-nuke.spec.ts` | P2 | block |
