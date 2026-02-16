# Category AI: Audio/Video Calls

**Priority**: Green (Medium — builds on established WebRTC infrastructure)
**Dependencies**: AE (P2P Foundation), AF (P2P Lobby & Session UI), AG (WebRTC Signaling)
**Existing**: None (new feature)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AI1 | media.js lib module | New | Pure logic module: `getUserMedia(constraints)`, `addTrackToPeer(track, peer)`, `replaceTrack(sender, newTrack)`, `stopAllTracks()`, `enumerateDevices()`, `getStats()`. Event callbacks for track events, device changes, quality metrics |
| AI2 | media_hook.js | New | LiveView hook wiring: connects media.js to DOM (video elements, control buttons, quality indicator) and LiveView events. Follows hook=wiring/lib=logic pattern |
| AI3 | Audio call initiation | New | After bilateral consent for audio call: request microphone permission, add audio track to PeerConnection, trigger renegotiation. Peer receives track via `ontrack` event. Audio playback via `<audio>` element |
| AI4 | Video call initiation | New | After bilateral consent for video call: request camera+microphone permission with constraints (640x480, 30fps ideal). Add audio+video tracks to PeerConnection. Remote video displayed in large area, local video in PiP corner |
| AI5 | Permission error handling | New | Handle `NotAllowedError` (permission denied — show friendly message with retry), `NotFoundError` (no device — show 'Nenhum microfone/câmera encontrado'), `NotReadableError` (device in use — show 'Dispositivo em uso por outro aplicativo'). Errors displayed in lobby context (AF11) |
| AI6 | Mute/unmute and camera toggle | New | Toggle buttons: mute audio (`audioTrack.enabled = false`), disable camera (`videoTrack.enabled = false`). Visual indicators: muted mic icon, camera off icon. Peer notified of mute state via DataChannel message |
| AI7 | Device selection mid-call | New | Dropdown to switch audio input, video input, audio output during active call. Uses `sender.replaceTrack(newTrack)` — no renegotiation needed. Old track stopped after replacement |
| AI8 | Audio to video upgrade | New | During audio-only call, either peer can request video upgrade (bilateral consent). Adds video track to existing PeerConnection. Triggers automatic renegotiation via `onnegotiationneeded`. Layout transitions from audio-only to video layout |
| AI9 | Video layout | New | Remote video: large, fills main area. Local video: small PiP overlay in corner (draggable). Audio-only layout: large area shows peer name + audio waveform indicator + duration timer. 98.css styled window chrome |
| AI10 | Call duration timer | New | Timer starts when call becomes active (first media track flowing). Displays HH:MM:SS format. Visible in both audio and video layouts. Stops on call end |
| AI11 | Quality indicator and adjustment | New | 4-level quality based on `RTCPeerConnection.getStats()`: Excellent (RTT<50ms, loss<1%), Good (RTT<150ms, loss<3%), Regular (RTT<300ms, loss<5%), Poor (RTT>300ms or loss>5%). Updated every 5 seconds. Visual: 4 bars like signal strength. Manual quality override via `sender.setParameters()`: high (1.5Mbps), medium (500Kbps), low (150Kbps) — exposed as dropdown or auto-triggered on sustained poor quality |
| AI12 | Browser-native Picture-in-Picture | New | Allow remote video to enter browser PiP mode via `video.requestPictureInPicture()`. User can watch video while navigating to other tabs/pages. Fallback: button does nothing if PiP not supported |
| AI13 | Device change detection | New | Listen to `navigator.mediaDevices.ondevicechange`. When a device is disconnected during call (e.g., USB headset unplugged), automatically fall back to default device. Notify user: 'Dispositivo desconectado, usando dispositivo padrão' |
| AI14 | Codec preferences | New | Prefer H.264 (hardware acceleration) > VP8 (fallback) for video. Opus for audio (only codec needed). Set via `RTCRtpTransceiver.setCodecPreferences()` if supported, otherwise rely on browser defaults |
| AI15 | JS tests | New | Vitest tests for media.js: getUserMedia mock, track management, device enumeration, quality stats parsing, device change handling. Tests for media_hook.js: DOM wiring for video elements, control buttons, PiP integration |

## Dependencies Detail

- AI1 (media.js) is self-contained — pure JS logic module
- AI2 (hook) depends on AI1 (lib) and AG3 (webrtc_hook.js for PeerConnection)
- AI3 (audio call) depends on AI1, AI2, AG2 (PeerConnection for tracks)
- AI4 (video call) depends on AI1, AI2, AG2, AI9 (video layout)
- AI5 (permission errors) depends on AI1 and AF11 (permission request UI in lobby)
- AI6 (mute/toggle) depends on AI2 (hook wires buttons to lib)
- AI7 (device selection) depends on AI1 (`enumerateDevices`, `replaceTrack`)
- AI8 (audio→video upgrade) depends on AI3 (active audio call), AI4 (video track addition), AF9 (bilateral consent)
- AI9 (video layout) depends on AF13 (CSS) and AI2 (hook manages video elements)
- AI10 (timer) depends on AI2 (hook manages timer display)
- AI11 (quality) depends on AI1 (`getStats`) and AG2 (PeerConnection)
- AI12 (PiP) depends on AI4 (video element exists)
- AI13 (device change) depends on AI1 (device monitoring) and AI7 (fallback to default)
- AI14 (codecs) depends on AG2 (PeerConnection configuration)
- AI15 (tests) depends on AI1 and AI2

## Technical Notes

- getUserMedia constraints for video: `{audio: true, video: {width: {ideal: 640}, height: {ideal: 480}, frameRate: {ideal: 30, max: 30}}}`
- Audio-only constraints: `{audio: true, video: false}`
- Track management: use `RTCPeerConnection.addTrack(track, stream)` and `sender.replaceTrack(newTrack)`
- Audio→video upgrade triggers `onnegotiationneeded` event — webrtc.js handles automatic renegotiation
- Mute state communicated to peer via DataChannel: `{type: "mute-state", audio: false, video: true}`
- Quality metrics from `RTCPeerConnection.getStats()`: filter for `RTCRemoteInboundRtpStreamStats` for RTT and packet loss
- Quality adjustment: `sender.getParameters()` / `sender.setParameters()` with `maxBitrate`: high=1_500_000, medium=500_000, low=150_000. Can be triggered manually (dropdown) or automatically on sustained poor quality
- PiP API: `video.requestPictureInPicture()` — check `document.pictureInPictureEnabled` before showing button
- Device enumeration: `navigator.mediaDevices.enumerateDevices()` returns array of InputDeviceInfo
- Audio output selection: `audioElement.setSinkId(deviceId)` — not universally supported, feature-detect
- Codec preferences: `transceiver.setCodecPreferences(orderedCodecs)` — order: H.264, VP8, VP9
- Video element attributes: `autoplay`, `playsinline`, `muted` (for local video to prevent echo)
- Local video element must be muted to prevent audio feedback loop
- Duration timer: use `setInterval` with 1-second tick, format as HH:MM:SS

---

## Spec Command

```
/speckit.specify "Audio/Video Calls for RetroHexChat.

PROBLEM: Users cannot make voice or video calls through RetroHexChat. While the WebRTC signaling infrastructure provides the P2P connection, there is no media handling layer — no way to capture microphone/camera, manage audio/video tracks, display remote video, handle device changes, or monitor call quality. Audio/video calls are a signature DCC-inspired feature that transforms the chat from text-only to a full communication platform.

EXISTING CONTEXT: The P2P bounded context provides session infrastructure (SessionServer GenServer, Service, Policy, tokens). The lobby provides bilateral consent, browser capability detection (getUserMedia check), and permission error handling context. WebRTC signaling establishes RTCPeerConnection. The project uses Vitest+jsdom for JS testing and follows the hook=wiring/lib=logic pattern. WebRTC media APIs (getUserMedia, addTrack, replaceTrack) are browser-native requiring zero dependencies.

USER JOURNEY — AUDIO CALL: Rodrigo clicks 'Chamada de Áudio' in the P2P lobby. Mario sees the request and clicks Accept. Both browsers request microphone permission. The audio tracks are added to the existing PeerConnection. Both users hear each other. The UI shows an audio call layout: peer name, audio waveform indicator, duration timer (00:00:15), and quality indicator (4 green bars). Rodrigo clicks the mute button — his mic icon shows muted, and Mario sees 'rodrigo silenciou o microfone'. After 10 minutes, Rodrigo ends the call.

USER JOURNEY — VIDEO CALL: Mario clicks 'Chamada de Vídeo'. After bilateral consent and permission grants, both cameras and microphones activate. The layout shows Mario's video large (remote) and Rodrigo's video small in the bottom-right corner (local PiP). Quality indicator shows 3 bars (Good). Rodrigo clicks the PiP button — Mario's video pops out into a browser Picture-in-Picture window. Rodrigo can now browse other tabs while keeping the video visible.

USER JOURNEY — UPGRADE AND DEVICE CHANGE: During an audio call, Mario wants to switch to video. He clicks 'Adicionar Vídeo'. Rodrigo sees the request and accepts. Mario's camera activates, the video track is added via renegotiation, and the layout transitions to video mode. Later, Rodrigo unplugs his USB headset. The system detects the device change, falls back to the default microphone, and shows 'Dispositivo desconectado, usando dispositivo padrão'.

ACTORS: Both peers have equal capabilities: initiate calls, mute, toggle camera, select devices, upgrade, end call. The browser handles codec negotiation, quality adaptation, and echo cancellation. The PeerConnection manages RTP/RTCP for media transport.

EDGE CASES: Camera in use by another application (NotReadableError — friendly message). No camera available for video call (NotFoundError — offer audio-only fallback). Both peers mute simultaneously (both see muted indicators). Device disconnected during call (auto-fallback to default). PiP not supported in browser (hide PiP button). Very poor network quality (quality indicator shows 1 bar, WebRTC auto-reduces resolution/framerate). Audio→video upgrade rejected by peer (remain in audio-only mode). Browser tab backgrounded (video paused by browser — audio continues). setSinkId not supported (skip audio output selection, use system default).

NEGATIVE REQUIREMENTS: Media streams must NEVER pass through the server — WebRTC P2P only. media.js must NOT contain DOM manipulation or LiveView code. The hook must NOT contain media logic. No recording capability (privacy). No screen sharing (out of scope). No multi-party calls (1-to-1 only). No virtual backgrounds or filters. Quality adjustment is available via manual override (maxBitrate: 1.5Mbps/500Kbps/150Kbps) and can auto-trigger on sustained poor quality, but WebRTC's built-in bandwidth estimation remains the primary adaptation mechanism. Local video element MUST be muted to prevent audio feedback.

SCOPE: In scope — media.js lib module, media_hook.js, audio call initiation, video call initiation, permission error handling, mute/unmute and camera toggle, device selection mid-call, audio-to-video upgrade with renegotiation, video layout (remote large + local PiP), call duration timer, quality indicator (4-level) with manual quality adjustment via maxBitrate (high 1.5Mbps / medium 500Kbps / low 150Kbps), browser-native PiP, device change detection and fallback, codec preferences (H.264 > VP8, Opus), JS tests. Out of scope — screen sharing, recording, multi-party, virtual backgrounds, TURN setup, help documentation."
```
