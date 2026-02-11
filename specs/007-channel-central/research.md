# Research: Channel Central Dialog

**Feature Branch**: `007-channel-central`
**Date**: 2026-02-11

## R1: Topic Metadata Tracking

**Decision**: Extend Server GenServer state with `topic_set_by` and `topic_set_at` fields.

**Rationale**: The current server state stores `topic: String.t()` with no metadata about who set it or when. The Channel Central dialog requires this information (FR-004). Since `set_topic/3` already receives the `nickname` parameter, we just need to store it alongside a timestamp.

**Alternatives considered**:
- Querying chat message history for topic change system messages — rejected because it couples UI to message storage and is fragile.
- Storing topic metadata in a separate DB table — rejected as over-engineering; topic metadata is ephemeral runtime state that resets when the channel process restarts (same as the topic itself for unregistered channels).

**Implementation**: Add `topic_set_by: String.t() | nil` and `topic_set_at: DateTime.t() | nil` to the server state map. Update `set_topic` handler to populate these fields. Expose them via `get_state/1`. For registered channels, persist `topic_set_by` and `topic_set_at` in `load_persisted_state`.

---

## R2: Ban Exception (+e) Storage

**Decision**: Use a separate `ban_exceptions` database table and a `MapSet.t(String.t())` in Server GenServer state, following the existing ban persistence pattern.

**Rationale**: Ban exceptions are channel-scoped (not user-scoped like ignore lists). They should persist across channel restarts for registered channels. The existing `bans` table pattern (channel_name + nickname + metadata) is the natural model.

**Alternatives considered**:
- Adding an `exception` boolean column to the existing `bans` table — rejected because exceptions and bans are semantically different (a ban blocks, an exception allows). Mixing them in one table would create confusing queries and violate single-responsibility.
- In-memory only (no persistence) — rejected because exception lists should survive channel restarts for registered channels.
- Single `channel_exceptions` table with a `type` column (ban/invite) — considered viable but rejected in favor of separate tables for cleaner queries and independent evolution.

**Implementation**: New `ban_exceptions` table with fields: `channel_name`, `nickname`, `added_by`, `inserted_at`. In-memory: `ban_exceptions: MapSet.t(String.t())` in Server state. Loaded during `load_persisted_state/1`.

---

## R3: Invite Exception (+I) Storage

**Decision**: Use a separate `invite_exceptions` database table and a `MapSet.t(String.t())` in Server GenServer state, mirroring ban exception pattern.

**Rationale**: Same reasoning as R2. Invite exceptions are channel-scoped and need persistence for registered channels. Separate table from ban exceptions because they serve different purposes and are checked at different points in the join flow.

**Implementation**: New `invite_exceptions` table with fields: `channel_name`, `nickname`, `added_by`, `inserted_at`. In-memory: `invite_exceptions: MapSet.t(String.t())` in Server state. Checked in `Policy.can_join?/4`.

---

## R4: Policy Extension for Exception Bypass

**Decision**: Extend `Policy.can_join?/4` to accept and check exception lists before rejecting for bans or invite-only.

**Rationale**: Currently `can_join?` takes `(modes, membership, password, max_channels)`. To support exceptions, the function signature needs to accept ban exceptions and invite exceptions. The check order should be:
1. Check limit (+l) — exceptions don't bypass capacity limits
2. Check invite-only (+i) — bypass if user is in invite exceptions
3. Check ban — bypass if user is in ban exceptions
4. Check key (+k) — exceptions don't bypass key requirement

**Alternatives considered**:
- Checking exceptions in Server.join handler instead of Policy — rejected because join validation belongs in Policy (single responsibility, testable in isolation).
- Adding a separate `can_bypass?` function — rejected as unnecessary indirection; the logic is simple enough to integrate into the existing `can_join?` flow.

**Implementation**: Change `can_join?` signature to accept `ban_exceptions` and `invite_exceptions` MapSets. Update Server.join to pass them. Add ban check (currently only in Server handler, not in Policy) to Policy for consistency.

---

## R5: Treebar Interaction for Channel Central

**Decision**: Add `phx-dblclick` event on channel items in the treebar, and add "Channel Central" to the channel context menu.

**Rationale**: The treebar currently only handles `phx-click="switch_channel"`. Double-click is a natural gesture for "open properties" in the Windows 98 paradigm. The context menu provides discoverability. There is currently no right-click context menu on channel names in the treebar (only on nicknames in the nicklist).

**Alternatives considered**:
- Adding a "Properties" button to the topic bar — rejected because it doesn't follow mIRC convention.
- Only using the menu bar (Tools > Channel Central) — insufficient; double-click is the primary expected interaction.
- Using a dedicated toolbar button — could be added later but not the primary entry point.

**Implementation**: Add `phx-dblclick="open_channel_central"` with `phx-value-channel` to treebar channel `<li>` elements. Add a context menu for channels (similar to nick context menu pattern). Add "Channel Central" as first item.

---

## R6: Dialog Layout Approach

**Decision**: Use a single-window dialog with tabbed sections (98.css tab control), not a scrollable single page.

**Rationale**: mIRC's Channel Central dialog uses a tabbed interface. With six sections (Info, Topic, Modes, Bans, Ban Exceptions, Invite Exceptions), a single scrollable page would be overwhelming. Tabs match the Windows 98 aesthetic and allow each section to use the full dialog area. The AddressBookDialog already implements a 4-tab pattern we can follow.

**Tabs**:
1. **General** — Info + Topic (combined, as they're both lightweight)
2. **Modes** — All channel mode checkboxes with key/limit inputs
3. **Bans** — Ban list with add/remove
4. **Ban Exceptions** — Ban exception list with add/remove
5. **Invite Exceptions** — Invite exception list with add/remove

**Alternatives considered**:
- Six tabs (one per section) — rejected because Info and Topic are small enough to share a tab, and too many tabs clutters the tab bar.
- Accordion/expandable fieldsets — rejected because it doesn't match the Windows 98 tabbed dialog convention.

---

## R7: Keyboard Shortcut

**Decision**: Use no dedicated keyboard shortcut for Channel Central. Access via double-click, context menu, and menu bar only.

**Rationale**: The existing shortcuts (Alt+B, Alt+H, Alt+I, Alt+U, F1) cover the most frequent operations. Channel Central is a per-channel operation (requires knowing which channel), making a global shortcut awkward — it would only work for the currently active channel. Double-click is faster for operators who use it frequently.

**Alternatives considered**:
- Alt+C — could conflict with future features; also, global shortcut for a per-channel dialog feels wrong.
- Ctrl+Enter on channel name — non-standard and undiscoverable.

---

## R8: Real-Time Update Strategy

**Decision**: Reuse existing PubSub subscriptions. ChatLive already subscribes to `"channel:#{name}"` for all joined channels. When Channel Central is open, the existing `handle_info` handlers for `:mode_changed`, `:topic_changed`, `:user_banned`, `:user_joined`, `:user_left` will update the relevant assigns, and the dialog component will re-render automatically.

**Rationale**: No new subscriptions needed. LiveView's reactive rendering means updating assigns (like `current_modes`, `current_topic`, channel user list) will automatically re-render the Channel Central component that reads those assigns. Exception list changes will need new broadcast events.

**New broadcasts needed**:
- `{:ban_exception_added, %{channel: name, nickname: nick, added_by: op}}`
- `{:ban_exception_removed, %{channel: name, nickname: nick, removed_by: op}}`
- `{:invite_exception_added, %{channel: name, nickname: nick, added_by: op}}`
- `{:invite_exception_removed, %{channel: name, nickname: nick, removed_by: op}}`

---

## R9: Server.get_state Enrichment

**Decision**: Extend `state_to_map/1` in Server to return structured data instead of just a mode string, plus new fields for exceptions and topic metadata.

**Rationale**: Currently `get_state` returns `modes: Modes.to_string(state.modes)` (a string like "+im"). The Channel Central dialog needs individual mode booleans to populate checkboxes, plus the key/limit values. It also needs ban exceptions, invite exceptions, and topic metadata.

**New fields in get_state return**:
- `modes_struct` — the raw `%Modes{}` struct (or individual boolean fields)
- `topic_set_by` — who set the topic
- `topic_set_at` — when the topic was set
- `ban_exceptions` — list of exception nicknames
- `invite_exceptions` — list of exception nicknames
- `bans_detailed` — list of `%{nickname, banned_by, inserted_at}` (from DB for registered channels, or just nicknames for unregistered)

**Implementation**: Keep the existing `modes` string field for backward compatibility. Add new fields alongside it.
