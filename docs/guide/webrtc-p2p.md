# WebRTC / P2P

Read when touching calls, signaling, TURN, file transfer, or call recovery.

Part of the [Agent Guide](../AGENT-GUIDE.md) (§8). Section numbers there are stable — `§8` still means this file.

---

**Naming policy — "lobby" is the DOMAIN, not a page.** `RetroHexChat.Lobby` is the
P2P-session bounded context; the PubSub topic `"lobby:#{token}"`, the `lobby_*`
events, the `lobby-*` DOM ids and the `Lobby*` module names all refer to that
domain concept. There is NO standalone lobby page — `/lobby/:token` only
redirects to `/chat`, where P2P sessions live (invite card in the PM, `p2p-*`
desktop windows). Do not invent or search for a lobby LiveView/page.

### 8.1 Session model

- **Session status is a 7-state machine:** `pending → lobby → connecting → active` plus
  terminal `closed / expired / failed`. Enforced as a DB `status` string column with changeset
  validation; `closed_at` and `closed_reason` are required whenever terminal. Any non-terminal
  state can jump to `closed`. Terminal sessions are retained indefinitely for audit (no purge).
- **Duplicate-session prevention is a DB query, not a Registry check**
  (`WHERE (creator=A AND peer=B) OR (creator=B AND peer=A)` filtered to non-terminal). The DB
  is authoritative because a crashed-but-not-yet-restarted GenServer would make a Registry
  check lie.
- **Session tokens are `Phoenix.Token.sign/verify`** (salt `"p2p_session"`, 24h max_age)
  embedding `%{creator_id, peer_id, session_id}` so authorization needs no DB lookup. The domain
  app reads the signing secret from `Application.get_env(:retro_hex_chat, :p2p_token_secret)`
  populated at startup — it must NOT depend on the web endpoint module.
- **`create_session` IS the invite.** No separate invite action; creating a session broadcasts
  `p2p_invite`, delivered by reusing `send_private_message` (persisted, appears in PM history).
  A single session-creation rate limit (5/10min) subsumes the invite limit. P2P rate limiting is
  its own ETS sliding-window (minutes-scale), deliberately NOT the message `RateLimit.Limiter`.
- **Block/ignore reuse:** P2P policy checks blocks by querying the existing
  `ignore_list_entries` table directly (type `:all`) rather than depending on Chat runtime
  state — self-contained, one source of truth.

### 8.2 Signaling & TURN

- **Self-hosted STUN/TURN runs inside the BEAM.** The `elixir-webrtc/rel` TURN server was
  *extracted* into `RetroHexChat.P2P.Turn.*` rather than added as a dep (`rel` is a standalone
  OTP app that collides with Phoenix — own Application, port 4000). Only new dep is `ex_stun`,
  pinned `~> 0.1` (0.2.x has breaking API changes). A Docker sidecar was rejected (violates
  "same BEAM VM"). TURN credentials are RFC 5766 HMAC-SHA1, generated in Phoenix.
- **The server is a blind signaling relay.** Signaling is stateless server-side: JS `pushEvent`
  → LiveView `handle_event` → `PubSub.broadcast("p2p:token")` → peer LiveView → `push_event` →
  peer JS. The server never inspects SDP; the SessionServer only learns of `connecting → active`
  transitions.
- **The session creator is always the offer initiator** — server sends `p2p_start_offer` only to
  the creator on `connecting`, preventing simultaneous-offer glare.
- **TURN-only privacy mode** = pass `{iceTransportPolicy: "relay"}` to the browser
  `RTCPeerConnection`; server sends a `turn_only` flag alongside `ice_servers`.

### 8.3 JS architecture (hook = wiring, lib = logic)

This separation is Principle IV and is enforced.

- **`webrtc.js` owns the single `RTCPeerConnection`** multiplexing all data channels (file
  transfer, game data) — shared by media+file+game, living in the host backbone, **never** in an
  island. It exposes pure functions (createOffer/Answer, ICE, track management) and is the one
  source of PC truth.
- **Sibling hooks never touch the PC directly.** `WebRTCHook` dispatches the PC reference via
  `CustomEvent` (`media_pc_ready`, `ft_channel_ready`); `FileTransferHook`/`MediaHook` listen.
  New media/data logic goes in its own lib module (`media.js`), never bloating `webrtc.js` or a
  hook.
- Audio→video upgrade rides the native `negotiationneeded` event through the existing
  `p2p_signal` channel — no custom upgrade protocol. Device switching uses `replaceTrack()` (no
  renegotiation). Codec ordering via `setCodecPreferences()`, never SDP munging.
- **Single-offerer negotiation** (only the initiator emits offers) is host/backbone logic — an
  island only *requests* media via push_events to its hook. Do not move this into an island.
- **Bidirectional video** (both enable at once, real RTP `track.muted === false`) is the scenario
  that most regresses — always run it after touching media.

### 8.4 File transfer protocol

- **Custom binary protocol over one ordered RTCDataChannel** (`arraybuffer`, named
  `"filetransfer"`, created by the initiator during the offer phase). Byte 0 = message type;
  chunk messages carry a 4-byte big-endian Uint32 index then ≤64 KB payload. JSON-only rejected
  (base64 +33%); multiple channels rejected (lifecycle complexity).
- **Chunk size 64 KB.** Backpressure via `bufferedAmount`: pause above 1 MB, resume below 256 KB.
  ACK-per-chunk rejected — SCTP already guarantees ordered reliable delivery.
- **Resume uses a `have-chunks` index array** (Uint32Array), not a byte offset, because
  disconnection leaves non-contiguous gaps. Receiver stores chunks index-keyed (O(1) out-of-order
  insert), assembles a Blob at the end.
- **SHA-256 integrity is mandatory** (sender hashes before, receiver hashes assembled buffer).
- **File metadata flows over the DataChannel, never PubSub** — consent reuses the existing
  `request_action("file_transfer")` → `respond_action` flow, but nothing about the file touches
  the server. Extension blocklist is env-configurable; MIME checking rejected (browser MIME is
  extension-derived).

### 8.5 Failure & recovery

Calls fail constantly in the field; the recovery protocol is part of the feature, not polish.

- **`disconnected` is not `failed`.** ICE `disconnected` is often transient and returns to
  `connected` on its own. Never restart on it: start a grace period, show feedback immediately
  (`lobby_recovery_pending` → recovery state `:reconnecting`), and consult `getStats()` before
  escalating — if packets are still moving, defer. Only `failed` earns an ICE restart.
- **The answerer never recovers by itself.** P2P is single-offerer, so an answerer-initiated
  recovery must become an explicit request to the initiator (`lobby_renegotiate` carrying
  `connection_reset`), not a local PC recreation that then waits for an offer that never comes.
  This is what makes two simultaneous manual `Retry` clicks idempotent.
- **Signaling carries an epoch.** Signals ship `signalingEpoch`, `offer_id` and `connection_reset`;
  answers and candidates from an old epoch are discarded, and a recovery offer with a new epoch +
  `connection_reset` is the answerer's licence to recreate its PC. `validate_signal/1` checks SDP /
  ICE-candidate shape and size and preserves recovery metadata; `lobby_renegotiate` goes through
  the signaling rate limit like any other signal.
- **Renegotiation ≠ rejoin.** Conference must distinguish renegotiating inside the same
  `PeerServer` from a full rejoin against a new WebRTC endpoint. When the participant's SFU peer
  died, `request_offer` answers `rejoin_required`; the hook then closes the local PC, drops pending
  candidates/offers and stale remote tiles, stops screen share, and re-runs `group_call_join` with
  `previous_participant_id` + `rejoin_epoch`. Republish local tracks whenever the PC changes.
- **`PeerServer` monitors the channel, never links to it.** A link made an SFU endpoint crash take
  down the very signaling channel needed to retry — recovery became unreachable. Same shape as
  [`liveview-islands.md` §6.6](liveview-islands.md): a supervision edge that kills your escape hatch.
- **A hook `destroyed()` is not a voluntary leave.** `GroupCallWebRTCHook.destroyed()` sending
  `group_call_leave` turned every reload/deploy into a terminal exit. Unexpected teardown must go
  through `disconnect_call/4` (status `disconnected`, reconnect window preserved); only the explicit
  LiveView/confirmation path is terminal. `terminate/2` marks unexpected closes accordingly.
- **Reconnect needs an application-level rehydrate.** Phoenix rejoins channels automatically, but
  call state living outside the channel does not come back. `GroupCallEvents.rehydrate/1` rebuilds
  `@group_call` for a non-terminal participant in an already-rejoined channel; background/restore
  channel joins must call it *after* updating `session.channels`, so channels restored after mount
  are covered. Rehydrate requires an identified session.
- **Fault injection is E2E-only and flag-compiled.** The destructive path (`chat-call-fault-injection.spec.ts`)
  uses a real in-browser delay injected into `setRemoteDescription` and a
  `POST /api/e2e/group-call-peer/terminate` route that is only *compiled* under
  `config :retro_hex_chat, e2e_fault_injection?: true` and 404s at runtime otherwise. Don't mock the
  Phoenix protocol. Injected failure must wait for the `:DOWN` to be processed by `RoomServer`
  before the test clicks `Retry`, or the click races the async state update.
- **Don't chase real packet loss locally.** CDP `Network.emulateNetworkConditions` documents
  packet loss, but local Chromium will not transition ICE deterministically within a test budget.
  That scenario belongs in a netem / Network Link Conditioner lab, not the local suite.
