# Quickstart: Audio/Video Calls

**Feature**: 038-audio-video-calls
**Date**: 2026-02-16

## Integration Points

### 1. WebRTCHook → MediaHook Communication

The WebRTCHook already owns the PeerConnection. MediaHook receives it via CustomEvent:

```javascript
// In WebRTCHook (addition to _handleConnectionStateChange):
case "connected":
  this.el.dispatchEvent(new CustomEvent("media_pc_ready", { detail: { pc: this.pc } }));
  break;

// In MediaHook (mounted):
this.el.addEventListener("media_pc_ready", (e) => {
  this.pc = e.detail.pc;
  this._setupOnTrack();
});
```

### 2. Consent Flow Integration

The existing bilateral consent already supports `audio_call` and `video_call` action types. After acceptance, the LiveView pushes media start events:

```elixir
# In P2PSessionLive, after action accepted:
defp handle_action_accepted("audio_call", socket) do
  socket
  |> assign(:call, %{status: "audio_active", type: "audio", ...})
  |> push_event("media_start_audio", %{})
end
```

### 3. Video Layout

The call UI replaces the lobby content area during an active call:

```heex
<div :if={@call} class="media-call" id="media-call" phx-hook="MediaHook">
  <video :if={@call.type == "video"} id="remote-video" class="media-call__remote" autoplay playsinline></video>
  <video :if={@call.type == "video"} id="local-video" class="media-call__local" autoplay playsinline muted></video>
  <audio :if={@call.type == "audio"} id="remote-audio" autoplay></audio>
  <!-- Controls: mute, camera, end call, quality, devices, PiP -->
</div>
```

### 4. Quality Polling

```javascript
// In MediaHook, after call starts:
this.qualityInterval = setInterval(async () => {
  const snapshot = await getQualitySnapshot(this.pc);
  const level = mapQualityLevel(snapshot);
  this.pushEvent("media_quality_update", { level, label: QUALITY_LABELS[level] });
}, 3000);
```

### 5. Device Switching

```javascript
// In MediaHook:
async _switchMicrophone(deviceId) {
  this.localStream = await switchAudioInput(this.localStream, this.senders, deviceId);
}
```

### 6. Audio→Video Upgrade

```javascript
// Requester clicks "Adicionar Video":
this.pushEvent("media_request_upgrade", {});

// After peer accepts (LiveView pushes media_upgrade_accepted):
this.handleEvent("media_upgrade_accepted", async () => {
  const videoStream = await acquireMedia({ video: getVideoConstraints(), audio: false });
  const videoTrack = videoStream.getVideoTracks()[0];
  this.localStream.addTrack(videoTrack);
  const sender = this.pc.addTrack(videoTrack, this.localStream);
  this.senders.push(sender);
  // onnegotiationneeded fires → WebRTCHook handles renegotiation
});
```

## File Map

| File | Type | Purpose |
|------|------|---------|
| `assets/js/lib/media.js` | New | Pure media logic (no DOM) |
| `assets/js/hooks/media_hook.js` | New | DOM wiring for media |
| `assets/test/lib/media.test.js` | New | Unit tests for media.js |
| `assets/test/hooks/media_hook.test.js` | New | Hook behavioral tests |
| `assets/css/media-call.css` | New | Call UI styles |
| `lib/.../components/p2p_lobby.ex` | Modified | Add call UI components |
| `lib/.../live/p2p_session_live.ex` | Modified | Add call event handlers |
| `assets/js/app.js` | Modified | Register MediaHook |
| `assets/css/app.css` | Modified | Import media-call.css |
| `assets/js/hooks/webrtc_hook.js` | Modified | Add media_pc_ready dispatch, onnegotiationneeded |

## Testing Approach

1. **media.js unit tests**: Test pure functions (quality mapping, duration formatting, error categorization, device filtering, bitrate presets)
2. **media_hook.js behavioral tests**: Test hook lifecycle, event wiring, pushEvent calls
3. **Existing E2E tests**: Verify no regression in P2P session flow
