# Elixir Contracts: WebRTC Signaling (036)

## Turn Server Modules (extracted from rel)

### RetroHexChat.P2P.Turn.Supervisor

```elixir
@spec start_link(keyword()) :: Supervisor.on_start()
# Starts: ListenerSupervisor + DynamicSupervisor (AllocationSupervisor) + Registry
```

### RetroHexChat.P2P.Turn.Auth

```elixir
@spec generate_credentials(String.t()) :: %{
  username: String.t(),
  password: String.t(),
  ttl: non_neg_integer(),
  uris: [String.t()]
}

@spec authenticate(ExSTUN.Message.t(), map()) :: :ok | {:error, atom()}
```

### RetroHexChat.P2P.Turn.Listener

```elixir
# Task (restart: :permanent) — UDP recv_loop on STUN/TURN port
@spec start_link(keyword()) :: {:ok, pid()}
```

### RetroHexChat.P2P.Turn.AllocationHandler

```elixir
# GenServer (restart: :transient) — one per TURN allocation
@spec start_link(keyword()) :: GenServer.on_start()
```

## Signaling Contracts

### RetroHexChat.P2P (facade additions)

```elixir
@spec ice_servers(String.t()) :: [map()]
# Returns ICE server config with TURN credentials for a given user_id

@spec validate_signal(map()) :: {:ok, map()} | {:error, :invalid_signal}
# Validates signal message format (type, sdp/candidate)
```

### RetroHexChat.P2P.SignalingRateLimit (behaviour)

```elixir
@callback check_signal_rate(String.t(), integer()) :: :ok | {:error, :rate_limited}
# session_token, user_id → rate check result
```

## LiveView Event Contracts

### Client → Server (handle_event)

```elixir
# Signal relay
handle_event("p2p_signal", %{"type" => type, "sdp" => sdp}, socket)
handle_event("p2p_signal", %{"type" => "ice-candidate", "candidate" => candidate}, socket)

# Connection state notifications
handle_event("p2p_connected", %{}, socket)
handle_event("p2p_failed", %{"reason" => reason}, socket)
handle_event("p2p_retry", %{"attempt" => attempt}, socket)
```

### Server → Client (push_event)

```elixir
# Initiate connection (sent to creator only)
push_event(socket, "p2p_start_offer", %{
  ice_servers: [%{urls: [...], username: "...", credential: "..."}],
  role: "initiator"
})

# Initiate connection (sent to peer)
push_event(socket, "p2p_start_answer", %{
  ice_servers: [%{urls: [...], username: "...", credential: "..."}]
})

# Relay signal from peer
push_event(socket, "p2p_signal", %{type: "offer" | "answer" | "ice-candidate", ...})
```

### PubSub Messages (p2p:#{token})

```elixir
# New message type for signaling
%{event: "p2p_signal", payload: %{type: String.t(), from: integer(), ...}}
```
