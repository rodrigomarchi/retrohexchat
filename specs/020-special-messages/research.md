# Research: Special Messages

**Feature Branch**: `020-special-messages`
**Date**: 2026-02-13

## R1: Administrator and Server Operator Roles

**Decision**: Introduce a configuration-based role system. Application config defines two lists of nicknames: `admins` and `server_operators`. Users in these lists who are identified via NickServ receive the corresponding privileges. Both checks require `session.identified == true` to prevent impersonation.

**Rationale**: The codebase has no existing admin/oper system. A config-based approach is the simplest viable solution that matches the spec's recommendation. NickServ identification is already tracked in `Session.identified` — combining it with a config list provides authentication (identified) + authorization (in admin/oper list) without new database tables or complex workflows. A dedicated `RetroHexChat.Accounts.ServerRoles` module encapsulates the logic.

**Alternatives considered**:
- `/oper` command with password: More IRC-traditional but requires runtime password management, adds a new persistent secret, and the codebase has no precedent for it. Config-based is simpler for a single-server deployment.
- Database-stored roles: Would require a new migration and admin UI for management. Over-engineered when the admin list rarely changes and config reloads are sufficient.
- NickServ-based flags (e.g., `SET ADMIN ON`): Would couple admin designation to the NickServ service. Better to keep server-level roles separate from nick registration.

## R2: MOTD Storage and Retrieval

**Decision**: Store the MOTD in a new `server_settings` table with a key-value pattern. A single row with key `"motd"` holds the MOTD text. A `RetroHexChat.Services.ServerSettings` module provides `get_motd/0` and `set_motd/1` and `clear_motd/0` functions. On application start, the MOTD is loaded into an in-memory cache (Application environment or a dedicated Agent) for fast retrieval on every connection.

**Rationale**: The MOTD needs to persist across restarts (database) but is read far more often than written (every connection vs. rare admin updates). A simple key-value table avoids creating a dedicated MOTD table for a single value. Caching in memory avoids a database query on every connection.

**Alternatives considered**:
- File-based MOTD (motd.txt): Traditional IRC approach but doesn't fit the existing PostgreSQL-based persistence pattern. Harder to manage in containerized deployments.
- Application config only: Would require code deployment to change the MOTD. Not suitable for runtime updates.
- ETS cache: Would work but an Agent or Application env is simpler for a single cached value that rarely changes. ETS is overkill here.

## R3: Channel Welcome Message Storage

**Decision**: Create a new `channel_welcome_messages` table with columns `channel_name` (unique, string) and `message` (text). A `RetroHexChat.Services.WelcomeMessage` schema and corresponding query functions in `RetroHexChat.Services.Queries`. The Channel.Server GenServer loads the welcome message on init and caches it in state. Updates via `/setwelcome` go to both DB and GenServer state.

**Rationale**: Welcome messages are per-channel persistent data — a perfect fit for a database table. Caching in the Channel.Server state avoids a DB query on every join. The GenServer already loads persisted channel config on startup (modes, topic, etc.), so adding welcome message fits the existing pattern.

**Alternatives considered**:
- Storing in the `registered_channels` table as a new column: Would couple welcome messages to ChanServ registration. Unregistered channels should also support welcome messages.
- In-memory only: Would lose welcome messages on server restart. Not acceptable per FR-013.

## R4: Session Tracking for Welcome Message Deduplication

**Decision**: Add a `welcomed_channels` field (MapSet) to the Session struct. When a user joins a channel and sees the welcome message, the channel is added to this set. On subsequent joins within the same session, the welcome message is skipped if the channel is already in the set. The set resets on disconnect (new session).

**Rationale**: The Session struct already tracks per-session user state (contacts, ignore list, preferences). A MapSet of channel names is minimal overhead. This matches the existing pattern of session-scoped state (e.g., `away`, `channels`).

**Alternatives considered**:
- Socket assigns: Would work but the Session struct is the established pattern for user state in this codebase.
- Channel.Server tracking who has seen the welcome: Would add per-user state to the channel process, which should remain user-agnostic. Better to track on the user side.

## R5: Wallops User Mode (+w) Implementation

**Decision**: Add a `user_modes` field (MapSet) to the Session struct. The `/umode` command (new handler) sets/unsets modes. For wallops, `+w` is the first user mode. The Session struct gets a `user_modes: MapSet.t()` field defaulting to an empty set. A `RetroHexChat.Accounts.Session.has_mode?/2` function checks mode presence.

**Rationale**: User modes are a standard IRC concept that will likely grow beyond `+w`. A MapSet-based approach (matching the channel modes pattern) is extensible. Storing in the Session struct keeps it in-memory (hot data per Principle IX) — user modes are transient per-session, not persisted.

**Alternatives considered**:
- Boolean `wallops_enabled` field: Simpler but doesn't scale to additional user modes in the future. The IRC protocol defines many user modes (+i, +w, +o, +s, etc.).
- Persisted user modes in DB: User modes in IRC are session-scoped. They reset on disconnect. No persistence needed.

## R6: Global Announcement Delivery Mechanism

**Decision**: Use a new PubSub topic `"server:announcements"` for global announcements. All connected LiveView processes subscribe to this topic on mount. When an admin sends `/announce`, the handler broadcasts to this topic. The PubSub handler in ChatLive inserts the announcement into the currently active window's message stream with distinctive styling. Announcements bypass ignore list checks entirely (no IgnoreList.ignored? check for announcement message types).

**Rationale**: The existing `"presence:global"` topic could be reused, but a dedicated topic provides clearer separation of concerns and makes it easy to add future server-wide message types. All LiveView processes already subscribe to global topics on mount, so adding one more subscription is trivial.

**Alternatives considered**:
- Broadcasting to every `"user:#{nickname}"` topic individually: Would require iterating over all connected users. PubSub broadcast to a shared topic is more efficient and naturally reaches all subscribers.
- Using `"presence:global"`: Would work but mixes presence events with announcements, making PubSub handler routing less clean.

## R7: Wallops Delivery Mechanism

**Decision**: Use a new PubSub topic `"server:wallops"` for wallops messages. All connected LiveView processes subscribe to this topic on mount. The PubSub handler checks `Session.has_mode?(session, :wallops)` before displaying. Only users with `+w` mode see the message.

**Rationale**: Similar to announcements, a dedicated PubSub topic is cleaner than filtering on a shared topic. The filter happens at the receiving end (PubSub handler) rather than the sending end, which is the established pattern in the codebase (e.g., channel messages are broadcast to all subscribers, and each subscriber decides whether to display based on ignore lists, etc.).

**Alternatives considered**:
- Only broadcasting to users with +w: Would require maintaining a list of +w users server-side. The current architecture doesn't have a central user registry beyond Phoenix.Presence. Broadcasting to all and filtering at the receiver is simpler and matches existing patterns.

## R8: Handler Context Extension for Server Roles

**Decision**: Add `is_admin: boolean()` and `is_server_operator: boolean()` fields to the `Handler.context()` type. These are computed in `CommandDispatch.build_context/1` by checking `ServerRoles.admin?(session.nickname, session.identified)` and `ServerRoles.server_operator?(session.nickname, session.identified)`. Command handlers use these fields for permission checks.

**Rationale**: The Handler context already includes `identified`, `operator_in`, and `half_operator_in` for permission checks. Adding server-level role flags follows the same pattern. Computing them in the context builder (rather than in each handler) centralizes the logic and avoids repeated config lookups.

**Alternatives considered**:
- Checking roles inside each handler: Would duplicate the config lookup logic across multiple handlers. Centralizing in the context builder is DRY.
- Adding to Session struct: Server role checks depend on both the nickname AND identification status. The Session struct has both, but the context builder is the right place to derive the role since it's command-specific context.

## R9: MOTD Display Styling

**Decision**: Display the MOTD as a bordered system message in the Status Window using a new message type `:motd`. The MOTD content is wrapped in a container with a distinctive border (double-line style via 98.css classes) and a "Message of the Day" header. The existing `push_status_message/3` function handles the insertion; CSS styling differentiates it from regular system messages.

**Rationale**: The Status Window already renders different message types with different styling (`:system`, `:error`, `:service`). Adding `:motd` as a new type allows CSS-targeted styling without changing the rendering pipeline. The bordered container provides the "distinctive" display required by the spec.

**Alternatives considered**:
- Using existing `:system` type with inline styling: Would work but doesn't allow CSS-based theming of MOTD separately from other system messages.
- Dedicated MOTD component: Over-engineered for what is essentially a styled status message.

## R10: Announcement Styling

**Decision**: Display announcements with a new message type `:announcement`. CSS provides bold text, colored background (amber/yellow to match Windows 98 warning dialogs), and high contrast. The announcement is inserted into the active window's message stream (channel or PM, whichever is focused) rather than the Status Window.

**Rationale**: The spec explicitly requires announcements to appear in the "currently active window" with distinctive styling. This differs from wallops/MOTD which go to the Status Window. Using the active channel/PM stream ensures visibility. The amber/yellow styling matches Windows 98 warning dialog conventions (Principle VIII).

**Alternatives considered**:
- Popup/modal: Would be more intrusive but also more annoying. A styled inline message in the active window balances visibility with usability.
- Status Window only: The spec explicitly says "active window", not Status Window.

## R11: Welcome Message Author Tracking

**Decision**: Store the `set_by` nickname in the `channel_welcome_messages` table alongside the message text. When a user joins and the welcome message check runs, compare the joining user's nickname with the `set_by` field. If they match, skip displaying the welcome.

**Rationale**: The spec requires "Channel welcome messages must NOT be sent to the user who set them." Storing the setter's nickname is the simplest way to implement this check. It also provides useful metadata for channel management (who set the welcome message and when).

**Alternatives considered**:
- Not tracking the setter (always show to everyone): Would violate the negative requirement.
- Tracking in the Channel.Server state only: The setter info should persist across restarts since the welcome message persists.
