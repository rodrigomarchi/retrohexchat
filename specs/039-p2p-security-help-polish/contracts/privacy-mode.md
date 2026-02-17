# Contract: TURN-Only Privacy Mode

**Feature**: 039-p2p-security-help-polish
**Date**: 2026-02-16

## Server → Client Event Changes

### `p2p_start_offer` / `p2p_start_answer` Events

Current payload:
```json
{ "ice_servers": [...], "role": "initiator" }
```

New payload (adds `turn_only` flag):
```json
{ "ice_servers": [...], "role": "initiator", "turn_only": false }
```

## Client-Side: `webrtc.js` Changes

### `createPeerConnection(iceServers, options)`

Current:
```javascript
export function createPeerConnection(iceServers) {
  return new RTCPeerConnection({ iceServers });
}
```

New:
```javascript
export function createPeerConnection(iceServers, options = {}) {
  const config = { iceServers };
  if (options.turnOnly) {
    config.iceTransportPolicy = "relay";
  }
  return new RTCPeerConnection(config);
}
```

## LiveView → Preference Persistence

### New event: `toggle_privacy_mode`

```elixir
def handle_event("toggle_privacy_mode", %{"enabled" => enabled}, socket)
```

Updates `message_settings.p2p_settings.turn_only` in user_preferences.

### Mount: Read preference

On `P2PSessionLive.mount/3`, read user's `turn_only` preference and assign to socket.

## TURN Availability Check

### `P2P.turn_configured?/0`

```elixir
@spec turn_configured?() :: boolean()
def turn_configured?()
```

Returns `true` if TURN server URLs are configured in application env. Used to:
1. Warn user when privacy mode enabled but TURN unavailable.
2. Conditionally show/hide the privacy mode checkbox.
