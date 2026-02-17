# Data Model: P2P Actions in Context Menus

**Feature**: 040-p2p-context-menus
**Date**: 2026-02-17

## Overview

No new database entities or migrations. This feature is purely UI-layer, wiring existing P2P infrastructure to context menu interactions. All state is ephemeral (socket assigns).

## Modified Assigns

### `context_menu` assign (nicklist context menu)

**Current shape**:
```elixir
%{visible: boolean, x: integer, y: integer, target_nick: string | nil}
```

**New shape** (added field):
```elixir
%{visible: boolean, x: integer, y: integer, target_nick: string | nil, is_target_registered: boolean}
```

### `chat_context_menu` assign (chat area context menu)

**Current shape**:
```elixir
%{visible: boolean, type: atom, x: integer, y: integer, target_nick: string, ...}
```

No structural change to the map — `is_target_registered` is computed at render time via a helper function passed as an attribute.

## Component Attributes (New)

### `context_menu.ex`

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `viewer_is_identified` | `:boolean` | `false` | Controls P2P items visibility (`:if` guard) |
| `is_target_registered` | `:boolean` | `false` | Controls P2P items disabled state |

### `chat_context_menu.ex`

| Attribute | Type | Default | Purpose |
|-----------|------|---------|---------|
| `viewer_is_identified` | `:boolean` | `false` | Controls P2P items visibility (`:if` guard) |
| `is_target_registered` | `:boolean` | `false` | Controls P2P items disabled state |

## Existing Entities Referenced (no changes)

### `RetroHexChat.P2P.Schema.Session`

- Session types: `generic`, `file_transfer`, `audio_call`, `video_call`
- Created via `RetroHexChat.P2P.create_session/3`
- Token-based addressing: `/p2p/:token`

### `RetroHexChat.Accounts.Session`

- `identified`: boolean — whether the current user is registered and identified
- `nickname`: string — current user's display name
