# P2P Game Audio/Video Plan

## Objective

Allow P2P game sessions to run voice and video calls during gameplay without opening a second WebRTC session. The game session remains one platform-level RTC surface:

- one `RTCPeerConnection`
- one `gamedata` `RTCDataChannel`
- optional audio/video `MediaStreamTrack`s
- LiveView state for media controls and peer indicators

## Product Principles

- Game canvas remains primary. Media is a dock or compact panel, never the default main surface.
- Permissions are requested only after the user starts voice or video.
- Audio can be started independently; video includes audio.
- Ending the call must not end the game.
- Ending the game must clean up media tracks.
- The implementation must reuse platform media primitives instead of forking one-off call code.
- Peer-initiated media must still renegotiate through the creator/initiator so the game avoids offer glare.

## WebRTC Design

### Existing Game RTC

`GameWebRTCHook` owns the game `RTCPeerConnection` and creates the `gamedata` DataChannel.

### Target RTC

The same peer connection carries media:

```text
RTCPeerConnection
├── RTCDataChannel: gamedata
├── MediaStreamTrack: audio
└── MediaStreamTrack: video optional
```

### Signaling

Existing `game_signal` remains the signaling transport for offer/answer/ICE. Adding media tracks triggers renegotiation through the existing `onnegotiationneeded` path when the creator starts media. If the peer starts or upgrades media, LiveView notifies the creator with `game_renegotiate`; the creator sends the new offer and the peer answers with its local tracks.

### Negotiation Policy

The current game hook centralizes new offers on the initiator/creator. This avoids glare for game media changes while still allowing either participant to start voice/video. A later perfect-negotiation migration remains possible if multi-party or more concurrent media edits are introduced.

## UX Design

### Playing, No Call

- Add compact media controls to the game window footer:
  - Start Voice
  - Start Video

### Audio Active

- Show `Voice on` status, duration, mute, and hang-up.
- No video panel is shown.

### Video Active

- Show a small dock over the game canvas by default:
  - remote video
  - local preview
  - nameplates
- Controls stay compact:
  - mute
  - camera on/off
  - dock/panel layout
  - hang-up

### Peer Indicators

- Peer muted
- Peer camera off
- Media permission/device error

## Implementation Tasks

- [x] Add LiveView tests for game media state and events.
- [x] Add a reusable RTC media hook factory.
- [x] Rebuild the existing P2P `MediaHook` on the factory.
- [x] Add `GameMediaHook` on the factory with game-specific event names and element IDs.
- [x] Expose the game `RTCPeerConnection` for media from `GameWebRTCHook`.
- [x] Add game media assigns and PubSub handlers to `GameSessionLive`.
- [x] Add game media UI to `GameCanvas`.
- [x] Register `GameMediaHook` in lazy hook loading.
- [x] Add showcase coverage for game canvas media states.
- [x] Add/extend E2E coverage for starting game voice/video.

## Test Plan

- LiveView:
  - game media hook readiness does not start media by itself.
  - starting voice queues/pushes `game_media_start_audio`.
  - starting video queues/pushes `game_media_start_video`.
  - mute/camera events update local state and broadcast peer events.
  - media call ended clears game media state without closing the game.
  - peer media PubSub updates remote indicators.

- Component/render:
  - game canvas renders start voice/video controls.
  - active audio renders audio element and active controls.
  - active video renders remote/local video elements.

- E2E:
  - game can start as before.
  - voice controls are visible during gameplay.
  - video controls render video elements during gameplay.
  - `getUserMedia` returns synthetic live audio/video tracks, not an empty stream.
  - local video receives live audio/video tracks after the player starts video.
  - remote audio/video elements receive live tracks through WebRTC.
  - video layout can switch side-by-side/maximized.
  - ending the media call keeps both game canvases open.
  - peer-started video renegotiates through the host and delivers media tracks.

## Progress

- 2026-06-04: Initial architecture mapped. Existing game RTC is separate from P2P call RTC; implementation will reuse the game peer connection for media.
- 2026-06-04: Added LiveView TDD coverage for game media dock, readiness, start, end, and peer indicators.
- 2026-06-04: Implemented reusable RTC media hook factory and migrated the existing P2P `MediaHook` to it.
- 2026-06-04: Added `GameMediaHook`, game media LiveView state/PubSub, game media UI, layout controls, and creator-led renegotiation.
- 2026-06-04: Updated showcase `Game Canvas` with idle, voice, side-by-side video, and maximized video states.
- 2026-06-04: Added headed Playwright coverage for in-game video controls and media-call teardown.
- 2026-06-04: Strengthened E2E media coverage with synthetic live audio/video tracks and peer-started video renegotiation. This exposed and fixed the host-offer case by adding `recvonly` media transceivers before host renegotiation.

## Verification

- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/game_session_media_live_test.exs`
- `npm test -- test/hooks/games/game_webrtc_hook.test.js test/hooks/games/game_media_hook.test.js test/hooks/p2p/media_hook.test.js`
- `mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/p2p_session_live_test.exs`
- `mix test apps/retro_hex_chat_web/test/showcase_smoke_test.exs`
- `npm run lint:hooks`
- `npm run lint`
- `npm run format:check`
- `mix format --check-formatted apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/game_session_live.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/games/game_canvas.ex apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/showcase_live/games/game_canvas_page.ex apps/retro_hex_chat_web/test/retro_hex_chat_web/live/game_session_media_live_test.exs`
- `npm run test:headed -- tests/chat-p2p-game-media.spec.ts`
