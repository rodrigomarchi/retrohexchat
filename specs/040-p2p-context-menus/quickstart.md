# Quickstart: P2P Actions in Context Menus

**Feature**: 040-p2p-context-menus
**Date**: 2026-02-17

## Prerequisites

- Dev server running (`make server`)
- Two registered users (use `/nickserv register <password>` + `/nickserv identify <password>`)
- Both users in the same channel

## Manual Testing Guide

### 1. Verify P2P Items Appear (Registered User)

1. Log in as a registered, identified user
2. Right-click any other registered user's nick in the nicklist
3. Verify you see: "Sessão P2P", "Chamada de Áudio", "Chamada de Vídeo", "Enviar Arquivo"
4. Items should appear after "Set Nick Color" and before the operator separator

### 2. Verify P2P Items in Chat Context Menu

1. Right-click a nick in a chat message
2. Same four items should appear after "Set Nick Color"

### 3. Verify Guest User Cannot See Items

1. Log in as a guest (don't identify)
2. Right-click any nick — P2P items should NOT appear

### 4. Verify Disabled State (Unregistered Target)

1. As identified user, right-click a guest user's nick
2. P2P items should appear grayed out
3. Hover should show "Usuário não registrado" tooltip

### 5. Verify Self-Target Disabled

1. Right-click your own nick
2. P2P items should appear grayed out, no tooltip

### 6. Verify Session Creation

1. Right-click a registered nick → click "Chamada de Áudio"
2. Should navigate to `/p2p/:token` lobby
3. Target should receive a PM with the lobby link

## Key Files

| File | Purpose |
|------|---------|
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/context_menu.ex` | Nicklist context menu component |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex` | Chat context menu component |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/context_menu_events.ex` | Event handlers |
| `apps/retro_hex_chat/lib/retro_hex_chat/commands/handlers/p2p.ex` | P2P session creation logic |

## Automated Tests

```bash
# Run all tests
mix test --include e2e

# Run context menu tests specifically
mix test test/retro_hex_chat_web/components/context_menu_test.exs
mix test test/retro_hex_chat_web/components/chat_context_menu_test.exs
mix test test/retro_hex_chat_web/live/chat_live/context_menu_events_test.exs
```
