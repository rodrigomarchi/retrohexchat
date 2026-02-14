# Research: Visual Feedback & Unread Indicators

## R1: Unread Count Tracking Strategy

**Decision**: Replace boolean MapSet (`unread_channels`) with a Map (`unread_counts`) mapping channel names to integer counts. Keep `highlight_channels` as a MapSet for mention tracking. Keep `muted_channels` as a MapSet.

**Rationale**: The existing `unread_channels` MapSet only tracks presence (has unread: yes/no). We need numeric counts for badges. A Map `%{channel_name => count}` provides O(1) increment and lookup. The treebar component receives the counts map and renders both bold text (count > 0) and numeric badges.

**Alternatives considered**:
- Separate `unread_counts` map alongside existing `unread_channels` MapSet — rejected: redundant data, risk of desynchronization.
- Struct-based tracker — rejected: overkill for simple integer counting.

## R2: Treebar Badge Rendering Approach

**Decision**: Render badges server-side in the treebar.ex component using HEEx. The treebar component receives `unread_counts` (map), `highlight_channels` (list), `muted_channels` (list), and `disconnected_channels` (list). Badge HTML is generated inline.

**Rationale**: Server-side rendering keeps the treebar as a pure function component with no JS hook dependency for badge display. LiveView efficiently diffs the HTML. The existing `treebar_item_class/5` function already handles multiple CSS classes — extending it with muted and disconnected states is straightforward.

**Alternatives considered**:
- JS-side badge rendering via hook — rejected: unnecessary complexity, breaks LiveView's declarative rendering model.
- CSS-only badges via `::after` pseudo-elements — rejected: can't show dynamic count text in pseudo-elements without `attr()` which has limited browser support.

## R3: Optimistic Send Architecture

**Decision**: Use a client-side optimistic pattern: when the user sends a message, immediately insert a "pending" stream item with a temporary client-generated ID. The server's `send_plain_message` already broadcasts via PubSub, which delivers the confirmed message back to the sender. On receiving the confirmed message, replace the pending item.

**Rationale**: Phoenix LiveView's stream mechanism supports `stream_insert` with `at: -1` for appending. We assign pending messages a temporary ID prefix (e.g., `pending_#{timestamp}`). The server broadcast delivers the real message with its database ID. The hook matches pending messages by content+author and transitions them to confirmed state.

**Alternatives considered**:
- Server-side optimistic (insert into stream before GenServer.call) — rejected: the GenServer.call is synchronous and fast (<10ms locally), so the "pending" window is negligible for non-failure cases. Client-side approach only matters for actual failures.
- No optimistic UI — rejected: spec requires it (FR-019 through FR-025).

## R4: Message Failure Detection

**Decision**: Wrap `Server.send_message` in a try/catch with a timeout. On `:ok`, push a `message_confirmed` event. On `{:error, reason}`, push a `message_failed` event with the temporary ID and reason. The JS hook transitions the message visually.

**Rationale**: The existing `send_plain_message` already handles `{:error, reason}` by showing an error message. We extend this to push events that the JS hook can use to update the pending message's visual state.

**Alternatives considered**:
- Purely server-side retry via `handle_event("retry_message", ...)` — chosen as the retry mechanism, keeping the retry button click as a LiveView event rather than pure JS.

## R5: Kick Dialog Pattern

**Decision**: Create a new `kick_dialog.ex` function component following the existing dialog pattern (`.dialog-overlay` + `.window` + `.title-bar` + `.dialog-buttons`). Use a `kick_queue` assign (list of kick events) in ChatLive. The first item in the queue is displayed; clicking OK removes it and shows the next.

**Rationale**: Follows the established dialog pattern used by 15+ existing dialogs. A list-based queue handles simultaneous kicks naturally. The component is conditionally rendered based on `length(kick_queue) > 0`.

**Alternatives considered**:
- Reuse toast component for kicks — rejected: spec requires a modal dialog with OK button, not an auto-dismissing toast.
- Single kick assign (no queue) — rejected: spec explicitly requires queuing for simultaneous kicks (FR-013).

## R6: Copy/Settings Toast Integration with Z2

**Decision**: Extend the existing toast infrastructure from Z2 (Contextual Tips) to support arbitrary "feedback toasts" alongside tips. Add a new `push_event("feedback_toast", %{message: text, duration: ms})` event. The hook creates a simpler toast (no checkbox, no suppress logic) that auto-dismisses after the specified duration.

**Rationale**: The Z2 toast container and animation system already exist. Feedback toasts are simpler than tip toasts — they only need a message and duration. Using the same container and positioning keeps the UI consistent.

**Alternatives considered**:
- Separate toast container — rejected: would cause positioning conflicts with the Z2 toast container.
- Pure JS toast (no LiveView event) — partially adopted: copy toast is triggered from JS (clipboard event), but settings toast is triggered from server (push_event on apply).

## R7: Join Flash Implementation

**Decision**: On successful join, push a `channel_joined_flash` event to the client. The treebar hook adds a CSS class (`tree-join-flash`) to the channel entry, which runs a 1-second green flash animation, then removes the class.

**Rationale**: CSS animations are the simplest and most performant approach. The existing `tree-highlight` animation (yellow flash) provides a pattern to follow. A green variant for joins is visually distinct.

**Alternatives considered**:
- Server-side flash via assign — rejected: CSS animation timing is better handled client-side. Server would need a timer to remove the class.

## R8: Disconnected Channel State

**Decision**: Track disconnected channels via a `disconnected_channels` MapSet in socket assigns. Channels enter disconnected state when a PubSub subscription is lost or a channel GenServer crashes. The treebar renders a lightning icon (`⚡`) and applies `.tree-disconnected` CSS class (gray text, no badges).

**Rationale**: The channel GenServer can crash independently. The existing `{:EXIT, pid, reason}` or `{:DOWN, ...}` monitoring pattern can detect this. For MVP, disconnected state is primarily a visual treatment for when the user is explicitly disconnected (e.g., reconnect scenario).

**Alternatives considered**:
- Monitor each channel GenServer — deferred: adds complexity. For now, disconnected state applies during reconnection flows.

## R9: Muted Channel Badge Suppression

**Decision**: When a channel is muted, the treebar renders it with `.tree-muted` (grayed-out text) and suppresses all badges (numeric count and red dot). Internally, unread counts still increment — when the user unmutes, the accumulated count is immediately visible.

**Rationale**: Muting means "don't distract me" — visual badges are a distraction. But the counts must still be tracked so unmuting reveals the true state. The existing `muted_channels` MapSet already exists in the session.

**Alternatives considered**:
- Don't track counts for muted channels — rejected: spec requires accumulated indicators to appear when unmuting.

## R10: Unread Count Cap (99+)

**Decision**: Cap the displayed count at 99 in the treebar component. The internal count continues to increment beyond 99 — only the display is capped. The component renders `"99+"` when count > 99.

**Rationale**: Display cap prevents badge overflow. Internal count accuracy is preserved for potential future use (e.g., "you have 247 unread messages" in a tooltip).

**Alternatives considered**:
- Cap internal count at 100 — rejected: loses precision for no benefit.
