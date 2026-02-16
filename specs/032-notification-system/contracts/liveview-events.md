# LiveView Event Contracts: Notification System

**Branch**: `032-notification-system` | **Date**: 2026-02-15

## Server → Client Events (push_event)

### `notify`

Sent when a notification-worthy event occurs. The client-side NotificationDispatcher processes this event and fans out to all notification channels.

```elixir
push_event(socket, "notify", %{
  id: "notif_" <> unique_id,          # String — unique notification ID
  type: "mention" | "pm" | "channel_message" | "join" | "leave",
  channel: "#dev" | nil,               # String | nil — source channel (nil for PMs)
  sender: "Mario",                     # String — message author
  content: "Hey @Nick, check this!",   # String — message preview (max 100 chars)
  timestamp: "2026-02-15T10:30:00Z",   # String — ISO 8601
  highlighted: true | false             # Boolean — highlight/mention detected
})
```

### `notification_batch`

Sent on reconnect when multiple notifications accumulated. Client shows a summary toast instead of individual notifications.

```elixir
push_event(socket, "notification_batch", %{
  count: 15,                            # Integer — total new messages
  channels: ["#dev", "#general", "PM:Alice"],  # [String] — affected channels
  channel_count: 3                      # Integer — number of distinct channels
})
```

### `update_notification_prefs`

Sent when server confirms preference changes (after save). Client updates local state.

```elixir
push_event(socket, "update_notification_prefs", %{
  sounds_enabled: true,
  browser_notifications: false,
  title_flash_enabled: true,
  privacy_mode: false,
  dnd_enabled: false,
  trigger_mentions: true,
  trigger_pms: true,
  trigger_channel_messages: false,
  trigger_joins_leaves: false,
  channel_levels: %{"#general" => "mentions_only", "#music" => "mute"}
})
```

### `dnd_changed`

Sent when DND state changes (via toolbar toggle or settings).

```elixir
push_event(socket, "dnd_changed", %{
  enabled: true | false
})
```

## Client → Server Events (pushEvent / phx-click)

### `save_notification_prefs`

Client pushes updated notification preferences to server for persistence.

```javascript
this.pushEvent("save_notification_prefs", {
  sounds_enabled: true,
  browser_notifications: false,
  title_flash_enabled: true,
  privacy_mode: false,
  dnd_enabled: false,
  trigger_mentions: true,
  trigger_pms: true,
  trigger_channel_messages: false,
  trigger_joins_leaves: false,
  channel_levels: { "#general": "mentions_only", "#music": "mute" }
});
```

### `toggle_dnd`

Quick toggle DND from toolbar button.

```javascript
// phx-click="toggle_dnd" on toolbar button
```

### `toggle_notification_center`

Open/close notification center panel.

```javascript
// phx-click="toggle_notification_center" on bell icon
```

### `mark_all_notifications_read`

Clear all notification entries and badges.

```javascript
// phx-click="mark_all_notifications_read" in notification center
```

### `click_notification`

Navigate to the channel/PM associated with a notification entry.

```javascript
// phx-click="click_notification" phx-value-id={entry.id} in notification center
```

### `browser_permission_result`

Client reports browser notification permission result after user interaction.

```javascript
this.pushEvent("browser_permission_result", {
  permission: "granted" | "denied" | "default"
});
```

## LiveView Assigns (Socket State)

### New assigns for notification system

```elixir
# Notification center entries (max 50, FIFO)
notification_entries: [],

# Unread notification count (for bell icon badge)
notification_count: 0,

# Notification center panel visibility
show_notification_center: false,

# DND state (also in preferences, mirrored here for quick access)
dnd_enabled: false
```

### Modified assigns

```elixir
# session.user_preferences now includes :notifications key
# session.user_preferences.notifications => %{
#   sounds_enabled: true,
#   browser_notifications: false,
#   title_flash_enabled: true,
#   privacy_mode: false,
#   dnd_enabled: false,
#   trigger_mentions: true,
#   trigger_pms: true,
#   trigger_channel_messages: false,
#   trigger_joins_leaves: false,
#   channel_levels: %{}
# }
```

## PubSub Topics (unchanged)

No new PubSub topics needed. Notification routing hooks into existing PubSub event handling in ChatLive:

- `"channel:#{name}"` — channel messages, joins, leaves
- `"pm:#{sorted_ids}"` — private messages
- `"user:#{nickname}"` — user-specific events (mentions via highlight)
