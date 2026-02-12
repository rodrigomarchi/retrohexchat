# Quickstart: Channel Invite System

**Feature**: 010-channel-invite-system
**Date**: 2026-02-12

## Prerequisites

- Branch `010-channel-invite-system` checked out
- `make setup` completed (no new migrations for this feature)
- Familiarity with: Command handlers (`/ban`, `/kick`), Channel.Server, Session struct, 98.css dialog components

## Implementation Order

Follow this sequence — each step builds on the previous.

### Step 1: Session Extension

**File**: `apps/retro_hex_chat/lib/retro_hex_chat/accounts/session.ex`

Add `auto_join_on_invite: false` to the struct definition and create three functions:

```elixir
# In defstruct list, add:
auto_join_on_invite: false

# In @type t, add:
auto_join_on_invite: boolean()

# New functions:
def get_auto_join_on_invite(%__MODULE__{auto_join_on_invite: value}), do: value
def set_auto_join_on_invite(%__MODULE__{} = session, value) when is_boolean(value), do: %{session | auto_join_on_invite: value}
def toggle_auto_join_on_invite(%__MODULE__{auto_join_on_invite: current} = session), do: %{session | auto_join_on_invite: not current}
```

**Test**: `test/retro_hex_chat/accounts/session_test.exs` — add tests for get/set/toggle.

**Verify**: `mix test test/retro_hex_chat/accounts/session_test.exs`

---

### Step 2: Invite Command Handler

**File**: `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/invite.ex` (NEW)

Follow the same pattern as `handlers/ban.ex` or `handlers/kick.ex`:

```elixir
defmodule RetroHexChat.Commands.Handlers.Invite do
  @behaviour RetroHexChat.Commands.Handler

  @impl true
  def validate(_args), do: :ok

  @impl true
  def execute([], _context), do: {:error, "Usage: /invite <nickname> [#channel]"}
  def execute(["auto"], _context), do: {:ok, :ui_action, :toggle_auto_join_on_invite, %{}}
  def execute([nickname], context), do: # use active_channel
  def execute([nickname, channel], _context), do: # use specified channel

  @impl true
  def help, do: %{name: "invite", syntax: "/invite <nickname> [#channel]", ...}
end
```

Key validations in execute:
- `require_channel/1` — operator must have an active channel (or channel specified)
- Return `{:ok, :ui_action, :send_invite, %{target: nickname, channel: channel}}`

**Test**: `test/retro_hex_chat/commands/handlers/invite_test.exs` (NEW) — test all execute clauses.

**Verify**: `mix test test/retro_hex_chat/commands/handlers/invite_test.exs`

---

### Step 3: Register Command

**File**: `apps/retro_hex_chat/lib/retro_hex_chat/commands/registry.ex`

Add to `@commands` map:

```elixir
"invite" => RetroHexChat.Commands.Handlers.Invite
```

**Test**: `test/retro_hex_chat/commands/registry_test.exs` — add `"invite"` to lookup test.

**Verify**: `mix test test/retro_hex_chat/commands/registry_test.exs`

---

### Step 4: Invite Dialog Component

**File**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/invite_dialog.ex` (NEW)

Follow the `perform_dialog.ex` pattern:

```elixir
defmodule RetroHexChatWeb.Components.InviteDialog do
  use Phoenix.Component

  attr :pending_invites, :list, default: []

  def invite_dialog(assigns) do
    ~H"""
    <%= for {invite, index} <- Enum.with_index(@pending_invites) do %>
      <!-- Win98 dialog with cascading offset -->
    <% end %>
    """
  end
end
```

CSS cascade: `top: calc(50% - 80px + #{20 * index}px); left: calc(50% - 160px + #{20 * index}px)`

**Verify**: Visual inspection via `make server` (after Step 5 integration).

---

### Step 5: ChatLive Integration

**File**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.ex`

#### 5a. Initialize assigns

In `assign_defaults/2`, add:

```elixir
pending_invites: []
```

#### 5b. Handle UI actions from command handler

Add to `handle_ui_action/3`:

```elixir
defp handle_ui_action(socket, :send_invite, %{target: target, channel: channel}) do
  # Validate: operator in channel, channel is +i, target exists, target not in channel
  # Channel.Server.add_invite_exception(channel, nickname, target)
  # Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "user:#{target}", {:channel_invite, %{channel: channel, inviter: nickname}})
  # Show system message: "* Inviting #{target} to #{channel}"
end

defp handle_ui_action(socket, :toggle_auto_join_on_invite, _payload) do
  # Session.toggle_auto_join_on_invite(session)
  # Show confirmation message
end
```

#### 5c. Handle incoming invite PubSub

```elixir
def handle_info({:channel_invite, %{channel: channel, inviter: inviter}}, socket) do
  # If auto-join: join channel, show system message
  # Else: add to pending_invites with timer, show dialog
end
```

#### 5d. Handle expiration timer

```elixir
def handle_info({:invite_expired, channel}, socket) do
  # Remove from pending_invites, remove invite_exception
end
```

#### 5e. Handle dialog button clicks

```elixir
def handle_event("invite_accept", %{"channel" => channel}, socket) do
  # Join channel, cancel timer, remove from pending_invites, remove exception
end

def handle_event("invite_ignore", %{"channel" => channel}, socket) do
  # Cancel timer, remove from pending_invites, remove exception
end
```

#### 5f. Render dialog

In `render/1`, add the component:

```heex
<RetroHexChatWeb.Components.InviteDialog.invite_dialog
  pending_invites={@pending_invites}
/>
```

#### 5g. Escape key handling

Add `pending_invites != []` check to existing Escape handler.

**Test**: `test/retro_hex_chat_web/live/chat_live_invite_test.exs` (NEW) — test dialog rendering, Join/Ignore clicks, expiration, auto-join.

**Verify**: `mix test test/retro_hex_chat_web/live/chat_live_invite_test.exs`

---

### Step 6: Help Topics

**File**: `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`

Add two new topics:

1. `"cmd-invite"` — Commands category, syntax and examples for `/invite`
2. `"feature-channel-invites"` — Features category, overview of invite system and auto-join

Update "See Also" in:
- `"cmd-join"` — add link to `"cmd-invite"`
- `"mode-i"` (if exists) — add link to `"cmd-invite"` and `"feature-channel-invites"`

**Test**: Existing help topic tests should cover structure. Add specific entries if needed.

**Verify**: `mix test test/retro_hex_chat/chat/help_topics_test.exs`

---

### Step 7: Full Integration Test

Run the full test suite:

```bash
make test
make lint
```

Manual smoke test:
1. Start server: `make server`
2. Open two browser tabs as different users
3. Create a channel, set +i mode
4. As operator, type `/invite OtherUser`
5. Verify OtherUser sees the dialog
6. Click Join — verify OtherUser enters the channel
7. Test Ignore flow
8. Test expiration (wait 5 minutes or adjust timer for testing)
9. Test `/invite auto` toggle

## Key Patterns to Follow

| Pattern | Reference File | What to Copy |
|---------|---------------|--------------|
| Command handler structure | `handlers/ban.ex` | `validate/1`, `execute/2`, `help/0`, `require_channel/1` |
| Registry entry | `registry.ex` | Add `"invite" => Handlers.Invite` to `@commands` |
| Session getter/setter | `session.ex` | `get_/set_/toggle_` function naming |
| Dialog component | `perform_dialog.ex` | 98.css `.window` structure, overlay, z-index |
| UI action dispatch | `chat_live.ex` | `handle_ui_action/3` clause pattern |
| PubSub broadcast | `chat_live.ex` | `"user:#{nickname}"` topic pattern |
| System messages | `chat_live.ex` | `system_message/1`, `error_message/1` helpers |
| Help topics | `help_topics.ex` | Topic map structure with id, title, category, keywords, content |

## No Database Changes

This feature is entirely in-memory. No migrations, no schema changes, no Ecto queries.
