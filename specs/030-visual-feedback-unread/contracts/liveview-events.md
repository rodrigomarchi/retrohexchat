# LiveView Event Contracts: Visual Feedback & Unread Indicators

## Server → Client Events (push_event)

### `message_confirmed`

Sent when a pending message is confirmed by the server.

```elixir
push_event(socket, "message_confirmed", %{temp_id: "pending_123456"})
```

| Field | Type | Description |
|-------|------|-------------|
| `temp_id` | string | The client-generated temporary ID of the pending message. |

### `message_failed`

Sent when a pending message fails to send.

```elixir
push_event(socket, "message_failed", %{temp_id: "pending_123456", reason: "You are not permitted to speak"})
```

| Field | Type | Description |
|-------|------|-------------|
| `temp_id` | string | The client-generated temporary ID of the pending message. |
| `reason` | string | Human-readable error reason. |

### `feedback_toast`

Sent to display a simple confirmation toast (copy, settings).

```elixir
push_event(socket, "feedback_toast", %{message: "Configurações salvas", duration: 2000})
```

| Field | Type | Description |
|-------|------|-------------|
| `message` | string | Toast text. |
| `duration` | integer | Auto-dismiss duration in ms. |

### `channel_joined_flash`

Sent when a channel join succeeds, to trigger treebar flash.

```elixir
push_event(socket, "channel_joined_flash", %{channel: "#general"})
```

| Field | Type | Description |
|-------|------|-------------|
| `channel` | string | Channel name to flash in the treebar. |

## Client → Server Events (pushEvent)

### `retry_message`

Sent when the user clicks the retry button on a failed message.

```javascript
this.pushEvent("retry_message", { temp_id: "pending_123456", content: "hello", target: "#general" });
```

| Field | Type | Description |
|-------|------|-------------|
| `temp_id` | string | Temporary ID of the failed message. |
| `content` | string | Message content to retry. |
| `target` | string | Channel name or PM nickname. |

### `kick_dialog_dismiss`

Sent when the user clicks OK on the kick dialog.

```javascript
// Handled via phx-click in HEEx, not pushEvent
render_click(view, "kick_dialog_dismiss")
```

No payload — server dequeues the first kick event.

## Existing Events Modified

### `send_input` (Client → Server)

No change to the event signature. The server-side handler is modified to:
1. Generate a `temp_id` from the input timestamp.
2. Insert the message optimistically into the stream with `:pending` status.
3. Call `Server.send_message` as before.
4. Push `message_confirmed` or `message_failed` based on the result.

## Trigger Integration Points

| Trigger | Source File | Event/Action |
|---------|------------|--------------|
| Unread increment | `pubsub_handlers/messages.ex` | `apply_background_message` increments `unread_counts` |
| Unread reset | `core_events.ex` | `switch_channel` / `switch_pm` resets count |
| Highlight set | `pubsub_handlers/messages.ex` | `maybe_add_highlight_channel` (existing) |
| Kick enqueue | `pubsub_handlers/channel_state.ex` | `:user_kicked` handler adds to `kick_queue` |
| Kick dismiss | `kick_events.ex` | `kick_dialog_dismiss` dequeues first item |
| Copy toast | `scroll_hook.js` | After `navigator.clipboard.writeText` succeeds |
| Settings toast | `options_events.ex` | After `apply_draft` succeeds |
| Join flash | `helpers/channel.ex` | After successful `Server.join` |
| Message confirmed | `core_events.ex` | After `Server.send_message` returns `:ok` |
| Message failed | `core_events.ex` | After `Server.send_message` returns `{:error, _}` |
| Retry | `core_events.ex` | `retry_message` event handler |
