# Category AK: P2P Actions in Context Menus

**Priority**: Green (Enhancement — discoverability improvement for existing P2P features)
**Dependencies**: Y (Context Menus), AE (P2P Foundation), AF (P2P Lobby & Session UI)
**Existing**: Y1 nick context menu (context_menu.ex), Y3 nick context menu in chat (chat_context_menu.ex), all P2P command handlers (/p2p, /call, /sendfile)

## Problem

The P2P system is fully functional but has a **discoverability gap**: users must know the slash commands (`/p2p`, `/call`, `/sendfile`) to initiate P2P sessions. Neither the nicklist context menu nor the chat context menu offers P2P actions. A new user who hasn't read the help documentation has no visual way to discover P2P features.

Both existing context menus already support: PM, Whois, Ignore, Add Contact, Set Nick Color, and op actions. Adding P2P items follows the established pattern and requires no new infrastructure.

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AK1 | P2P submenu in nicklist context menu | New | Add "P2P >" submenu to `context_menu.ex` after "Set Nick Color": Sessão P2P, Chamada de Áudio, Chamada de Vídeo, Enviar Arquivo. Only visible when viewer is identified (registered). Items dispatch to existing `/p2p`, `/call`, `/sendfile` command handlers. Disabled with tooltip when target nick is self or target is not registered |
| AK2 | P2P submenu in chat context menu | New | Add same P2P submenu to `chat_context_menu.ex` `nick_menu_items/1` section after "Set Nick Color". Same visibility/disabled rules as AK1 |
| AK3 | Context menu event handlers | New | Add `handle_event` for `context_p2p`, `context_call`, `context_video_call`, `context_sendfile` in `chat_live.ex` UI actions. Reuse existing `do_execute/3` from P2P command handlers to create session and navigate |
| AK4 | Tests for P2P context menu actions | New | Unit tests for context menu rendering (P2P items visible when identified, hidden for guests, disabled for self-target). Integration tests for event handlers dispatching correctly |

## Dependencies Detail

- AK1/AK2 extend existing context menu components — pure UI additions
- AK3 reuses existing P2P command handler logic (`Handlers.P2p.do_execute/3`) — no new domain logic needed
- AK4 follows existing context menu test patterns in `context_menu_test.exs` and `chat_context_menu_test.exs`

## Technical Notes

- P2P requires registered users — menu items MUST check `@identified` (or equivalent assign) and only render for identified users
- Target must also be registered — if target nick is a guest, items should be disabled with tooltip "Usuário não registrado"
- Self-targeting: items disabled with no tooltip (same as Ignore behavior)
- Submenu pattern: 98.css supports nested menus via `.tree-view` nesting. Alternative: flat items with separator (simpler, matches existing patterns)
- Event flow: `context_p2p` → resolve target nick → call `P2P.create_session/3` → on success, navigate to `/p2p/{token}` and close context menu
- Error handling: rate limit errors, block errors, etc. shown as flash messages (same as slash command errors)
- The chat context menu (`chat_context_menu.ex`) uses a different component structure than the nicklist menu (`context_menu.ex`) — both need the same items but wired differently

---

## Spec Command

```
/speckit.specify "P2P Actions in Context Menus for RetroHexChat.

PROBLEM: The P2P system is fully functional with /p2p, /call, and /sendfile commands, but users cannot discover or access these features through the context menus (right-click). Both the nicklist context menu and the chat area nick context menu lack P2P actions. This is a significant discoverability gap — a user who doesn't know the slash commands has no visual way to start a P2P session, make a call, or send a file.

EXISTING CONTEXT: Two context menu components exist. (1) context_menu.ex provides right-click on nicklist nicks with PM, Whois, Ignore, Add Contact, Set Nick Color, and op actions. (2) chat_context_menu.ex provides right-click on nicks in chat messages with PM, Whois, Copy Nick, Ignore, Add Contact, Set Nick Color, and op actions. The P2P command handlers (p2p.ex, call.ex, send_file.ex) expose do_execute/3 for creating sessions. P2P requires both users to be registered (identified).

USER JOURNEY: A user right-clicks on a nickname in the nicklist or chat area. Below 'Set Nick Color' and above the operator separator, they see P2P actions: 'Sessão P2P', 'Chamada de Áudio', 'Chamada de Vídeo', 'Enviar Arquivo'. Clicking 'Chamada de Áudio' creates a P2P session with session_type audio_call and navigates to the lobby. If the target is not registered, the items appear grayed out with 'Usuário não registrado' tooltip. If the viewer is a guest, the P2P items do not appear at all.

ACTORS: Registered (identified) users see P2P items. Guest users do not see P2P items. Target nick must be registered for items to be enabled.

EDGE CASES: Target is self (items disabled). Target is ignored/blocked (session creation fails with generic error, shown as flash). Rate limit hit (flash error with wait time). Target is offline (session created normally — pending state until they join).

SCOPE: In scope — P2P action items in both context menus, event handlers, visibility rules, disabled states, tests. Out of scope — new P2P features, changes to P2P session flow, submenu styling."
```
