# Event Contracts: Keyboard Shortcuts & Chat Search

**Feature**: 025-shortcuts-chat-search
**Date**: 2026-02-13

## LiveView Events (Client → Server)

### Shortcut Dispatch

| Event | Params | Handler Module | Description |
|-------|--------|----------------|-------------|
| `shortcut_action` | `%{"action" => string}` | `KeyboardEvents` | Global dispatcher sends matched action name |

### Search Events

| Event | Params | Handler Module | Description |
|-------|--------|----------------|-------------|
| `search_input` | `%{"query" => string}` | `SearchEvents` | User typed in search bar (300ms debounce) |
| `search_next` | `%{}` | `SearchEvents` | Navigate to next match |
| `search_prev` | `%{}` | `SearchEvents` | Navigate to previous match |
| `close_search` | `%{}` | `SearchEvents` | Close search bar |
| `toggle_search` | `%{}` | `SearchEvents` | Show/hide search bar |
| `search_toggle_filter` | `%{"filter" => string}` | `SearchEvents` | Toggle a filter: "case_sensitive", "regex", "my_mentions", "history" |

### Navigation Events

| Event | Params | Handler Module | Description |
|-------|--------|----------------|-------------|
| `window_next` | `%{}` | `NavigationEvents` | Switch to next window in treebar order |
| `window_prev` | `%{}` | `NavigationEvents` | Switch to previous window in treebar order |
| `window_select` | `%{"index" => integer}` | `NavigationEvents` | Switch to window at 1-based index |

### Cheatsheet Events

| Event | Params | Handler Module | Description |
|-------|--------|----------------|-------------|
| `toggle_cheatsheet` | `%{}` | `KeyboardEvents` | Open/close cheatsheet dialog |

## Server Push Events (Server → Client)

### Search Highlighting

| Event | Payload | Target Hook | Description |
|-------|---------|-------------|-------------|
| `search_highlight` | `%{query: string, case_sensitive: bool, regex: bool, my_mentions: bool, nick: string}` | `SearchHighlightHook` | Trigger client-side text highlighting |
| `search_scroll_to` | `%{index: integer}` | `SearchHighlightHook` | Scroll to and activate the Nth match |
| `search_clear_highlights` | `%{}` | `SearchHighlightHook` | Remove all highlight marks from DOM |

### Shortcut Dispatcher Configuration

| Event | Payload | Target Hook | Description |
|-------|---------|-------------|-------------|
| `update_bindings` | `%{bindings: map}` | `ShortcutDispatcherHook` | Send current binding map to JS for lookup |

## Client Push Events (JS Hook → Server)

### Search Highlight Results

| Event | Payload | Source Hook | Description |
|-------|---------|-------------|-------------|
| `search_highlight_count` | `%{"count" => integer}` | `SearchHighlightHook` | Report total matches found client-side |

## PubSub Topics

No new PubSub topics. All events are session-scoped (LiveView socket), not broadcast.

## Elixir Function Contracts

### KeyBindings Module (extended)

```elixir
# NEW: Returns full registry with metadata for cheatsheet/help
@spec registry(bindings :: map()) :: [registry_entry()]
@type registry_entry :: %{
  action: atom(),
  category: :navigation | :chat | :formatting | :system,
  label: String.t(),
  description: String.t(),
  binding: binding() | nil,
  default_binding: binding(),
  customizable: boolean()
}

# NEW: Returns all categories with their entries
@spec categories(bindings :: map()) :: [{atom(), [registry_entry()]}]

# EXISTING (unchanged): find_action, conflict?, reserved?, validate, etc.
```

### Search Module (extended)

```elixir
# MODIFIED: Add filter options
@spec search_messages(String.t(), String.t(), keyword()) :: [Message.t()]
# New options: case_sensitive: boolean, regex: boolean, nick_filter: String.t() | nil

# MODIFIED: Add filter options
@spec count_matches(String.t(), String.t(), keyword()) :: non_neg_integer()
# New options: case_sensitive: boolean, regex: boolean, nick_filter: String.t() | nil

# NEW: Validate regex pattern
@spec valid_regex?(String.t()) :: boolean()
```

### NavigationEvents Module (new)

```elixir
@spec handle_event("window_next", map(), Socket.t()) :: {:noreply, Socket.t()}
@spec handle_event("window_prev", map(), Socket.t()) :: {:noreply, Socket.t()}
@spec handle_event("window_select", %{"index" => integer()}, Socket.t()) :: {:noreply, Socket.t()}
```
