# Contract: MediaHook Events

**Module**: `assets/js/hooks/media_hook.js`
**Pattern**: LiveView Hook — wires DOM to media.js, manages video elements

## Inter-Hook Events (CustomEvent)

### From WebRTCHook → MediaHook

| Event | Detail | Description |
|-------|--------|-------------|
| `media_pc_ready` | `{ pc: RTCPeerConnection }` | PC connected, media can attach tracks |
| `media_pc_closed` | `{}` | PC closed, clean up media |

### From MediaHook → WebRTCHook

| Event | Detail | Description |
|-------|--------|-------------|
| `media_renegotiate` | `{}` | Track added/removed, trigger renegotiation |

## LiveView → Hook (handleEvent)

| Event | Payload | Description |
|-------|---------|-------------|
| `media_start_audio` | `{}` | Start audio call after consent |
| `media_start_video` | `{}` | Start video call after consent |
| `media_end_call` | `{}` | End the current call |
| `media_peer_muted` | `{ muted: boolean }` | Remote peer toggled mute |
| `media_peer_camera` | `{ off: boolean }` | Remote peer toggled camera |
| `media_upgrade_accepted` | `{}` | Video upgrade accepted by peer |
| `media_upgrade_rejected` | `{}` | Video upgrade rejected by peer |

## Hook → LiveView (pushEvent)

| Event | Payload | Description |
|-------|---------|-------------|
| `media_call_started` | `{ type: "audio"\|"video" }` | Call successfully started |
| `media_call_ended` | `{ reason: string }` | Call ended |
| `media_error` | `{ code: string, message: string }` | Permission or device error |
| `media_mute_changed` | `{ muted: boolean }` | Local mute state changed |
| `media_camera_changed` | `{ off: boolean }` | Local camera state changed |
| `media_quality_update` | `{ level: string, label: string }` | Quality indicator update |
| `media_request_upgrade` | `{}` | User wants audio→video upgrade |
| `media_duration_tick` | `{ formatted: string }` | Timer tick (every second) |
| `media_device_fallback` | `{ message: string }` | Device disconnected, fell back |

## DOM Elements (managed by MediaHook)

| Element | ID/Selector | Description |
|---------|-------------|-------------|
| Remote video | `#remote-video` | Large video element for remote peer |
| Local video | `#local-video` | Small PiP overlay, `muted` attribute |
| Remote audio | `#remote-audio` | Audio element (audio-only calls) |

## MediaHook Lifecycle

1. **mounted()**: Register handleEvent listeners, listen for `media_pc_ready` CustomEvent
2. **media_pc_ready received**: Store PC reference, set up `ontrack` handler
3. **media_start_audio/video**: Call `acquireMedia()`, `addMediaTracks()`, set codec preferences
4. **ontrack fired**: Attach remote stream to video/audio element
5. **Call active**: Start quality polling (3s interval), start duration timer (1s interval)
6. **media_end_call / destroyed()**: Stop all tracks, clear intervals, clean up DOM
