# API Contracts: Web Layer

**Feature Branch**: `020-special-messages`
**Date**: 2026-02-13

## ChatLive Mount Changes

### New PubSub Subscriptions
```elixir
# In mount/3, after existing subscriptions:
Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:announcements")
Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:wallops")
Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:settings")
```

### MOTD Display on Connect
```elixir
# In mount/3, after session initialization:
# Read MOTD from cache (Motd.get/0)
# If MOTD is set, push_status_message(socket, motd_content, :motd)
```

## CommandDispatch Changes

### Context Builder
```elixir
# In build_context/1, add:
context = %{
  ...existing fields...,
  is_admin: ServerRoles.admin?(session.nickname, session.identified),
  is_server_operator: ServerRoles.server_operator?(session.nickname, session.identified)
}
```

## PubSub Handler Changes

### New Handler Module: PubSubHandlers.ServerMessages

```elixir
# Handle global announcements
@spec handle_info({:announcement, map()}, Socket.t()) :: {:noreply, Socket.t()}
# Inserts announcement into the active window's message stream.
# Uses a new message type :announcement with distinctive styling.
# Does NOT check ignore list (bypass by design).
# Displays: "[ANNOUNCEMENT] content" with bold + colored background.

# Handle wallops
@spec handle_info({:wallops, map()}, Socket.t()) :: {:noreply, Socket.t()}
# Checks Session.has_mode?(session, :wallops) first.
# If +w enabled: pushes "[Wallops] sender: content" to Status Window.
# If +w not enabled: {:noreply, socket} (silently ignore).

# Handle MOTD cache update
@spec handle_info({:motd_updated, map()}, Socket.t()) :: {:noreply, Socket.t()}
# Updates the cached MOTD in socket assigns for future /motd commands.
# No visible action to the user (just cache sync).
```

### PubSub Router Update
```elixir
# In pubsub_handlers.ex, add routing for new message types:
def handle_info({:announcement, _} = msg, socket),
  do: ServerMessages.handle_info(msg, socket)

def handle_info({:wallops, _} = msg, socket),
  do: ServerMessages.handle_info(msg, socket)

def handle_info({:motd_updated, _} = msg, socket),
  do: ServerMessages.handle_info(msg, socket)
```

## UI Action Handler Changes

### New UI Actions Module: UiActions.ServerMessages

```elixir
# Show MOTD in Status Window
@spec handle_ui_action(Socket.t(), :show_motd, map()) :: {:noreply, Socket.t()}
# Pushes MOTD content to status_messages stream with :motd type.
# If content is nil, pushes "No MOTD has been set." with :system type.

# Set welcome message
@spec handle_ui_action(Socket.t(), :set_welcome, map()) :: {:noreply, Socket.t()}
# Calls Server.set_welcome/3 with channel and message.
# Pushes confirmation system message to channel stream.

# Clear welcome message
@spec handle_ui_action(Socket.t(), :clear_welcome, map()) :: {:noreply, Socket.t()}
# Calls Server.clear_welcome/2 with channel.
# Pushes confirmation system message to channel stream.

# Set user mode
@spec handle_ui_action(Socket.t(), :set_user_mode, map()) :: {:noreply, Socket.t()}
# Parses mode_string (+w, -w, etc.)
# Updates session.user_modes via Session.set_mode/2 or Session.unset_mode/2
# Pushes confirmation to Status Window: "User mode +w enabled" or "User mode +w disabled"
```

### UiActionHandlers Router Update
```elixir
# In ui_action_handlers.ex, add delegation:
def handle_ui_action(socket, action, payload)
    when action in [:show_motd, :set_welcome, :clear_welcome, :set_user_mode],
    do: UiActions.ServerMessages.handle_ui_action(socket, action, payload)
```

## Channel Join Flow Changes

### helpers/channel.ex — join_channel/4

```elixir
# After successful Server.join and session update, BEFORE returning:
# 1. Call Server.get_welcome(channel_name)
# 2. If welcome message exists AND
#    session.nickname != welcome.set_by AND
#    NOT Session.welcomed_channel?(session, channel_name):
#      a. Insert welcome message as system message in channel stream
#      b. Update session: Session.add_welcomed_channel(session, channel_name)
```

## CSS Additions

### Message Types
```css
/* MOTD — bordered, distinctive styling in Status Window */
.status-message.motd {
  border: 2px solid var(--text-color);
  padding: 8px;
  margin: 4px 0;
  background: var(--surface);
}

.status-message.motd::before {
  content: "— Message of the Day —";
  display: block;
  text-align: center;
  font-weight: bold;
  margin-bottom: 4px;
}

/* Announcement — bold, colored background in active window */
.chat-message.announcement {
  background: #cc7700;
  color: #ffffff;
  font-weight: bold;
  padding: 4px 8px;
  border: 1px solid #ff9900;
}

/* Wallops — Status Window styling */
.status-message.wallops {
  color: var(--highlight-color);
  font-style: italic;
}
```

## Help Topics

### New Topics (in Chat.HelpTopics)

| Topic ID | Category | Title |
|----------|----------|-------|
| motd | Commands | /motd |
| setmotd | Commands | /setmotd |
| clearmotd | Commands | /clearmotd |
| setwelcome | Commands | /setwelcome |
| clearwelcome | Commands | /clearwelcome |
| wallops | Commands | /wallops |
| announce | Commands | /announce |
| umode | Commands | /umode |
| special-messages | Features | Special Messages |

### Updated Topics
- "Commands" overview topic — add new commands to the list
- "Keyboard Shortcuts" — no changes needed (no new shortcuts)
