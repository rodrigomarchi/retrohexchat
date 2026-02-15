# Data Model: Status Bar & Loading States

**Feature**: 031-statusbar-loading-states
**Date**: 2026-02-15

## Overview

This feature introduces no persistent data — all state is ephemeral, living in LiveView socket assigns (server-side) and JavaScript variables (client-side). No database migrations required.

## Server-Side State (Socket Assigns)

### ChatLive Assigns

| Assign | Type | Default | Description |
|--------|------|---------|-------------|
| `connection_state` | `:connecting \| :connected \| :disconnected \| :reconnecting` | `:connected` | Current connection state for status bar display |
| `lag_ms` | `non_neg_integer() \| nil` | `nil` | Last measured round-trip latency in milliseconds, nil = no measurement yet |
| `lag_status` | `:normal \| :warning \| :critical \| :timeout` | `:normal` | Derived from lag_ms thresholds |
| `loading_channel` | `String.t() \| nil` | `nil` | Channel name currently loading history, nil = not loading |
| `connection_established` | `boolean()` | `false` | Whether a successful connection has been made (for banner suppression during initial load) |

### ChannelListLive Assigns

| Assign | Type | Default | Description |
|--------|------|---------|-------------|
| `loading` | `boolean()` | `true` | Whether channel list is being fetched |
| `channel_count` | `non_neg_integer()` | `0` | Count of channels loaded so far |

## Client-Side State (JavaScript)

### LagHook State

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `pingTimer` | `number \| null` | `null` | setInterval ID for periodic pings |
| `pendingPingTime` | `number \| null` | `null` | Timestamp of last sent ping (Date.now()) |
| `timeoutTimer` | `number \| null` | `null` | setTimeout ID for ping timeout detection |

### ClockHook State

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `clockTimer` | `number \| null` | `null` | setInterval ID for clock updates |

### ConnectionBannerHook State

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `debounceTimer` | `number \| null` | `null` | setTimeout ID for 1-second debounce |
| `fadeTimer` | `number \| null` | `null` | setTimeout ID for 3-second reconnected fade |
| `bannerState` | `'hidden' \| 'disconnected' \| 'reconnected'` | `'hidden'` | Current banner visual state |
| `wasConnected` | `boolean` | `false` | Whether connection was established at least once |
| `countdownTimer` | `number \| null` | `null` | setInterval ID for countdown ticks |
| `countdownValue` | `number` | `0` | Current countdown seconds |

## State Transitions

### Connection State Machine

```
                    mount
                      │
                      ▼
              ┌──────────────┐
              │  :connecting  │
              └──────┬───────┘
                     │ LiveView mounted successfully
                     ▼
              ┌──────────────┐
     ┌───────▶│  :connected   │◀────────┐
     │        └──────┬───────┘         │
     │               │ WebSocket drops │
     │               ▼                 │
     │        ┌──────────────┐         │
     │        │ :disconnected │         │
     │        └──────┬───────┘         │
     │               │ Auto-reconnect  │
     │               ▼                 │
     │        ┌──────────────┐         │
     │        │ :reconnecting │─────────┘
     │        └──────┬───────┘  (success)
     │               │
     │               │ (max retries)
     │               ▼
     │        ┌──────────────┐
     └────────│ :disconnected │
              └──────────────┘
```

### Banner State Machine

```
              ┌────────────┐
              │   hidden    │◀──────────────────────┐
              └─────┬──────┘                        │
                    │ disconnect detected            │
                    │ (1s debounce)                  │
                    ▼                                │
              ┌────────────┐                        │
              │disconnected │──── reconnect ────▶┌───┴────────┐
              │ (red banner)│                    │reconnected  │
              └─────┬──────┘                    │(green banner)│
                    │                           └─────┬───────┘
                    │ overlay takes over               │ 3s fade
                    ▼                                  ▼
              ┌────────────┐                    ┌────────────┐
              │   hidden    │                    │   hidden    │
              └────────────┘                    └────────────┘
```

### Lag Status Derivation

| lag_ms Value | lag_status |
|-------------|------------|
| nil (no measurement) | :normal (display "—") |
| 0-199 | :normal |
| 200-499 | :warning |
| 500+ | :critical |
| timeout (no response in 10s) | :timeout (display "?") |

## Entities Summary

No database entities. All state is per-session ephemeral data managed through:
- **Server**: Phoenix LiveView socket assigns (per-process memory)
- **Client**: JavaScript hook instance variables (per-browser-tab memory)
- **Cleanup**: All state is automatically garbage-collected when the LiveView process terminates or the browser tab closes
