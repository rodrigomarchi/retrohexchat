# LiveView Event Contracts: Context Menus

**Date**: 2026-02-14 | **Feature**: 026-context-menus

## Client → Server Events (phx-click / pushEvent)

### Chat Area Right-Click Detection

**Event**: `chat_context_menu`
**Source**: JS hook on scroll container (replaces existing copy menu in scroll_hook.js)
**Payload**:
```elixir
%{
  "type" => "nick" | "url" | "channel" | "message",
  "x" => integer(),        # clientX
  "y" => integer(),        # clientY
  "nick" => String.t(),    # present when type=nick
  "url" => String.t(),     # present when type=url or type=message (first URL in message)
  "channel" => String.t(), # present when type=channel
  "author" => String.t(),  # present when type=nick or type=message
  "message_id" => String.t(),  # DOM id of the message element
  "is_system" => boolean(),    # true for join/part/quit messages
  "message_urls" => [String.t()],  # all URLs in the message
  "has_selection" => boolean(),    # whether text is selected
  "message_text" => String.t()     # formatted message line for Copy Message
}
```

### Chat Context Menu Actions

| Event | Payload | Action |
|-------|---------|--------|
| `ctx_chat_pm` | `%{"nick" => nick}` | Open PM with nick |
| `ctx_chat_whois` | `%{"nick" => nick}` | Execute /whois on nick |
| `ctx_chat_copy_nick` | `%{"nick" => nick}` | Push clipboard_copy event with nick text |
| `ctx_chat_ignore` | `%{"nick" => nick}` | Execute /ignore on nick |
| `ctx_chat_add_contact` | `%{"nick" => nick}` | Add nick to address book |
| `ctx_chat_set_color` | `%{"nick" => nick}` | Open color picker for nick |
| `ctx_chat_kick` | `%{"nick" => nick}` | Execute /kick on nick (op only) |
| `ctx_chat_ban` | `%{"nick" => nick}` | Execute /ban on nick (op only) |
| `ctx_chat_voice` | `%{"nick" => nick}` | Execute /voice on nick (op only) |
| `ctx_chat_op` | `%{"nick" => nick}` | Execute /op on nick (op only) |
| `ctx_chat_open_url` | `%{"url" => url}` | Push open_url event to JS |
| `ctx_chat_copy_url` | `%{"url" => url}` | Push clipboard_copy event with URL |
| `ctx_chat_save_url` | `%{"url" => url, "author" => author}` | Add URL to catcher list |
| `ctx_chat_join` | `%{"channel" => channel}` | Execute /join on channel |
| `ctx_chat_fav` | `%{"channel" => channel}` | Add channel to favorites |
| `ctx_chat_copy_channel` | `%{"channel" => channel}` | Push clipboard_copy with channel name |
| `ctx_chat_channel_info` | `%{"channel" => channel}` | Open channel info dialog |
| `ctx_chat_copy_message` | `%{"text" => text}` | Push clipboard_copy with full message line |
| `ctx_chat_copy_selection` | (none) | Push clipboard_copy_selection to JS |
| `ctx_chat_ignore_sender` | `%{"nick" => nick}` | Execute /ignore on message author |
| `close_chat_context_menu` | (none) | Close the chat context menu |

### Extended Treebar Context Menu Actions

| Event | Payload | Action |
|-------|---------|--------|
| `ctx_treebar_mark_read` | `%{"channel" => ch}` | Remove channel from unread_channels MapSet |
| `ctx_treebar_mute` | `%{"channel" => ch}` | Toggle channel in muted_channels, persist to prefs |
| `add_to_favorites` | `%{"channel" => ch}` | (existing) Add to favorites |
| `ctx_treebar_copy_name` | `%{"channel" => ch}` | Push clipboard_copy with channel name |
| `ctx_treebar_leave` | `%{"channel" => ch}` | Execute /part on channel |
| `ctx_treebar_settings` | `%{"channel" => ch}` | Open channel settings dialog |

## Server → Client Events (push_event)

| Event | Payload | JS Action |
|-------|---------|-----------|
| `clipboard_copy` | `%{text: String.t()}` | `navigator.clipboard.writeText(text)` |
| `clipboard_copy_selection` | (none) | Copy current text selection via `document.execCommand("copy")` or `navigator.clipboard.writeText(window.getSelection().toString())` |
| `open_url` | `%{url: String.t()}` | `window.open(url, "_blank", "noopener,noreferrer")` |

## Component Contracts

### ChatContextMenu Component

```elixir
attr :menu, :map, required: true  # The chat_context_menu assign
attr :viewer_nick, :string, required: true
attr :viewer_is_op, :boolean, default: false
attr :is_target_ignored, :boolean, default: false
attr :is_target_self, :boolean, default: false
attr :is_already_joined, :boolean, default: false
attr :key_bindings, :map, default: %{}  # For shortcut hint display
```

### TreebarContextMenu Component (extended)

```elixir
# Existing attrs plus:
attr :is_muted, :boolean, default: false  # Toggle Mute/Unmute label
attr :has_unread, :boolean, default: false  # Enable/disable Mark as Read
attr :key_bindings, :map, default: %{}
```
