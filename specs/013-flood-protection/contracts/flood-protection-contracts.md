# Internal Contracts: Flood Protection (013)

**Feature**: 013-flood-protection
**Date**: 2026-02-12

This feature has no external APIs (REST, GraphQL, WebSocket endpoints). All contracts are internal Elixir module interfaces.

## Domain Module Contracts

### RetroHexChat.Chat.FloodProtection

Settings CRUD and persistence. Follows the CTCP Settings pattern.

```
new() → settings_map
  Returns: %{flood_threshold: 10, flood_window_seconds: 15, auto_ignore_duration_seconds: 300,
             spam_threshold: 3, spam_window_seconds: 10, ctcp_reply_limit: 2, ctcp_reply_window_seconds: 10}

get_flood_threshold(settings) → pos_integer
get_flood_window_seconds(settings) → pos_integer
get_auto_ignore_duration_seconds(settings) → pos_integer
get_spam_threshold(settings) → pos_integer
get_spam_window_seconds(settings) → pos_integer
get_ctcp_reply_limit(settings) → pos_integer
get_ctcp_reply_window_seconds(settings) → pos_integer

set_flood_threshold(settings, value) → settings | {:error, :invalid_value}
set_flood_window_seconds(settings, value) → settings | {:error, :invalid_value}
set_auto_ignore_duration_seconds(settings, value) → settings | {:error, :invalid_value}
set_spam_threshold(settings, value) → settings | {:error, :invalid_value}
set_spam_window_seconds(settings, value) → settings | {:error, :invalid_value}
set_ctcp_reply_limit(settings, value) → settings | {:error, :invalid_value}
set_ctcp_reply_window_seconds(settings, value) → settings | {:error, :invalid_value}

save(owner_nickname, settings) → :ok | {:error, term}
  Upserts flood protection settings for a registered user.

load(owner_nickname) → {:ok, settings_map} | {:error, :not_found}
  Loads flood protection settings from DB. Returns :not_found for unregistered or unconfigured users.
```

### RetroHexChat.Chat.FloodTracker

Per-sender message count tracking with sliding window and sender cap.

```
new() → tracker_map
  Returns: %{senders: %{}, max_senders: 50}

record_message(tracker, sender_nickname) → tracker
  Records a message from the given sender at the current monotonic time.
  Evicts oldest sender if max_senders cap is reached.

flooded?(tracker, sender_nickname, threshold, window_seconds) → boolean
  Returns true if the sender has sent >= threshold messages within the last window_seconds.

prune_expired(tracker, window_seconds) → tracker
  Removes timestamps older than window_seconds from all senders.
  Removes senders with no remaining timestamps.

reset_sender(tracker, sender_nickname) → tracker
  Removes all tracking data for a specific sender.
```

### RetroHexChat.Chat.DuplicateTracker

Per-sender-target duplicate message detection.

```
new() → tracker_map
  Returns: %{entries: %{}, max_senders: 50}

record_message(tracker, sender, target_key, content) → tracker
  Records a message with its content for the sender-target pair.
  target_key: {:channel, channel_name} | {:pm, sender_nick}

duplicate_count(tracker, sender, target_key, content, window_seconds) → non_neg_integer
  Returns the number of times the exact same content has been sent by this sender
  to this target within the last window_seconds.

is_duplicate?(tracker, sender, target_key, content, threshold, window_seconds) → boolean
  Returns true if duplicate_count >= threshold.

prune_expired(tracker, window_seconds) → tracker
  Removes entries older than window_seconds.
```

### Auto-Ignore State (socket assigns helper functions in ChatLive)

```
init_auto_ignore_state() → state_map
  Returns: %{active: %{}, cooldowns: %{}}

auto_ignore_active?(state, sender_nickname) → boolean
  Returns true if the sender is currently auto-ignored.

cooldown_active?(state, sender_nickname) → boolean
  Returns true if removing the sender's auto-ignore recently triggered a cooldown.

record_auto_ignore(state, sender_nickname, timer_ref, expires_at) → state
  Records an auto-ignore entry with its timer reference.

remove_auto_ignore(state, sender_nickname) → state
  Removes the auto-ignore tracking for a sender (timer must be cancelled separately).

add_cooldown(state, sender_nickname, duration_ms) → state
  Adds a cooldown entry that expires after duration_ms.

cleanup_expired_cooldowns(state) → state
  Removes cooldown entries whose time has passed.
```

## Session Integration Contract

### RetroHexChat.Accounts.Session (additions)

```
get_flood_protection(session) → settings_map
set_flood_protection(session, settings_map) → session
```

## ChatLive Event Contracts

### Dialog Events (phx-click / phx-submit)

| Event | Params | Action |
|-------|--------|--------|
| `open_flood_protection_dialog` | none | Show dialog, assign `show_flood_protection_dialog: true` |
| `close_flood_protection_dialog` | none | Hide dialog, assign `show_flood_protection_dialog: false` |
| `flood_save_settings` | form params (all threshold fields as strings) | Parse, validate, update session, persist if identified, close dialog |
| `flood_reset_defaults` | none | Reset all settings to defaults, update session, persist if identified |

### Timer Messages (handle_info)

| Message | Action |
|---------|--------|
| `{:auto_ignore_expired, sender_nickname}` | Remove auto-ignore from ignore list, remove from auto_ignore_state, display system message |

## Component Contract

### RetroHexChatWeb.Components.FloodProtectionDialog

```
flood_protection_dialog(assigns)
  Required attrs:
    visible: boolean
    flood_protection: map (settings from session)
```

## Help System Contract

### New Help Topics

| Topic ID | Title | Category | Keywords |
|----------|-------|----------|----------|
| `feature-flood-protection` | Flood Protection | Features | flood, spam, duplicate, auto-ignore, protection, anti-spam |

### Updated Help Topics (cross-references)

| Topic ID | Addition |
|----------|----------|
| `feature-ignore` | See Also: link to `feature-flood-protection` |
| `feature-ctcp` | See Also: link to `feature-flood-protection` |
