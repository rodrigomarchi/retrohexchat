# Data Model: Interactive Chat Elements

**Feature**: 027-interactive-chat-elements
**Date**: 2026-02-14

## Overview

This feature introduces no new database entities or migrations. All data is transient (UI state) or sourced from existing in-memory stores.

## LiveView Assigns (Transient State)

### `hover_card` assign

Tracks the currently visible nick hover card state. Added to `ChatLive` socket assigns.

```
hover_card :: %{
  visible: boolean(),
  nick: String.t() | nil,
  x: integer(),
  y: integer(),
  loading: boolean(),
  data: hover_card_data() | nil
}
```

**Default value**:
```
%{visible: false, nick: nil, x: 0, y: 0, loading: false, data: nil}
```

### `hover_card_data` structure

Populated from existing whois data sources when a nick hover is requested.

```
hover_card_data :: %{
  nickname: String.t(),
  hostname: String.t() | nil,
  online_for: String.t(),
  channels: [String.t()],
  away: boolean(),
  away_message: String.t() | nil,
  registered: boolean()
}
```

**Data sources**:
- `nickname`: From the `data-nick` attribute on the hovered element
- `hostname`: From Tracker presence metadata (`meta.hostname`)
- `online_for`: Computed from `connected_at` or `joined_at` in presence metadata, formatted as "2h 15m"
- `channels`: From `Tracker.list_users/1` across all channels (filtered for secret channels)
- `away` / `away_message`: From presence metadata
- `registered`: From `NickServ.registered?/1`

## Client-Side State (JavaScript)

### Interactive element state (in `interactive.js`)

```
hoverState :: {
  timer: number | null,          // setTimeout ID for 500ms debounce
  currentNick: string | null,    // Nick currently being hovered
  mouseDownPos: {x, y} | null,   // For click-vs-drag detection
  contextMenuOpen: boolean       // Flag to suppress interactions
}
```

### Channel tooltip cache (in `interactive.js`)

```
channelCache :: Map<string, {
  count: number,
  timestamp: number              // Cache for 30s to avoid repeated server calls
}>
```

## Existing Data Sources (No Changes)

| Data | Source | Access Pattern |
|------|--------|---------------|
| URL page title | `socket.assigns.link_previews` map | Direct lookup by URL key |
| Channel user count | `Channels.Server.get_state/1` → `Membership.count/1` | GenServer call (in-memory) |
| Channel topic | `Channels.Server.get_state/1` → `state.topic` | GenServer call (in-memory) |
| User joined channels | `Session.channels` | Already in socket assigns |
| Nick presence data | `Presence.Tracker.list_users/1` | ETS lookup |
| NickServ registration | `Services.NickServ.registered?/1` | GenServer call |
| Whois data | `ChatLive.Helpers.Whois.gather_whois_data/4` | Aggregation of above |

## Entity Relationships

```
Chat Message (existing)
  └── contains Interactive Elements (detected at render time)
       ├── URL Element (.chat-link[data-url])
       │     └── hover → URL Tooltip (native title attribute)
       │     └── click → window.open(url, '_blank')
       │
       ├── Channel Element (.chat-channel-link[data-channel])
       │     └── hover → Channel Tooltip (server-fetched count)
       │     └── click → join/switch channel (LiveView event)
       │
       └── Nick Element (.chat-nick[data-nick])
             └── hover 500ms → Nick Hover Card (server-fetched whois)
             └── single-click → insert "Nick: " into input
             └── double-click → open PM conversation
```
