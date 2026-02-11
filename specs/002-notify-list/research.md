# Research: Notify List (Buddy List)

**Feature**: 002-notify-list
**Date**: 2026-02-11

## R1: Global Presence Tracking

**Decision**: Introduce a `"presence:global"` PubSub topic for broadcasting user connect/disconnect events system-wide.

**Rationale**: The existing presence system (`Presence.Tracker`) is per-channel only — it tracks users within `"channel:#{name}"` topics. There is no global registry of connected users. For the notify list, we need to know when ANY user connects or disconnects, regardless of channel membership. A global PubSub topic is the lightest solution: ChatLive broadcasts `:user_connected` on mount and `:user_disconnected` on terminate. Each LiveView process subscribes and filters against its local notify list.

**Alternatives considered**:
- **Phoenix.Presence on a global topic**: Would give us automatic diff tracking, but creates unnecessary overhead — we only care about connect/disconnect, not full presence state. Also, Phoenix.Presence heartbeats add load proportional to total connected users.
- **Dedicated GenServer (UserRegistry)**: A global registry process tracking all connected users. Provides a queryable "who is online?" API. However, this adds OTP complexity (Constitution III) that isn't needed — PubSub events are sufficient since each LiveView only needs to react to changes, not query state.
- **Poll-based approach**: Periodically scan channel membership to detect buddy presence. Unacceptable latency and unnecessary load.

## R2: Notify List Persistence Strategy

**Decision**: New `notify_list_entries` PostgreSQL table, keyed by `owner_nickname` (referencing `registered_nicks.nickname`). Loaded into Session assigns on NickServ identify. Guest lists live only in Session assigns (in-memory).

**Rationale**: Constitution IX mandates hot/cold separation. The database stores the persistent truth for registered users. On identify, the entries are loaded from DB into the Session struct, and all subsequent CRUD operates on the in-memory copy first, then persists changes asynchronously to DB. This gives <2s response times (SC-005) while ensuring durability.

**Alternatives considered**:
- **ETS table**: Fast but no cross-node persistence, and Constitution IX says persistent data belongs in PostgreSQL.
- **Session-only (no DB)**: Guests already work this way, but registered users expect persistence across sessions (FR-006).
- **Separate GenServer per user**: Over-engineered — the notify list has no concurrent access pattern that requires a process. LiveView assigns are sufficient.

## R3: Notification Delivery — Status Window

**Decision**: Introduce a Status window as a persistent, always-visible message area in the ChatLive layout. Notify list events are delivered here as system messages. The Status window uses a LiveView stream (`:status_messages`) separate from `:chat_messages`.

**Rationale**: Per clarification, notifications go to a Status window (mIRC-style). This avoids the ambiguity of "active channel" when none is selected. The Status window is always present (FR-021), acts as the destination for all system-level messages, and lays groundwork for future features (server messages, MOTD, etc.).

**Alternatives considered**:
- **Deliver to active channel**: Ambiguous when no channel is active. Mixes notify events with channel conversation.
- **Toast/popup notifications**: Not faithful to mIRC's Windows 98 UI paradigm.
- **Separate LiveView/route**: Unnecessary complexity — a component within ChatLive is sufficient.

## R4: Debounce Strategy

**Decision**: Per-LiveView `Process.send_after/3` timers with a 10-second window. When a buddy connect/disconnect event arrives, start a timer. If the opposite event arrives within 10s, cancel the pending timer and emit nothing (or emit the final state only). After 10s with no contradicting event, emit the notification.

**Rationale**: Debouncing must happen client-side (per-user) because each user has their own notify list. Process timers are lightweight (no GenServer needed), cancel cleanly, and integrate naturally with LiveView's `handle_info/2`. The 10s window matches FR-010 and SC-004.

**Alternatives considered**:
- **Server-side global debounce**: Would require tracking all watchers for each user — O(users × watchers) complexity. Per-LiveView is O(buddies) which is capped at 50.
- **JavaScript-side debounce**: Would require pushing events to the client and debouncing there. Adds JS complexity against Constitution I (zero JS frameworks) and VII (minimal hooks).

## R5: NickServ Identify Hook

**Decision**: Add a PubSub broadcast in `NickServ.mark_identified/2` to `"user:#{nickname}"` with `{:nickserv_identified, %{nickname: nickname}}`. ChatLive handles this event to load the persistent notify list from DB.

**Rationale**: Currently NickServ does not broadcast on identify — it returns the result to the caller (the `/ns` handler). To trigger notify list restoration, we need a hook. Broadcasting on the existing `"user:#{nickname}"` topic (which ChatLive already subscribes to) is the cleanest approach — no new subscriptions needed.

**Alternatives considered**:
- **Return value based**: The `/ns identify` handler already returns `{:ok, :system, ...}`. We could add a second return value, but this would require changing the handler result type and ChatLive dispatch logic.
- **Polling on timer**: Check `session.identified` periodically. Wasteful and adds latency.
- **Direct function call in handler**: Call `NotifyList.load_for_user/1` inside the Ns handler. Works but couples the command handler to the notify list feature — broadcasting is more loosely coupled.

## R6: Nickname Rename Tracking

**Decision**: Listen to existing `:nick_changed` broadcast on channel topics. When a rename matches a buddy in the notify list, update the in-memory entry and persist the change to DB for registered users. Display a system message in the Status window.

**Rationale**: The existing system already broadcasts `{:nick_changed, %{old: old, new: new}}` to all channels the user is in. ChatLive already handles this event. We extend the handler to check if `old` is in the notify list and update accordingly. No new broadcasts needed.

**Alternatives considered**:
- **Global nick-change broadcast**: Would require modifying the rename flow to broadcast on `"presence:global"`. Unnecessary since we already receive per-channel broadcasts for any channel we share with the buddy.
- **Ignore renames**: User must manually re-add. Poor UX per spec clarification (option A was chosen).

## R7: Auto-Whois Data Gathering

**Decision**: Implement a `Presence.NotifyList.whois_info/1` function that aggregates data from NickServ.info, Tracker.list_users (across channels), and channel Server states. Returns a map with nickname, channels, away status, registered status, and idle time.

**Rationale**: The existing `/whois` command is a stub (returns `:ui_action` only, no data fetching). For auto-whois, we need actual data. The function lives in the Presence context since it queries presence-related information. It's called from ChatLive when a buddy comes online and auto-whois is enabled.

**Alternatives considered**:
- **Reuse existing whois handler**: The existing handler is a UI stub. We'd need to refactor it to return data. Better to build the data-gathering function separately and eventually wire both the manual `/whois` and auto-whois to it.
