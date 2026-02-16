# Data Model: Audio/Video Calls

**Feature**: 038-audio-video-calls
**Date**: 2026-02-16

## Overview

Audio/video calls are entirely ephemeral — all state lives in JavaScript (client-side) and LiveView socket assigns (server-side). No database migrations needed. No persistent entities.

## Client-Side Entities (JavaScript)

### CallSession

Represents an active audio or video call between two peers.

| Field | Type | Description |
|-------|------|-------------|
| type | `"audio" \| "video"` | Current call mode |
| startTime | `number` | `Date.now()` when call connected |
| localMuted | `boolean` | Local microphone muted state |
| remoteMuted | `boolean` | Remote peer muted state |
| localCameraOff | `boolean` | Local camera disabled (video calls) |
| remoteCameraOff | `boolean` | Remote camera disabled (video calls) |
| qualityLevel | `"excellent" \| "good" \| "fair" \| "poor"` | Current quality assessment |
| qualityPreset | `"high" \| "medium" \| "low"` | User-selected bitrate preset |

**State transitions**:
- `null → audio`: Audio call accepted by both peers
- `null → video`: Video call accepted by both peers
- `audio → video`: Audio-to-video upgrade accepted
- `audio/video → null`: Call ended (user action or peer disconnect)

### QualitySnapshot

Periodic sample of connection health from `getStats()`.

| Field | Type | Description |
|-------|------|-------------|
| roundTripTime | `number` | RTT in seconds |
| packetLoss | `number` | Packet loss percentage (0-100) |
| jitter | `number` | Jitter in seconds |
| availableBandwidth | `number \| null` | Available outbound bandwidth in bps |
| timestamp | `number` | When snapshot was taken |

**Quality level mapping** (pure function in media.js):
- **Excellent**: packetLoss < 1% AND rtt < 100ms
- **Good**: packetLoss < 3% AND rtt < 200ms
- **Fair**: packetLoss < 8% AND rtt < 400ms
- **Poor**: Everything else

### DeviceInfo

Available media device from `enumerateDevices()`.

| Field | Type | Description |
|-------|------|-------------|
| deviceId | `string` | Unique device identifier |
| kind | `"audioinput" \| "audiooutput" \| "videoinput"` | Device type |
| label | `string` | Human-readable device name |

### BitratePreset

Manual quality adjustment presets.

| Preset | Max Video Bitrate | Max Audio Bitrate |
|--------|------------------|------------------|
| high | 1,500,000 bps | 128,000 bps |
| medium | 500,000 bps | 64,000 bps |
| low | 150,000 bps | 32,000 bps |

## Server-Side State (LiveView Assigns)

### call assign (in P2PSessionLive)

| Field | Type | Description |
|-------|------|-------------|
| status | `string` | `"audio_active"`, `"video_active"`, `nil` |
| type | `string` | `"audio"`, `"video"`, `nil` |
| peer_muted | `boolean` | Remote peer's mute state |
| peer_camera_off | `boolean` | Remote peer's camera state |

**Note**: The LiveView holds minimal call state — just enough for UI rendering. All media logic stays in JavaScript.

## Relationships

```text
P2PSessionLive (LiveView)
  └── call assign (map or nil)

WebRTCHook (owns RTCPeerConnection)
  ├── dispatches CustomEvent "media_pc_ready" → MediaHook
  └── handles onnegotiationneeded for renegotiation

MediaHook (wiring)
  ├── uses media.js (pure logic)
  │   ├── CallSession state
  │   ├── QualitySnapshot polling
  │   ├── DeviceInfo enumeration
  │   └── BitratePreset application
  └── manages DOM (video elements, controls)
```

## No Database Changes

This feature requires zero migrations. All call state is ephemeral:
- Client-side: JavaScript variables in MediaHook/media.js
- Server-side: LiveView socket assigns (cleared on disconnect)
- No call history, no call logs, no persistent records
