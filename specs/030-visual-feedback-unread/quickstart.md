# Quickstart: Visual Feedback & Unread Indicators

## Architecture Overview

```text
┌─────────────────────────────────────────────────────────┐
│                    Browser (Client)                      │
│                                                          │
│  ┌──────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ TreebarHook│  │  ScrollHook  │  │ContextualTipsHook │  │
│  │ ─join flash│  │ ─copy toast  │  │ ─feedback toast   │  │
│  └────┬─────┘  └──────┬───────┘  └────────┬──────────┘  │
│       │               │                    │              │
│  ┌────┴─────┐  ┌──────┴───────┐  ┌────────┴──────────┐  │
│  │ unread.js │  │feedback_toast│  │   toast.js (Z2)   │  │
│  │ (badges)  │  │   .js        │  │   (rendering)     │  │
│  └───────────┘  └──────────────┘  └───────────────────┘  │
└────────────────────────┬────────────────────────────────┘
                         │ LiveView WebSocket
┌────────────────────────┴────────────────────────────────┐
│                    Server (Elixir)                        │
│                                                          │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │ ChatLive     │  │ Treebar.ex   │  │ KickDialog.ex  │  │
│  │ (assigns)    │  │ (component)  │  │ (component)    │  │
│  │              │  │ ─badges      │  │ ─queued dialog │  │
│  │ unread_counts│  │ ─6 states    │  └────────────────┘  │
│  │ kick_queue   │  └──────────────┘                      │
│  └──────┬──────┘                                         │
│         │                                                │
│  ┌──────┴──────────────────────────────────────────────┐ │
│  │              PubSub Handlers                         │ │
│  │  messages.ex  ─→ unread increment                    │ │
│  │  channel_state.ex ─→ kick enqueue                    │ │
│  └──────────────────────────────────────────────────────┘ │
│         │                                                │
│  ┌──────┴──────┐                                         │
│  │UnreadTracker │  (domain — pure Elixir, no Phoenix)    │
│  │ increment()  │                                        │
│  │ reset()      │                                        │
│  │ display()    │                                        │
│  └──────────────┘                                        │
└──────────────────────────────────────────────────────────┘
```

## Data Flow

### Unread Message Flow

```text
1. User message arrives via PubSub → messages.ex handle_info
2. Is the message in the active channel?
   ├── YES → stream_insert to chat (no unread increment)
   └── NO → apply_background_message
       ├── Is the channel muted?
       │   ├── YES → increment count silently (no flash/sound)
       │   └── NO → increment count + flash + sound
       ├── UnreadTracker.increment(unread_counts, channel)
       ├── Is it a highlight (mention)?
       │   └── YES → MapSet.put(highlight_channels, channel)
       └── assign(unread_counts: updated, highlight_channels: updated)
3. Treebar re-renders with new counts → badges appear
```

### Channel Switch Flow

```text
1. User clicks channel in treebar → "switch_channel" event
2. UnreadTracker.reset(unread_counts, channel)
3. MapSet.delete(highlight_channels, channel)
4. assign(unread_counts: updated, highlight_channels: updated)
5. Treebar re-renders → badges removed for that channel
```

### Kick Dialog Flow

```text
1. :user_kicked PubSub → channel_state.ex
2. Is the kicked user me?
   └── YES → kick_queue = kick_queue ++ [%{channel, operator, reason}]
       └── assign(kick_queue: updated)
3. chat_live.html.heex conditionally renders KickDialog
4. User clicks OK → "kick_dialog_dismiss" event
5. kick_queue = tl(kick_queue)  # remove first
6. If queue not empty → next dialog renders automatically
```

### Copy Toast Flow (Client-side)

```text
1. User copies text → ScrollHook clipboard handler fires
2. navigator.clipboard.writeText(text) succeeds
3. Find toast container element
4. feedback_toast.showFeedbackToast(container, "Copiado!", 2000)
5. Toast appears → auto-dismisses after 2s
```

### Settings Toast Flow (Server-side)

```text
1. User clicks OK/Apply in Options → options_events.ex apply_draft
2. push_event(socket, "feedback_toast", %{message: "Configurações salvas", duration: 2000})
3. ContextualTipsHook or dedicated handler creates toast
4. Toast appears → auto-dismisses after 2s
```

## File Map

| File | Change | Purpose |
|------|--------|---------|
| `chat/unread_tracker.ex` | NEW | Pure domain logic for unread count operations |
| `treebar.css` | NEW | Badge CSS, muted/disconnected states, join flash animation |
| `app.css` | MOD | Import treebar.css |
| `unread.js` | NEW | Badge DOM rendering functions |
| `feedback_toast.js` | NEW | Simple feedback toast creation/display |
| `treebar_hook.js` | MOD | Join flash handler, feedback toast handler |
| `scroll_hook.js` | MOD | Copy toast trigger after clipboard write |
| `treebar.ex` | MOD | Badge rendering, muted/disconnected states, new attrs |
| `kick_dialog.ex` | NEW | Kick notification dialog component |
| `chat_live.ex` | MOD | New assigns: unread_counts, kick_queue |
| `chat_live.html.heex` | MOD | Render kick dialog conditionally |
| `messages.ex` | MOD | Increment unread counts on background messages |
| `channel_state.ex` | MOD | Enqueue kick events instead of just system message |
| `core_events.ex` | MOD | Optimistic send, message confirm/fail, retry handler |
| `options_events.ex` | MOD | Push feedback_toast on settings save |
| `channel.ex` | MOD | Push channel_joined_flash on join |
| `kick_events.ex` | NEW | Handle kick_dialog_dismiss event |

## Testing Strategy

| Layer | Tool | What to Test |
|-------|------|-------------|
| Domain (UnreadTracker) | ExUnit | increment, reset, display_count, system message filtering |
| JS libs (unread, feedback_toast) | Vitest | formatCount, createBadge, updateBadge, toast creation |
| JS hooks (treebar, scroll) | Vitest | join flash animation, copy toast trigger |
| Components (treebar, kick_dialog) | LiveViewTest | Badge rendering, dialog display, queue behavior |
| E2E | LiveViewTest | Full flows: message → unread badge, kick → dialog, copy → toast |

## MVP Scope

**US1 (Treebar Unread Indicators)** alone delivers significant value and can be shipped independently. It requires:
- `UnreadTracker` domain module
- `treebar.css` with badge styles
- `treebar.ex` badge rendering
- `messages.ex` count increment
- `core_events.ex` count reset on switch

This can be tested and deployed without any of the other user stories.
