# Research: User Information

## R1: Whois Output Format (Text vs Dialog)

**Decision**: Text output in chat stream, enhancing the existing /whois command.
**Rationale**: The current /whois already outputs text via `{:ok, :ui_action, :open_whois, %{}}`. We will change it to output multiple `system_message` lines directly in the chat stream instead, matching how traditional mIRC /whois works (numeric 311/312/317/318 replies as text). This avoids building a new dialog component and is consistent with the clarification from the spec.
**Alternatives considered**: Windowed dialog (like Organize Favorites) — rejected because the spec explicitly clarified text output is preferred.

## R2: Idle Time Tracking Approach

**Decision**: Store `last_activity_at` timestamp as a socket assign in ChatLive. Compute idle time on-demand when /whois is queried.
**Rationale**: Idle time is per-connection, ephemeral data. No persistence needed. Storing a timestamp rather than a counter avoids needing a periodic tick. The existing `connected_at` field in Session already demonstrates this pattern. We'll add a new socket assign `last_activity_at` that resets on every `handle_event` that represents user activity (message send, PM send, command execution).
**Alternatives considered**: GenServer per user tracking idle — rejected (over-engineered for a simple timestamp). ETS table — rejected (socket assigns are simpler and already scoped per user).

## R3: Cross-User Idle Time Query

**Decision**: Use Phoenix Presence metadata to expose `last_activity_at` per user. When tracking a user in Presence, include `last_activity_at` in the meta. Update the meta on activity. Query Presence when generating /whois output.
**Rationale**: Phoenix Presence already tracks per-user metadata (away status, joined_at). Adding `last_activity_at` to the meta follows the existing pattern. This allows cross-user queries without direct socket access.
**Alternatives considered**: Direct socket assign query (impossible — can't access another user's socket). Central ETS registry (extra infrastructure when Presence already exists).

## R4: Whowas Cache Implementation

**Decision**: Named GenServer (`RetroHexChat.Presence.WhowasCache`) backed by an ETS table with periodic cleanup.
**Rationale**: ETS provides O(1) lookup by nickname. A GenServer wraps the ETS for state management and runs a periodic cleanup timer (every 10 minutes) to evict expired entries. The 1000-entry cap is enforced on insert (evict oldest entry when at capacity). This follows the OTP process architecture principle.
**Alternatives considered**: Pure GenServer with map state — rejected (ETS is faster for lookups and allows concurrent reads). Database table — rejected (whowas data is ephemeral and should not survive restarts).

## R5: Whowas Data Collection Point

**Decision**: Record whowas entries when a user's ChatLive process terminates (in `terminate/2` callback or via PubSub event on disconnect).
**Rationale**: The ChatLive `terminate/2` callback fires on disconnect and has access to the session (channels, nickname). We publish a PubSub event on the `"user:#{nickname}"` topic, and the WhowasCache GenServer subscribes to a catch-all topic or we call WhowasCache directly from terminate.
**Alternatives considered**: Channel-level tracking — rejected (would miss users not in any channel). Presence diff hooks — considered but terminate callback is simpler.

## R6: Bio Persistence Pattern

**Decision**: Single-row-per-user table `user_bios` with `owner_nickname` FK to `registered_nicks`, `bio_text` string (max 200), timestamps. Domain module `RetroHexChat.Chat.UserBio` with `save/2`, `load/1`, `delete/1`.
**Rationale**: Follows the existing pattern used by NoticeRouting, CtcpSettings, FloodProtection (single-row per user). Bio is simple — one field per user, no complex structure. Session integration via `load_persisted_data` chain.
**Alternatives considered**: Storing bio in the `registered_nicks` table — rejected (adding columns to core auth table for feature data is bad practice). JSON field — rejected (overkill for a single string).

## R7: Shared Channels Computation

**Decision**: Iterate the querying user's `session.channels` list and for each channel, check if the target user is a member via `Channels.Server.get_state/1` and `Membership.member?/2`.
**Rationale**: The querying user's channel list is already in their session. Checking membership via the channel GenServer is fast (GenServer.call). This avoids maintaining a separate user→channels index.
**Alternatives considered**: Central user→channels registry — rejected (over-engineered; the number of channels per user is small, typically < 20).

## R8: Idle Time Formatting

**Decision**: Create a utility function `RetroHexChat.Chat.TimeFormatter.format_duration/1` that converts seconds to human-friendly strings: "less than a minute", "2 minutes", "1 hour 30 minutes", etc.
**Rationale**: Reusable across /whois idle time, /whois online time, and potentially /whowas "last seen X ago". Follows the pattern of keeping utilities in the domain layer.
**Alternatives considered**: Inline formatting in the handler — rejected (duplicated logic, harder to test).

## R9: Double-Click Nicklist

**Decision**: Add `phx-click="nick_double_click"` with a JS hook or `phx-click` event that detects double-click via a timer-based approach in the LiveView (track last click time and nickname, trigger whois if same nick clicked within 300ms).
**Rationale**: Phoenix LiveView doesn't have native double-click support. A simple approach: on `nick_click` event, check if the same nickname was clicked within 300ms — if so, treat as double-click and trigger whois. This avoids a JS hook.
**Alternatives considered**: JS hook for dblclick — viable alternative but adds JS complexity. Using the existing `nick_right_click` as single-click and adding double-click — also viable but changes existing behavior.

## R10: Whois Output Line Format

**Decision**: Output whois information as multiple system messages, one per field, formatted consistently:
```
----- Whois: Alice -----
Channels: #elixir, #lobby
Shared channels: #elixir
Online for: 2 hours 15 minutes
Idle for: 15 minutes
Registered: Yes
Away: Gone to lunch
Bio: Elixir enthusiast from Brazil
-----------------------------
```
**Rationale**: Follows traditional IRC /whois reply format. Each field is on its own line for readability. Header/footer delimiters make it visually distinct in the chat stream. Fields with no value (no bio, not away) are omitted entirely.
**Alternatives considered**: Single multiline message — rejected (stream_insert works best with individual messages). JSON-like format — rejected (not user-friendly).
