# P2P and conference — handshake and resilience map

This document maps how P2P calls and conference calls are implemented, which
resilience mechanisms exist, and where a user can still get stuck in a broken
flow. The product contract for surfaces and windows is in
[`guide/surfaces.md`](../guide/surfaces.md).

The durable rules that came out of this map — `disconnected` is not `failed`,
signaling epoch, renegotiate versus rejoin, `PeerServer` monitoring the channel —
live in `docs/AGENT-GUIDE.md` section 8.5. This document holds the technical
inventory: which files take part in each path and what the tests already cover.

## Main inventory

### P2P

Frontend:

- `apps/retro_hex_chat_web/assets/js/lib/p2p/webrtc.js`
- `apps/retro_hex_chat_web/assets/js/lib/p2p/media.js`
- `apps/retro_hex_chat_web/assets/js/lib/p2p/rtc_media_hook_factory.js`
- `apps/retro_hex_chat_web/assets/js/lib/p2p/signaling_channel.js`
- `apps/retro_hex_chat_web/assets/js/hooks/lobby/lobby_webrtc_hook.js`
- `apps/retro_hex_chat_web/assets/js/hooks/lobby/lobby_media_hook.js`

Backend, channel and LiveView:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/channels/p2p_channel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/p2p_live.ex` — the session,
  mounted at `/p2p/:token`, at `/play/:game/:token` and inside the chat window
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_live/events.ex` — the
  session's event adapter (was `chat_live/p2p_session_events.ex`)
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_read_model.ex` —
  what the chat knows about a session the reader is not in
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex` —
  what remains in the chat: invite, window and session switch
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_live/components/p2p_media_island.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/p2p_live/components/p2p_session_console.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/service.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/session_server.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/join_token.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/policy.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/queries.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/lobby/schema/session.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/p2p/p2p.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/p2p/signaling_rate_limit.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/p2p/signaling_rate_limit/ets.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/*`

### Conference

Frontend:

- `apps/retro_hex_chat_web/assets/js/hooks/group_call/group_call_prejoin_hook.js`
- `apps/retro_hex_chat_web/assets/js/hooks/group_call/group_call_webrtc_hook.js`

Backend and LiveView:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/channels/group_call_channel.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/group_call_events.ex`
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/group_call/*`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/room_server.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/peer_server.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/rtp_forwarder.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/config.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/join_token.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/rate_limiter.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/policy.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/schema/room.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/schema/participant.ex`
- `apps/retro_hex_chat/lib/retro_hex_chat/group_call/schema/track.ex`

## P2P — current architecture

### Model

P2P uses a single persistent `RTCPeerConnection` per session. That PC carries:

- audio/video;
- `RTCDataChannel` `filetransfer`;
- `RTCDataChannel` `gamedata`;
- per-facet stats, derived from the same PC.

The backend sees no media and no file/game data. It sees:

- session creation and teardown;
- policies on who can invite/accept;
- presence of the two LiveViews;
- readiness of the WebRTC hooks;
- relay of SDP/ICE messages over PubSub;
- visual state and persisted system messages.

### Durable states and UI states

Persistence in `Lobby.Schema.Session`:

- `pending`
- `lobby`
- `connected`
- `closed`
- `expired`
- `failed`

Approximate LiveView state:

- `nil`
- `:invite_sent`
- `:joining`
- `:connecting`
- `:connected`
- `nil`

Note: `:connecting` is a UI/assign state; it does not exist as a persisted
status. The persisted status `lobby` covers the interval between acceptance and
the WebRTC connection.

### Happy P2P handshake

1. The creator starts P2P from the PM or a command.
2. `Lobby.Service` creates a `pending` session and the invite (the PM) goes out
   immediately — creating the session IS inviting. The creator lands in the
   `App.P2PLive` starting room, in `:invite_sent`; the WebRTC anchor does not
   mount yet.
3. The peer accepts the invite from the PM/header; that is the consent, and it
   opens the same starting room — `P2PLive` takes the seat on mount.
4. `Lobby.SessionServer` marks both sides as joined and transitions to
   `lobby`.
5. Each side picks devices and presses `[Ready]`. Only then does the
   `#lobby-webrtc` anchor mount, carrying the `session_token` and the
   `Lobby.JoinToken` that the hook uses to join the `p2p:<session_token>`
   channel. The join reply already carries the replay: joining the channel is,
   by itself, saying "I am listening and may have missed something".
6. Each hook sends `lobby_webrtc_ready` — this one still goes to the LiveView,
   because it is the "the hook mounted" half of what `[Ready]` promises.
7. `Lobby.SessionServer.maybe_start_signaling/1` only starts signaling when:
   the status is `lobby` or `connected`, signaling has not started yet and both
   sides are `webrtc_ready`.
8. `lobby_start_signaling` reaches both. The peer already receives
   `lobby_start_answer` and builds the PC (the first offer is dropped if it is
   not listening), but stays in the room. The creator gets `[Start]` enabled.
9. The creator presses `[Start]`: `lobby_start_offer` goes out to them and the
   `lobby_session_start` broadcast takes both out of the room.
10. The initiator creates the PC, data channels and offer.
11. The offer travels via the `lobby_signal` event **on the** `p2p:<session_token>`
    **channel**; `P2PChannel` validates it (`Calls.SignalValidation`), applies
    the rate limit, records it for replay and relays it via PubSub
    `lobby:<token>` — the channel on the other side pushes it to that browser.
12. The answerer applies the remote offer, drains pending ICE, creates the
    answer and sends `lobby_signal` over the same channel.
13. The initiator applies the answer, drains pending ICE and finishes
    negotiation.
14. ICE candidates are exchanged; candidates that arrive early stay in
    `pendingIceCandidates` until there is a `remoteDescription`.
15. When `connectionState` becomes `connected`, each hook sends
    `lobby_connected` (to the LiveView: it is session lifecycle, not wire);
    the LiveView transitions the session to `connected`, opens the
    console and fires `lobby_media_pc_ready`.
16. `LobbyMediaHook` drains pending commands and auto-starts media according to
    the `media_mode` chosen in setup.

### P2P negotiation

The `LobbyWebRTCHook` hook uses a single-offerer model:

- the creator/initiator is the only peer that sends offers;
- the answerer never creates an offer directly;
- an answerer that adds tracks calls `lobby_renegotiate`;
- the initiator receives `lobby_renegotiate`, creates recvonly transceivers if
  needed and sends a new offer;
- data channels are created early by the initiator to avoid an extra
  renegotiation later.

This choice is consistent with the recommendation to avoid glare, but it implies
an obligation: any recovery started by the answerer must notify the initiator
so that it generates a new offer.

### P2P media

`LobbyMediaHook` is created by `createRtcMediaHook`. It is responsible for:

- capturing camera/microphone;
- joining receive-only without capturing media;
- attaching the local/remote stream to the elements;
- applying mute/camera off;
- switching device;
- screen share via `replaceTrack`/restore;
- publishing `lobby_media_call_started`, `lobby_media_call_ended`,
  `lobby_media_devices`, `lobby_media_quality`, `lobby_media_fallback`;
- republishing local tracks when the PC is replaced;
- the stalled remote video watchdog.

`P2PMediaIsland` is the stateful LiveView point that:

- keeps local call state;
- calls `Lobby.set_media`;
- receives and propagates peer state;
- surfaces peer media automatically when the other side starts;
- ends receive-only when the peer stops all media;
- syncs console, status bar and summary.

`media.js` centralizes:

- stable audio/video/screen constraints;
- permission/device error classification;
- bitrate/framerate profiles;
- codec preference H264 > VP8 and Opus;
- per-facet derived stats;
- the defensive `attachMediaStream` helper.

### P2P resilience already implemented

- Setup before mounting WebRTC avoids signaling before consent.
- The readiness gate on both hooks avoids losing the first offer.
- PubSub on `lobby:<token>` with a stale-token filter in the LiveView avoids
  applying an event from an old session.
- P2P signaling has a per-user rate limiter.
- An offer received before the PC is buffered on the answerer.
- An ICE candidate received before the remote description is buffered.
- `connectionState` and `iceConnectionState` are observed; `disconnected`
  enters a grace period and `failed` starts recovery immediately.
- On entering `connection_disconnected` or `ice_disconnected`, the hook publishes
  `lobby_recovery_pending`; the UI shows reconnecting feedback during the
  grace period, without firing a restart before the stats-based decision.
- During `disconnected`, the hook compares `getStats()` snapshots before/after
  the grace period. If bytes/packets/messages still advance, it defers the retry
  up to a small limit; once they stop advancing, normal recovery fires.
- Automatic retry is limited to 3 attempts with 2s, 4s, 8s backoff.
- An automatic retry started by the answerer sends `lobby_renegotiate` with
  `recover`, `epoch`, `attempt` and `connection_reset`; the initiator generates a
  new offer instead of leaving the answerer waiting.
- `lobby_signal` carries `epoch`, `offer_id` and `connection_reset`; SDP/ICE from
  an old epoch or offer are dropped.
- `SessionServer` keeps an in-memory snapshot of the last SDP, the last ICE
  candidates per role and the last `lobby_renegotiate`; the hook can request
  `lobby_signal_replay` on the channel when startup/reconnect did not receive a
  critical message — and the channel join itself already returns the replay, so
  an automatic Phoenix rejoin after a socket drop recovers on its own.
- P2P replay is idempotent in the browser: offers/answers/candidates already
  applied are ignored by `offer_id`, SDP or ICE candidate key.
- The P2P stats panel shows recovery and handshake diagnostics:
  state, reason, trigger, attempt, signaling epoch and current offer id.
- The answerer resends `lobby_renegotiate` with a short backoff until it receives
  a new offer; if no offer arrives after the limit, it enters coordinated
  recovery instead of waiting indefinitely.
- Manual retry (`p2p_retry_connection`) broadcasts a restart to both peers.
- Every `lobby_restart` carries fresh ICE servers, role and `turn_only`, so the
  hook rebuilds the PC with the current policy.
- The stalled remote video watchdog first tries renegotiation/ICE restart and
  then escalates to a coordinated restart.
- The watchdog also covers the "remote video expected and no track arrived"
  case, using the `lobby_media_peer_media` event.
- `SessionServer` has a 30s LiveView rejoin grace, for a refresh or a short
  reconnect.
- A second window of the same person **takes over** the session:
  `Lobby.join_session/3` with `takeover: true`, which `SessionServer` treats as a
  disconnect followed by a join — seat released, readiness on that side reset,
  replay cleared and peer notified. The same gate that rebuilds media after a
  socket drop rebuilds it here. The displaced window receives
  `{:lobby_slot_taken, token}`, stops rendering the anchor (the hook is destroyed)
  and offers to bring the session back.
- `SessionServer` closes/fails on lobby/connecting timeout, avoiding a session
  hanging indefinitely before the connection.
- Rehydrate on LiveView mount reconnects the user to the active session.
- Embedded TURN can generate ephemeral credentials; when `turn_only` is active
  the frontend uses `iceTransportPolicy: "relay"`.
- SDP/ICE validation has a size limit, a minimal shape and preserves only
  accepted recovery metadata.
- SDP and ICE creation/application errors in the hook enter the same
  recovery/failure cycle, without relying only on `console.warn`.
- Repeated `addIceCandidate` failures in the browser are aggregated per
  connection cycle; an isolated/stale error is tolerated, but three failures in
  a row trigger coordinated recovery.
- Terminal failure is idempotent: repeated events with the same reason do not
  pile up endless messages nor unmount the media surface.
- `P2PSessionConsole` keeps `LobbyMediaHook` mounted when the base session
  is `:connected`, even during `:reconnecting`/`:failed` recovery.
- The recovery banner always offers Retry when manually recoverable and
  End through the same confirmation flow used by the rest of the session.
- The camera fallback on `devicechange` now mirrors the microphone fallback.
- Toggling privacy relay in a live session fires an immediate coordinated
  restart; the connection does not keep using the old policy until the next
  error/retry.

### Remaining P2P risks

- P2P signaling replay is in memory on purpose. If the BEAM/session process
  restarts, the system does not try to reapply old SDP/ICE; a `connected`
  session without a snapshot fires a clean WebRTC restart with
  `reason: "signaling_snapshot_lost"`. Durable history is still missing, only
  for post-incident audit.
- Relay-only mode depends on the operational availability of TURN. The UI does
  not get stuck in endless connecting; recovery/failure now enters aggregated
  telemetry, but a specific TURN outage alert is still missing.
- The P2P visual watchdog was extended, but there is still no single helper
  shared by P2P, prejoin and conference.

## Conference — current architecture

### Model

A conference is a per-channel call with an SFU on the server:

- The LiveView opens prejoin and creates/joins a room.
- The browser opens its own Phoenix Socket to `/socket`.
- The browser joins the `group_call:<room_token>` topic using a signed join token.
- `GroupCallChannel` authorizes, applies the rate limit and delegates to
  `RetroHexChat.GroupCall`.
- `RoomServer` is the room's authority process.
- `PeerServer` is each participant's ExWebRTC WebRTC endpoint.
- `RTPForwarder` rewrites and forwards RTP from publishers to subscribers.

### Durable states

Room (`GroupCall.Schema.Room`):

- `pending`
- `open`
- `active`
- `closing`
- `closed`
- `expired`
- `failed`

Participant (`GroupCall.Schema.Participant`):

- `invited`
- `joining`
- `connected`
- `reconnecting`
- `disconnected`
- `left`
- `kicked`
- `failed`

Track (`GroupCall.Schema.Track`):

- `announced`
- `active`
- `muted`
- `ended`
- `failed`

### Happy conference handshake

1. An identified user opens a call in the channel.
2. The LiveView opens prejoin (`GroupCallPreJoinHook`) and loads preferences.
3. The user confirms the join.
4. The LiveView calls `GroupCall.create_channel_call` or takes the active room.
5. The LiveView signs the join token and mounts `GroupCallWebRTCHook`.
6. The hook creates `Phoenix.Socket("/socket")` and joins
   `group_call:<room_token>`.
7. `GroupCallChannel.join/3` verifies the join token, room and channel.
8. The hook sends `group_call_join` with `client_info` and `media_constraints`.
9. `RoomServer.join_call` validates policy/capacity and creates or reconnects
   the participant.
10. `RoomServer` creates a pending `PeerServer`, monitors the pid and schedules
    `ready_timeout`.
11. `PeerServer` starts the ExWebRTC `PeerConnection`, creates recvonly
    transceivers to receive audio/video from the browser and sendonly ones for
    existing peers.
12. `PeerServer` sends `group_call_offer` to the channel pid.
13. The browser processes the offer in a serialized queue:
    - ensures the browser PC;
    - applies the remote offer;
    - captures local media if audio/video are enabled;
    - adds local tracks;
    - drains pending candidates;
    - creates the answer;
    - sends `group_call_answer`.
14. `PeerServer` applies the answer, drains remote candidates and subscribes
    pending tracks.
15. ICE connects; `PeerServer` receives the `:connected` state and calls
    `RoomServer.mark_ready`.
16. `RoomServer` moves the participant from pending to participants, marks the
    status `connected`, cancels the ready timeout and broadcasts the join.
17. When a participant publishes a track, `RoomServer.track_added` persists or
    updates the track and notifies the others.
18. For participants already connected, `RoomServer` sends `peer_added` to the
    `PeerServer`; it adds outbound transceivers and sends a new offer with ICE
    restart when needed.
19. Inbound RTP on the `PeerServer` is forwarded to subscribers by
    `RTPForwarder`.

### Conference signaling

Main channel events:

- `group_call_join`
- `group_call_answer`
- `group_call_ice_candidate`
- `group_call_request_offer`
- `group_call_media_state`
- `group_call_screen_share_state`
- `group_call_reaction`
- `group_call_leave`

Rate limit:

- join has its own rate limit;
- answer, ICE, request_offer, media_state and screen_share_state use
  `check_signal_rate`;
- reaction does not appear in the same signaling rate limiter.

### Conference resilience already implemented

- A signed join token binds the browser to the room/channel.
- Phoenix Channel has automatic reconnect/backoff.
- Channel join validates the active room and the token.
- The browser queues offers, avoiding processing two concurrent offers.
- The browser ignores an identical offer already answered.
- The browser buffers ICE candidates until the remote description.
- `PeerServer` buffers remote candidates while in
  `:have_local_offer`.
- The hook observes `iceConnectionState`; `checking` publishes connecting
  recovery, `disconnected` schedules recovery and `failed` triggers an
  immediate retry.
- Before the automatic fresh offer request on `disconnected`, the hook compares
  `getStats()` snapshots and defers the retry if there is still transport, RTP
  or data channel activity, up to a small limit.
- `PeerServer.request_offer` resends the pending offer or creates an offer with
  `ice_restart?: true`.
- The hook schedules a watchdog after `group_call_joined`; if the initial offer
  does not arrive, it publishes `offer_not_received` recovery and requests
  `group_call_request_offer` instead of leaving the UI stuck waiting for SDP.
- `group_call_request_offer` returns the structured error `rejoin_required` when
  the `PeerServer` is not ready; the browser closes the local PC, clears old
  streams and runs `group_call_join` again on the same channel.
- `PeerServer` uses an `offer_id` per offer; the browser echoes it in the answer
  and stale answers are ignored.
- A failure to apply an answer or ICE candidate in the `PeerServer` sends
  `group_call_error` to the browser instead of staying only in the log.
- Repeated `addIceCandidate` failures in the browser are aggregated per cycle;
  an isolated/stale error is tolerated, but three failures in a row trigger
  conference recovery.
- `RoomServer` has `ready_timeout_ms` for a participant that did not connect.
- `RoomServer` has `reconnect_timeout_ms` for a disconnected participant.
- `RoomServer` has `peerless_timeout_ms` to close an empty room.
- `RoomServer` accepts reconnection by normalized nickname when the participant
  is `disconnected`.
- Peer add/remove during a pending offer goes to `pending_peers` until the answer.
- `RTPForwarder` has a munger/cache for reorder, gaps and duplicates.
- BEAM tests exercise RTP fanout, late join, leave/rejoin, audio-only,
  screen share and ICE restart.
- The hook reports browser stats and per-participant quality.
- The conference stats panel shows recovery and handshake diagnostics:
  state, reason, trigger, attempt, next retry, offer id and rejoin epoch.
- The UI has a recoverable state for media warnings and an actionable state for
  connection failure.
- `GroupCallChannel` validates the size/shape of SDP, candidate and `offer_id`.
- Audio/video can be captured on demand when the user turns media on after
  joining receive-only or after an initial failure.
- The reaction rate limit lives in the `GroupCall.send_reaction/4` context; the
  channel preserves that contract without duplicating the block.

### Remaining conference risks

- Server-client signaling remains at-most-once. `offer_id` makes answers
  idempotent and `group_call_request_offer` recovers lost offers while the
  `PeerServer` is alive, but a durable room snapshot for audit after a full
  restart is still missing.
- The remote tile now uses `attachMediaStream` and fires recovery when the track
  is live but the video element presents no frames. That event now enters
  aggregated telemetry under `reason: "remote_video_stalled"`.
- The new recovery/error counters still need to become operational alerts
  and incident-focused dashboards.

## Existing tests

### P2P

JS unit tests:

- `webrtc.js`: PC creation, TURN relay policy, offer/answer, ICE, close,
  callbacks and `RETRY_CONFIG`.
- `media.js`: constraints, permission/device errors, screen capture,
  stream helpers, stats, MOS, profiles, devices, replace track, attach video
  stall and codec preferences.
- `lobby_connection.test.js`: data channels, inbound channel routing,
  full stats, immediate feedback on `ice_disconnected`, deferral via
  `getStats()` and poller cleanup.
- `lobby_media_hook.test.js`: receive-only, capture fallback, setup devices,
  queue until PC ready, republish after PC replacement, remote video
  watchdog, screen share and shortcuts.

Backend:

- `calls/health_test.exs`: the operational healthcheck covers P2P signaling,
  TURN disabled/degraded, TURN listener drift, conference disabled and an
  unusable ICE range without exposing secrets.

LiveView:

- `p2p_session_flow_test.exs`: setup, invite, accept/decline/cancel, console,
  files/games/stats, media state, receive-only, audio-only, recovery UI,
  window manager, persisted messages, ignore/block, invite concurrency,
  rehydrate with a stale slot, `ice_disconnected` feedback and the End button
  inside the recovery banner.

E2E:

- `e2e/tests/chat-p2p.spec.ts`: accept from the PM, real bidirectional video,
  file/game on the same PC, TURN relay, receive-only, audio-only, screen share,
  failure with manual retry, mini/stats/maximize, decline/cancel.
- `e2e/tests/chat-call-fault-injection.spec.ts`: short LiveView/network drop
  during a P2P session, reconnection and teardown; `failed` recovery with the
  `End` button opening confirmation and ending the session; answerer reload
  during the initial offer; simultaneous manual retries from both peers with
  remote media recovered.

P2P test gaps:

- server-client message loss during the handshake with an offer already in
  flight;
- TURN unavailable with `turn_only` enabled;
- destructive lab E2E with physical network loss/packet loss while
  ICE enters `disconnected`.

### Conference

JS unit tests:

- `group_call_prejoin_hook.test.js`: persisted preferences, device preview,
  markup refresh, pending prompt, denied permission with retry and P2P config.
- `group_call_webrtc_hook.test.js`: capture denied warning, constraints,
  audio/video off without getUserMedia, moderation, push-to-talk, duplicate offer,
  offer queue, recovery with request_offer, `rejoin_required`, ICE state,
  on-demand capture, remote tile watchdog, manual retry, layout, reactions,
  stats, active speaker, screen share and screen moderation.

Channel/LiveView:

- `group_call_channel_test.exs`: missing token, token from another room, join
  with server SDP offer, SDP/ICE/offer_id validation, rejoin_required and
  signaling rate limit.
- `group_call_flow_test.exs`: creation/join/prejoin, preferences, indicators,
  participants, leave, layout, shortcuts, a11y, empty/failure states, mini mode,
  stats, renegotiation does not degrade status, screen share, quality, reactions,
  server stats and moderation.
- `calls_health_controller_test.exs`: the `GET /api/calls/healthz` endpoint
  returns 200 for `degraded` and 503 for `down`.

SFU BEAM:

- `sfu_media_path_test.exs`: synthetic bidirectional video, gaps/duplicates/
  reorder, monotonic RTP stats, PLI, late join, four participants, no
  camera, audio-only, screen share, leave/rejoin churn, remaining routes and
  explicit ICE restart. The stats test warms up the route before the exact
  count to avoid discarding old sequences as if they were a forwarding failure.

E2E:

- `e2e/tests/chat-group-call.spec.ts`: prejoin, polish, two users exchanging
  real video, shortcuts, joining with mic/camera off, denied permission with
  receive-only, moderation, request-to-speak, locked conference, screen share,
  layout, mini mode, stats, quality, reactions, failed media recovery with
  manual retry, three users renegotiating join/leave and screen moderation.
- `e2e/tests/chat-call-fault-injection.spec.ts`: short LiveView/network drop
  during a conference, reconnection and leave; reload during `group_call_offer`;
  `PeerServer` terminated before `request_offer` with rejoin via
  `previous_participant_id`; recovery/media error with the `Leave` button opening
  confirmation and clearing status/window.

Conference test gaps:

- browser re-entry after a Phoenix channel reconnect during a pending offer and
  real server-client message loss;
- repeated invalid candidate aggregated per epoch.
