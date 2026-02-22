# Research: 035-p2p-session-ui

**Date**: 2026-02-16

## R1: PM Invitation Delivery Mechanism

**Decision**: Use existing `Chat.Service.send_private_message/5` to send the invitation as a system-generated PM from the initiator.

**Rationale**: The PM infrastructure already handles persistence, PubSub broadcasting (`"pm:#{sorted_nicks}"`), real-time delivery via `ChatLive.PubsubHandlers.Messages`, unread counters, and sound notifications. Reusing it avoids duplicating delivery logic and ensures the invitation appears naturally in the PM conversation history.

**Alternatives considered**:
- Custom notification-only delivery (rejected: ephemeral, lost on reload)
- New `p2p_invitations` table (rejected: over-engineering, PM table already fits)

**Implementation notes**:
- PM schema supports `type` field (currently "message" or "action") — could add a "p2p_invite" type for rendering with invitation card styling
- PubSub topic format: `"pm:#{[nick_a, nick_b] |> Enum.sort() |> Enum.join(":")}"`
- Broadcast event: `%{event: "new_pm", payload: %{sender, recipient, content, type, ...}}`
- ChatLive already handles `new_pm` events in `PubsubHandlers.Messages`

## R2: Toast Notification for P2P Invites

**Decision**: Use existing `NotificationDispatcherHook` via `push_event("notify", payload)` for the toast, extended with P2P-specific action buttons.

**Rationale**: The notification dispatcher already routes to toast, sound, title flash, and browser notifications. Adding a P2P invite type leverages the full notification pipeline.

**Alternatives considered**:
- Contextual tips system (rejected: tips are informational, not actionable)
- Custom separate toast system (rejected: fragmentation)

**Implementation notes**:
- Current toast has click-to-navigate via `onNavigate({channel})` callback
- P2P toast needs 3 action buttons (Aceitar/Recusar/Ignorar) — requires extending the toast component
- Toast manager lives in `js/lib/notification_toast.js`
- New event type: `"p2p_invite"` with payload including `token`, `from`, `session_type`
- Aceitar: `window.location = "/p2p/:token"` or `pushEvent("accept_p2p", {token})`
- Recusar: `pushEvent("reject_p2p", {token})`
- Ignorar: dismiss toast (default behavior)

## R3: Command Handler Pattern

**Decision**: Create 3 new handler modules (`P2p`, `Call`, `SendFile`) following the existing `Handler` behaviour.

**Rationale**: The project has 45+ handlers all following the same pattern. Each command is a separate module registered in `Commands.Registry`.

**Implementation notes**:
- Registry uses compile-time `@commands` map — add entries: `"p2p"`, `"call"`, `"sendfile"`
- Handler returns `{:ok, :ui_action, :p2p_invite, %{target, session_type, token}}` for ChatLive to process
- `ChatLive.CommandDispatch.handle_dispatch_result/3` needs a new clause for `:p2p_invite` result type
- Handler delegates to `RetroHexChat.P2P.create_session/3` via Service
- Validation: check args not empty, parse target nickname

## R4: SessionServer Lobby Extensions

**Decision**: Extend `SessionServer` GenServer state with `messages` list and `action_request` field for ephemeral lobby data.

**Rationale**: The spec requires ephemeral lobby chat (not persisted). The SessionServer already manages per-session state with timeouts and PubSub broadcasting. Adding messages/actions to its state is the natural OTP approach.

**Alternatives considered**:
- Separate GenServer for lobby state (rejected: unnecessary process, complicates lifecycle)
- ETS table for lobby messages (rejected: harder to clean up, less cohesive)

**Implementation notes**:
- Add to GenServer state: `messages: []`, `action_request: nil`
- New API functions: `send_message/4`, `request_action/3`, `respond_action/3`
- Broadcasts: `p2p_lobby_message`, `p2p_action_request`, `p2p_action_response`
- Cap messages at 100 (drop oldest) to bound memory
- Action request struct: `%{requester_id, action_type, requested_at, timer_ref}`
- 60-second timeout on action requests (spec clarification)

## R5: P2PSessionLive Architecture

**Decision**: Create a new LiveView `P2PSessionLive` at route `/p2p/:token` with modular event handling.

**Rationale**: The lobby is a separate page with distinct concerns from ChatLive. A dedicated LiveView keeps it focused and follows the thin-LiveView constitution principle.

**Implementation notes**:
- Mount: validate token → verify user is participant → join session → subscribe to `"p2p:#{token}"`
- Authentication: check `http_session["chat_nickname"]` + verify against session creator_id/peer_id
- PubSub events: `p2p_status_changed`, `p2p_lobby_message`, `p2p_action_request`, `p2p_action_response`, `p2p_session_closed`, `p2p_inactivity_warning`
- JS hooks: `P2PCapabilityHook` (async browser detection), `P2PSessionHook` (beforeunload cleanup)
- Components: `p2p_lobby`, `p2p_chat`, `p2p_actions`, `p2p_presence`
- `terminate/2` callback: close session via `P2P.close_session/3`

## R6: Router & Authentication

**Decision**: Add `/p2p/:token` route in the existing browser pipeline scope, with authorization at LiveView mount level.

**Rationale**: The project uses session-based auth at LiveView mount (no explicit auth pipeline). The P2P route follows the same pattern as ChatLive.

**Implementation notes**:
- Route: `live "/p2p/:token", P2PSessionLive` in the browser scope
- Mount checks: (1) `http_session["chat_nickname"]` exists, (2) nickname is registered, (3) user is session creator or peer
- Guest rejection: no `chat_nickname` in session → redirect to `/`
- Invalid token: session not found or terminal → redirect to `/chat` with flash error
- Unauthorized: user is neither creator nor peer → 404

## R7: CSS Architecture for P2P

**Decision**: Create 2 new CSS files: `p2p-session.css` (layout/structure) and `p2p-lobby.css` (chat/actions/controls).

**Rationale**: Following the CSS architecture rules — each concern with 40+ lines and distinct class prefix gets its own file. P2P session layout and lobby components are distinct concerns.

**Implementation notes**:
- Class prefixes: `.p2p-session-*` for layout, `.p2p-lobby-*` for lobby components
- Import in `app.css` Layer 4 (Components), alphabetical
- Use design tokens for colors, spacing, z-index
- retro window component for lobby container
- Dark theme support via existing CSS variable system

## R8: JS Hook Architecture for P2P

**Decision**: Create 2 hooks (`P2PCapabilityHook`, `P2PSessionHook`) and 1 lib module (`p2p.js`).

**Rationale**: Following "hook = wiring, lib = logic" pattern. Capability detection and beforeunload are wiring concerns; the detection logic itself is testable in isolation.

**Implementation notes**:
- `P2PCapabilityHook`: mounted → async detect capabilities → pushEvent("p2p_capabilities", results)
- `P2PSessionHook`: mounted → beforeunload listener → pushEvent("p2p_leave"); destroyed → cleanup
- `js/lib/p2p.js`: `detectCapabilities()` returns `{webrtc, getUserMedia, dataChannel}`, `requestPermission(type)` returns promise
- Register hooks in `app.js` Hooks object
