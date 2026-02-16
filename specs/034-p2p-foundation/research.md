# Research: P2P Foundation

**Feature**: 034-p2p-foundation | **Date**: 2026-02-16

## R1: GenServer State Machine Pattern for Session Lifecycle

**Decision**: Use GenServer with `Process.send_after/3` for timeout-driven state transitions, mirroring the ChannelServer pattern. State struct holds current status, peers present, and timer references.

**Rationale**: The existing ChannelServer in `channels/server.ex` uses exactly this approach — `restart: :transient`, `via_tuple` registration, `Process.send_after` for timed operations. The P2P session state machine (pending → lobby → connecting → active → terminal) maps naturally to GenServer state with `handle_info` for timeout messages.

**Alternatives considered**:
- `:gen_statem` — More explicit state machine semantics but overkill for 7 states with simple transitions. Would break consistency with the existing ChannelServer pattern.
- Finite state machine library (e.g., `fsmx`) — Adds a dependency for minimal benefit. Plain GenServer state + pattern matching is idiomatic Elixir.

## R2: Session Token Strategy

**Decision**: Use `Phoenix.Token.sign/4` and `Phoenix.Token.verify/4` with a dedicated salt `"p2p_session"`, embedding `%{creator_id: id, peer_id: id, session_id: db_id}` as the token data. Token max_age: 86_400 seconds (24 hours).

**Rationale**: Phoenix.Token is already used for NickServ identity verification (`session_controller.ex`). It provides HMAC-SHA256 signing with built-in expiration. The token embeds enough data to verify authorization without a DB lookup on every access.

**Alternatives considered**:
- Raw UUID token stored in DB — Simpler but requires DB lookup on every token verification. Phoenix.Token is self-verifying.
- JWT with `joken` — External dependency, more complex. Phoenix.Token is sufficient for server-side-only verification.

**Umbrella concern**: Phoenix.Token requires an `endpoint` or a `secret_key_base`. The domain app can accept the secret as a config parameter rather than depending on the web endpoint module directly. Pattern: `Application.get_env(:retro_hex_chat, :p2p_token_secret)` populated from the endpoint's secret at startup.

## R3: Duplicate Session Detection (Bidirectional Pair Check)

**Decision**: Use a database query that checks for active sessions between user pair (A, B) regardless of direction. Query: `WHERE (creator_id = A AND peer_id = B) OR (creator_id = B AND peer_id = A)` filtered to non-terminal statuses.

**Rationale**: The spec requires bidirectional uniqueness (FR-004). A DB-level check with proper indexing is authoritative and race-condition resistant (combined with a unique constraint on active pairs if needed).

**Alternatives considered**:
- Registry-level check — Fast but not authoritative; misses sessions where GenServer crashed and hasn't been restarted yet.
- Sorted pair key (always store `min(A,B), max(A,B)`) — Cleaner for unique constraints but adds indirection. The query approach is simpler and the DB is authoritative per Constitution IX.

## R4: Block/Ignore Check Integration

**Decision**: P2P Policy module will call `RetroHexChat.Chat.IgnoreList.ignored?/3` with ignore_type `:all` to check if either user has blocked the other. The ignore list must be loaded from DB via the Accounts session or a direct query.

**Rationale**: The existing ignore system in `chat/ignore_list.ex` already supports type-based filtering. Using `:all` type ensures any block relationship is caught. The function is in the Chat context but operates on pure data — no web dependency.

**Alternatives considered**:
- New P2P-specific block check — Duplication. The ignore system already models this relationship.
- Behaviour-based abstraction — Over-engineering for a single cross-context call.

**Note**: For the initial implementation, P2P Policy will query ignore_list_entries directly via Ecto to avoid tight coupling to the Chat context's runtime state. This keeps the P2P context self-contained while reusing the same DB table.

## R5: Periodic Cleanup Task Pattern

**Decision**: Implement as a GenServer with `Process.send_after/3` for periodic execution (every 60 seconds). On each tick, query the DB for non-terminal sessions older than their timeout threshold, update them to "expired", and attempt to stop any running GenServer processes.

**Rationale**: This follows the OTP way — a supervised process that self-schedules. No external cron dependency. The ChannelServer uses `Process.send_after` for its own timed operations; the cleanup task extends this pattern.

**Alternatives considered**:
- `Oban` job scheduler — External dependency, overkill for a single periodic task.
- `:timer.send_interval/2` — Works but `Process.send_after` is more idiomatic in OTP and allows dynamic interval adjustment.
- Application startup cleanup only — Insufficient; sessions can become stale during runtime.

## R6: PubSub Topic for P2P Notifications

**Decision**: Use `"p2p:#{token}"` for session-specific events (matching Constitution VII) and `"user:#{nickname}"` for invitation notifications (matching existing convention).

**Rationale**: Constitution v1.3.0 already defines `"p2p:#{token}"` as the PubSub topic pattern. User notifications use the established `"user:#{nickname}"` pattern.

**Alternatives considered**:
- `"p2p:#{sorted_nicks}"` — Considered but the token-based topic is more precise (one topic per session, not per user pair) and aligns with the constitution.

## R7: Crash Recovery Strategy

**Decision**: When the supervisor restarts a crashed SessionServer, `init/1` loads the session state from the database (DB is authoritative). If the DB record is in a terminal state, the GenServer stops immediately with `:ignore`. If in an active state, the GenServer resumes with reset timers.

**Rationale**: Constitution IX mandates hot/cold separation with DB as authoritative. The ChannelServer follows this pattern in `load_persisted_state/1`. The P2P SessionServer does the same.

**Alternatives considered**:
- ETS-backed state persistence — Faster recovery but ETS is lost on node restart. DB is the correct authoritative source.
- No recovery (just expire) — Wastes valid sessions that had a transient process crash.
