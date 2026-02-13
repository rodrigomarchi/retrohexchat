# Category AB2: Status Bar & Loading States

**Priority**: Red (Critical — system state visibility)
**Dependencies**: None (foundational UX)
**Existing**: AB9 status bar (status_bar.ex), AB13 reconnect overlay (reconnect_hook.js)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AB9 | Status bar | Existing | Shows nickname, active channel, user count, connection status, mute toggle |
| AB10 | Status bar lag display | New | Real-time latency indicator (e.g., "Lag: 45ms") in status bar |
| AB11 | Status bar connection states | New | 🟢 Conectado, 🟡 Conectando, 🔴 Desconectado, 🔄 Reconectando with server name |
| AB12 | Status bar clock | New | Current time display in the rightmost section of status bar |
| AB13 | Reconnect overlay | Existing | Auto-reconnect with countdown, attempt tracking, 98.css styled overlay |
| AB14 | Connection progress indicator | New | Visual progress during initial connection: DNS, connecting, authenticating steps |
| AB15 | Channel history loading | New | Spinner/loading indicator while loading message history for a channel |
| AB16 | Channel list loading | New | Progress bar while fetching channel list from server |
| AB17 | Disconnection banner | New | Red banner at top of chat: "⚠️ Desconectado — Reconectando em 5s..." |
| AB18 | Reconnection success banner | New | Green banner: "✓ Reconectado!" that fades after 3 seconds |

## Dependencies Detail

- AB9 (existing) provides the status bar component structure with sections for nick, channel, status, mute
- AB10 (lag) requires measuring round-trip time via LiveView push_event/handle_event ping-pong
- AB13 (existing) provides reconnection infrastructure (watches phx-loading, countdown overlay)
- AB14 (connection progress) extends the connect flow in ConnectLive with visual step tracking
- AB17-AB18 (banners) are independent of AB13 — they appear inside the chat area, not as a full overlay

## Technical Notes

- Existing status_bar.ex shows nick, channel, user count, connection status, and mute toggle ([MUTE]/[SND])
- Existing reconnect_hook.js watches phx-loading class, shows overlay with countdown (max 10 attempts, 30s max delay)
- Lag measurement: use LiveView push_event/handle_event ping-pong with timestamp comparison
- Connection progress: track connection stages in LiveView assigns, render progressive steps with ✓/⏳ icons
- Channel history loading: 98.css animated spinner centered in chat area while messages load
- Channel list loading: progress bar with count of channels found so far
- Disconnection banner: fixed position at top of chat area, red background, shows countdown to next reconnect attempt
- Reconnection banner: green background, auto-fades after 3 seconds using CSS transition
- Status bar clock: update every minute via JS hook or Process.send_after

---

## Spec Command

```
/speckit.specify "Status Bar & Loading States for RetroHexChat.

PROBLEM: The status bar exists but lacks real-time latency information, detailed connection states, and a clock. Users have no idea about network lag or the exact connection state. When loading content (initial connection, channel history, channel list), users see blank areas with no progress indication. While a reconnect overlay exists for full disconnections, there is no subtle feedback for brief connection issues — no banner for disconnection/reconnection events. Users feel blind about the system's state.

EXISTING CONTEXT: (1) status_bar.ex shows the current nickname, active channel name, user count, connection status indicator, and a mute toggle field ([MUTE]/[SND]). (2) reconnect_hook.js provides an auto-reconnect overlay that watches the phx-loading class, shows a countdown timer and attempt counter (max 10 attempts, max 30s delay) in a 98.css-styled full overlay.

USER JOURNEY — STATUS BAR: The status bar at the bottom of the screen shows rich real-time information. Left section: '#general — 15 usuários'. Center: '🟢 Conectado a irc.retro.chat'. Right: 'Lag: 45ms | 14:32'. The lag updates in real-time, measuring the round-trip time between client and server. When the connection degrades, the lag number increases and may change color (yellow above 200ms, red above 500ms). When the connection drops, the center changes to '🔴 Desconectado' and then '🔄 Reconectando (5s)' with a countdown. When reconnected: '🟢 Conectado' returns. The clock shows the current local time.

USER JOURNEY — LOADING STATES: During initial connection, a progress indicator shows steps: '✓ DNS resolvido | ⏳ Conectando na porta 6697... | Aguardando resposta...'. Each step shows ✓ when complete and ⏳ when in progress. When switching to a channel with message history to load, a 98.css spinner appears centered in the chat area: 'Carregando mensagens...' — the spinner disappears when messages appear. When fetching the full channel list, a progress bar shows: 'Buscando canais... 1,247 encontrados' with a growing bar.

USER JOURNEY — CONNECTION BANNERS: When the WebSocket disconnects (after having been connected), a red banner appears at the top of the chat area: '⚠️ Desconectado — Reconectando em 5s...' with a countdown. This is more subtle than the full reconnect overlay — it appears for brief interruptions. When successfully reconnected, the banner turns green: '✓ Reconectado!' and fades out after 3 seconds.

ACTORS: All status bar information and loading states are visible to any connected user. Lag measurement is automatic.

EDGE CASES: Lag measurement must handle the case where a response never comes — show '?' or 'Timeout' instead of a number. Loading states must have a maximum duration — if loading takes more than 30 seconds, show a retry option. The reconnection banner must not appear for very brief disconnections (under 1 second) to avoid flicker. The disconnection banner must not appear during initial page load (only after an established connection drops). If the user switches channels rapidly while history is loading, the spinner must update to the new channel and cancel the old loading request. The clock must handle timezone correctly (use local browser time).

NEGATIVE REQUIREMENTS: Loading spinners must NOT block the UI — the user should still be able to switch channels or type while content loads in the background. The disconnection banner must NOT overlap with or duplicate the existing reconnect overlay — use the banner for brief issues, the overlay for extended disconnections. The lag indicator must NOT create excessive network traffic — measure at reasonable intervals (every 30-60 seconds). Status bar updates must NOT cause layout shifts.

SCOPE: In scope — status bar lag display with color thresholds, detailed connection state indicators (4 states), status bar clock, connection progress indicator with steps, channel history loading spinner, channel list loading progress bar, disconnection/reconnection banners. Out of scope — network speed test, connection quality graph, historical lag data, status bar customization (fixed layout)."
```
