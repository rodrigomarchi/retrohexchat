# Category AF: P2P Lobby & Session UI

**Priority**: Red (Critical — user-facing entry point for all P2P interactions)
**Dependencies**: AE (P2P Foundation)
**Existing**: None (new feature)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AF1 | Router and P2PSessionLive | New | Route `/p2p/:token` with `:require_authenticated_user` pipeline. P2PSessionLive mount: verify token, check user is creator or peer, subscribe to `p2p:#{token}`, join GenServer |
| AF2 | Invitation notification | New | When a P2P invite is created, target user receives a notification via the existing notification system (feature 032) with three actions: "Aceitar" (opens `/p2p/:token`), "Recusar" (sends rejection event, updates session to closed with reason `rejected`, notifies creator), "Ignorar" (dismisses notification, session expires via timeout) |
| AF3 | /p2p command handler | New | `Commands.Handlers.P2P` — `/p2p <nickname>` creates a generic P2P session. Validates target, delegates to `P2P.Service.create_session/2`, displays lobby URL |
| AF4 | /call command handler | New | `Commands.Handlers.Call` — `/call <nickname>` creates a P2P session with session_type `:audio_call`. Same flow as /p2p but with intent pre-set |
| AF5 | /sendfile command handler | New | `Commands.Handlers.SendFile` — `/sendfile <nickname>` creates a P2P session with session_type `:file_transfer`. Same flow as /p2p but with intent pre-set |
| AF6 | Lobby chat | New | Ephemeral chat between peers in the lobby. Messages stored in GenServer state (not persisted to DB). PubSub broadcast via `p2p:#{token}`. Rendered as a stream in the LiveView |
| AF7 | Lobby 98.css window layout | New | Windows 98-style window with title bar, peer names, status indicator. Action panel with buttons for file transfer, audio call, video call. System event log showing session history |
| AF8 | Peer presence indicator | New | Shows which peers are currently in the lobby. Visual indicator (online/away) updated via GenServer `:peer_joined`/`:peer_left` events |
| AF9 | Bilateral consent action request/accept UI | New | When a peer requests an action (e.g., file transfer), the other peer sees a request notification with Accept/Reject buttons. Both must consent before proceeding. Request shows action type and metadata |
| AF10 | Browser capability check | New | On lobby mount, JS hook checks for `RTCPeerConnection`, `RTCDataChannel`, `getUserMedia`, `crypto.subtle`. Unsupported action buttons are disabled with tooltip explaining why (e.g., "Your browser does not support video calls") |
| AF11 | Browser permission requests | New | After bilateral consent, before WebRTC handshake: request `getUserMedia` for calls, file picker for transfers. Friendly error message and retry button on permission denial (`NotAllowedError`, `NotFoundError`, `NotReadableError`) |
| AF12 | Session close and redirect | New | Session closes on: (1) click "Encerrar Sessão" button, (2) browser tab close / navigate away (`beforeunload` event + LiveView `terminate/2` callback), (3) timeout, (4) error. Closing updates GenServer and DB, broadcasts close event, redirects remaining peer back to main chat with a system message |
| AF13 | CSS files | New | `p2p-session.css` for main session layout, `p2p-lobby.css` for lobby-specific styles. Follow project CSS architecture: component class prefix `.p2p-session__*` and `.p2p-lobby__*`, imports in `app.css` |

## Dependencies Detail

- AF1 (router/LiveView) is the scaffold — all other UI items depend on it
- AF2 (notification) depends on AE7 (service creates session) and existing notification system (feature 032)
- AF3/AF4/AF5 (command handlers) depend on AE7 (service) for session creation
- AF6 (lobby chat) depends on AF1 (LiveView) and AE5 (GenServer stores messages)
- AF7 (layout) depends on AF1 and AF13 (CSS)
- AF8 (presence) depends on AE5 (GenServer tracks peers)
- AF9 (consent UI) depends on AF1 and AE5 (GenServer handles action requests)
- AF10 (capability check) depends on AF7 (buttons to disable)
- AF11 (permissions) depends on AF9 (triggers after consent)
- AF12 (close) depends on AE7 (service) and AF1 (LiveView)

## Technical Notes

- P2PSessionLive is a separate LiveView (not embedded in ChatLive) — it has its own URL and layout
- Lobby chat is ephemeral: messages live only in GenServer state, lost on process termination
- Command handlers follow existing pattern: implement `Handler` behaviour, register in dispatcher
- Notification integration uses the existing notification system from feature 032 (`user:#{nickname}` PubSub)
- Browser capability check runs in a JS hook on mount, pushes results to LiveView via `pushEvent`
- Browser permissions are requested in JS after LiveView confirms bilateral consent
- The lobby layout follows 98.css window conventions: title-bar, window-body, field-row, etc.
- Action buttons: "Enviar Arquivo", "Chamada de Áudio", "Chamada de Vídeo"
- Timeout display: show remaining time for pending invites and lobby inactivity
- Notification has 3 actions: Aceitar (navigate to lobby), Recusar (call `P2P.Service.reject_invite/2` → close session with reason `rejected`), Ignorar (dismiss, let timeout expire)
- Close-on-navigation: JS `beforeunload` event pushes a "leaving" event to the hook; LiveView `terminate/2` callback handles the server-side cleanup (GenServer leave, DB update if last peer)
- CSS follows project architecture: `.p2p-session` and `.p2p-lobby` prefixes, 50-200 lines per file

---

## Spec Command

```
/speckit.specify "P2P Lobby & Session UI for RetroHexChat.

PROBLEM: Users have no way to initiate, discover, or interact with P2P sessions. The P2P foundation provides the domain infrastructure (GenServer, Service, Policy, tokens) but no user interface. Users need slash commands to create sessions, a dedicated lobby page to meet their peer, and UI for negotiating actions (file transfer, calls) with bilateral consent. Without the lobby, users cannot see each other, chat before starting a P2P action, or agree on what to do.

EXISTING CONTEXT: The P2P bounded context exists with SessionServer GenServer, Service orchestration, Policy checks, and session tokens. The notification system (feature 032) exists for delivering real-time notifications to users. The command system has 45 handlers following the Handler behaviour pattern. The router uses Phoenix LiveView with authenticated pipelines. 98.css provides the Windows 98 aesthetic with dark theme. CSS architecture uses component-prefixed classes with 50-200 line files.

USER JOURNEY — INITIATE SESSION: A user types '/p2p mario' in the chat input. The command handler validates mario exists and is online, then calls P2P.Service.create_session/2. The system creates the session and sends a notification to mario: 'rodrigo quer iniciar uma sessão P2P' with three buttons: 'Aceitar' (opens /p2p/:token), 'Recusar' (sends rejection — session closed with reason 'rejected', rodrigo sees 'mario recusou o convite P2P'), 'Ignorar' (dismisses notification, session expires after 5min). The initiator sees a system message with a link to the lobby. Mario clicks Aceitar and navigates to /p2p/:token. Both are now in the lobby.

USER JOURNEY — LOBBY INTERACTION: Both peers see a Windows 98-style window with each other's names, presence indicators, and an action panel. They can chat in an ephemeral lobby chat (messages not persisted). The lobby shows three action buttons: 'Enviar Arquivo', 'Chamada de Áudio', 'Chamada de Vídeo'. On mount, a JS hook checks browser capabilities — if the browser doesn't support getUserMedia, the audio/video buttons are disabled with a tooltip. Rodrigo clicks 'Chamada de Áudio'. Mario sees a request: 'rodrigo quer iniciar uma chamada de áudio' with Accept/Reject buttons. Mario clicks Accept. The system requests microphone permission from both browsers, then proceeds to the WebRTC handshake.

USER JOURNEY — CLOSE SESSION: Either peer clicks 'Encerrar Sessão', or closes the browser tab, or navigates away. The JS beforeunload event and LiveView terminate/2 callback handle passive disconnection. The session is closed in the GenServer and DB, the remaining peer is redirected to the main chat with a system message: 'Sessão P2P encerrada'.

ACTORS: Registered users only. Both creator and peer have equal capabilities in the lobby. The system acts for timeout enforcement and capability detection.

EDGE CASES: User navigates to /p2p/:token but is neither creator nor peer (reject with 404). Token is expired or invalid (redirect to main chat with error). One peer leaves the lobby (other peer is notified, session can remain open for a grace period). Peer closes browser tab without clicking close (beforeunload + terminate/2 handles cleanup). Peer rejects invite via notification (session closed with reason 'rejected', creator notified). Browser doesn't support WebRTC at all (all action buttons disabled, message explaining incompatibility). Permission denied for microphone (friendly error with retry option, don't proceed with call). File picker cancelled (no error, just return to lobby). Both peers request different actions simultaneously (first request takes priority, second is queued). Session expires while peers are in lobby (redirect both with timeout message).

NEGATIVE REQUIREMENTS: Lobby chat must NOT be persisted to the database — it's ephemeral in GenServer state only. The lobby must NOT be accessible to guests. Command handlers must NOT contain business logic — delegate to P2P.Service. The P2PSessionLive must NOT contain business logic — delegate to P2P context. Browser capability check must NOT block the lobby render — it runs asynchronously after mount. Permission requests must NOT happen before bilateral consent.

SCOPE: In scope — router with /p2p/:token route, P2PSessionLive with mount/auth/subscribe, invitation notification via feature 032 (with Aceitar/Recusar/Ignorar actions), /p2p /call /sendfile command handlers, ephemeral lobby chat, 98.css lobby layout, peer presence indicators, bilateral consent action request/accept UI, browser capability detection, browser permission requests, session close with redirect (including passive close via beforeunload and terminate/2), p2p-session.css and p2p-lobby.css. Out of scope — WebRTC signaling, file transfer protocol, media streams, TURN credentials, help documentation."
```
