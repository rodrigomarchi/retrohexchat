# Research: P2P Actions in Context Menus

**Feature**: 040-p2p-context-menus
**Date**: 2026-02-17

## R1: Target Registration Check — Render-Time vs Handler-Time

**Decision**: Hybrid approach — check at menu-open time for visual disabled state, and rely on `do_execute/3` validation as the authoritative gate.

**Rationale**: The spec requires items to appear grayed out with a tooltip when the target is unregistered. This requires knowing registration status at render time. However, `NickServ.registered?/1` is an ETS lookup (fast) so calling it when the context menu opens (once per right-click) is acceptable. The same pattern is used by `hover_events.ex` and `whois.ex`.

**Alternatives considered**:
- Handler-time only (no visual disabled state): Rejected — spec explicitly requires disabled items with tooltip.
- Pre-cached registration in nicklist assigns: Rejected — adds complexity for marginal benefit; registration status can change at any time.

**Implementation**: Add `is_target_registered` to the `context_menu` assign map (set in `nick_right_click` handler) and to the `chat_context_menu` assign map (set in `chat_context_menu` handler). Both call `NickServ.registered?/1` at menu-open time.

## R2: Event Handler Reuse of P2p.do_execute/3

**Decision**: Call `P2p.do_execute/3` directly from context menu event handlers, building the context map from `socket.assigns.session`.

**Rationale**: The existing command dispatch builds a context map with `%{nickname:, identified:, active_channel:, channels:, ...}` and calls `P2p.do_execute/3`. The context menu handlers need the same flow. Duplicating the context-building code is minimal (3-4 lines) and avoids coupling to the command dispatch pipeline.

**Alternatives considered**:
- Route through command dispatch (simulate `/p2p nick`): Rejected — adds indirection, command dispatch has unrelated concerns (input parsing, command routing).
- Extract shared helper for context building: Considered but overkill for 3-4 lines.

## R3: Initiator Navigation to P2P Lobby

**Decision**: After `P2p.do_execute/3` succeeds, use `push_navigate(socket, to: ~p"/p2p/#{token}")` to navigate the initiator to the lobby. Also call `handle_p2p_invite/3` to send the PM invitation to the target.

**Rationale**: The current slash-command flow does NOT navigate the initiator — it sends a PM and shows a system message. The spec requires the context menu to navigate to the lobby. This is a new behavior for context menu P2P actions specifically.

**Alternatives considered**:
- Match current slash-command behavior (no navigation): Rejected — spec explicitly requires lobby navigation.
- Navigate and skip PM: Rejected — the target still needs the PM invitation to discover the session.

**Implementation**: Event handler calls `handle_p2p_invite/3` (for PM + system message) then `push_navigate/2` to `/p2p/#{token}`. The `handle_p2p_invite` function is currently private in `command_dispatch.ex` — extract to a shared helper or duplicate the logic in context_menu_events.ex.

## R4: Shared P2P Invite Logic

**Decision**: Extract `handle_p2p_invite/3` and `p2p_invite_content/2` from `command_dispatch.ex` into a shared helper module `RetroHexChatWeb.ChatLive.Helpers.P2pInvite`, importable by both `command_dispatch.ex` and `context_menu_events.ex`.

**Rationale**: The P2P invite flow (send PM, show system message) is needed from both the `/p2p` command and the context menu. Duplicating 20+ lines of logic (including pattern-matched `p2p_invite_content/2`) would create divergence risk.

**Alternatives considered**:
- Duplicate the logic: Rejected — 4 function clauses + PM sending is enough to warrant extraction.
- Make `command_dispatch.ex` functions public: Rejected — violates module cohesion, command_dispatch is for command pipeline.

## R5: Video Call Session Type

**Decision**: Use `"video_call"` session type string, same as existing session schema definition.

**Rationale**: The `Session` schema already defines `@session_type_values ~w(generic file_transfer audio_call video_call)`. The `"video_call"` type has no dedicated slash command but is fully supported by the schema and P2P infrastructure. The context menu provides a new entry point for this existing capability.

**Alternatives considered**: None — `"video_call"` already exists.

## R6: Context Menu Assigns — New Attributes

**Decision**: Add these new attributes:

- `context_menu.ex`: `attr :viewer_is_identified, :boolean, default: false` and `attr :is_target_registered, :boolean, default: false`
- `chat_context_menu.ex`: `attr :viewer_is_identified, :boolean, default: false` and `attr :is_target_registered, :boolean, default: false`

**Rationale**: `viewer_is_identified` controls whether P2P items render at all (`:if` guard). `is_target_registered` controls whether items are disabled (class + phx-click conditional). Both follow existing patterns in these components.

**Pass-through in template**:
- `viewer_is_identified={@session.identified}`
- `is_target_registered={@context_menu[:is_target_registered] || false}` (for nicklist)
- `is_target_registered={chat_context_target_registered?(@session, @chat_context_menu)}` (for chat — new helper)
