# Research: Scripting & Aliases (Simplified)

**Feature**: 018-scripting-aliases
**Date**: 2026-02-12

## R-001: Alias Interception Point in Command Dispatch

**Decision**: Intercept alias lookup in `dispatch_command/4` in `chat_live.ex` (line 3303), BEFORE calling `Dispatcher.dispatch/3`. The alias resolution happens at the LiveView layer because aliases are per-user state stored in the Session struct — the domain-level Dispatcher has no access to user session data.

**Rationale**: The Dispatcher and Registry are compile-time, stateless modules. Aliases are user-specific runtime state. Injecting alias resolution into the Dispatcher would require threading session data through the entire command dispatch chain, violating the existing architecture where the Dispatcher is a pure function of (command_name, args, context). Instead, `dispatch_command/4` already has access to the session and is the natural interception point.

**Alternatives considered**:
- Modifying `Dispatcher.dispatch/3` to accept an alias map — rejected because it changes the public API signature and couples the stateless dispatcher to per-user state.
- Adding alias lookup to `Registry.lookup/1` — rejected because the Registry is a compile-time module attribute, not runtime-configurable.

**Implementation approach**:
1. In `dispatch_command/4`, before calling `Dispatcher.dispatch/3`, check if `command_name` matches a user alias
2. If match found, expand variables, re-parse the expansion via `Parser.parse/1`, and recursively call `dispatch_command/4`
3. Track expansion depth (max 5) to detect recursion
4. If no alias match, fall through to `Dispatcher.dispatch/3` as today

## R-002: Variable Expansion Engine

**Decision**: Create a dedicated `RetroHexChat.Chat.AliasExpander` module in the domain layer (`apps/retro_hex_chat`) for variable expansion. This module is a pure function that takes an expansion string, positional args, and context variables, and returns the expanded string.

**Rationale**: Variable expansion is used by aliases, custom menu items, auto-respond rules, and timer commands. Centralizing it in a single domain module avoids duplication and ensures consistent behavior. It belongs in the domain layer because it has zero web dependencies.

**Alternatives considered**:
- Inline expansion in each handler — rejected because of DRY violation across 4 subsystems.
- Putting expansion in the Commands context — rejected because it's not a command handler; it's a shared utility for the Chat context.

**Variable substitution rules**:
- `$1` through `$9` — positional arguments (empty string if not provided)
- `$nick` — the user's current nickname
- `$chan` — the user's active channel (empty string if nil/PM context)
- Literal `$$` — escaped to `$` (allows users to type literal dollar signs)

## R-003: Command Chaining Detection

**Decision**: Reject alias expansions containing `|`, `&&`, or `;` as command separators at save time (validation), not at execution time.

**Rationale**: Catching invalid expansions early provides a better user experience (immediate feedback) and is simpler to implement than runtime detection. The pipe `|` character is the most likely false positive since it appears in text, but since alias expansions are command strings (not prose), this restriction is reasonable.

**Edge case**: The characters are checked in the raw expansion string. A user who wants a literal pipe in a message alias like `/shrug ¯\_(ツ)_/¯ | whatever` would be blocked. This is an acceptable trade-off per the spec's security requirements. Users can work around it by not including pipes in alias text.

## R-004: Timer Implementation Strategy

**Decision**: Use `Process.send_after/3` in the LiveView process for timer scheduling, consistent with 11 existing timer patterns in `chat_live.ex`. Store timer references in a dedicated `timers` socket assign (a map of `%{name => %{ref, type, interval, command, created_at}}`).

**Rationale**: The LiveView process is already the natural home for user-scoped timers. `Process.send_after/3` is the idiomatic OTP approach, already proven at scale in this codebase. Timers automatically cancel when the LiveView process terminates (page reload/disconnect), satisfying the "session-only" requirement for free.

**Alternatives considered**:
- Dedicated GenServer per user for timers — rejected as over-engineering for max 5 timers per user.
- `:timer` module — rejected because `Process.send_after` is more idiomatic in OTP and ties timer lifecycle to the process.

**Repeat timer approach**: When a repeating timer fires, the `handle_info` callback executes the command AND schedules the next fire via another `Process.send_after/3`, storing the new ref.

## R-005: Auto-Respond Rate Limiting

**Decision**: Track rate limits in a socket assign `autorespond_cooldowns` as a map of `%{{rule_id, triggering_nick} => expiry_timestamp}`. Check before firing; clean up expired entries lazily.

**Rationale**: In-memory tracking in socket assigns is consistent with how the codebase handles similar per-session state (e.g., `notify_debounce_timers`, `ignore_timers`). No external state needed since cooldowns reset on disconnect (per spec A-006).

**Alternatives considered**:
- ETS table for cooldowns — rejected as unnecessary complexity for per-session data.
- Dedicated GenServer — rejected as over-engineering.

## R-006: Persistence Strategy (3 New Tables)

**Decision**: Create 3 new PostgreSQL tables following the established pattern:
1. `aliases` — stores user-defined aliases
2. `custom_menu_items` — stores custom popup menu items
3. `autorespond_rules` — stores auto-respond rules

Each table follows the exact pattern of existing tables (`perform_entries`, `favorites`, `contacts`): `owner_nickname` FK to `registered_nicks`, domain-specific fields, `position` for ordering, `timestamps(type: :utc_datetime_usec)`.

**Rationale**: Consistent with all 12+ existing feature tables. The "delete all then insert all" transaction pattern used by `save/2` is simple and proven. No timers table needed (session-only per spec).

## R-007: Auto-Respond Event Subscription

**Decision**: Hook into existing `handle_info` callbacks for `{:user_joined, ...}`, `{:user_left, ...}`, and `{:nick_changed, ...}` in `chat_live.ex`. After the existing processing (nicklist update, sound, system message), add auto-respond rule evaluation.

**Rationale**: These PubSub events are already received by the LiveView process. Adding auto-respond checks at the end of existing handlers is minimally invasive. No new subscriptions needed.

**Implementation**: Create a helper function `maybe_fire_autorespond(socket, event_type, event_data)` that:
1. Gets auto-respond rules from session
2. Filters rules matching the event type and channel
3. Checks rate limit cooldowns
4. Skips if the triggering nick is the user's own nick
5. Expands variables and dispatches the command

## R-008: New Session Fields

**Decision**: Add 3 new fields to the Session struct:
- `aliases: map()` — initialized with `AliasList.new()` → `%{entries: []}`
- `custom_menus: map()` — initialized with `CustomMenus.new()` → `%{entries: []}`
- `autorespond_rules: map()` — initialized with `AutoRespondRules.new()` → `%{entries: []}`

Timer state lives in socket assigns (not Session) because timers are process-level state tied to `Process.send_after` refs, not serializable user data.

**Rationale**: Follows the exact pattern of all existing feature fields (perform_list, favorites, contacts, etc.). Each gets a getter/setter pair in Session and a domain module with `new/0`, CRUD functions, `save/2`, and `load/1`.
