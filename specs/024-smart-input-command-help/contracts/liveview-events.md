# LiveView Event Contracts: Smart Input & Command Help

**Feature**: 024-smart-input-command-help
**Date**: 2026-02-13

This feature uses LiveView events (pushEvent / handleEvent) rather than REST endpoints. Below are the event contracts organized by direction.

## Client → Server Events

### `syntax_tooltip_query`

Triggered when the input contains a recognized command and the autocomplete is closed.

**Pushed by**: AutocompleteHook (extended)
**Payload**:
```javascript
{
  command: "mode",       // Command name without slash
  args: "#general +o",   // Current argument string (everything after command + space)
  detail_level: "beginner" // Current user preference (cached client-side)
}
```

**When triggered**:
- On each `input` event when text starts with `/<command> ` (with space)
- After autocomplete selection inserts a command
- NOT when autocomplete dropdown is visible

### `syntax_tooltip_dismiss`

Triggered when user presses Escape to dismiss the tooltip.

**Pushed by**: AutocompleteHook (extended)
**Payload**: `{}`

### `update_command_help_level`

Triggered when user changes the tooltip detail level in settings.

**Pushed by**: OptionsHook (via form event)
**Payload**:
```javascript
{
  level: "expert"  // "beginner" | "expert" | "off"
}
```

## Server → Client Events

### `syntax_tooltip_data`

Sent in response to `syntax_tooltip_query` with computed tooltip content.

**Pushed by**: ChatLive event handler
**Payload**:
```javascript
{
  visible: true,
  command: "mode",
  syntax: "/mode <#canal> <+/-modos> [nick]",
  current_param_index: 2,  // 0-indexed, which param to highlight
  parameters: [
    { name: "#canal", required: true, type: "channel", description: "Canal para modificar" },
    { name: "+/-modos", required: true, type: "mode_flags", description: "Flags de modo" },
    { name: "nick", required: false, type: "nick", description: "Nickname alvo" }
  ],
  context_message: "Você está definindo: +o (operador). Próximo: nickname do usuário.",
  sub_options: [
    { flag: "+o", label: "Operador", description: "Dar status de operador ao nick", requires_param: true },
    { flag: "+v", label: "Voz", description: "Dar status de voz ao nick", requires_param: true },
    { flag: "+b", label: "Ban", description: "Banir máscara do canal", requires_param: true },
    { flag: "+i", label: "Convite", description: "Canal somente com convite", requires_param: false },
    { flag: "+m", label: "Moderado", description: "Somente +v e +o podem falar", requires_param: false },
    { flag: "+t", label: "Tópico", description: "Somente operadores podem mudar o tópico", requires_param: false }
  ],
  detail_level: "beginner"  // Server echoes back for consistency
}
```

### `syntax_tooltip_hide`

Sent to hide the tooltip (e.g., when autocomplete opens, input cleared).

**Pushed by**: ChatLive event handler
**Payload**:
```javascript
{
  visible: false
}
```

### `set_input`

Already exists — server can set input value. No changes needed.

**Payload**:
```javascript
{
  value: "/mode "  // The text to place in the input
}
```

## Existing Events — No Changes

These events continue to work as-is:

| Event | Direction | Purpose |
|-------|-----------|---------|
| `autocomplete_query` | Client → Server | Trigger autocomplete search |
| `autocomplete_results` | Server → Client | Return autocomplete matches |
| `autocomplete_select` | Client → Server | User selects autocomplete item |
| `autocomplete_close` | Client → Server | Close autocomplete dropdown |
| `history_navigate` | Client → Server | Existing Up/Down history (unchanged) |
| `send_input` | Client → Server | Form submission (unchanged) |

## Client-Side Only Contracts (No Server Involvement)

### localStorage: `retro_hex_chat_history`

**Format**: JSON array of history entries
```javascript
[
  { "text": "/join #general", "timestamp": 1739462400000 },
  { "text": "hello everyone!", "timestamp": 1739462401000 }
]
```

**Max entries**: 100 (FIFO)
**Sensitive filter**: Entries starting with `/identify`, `/nickserv`, `/ns` are never persisted.

### Ctrl+Up/Down History Navigation

Handled entirely in JavaScript hook. No server events. State:
- `historyBuffer`: Array of strings from localStorage
- `historyIndex`: Current position (-1 = not browsing)
- `draft`: Saved input text + cursor position

### Ctrl+R Reverse Search

Handled entirely in JavaScript hook. No server events. State:
- `searchActive`: Boolean
- `searchTerm`: String
- `searchResult`: Matching history entry or null
