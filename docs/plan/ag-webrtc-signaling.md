# Category AG: WebRTC Signaling

**Priority**: Yellow (High — enables P2P data and media channels)
**Dependencies**: AE (P2P Foundation), AF (P2P Lobby & Session UI)
**Existing**: None (new feature)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AG1 | PubSub signal relay in P2PSessionLive | New | Handle `push_event` from JS hook with signaling messages (offer, answer, ice-candidate). Broadcast via PubSub `p2p:#{token}`. Receive and forward to JS via `push_event`. Validate message format server-side |
| AG2 | webrtc.js lib module | New | Pure logic module: `createPeerConnection(iceServers)`, `createOffer()`, `createAnswer(offer)`, `handleSignal(signal)`, `addIceCandidate(candidate)`, `close()`. Event callbacks for `onicecandidate`, `onconnectionstatechange`, `ondatachannel`, `ontrack` |
| AG3 | webrtc_hook.js | New | LiveView hook wiring: receives `p2p_start_offer` and `p2p_signal` events from server, delegates to webrtc.js lib. Pushes local signals (offer/answer/ICE) to server via `pushEvent`. Follows hook=wiring/lib=logic pattern |
| AG4 | ICE server configuration | New | App environment config for STUN/TURN servers. Default: public STUN (stun:stun.l.google.com:19302) for dev. Production: configurable STUN+TURN URLs. Sent to browser on `p2p_start_offer` event with TURN credentials |
| AG5 | Connection state tracking UI | New | Display WebRTC connection state to users: 'Conectando...', 'Conectado', 'Reconectando...', 'Falha na conexão'. Based on `RTCPeerConnection.connectionState` events. Visual indicator in the session window |
| AG6 | Automatic retry | New | On WebRTC handshake failure: retry up to 3 times with exponential backoff (2s, 4s, 8s). After 3 failures, transition session to 'failed' state. User sees retry progress: 'Tentativa 2 de 3...' |
| AG7 | Session state transition to active | New | When `RTCPeerConnection.connectionState` becomes 'connected', JS hook notifies LiveView. LiveView updates GenServer state to `:active`. DB record updated. UI reflects active session |
| AG8 | Signaling rate limit interface | New | Define rate limit interface for signaling messages in the P2P context. Actual enforcement implemented in AJ, but the interface (behaviour/contract) is established here for clean integration |
| AG9 | JS tests for webrtc.js | New | Vitest tests for webrtc.js lib: PeerConnection creation, offer/answer flow with mocked RTCPeerConnection, ICE candidate handling, connection state callbacks, retry logic, error scenarios |
| AG10 | JS tests for webrtc_hook.js | New | Vitest tests for hook wiring: event handling from LiveView, pushEvent calls for signaling, DOM state updates for connection status |

## Dependencies Detail

- AG1 (PubSub relay) depends on AF1 (P2PSessionLive exists) and AE5 (GenServer for validation)
- AG2 (webrtc.js) is self-contained — pure JS logic module
- AG3 (hook) depends on AG2 (lib) and AF1 (LiveView)
- AG4 (ICE config) depends on AG2 (needs servers for PeerConnection creation)
- AG5 (state UI) depends on AG2 (connection state events) and AF7 (lobby layout)
- AG6 (retry) depends on AG2 (PeerConnection management)
- AG7 (state transition) depends on AG3 (hook notifies LiveView) and AE5 (GenServer state)
- AG8 (rate limit interface) depends on AE context structure
- AG9/AG10 (tests) depend on AG2/AG3 respectively

## Technical Notes

- Signaling flow: JS hook → `pushEvent("p2p_signal", payload)` → LiveView `handle_event` → PubSub broadcast → peer's LiveView `handle_info` → `push_event("p2p_signal", payload)` → peer's JS hook
- Signal message types: `{"type": "offer", "sdp": "..."}`, `{"type": "answer", "sdp": "..."}`, `{"type": "ice-candidate", "candidate": "..."}`
- ICE Trickle: candidates sent incrementally as discovered, not batched
- webrtc.js must be a pure logic module with no DOM dependencies — all DOM wiring in the hook
- RTCPeerConnection is a browser-native API — no JS libraries needed
- For tests, mock RTCPeerConnection with a class that simulates offer/answer/ICE flow
- The hook receives `p2p_start_offer` (initiator creates offer) or `p2p_start_answer` (peer creates answer)
- Connection states to track: `new`, `connecting`, `connected`, `disconnected`, `failed`, `closed`
- Exponential backoff: create new PeerConnection on each retry (don't reuse failed one)
- Rate limit interface: define `@callback check_signal_rate(session_token, user_id) :: :ok | {:error, :rate_limited}`

---

## Spec Command

```
/speckit.specify "WebRTC Signaling for RetroHexChat.

PROBLEM: After both peers are in the lobby and agree on an action, there is no mechanism to establish a direct P2P connection between their browsers. WebRTC requires a signaling channel to exchange SDP offers/answers and ICE candidates before a peer-to-peer connection can be established. The server must relay these signaling messages without carrying any actual media data. Without signaling, no file transfers or calls can happen.

EXISTING CONTEXT: The P2P SessionServer GenServer manages session state and PubSub topic 'p2p:#{token}'. P2PSessionLive provides authenticated mount and bilateral consent UI for the lobby. The project follows the hook=wiring/lib=logic JS pattern with 9 existing lib modules and corresponding hooks. Vitest with jsdom is used for JS testing. Phoenix PubSub is used for all real-time communication. WebRTC is a browser-native API requiring zero JS dependencies.

USER JOURNEY — SIGNALING FLOW: After bilateral consent in the lobby, the server sends a 'p2p_start_offer' event to the initiator's browser with ICE server configuration. The initiator's webrtc_hook.js receives the event and delegates to webrtc.js, which creates an RTCPeerConnection, generates an SDP offer, and sets it as localDescription. The hook pushes the offer to the server via pushEvent. The server broadcasts the offer via PubSub to the peer. The peer's hook receives the offer, creates an RTCPeerConnection, sets the offer as remoteDescription, generates an answer, and pushes it back. Meanwhile, both sides discover and exchange ICE candidates via the same relay path. The connection state UI shows 'Conectando...' during this process. When connectionState becomes 'connected', both users see 'Conectado' and the session transitions to active.

USER JOURNEY — RETRY ON FAILURE: The WebRTC handshake fails (e.g., NAT traversal issue). The user sees 'Falha na conexão. Tentativa 2 de 3...'. A new PeerConnection is created with exponential backoff (2s delay). If all 3 attempts fail, the session state becomes 'failed' and the user sees 'Não foi possível estabelecer a conexão P2P' with an option to return to the lobby.

ACTORS: Both peers participate equally in the signaling flow (one initiates the offer, one responds with an answer). The server acts purely as a relay — it never inspects or modifies SDP content. ICE servers (STUN/TURN) are external services configured in app environment.

EDGE CASES: One peer's browser doesn't support RTCPeerConnection (detected by lobby capability check, this plan assumes support). Offer created but peer disconnects before answering (timeout after 30s, retry). ICE gathering takes too long (trickle ICE sends candidates as discovered). Symmetric NAT blocks all direct connections (TURN relay used as fallback). Rapid signaling messages from a malicious client (rate limit interface prepared, enforcement in the security plan). Peer reconnects to LiveView mid-handshake (new mount triggers re-negotiation). Both peers try to create offers simultaneously (server designates initiator based on creator role).

NEGATIVE REQUIREMENTS: The server must NEVER inspect, modify, or store SDP content — it is a dumb relay. No JavaScript WebRTC libraries (no simple-peer, no adapter.js) — use browser-native RTCPeerConnection only. webrtc.js must NOT contain any DOM manipulation or LiveView-specific code. The hook must NOT contain PeerConnection logic — only wiring. ICE server configuration must NOT be hardcoded — must be configurable via app environment. Signaling must NOT happen outside the PubSub relay (no direct WebSocket messages).

SCOPE: In scope — PubSub signal relay in P2PSessionLive, webrtc.js lib module, webrtc_hook.js, ICE server configuration from app env, connection state tracking UI, automatic retry with exponential backoff (3 attempts), session state transition to active, signaling rate limit interface (contract only), JS tests for lib and hook. Out of scope — TURN server setup, TURN credential generation, rate limit enforcement, file transfer protocol, media streams, help documentation."
```
