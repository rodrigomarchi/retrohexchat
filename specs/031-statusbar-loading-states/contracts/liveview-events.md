# LiveView Event Contracts: Status Bar & Loading States

**Feature**: 031-statusbar-loading-states
**Date**: 2026-02-15

## Overview

This feature uses Phoenix LiveView's `pushEvent`/`push_event` mechanism for client-server communication. No REST APIs — all communication flows through the existing LiveView WebSocket channel.

## Client → Server Events (pushEvent)

### `ping`

Sent by `LagHook` every 30 seconds to measure round-trip latency.

```json
{
  "event": "ping",
  "payload": {
    "client_time": 1739620800000
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `client_time` | `integer` | `Date.now()` timestamp when ping was sent |

**Server handler**: `handle_event("ping", %{"client_time" => client_time}, socket)`
**Server response**: Echoes back via `push_event(socket, "pong", %{client_time: client_time})`

---

## Server → Client Events (push_event)

### `pong`

Echo of the ping timestamp, allowing the client to calculate round-trip time.

```json
{
  "event": "pong",
  "payload": {
    "client_time": 1739620800000
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `client_time` | `integer` | Original `Date.now()` timestamp echoed back |

**Client handler**: `LagHook.handleEvent("pong", {client_time})`
**Client action**: Calculates `Date.now() - client_time`, pushes `lag_update` to server.

---

### `lag_update`

Sent by `LagHook` after calculating round-trip time, so the server can update the assign.

```json
{
  "event": "lag_update",
  "payload": {
    "lag_ms": 45
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `lag_ms` | `integer \| null` | Measured latency in ms, null = timeout |

**Server handler**: `handle_event("lag_update", %{"lag_ms" => lag_ms}, socket)`
**Server action**: Updates `lag_ms` and `lag_status` assigns.

---

## LiveView Assign-Driven Rendering

These assigns drive component rendering without explicit events:

### Status Bar Component

| Assign | Drives | Component |
|--------|--------|-----------|
| `connection_state` | Center section text + icon color | `status_bar` |
| `lag_ms` | Right section "Lag: Xms" display | `status_bar` |
| `lag_status` | Right section lag color | `status_bar` |
| `channel` | Left section channel name | `status_bar` (existing) |
| `user_count` | Left section user count | `status_bar` (existing) |
| `muted` | Mute toggle display | `status_bar` (existing) |

### Connection Banner Component

| Assign | Drives | Component |
|--------|--------|-----------|
| `connection_state` | Banner visibility + content | `connection_banner` |
| `connection_established` | Suppresses banner during initial load | `connection_banner` |

### Loading Components

| Assign | Drives | Component |
|--------|--------|-----------|
| `loading_channel` | Spinner visibility in chat area | `loading_spinner` |
| `loading` (ChannelListLive) | Progress bar visibility | `channel_list_live` template |
| `channel_count` (ChannelListLive) | Progress bar count text | `channel_list_live` template |

## Hook Lifecycle Events

### LagHook

| Lifecycle | Action |
|-----------|--------|
| `mounted()` | Start 30s ping interval |
| `destroyed()` | Clear ping interval + timeout timer |
| `disconnected()` | Clear ping interval (stop measuring during disconnect) |
| `reconnected()` | Restart 30s ping interval |

### ClockHook

| Lifecycle | Action |
|-----------|--------|
| `mounted()` | Render current time, start 30s update interval |
| `destroyed()` | Clear interval |

### ConnectionBannerHook

| Lifecycle | Action |
|-----------|--------|
| `mounted()` | Set `wasConnected = false`, listen for phx events |
| `disconnected()` | If `wasConnected`, start 1s debounce timer |
| `reconnected()` | Cancel debounce, show green banner if red was showing, set `wasConnected = true` |
| `destroyed()` | Clear all timers |
