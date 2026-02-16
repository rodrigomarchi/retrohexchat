# Research: Audio/Video Calls

**Feature**: 038-audio-video-calls
**Date**: 2026-02-16

## R1: WebRTC Media Track Integration

**Decision**: Extend `webrtc.js` with media track functions and create new `media.js` for media-specific logic.

**Rationale**: The existing `webrtc.js` (13 exports) manages PeerConnection lifecycle but has zero media track functions — no `addTrack`, `ontrack`, `replaceTrack`, or renegotiation support. Adding track management to `webrtc.js` keeps the PC as the single source of truth. Media-specific logic (getUserMedia, device enumeration, quality metrics, codec preferences) goes in a new `media.js` module following the existing lib pattern.

**Alternatives considered**:
- Put everything in `media.js` → Rejected: would duplicate PC access and break the single-PC-owner pattern established by `webrtc.js`.
- Merge all into `webrtc.js` → Rejected: would bloat the module beyond its signaling/connection scope.

## R2: Hook Architecture

**Decision**: Create `MediaHook` following the `FileTransferHook` pattern — receives CustomEvents from `WebRTCHook` for PC access, wires DOM events to `media.js` pure functions.

**Rationale**: The codebase already has the pattern: `WebRTCHook` owns the PC and dispatches `CustomEvent` to sibling hooks (`ft_channel_ready`, `ft_channel_closed`). `MediaHook` will listen for a `media_pc_ready` event containing the PC reference, then manage media tracks through `media.js`. This avoids the hook accessing the PC directly and maintains clean separation.

**Alternatives considered**:
- Single monolithic hook → Rejected: violates hook=wiring/lib=logic constitution principle and makes testing impossible.
- Media inside WebRTCHook → Rejected: would bloat the hook and mix signaling with media concerns.

## R3: LiveView Event Flow

**Decision**: Follow the `FileTransferHook` bidirectional pattern — `pushEvent` from hook → LiveView handler → assign update → re-render; and `push_event` from LiveView → hook `handleEvent`.

**Rationale**: The existing consent flow already handles `audio_call` and `video_call` action types through `request_action` → `SessionServer` → broadcast → consent banner. After acceptance, the LiveView pushes `p2p_start_offer`/`p2p_start_answer` which triggers WebRTC connection. Media events (call state, mute, camera toggle, quality) follow the same `pushEvent`/`handleEvent` pattern used by file transfer.

**Alternatives considered**:
- Direct hook-to-hook communication only → Rejected: LiveView needs to know call state for UI rendering (call layout vs lobby).

## R4: Signaling Renegotiation for Audio→Video Upgrade

**Decision**: Use the existing WebRTC signaling channel. When a video track is added mid-call, the `negotiationneeded` event fires on the PC. The hook intercepts this, creates a new offer, and sends it through the existing `p2p_signal` mechanism.

**Rationale**: WebRTC natively handles renegotiation via the `negotiationneeded` event. The existing signaling infrastructure (offer/answer/ice-candidate via `p2p_signal` pushEvent) supports this without modification. The only addition is registering `pc.onnegotiationneeded` in the WebRTCHook.

**Alternatives considered**:
- Custom signaling protocol for upgrades → Rejected: unnecessary complexity when WebRTC provides this natively.

## R5: Quality Monitoring

**Decision**: Use `RTCPeerConnection.getStats()` polled every 3 seconds. Parse `RTCInboundRtpStreamStats` and `RTCIceCandidatePairStats` for packet loss, RTT, jitter, and bandwidth. Map to 4 quality levels in `media.js`.

**Rationale**: `getStats()` is widely supported and provides all needed metrics. Polling every 3 seconds matches the SC-004 success criterion. The quality level mapping (Excellent/Good/Fair/Poor) is a pure function in `media.js` with no DOM dependencies.

**Alternatives considered**:
- `RTCPeerConnection` events only → Rejected: no event for continuous quality reporting, only state changes.

## R6: Device Management

**Decision**: Use `navigator.mediaDevices.enumerateDevices()` for device listing, `navigator.mediaDevices.ondevicechange` for disconnect detection, and `replaceTrack()` for mid-call device switching.

**Rationale**: `replaceTrack()` swaps the track without renegotiation, making device switching seamless. `enumerateDevices()` requires an active permission grant to show labels (documented in spec assumptions). Audio output selection uses `setSinkId()` with feature detection.

**Alternatives considered**:
- Stop and restart getUserMedia for device switch → Rejected: causes audio/video interruption, violates SC-006.

## R7: CSS Architecture

**Decision**: Create `media-call.css` in Layer 4 (Components) of `app.css`. Use `.media-call__*` BEM naming. Video layout uses CSS Grid for remote/local positioning.

**Rationale**: Follows existing CSS architecture (one file per component, 50-200 lines target, alphabetical in layer). The call UI is a distinct component with its own class prefix. Design tokens from `tokens.css` provide colors, spacing, and z-index values.

**Alternatives considered**:
- Extend p2p-lobby.css → Rejected: call UI is large enough (100+ lines) to warrant its own file.

## R8: Testing Strategy

**Decision**: Vitest + jsdom for `media.js` unit tests and `media_hook.js` behavioral tests. Mock `navigator.mediaDevices` and `RTCPeerConnection.getStats()`. Follow existing patterns from `file_transfer.test.js` and `webrtc_hook.test.js`.

**Rationale**: The existing test infrastructure provides `mountHook`, `simulateEvent`, `cleanupDOM`, and `__pushEvents` tracking helpers. `media.js` pure functions can be tested without DOM. Hook tests use the `mountHook` pattern with mock elements.

**Alternatives considered**:
- E2E browser tests for media → Rejected: getUserMedia in jsdom is not real, and E2E media tests are fragile. Pure function tests + hook behavioral tests provide sufficient coverage.

## R9: Codec Preferences

**Decision**: Set codec preferences via `RTCRtpTransceiver.setCodecPreferences()` — prefer H.264 for video, Opus for audio. Fall back gracefully if codecs unavailable.

**Rationale**: `setCodecPreferences()` is the standard API for codec ordering. Opus is the default WebRTC audio codec. H.264 has better hardware acceleration support than VP8 on most devices. The spec explicitly states these are hints, not hard requirements.

**Alternatives considered**:
- SDP munging → Rejected: fragile, non-standard, and unnecessary with `setCodecPreferences()`.
