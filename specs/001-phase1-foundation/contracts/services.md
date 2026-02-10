# Services Contracts: NickServ & ChanServ

**Date**: 2026-02-09
**Context**: RetroHexChat Phase 1 — NickServ + ChanServ internal services

---

## NickServ GenServer Contract

```elixir
defmodule RetroHexChat.Services.NickServ do
  @moduledoc """
  GenServer managing nickname registration and protection.
  Started as a named singleton in the supervision tree.
  """

  @doc "Register the current nickname with a password"
  @spec register(nickname :: String.t(), password :: String.t()) ::
    {:ok, :registered} | {:error, String.t()}

  @doc "Identify as the owner of a registered nickname"
  @spec identify(nickname :: String.t(), password :: String.t()) ::
    {:ok, :identified} | {:error, String.t()}

  @doc "Disconnect a ghost session using the registered nickname"
  @spec ghost(nickname :: String.t(), password :: String.t()) ::
    {:ok, :ghosted} | {:error, String.t()}

  @doc "Get info about a registered nickname"
  @spec info(nickname :: String.t()) ::
    {:ok, map()} | {:error, :not_registered}

  @doc "Remove the registration of the current nickname"
  @spec drop(nickname :: String.t()) ::
    {:ok, :dropped} | {:error, String.t()}

  @doc "Check if a nickname is registered"
  @spec registered?(nickname :: String.t()) :: boolean()

  @doc "Start the 60-second identify timer for a user"
  @spec start_identify_timer(nickname :: String.t()) :: :ok

  @doc "Cancel the identify timer (user identified in time)"
  @spec cancel_identify_timer(nickname :: String.t()) :: :ok
end
```

### 60-Second Identify Timer Design

When a user connects with a registered nickname, the following sequence
executes:

```text
1. User connects as "Rodrigo"
2. System checks: is "Rodrigo" registered? → YES
3. NickServ.start_identify_timer("Rodrigo") is called
4. NickServ sends message to user via PubSub "user:Rodrigo":
   "[NickServ] This nickname is registered. You have 60 seconds
   to identify via /ns identify <password> or you will be renamed."
5. Timer starts via Process.send_after(self(), {:identify_timeout,
   "Rodrigo"}, 60_000)
6. NickServ tracks active timers in GenServer state:
   %{identify_timers: %{"Rodrigo" => timer_ref}}

   Path A — User identifies in time:
   7a. User types /ns identify <correct_password>
   8a. NickServ.identify("Rodrigo", password) → {:ok, :identified}
   9a. NickServ.cancel_identify_timer("Rodrigo") →
       Process.cancel_timer(timer_ref), remove from state
   10a. NickServ sends: "[NickServ] You are now identified as Rodrigo."

   Path B — Timer expires:
   7b. GenServer receives {:identify_timeout, "Rodrigo"}
   8b. NickServ checks: is "Rodrigo" still connected AND not identified?
   9b. If yes → generate Guest_XXXXX nickname:
       - Generate random 5 digits
       - Check uniqueness against connected users
       - If taken, retry (max 10 attempts, then Guest_XXXXXXXXXX with 10 digits)
   10b. Broadcast force_rename via PubSub "user:Rodrigo":
        %{event: "force_rename", payload: %{
          old_nick: "Rodrigo",
          new_nick: "Guest_12345",
          reason: "NickServ identification timeout"
        }}
   11b. NickServ sends: "[NickServ] You did not identify in time.
        Your nickname has been changed to Guest_12345."

   Path C — User disconnects before timer:
   7c. Socket disconnect triggers cleanup (FR-073)
   8c. Cleanup calls NickServ.cancel_identify_timer("Rodrigo")
   9c. Timer cancelled, no further action
```

### Race Condition Handling (Edge Case: identify at second 59.9)

The NickServ GenServer serializes all operations. Both `identify/2` and
the `{:identify_timeout, nickname}` message arrive in the GenServer
mailbox sequentially. Whichever arrives first wins:

- If `identify` arrives first: timer is cancelled, timeout message is
  ignored (timer ref already removed from state).
- If timeout arrives first: user is renamed, subsequent `identify` call
  fails with `{:error, "You are no longer using this nickname"}`.

No additional locking or CAS operations needed — the GenServer mailbox
is the synchronization mechanism.

---

## ChanServ GenServer Contract

```elixir
defmodule RetroHexChat.Services.ChanServ do
  @moduledoc """
  GenServer managing channel registration and access lists.
  Started as a named singleton in the supervision tree.
  """

  @doc "Register a channel (requires identified user)"
  @spec register(channel :: String.t(), founder :: String.t()) ::
    {:ok, :registered} | {:error, String.t()}

  @doc "Drop (unregister) a channel"
  @spec drop(channel :: String.t(), requester :: String.t()) ::
    {:ok, :dropped} | {:error, String.t()}

  @doc "Grant temporary operator status"
  @spec op(channel :: String.t(), nickname :: String.t(), requester :: String.t()) ::
    :ok | {:error, String.t()}

  @doc "Revoke temporary operator status"
  @spec deop(channel :: String.t(), nickname :: String.t(), requester :: String.t()) ::
    :ok | {:error, String.t()}

  @doc "Grant temporary voice status"
  @spec voice(channel :: String.t(), nickname :: String.t(), requester :: String.t()) ::
    :ok | {:error, String.t()}

  @doc "Revoke temporary voice status"
  @spec devoice(channel :: String.t(), nickname :: String.t(), requester :: String.t()) ::
    :ok | {:error, String.t()}

  @doc "Get info about a registered channel"
  @spec info(channel :: String.t()) ::
    {:ok, map()} | {:error, :not_registered}

  @doc "Add/remove/list access list entries"
  @spec manage_access(
    channel :: String.t(),
    level :: :sop | :aop | :vop,
    action :: :add | :del | :list,
    nickname :: String.t() | nil,
    requester :: String.t()
  ) :: {:ok, any()} | {:error, String.t()}

  @doc "Check access list and return the privilege level for a user"
  @spec check_access(channel :: String.t(), nickname :: String.t()) ::
    {:ok, :founder | :sop | :aop | :vop} | {:error, :no_access}
end
```

### Auto-Privilege on Join Sequence (FR-051)

When a user joins a ChanServ-registered channel, the Channel GenServer
coordinates with ChanServ to apply automatic privileges:

```text
1. User sends /join #elixir
2. Channels.Server receives join request
3. Server checks: is #elixir registered? → YES
4. Server checks: is user identified with NickServ? → YES/NO

   If NOT identified:
   5a. User joins as regular member. No auto-privilege.
       ChanServ sends no message.

   If identified:
   5b. Server calls ChanServ.check_access("#elixir", "Rodrigo")
   6b. ChanServ queries access_list_entries for (channel, nickname)
   7b. Returns {:ok, :founder} | {:ok, :sop} | {:ok, :aop} | {:ok, :vop}
       | {:error, :no_access}

   8b. Based on access level:
       - :founder → apply :operator, broadcast mode +o
       - :sop     → apply :operator, broadcast mode +o
       - :aop     → apply :operator, broadcast mode +o
       - :vop     → apply :voiced, broadcast mode +v
       - :no_access → join as regular, no privilege

   9b. ChanServ sends service message to user:
       "[ChanServ] You have been granted operator status in #elixir."
       or "[ChanServ] You have been granted voice in #elixir."
```

### Hierarchical Permission Enforcement

Access list operations enforce a strict hierarchy:

```text
Founder > SOP > AOP > VOP

Permission matrix for /cs access list management:

Action                    | Required Level
--------------------------|---------------
sop add/del               | Founder only
aop add/del               | Founder or SOP
vop add/del               | Founder, SOP, or AOP
sop/aop/vop list          | Any channel member
register                  | Identified user (not in channel access list yet)
drop                      | Founder only
op/deop (temporary)       | Founder, SOP, or current operator
voice/devoice (temporary) | Founder, SOP, AOP, or current operator
info                      | Anyone
```

---

## Socket Disconnect Cleanup Sequence (FR-073/074)

When a LiveView socket disconnects (browser close, network loss, etc.),
the `ChatLive.terminate/2` callback executes the following cleanup:

```text
1. LiveView.terminate/2 fires with socket assigns
2. Extract nickname and channels list from assigns

3. Cancel NickServ identify timer (if active):
   NickServ.cancel_identify_timer(nickname)

4. For each channel the user was in:
   a. Channels.Server.part(channel, nickname, "Connection lost")
   b. Server removes user from membership
   c. Server broadcasts via PubSub "channel:#{name}":
      %{event: "user_left", payload: %{nickname, channel, message: "Connection lost"}}
   d. Server persists system message: "* User has quit (Connection lost)"
   e. If last user in unregistered channel → terminate channel process

5. Remove from Phoenix Presence:
   Presence.untrack(nickname)

6. Release nickname:
   (Nickname becomes immediately available for new connections)

7. Broadcast quit to user-scoped topic:
   PubSub.broadcast("user:#{nickname}", %{event: "user_quit"})
```

**Ordering matters**: NickServ timer cancellation MUST happen before
channel parts (to prevent timer firing during cleanup). Channel parts
MUST happen before Presence untrack (Presence is the source of truth
for the nicklist — removing presence first would cause UI flicker
before the part messages arrive).
