# Data Model: 035-p2p-session-ui

**Date**: 2026-02-16

## Existing Entities (no changes needed)

### P2P Session (p2p_sessions table)

Already exists from feature 034. No schema changes required.

| Field | Type | Constraints |
|-------|------|------------|
| id | integer | PK, auto-increment |
| token | string(64) | unique, not null |
| creator_id | integer | FK → registered_nicks, not null |
| peer_id | integer | FK → registered_nicks, not null |
| status | string | not null, default "pending" |
| session_type | string | not null, default "generic" |
| metadata | map (JSONB) | default %{} |
| closed_at | utc_datetime_usec | nullable |
| closed_reason | string(100) | nullable |
| inserted_at | utc_datetime_usec | auto |
| updated_at | utc_datetime_usec | auto |

**Status values**: pending, lobby, connecting, active, closed, expired, failed
**Session types**: generic, file_transfer, audio_call, video_call
**Terminal statuses**: closed, expired, failed

### Private Message (private_messages table)

Already exists. Used for P2P invitation delivery.

| Field | Type | Notes |
|-------|------|-------|
| id | integer | PK |
| sender_nickname | string(16) | not null |
| recipient_nickname | string(16) | not null |
| content | string | not null |
| type | string | "message", "action", or **"p2p_invite"** (new type value) |
| reply_to_id | integer | nullable |
| inserted_at | utc_datetime_usec | auto |

**New type value**: `"p2p_invite"` — used to render the PM with invitation card styling (clickable lobby link, session type badge). No schema migration needed, just a new allowed value in the changeset validation.

## Ephemeral Entities (GenServer state only)

### Lobby Chat Message

Lives in `SessionServer` GenServer state. Never persisted.

```elixir
%{
  id: String.t(),           # unique message ID (System.unique_integer)
  sender_id: integer(),     # registered_nick ID
  sender_nick: String.t(),  # display nickname
  content: String.t(),      # message text
  type: :message | :system, # user message or system event
  timestamp: DateTime.t()   # UTC timestamp
}
```

**Constraints**:
- Max 100 messages retained (FIFO, drop oldest)
- Content max 500 characters
- Lost on process crash (acceptable per spec)

### Action Request

Lives in `SessionServer` GenServer state. Only one active request at a time.

```elixir
%{
  requester_id: integer(),           # who initiated the request
  requester_nick: String.t(),        # display nickname
  action_type: :file_transfer | :audio_call | :video_call,
  status: :pending | :accepted | :rejected | :expired,
  requested_at: DateTime.t(),        # when request was created
  timer_ref: reference() | nil       # 60-second expiry timer
}
```

**Constraints**:
- Only one pending request at a time (second request queued until first resolves)
- 60-second timeout (timer_ref for Process.send_after)
- On expiry: status → :expired, broadcast notification, clear request

## State Transitions

### Session Lifecycle (existing, unchanged)

```
pending ──[both join]──→ lobby ──[consent + connect]──→ connecting ──[WebRTC]──→ active
   │                       │                                │                      │
   └──[5min timeout]──→ expired   └──[15min idle]──→ expired   └──[30s timeout]──→ failed
                           │                                                       │
                           └──[close/reject]──→ closed ←──[close]─────────────────┘
```

### Action Request Lifecycle (new)

```
(none) ──[peer clicks action]──→ pending ──[other peer accepts]──→ accepted
                                    │                                  │
                                    ├──[other peer rejects]──→ rejected
                                    │
                                    └──[60s timeout]──→ expired
```

## PubSub Events (new broadcasts)

| Event | Topic | Payload |
|-------|-------|---------|
| p2p_lobby_message | p2p:#{token} | %{id, sender_id, sender_nick, content, type, timestamp} |
| p2p_action_request | p2p:#{token} | %{requester_id, requester_nick, action_type} |
| p2p_action_response | p2p:#{token} | %{responder_id, responder_nick, action_type, accepted} |
| p2p_action_expired | p2p:#{token} | %{action_type} |

## Existing PubSub Events (unchanged, consumed by P2PSessionLive)

| Event | Topic | Payload |
|-------|-------|---------|
| p2p_status_changed | p2p:#{token} | %{status, reason} |
| p2p_inactivity_warning | p2p:#{token} | %{expires_in_seconds} |
| p2p_session_closed | p2p:#{token} | %{reason, closed_by} |
| p2p_invite | user:#{nickname} | %{token, from, session_type} |
