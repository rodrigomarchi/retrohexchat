# Research: Notice System

**Feature**: 011-notice-system
**Date**: 2026-02-12

## R1: Notice Delivery Mechanism — User Notices

**Decision**: Broadcast user-targeted notices via PubSub on the existing `user:#{nickname}` topic using a new `{:new_notice, payload}` tuple event.

**Rationale**: The `user:#{nickname}` topic is already subscribed to by every connected user's ChatLive process (line 46 of chat_live.ex). It is used for `:channel_invite`, `:force_disconnect`, `:force_rename`, and other user-scoped events. Adding `:new_notice` follows the established pattern. No new subscriptions needed.

**Alternatives considered**:
- Creating a new `notice:#{nickname}` topic — rejected because it would require additional subscriptions on mount and adds unnecessary complexity.
- Routing through the PM system — rejected because PM delivery creates PM windows and treebar entries (violates FR-007).
- Using the channel broadcast system for user notices — rejected because user notices are not channel-scoped.

## R2: Notice Delivery Mechanism — Channel Notices

**Decision**: Broadcast channel-targeted notices via PubSub on the existing `channel:#{name}` topic using a `%{event: "new_notice", payload: payload}` map event, matching the existing `new_message` event shape.

**Rationale**: Channel messages already use `%{event: "new_message", payload: ...}` broadcast on the `channel:#{name}` topic. Using the same topic with a distinct event name (`"new_notice"`) keeps channel notices co-located with channel messages while allowing ChatLive to distinguish them and skip highlight/sound processing.

**Alternatives considered**:
- Using `"new_message"` event with a `:notice` type field — rejected because existing `handle_info` for `"new_message"` triggers highlights, sounds, and URL capture, all of which notices must skip. A separate event name provides cleaner separation.
- Broadcasting via the Channel.Server GenServer — considered but unnecessary since we can broadcast directly from the command handler's dispatch result handler in ChatLive. The Channel.Server is for stateful channel operations (topic, modes, bans).

## R3: Command Handler Result Type for /notice

**Decision**: Introduce a new dispatch result type `{:ok, :notice, %{target: target, content: content}}` in the Handler behaviour, handled in ChatLive's `handle_dispatch_result/3`.

**Rationale**: The existing `:message` result type (used by `/msg`) triggers `handle_pm_send`, which creates PM windows and conversations — exactly what notices must avoid. A dedicated `:notice` result type allows ChatLive to handle notice delivery with the correct semantics: broadcast via PubSub, no PM window creation, no persistence.

**Alternatives considered**:
- Using `:ui_action` — rejected because `:ui_action` is for UI state changes (open dialogs, toggle settings), not for message delivery.
- Handling delivery inside the handler itself — rejected because handlers are pure domain logic with no access to PubSub or socket (following Constitution Principle II).

## R4: Notice Rendering — New Message Type

**Decision**: Add a new `:notice` message type to the ChatMessage component alongside existing `:message`, `:action`, `:system`, `:service`, `:error` types. Render with `-AuthorNick-` prefix and a distinct CSS class `.chat-notice`.

**Rationale**: Notices need a unique visual treatment that is fundamentally different from all existing types:
- `:message` uses `<Nick>` — notices use `-Nick-`
- `:service` has no nick prefix — notices need one
- `:system` prefixes with `*` — notices use `-Nick-`

A dedicated type keeps the component clean and allows targeted CSS styling.

**Alternatives considered**:
- Reusing `:service` type — rejected because `:service` has no nick prefix and uses a different color scheme.
- Adding a `:notice` flag to the message map and conditionally rendering within the default clause — rejected because it adds conditional complexity to the most common rendering path.

## R5: Notice Routing Preference Storage

**Decision**: Add a `notice_routing` field to the Session struct (atom: `:active | :status | :sender`, default `:active`). Persist for registered users in a new `notice_routing_settings` table following the `perform_settings` pattern (primary key = `owner_nickname`, single row per user).

**Rationale**: The feature requires in-memory routing for all users (Session struct) and persistence for registered users (database). The `perform_settings` table pattern (primary key = owner, single row, boolean/string columns) is the established pattern for simple per-user settings.

**Alternatives considered**:
- Storing in the existing `perform_settings` table — rejected because the table is specifically for perform-related settings, and adding unrelated columns violates single-responsibility.
- Using a generic `user_settings` key-value table — rejected because no such table exists and creating one would be over-engineering for a single setting.

## R6: Ignore System Integration

**Decision**: Add `:notices` to `IgnoreEntry.valid_types/0` and a `type_matches?(:notices, :notice)` clause to `IgnoreList`. Check `IgnoreList.ignored?(session.ignore_list, sender, :notice)` in the ChatLive `handle_info` for `:new_notice`.

**Rationale**: The ignore system already supports type-specific filtering (`:all`, `:messages`, `:pms`, `:invites`, `:actions`). Adding `:notices` follows the established pattern. The `:all` type already matches any message type, so users with `ignore_type: :all` will automatically have notices filtered.

**Alternatives considered**:
- Making notices always bypass the ignore system — rejected because the spec explicitly requires FR-013 (respect the ignore system).
- Checking ignore in the sender's handler — rejected because ignore filtering is always done on the receiver side (in ChatLive handle_info), consistent with how messages and PMs are filtered.

## R7: CSS Color Choice for Notices

**Decision**: Use `#cc6699` (muted pink/magenta) for the `.chat-notice` class, distinct from existing message type colors.

**Rationale**: Existing colors are:
- `.chat-system`: `#808080` (grey)
- `.chat-service`: `#996600` (amber/brown)
- `.chat-error`: `#cc0000` (red)
- `.chat-action`: `#800080` (purple)

A muted pink/magenta provides clear visual distinction from all existing types while fitting the retro palette. In IRC clients like mIRC and HexChat, notices traditionally use a distinct color (often dark cyan or magenta).

**Alternatives considered**:
- Dark cyan (`#008080`) — viable but too close to teal link colors.
- Same as `:service` (`#996600`) — rejected because notices must be visually distinct from service messages.
