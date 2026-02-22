# Web Contracts: Channel Invite System

**Feature**: 010-channel-invite-system
**Date**: 2026-02-12

## 1. LiveView Socket Assigns — ChatLive

### New Assigns (initialized in `assign_defaults/2`)

```elixir
pending_invites: [],                # list of pending invite maps
show_invite_dialog: false           # (not needed — dialogs render based on pending_invites list)
```

### Pending Invite Map Structure

```elixir
%{
  channel: String.t(),              # e.g. "#private"
  inviter: String.t(),              # e.g. "OperatorNick"
  invited_at: DateTime.t(),         # UTC timestamp
  timer_ref: reference()            # Process.send_after ref
}
```

## 2. LiveView Event Handlers — ChatLive

### handle_ui_action/3 — Invite Command Actions

```elixir
# :send_invite — Operator sends an invite
@spec handle_ui_action(Socket.t(), :send_invite, %{target: String.t(), channel: String.t()}) :: Socket.t()
defp handle_ui_action(socket, :send_invite, %{target: target, channel: channel}) do
  # 1. Validate operator is in channel and has +o
  # 2. Validate channel is invite-only (+i)
  # 3. Validate target user exists/is connected (Presence check)
  # 4. Validate target is not already in channel
  # 5. Add invite_exception via Channel.Server.add_invite_exception/3
  # 6. Broadcast {:channel_invite, payload} to "user:#{target}"
  # 7. Show confirmation system message: "* Inviting <target> to <channel>"
  # On error: show error_message with appropriate text
end

# :toggle_auto_join_on_invite — User toggles preference
@spec handle_ui_action(Socket.t(), :toggle_auto_join_on_invite, map()) :: Socket.t()
defp handle_ui_action(socket, :toggle_auto_join_on_invite, _payload) do
  # 1. Toggle session.auto_join_on_invite via Session.toggle_auto_join_on_invite/1
  # 2. Show system message confirming new state:
  #    "* Auto-join on invite: enabled" or "* Auto-join on invite: disabled"
end
```

### handle_info/2 — PubSub and Timer Messages

```elixir
# Receive invite broadcast from operator
@spec handle_info({:channel_invite, map()}, Socket.t()) :: {:noreply, Socket.t()}
def handle_info({:channel_invite, %{channel: channel, inviter: inviter}}, socket) do
  session = socket.assigns.session

  if Session.get_auto_join_on_invite(session) do
    # Auto-join path:
    # 1. Join channel via existing join flow
    # 2. Show system message: "* You have been invited to <channel> by <inviter> (auto-joined)"
    # 3. Remove invite_exception (consumed)
  else
    # Dialog path:
    # 1. Cancel existing timer for same channel (dedup — FR-020)
    # 2. Create timer_ref = Process.send_after(self(), {:invite_expired, channel}, 300_000)
    # 3. Build invite map: %{channel: channel, inviter: inviter, invited_at: DateTime.utc_now(), timer_ref: timer_ref}
    # 4. Replace or append to pending_invites (one per channel)
  end
end

# Invite expiration timer fired
@spec handle_info({:invite_expired, String.t()}, Socket.t()) :: {:noreply, Socket.t()}
def handle_info({:invite_expired, channel}, socket) do
  # 1. Find invite in pending_invites for channel
  # 2. Remove from pending_invites
  # 3. Remove invite_exception via Channel.Server.remove_invite_exception/3
  # 4. (Dialog auto-hides because invite is removed from list)
end
```

### handle_event/3 — Dialog User Actions

```elixir
# User clicks "Join" on invite dialog
@spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
def handle_event("invite_accept", %{"channel" => channel}, socket) do
  # 1. Find invite in pending_invites for channel
  # 2. If not found (expired): show error "This invitation has expired"
  # 3. Cancel the timer_ref
  # 4. Join channel via existing join flow
  # 5. Remove from pending_invites
  # 6. Remove invite_exception (consumed — one-time use)
end

# User clicks "Ignore" on invite dialog
def handle_event("invite_ignore", %{"channel" => channel}, socket) do
  # 1. Find invite in pending_invites for channel
  # 2. Cancel the timer_ref
  # 3. Remove from pending_invites
  # 4. Remove invite_exception via Channel.Server.remove_invite_exception/3
end
```

## 3. Function Component — RetroHexChatWeb.Components.InviteDialog

### Module

```elixir
defmodule RetroHexChatWeb.Components.InviteDialog do
  use Phoenix.Component

  @doc """
  Renders cascading retro-style invite dialog(s).
  Each pending invite renders as a separate dialog with CSS offset.
  """
end
```

### Attributes

```elixir
attr :pending_invites, :list, default: []
# Each item: %{channel: String.t(), inviter: String.t(), invited_at: DateTime.t(), timer_ref: reference()}
```

### Template Structure

```heex
<%= for {invite, index} <- Enum.with_index(@pending_invites) do %>
  <div
    class="dialog-overlay"
    data-testid={"invite-dialog-#{invite.channel}"}
    style={"position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: #{200 + index}; background: #{if index == 0, do: "rgba(0,0,0,0.3)", else: "transparent"};"}
  >
    <div
      class="window"
      style={"width: 320px; position: absolute; top: calc(50% - 80px + #{20 * index}px); left: calc(50% - 160px + #{20 * index}px);"}
    >
      <div class="title-bar">
        <div class="title-bar-text">Channel Invitation</div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="invite_ignore" phx-value-channel={invite.channel}></button>
        </div>
      </div>
      <div class="window-body" style="padding: 16px;">
        <p><strong><%= invite.inviter %></strong> has invited you to join <strong><%= invite.channel %></strong></p>
        <div style="display: flex; justify-content: center; gap: 8px; margin-top: 16px;">
          <button phx-click="invite_accept" phx-value-channel={invite.channel}>Join</button>
          <button phx-click="invite_ignore" phx-value-channel={invite.channel}>Ignore</button>
        </div>
      </div>
    </div>
  </div>
<% end %>
```

### Rendering in ChatLive

```heex
<RetroHexChatWeb.Components.InviteDialog.invite_dialog
  pending_invites={@pending_invites}
/>
```

## 4. Command Dispatch Context Extension

### Context Map (passed to Handler.execute/2)

```elixir
# Existing context fields used by invite handler:
context = %{
  nickname: session.nickname,          # operator's nickname
  active_channel: session.active_channel,  # current channel (fallback for /invite <nick>)
  channels: session.channels,          # channels the user is in
  identified: session.identified,      # whether user is identified
  operator_in: channels_where_operator(session)  # list of channels where user is op
}
```

No new context fields needed — the handler uses existing `active_channel` and `operator_in`.

## 5. PubSub Subscription

### Mount/Reconnect

The existing `"user:#{nickname}"` subscription in ChatLive's mount already handles user-targeted messages. No additional subscription needed — `{:channel_invite, payload}` is broadcast to this topic and received via the existing `handle_info/2` catch-all.

## 6. Test Selectors

| Selector | Element | Purpose |
|----------|---------|---------|
| `[data-testid="invite-dialog-#{channel}"]` | Dialog overlay | Target specific invite dialog |
| `button[phx-click="invite_accept"]` | Join button | Accept invite |
| `button[phx-click="invite_ignore"]` | Ignore button | Dismiss invite |
| `[data-testid="invite-dialog-#{channel}"] .title-bar-text` | Title bar | Verify dialog title |
| `[data-testid="invite-dialog-#{channel}"] .window-body` | Body text | Verify invite message |

## 7. Keyboard Handling

```elixir
# Escape key closes the topmost invite dialog (last in list)
def handle_event("window_keydown", %{"key" => "Escape"}, socket) do
  cond do
    # ... existing dialog checks first (channel central, perform, etc.)
    socket.assigns.pending_invites != [] ->
      # Ignore the most recent invite (last in list)
      last_invite = List.last(socket.assigns.pending_invites)
      # Trigger same logic as invite_ignore
    true ->
      {:noreply, socket}
  end
end
```
