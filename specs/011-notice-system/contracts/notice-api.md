# Internal API Contracts: Notice System

**Feature**: 011-notice-system
**Date**: 2026-02-12

## Command Handlers

### `/notice` — `RetroHexChat.Commands.Handlers.Notice`

**Behaviour**: `RetroHexChat.Commands.Handler`

```text
validate("") → {:error, "Usage: /notice <target> <message>"}
validate(_)  → :ok

execute([], context)            → {:error, "Usage: /notice <target> <message>"}
execute([_target], context)     → {:error, "No message specified. Usage: /notice <target> <message>"}
execute([target | rest], context) →
  content = Enum.join(rest, " ")
  {:ok, :notice, %{target: target, content: content}}

help() → %{
  name: "notice",
  syntax: "/notice <target> <message>",
  description: "Send a notice to a user or channel. Notices use -Nick- formatting and do not open PM windows.",
  examples: [
    "/notice Alice Check out #project",
    "/notice #elixir Server maintenance in 30 minutes"
  ]
}
```

**Result type**: `{:ok, :notice, %{target: String, content: String}}`

---

### `/notice_routing` — `RetroHexChat.Commands.Handlers.NoticeRouting`

**Behaviour**: `RetroHexChat.Commands.Handler`

```text
validate(_) → :ok

execute([], context) →
  {:ok, :ui_action, :notice_routing_show, %{}}

execute(["active"], context)  → {:ok, :ui_action, :notice_routing_set, %{routing: :active}}
execute(["status"], context)  → {:ok, :ui_action, :notice_routing_set, %{routing: :status}}
execute(["sender"], context)  → {:ok, :ui_action, :notice_routing_set, %{routing: :sender}}
execute([invalid], context)   → {:error, "Invalid routing option '#{invalid}'. Valid options: active, status, sender"}

help() → %{
  name: "notice_routing",
  syntax: "/notice_routing [active|status|sender]",
  description: "Set or view where incoming notices are displayed.",
  examples: [
    "/notice_routing",
    "/notice_routing active",
    "/notice_routing status",
    "/notice_routing sender"
  ]
}
```

**Result types**:
- `{:ok, :ui_action, :notice_routing_show, %{}}` — display current preference
- `{:ok, :ui_action, :notice_routing_set, %{routing: atom}}` — set preference

---

## Domain Module

### `RetroHexChat.Chat.NoticeRouting`

```text
# In-memory CRUD
new()                           → %{routing: :active}
get_routing(settings)           → :active | :status | :sender
set_routing(settings, routing)  → %{routing: routing}

# Persistence (registered users only)
save(owner_nickname, settings)  → :ok | {:error, term()}
load(owner_nickname)            → {:ok, %{routing: atom}} | {:error, :not_found}
```

---

## Session Extensions

### `RetroHexChat.Accounts.Session`

```text
# New field
notice_routing: :active | :status | :sender  (default: :active)

# New functions
get_notice_routing(session)              → :active | :status | :sender
set_notice_routing(session, routing)     → session
```

---

## ChatLive Dispatch Result Handler

### `handle_dispatch_result` for `:notice`

```text
handle_dispatch_result(socket, session, {:ok, :notice, %{target: "#" <> _ = channel, content: content}}) →
  # Channel notice: validate membership, broadcast to channel topic
  if channel in session.channels →
    broadcast("channel:#{channel}", %{event: "new_notice", payload: %{author: session.nickname, content: content, channel: channel, timestamp: now}})
    stream_insert(socket, :chat_messages, notice_message(session.nickname, content))  # sender sees it too
  else →
    stream_insert(socket, :chat_messages, error_message("You must be a member of #{channel} to send notices there"))

handle_dispatch_result(socket, session, {:ok, :notice, %{target: nickname, content: content}}) →
  # User notice: validate user exists, broadcast to user topic
  if user_online?(nickname) →
    broadcast("user:#{nickname}", {:new_notice, %{sender: session.nickname, content: content, timestamp: now}})
    socket  # sender sees nothing (notices are fire-and-forget)
  else →
    stream_insert(socket, :chat_messages, error_message("User not found: #{nickname}"))
```

---

## ChatLive PubSub Handlers

### `handle_info` for user notice

```text
handle_info({:new_notice, %{sender: sender, content: content}}, socket) →
  session = socket.assigns.session
  if IgnoreList.ignored?(session.ignore_list, sender, :notice) →
    {:noreply, socket}
  else →
    notice = notice_message(sender, content)
    socket = route_notice(socket, session, notice, sender)
    {:noreply, socket}
```

### `handle_info` for channel notice

```text
handle_info(%{event: "new_notice", payload: %{author: author, channel: channel}}, socket) →
  session = socket.assigns.session
  if IgnoreList.ignored?(session.ignore_list, author, :notice) →
    {:noreply, socket}
  else →
    # Always display in channel window (routing does not apply to channel notices)
    if channel == session.active_channel →
      stream_insert(socket, :chat_messages, notice_message(author, content))
    else →
      # Channel is not active — accumulate as unread (no sound)
      socket
    {:noreply, socket}
```

---

## Routing Logic

### `route_notice(socket, session, notice, sender)`

```text
case Session.get_notice_routing(session) →
  :active →
    stream_insert(socket, :chat_messages, notice)

  :status →
    if socket.assigns.show_status_tab →
      push_status_message(socket, format_notice_for_status(sender, content), :service)
    else →
      stream_insert(socket, :chat_messages, notice)  # fallback to active

  :sender →
    if sender in session.pm_conversations →
      # Insert into PM stream if sender's PM window exists
      # (details depend on how PM messages are streamed)
      stream_insert(socket, :chat_messages, notice)  # when PM is active
    else →
      stream_insert(socket, :chat_messages, notice)  # fallback to active
```

---

## ChatMessage Component Extension

### New rendering clause for `:notice` type

```text
render_message_body(%{message: %{type: :notice}} = assigns) →
  <span class="chat-notice">
    <span class="chat-notice-nick">-{author}-</span>
    <span class="chat-notice-content">{content}</span>
  </span>
```

---

## UI Action Handlers

### `:notice_routing_show`

```text
handle_ui_action(socket, :notice_routing_show, %{}) →
  routing = Session.get_notice_routing(session)
  push_status_message(socket, "Notice routing is set to: #{routing}", :system)
```

### `:notice_routing_set`

```text
handle_ui_action(socket, :notice_routing_set, %{routing: routing}) →
  session = Session.set_notice_routing(session, routing)
  if session.identified → Task.start(fn -> NoticeRouting.save(session.nickname, ...) end)
  push_status_message(socket, "Notice routing set to: #{routing}", :system)
```

---

## Helper Functions

### `notice_message(author, content)`

```text
notice_message(author, content) → %{
  id: "notice-#{System.unique_integer([:positive])}",
  author: author,
  content: content,
  type: :notice,
  timestamp: DateTime.utc_now()
}
```
