# Contract: media.js API

**Module**: `assets/js/lib/media.js`
**Pattern**: Pure logic module — no DOM, no LiveView, no side effects (except WebRTC API calls)

## Media Acquisition

### `acquireMedia(constraints)`
Requests user media via `getUserMedia`.

- **Input**: `{ audio: boolean|MediaTrackConstraints, video: boolean|MediaTrackConstraints }`
- **Output**: `Promise<MediaStream>`
- **Errors**: Returns rejected promise with categorized error:
  - `{ code: "permission_denied", message: "Permissao de microfone negada..." }`
  - `{ code: "not_readable", message: "Camera em uso por outro aplicativo..." }`
  - `{ code: "not_found", message: "Nenhuma camera encontrada." }`
  - `{ code: "unknown", message: "Erro ao acessar midia: {original}" }`

### `getAudioConstraints()`
Returns standard audio constraints.

- **Output**: `{ echoCancellation: true, noiseSuppression: true }`

### `getVideoConstraints()`
Returns standard video constraints.

- **Output**: `{ width: { ideal: 640 }, height: { ideal: 480 }, facingMode: "user" }`

## Track Management

### `addMediaTracks(pc, stream)`
Adds all tracks from a MediaStream to the PeerConnection.

- **Input**: `RTCPeerConnection`, `MediaStream`
- **Output**: `RTCRtpSender[]` — array of senders for later manipulation

### `removeMediaTracks(pc, senders)`
Removes tracks from the PeerConnection.

- **Input**: `RTCPeerConnection`, `RTCRtpSender[]`
- **Output**: `void`

### `toggleTrack(stream, kind, enabled)`
Enables/disables a track in a stream.

- **Input**: `MediaStream`, `"audio"|"video"`, `boolean`
- **Output**: `boolean` — new enabled state

### `replaceTrack(sender, newTrack)`
Replaces a track on an RTP sender (for device switching).

- **Input**: `RTCRtpSender`, `MediaStreamTrack`
- **Output**: `Promise<void>`

### `stopAllTracks(stream)`
Stops all tracks in a MediaStream and releases resources.

- **Input**: `MediaStream`
- **Output**: `void`

## Device Management

### `enumerateDevices()`
Lists available media devices.

- **Output**: `Promise<{ audioinput: DeviceInfo[], audiooutput: DeviceInfo[], videoinput: DeviceInfo[] }>`

### `switchAudioInput(stream, senders, deviceId)`
Switches to a different microphone without interrupting the call.

- **Input**: `MediaStream`, `RTCRtpSender[]`, `string` (deviceId)
- **Output**: `Promise<MediaStream>` — new stream with replaced audio track

### `switchVideoInput(stream, senders, deviceId)`
Switches to a different camera without interrupting the call.

- **Input**: `MediaStream`, `RTCRtpSender[]`, `string` (deviceId)
- **Output**: `Promise<MediaStream>` — new stream with replaced video track

### `setSinkId(audioElement, deviceId)`
Sets audio output device. Returns false if not supported.

- **Input**: `HTMLAudioElement`, `string` (deviceId)
- **Output**: `Promise<boolean>` — true if successful, false if not supported

### `supportsSetSinkId()`
Feature detection for audio output selection.

- **Output**: `boolean`

## Quality Monitoring

### `getQualitySnapshot(pc)`
Polls connection statistics and returns a quality snapshot.

- **Input**: `RTCPeerConnection`
- **Output**: `Promise<QualitySnapshot>`

### `mapQualityLevel(snapshot)`
Maps a quality snapshot to a quality level string.

- **Input**: `QualitySnapshot`
- **Output**: `"excellent" | "good" | "fair" | "poor"`

### `applyBitratePreset(pc, preset)`
Applies a bitrate limit to all senders.

- **Input**: `RTCPeerConnection`, `"high" | "medium" | "low"`
- **Output**: `Promise<void>`

### `BITRATE_PRESETS`
Constant object with preset values.

```javascript
{
  high:   { video: 1500000, audio: 128000 },
  medium: { video: 500000,  audio: 64000  },
  low:    { video: 150000,  audio: 32000  }
}
```

## Codec Preferences

### `setCodecPreferences(pc)`
Sets preferred codec order on transceivers (H.264 > VP8 for video, Opus for audio).

- **Input**: `RTCPeerConnection`
- **Output**: `void`
- **Note**: No-op if `setCodecPreferences` is not supported

## Call Timer

### `formatDuration(startTime)`
Formats elapsed time as HH:MM:SS.

- **Input**: `number` (Date.now() start time)
- **Output**: `string` — e.g., "00:05:23"

## Picture-in-Picture

### `supportsPiP()`
Feature detection for Picture-in-Picture API.

- **Output**: `boolean`

### `togglePiP(videoElement)`
Enters or exits Picture-in-Picture mode.

- **Input**: `HTMLVideoElement`
- **Output**: `Promise<void>`
