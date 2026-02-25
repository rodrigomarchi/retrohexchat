# Quickstart: WebRTC Signaling (036)

## Prerequisites

- Existing dev environment (`make setup` completed)
- Two browser tabs (or two browsers) for testing P2P

## Development Testing

### 1. Start the server

```bash
make server
```

The embedded TURN server starts automatically on UDP port 3478.

### 2. Create a P2P session

1. Open two browser tabs at `localhost:4000`
2. Log in with different accounts in each tab
3. In one tab, type `/p2p <other_nick>` or `/call <other_nick>`
4. The other tab receives an invite notification — click to accept
5. Both tabs redirect to the P2P lobby (`/p2p/:token`)

### 3. Test signaling

1. In the lobby, one user requests an action (e.g., audio call)
2. The other user accepts
3. Session transitions to `connecting`
4. Watch the connection state indicator: "Conectando..." → "Conectado"
5. Both browsers now have a direct RTCPeerConnection

### 4. Test on LAN (two devices)

On LAN, host ICE candidates work without STUN/TURN. The TURN server provides STUN binding responses for public IP discovery.

```bash
# Find your LAN IP
ifconfig | grep "inet " | grep -v 127.0.0.1

# Start server binding to LAN IP
PHX_HOST=192.168.x.x mix phx.server
```

Access from both devices at `http://192.168.x.x:4000`.

### 5. Verify self-hosted STUN/TURN

Open browser DevTools → Network tab. Verify:
- ICE server URLs point to `localhost:3478` (or your LAN IP)
- No requests to `stun.l.google.com` or any external service
- TURN credentials include a timestamped username and HMAC password

### 6. Test retry behavior

To simulate connection failure, you can:
- Block UDP port 3478 temporarily: `sudo pfctl -e && echo "block drop quick on lo0 proto udp from any port 3478" | sudo pfctl -f -`
- This forces ICE to fail, triggering retry with exponential backoff
- Unblock to see retry succeed: `sudo pfctl -d`

## Running Tests

```bash
# Elixir tests (includes TURN server unit tests)
mix test --include e2e

# JS tests (webrtc.js + webrtc_hook.js)
npm test --prefix apps/retro_hex_chat_web/assets

# Full CI validation
make ci            # Full CI validation (9 parallel checks)
```

## Key Files

| Layer | File | Purpose |
|---|---|---|
| TURN server | `apps/retro_hex_chat/lib/retro_hex_chat/p2p/turn/` | Extracted rel modules |
| Config | `config/config.exs`, `config/runtime.exs` | TURN server configuration |
| LiveView | `apps/retro_hex_chat_web/lib/.../p2p_session_live.ex` | Signal relay handlers |
| JS lib | `apps/retro_hex_chat_web/assets/js/lib/webrtc.js` | RTCPeerConnection logic |
| JS hook | `apps/retro_hex_chat_web/assets/js/hooks/webrtc_hook.js` | LiveView wiring |
| JS tests | `apps/retro_hex_chat_web/assets/test/lib/webrtc.test.js` | Vitest tests |
