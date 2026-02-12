# Domain Contracts: Channel Invite System

**Feature**: 010-channel-invite-system
**Date**: 2026-02-12

## 1. Command Handler — RetroHexChat.Commands.Handlers.Invite

Implements `RetroHexChat.Commands.Handler` behaviour.

### validate/1

```elixir
@spec validate(String.t()) :: :ok | {:error, String.t()}
```

Always returns `:ok` — validation is deferred to `execute/2` where context is available.

### execute/2

```elixir
@spec execute([String.t()], Handler.context()) :: Handler.result()

# /invite (no args) — show usage
execute([], _context)
# => {:error, "Usage: /invite <nickname> [#channel]"}

# /invite auto — toggle auto-join preference
execute(["auto"], _context)
# => {:ok, :ui_action, :toggle_auto_join_on_invite, %{}}

# /invite <nickname> — invite to active channel
execute([nickname], context)
# => {:ok, :ui_action, :send_invite, %{target: nickname, channel: active_channel}}
# => {:error, "You are not in any channel"} if no active channel

# /invite <nickname> #channel — invite to specific channel
execute([nickname, channel], context)
# => {:ok, :ui_action, :send_invite, %{target: nickname, channel: channel}}
```

### help/0

```elixir
@spec help() :: %{name: String.t(), syntax: String.t(), description: String.t(), examples: [String.t()]}
# => %{
#   name: "invite",
#   syntax: "/invite <nickname> [#channel]",
#   description: "Invite a user to an invite-only (+i) channel",
#   examples: ["/invite Alice", "/invite Alice #private", "/invite auto"]
# }
```

### Private Helpers

```elixir
# Checks operator has active channel
@spec require_channel(Handler.context()) :: {:ok, String.t()} | {:error, String.t()}
defp require_channel(%{active_channel: nil}), do: {:error, "You are not in any channel"}
defp require_channel(%{active_channel: channel}), do: {:ok, channel}

# Checks operator status in channel
@spec require_operator(Handler.context(), String.t()) :: :ok | {:error, String.t()}
defp require_operator(%{operator_in: operator_in}, channel)
```

## 2. Command Registry — RetroHexChat.Commands.Registry

### Modification

Add entry to `@commands` map:

```elixir
"invite" => RetroHexChat.Commands.Handlers.Invite
```

## 3. Session Extension — RetroHexChat.Accounts.Session

### New Field

```elixir
@type t :: %__MODULE__{
  # ... existing fields ...
  auto_join_on_invite: boolean()
}

defstruct [
  # ... existing fields ...
  auto_join_on_invite: false
]
```

### New Functions

```elixir
@spec get_auto_join_on_invite(t()) :: boolean()
def get_auto_join_on_invite(%__MODULE__{auto_join_on_invite: value}), do: value

@spec set_auto_join_on_invite(t(), boolean()) :: t()
def set_auto_join_on_invite(%__MODULE__{} = session, value) when is_boolean(value) do
  %{session | auto_join_on_invite: value}
end

@spec toggle_auto_join_on_invite(t()) :: t()
def toggle_auto_join_on_invite(%__MODULE__{auto_join_on_invite: current} = session) do
  %{session | auto_join_on_invite: not current}
end
```

## 4. Channel.Server — Existing API Used

No new functions needed. The following existing functions are called:

```elixir
# Add temporary invite exception (already exists)
@spec add_invite_exception(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
Channel.Server.add_invite_exception(channel_name, operator_nickname, invitee_nickname)

# Remove temporary invite exception (already exists)
@spec remove_invite_exception(String.t(), String.t(), String.t()) :: :ok | {:error, String.t()}
Channel.Server.remove_invite_exception(channel_name, operator_nickname, invitee_nickname)

# Check if channel is invite-only (already exists via Modes)
# Used indirectly through Channel.Server.get_modes/1 or Channel.Server.info/1
```

## 5. PubSub Messages

### Outgoing (from operator's ChatLive)

```elixir
Phoenix.PubSub.broadcast(
  RetroHexChat.PubSub,
  "user:#{invitee_nickname}",
  {:channel_invite, %{
    channel: channel_name,
    inviter: operator_nickname
  }}
)
```

### Incoming (to invitee's ChatLive)

```elixir
def handle_info({:channel_invite, %{channel: channel, inviter: inviter}}, socket) do
  # Check auto-join preference
  # If auto-join: join channel immediately, show system message
  # If not auto-join: add to pending_invites, start expiration timer, show dialog
end
```

### Expiration (self-sent timer)

```elixir
# Scheduled via:
timer_ref = Process.send_after(self(), {:invite_expired, channel_name}, 300_000)

# Handled via:
def handle_info({:invite_expired, channel_name}, socket) do
  # Remove from pending_invites
  # Remove from invite_exceptions
  # Update dialog state (show expired if still visible)
end
```

## 6. Help Topics — RetroHexChat.Chat.HelpTopics

### New Topics

```elixir
# cmd-invite topic
%{
  id: "cmd-invite",
  title: "/invite",
  category: "Commands",
  keywords: ["invite", "channel", "invite-only", "private"],
  content: "..." # HTML: syntax, description, examples, see also
}

# feature-channel-invites topic
%{
  id: "feature-channel-invites",
  title: "Channel Invites",
  category: "Features",
  keywords: ["invite", "invite-only", "private channel", "auto-join"],
  content: "..." # HTML: overview of invite system, auto-join preference
}
```

### Updated Topics (See Also additions)

- `cmd-join`: Add see also link to `cmd-invite`
- `mode-i` (if exists): Add see also link to `cmd-invite` and `feature-channel-invites`
