# Research: Perform / Auto-Commands

**Branch**: `009-perform-auto-commands` | **Date**: 2026-02-12

## R1: Perform Execution Timing (Chicken-and-Egg Problem)

**Question**: How do perform commands auto-execute on connect when the persisted list requires NickServ identification to load, but `/ns identify` is itself a perform command?

**Decision**: Two-tier storage with localStorage bridge.

**Rationale**: The perform list has three sources of truth with fallback priority:
1. **localStorage** (browser) — Available immediately on mount, carries state from previous session/reconnect
2. **In-memory** (Session struct) — Available during current session after manual `/perform add`
3. **Database** (PostgreSQL) — Authoritative source, loaded after NickServ identification

**Flow**:
- **Cold start (new browser)**: No localStorage, user must manually identify once. After identification, perform list loads from DB and is saved to localStorage for next time.
- **Warm start (returning browser)**: localStorage has perform list from previous session. Commands execute immediately on mount, including `/ns identify`.
- **Auto-reconnect**: localStorage has perform list + channel list. Commands re-execute after reconnection.
- **After identification**: DB data syncs into session and localStorage, updating any changes made from another device.

**Alternatives considered**:
1. ~~Load perform list eagerly by nickname before identification~~ — Security risk: any user connecting with a registered nickname would get access to stored perform commands (including NickServ passwords).
2. ~~Encrypt perform entries with NickServ password~~ — Over-complex, requires crypto for a client-side convenience feature.
3. ~~Store only in DB, require manual identify every session~~ — Poor UX, defeats the purpose of auto-identify.
4. ~~Store only in localStorage~~ — No cross-session sync for registered users who clear browser data.

---

## R2: Auto-Reconnect Architecture in LiveView

**Question**: How does auto-reconnect work in a LiveView-based app where the server process dies on disconnect?

**Decision**: Custom JS hook leveraging Phoenix LiveView's built-in reconnection with UI overlay.

**Rationale**: Phoenix LiveView already reconnects WebSocket connections with exponential backoff. What we add:
1. **ReconnectHook JS** — Monitors connection state via `phx-disconnected`/`phx-connected` CSS classes on the LiveView root element
2. **Reconnection overlay** — Pure HTML/CSS/JS overlay (not LiveView, since LV is disconnected)
3. **Session state in localStorage** — Nickname, channels, active tab, perform list saved on important events
4. **Intentional disconnect flag** — Set before `/quit` navigation, checked by ReconnectHook to suppress auto-reconnect

**Phoenix LiveView reconnect customization**:
```javascript
new LiveSocket("/live", Socket, {
  reconnectAfterMs: (tries) => {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s (capped)
    return Math.min(1000 * Math.pow(2, tries - 1), 30000)
  }
})
```

**Alternatives considered**:
1. ~~Server-side reconnection~~ — Not possible; LiveView process dies on WS disconnect.
2. ~~Channel-based reconnection (Phoenix Channels)~~ — Over-engineering; LiveView WS is sufficient.
3. ~~Service Worker~~ — Too heavy for this use case.

---

## R3: Perform Command Execution Mechanism

**Question**: How to execute a list of commands sequentially with delays in a LiveView process?

**Decision**: `Process.send_after` chain pattern — each command sends a message to execute the next after a 100ms delay.

**Rationale**: LiveView event handlers must return `{:noreply, socket}` immediately. Blocking (Process.sleep) is forbidden. The send_after pattern is the idiomatic OTP approach:
1. Mount triggers `send(self(), {:execute_perform, 0})`
2. `handle_info({:execute_perform, index})` executes command at index
3. Calls `Process.send_after(self(), {:execute_perform, index + 1}, 100)`
4. After last perform command, sends `{:execute_autojoin, 0}` to start auto-join phase
5. After all auto-join, sends `{:execute_rejoin, 0}` if reconnecting (previous channels)

**Alternatives considered**:
1. ~~Task.async chain~~ — Unnecessary complexity, GenServer message passing is simpler.
2. ~~Synchronous dispatch loop~~ — Blocks the LiveView process, preventing PubSub messages from being processed between commands.
3. ~~Concurrent execution~~ — Would cause race conditions (e.g., identify must complete before joining +i channels).

---

## R4: Password Masking Approach

**Question**: How to mask passwords in perform commands for display while keeping the real password for execution?

**Decision**: Regex-based masking function applied at display time only. Raw command stored as-is.

**Rationale**: Passwords appear only in `/ns identify <password>` and `/msg NickServ identify <password>` patterns. A simple regex replaces the password portion with `****` at display time. The raw command (with real password) is stored in the perform list for execution.

```elixir
@identify_patterns [
  ~r{^/ns\s+identify\s+\S+}i,
  ~r{^/msg\s+nickserv\s+identify\s+\S+}i
]

def mask_command(command) do
  command
  |> String.replace(~r{((?:/ns\s+identify|/msg\s+nickserv\s+identify)\s+)\S+}i, "\\1****")
end
```

**Security boundary**: Passwords in localStorage are acceptable (same trust model as browser password managers). Passwords in PostgreSQL are behind authentication. Passwords are never sent to other users via PubSub.

---

## R5: Bounded Context Placement

**Question**: Where should PerformList and AutoJoinList modules live?

**Decision**: `RetroHexChat.Chat` bounded context.

**Rationale**: Following the pattern established by similar user-preference modules:
- `Chat.IgnoreList` — user preference for filtering
- `Chat.HighlightWords` — user preference for display
- `Chat.PerformList` — user preference for connection automation
- `Chat.AutoJoinList` — user preference for channel automation

The Commands context (`RetroHexChat.Commands`) contains only the parser, dispatcher, registry, and handler modules. Adding CRUD data modules there would mix concerns.

---

## R6: Auto-Reconnect vs. Intentional Disconnect Detection

**Question**: How to reliably distinguish intentional from unintentional disconnects?

**Decision**: Intentional disconnect flag in localStorage + `beforeunload` event.

**Rationale**:
- `/quit` command → handler sets `intentional_disconnect: true` in localStorage via `push_event`, then navigates to `/`
- Menu "Disconnect" → same flow
- Browser tab close → `beforeunload` event fires; we treat this as intentional (no reconnect on next visit)
- Network drop / server crash → no `beforeunload`, no intentional flag → auto-reconnect triggers
- Browser back navigation → LiveView handles this as navigation, not disconnect

**Key invariant**: The intentional disconnect flag is set BEFORE the disconnect happens and cleared on successful mount. If the flag is present when ReconnectHook detects a disconnect, it suppresses auto-reconnect.

---

## R7: Constitution Compliance — JS Hooks for Auto-Reconnect

**Question**: The constitution says "JavaScript hooks MUST be minimal and isolated (scroll behavior, sounds, keyboard shortcuts only)." The ReconnectHook is more substantial. Is this a violation?

**Decision**: Justified exception — the reconnect overlay CANNOT use LiveView because LiveView is disconnected.

**Rationale**: When the WebSocket drops, LiveView is inoperable. The reconnect overlay (countdown timer, cancel button, attempt counter) must be pure HTML/CSS/JS. This is an inherent architectural constraint, not a design choice. The hook remains isolated (single file, single responsibility) and does not implement any business logic — it only manages connection state display and localStorage persistence.

This is documented in the Complexity Tracking table as a justified deviation.
