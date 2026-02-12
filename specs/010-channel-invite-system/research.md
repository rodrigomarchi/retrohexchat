# Research: Channel Invite System

**Feature**: 010-channel-invite-system
**Date**: 2026-02-12

## R1: Invite State Storage Mechanism

**Decision**: Store pending invites in LiveView socket assigns as a list of invite maps.

**Rationale**: Invites are ephemeral and per-user — they only exist while the user is connected. Socket assigns are the natural location for per-connection transient state in LiveView. This avoids introducing new GenServers, ETS tables, or database tables for data that is inherently tied to the connection lifecycle. When the user disconnects, invites are automatically discarded (the socket dies).

**Alternatives considered**:
- **ETS table**: Would survive LiveView reconnects but adds complexity. Invites are intentionally lost on disconnect per spec (FR-019).
- **Channel.Server GenServer state**: Would couple invite state to channel processes. Invites are a user-side concern, not a channel-side concern.
- **Dedicated GenServer per user**: Over-engineering for simple list tracking. Socket assigns suffice.

## R2: Join Authorization via invite_exceptions

**Decision**: When an invite is sent, temporarily add the invitee to the channel's `invite_exceptions` MapSet via `Channel.Server.add_invite_exception/3`. When the invite expires or is ignored, remove them via `Channel.Server.remove_invite_exception/3`. When the user successfully joins, remove the exception (one-time use).

**Rationale**: The existing `Policy.can_join?/5` already checks `invite_exceptions` to bypass the +i restriction. This is the designed integration point — no new authorization paths needed. The invite command handler adds the nickname, and the join flow naturally checks it.

**Alternatives considered**:
- **Separate invite token system**: Would require modifying `Policy.can_join?` to accept tokens. Unnecessary when `invite_exceptions` already exists.
- **Pass-through authorization flag**: Would bypass the policy layer, violating the existing security model.

## R3: Invite Expiration Strategy

**Decision**: Use `Process.send_after/3` in the LiveView process to schedule an expiration message (e.g., `{:invite_expired, channel_name}`) after 5 minutes. On expiration, remove the invitee from `invite_exceptions` and update the dialog state (show expired error if still open).

**Rationale**: `Process.send_after` is the idiomatic Elixir/OTP approach for time-delayed actions within a process. The LiveView process is the right owner because the invite state lives in its assigns. No external timer processes needed.

**Alternatives considered**:
- **Channel.Server-side timer**: Would couple expiration logic to the channel process. The invite is a user-side concern.
- **Periodic sweep/cleanup**: Adds unnecessary complexity. Per-invite timers are precise and self-cleaning.

## R4: PubSub Delivery for Invite Notifications

**Decision**: When an operator sends `/invite Alice #private`, the ChatLive handling the operator broadcasts to `"user:Alice"` with `{:channel_invite, %{channel: "#private", inviter: "OperatorNick"}}`. Alice's ChatLive receives this in `handle_info/2`, adds the invite to her socket assigns, and renders the dialog.

**Rationale**: The `"user:#{nickname}"` PubSub topic is the established pattern for user-targeted real-time events (already used for force renames, PM notifications). This is consistent with Principle VII (PubSub naming convention).

**Alternatives considered**:
- **Direct LiveView messaging**: Not possible — the operator's LiveView doesn't know Alice's PID.
- **Channel topic broadcast**: Would leak invite visibility to all channel members.

## R5: Auto-Join Preference Storage

**Decision**: Add `auto_join_on_invite: boolean()` field to the Session struct, defaulting to `false`. No database persistence — this is a session-only preference (lost on disconnect). Toggled via `/invite auto` command (subcommand).

**Rationale**: Follows the existing Session pattern for lightweight user preferences. The spec explicitly states in-memory Session is sufficient for the initial implementation. The preference is simple enough that a Session field is appropriate (vs. a separate module like PerformList).

**Alternatives considered**:
- **Separate preference module**: Over-engineering for a single boolean.
- **Database-persisted setting**: Deferred to future enhancement. Initial implementation is Session-only per spec assumptions.

## R6: Multiple Simultaneous Dialogs (Cascading)

**Decision**: Store pending invites as a list in socket assigns: `pending_invites: [%{channel: String.t(), inviter: String.t(), invited_at: DateTime.t(), timer_ref: reference()}]`. Each invite renders as a separate dialog component instance with CSS offset based on list index (e.g., `top: #{20 * index}px; left: #{20 * index}px`).

**Rationale**: Clarification session confirmed cascading windows effect. The list naturally supports multiple invites. CSS offset provides the Win98 cascading aesthetic without JavaScript.

**Alternatives considered**:
- **Single dialog with list view**: Rejected in clarification — user chose cascading.
- **Queue-based (one at a time)**: Rejected in clarification.

## R7: Invite Dialog Component Pattern

**Decision**: Create `RetroHexChatWeb.Components.InviteDialog` as a function component following the same pattern as `PerformDialog` — uses `class="window"`, `class="title-bar"`, overlay with z-index. Each dialog instance receives its invite data as attributes.

**Rationale**: Consistent with existing dialog components. The function component pattern keeps the web layer thin (Principle VII).

**Alternatives considered**:
- **LiveComponent**: Unnecessary — no local state needed. The invite state lives in the parent LiveView's assigns.
- **JavaScript-based popup**: Violates Constitution Principle I (no JS UI frameworks).
