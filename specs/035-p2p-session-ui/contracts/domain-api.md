# Domain API Contracts: 035-p2p-session-ui

## P2P Context — New Public Functions

### RetroHexChat.P2P (facade)

```elixir
# Existing (unchanged)
@spec create_session(integer(), integer(), keyword()) :: {:ok, %{session: Session.t(), token: String.t()}} | {:error, atom() | String.t()}
@spec join_session(String.t(), integer()) :: :ok | {:error, atom()}
@spec close_session(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
@spec get_session(String.t()) :: {:ok, Session.t()} | {:error, :not_found}
@spec transition_status(String.t(), String.t()) :: :ok | {:error, atom()}
@spec session_info(String.t()) :: {:ok, map()} | {:error, atom()}

# New lobby functions
@spec send_lobby_message(String.t(), integer(), String.t(), String.t()) :: :ok | {:error, atom()}
@spec request_action(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
@spec respond_action(String.t(), integer(), boolean()) :: :ok | {:error, atom()}
```

### P2P.SessionServer — New API

```elixir
# New functions (added to existing module)
@spec send_message(String.t(), integer(), String.t(), String.t()) :: :ok | {:error, atom()}
# send_message(token, user_id, sender_nick, content)
# Adds message to state, broadcasts p2p_lobby_message, resets activity timer
# Returns :ok or {:error, :not_in_lobby | :content_too_long}

@spec request_action(String.t(), integer(), String.t(), String.t()) :: :ok | {:error, atom()}
# request_action(token, requester_id, requester_nick, action_type)
# Sets action_request in state, starts 60s timer, broadcasts p2p_action_request
# Returns :ok or {:error, :not_in_lobby | :request_pending}

@spec respond_action(String.t(), integer(), String.t(), boolean()) :: :ok | {:error, atom()}
# respond_action(token, responder_id, responder_nick, accepted?)
# Updates action_request status, broadcasts p2p_action_response
# If accepted: transition to "connecting" state
# Returns :ok or {:error, :not_in_lobby | :no_pending_request | :cannot_respond_own}
```

### P2P.Service — New Functions

```elixir
@spec send_lobby_message(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
# Validates content, resolves nick, delegates to SessionServer.send_message

@spec request_action(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
# Validates action_type, resolves nick, delegates to SessionServer.request_action

@spec respond_action(String.t(), integer(), boolean()) :: :ok | {:error, atom()}
# Resolves nick, delegates to SessionServer.respond_action
```

## Chat Context — PM Type Extension

### RetroHexChat.Chat.PrivateMessage

No schema migration needed. Add `"p2p_invite"` to the allowed `type` values in the changeset validation.

```elixir
# Current: validate_inclusion(:type, ~w(message action))
# Updated: validate_inclusion(:type, ~w(message action p2p_invite))
```

### P2P Invitation PM Content Format

```elixir
# Content for p2p_invite type PM:
# Generic: "P2P session started. Join the lobby: /p2p/{token}"
# Audio call: "Audio call invitation. Join the lobby: /p2p/{token}"
# File transfer: "File transfer invitation. Join the lobby: /p2p/{token}"
```

## LiveView Events

### P2PSessionLive — Client → Server Events

| Event | Payload | Handler |
|-------|---------|---------|
| send_lobby_message | %{"content" => text} | handle_event |
| request_action | %{"action_type" => type} | handle_event |
| respond_action | %{"accepted" => bool} | handle_event |
| close_session | %{} | handle_event |
| p2p_capabilities | %{"webrtc" => bool, "getUserMedia" => bool} | handle_event |
| p2p_leave | %{} | handle_event (beforeunload) |

### P2PSessionLive — Server → Client Events (push_event)

| Event | Payload | JS Handler |
|-------|---------|------------|
| p2p_request_permission | %{type: "microphone" \| "camera"} | P2PCapabilityHook |
| p2p_redirect | %{to: "/chat", flash: "..."} | P2PSessionHook |

### ChatLive — New Events for P2P Invitation

| Event | Source | Handler |
|-------|--------|---------|
| accept_p2p | Toast button click (JS) | handle_event → navigate to /p2p/:token |
| reject_p2p | Toast button click (JS) | handle_event → P2P.close_session(token, user_id, "rejected") |

### ChatLive — CommandDispatch Extension

New result type in `handle_dispatch_result/3`:

```elixir
defp handle_dispatch_result(socket, session, {:ok, :ui_action, :p2p_invite, payload}) do
  # 1. Send PM invitation via Chat.Service.send_private_message/5
  # 2. Push toast notification to peer via PubSub
  # 3. Show system message to initiator confirming session creation
  socket
end
```
