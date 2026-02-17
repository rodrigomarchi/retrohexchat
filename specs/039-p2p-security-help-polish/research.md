# Research: P2P Security, Help & Polish

**Feature**: 039-p2p-security-help-polish
**Date**: 2026-02-16

## R1: TURN Credential Generation — Already Implemented

**Decision**: Reuse existing `RetroHexChat.P2P.Turn.Auth.generate_credentials/2` and `RetroHexChat.P2P.ice_servers/1`.

**Rationale**: The full TURN server infrastructure already exists:
- `Turn.Auth.generate_credentials/2` generates RFC 5766 HMAC-SHA1 credentials with configurable TTL.
- `Turn.Config` reads all TURN params from application env (auth_secret, credentials_lifetime, listen_port, relay_ip).
- `P2P.ice_servers/1` returns properly formatted ICE server config with credentials.
- `P2PSessionLive` already calls `P2P.ice_servers/1` on "connecting" status change.
- `config/runtime.exs` already configures TURN listen/relay parameters.

**What's actually needed**: The TURN credential system is **already complete**. The spec describes it as "to be built" but the code already handles this. The `credentials_lifetime` is set to `86_400` (24h) in config — the spec says 1h (3600s). This is a config tweak, not new code.

**Alternatives considered**: None needed — the implementation matches RFC 5766 exactly.

## R2: ICE Transport Policy for Privacy Mode

**Decision**: Pass `iceTransportPolicy` option to `createPeerConnection()` in `webrtc.js`.

**Rationale**: The browser-native `RTCPeerConnection` constructor accepts `{ iceTransportPolicy: "relay" }` to force TURN-only connections. The change is:
1. Server sends a `turn_only: true/false` flag alongside `ice_servers` in the `p2p_start_offer`/`p2p_start_answer` events.
2. `webrtc.js` → `createPeerConnection(iceServers, options)` adds `iceTransportPolicy: "relay"` when `options.turnOnly` is true.
3. `WebRTCHook` passes the flag through from the LiveView event.

**User preference storage**: Use existing `message_settings` JSONB column in `user_preferences` table. Add a `p2p_settings` nested key: `%{"p2p_settings" => %{"turn_only" => false}}`. No migration needed — JSONB columns accept arbitrary keys.

**Alternatives considered**:
- New `p2p_settings` JSONB column: Rejected — unnecessary migration. The `message_settings` column was designed as a general-purpose JSONB store and already holds notification preferences.
- Separate `p2p_preferences` table: Rejected — over-engineering for a single boolean preference.

## R3: P2P Rate Limiting Strategy

**Decision**: Implement three separate ETS-based rate limiters in the P2P bounded context, following the existing `RateLimit.Limiter` pattern.

**Rationale**:
- **Session creation (5/10min)**: Checked in `P2P.Service.create_session/3` before policy check. Uses sliding window counter in ETS keyed by `user_id`.
- **Invite rate limit (10/30min)**: The session creation and invite are the same operation in the current architecture — `create_session` IS the invite (it calls `notify_peer`). So session creation rate limit already covers invites. We can set a single limit of 5 sessions/10min which implicitly limits invites.
- **Signaling rate limit (100/min)**: Implement `SignalingRateLimit` behaviour with an ETS-based module. Replace the `Noop` default in application config. The behaviour contract already exists at `RetroHexChat.P2P.SignalingRateLimit`.

**Pattern**: The existing `RateLimit.Limiter` uses a token-bucket algorithm with ETS. For P2P, a simpler sliding-window counter is more appropriate since the windows are minutes, not seconds. Use an ETS table initialized in the P2P application supervisor.

**Alternatives considered**:
- Reuse `RateLimit.Limiter` directly: Rejected — it's tuned for messages/sec with mute duration. P2P needs minutes-scale windows.
- Database-backed counters: Rejected — adds latency and DB load for what should be fast in-memory checks.

## R4: Ignore/Ban Integration

**Decision**: The P2P Policy module already checks ignore/block status via `check_no_block/2`. Extend to also close active sessions on new block events.

**Rationale**:
- `P2P.Policy.can_create?/2` already calls `check_no_block/2` which queries `ignore_list_entries` table.
- For active session closure on block: subscribe to ignore-list change events (PubSub on `"user:#{nickname}"`) in `P2PSessionLive`, or add a hook in the ignore command handler that finds and closes active P2P sessions.
- The error message for blocked users should be generic: change `"Session cannot be created"` to `"Usuário não disponível"` (user unavailable) — currently it says "Session cannot be created" which doesn't reveal block status but isn't the generic message the spec requires.

**Alternatives considered**:
- Real-time PubSub listener in SessionServer: Rejected — SessionServer doesn't know about ignore lists and shouldn't depend on Accounts context.
- Polling: Rejected — wasteful and non-reactive.

## R5: Help Topics Structure

**Decision**: Add 4 new topics to `HelpTopics.Features` module and update `HelpTopics.KeyboardShortcuts`. Follow existing topic structure (id, title, category, keywords, content with HTML).

**Rationale**: Existing pattern is clear:
- Each category has its own module under `HelpTopics.*`.
- Topics are maps with `id`, `title`, `category`, `keywords`, `content` fields.
- "See Also" uses `<a href="#" data-help-topic="topic-id">` links.
- New topics: `feature-p2p-sessions`, `feature-file-transfer`, `feature-audio-video-calls`, `feature-privacy-settings`.
- Update: `keyboard-shortcuts` topic to include P2P shortcuts (if any browser-allowed ones exist).

**Alternatives considered**: None — the pattern is well-established.

## R6: Session Creation vs Invite — Clarification

**Decision**: In the current architecture, `P2P.create_session/3` IS the invite mechanism. There is no separate "invite" action. Creating a session automatically calls `notify_peer` which broadcasts a `p2p_invite` event.

**Implication**: The spec's FR-007 (invite rate limit 10/30min) is effectively the same as FR-006 (session creation rate limit 5/10min). The tighter limit (5/10min) subsumes the more generous one. We implement a single session creation rate limit that covers both.

## R7: User Preference Storage for Privacy Mode

**Decision**: Store `turn_only` preference in `message_settings` JSONB under a `p2p_settings` nested key.

**Read path**: `P2PSessionLive.mount/3` reads user preferences and passes `turn_only` flag to the lobby component and to ICE server events.

**Write path**: The lobby checkbox sends a `toggle_privacy_mode` event. The LiveView handler updates `message_settings.p2p_settings.turn_only` via the existing preference persistence mechanism.

**No migration needed**: JSONB columns accept arbitrary nested keys.
