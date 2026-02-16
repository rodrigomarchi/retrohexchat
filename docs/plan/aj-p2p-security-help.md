# Category AJ: P2P Security, Help & Polish

**Priority**: Yellow (High — security hardening and mandatory documentation)
**Dependencies**: AE (P2P Foundation), AF (P2P Lobby & Session UI), AG (WebRTC Signaling), AH (P2P File Transfer), AI (Audio/Video Calls)
**Existing**: None (new feature)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AJ1 | TurnCredentials module | New | `P2P.TurnCredentials` generates short-lived TURN credentials per RFC 5766: username = `"#{timestamp + ttl}:#{session_token}"`, credential = HMAC-SHA1 of username with shared secret. TTL: 1 hour. Used by AG4 ICE server config |
| AJ2 | TURN server configuration | New | App environment config for TURN server: host, port, shared secret, transport (UDP/TCP). Dev: optional (STUN-only works on localhost). Production: required for NAT traversal (~30% of connections). Compatible with Rel (Elixir TURN server) or coturn. Add `{:rel, "~> x.x"}` to mix.exs if using Rel. Ensure `force_ssl` is configured in production endpoint for HTTPS (required by WebRTC) |
| AJ3 | TURN-only privacy mode | New | User preference in `user_preferences.p2p_settings` JSONB: `turn_only: false` default. When enabled, `iceTransportPolicy: "relay"` is set in RTCPeerConnection config, forcing all traffic through TURN and hiding real IPs. Includes lobby-visible toggle checkbox: "Modo privado (TURN-only)" with description explaining the latency tradeoff. Warns if no TURN server configured |
| AJ4 | Session creation rate limit | New | Max 5 P2P session creations per 10 minutes per user. Uses existing RateLimit context. Enforced in P2P.Service before session creation. Error: 'Você criou muitas sessões. Tente novamente em X minutos' |
| AJ5 | Invite rate limit | New | Max 10 P2P invites per 30 minutes per user. Prevents invite spam. Enforced in P2P.Service. Error: 'Limite de convites atingido. Tente novamente em X minutos' |
| AJ6 | Signaling rate limit enforcement | New | Max 100 signaling messages per minute per session. Enforced in P2PSessionLive handle_event for p2p_signal pushEvents. Uses the interface defined in AG8. Excess messages dropped silently |
| AJ7 | Help topic: P2P Sessions | New | Features category topic covering: what P2P sessions are, how to create (/p2p, /call, /sendfile), lobby interaction, bilateral consent, timeouts, closing sessions. Cross-references: File Transfer, Audio/Video Calls |
| AJ8 | Help topic: File Transfer | New | Features category topic covering: how to send files, drag-and-drop, file limits (500MB, blocked types), progress tracking, cancellation, resume on disconnect. Cross-references: P2P Sessions |
| AJ9 | Help topic: Audio/Video Calls | New | Features category topic covering: audio calls, video calls, mute/camera toggle, device selection, audio→video upgrade, PiP, quality indicator. Cross-references: P2P Sessions |
| AJ10 | Help topic: Keyboard Shortcuts update | New | Update existing Keyboard Shortcuts help topic to include any P2P-related shortcuts (e.g., mute toggle, camera toggle, end call) |
| AJ11 | Help topic: Privacy Settings | New | Features category topic covering: TURN-only privacy mode, what it protects (IP address), tradeoffs (higher latency), how to enable (lobby checkbox or user preferences). Cross-references: P2P Sessions, Audio/Video Calls |
| AJ12 | Ignore/ban integration | New | When User A has ignored/blocked User B: P2P invite from B to A fails with generic error (not revealing the block). Already-active sessions between them are closed if a block is added mid-session. Integrates with existing Accounts ignore system |

## Dependencies Detail

- AJ1 (TURN credentials) is used by AG4 (ICE server config) — can be developed in parallel and integrated
- AJ2 (TURN config) is used by AJ1 (credentials need server info) and AJ3 (privacy mode needs TURN)
- AJ3 (privacy mode) depends on AJ2 (TURN must be configured) and AG2 (PeerConnection config)
- AJ4/AJ5 (rate limits) depend on AE7 (Service) and existing RateLimit context
- AJ6 (signaling rate limit) depends on AG8 (interface) and AF1 (LiveView enforcement)
- AJ7/AJ8/AJ9/AJ10/AJ11 (help topics) depend on all previous plans being designed (content accuracy)
- AJ12 (ignore integration) depends on AE4 (Policy) and existing Accounts ignore system

## Technical Notes

- TURN credentials (RFC 5766 HMAC-SHA1):
  ```elixir
  ttl = 3600  # 1 hour
  timestamp = System.system_time(:second) + ttl
  username = "#{timestamp}:#{session_token}"
  credential = :crypto.mac(:hmac, :sha, shared_secret, username) |> Base.encode64()
  ```
- TURN-only mode sends `iceTransportPolicy: "relay"` in RTCPeerConnection config — browser excludes host/srflx candidates
- Rate limit keys: `{:p2p_create, user_id}`, `{:p2p_invite, user_id}`, `{:p2p_signal, session_token}`
- Help topics go in `RetroHexChat.Chat.HelpTopics` (`apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`)
- Help topics must include "See Also" cross-references to related topics
- Ignore integration: subscribe to ignore events and close active P2P sessions when a block is added
- Privacy mode preference stored in `user_preferences.p2p_settings` JSONB column (field: `turn_only`, default: `false`). If `p2p_settings` key doesn't exist yet, add to existing JSONB column — no new migration needed
- Privacy mode UI: checkbox in lobby with label "Modo privado (TURN-only)" and description "Seu IP real não será exposto ao outro peer. Latência pode ser maior."
- TURN server: add `{:rel, "~> x.x"}` to mix.exs if using Rel (Elixir, self-hosted). Alternative: coturn (C, battle-tested) — configurable via app env
- Production HTTPS: ensure `force_ssl: [rewrite_on: [:x_forwarded_proto]]` is configured in endpoint (required for getUserMedia and WebRTC)
- Signaling rate limit: count per session per minute, not per user (both peers signal equally)

---

## Spec Command

```
/speckit.specify "P2P Security, Help & Polish for RetroHexChat.

PROBLEM: The P2P system (foundation, lobby, signaling, file transfer, audio/video) needs security hardening, rate limiting, privacy features, and mandatory help documentation before it can be considered complete. Without TURN credentials, ~30% of users behind symmetric NATs cannot connect. Without rate limiting, malicious users can spam session creation, invites, and signaling messages. Without TURN-only privacy mode, privacy-conscious users have no way to hide their IP addresses. Without help documentation, the P2P features violate Constitution Principle XI (mandatory documentation).

EXISTING CONTEXT: The full P2P stack is in place: SessionServer GenServer, lobby UI with bilateral consent, WebRTC signaling, file transfer via DataChannel, and audio/video calls. A signaling rate limit interface (behaviour/contract) is defined in the signaling layer. The RateLimit bounded context exists with established patterns for flood control. The Accounts context provides ignore/ban functionality. The HelpTopics module contains all existing help documentation. The user_preferences table has a message_settings JSONB column. The constitution (v1.3.0) recognizes the P2P bounded context and requires help documentation for all features.

USER JOURNEY — TURN CREDENTIALS: A user behind a symmetric NAT tries to establish a P2P connection. During the ICE gathering phase, only relay candidates succeed. The TurnCredentials module generates short-lived credentials (1-hour TTL, HMAC-SHA1 per RFC 5766) that are sent to the browser with the ICE server configuration. The TURN server authenticates the credentials and relays the WebRTC traffic. The P2P connection succeeds despite the restrictive NAT.

USER JOURNEY — PRIVACY MODE: A privacy-conscious user checks the 'Modo privado (TURN-only)' checkbox in the P2P lobby (or enables it in user preferences under p2p_settings.turn_only). When the WebRTC handshake begins, their RTCPeerConnection is configured with iceTransportPolicy: 'relay', forcing all traffic through the TURN server. Their real IP is never exposed to the peer. They accept slightly higher latency in exchange for IP privacy. If no TURN server is configured, a warning explains that privacy mode requires TURN.

USER JOURNEY — RATE LIMITING: A user tries to create their 6th P2P session in 10 minutes. The system rejects with 'Você criou muitas sessões. Tente novamente em X minutos'. A user sends rapid signaling messages (potential abuse): after 100 messages in a minute, excess messages are silently dropped.

USER JOURNEY — HELP: A new user presses F1 and navigates to the 'P2P Sessions' help topic. They learn how to create sessions with /p2p, /call, /sendfile, understand the lobby system, bilateral consent, and timeouts. 'See Also' links take them to 'File Transfer', 'Audio/Video Calls', and 'Privacy Settings' topics for detailed feature documentation.

ACTORS: All registered users interact with TURN credentials transparently. Privacy-conscious users opt into TURN-only mode. The RateLimit system enforces session and signaling limits. The Help system serves all users. The ignore/ban system protects users from unwanted P2P contact.

EDGE CASES: TURN server is down (P2P may still work via direct connection for non-symmetric NATs, but relay-dependent users fail with connection error). TURN credentials expire during active session (session continues — credentials only needed during ICE). Privacy mode enabled but no TURN server configured (warn user that privacy mode requires TURN, fall back to direct). Rate limit hit during legitimate burst (user waits for window to reset). User blocks peer during active P2P session (session closed immediately). Help topic references a feature that was modified in a later plan (keep help in sync).

NEGATIVE REQUIREMENTS: TURN shared secret must NEVER be exposed to the client — only computed credentials are sent. Rate limiting must be enforced server-side, not client-side. Signaling rate limit must NOT affect legitimate ICE trickle (100/min is generous for normal operation). Privacy mode must NOT be the default — users opt in understanding the latency tradeoff. Help topics must NOT be auto-generated — they must be hand-crafted with clear examples and accurate content. Ignore integration must NOT reveal the block reason to the blocked user.

SCOPE: In scope — TurnCredentials module (RFC 5766 HMAC-SHA1), TURN server app config (including Rel dependency in mix.exs and force_ssl production config), TURN-only privacy mode user preference (p2p_settings.turn_only) with lobby-visible toggle checkbox, session creation rate limit (5/10min), invite rate limit (10/30min), signaling rate limit enforcement (100/min), 5 help topics (P2P Sessions, File Transfer, Audio/Video Calls, Privacy Settings, Keyboard Shortcuts update), ignore/ban integration for P2P. Out of scope — TURN server deployment/operations, certificate management, DDoS protection beyond rate limiting, session recording/history persistence, admin controls for P2P."
```
