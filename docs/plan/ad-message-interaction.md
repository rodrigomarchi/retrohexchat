# Category AD: Quote/Reply & Message Edit/Delete

**Priority**: Yellow (High — modern message interaction patterns)
**Dependencies**: Y (Context Menus) for "Responder" and "Apagar" menu items
**Existing**: None (new category)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AD1 | Reply activation via context menu | New | Right-click message → "Responder" option in context menu (via Y6) |
| AD2 | Reply activation via hover button | New | Hover over message → ↩️ reply button appears |
| AD3 | Reply compose UI | New | Bar above input showing: "Respondendo a Mario" + quoted text preview + ✕ cancel |
| AD4 | Reply display in chat | New | Visual reply format with quoted original message and response below it |
| AD5 | Reply to own messages | New | Users can reply to their own messages (self-quote) |
| AD6 | Edit last message (↑ key) | New | Press ↑ in empty input to edit last sent message — input fills with message text |
| AD7 | Edit mode visual indicator | New | Message being edited gets distinct border/background, input shows "Editando" label |
| AD8 | Edit confirmation and display | New | Enter confirms edit, Esc cancels. Edited message shows "(editado)" tag |
| AD9 | Delete own message | New | Right-click own message → "Apagar mensagem" with confirmation dialog |
| AD10 | Delete display options | New | Configurable: deleted messages show "[mensagem removida]" or disappear entirely |
| AD11 | Edit/delete time limit | New | 5-minute window for edit/delete after sending, enforced server-side |

## Dependencies Detail

- AD1 (reply via context menu) uses Y6's message context menu — "Responder" is a menu item there
- AD2 (reply hover button) is self-contained — adds a hover overlay to message rows
- AD3 (reply compose UI) modifies the input area — adds a bar above the input field
- AD4 (reply display) extends message rendering to show quoted-reply format
- AD6 (edit via ↑) extends existing history navigation — when input is empty and ↑ is pressed
- AD9 (delete) uses Y6's message context menu — "Apagar" appears only on own messages
- AD11 (time limit) requires server-side enforcement in the Chat context

## Technical Notes

- Reply format in IRC: no standard protocol for replies. Use application-level convention:
  - Store reply metadata (original message ID) with the message in the database
  - Render as: "[timestamp] <Nick> ┌ OrigNick: 'quoted text' \n └ Reply text"
- Edit mechanism: messages need a unique ID to identify which message to edit
  - Store edits as updates to the message record in DB
  - Broadcast edit events via PubSub to update all viewers in real-time
  - Show "(editado)" suffix with tooltip showing edit timestamp
- Delete mechanism: soft-delete (mark as deleted in DB)
  - Broadcast delete events via PubSub
  - Configurable display: either "[mensagem removida]" placeholder or remove from stream
- 5-minute edit/delete window: check message timestamp server-side before allowing edit/delete
- Reply compose bar: similar to Discord/Slack — shows above the input with context and cancel button
- ↑ for edit: only triggers on own messages, only the last message, only within 5-minute window

---

## Spec Command

```
/speckit.specify "Quote/Reply & Message Edit/Delete for RetroHexChat.

PROBLEM: Users cannot reference or respond to specific messages in the conversation. In busy channels, it is impossible to indicate which message you are replying to, leading to confusion. Users also cannot correct typos in messages they just sent or delete messages sent by mistake. These are standard features in every modern chat application (Discord, Slack, Telegram) that IRC traditionally lacks. Without them, conversations in active channels become hard to follow and typos persist forever.

EXISTING CONTEXT: No message interaction features are currently implemented. Messages are displayed as a flat chronological stream. The input history navigation (↑/↓ arrows) exists for command history but does not support message editing. Messages have unique IDs in the database. Category Y provides a message context menu (Y6) where 'Responder' and 'Apagar' items will be added.

USER JOURNEY — QUOTE/REPLY: A user sees a message from Mario: 'eu acho que devíamos usar Elixir'. They want to respond specifically to this message. They either right-click the message and select 'Responder', or hover over it and click the ↩️ button that appears. A bar appears above the input: 'Respondendo a Mario — eu acho que devíamos usar Elixir ✕'. They type their response: 'Concordo 100%!' and press Enter. The message appears in the chat with a visual reply format: a quoted block showing the original message from Mario, with their response below it. Other users see the same visual format, clearly linking the reply to the original. Clicking the quoted part scrolls to and highlights the original message.

USER JOURNEY — MESSAGE EDIT: A user sends a message with a typo: 'I thnk this is great'. They realize the mistake and press ↑ in the now-empty input. The input fills with their last message text, and the message in the chat gets a distinct border indicating edit mode. They fix the typo to 'I think this is great' and press Enter. The message updates in place for all viewers with a small '(editado)' tag. Hovering over '(editado)' shows the edit timestamp. Pressing Esc instead of Enter cancels the edit and restores the input. Editing is only available within 5 minutes of sending.

USER JOURNEY — MESSAGE DELETE: A user accidentally sends a message to the wrong channel. They right-click the message and select 'Apagar mensagem'. A confirmation dialog appears: 'Apagar esta mensagem?' with Confirm/Cancel buttons. After confirming, the message is replaced with '[mensagem removida]' for all viewers (or disappears entirely, depending on settings). Deletion is only available within 5 minutes and only for the user's own messages.

ACTORS: Any connected user (guest or registered) can reply to any message. Users can only edit or delete their own messages. Channel operators cannot edit/delete other users' messages. The 5-minute time limit applies equally to all users.

EDGE CASES: Replying to a message that has been deleted should show 'Respondendo a [mensagem removida]'. Editing a message that someone has already replied to should update the quote in the reply. If the original message is very long, the reply preview should truncate it. The ↑ key for editing must not trigger if there are messages from other users after the user's last message (ambiguity). If the 5-minute window expires while the user is editing, the edit should still be accepted (grace period for in-progress edits). Rapid successive edits should debounce to prevent spam. Messages edited to be empty should be treated as deletion.

NEGATIVE REQUIREMENTS: Users must NOT be able to edit or delete other users' messages. The edit/delete time limit must be enforced server-side, not just client-side. Edited messages must NOT lose their reply context (if a message was a reply, editing keeps the reply reference). Delete must be soft-delete — the message record remains in the database for audit. The reply quote must NOT be editable by the replier. The ↑ shortcut for edit must NOT interfere with normal history navigation in a non-empty input.

SCOPE: In scope — reply via context menu and hover button, reply compose UI above input, visual reply format in chat, edit last message via ↑ key, edit mode visual indicators, edit confirmation with '(editado)' tag, delete via context menu with confirmation, configurable delete display, 5-minute edit/delete window with server-side enforcement. Out of scope — threading (replies do not create threads), message reactions/emoji, message pinning, edit history (only latest version shown), forwarding messages."
```
