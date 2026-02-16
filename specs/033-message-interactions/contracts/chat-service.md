# Contracts: Chat Service (Message Interactions)

**Feature Branch**: `033-message-interactions`
**Date**: 2026-02-16

## Domain Layer (RetroHexChat.Chat)

### Chat.Service

```
send_message/4 (existing — extended)
  Input: channel_name :: String, nickname :: String, content :: String, type :: String
  Options: reply_to_id :: integer | nil (NEW)
  Output: {:ok, Message.t()} | {:error, String.t()}
  Side effects: Broadcasts "new_message" with reply fields in payload
  Reply snapshot: Truncates parent content to 100 chars for reply_to_preview

edit_message/3 (NEW)
  Input: message_id :: integer, nickname :: String, new_content :: String
  Output: {:ok, Message.t()} | {:error, String.t()}
  Preconditions:
    - Message exists and is not deleted
    - nickname matches message.author_nickname (or session for guests)
    - Within 5-minute window (≤300s) or grace period (+120s if edit started in window)
    - Debounce: 3s since last edit (compared against edited_at)
    - new_content passes Policy.validate_content/1
  Side effects:
    - Updates message content and edited_at in DB
    - Broadcasts "message_edited" to channel topic
    - Updates reply_to_preview in all replies to this message (bulk update)
    - Broadcasts "reply_quote_updated" if replies exist
  Error messages:
    - "Tempo para edição expirou." (window + grace expired)
    - "Aguarde alguns segundos antes de editar novamente." (debounce)
    - "Você não pode editar mensagens de outros usuários." (author mismatch)

delete_message/2 (NEW)
  Input: message_id :: integer, nickname :: String
  Output: {:ok, Message.t()} | {:error, String.t()}
  Preconditions:
    - Message exists and is not already deleted
    - nickname matches message.author_nickname (or session for guests)
    - Within 5-minute window (≤300s) — NO grace period
  Side effects:
    - Sets deleted_at in DB (soft delete)
    - Broadcasts "message_deleted" to channel topic
  Error messages:
    - "Tempo para exclusão expirou." (window expired)
    - "Você não pode apagar mensagens de outros usuários." (author mismatch)
```

### Chat.Service (Private Messages)

```
send_private_message/4 (existing — extended)
  Input: sender :: String, recipient :: String, content :: String, type :: String
  Options: reply_to_id :: integer | nil (NEW)
  Output: {:ok, PrivateMessage.t()} | {:error, String.t()}

edit_private_message/3 (NEW)
  Input: pm_id :: integer, nickname :: String, new_content :: String
  Output: {:ok, PrivateMessage.t()} | {:error, String.t()}
  (Same preconditions and error messages as edit_message)

delete_private_message/2 (NEW)
  Input: pm_id :: integer, nickname :: String
  Output: {:ok, PrivateMessage.t()} | {:error, String.t()}
  (Same preconditions and error messages as delete_message)
```

### Chat.Policy (extended)

```
can_edit?/2 (NEW)
  Input: message :: Message.t() | PrivateMessage.t(), nickname :: String
  Output: :ok | {:error, String.t()}
  Checks:
    - Author match (nickname == message.author_nickname)
    - Not deleted (deleted_at == nil)
    - Within 5-minute window (≤300s inclusive from inserted_at)
    - Debounce (3s since last edit — edited_at check)
  Note: Grace period (+120s) is handled at Service level, not Policy

can_edit_with_grace?/3 (NEW)
  Input: message :: Message.t() | PrivateMessage.t(), nickname :: String, edit_started_at :: DateTime
  Output: :ok | {:error, String.t()}
  Checks: Same as can_edit?/2 but allows up to 7 minutes total if edit_started_at is within window

can_delete?/2 (NEW)
  Input: message :: Message.t() | PrivateMessage.t(), nickname :: String
  Output: :ok | {:error, String.t()}
  Checks:
    - Author match
    - Not already deleted
    - Within 5-minute window (≤300s inclusive from inserted_at) — NO grace period
```

### Chat.Queries (extended)

```
get_message/1 (NEW)
  Input: id :: integer
  Output: Message.t() | nil

get_private_message/1 (NEW)
  Input: id :: integer
  Output: PrivateMessage.t() | nil

update_message_content/3 (NEW)
  Input: message :: Message.t(), new_content :: String, edited_at :: DateTime
  Output: {:ok, Message.t()} | {:error, Changeset.t()}

soft_delete_message/2 (NEW)
  Input: message :: Message.t(), deleted_at :: DateTime
  Output: {:ok, Message.t()} | {:error, Changeset.t()}

update_reply_previews/2 (NEW)
  Input: parent_id :: integer, new_preview :: String
  Output: {count :: integer, nil}
  (Bulk update all messages where reply_to_id = parent_id)
  Note: For messages with many replies, this is a single UPDATE WHERE query

get_reply_ids/1 (NEW)
  Input: parent_id :: integer
  Output: [integer]

(Same functions for private messages with _pm suffix)
```

## Web Layer (LiveView Events)

### Client → Server Events

```
"reply_to_message" (NEW)
  Payload: %{"message_id" => integer}
  Action: Cancels edit mode if active (FR-025), then sets reply mode in socket assigns

"cancel_reply" (NEW)
  Payload: %{}
  Action: Clears reply mode

"edit_last_message" (NEW)
  Payload: %{}
  Action: Cancels reply mode if active (FR-025), enters edit mode for user's last message
  Prechecks: Last message is most recent in channel, within 5 minutes, confirmed (has server ID)

"cancel_edit" (NEW)
  Payload: %{}
  Action: Clears edit mode, pushes "exit_edit_mode" to client

"submit_edit" (NEW)
  Payload: %{"content" => string}
  Action: If content empty → open delete dialog (FR-020). Otherwise call Chat.Service.edit_message/3

"delete_message" (NEW)
  Payload: %{"message_id" => integer}
  Action: Calls Chat.Service.delete_message/2

"ctx_chat_reply" (NEW — context menu)
  Payload: %{"message_id" => integer}
  Action: Same as "reply_to_message"

"ctx_chat_delete" (NEW — context menu)
  Payload: %{"message_id" => integer}
  Action: Opens delete confirmation dialog (replaces any existing open dialog — FR-013)

"scroll_to_reply_parent" (NEW)
  Payload: %{"parent_id" => integer}
  Action: Pushes "scroll_to_message" event to client if parent message is in loaded stream

"confirm_delete" (NEW)
  Payload: %{}
  Action: Calls Chat.Service.delete_message/2 with stored message_id, closes dialog

"cancel_delete" (NEW)
  Payload: %{}
  Action: Closes delete confirmation dialog
```

### Server → Client Events (push_event)

```
"enter_edit_mode" (NEW)
  Payload: %{message_id: integer, content: string}
  Action: JS fills input with message content (raw, including format codes), adds .chat-message--editing class

"exit_edit_mode" (NEW)
  Payload: %{message_id: integer}
  Action: JS clears edit state, removes .chat-message--editing class, restores input

"scroll_to_message" (NEW)
  Payload: %{message_id: integer}
  Action: JS scrolls to target message and applies 2-second yellow background fade highlight.
          If message not found in DOM (pagination boundary), silently ignores.
```

### PubSub → LiveView (handle_info)

```
%{event: "message_edited", payload: %{id, content, edited_at}}
  Action: Update message in stream via stream_insert with new content and edited_at

%{event: "message_deleted", payload: %{id, deleted_at}}
  Action: Update message in stream with deleted_at set (component renders "[mensagem removida]")

%{event: "reply_quote_updated", payload: %{parent_id, new_preview, reply_ids}}
  Action: Update reply_to_preview in stream for affected reply messages
```

## Component Contracts

### ReplyComposeBar (NEW)

```
Attributes:
  reply_to :: map | nil  (%{id, author, preview})

Renders: Bar with "Respondendo a {author} — {preview} ✕"
  - preview is pre-truncated to 100 chars
  - "✕" button has tabindex="0" for keyboard accessibility (FR-028)
  - Escape key also dismisses (FR-002)
Events:
  phx-click="cancel_reply" on ✕ button
  ARIA: role="status", aria-live="polite" for screen reader announcement
```

### ChatMessage (extended)

```
New rendering:
  If message has reply_to_id:
    Render reply block above content with:
      - reply_to_author
      - reply_to_preview (or "[mensagem removida]" if parent deleted/NULL)
      - phx-click="scroll_to_reply_parent" with parent ID
      - Indented with left border in author's nick color
      - ARIA: role="link" for screen reader (FR-029)

  If message has edited_at:
    Append "(editado)" span with:
      - title={formatted edited_at in "HH:MM DD/MM/YYYY" UTC}
      - tabindex="0" for keyboard focus (FR-028)
      - ARIA: aria-label="Editado às {timestamp}"

  If message has deleted_at:
    Replace entire content with "[mensagem removida]" in --system-messages-color
    Show timestamp, hide author nick
    ARIA: aria-label="Mensagem removida" (FR-029)

  If message is being edited (edit_mode_message_id matches):
    Add .chat-message--editing class (dashed border in highlight color — FR-006)

  Nested reply: Only shows immediate parent quote (no recursion — flat display)
```

### DeleteConfirmDialog (NEW)

```
Attributes:
  visible :: boolean
  message_id :: integer | nil

Renders: "Apagar esta mensagem?" with "Confirmar" / "Cancelar" buttons
  - Only one instance at a time (new request replaces old — FR-013)
  - Escape key closes dialog (same as "Cancelar")
Events:
  phx-click="confirm_delete" → triggers delete_message
  phx-click="cancel_delete" → closes dialog
```
