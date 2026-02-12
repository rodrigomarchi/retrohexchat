# Data Model: Channel Invite System

**Feature**: 010-channel-invite-system
**Date**: 2026-02-12

## Overview

This feature introduces **no new database tables or migrations**. All data is ephemeral and in-memory. Two runtime structures are extended:

1. **Socket assigns** — pending invites list (per-connection)
2. **Session struct** — auto-join preference boolean (per-session)

The existing `invite_exceptions` MapSet in `Channel.Server` GenServer state is used transiently to authorize join attempts.

## Entity Definitions

### Pending Invite (socket assigns)

An ephemeral record representing a channel invitation awaiting user response.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| channel | String.t() | Must start with `#`, non-empty | Target channel name |
| inviter | String.t() | Non-empty | Nickname of the operator who sent the invite |
| invited_at | DateTime.t() | UTC timestamp | When the invite was received |
| timer_ref | reference() | Valid process timer ref | Reference to the `Process.send_after` expiration timer |

**Lifecycle**:
```
Created (invite received) → Active (awaiting response) → Consumed (user clicked Join)
                                                        → Dismissed (user clicked Ignore)
                                                        → Expired (5-minute timer fired)
```

**Storage**: List in `socket.assigns.pending_invites`, managed by ChatLive.

**Uniqueness**: One invite per channel per user. A second invite to the same channel replaces the existing one (timer is cancelled and reset).

**Cleanup**: All pending invites are discarded when the LiveView process terminates (user disconnects).

### Session Extension: auto_join_on_invite

A boolean preference added to the existing `RetroHexChat.Accounts.Session` struct.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| auto_join_on_invite | boolean() | false | When true, skip invite dialog and join immediately |

**Persistence**: In-memory only (Session struct). Not persisted to database in this iteration.

## Existing Entities Used (not modified)

### Channel.Server State — invite_exceptions

The existing `invite_exceptions: MapSet.t(String.t())` field in Channel.Server state is used transiently:

- **Add**: When an invite is sent, `Channel.Server.add_invite_exception(channel, operator, invitee)` adds the invitee's nickname to the MapSet.
- **Remove**: When an invite expires, is ignored, or the user joins, the nickname is removed from the MapSet.
- **Check**: `Policy.can_join?/5` already checks this MapSet — no modification needed.

**Important**: The invite_exceptions addition here is **transient** — it is not the same as permanent invite exceptions managed via Channel Central (+I mode). Transient entries are cleaned up by the invite system. If the server restarts, these transient entries are lost (which is correct — the invites themselves are lost too).

### Channel Modes — invite_only flag

The existing `Modes.invite_only?/1` function is used to validate that `/invite` is only used on +i channels. No modification needed.

## Relationships

```
Operator (sender)
    │
    ├── sends /invite → Command Handler validates permissions
    │                    │
    │                    ├── adds invitee to Channel.Server.invite_exceptions (transient)
    │                    │
    │                    └── broadcasts {:channel_invite, payload} to "user:#{invitee}"
    │
Invitee (receiver)
    │
    ├── ChatLive receives broadcast → adds to socket.assigns.pending_invites
    │                                  │
    │                                  ├── if auto_join_on_invite: true → auto-join channel
    │                                  │
    │                                  └── if auto_join_on_invite: false → show InviteDialog
    │
    ├── User clicks "Join" → joins channel, removes from pending_invites,
    │                         removes from invite_exceptions
    │
    ├── User clicks "Ignore" → removes from pending_invites,
    │                           removes from invite_exceptions
    │
    └── Timer fires (5 min) → removes from pending_invites,
                               removes from invite_exceptions,
                               dialog shows "expired" if still open
```

## Validation Rules

| Rule | Source | Enforcement |
|------|--------|-------------|
| Operator must be in channel | FR-002 | Command handler checks `channel in context.operator_in` |
| Channel must be +i | FR-003 | Command handler calls `Channel.Server` to check mode |
| Invitee must be connected | FR-016 | Command handler checks presence via PubSub/Presence |
| Invitee not already in channel | FR-015 | Command handler checks channel membership |
| One invite per channel per user | FR-020 | ChatLive deduplicates on receive, cancels old timer |
| Invite expires after 5 minutes | FR-009 | Process.send_after with 300_000 ms timeout |
| Auto-join default false | FR-012 | Session struct default |

## Volume & Scale Assumptions

- **Pending invites per user**: Typically 0-2 at any time. Unlikely to exceed 5 simultaneous invites.
- **invite_exceptions per channel**: Transient additions are short-lived (max 5 minutes). No meaningful impact on MapSet size.
- **No database impact**: Zero queries, zero migrations, zero storage growth.
