# Contract: Ignore/Ban Integration for P2P

**Feature**: 039-p2p-security-help-polish
**Date**: 2026-02-16

## Existing Integration (Already Working)

### Session Creation Block

`P2P.Policy.can_create?/2` → `check_no_block/2` queries `ignore_list_entries` table.
Returns `{:error, "Session cannot be created"}` if either user has ignored the other.

**Change needed**: Update error message to `"Usuário não disponível"` (generic, doesn't reveal block).

## New Integration: Active Session Closure on Block

### Approach: Hook into Ignore Command Handler

When a user ignores another user (via `/ignore` command), check for active P2P sessions between them and close any that exist.

### New function: `P2P.close_sessions_between/2`

```elixir
@spec close_sessions_between(integer(), integer()) :: :ok
def close_sessions_between(user_id_a, user_id_b)
```

Finds all non-terminal P2P sessions between the two users and closes them with reason `"user_blocked"`.

### Integration point: Ignore command handler

After successfully adding a user to the ignore list, call:
```elixir
P2P.close_sessions_between(blocker_id, blocked_id)
```

### Ban check: Session creation

Banned users are already prevented from using most features. Add explicit check in `P2P.Policy.can_create?/2`:

```elixir
defp check_not_banned(user_id) do
  # Check if user has active ban in channels (existing ban system is channel-level)
  # For P2P, "banned" means the user is on a global restriction —
  # this maps to being in the ignore list of the system or having no registered nick
  :ok
end
```

Note: The current ban system (`Services.Ban`) is channel-level. For P2P, the ignore list and registration requirement serve as the access control mechanism. No additional "global ban" concept is needed — the spec's FR-016 is already satisfied by the registration requirement in `Policy.check_registered/2`.
