# Contract: LiveView Events for Audio/Video Calls

**Module**: `P2PSessionLive`
**Pattern**: Thin LiveView handlers — update assigns, push events to hooks

## Hook → LiveView Event Handlers

### `handle_event("media_call_started", %{"type" => type}, socket)`
Call successfully established.
- Sets `call` assign: `%{status: "#{type}_active", type: type, peer_muted: false, peer_camera_off: false}`
- Broadcasts call state to peer via PubSub

### `handle_event("media_call_ended", %{"reason" => reason}, socket)`
Call ended (user action or error).
- Sets `call` assign to `nil`
- Broadcasts call ended to peer
- Adds system message to lobby chat

### `handle_event("media_error", %{"code" => code, "message" => msg}, socket)`
Permission or device error.
- Sets `call` assign to `nil` (if call didn't start)
- Shows error to user (could use existing toast or inline)

### `handle_event("media_mute_changed", %{"muted" => muted}, socket)`
Local user toggled mute.
- Broadcasts mute state to peer via PubSub
- Peer's LiveView pushes `media_peer_muted` to their hook

### `handle_event("media_camera_changed", %{"off" => off}, socket)`
Local user toggled camera.
- Broadcasts camera state to peer via PubSub
- Peer's LiveView pushes `media_peer_camera` to their hook

### `handle_event("media_quality_update", %{"level" => level, "label" => label}, socket)`
Quality indicator update.
- Updates `call` assign with quality info for UI rendering

### `handle_event("media_request_upgrade", _params, socket)`
User wants to upgrade audio → video.
- Broadcasts upgrade request to peer via PubSub
- Peer's LiveView shows upgrade consent UI

### `handle_event("media_respond_upgrade", %{"accepted" => accepted}, socket)`
Peer responds to upgrade request.
- If accepted: pushes `media_upgrade_accepted` to requester's hook
- If rejected: pushes `media_upgrade_rejected` to requester's hook

### `handle_event("media_duration_tick", %{"formatted" => time}, socket)`
Timer tick from hook.
- Updates `call` assign duration for UI display

### `handle_event("media_device_fallback", %{"message" => msg}, socket)`
Device disconnected and fell back.
- Shows notification to user

### `handle_event("media_select_preset", %{"preset" => preset}, socket)`
User selects quality preset.
- Pushes preset to hook via `push_event`

## LiveView → Hook Events (push_event)

| Event | Payload | Trigger |
|-------|---------|---------|
| `media_start_audio` | `{}` | After bilateral consent for audio call |
| `media_start_video` | `{}` | After bilateral consent for video call |
| `media_end_call` | `{}` | User clicks end call button |
| `media_peer_muted` | `{muted: bool}` | Peer broadcast received |
| `media_peer_camera` | `{off: bool}` | Peer broadcast received |
| `media_upgrade_accepted` | `{}` | Peer accepted video upgrade |
| `media_upgrade_rejected` | `{}` | Peer rejected video upgrade |
| `media_set_preset` | `{preset: string}` | User selected quality preset |

## Socket Assigns

```elixir
# Added to existing P2PSessionLive assigns
call: nil | %{
  status: String.t(),      # "audio_active" | "video_active"
  type: String.t(),        # "audio" | "video"
  duration: String.t(),    # "00:05:23"
  quality_level: String.t(), # "excellent" | "good" | "fair" | "poor"
  quality_label: String.t(), # "Excelente" | "Bom" | "Regular" | "Ruim"
  peer_muted: boolean(),
  peer_camera_off: boolean(),
  upgrade_pending: boolean()  # true when waiting for upgrade response
}
```

## PubSub Messages (via "p2p:#{token}" topic)

| Message | Payload | Description |
|---------|---------|-------------|
| `{:media_mute, muted}` | `boolean` | Peer mute state change |
| `{:media_camera, off}` | `boolean` | Peer camera state change |
| `{:media_call_ended, reason}` | `string` | Peer ended the call |
| `{:media_upgrade_request}` | — | Peer wants video upgrade |
| `{:media_upgrade_response, accepted}` | `boolean` | Upgrade response |
