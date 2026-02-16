# Data Model: WebRTC Signaling (036)

**Date**: 2026-02-16

## Database Changes

**No new migrations.** All signaling data is ephemeral (in-memory only). The existing `p2p_sessions` table already supports the `connecting` and `active` status values.

## Ephemeral Entities

### Signal Message (never persisted)

Relayed via PubSub broadcast, never stored.

| Field | Type | Description |
|---|---|---|
| `type` | `"offer" \| "answer" \| "ice-candidate"` | Signal message type |
| `sdp` | `string` | SDP content (for offer/answer) |
| `candidate` | `map` | ICE candidate object (for ice-candidate) |
| `from` | `integer` | Sender's user_id (for routing, set server-side) |

**Validation (server-side, FR-012):**
- `type` must be one of: `"offer"`, `"answer"`, `"ice-candidate"`
- For `offer`/`answer`: `sdp` must be a non-empty string
- For `ice-candidate`: `candidate` must be a map
- `from` is set by the server (not trusted from client)

### ICE Server Configuration (generated per session)

Sent to browser via `push_event`, never stored in DB.

| Field | Type | Description |
|---|---|---|
| `urls` | `list(string)` | STUN/TURN server URIs (e.g., `["turn:host:3478?transport=udp"]`) |
| `username` | `string` | Time-limited TURN username (`"timestamp:user_id"`) |
| `credential` | `string` | HMAC-SHA1 password (Base64) |
| `credential_type` | `"password"` | Always `"password"` for WebRTC |

### Connection State (client-side, pushed to server)

Tracked in JS, pushed to server on transitions.

| Browser State | User-Facing Label | Server Action |
|---|---|---|
| `new` | — | — |
| `connecting` | "Conectando..." | — |
| `connected` | "Conectado" | Transition session to `:active` |
| `disconnected` | "Reconectando..." | Start 5s grace timer |
| `failed` | "Falha na conexão" | Trigger retry or transition to `:failed` |
| `closed` | — | — |

### Retry State (client-side only)

| Field | Type | Description |
|---|---|---|
| `attempt` | `1-3` | Current retry attempt number |
| `maxAttempts` | `3` | Maximum retry attempts |
| `delays` | `[2000, 4000, 8000]` | Exponential backoff delays (ms) |
| `disconnectedTimer` | `timeout_id \| null` | 5s grace period timer for `disconnected` state |

## Existing Schema Changes

**None.** The `p2p_sessions` schema already has:
- Status enum including `connecting`, `active`, `failed`
- Valid transitions: `lobby → connecting`, `connecting → active`, `connecting → failed`

## Configuration Schema (new keys under `:retro_hex_chat`)

All TURN server configuration added to existing app config:

```elixir
# config/config.exs (compile-time)
config :retro_hex_chat,
  turn_realm: "retro-hex-chat",
  turn_credentials_lifetime: 86_400,
  turn_nonce_lifetime: 3_600_000_000_000,
  turn_default_allocation_lifetime: 600,
  turn_max_allocation_lifetime: 3_600,
  turn_permission_lifetime: 300,
  turn_channel_lifetime: 600

# config/runtime.exs (runtime)
config :retro_hex_chat,
  turn_listen_ip: {0, 0, 0, 0},
  turn_listen_port: 3478,
  turn_relay_ip: :auto,
  turn_relay_port_range: {49152, 65535},
  turn_listener_count: System.schedulers_online(),
  turn_auth_secret: :crypto.strong_rand_bytes(64),
  turn_nonce_secret: :crypto.strong_rand_bytes(64)
```
