# LiveView Event Contracts: Contextual Tips

**Feature**: 029-contextual-tips | **Date**: 2026-02-14

## Server → Client Events (push_event)

### `tip_trigger`

Pushed from LiveView to JS hook when a tip-worthy event occurs.

**Direction**: Server → Client
**Target**: `ContextualTipsHook` (attached to toast container element)

```elixir
# Elixir (LiveView)
push_event(socket, "tip_trigger", %{tip: tip_id})
```

```javascript
// JS (Hook)
this.handleEvent("tip_trigger", ({ tip }) => { ... })
```

**Payload**:

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `tip` | `string` | `"first_message"`, `"first_join"`, `"first_pm"`, `"first_highlight"`, `"help_used"` | Tip identifier or preemption signal |

**Notes**:
- `"help_used"` is not a tip to display — it signals that the idle tip should be preempted
- The hook decides whether to show, queue, or discard based on local state

---

### `tips_toggle`

Pushed from LiveView to JS hook when the user toggles the tips setting in the Options dialog.

**Direction**: Server → Client
**Target**: `ContextualTipsHook`

```elixir
# Elixir (LiveView)
push_event(socket, "tips_toggle", %{enabled: enabled})
```

```javascript
// JS (Hook)
this.handleEvent("tips_toggle", ({ enabled }) => { ... })
```

**Payload**:

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `enabled` | `boolean` | `true` / `false` | Whether tips should be enabled (`true`) or suppressed (`false`) |

---

## Client → Server Events (pushEvent)

### `tips_state_sync`

Pushed from JS hook to LiveView to sync the current suppression state for the Settings UI.

**Direction**: Client → Server
**Target**: `TipEvents` handler module

```javascript
// JS (Hook)
this.pushEvent("tips_state_sync", { suppressed: isSuppressed() })
```

```elixir
# Elixir (LiveView)
def handle_event("tips_state_sync", %{"suppressed" => suppressed}, socket)
```

**Payload**:

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `suppressed` | `boolean` | `true` / `false` | Current global suppression state from localStorage |

**Notes**:
- Pushed on hook mount so the Options dialog can display the correct toggle state
- Also pushed after user toggles "Não mostrar mais dicas" on a toast

---

## Trigger Integration Points

| Source File | Event | Tip ID | Condition |
|-------------|-------|--------|-----------|
| `core_events.ex` | `send_input` (message branch) | `"first_message"` | Always on message send |
| `helpers/channel.ex` | `join_channel/4` success | `"first_join"` | Always on successful join |
| `pubsub_handlers/messages.ex` | `new_pm` handler | `"first_pm"` | Always on PM receive |
| `pubsub_handlers/messages.ex` | After `maybe_highlight` | `"first_highlight"` | Only when `decorated.highlighted == true` |
| `command_dispatch.ex` | `/help` dispatch | `"help_used"` | Always on /help execution |
| `contextual_tips_hook.js` | Idle timer (30s) | `"idle_help"` | Client-side only, no server event |
