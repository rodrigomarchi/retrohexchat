# Category AE: P2P Foundation

**Priority**: Red (Critical — infrastructure for all P2P features)
**Dependencies**: None
**Existing**: None (new bounded context)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AE1 | P2P bounded context scaffold | New | Create `RetroHexChat.P2P` module tree: `p2p.ex` (public API facade), `service.ex`, `policy.ex`, `queries.ex` |
| AE2 | p2p_sessions schema & migration | New | Ecto schema with fields: token, creator_id, peer_id, status (enum: pending/lobby/connecting/active/closed/expired/failed), session_type (enum: generic/file_transfer/audio_call/video_call), metadata (map), closed_at, closed_reason. Migration with unique index on token, indexes on creator_id, peer_id, status, inserted_at |
| AE3 | SessionToken module | New | `Phoenix.Token.sign/4` for session tokens encoding creator_id, peer_id, created_at. 24h expiration. `generate/2` and `verify/2` functions |
| AE4 | Policy module | New | Authorization rules: registered-only (no guests), ignore/ban integration (generic error on block), no self-P2P, no duplicate active sessions between same peers |
| AE5 | SessionServer GenServer | New | One GenServer per active P2P session. State: session_id, token, creator_id, peer_id, status, lobby_messages, peers_present, missed_heartbeats. Handles: join, leave, state transitions, lobby messages, action requests/responses. Lobby inactivity: sends warning broadcast at 10min, expires session at 15min |
| AE6 | DynamicSupervisor + Registry | New | `P2P.Supervisor` (rest_for_one) containing `P2P.SessionRegistry` and `P2P.DynamicSupervisor`. via_tuple registration. Add to application supervision tree |
| AE7 | Service orchestration | New | `P2P.Service` with `create_session/2`, `accept_invite/2`, `close_session/2`, `get_session/1`. Coordinates Policy check → DB insert → GenServer start → PubSub notification |
| AE8 | Queries module | New | Ecto queries: find by token, active sessions for user, active session between two users, sessions by status, expired sessions query |
| AE9 | Session state machine | New | State transitions enforced in SessionServer: pending→lobby (peer joins), lobby→connecting (mutual accept), connecting→active (WebRTC established), any→closed (graceful), pending→expired (timeout), connecting→failed (handshake failure) |
| AE10 | Stale session cleanup | New | Periodic task (hourly) to expire stale sessions: pending >5min, lobby >15min inactive. Updates DB status and stops GenServer |

## Dependencies Detail

- AE1 is the scaffold — all other items depend on it
- AE2 (schema) is needed by AE3, AE7, AE8
- AE4 (policy) is needed by AE7 (service calls policy before creating)
- AE5 (GenServer) depends on AE6 (supervisor/registry)
- AE7 (service) depends on AE4, AE5, AE8
- AE9 (state machine) is implemented within AE5
- AE10 (cleanup) depends on AE5, AE8

## Technical Notes

- Follow existing `ChannelServer` pattern in `apps/retro_hex_chat/lib/retro_hex_chat/channels/channel_server.ex`
- Supervision tree: `P2P.Supervisor` (rest_for_one) → Registry + DynamicSupervisor
- Registry via_tuple: `{:via, Registry, {P2P.SessionRegistry, {:session, token}}}`
- Session tokens use `Phoenix.Token.sign/4` with "p2p_session" salt, encoding `%{creator_id: id, peer_id: id, created_at: timestamp}`
- PubSub topic: `"p2p:#{token}"` for session events, `"user:#{nickname}"` for invitations
- State transitions must be enforced server-side — no client can skip states
- Lobby timeout uses two `Process.send_after/3` calls: one at 10min for warning broadcast, one at 15min for expiration
- Stale cleanup can use `Process.send_after/3` or a dedicated `Task` with `:timer.apply_interval`
- Policy must check ignore list without revealing to initiator that they are blocked (generic error)
- No UI, no WebRTC — this is pure domain infrastructure

---

## Spec Command

```
/speckit.specify "P2P Foundation for RetroHexChat.

PROBLEM: RetroHexChat has no peer-to-peer infrastructure. Before any P2P feature (file transfer, audio/video calls) can be built, the foundational domain layer must exist: a new bounded context, database schema, session lifecycle management via OTP processes, authorization policies, and session token generation. Without this foundation, there is no way to create, track, or manage P2P sessions between users.

EXISTING CONTEXT: The project has 7 bounded contexts (Accounts, Chat, Channels, Services, Presence, Commands, RateLimit). The OTP process-per-channel pattern in ChannelServer (DynamicSupervisor + Registry + GenServer) serves as the direct architectural template. Phoenix.Token is already used for user authentication. The ignore/ban system exists in the Accounts context. PubSub is used extensively for channel and user events. Constitution v1.3.0 formally recognizes the P2P bounded context.

USER JOURNEY — SESSION CREATION: A registered user types '/p2p mario' in the chat. The system validates: both users are registered, neither has blocked the other, no active P2P session exists between them. A p2p_sessions record is created in the database with status 'pending'. A GenServer is started via DynamicSupervisor, registered in the P2P.SessionRegistry. A session token is generated using Phoenix.Token. A notification is sent to mario via PubSub on 'user:mario'. Both users receive the lobby URL '/p2p/:token'. The session awaits mario's response for up to 5 minutes before expiring.

USER JOURNEY — SESSION LIFECYCLE: When both peers navigate to '/p2p/:token', the GenServer transitions from 'pending' to 'lobby'. Peers can chat in the lobby and negotiate actions. After 10 minutes of lobby inactivity, both peers receive a warning: 'Sessão expira em 5 minutos por inatividade'. At 15 minutes, the session expires. When both agree on an action (file transfer, call), the state transitions to 'connecting'. After WebRTC handshake succeeds, state becomes 'active'. Either peer can close the session gracefully, or it may expire due to inactivity. The GenServer stops and DB record is updated with closed_at and closed_reason.

ACTORS: Registered users only — guests cannot create or join P2P sessions. Both creator and peer have equal capabilities within a session. The system (cleanup task) acts to expire stale sessions.

EDGE CASES: User tries to create session with themselves (reject). User tries to create session with a guest (reject). User tries to create duplicate session with same peer (reject). Target user is offline (session created in pending, notification queued). GenServer crashes mid-session (supervisor restarts, state recovered from DB). Multiple rapid session creation attempts (rate limiting added in a later plan). Session token reuse after expiration (verify/2 returns error). Cleanup task finds GenServer already stopped but DB still pending (update DB only).

NEGATIVE REQUIREMENTS: No UI components in this plan — purely domain infrastructure. No WebRTC code — signaling is a separate plan. No TURN/STUN server setup — covered in a security plan. The P2P context must NOT depend on Phoenix or web concerns (umbrella separation). GenServer state must NOT be the source of truth for persistence — DB is authoritative, GenServer is hot cache. Policy must NOT reveal ignore/block status to the blocked user.

SCOPE: In scope — P2P module scaffold, p2p_sessions Ecto schema and migration, SessionToken module, Policy module with authorization rules, SessionServer GenServer with state machine (including lobby 10-minute inactivity warning and 15-minute expiration), DynamicSupervisor and Registry setup, Service orchestration module, Queries module, stale session cleanup task. Out of scope — P2P LiveView UI, command handlers, WebRTC signaling, file transfer protocol, audio/video media, TURN credentials and rate limiting, help documentation."
```
