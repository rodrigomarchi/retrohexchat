# Research: Ignore System

**Feature**: 006-ignore-system
**Date**: 2026-02-11

## R1: Domain Module Placement

**Decision**: Place IgnoreEntry and IgnoreList in `RetroHexChat.Chat` bounded context.

**Rationale**: The ignore system directly affects message display and filtering, which is a Chat concern. HighlightWords (also a message-display feature) follows the same placement. The Ecto schema goes under `Chat.Schemas` following the HighlightWordEntry pattern.

**Alternatives considered**:
- `Accounts` context — rejected because ignore is about filtering received messages, not user identity/authentication.
- `Presence` context — rejected because ignore doesn't track online/offline state; it filters content.

## R2: Timer Mechanism

**Decision**: Use `Process.send_after/3` in the LiveView process with timer refs stored in socket assigns (`ignore_timers` map).

**Rationale**: The LiveView process is the natural owner of ignore state and the recipient of timer expiry messages. `Process.send_after` is lightweight, cancellable via `Process.cancel_timer/1`, and requires no additional GenServer. Timer refs are stored separately from the domain IgnoreList to keep the domain module pure (no process-level concerns).

**Alternatives considered**:
- Dedicated GenServer per user for timers — rejected; over-engineered for per-session state.
- `:timer` module — rejected; `Process.send_after` is simpler and more idiomatic in LiveView.
- Store timers in IgnoreList struct — rejected; mixes domain logic with process-level concerns.

**Implementation pattern**:
```elixir
# In socket assigns
ignore_timers: %{}  # %{downcased_nickname => timer_ref}

# Adding a timed ignore
ref = Process.send_after(self(), {:ignore_expired, nickname}, duration_ms)
assign(socket, ignore_timers: Map.put(socket.assigns.ignore_timers, String.downcase(nickname), ref))

# Removing/updating (cancel old timer)
case Map.pop(socket.assigns.ignore_timers, String.downcase(nickname)) do
  {nil, timers} -> timers
  {old_ref, timers} -> Process.cancel_timer(old_ref); timers
end

# Timer expiry handler
def handle_info({:ignore_expired, nickname}, socket) do
  # Remove from ignore list, push system message, clean up timer map
end
```

## R3: Persistence Model

**Decision**: Follow the exact pattern of NotifyList/HighlightWords — delete-all-then-reinsert in a transaction for `save/2`, query-and-convert for `load/1`.

**Rationale**: Proven pattern used by 4 existing features. Simple, consistent, and the ignore list is small enough (max 100 entries) that bulk operations are negligible.

**Key detail for timed ignores**: The `expires_at` field is stored as `utc_datetime_usec` in PostgreSQL. On load, entries where `expires_at < DateTime.utc_now()` are filtered out. Surviving timed entries retain their original `expires_at` and the LiveView sets up new `Process.send_after` timers with the remaining duration.

**Alternatives considered**:
- Granular save_entry/delete_entry — rejected for initial implementation; can be added later if bulk save becomes a bottleneck (unlikely with max 100 entries).

## R4: Message Filtering Integration Points

**Decision**: Insert ignore checks at the top of existing `handle_info` clauses in ChatLive, before any processing (highlight check, URL capture, stream insert).

**Rationale**: Early return avoids unnecessary computation for ignored messages. The check is a simple `IgnoreList.ignored?/3` call (in-memory list scan, sub-millisecond).

**Filtering points identified**:
1. `handle_info(%{event: "new_message"}, ...)` — check `payload.author` against ignore list with type `:messages` (or `:all`). Also filters `:action` type messages with type `:actions` (or `:all`).
2. `handle_info(%{event: "new_pm"}, ...)` — check `payload.sender` against ignore list with type `:pms` (or `:all`).
3. Invite handling (future) — would check against type `:invites` (or `:all`).

**NOT filtered** (per spec FR-005):
- `:user_joined`, `:user_left`, `:nick_changed`, `:user_kicked`, `:mode_changed` — system messages always shown.

## R5: Ignore Check API Design

**Decision**: Use `IgnoreList.ignored?/3` with signature `ignored?(ignore_list, nickname, message_type)` where `message_type` is an atom (`:message | :pm | :action | :invite`).

**Rationale**: The caller passes the message type as context; the IgnoreList checks if the nickname has an entry matching that type (or `:all`). This is more flexible than separate `ignored_messages?/2`, `ignored_pms?/2` functions.

**Matching logic**:
- `:all` type matches everything
- `:messages` type matches only `:message`
- `:pms` type matches only `:pm`
- `:actions` type matches only `:action`
- `:invites` type matches only `:invite`

## R6: Dialog Design

**Decision**: Standalone `IgnoreListDialog` component (not embedded in Address Book Control tab, which is explicitly out of scope).

**Rationale**: The spec says "Ignore management within Address Book Control tab" is out of scope. A standalone dialog follows the HighlightDialog pattern — simpler to implement and test independently.

**UI pattern**: retro window with sunken-panel list table (Nickname, Type, Expires columns), Add/Remove buttons, selected row highlighting. Opened via menu bar item + Alt+I keyboard shortcut.

**Alternatives considered**:
- Address Book Control tab integration — explicitly out of scope per spec.
- MDI window — rejected; dialogs are modal, consistent with existing Highlight/Address Book dialogs.

## R7: Nick Rename Tracking

**Decision**: Follow the exact pattern of NotifyList nick rename tracking — update in-memory ignore list when `:nick_changed` broadcast is received.

**Rationale**: Existing `handle_info({:nick_changed, ...})` in ChatLive already calls `NotifyList.update_nickname/3`. Adding `IgnoreList.update_nickname/3` in the same handler is the natural extension.

**Implementation**: `IgnoreList.update_nickname(ignore_list, old_nick, new_nick)` updates the `nickname` field of matching entries (case-insensitive match on old_nick).

## R8: Command Design

**Decision**: Two separate command handlers — `Handlers.Ignore` for `/ignore` and `Handlers.Unignore` for `/unignore`.

**Rationale**: They are distinct slash commands (not subcommands of one command like `/notify add`/`/notify remove`). Each implements the Handler behaviour independently.

**Command syntax**:
- `/ignore` — list all ignores
- `/ignore <nick>` — ignore with type `all`, permanent
- `/ignore <nick> <type>` — ignore with specified type, permanent
- `/ignore <nick> <type> <duration>` — ignore with specified type and timer
- `/unignore <nick>` — remove ignore

Both handlers return `{:ok, :ui_action, action_atom, payload}` for ChatLive to process.
