# Data Model: P2P Foundation

**Feature**: 034-p2p-foundation | **Date**: 2026-02-16

## Entities

### p2p_sessions

The single entity in this feature. Represents a peer-to-peer session between two registered users.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| id | bigint | PK, auto-increment | Database primary key |
| token | string(64) | NOT NULL, UNIQUE | Cryptographic session identifier (used in URLs and PubSub topics) |
| creator_id | integer | NOT NULL, FK → registered_nicks | User who initiated the session |
| peer_id | integer | NOT NULL, FK → registered_nicks | Target user invited to the session |
| status | string(20) | NOT NULL, DEFAULT "pending" | Current state: pending, lobby, connecting, active, closed, expired, failed |
| session_type | string(20) | NOT NULL, DEFAULT "generic" | Purpose: generic, file_transfer, audio_call, video_call |
| metadata | map | NOT NULL, DEFAULT {} | Extensible JSON for future features (file info, codec prefs, etc.) |
| closed_at | utc_datetime_usec | nullable | When the session reached a terminal state |
| closed_reason | string(100) | nullable | Why the session ended (user_closed, expired, timeout, error) |
| inserted_at | utc_datetime_usec | NOT NULL | Creation timestamp |
| updated_at | utc_datetime_usec | NOT NULL | Last modification timestamp |

### Indexes

| Index | Columns | Type | Purpose |
|-------|---------|------|---------|
| p2p_sessions_token_index | token | UNIQUE | Token-based session lookup |
| p2p_sessions_creator_id_index | creator_id | btree | Find sessions by creator |
| p2p_sessions_peer_id_index | peer_id | btree | Find sessions by peer |
| p2p_sessions_status_index | status | btree | Filter by session state |
| p2p_sessions_active_pair_index | creator_id, peer_id, status | btree | Duplicate session check (active pairs) |

### Foreign Keys

| Column | References | On Delete |
|--------|------------|-----------|
| creator_id | registered_nicks.id | CASCADE |
| peer_id | registered_nicks.id | CASCADE |

### State Machine

```text
                    ┌─────────┐
                    │ pending  │──── timeout (5 min) ──→ expired
                    └────┬────┘
                         │ both peers join
                    ┌────▼────┐
             ┌──────│  lobby  │──── inactivity (15 min) ──→ expired
             │      └────┬────┘     (warning at 10 min)
             │           │ mutual action agreement
             │      ┌────▼──────┐
             │      │connecting │──── timeout (30 sec) ──→ failed
             │      └────┬──────┘
             │           │ handshake success
             │      ┌────▼────┐
             │      │ active  │
             │      └────┬────┘
             │           │
             ▼           ▼
        ┌─────────┐  ┌────────┐  ┌─────────┐
        │ expired  │  │ closed │  │ failed  │
        └─────────┘  └────────┘  └─────────┘
                  (terminal states)

  * Any non-terminal state → closed (user-initiated close)
```

### Valid Transitions

| From | To | Trigger |
|------|----|---------|
| pending | lobby | Both peers join |
| pending | expired | 5-minute timeout |
| pending | closed | Creator cancels |
| lobby | connecting | Mutual action agreement |
| lobby | expired | 15-minute inactivity |
| lobby | closed | Either peer closes |
| connecting | active | Handshake success |
| connecting | failed | 30-second timeout |
| connecting | closed | Either peer closes |
| active | closed | Either peer closes |

### Validation Rules

- `token`: Required, unique, max 64 characters
- `creator_id`: Required, must reference a registered nick, must differ from peer_id
- `peer_id`: Required, must reference a registered nick, must differ from creator_id
- `status`: Required, must be one of: pending, lobby, connecting, active, closed, expired, failed
- `session_type`: Required, must be one of: generic, file_transfer, audio_call, video_call
- `closed_at`: Required when status is a terminal state (closed, expired, failed)
- `closed_reason`: Required when status is a terminal state

### Data Volume Assumptions

- Expected: Low volume initially (tens of sessions per day)
- Retention: Terminal sessions kept indefinitely for audit; no automatic purging in this plan
- Growth: Linear with user count, bounded by session timeout (most sessions short-lived)
