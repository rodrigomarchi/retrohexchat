# Quickstart: Quote/Reply & Message Edit/Delete

**Feature Branch**: `033-message-interactions`
**Date**: 2026-02-16

## What This Feature Does

Adds three message interaction capabilities to RetroHexChat:
1. **Reply** — Users can reply to specific messages, creating a visual link between the reply and the original
2. **Edit** — Users can edit their own messages within 5 minutes of sending
3. **Delete** — Users can soft-delete their own messages within 5 minutes of sending

## Key Files to Create/Modify

### New Files

| File | Purpose |
|------|---------|
| `apps/retro_hex_chat/priv/repo/migrations/YYYYMMDDHHMMSS_add_message_interactions.exs` | Migration: reply, edit, delete columns on messages + private_messages |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/reply_compose_bar.ex` | Reply compose bar component above input |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/delete_confirm_dialog.ex` | Delete confirmation dialog |
| `apps/retro_hex_chat_web/assets/css/message-interactions.css` | CSS for reply blocks, edit indicators, delete display |
| `apps/retro_hex_chat_web/assets/js/lib/message_interactions.js` | JS logic: scroll-to-message, edit mode input, hover reply button |
| `apps/retro_hex_chat_web/assets/js/hooks/message_interactions_hook.js` | Hook: wires JS events to LiveView push_events |

### Modified Files

| File | Change |
|------|--------|
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/message.ex` | Add reply/edit/delete fields and changesets |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/private_message.ex` | Same as above for PMs |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/queries.ex` | Add get, update, soft-delete, reply-preview queries |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/service.ex` | Add edit_message, delete_message, extend send_message with reply |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/policy.ex` | Add can_edit?/2, can_delete?/2 |
| `apps/retro_hex_chat/lib/retro_hex_chat/channels/server.ex` | Add edit/delete message handling in GenServer |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_message.ex` | Render reply blocks, (editado) tags, deleted display |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/chat_context_menu.ex` | Enable "Responder", add "Apagar mensagem" |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live.html.heex` | Add reply compose bar, delete dialog |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/pubsub_handlers/messages.ex` | Handle message_edited, message_deleted events |
| `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/core_events.ex` | Handle edit/delete/reply LiveView events |
| `apps/retro_hex_chat_web/assets/js/hooks/keyboard_hook.js` | Add edit-mode trigger on ↑ when input empty |
| `apps/retro_hex_chat_web/assets/css/app.css` | Import message-interactions.css |
| `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex` | Add help topics for reply, edit, delete |

## Implementation Order

1. **Migration + Schema** — Database columns first (foundation for everything else)
2. **Policy + Queries** — Authorization and data access (can test independently)
3. **Service layer** — edit_message, delete_message, reply support in send_message
4. **Channel Server** — GenServer integration for edit/delete
5. **PubSub handlers** — Handle message_edited, message_deleted in ChatLive
6. **Chat message component** — Render reply blocks, edit tags, deleted display
7. **Context menu + reply compose bar** — UI triggers for reply and delete
8. **Keyboard hook + edit mode** — ↑ key trigger, edit mode JS logic
9. **Hover reply button** — Message hover interaction
10. **Scroll-to-message** — Click reply quote to scroll
11. **Help topics** — Documentation for all new features
12. **CSS** — Styling throughout (can be done incrementally with each component)

## How to Test

```bash
# Run all tests
mix test --include e2e

# Run just the new tests
mix test test/retro_hex_chat/chat/message_test.exs
mix test test/retro_hex_chat/chat/policy_test.exs
mix test test/retro_hex_chat/chat/service_test.exs
mix test test/retro_hex_chat_web/live/chat_live_test.exs

# JS tests
npm test --prefix apps/retro_hex_chat_web/assets

# Full validation
mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix dialyzer
make lint.js && make lint.css
```
