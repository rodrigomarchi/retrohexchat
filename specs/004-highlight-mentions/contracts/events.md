# LiveView Events Contract: Highlight / Mentions

**Feature**: 004-highlight-mentions
**Date**: 2026-02-11

## Server → Client Events (push_event)

### `play_sound`

Triggers notification sound via existing SoundHook.

```elixir
push_event(socket, "play_sound", %{type: "mention"})
```

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `type` | `string` | `"mention"` | Sound type (maps to 880Hz sine, 150ms) |

**Trigger**: When a highlight is detected in any channel (active or not) and the channel is not muted.

### `scroll_to_bottom` (existing)

No changes. Already used by ScrollHook.

## Client → Server Events (phx-click / pushEvent)

### `open_highlight_dialog`

Opens the Highlight configuration dialog.

```elixir
# Triggered by menu item click or Alt+H keyboard shortcut
def handle_event("open_highlight_dialog", _params, socket)
```

**Response**: Sets `show_highlight_dialog: true` assign.

### `close_highlight_dialog`

Closes the Highlight configuration dialog.

```elixir
def handle_event("close_highlight_dialog", _params, socket)
```

**Response**: Sets `show_highlight_dialog: false` assign.

### `highlight:add`

Adds a new highlight word.

```elixir
def handle_event("highlight:add", %{"word" => word, "bg_color" => bg_color}, socket)
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `word` | `string` | Yes | Word to highlight (1-50 chars) |
| `bg_color` | `string` | No | IRC color index as string ("0"-"15") or empty |

**Response**: Updates session highlight_words, persists if identified.

**Errors**: Word already exists (case-insensitive), word too long, list full (50 max).

### `highlight:edit`

Edits an existing highlight word's color.

```elixir
def handle_event("highlight:edit", %{"word" => word, "bg_color" => bg_color}, socket)
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `word` | `string` | Yes | Existing word to update |
| `bg_color` | `string` | No | New IRC color index or empty (nil = default) |

**Response**: Updates session highlight_words, persists if identified.

### `highlight:remove`

Removes a highlight word.

```elixir
def handle_event("highlight:remove", %{"word" => word}, socket)
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `word` | `string` | Yes | Word to remove |

**Response**: Removes from session highlight_words, persists if identified.

### `highlight:reorder`

Changes the priority order of highlight words.

```elixir
def handle_event("highlight:reorder", %{"words" => ordered_words}, socket)
```

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `words` | `list(string)` | Yes | Words in new order |

**Response**: Updates positions in session highlight_words, persists if identified.

## PubSub Messages (unchanged)

### `%{event: "new_message", payload: payload}`

No changes to broadcast format. Highlight detection happens in the receiving LiveView's `handle_info`, not at broadcast time.

**Existing payload fields used for highlighting**:
- `payload.author` — compared to `session.nickname` for self-highlight prevention
- `payload.content` — text matched against highlight words
- `payload.type` — `:system`/`:service`/`:error` types skip highlighting
- `payload.channel` — determines if flash/sound should trigger (active vs. non-active)

## Stream Item Decoration

### Before highlight (existing)

```elixir
%{
  id: id,
  channel: channel,
  author: nickname,
  content: content,
  type: :message,
  timestamp: timestamp
}
```

### After highlight decoration (new)

```elixir
%{
  id: id,
  channel: channel,
  author: nickname,
  content: content,
  type: :message,
  timestamp: timestamp,
  highlighted: true,           # NEW - boolean
  highlight_color: "#3a3500"   # NEW - CSS color string or nil
}
```

Non-highlighted messages do not have these keys (or have `highlighted: false`).

## Component Assigns

### TreeBar (modified)

```elixir
<Components.Treebar.treebar
  channels={@session.channels}
  active_channel={@session.active_channel}
  unread_channels={MapSet.to_list(@unread_channels)}
  highlight_channels={MapSet.to_list(@highlight_channels)}  # NEW
  pm_conversations={@session.pm_conversations}
  active_pm={@session.active_pm}
/>
```

### HighlightDialog (new)

```elixir
<Components.HighlightDialog.highlight_dialog
  :if={@show_highlight_dialog}
  highlight_words={@session.highlight_words.entries}
  own_nickname={@session.nickname}
/>
```
