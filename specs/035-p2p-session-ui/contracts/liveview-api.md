# LiveView API Contracts: 035-p2p-session-ui

## P2PSessionLive

**Route**: `GET /p2p/:token`
**Module**: `RetroHexChatWeb.P2PSessionLive`

### Mount

```elixir
@spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}

# Params: %{"token" => token_string}
# Session: %{"chat_nickname" => nickname} (from encrypted cookie)

# Flow:
# 1. Extract nickname from http_session (redirect to / if missing)
# 2. Verify nickname is registered (redirect to / if guest)
# 3. Fetch session by token (redirect to /chat with flash if not found)
# 4. Verify user is creator or peer (render 404 if unauthorized)
# 5. Check session not terminal (redirect to /chat with flash if expired/closed)
# 6. Call P2P.join_session(token, user_id)
# 7. Subscribe to "p2p:#{token}" PubSub topic
# 8. Initialize assigns: session, peer_nick, messages, action_request, capabilities, etc.
```

### Assigns

```elixir
%{
  # Session state
  session: Session.t(),           # DB session record
  token: String.t(),              # session token
  nickname: String.t(),           # current user's nick
  user_id: integer(),             # current user's registered_nick ID
  peer_nick: String.t(),          # other peer's nick
  peer_online: boolean(),         # peer presence in lobby
  role: :creator | :peer,         # current user's role

  # Lobby state
  messages: list(map()),          # ephemeral chat messages (from GenServer)
  action_request: map() | nil,    # current pending action request

  # Browser capabilities (filled async by JS hook)
  capabilities: %{
    webrtc: boolean() | nil,
    get_user_media: boolean() | nil,
    data_channel: boolean() | nil
  },

  # UI state
  session_status: String.t(),     # "pending" | "lobby" | "connecting" | ...
  inactivity_warning: boolean()   # show warning banner
}
```

### handle_info (PubSub broadcasts)

```elixir
# Peer status changes
def handle_info(%{event: "p2p_status_changed", payload: %{status: status}}, socket)
# → update session_status assign, redirect if terminal

# Lobby message received
def handle_info(%{event: "p2p_lobby_message", payload: msg}, socket)
# → append to messages list

# Action request from peer
def handle_info(%{event: "p2p_action_request", payload: request}, socket)
# → set action_request assign (only if from other peer)

# Action response from peer
def handle_info(%{event: "p2p_action_response", payload: response}, socket)
# → update action_request, trigger permission request if accepted

# Action expired
def handle_info(%{event: "p2p_action_expired", payload: _}, socket)
# → clear action_request, show "Pedido expirou" system message

# Session closed
def handle_info(%{event: "p2p_session_closed", payload: %{reason: reason}}, socket)
# → redirect to /chat with flash message

# Inactivity warning
def handle_info(%{event: "p2p_inactivity_warning", payload: %{expires_in_seconds: secs}}, socket)
# → set inactivity_warning: true, show countdown
```

### handle_event (client events)

```elixir
def handle_event("send_lobby_message", %{"content" => content}, socket)
# → P2P.send_lobby_message(token, user_id, content)

def handle_event("request_action", %{"action_type" => type}, socket)
# → P2P.request_action(token, user_id, type)

def handle_event("respond_action", %{"accepted" => accepted}, socket)
# → P2P.respond_action(token, user_id, accepted)
# If accepted: push_event("p2p_request_permission", %{type: permission_type})

def handle_event("close_session", _, socket)
# → P2P.close_session(token, user_id, "user_closed")
# → redirect to /chat

def handle_event("p2p_capabilities", capabilities, socket)
# → assign capabilities map

def handle_event("p2p_leave", _, socket)
# → P2P.close_session(token, user_id, "tab_closed")

def handle_event("permission_result", %{"granted" => granted, "type" => type}, socket)
# → If both peers granted: transition to "connecting"
# → If denied: show error, offer retry
```

### terminate/2

```elixir
@spec terminate(term(), Phoenix.LiveView.Socket.t()) :: term()
def terminate(_reason, socket) do
  # Close session if still active (handles tab close, navigation away)
  # Only close if not already closed (avoid double-close race)
end
```

## Components

### p2p_lobby (function component)

```elixir
attr :session, :map, required: true
attr :nickname, :string, required: true
attr :peer_nick, :string, required: true
attr :peer_online, :boolean, required: true
attr :messages, :list, required: true
attr :action_request, :map, default: nil
attr :capabilities, :map, required: true
attr :session_status, :string, required: true
attr :inactivity_warning, :boolean, default: false
```

### p2p_presence (function component)

```elixir
attr :nickname, :string, required: true
attr :peer_nick, :string, required: true
attr :peer_online, :boolean, required: true
```

### p2p_chat (function component)

```elixir
attr :messages, :list, required: true
attr :nickname, :string, required: true
```

### p2p_actions (function component)

```elixir
attr :capabilities, :map, required: true
attr :action_request, :map, default: nil
attr :nickname, :string, required: true
attr :peer_nick, :string, required: true
attr :session_status, :string, required: true
```
