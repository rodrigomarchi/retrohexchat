# Research: Channel Features Advanced

**Feature Branch**: `019-channel-features-advanced`
**Date**: 2026-02-13

## R1: Extended Role Hierarchy (owner, half-operator)

**Decision**: Extend `Channels.Membership` role type from `@type role :: :operator | :voiced | :regular` to `@type role :: :owner | :operator | :half_operator | :voiced | :regular`. Add a `rank/1` function returning integer rank for comparison.

**Rationale**: The existing role system uses atoms stored in a `%{nickname => %{role: atom(), joined_at: DateTime.t()}}` map. Adding two new atoms (`:owner`, `:half_operator`) is a minimal, backwards-compatible change. A numeric rank function (`owner=4, operator=3, half_operator=2, voiced=1, regular=0`) enables clean permission comparisons: `rank(actor_role) > rank(target_role)`.

**Alternatives considered**:
- Bitfield-based permissions: More flexible but over-engineered for 5 levels. IRC protocol uses a fixed hierarchy, not arbitrary permission sets.
- Separate `permissions` MapSet per user: Would decouple roles from permissions but adds unnecessary complexity. The IRC model is role-based, not capability-based.

## R2: Policy Module Extension for Hierarchy Enforcement

**Decision**: Extend `Channels.Policy` with rank-aware functions: `can_kick?(membership, actor, target)`, `can_ban?(membership, actor, target)`, `can_set_mode?(membership, actor, mode_flag)`. Replace the boolean `operator?/2` check in Server with rank-based checks.

**Rationale**: Currently, kick/ban only checks `operator?(membership, nickname)`. The new hierarchy requires: (1) half-ops can kick lower-ranked users but not set modes or ban, (2) operators can do everything except modify owners, (3) only owners can grant/revoke +q. A central Policy module keeps authorization logic testable and out of the Server GenServer.

**Alternatives considered**:
- Inline permission checks in Server: Would scatter authorization logic across GenServer callbacks. Policy module keeps it centralized and independently testable.

## R3: Channel Modes Expansion

**Decision**: Extend `Channels.Modes` struct to add new flag atoms and a `join_throttle` field:
- New flags: `:no_external`, `:secret`, `:private`, `:strip_colors`, `:registered_only`, `:no_knock`
- New field: `join_throttle: {count, seconds} | nil`
- Add mutual exclusivity validation for `:secret` and `:private`

**Rationale**: The existing `flags` MapSet pattern (`:moderated`, `:invite_only`, `:topic_lock`) naturally extends with new atoms. The `join_throttle` is parameterized like `key` and `limit`, so it gets its own struct field. The `@channel_flags` map needs new entries for the new mode characters.

**Alternatives considered**:
- Separate struct for advanced modes: Would fragment the mode system unnecessarily. The existing Modes struct is designed for extension.

## R4: +c Strip Colors — Message Pipeline Integration

**Decision**: Use the existing `Formatter.strip/1` function in `Channels.Server.send_message/4` when the channel has `:strip_colors` mode enabled. Strip content before persisting to DB and broadcasting.

**Rationale**: `Formatter.strip/1` already removes all IRC control codes (color \x03, bold \x02, italic \x1D, underline \x1F, reverse \x16, strikethrough \x1E, reset \x0F). Stripping server-side (before persistence) ensures: (1) all clients see stripped text, (2) stored messages are clean, (3) no client-side workaround needed. This is the same approach used by the user-level `strip_formatting` session flag, but applied at the channel level.

**Alternatives considered**:
- Client-side stripping only: Would still store colored messages in DB. Users who toggle strip_formatting off would see colors in +c channels, violating the mode's purpose.
- Stripping only in PubSub handler: Would store colored messages in DB, causing inconsistency when loading history.

## R5: +R Registered-Only — NickServ Integration

**Decision**: Check `session.identified` (or `NickServ.identified?/1` via Services.Policy) during the join flow in `Channels.Server`. The check occurs in `Policy.can_join?` as a new condition. Existing members are never ejected when +R is set.

**Rationale**: `session.identified` is already tracked in the Session struct and set to `true` when the user successfully identifies via `/ns identify`. The Server needs the `identified` status passed as a parameter to `join/3` (or a new `join/4` variant). This avoids coupling the domain Server to the web layer's Session struct.

**Alternatives considered**:
- Querying NickServ GenServer directly from Server: Would create a direct dependency between Channels and Services contexts. Passing the `identified` flag as a parameter maintains bounded context separation.

## R6: +j Join Throttle — Rate Limiting Pattern

**Decision**: Track join timestamps as a list in the Channel.Server state (field `join_timestamps: [DateTime.t()]`). On each join attempt, filter timestamps within the window, count them, and reject if at or above the limit. Operators bypass the check.

**Rationale**: The existing flood protection uses ETS-based token buckets, but join throttling is per-channel, not per-user. A simple list of timestamps in the GenServer state is appropriate because: (1) it's bounded by the throttle count (max ~50 entries), (2) it's naturally cleaned up when the window slides, (3) it dies with the process if the channel is destroyed.

**Alternatives considered**:
- ETS-based limiter like RateLimit module: Over-engineered for per-channel state that already lives in a GenServer. ETS is useful for global per-user limits, not per-channel limits.
- Separate GenServer for throttling: Unnecessary indirection when the channel GenServer already owns the state.

## R7: /knock Command — PubSub Delivery

**Decision**: Implement `/knock` as a new command handler (`Commands.Handlers.Knock`). The handler queries the channel's state via `Server.get_state/1` to validate preconditions (+i set, not +K, not banned, not already member). If valid, broadcast a `{:knock, %{nickname, channel, message}}` event to the `"channel:#{name}"` PubSub topic. The PubSub handler in ChatLive filters to show only to operators/owners.

**Rationale**: Using PubSub rather than direct GenServer call means: (1) the knock is truly transient (no state change in the channel), (2) operators online receive it in real-time, (3) offline operators don't see stale knocks. Rate limiting (1 per 60s per user per channel) is tracked in socket assigns, similar to existing CTCP rate limiting.

**Alternatives considered**:
- Storing knocks in channel GenServer state: Would add complexity for a transient notification. Knocks don't need to persist — if no operator is online, the knock is lost (standard IRC behavior).
- Direct PM to each operator: Would bypass the channel topic and not scale well with many operators.

## R8: Persistence for New Modes

**Decision**: Extend the `registered_channels` table's `modes` varchar field to include the new flag characters (n, s, p, c, R, K). Add a new column `mode_join_throttle` (varchar, nullable) to store the "count:seconds" parameter. The existing `Modes.to_string/1` and `Modes.apply_changes/3` naturally handle the new characters once the `@channel_flags` map is updated.

**Rationale**: The current persistence model stores modes as a string like "+imk" in the `modes` column. Adding new characters to this string is zero-migration for the modes column (just wider usage). The join throttle parameter needs its own column like `mode_key` and `mode_limit`.

**Alternatives considered**:
- JSONB column for all modes: Would require reworking the existing persistence layer. The current string-based approach is simple and sufficient.

## R9: Nicklist UI — New Role Groups

**Decision**: Extend the `Nicklist` component to display 5 groups instead of 3: Owners (~), Operators (@), Half-Operators (%), Voiced (+), Regular. Update the `group_users/1` function and template. Add CSS classes `nick-owner` and `nick-halfop`.

**Rationale**: The existing component groups by role atom match. Adding two new groups follows the same pattern. The template uses `:for` comprehensions that naturally accommodate new sections.

**Alternatives considered**:
- Dynamic group rendering from a role list: Could reduce template duplication but would sacrifice explicit prefix control per group. The hardcoded approach is clearer and matches the existing pattern.

## R10: `operator_in` Context — Expanding to Include Half-Ops and Owners

**Decision**: Rename `operator_in` in the handler context to keep backwards compatibility but expand its meaning: include channels where the user is `:operator` OR `:owner`. Add a new `half_operator_in` field for channels where the user is `:half_operator`. The Mode handler checks `operator_in` (which now includes owners). The Kick handler checks both `operator_in` and `half_operator_in`.

**Rationale**: The existing `operator_in` list is built in `CommandDispatch.channels_where_operator/1` by checking `session.nickname in state.operators`. Since `state.operators` currently returns only `:operator` roles, this needs to return `:owner` roles too. Adding `half_operator_in` as a separate field keeps the permission check clear: mode changes require operator+, kicks require half-op+.

**Alternatives considered**:
- Single `roles_in` map per channel: More flexible but breaks all existing handler code that pattern-matches on `operator_in`.
- Passing the full role to each handler: Would require updating every handler's context type. Too invasive.

## R11: Channel List and Whois Filtering for +s/+p

**Decision**: Modify `ChannelListLive.list_active_channels/0` to accept a `viewer_channels` parameter (list of channels the viewer is a member of). Filter out channels with `:secret` mode entirely. For `:private` mode channels, show "Prv" as name and empty topic if viewer is not a member. Modify `Whois.get_user_channels/1` to exclude `:secret` channels that the whois requester is not a member of.

**Rationale**: The channel list is currently rendered in a separate LiveView (`ChannelListLive`) that doesn't know who the viewer is. This needs a session context to filter. The whois helper already has access to the requester's session.

**Alternatives considered**:
- Filtering in the channel GenServer's `get_state/1`: Would couple visibility logic to the data access layer. Better to filter at the presentation layer where viewer context is available.
