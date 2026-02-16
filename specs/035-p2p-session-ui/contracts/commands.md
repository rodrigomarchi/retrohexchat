# Command Contracts: 035-p2p-session-ui

## /p2p Command Handler

**Module**: `RetroHexChat.Commands.Handlers.P2p`
**Category**: `:user`

```elixir
@spec validate(String.t()) :: :ok | {:error, String.t()}
# validate("") → {:error, "Usage: /p2p <nickname>"}
# validate("mario") → :ok

@spec execute([String.t()], Handler.context()) :: Handler.result()
# execute(["mario"], ctx) → {:ok, :ui_action, :p2p_invite, %{target: "mario", session_type: "generic"}}
# execute(["mario"], ctx) when mario offline → {:error, "mario is not online"}
# execute(["mario"], ctx) when policy fails → {:error, reason}

@spec help() :: map()
# %{name: "p2p", syntax: "/p2p <nickname>", description: "Start a P2P session", examples: ["/p2p mario"]}

@spec category() :: :user
```

## /call Command Handler

**Module**: `RetroHexChat.Commands.Handlers.Call`
**Category**: `:user`

```elixir
@spec validate(String.t()) :: :ok | {:error, String.t()}
# validate("") → {:error, "Usage: /call <nickname>"}
# validate("mario") → :ok

@spec execute([String.t()], Handler.context()) :: Handler.result()
# execute(["mario"], ctx) → {:ok, :ui_action, :p2p_invite, %{target: "mario", session_type: "audio_call"}}

@spec help() :: map()
# %{name: "call", syntax: "/call <nickname>", description: "Start an audio call", examples: ["/call mario"]}

@spec category() :: :user
```

## /sendfile Command Handler

**Module**: `RetroHexChat.Commands.Handlers.SendFile`
**Category**: `:user`

```elixir
@spec validate(String.t()) :: :ok | {:error, String.t()}
# validate("") → {:error, "Usage: /sendfile <nickname>"}
# validate("mario") → :ok

@spec execute([String.t()], Handler.context()) :: Handler.result()
# execute(["mario"], ctx) → {:ok, :ui_action, :p2p_invite, %{target: "mario", session_type: "file_transfer"}}

@spec help() :: map()
# %{name: "sendfile", syntax: "/sendfile <nickname>", description: "Send a file", examples: ["/sendfile mario"]}

@spec category() :: :user
```

## Shared P2P Handler Logic

All three handlers delegate to `RetroHexChat.P2P.create_session/3`:

```elixir
# Common pattern in execute/2:
defp do_execute(target, session_type, context) do
  with {:ok, target_id} <- resolve_registered_nick(target),
       {:ok, creator_id} <- resolve_registered_nick(context.nickname),
       {:ok, result} <- RetroHexChat.P2P.create_session(creator_id, target_id, session_type: session_type) do
    {:ok, :ui_action, :p2p_invite, %{
      target: target,
      session_type: session_type,
      token: result.token
    }}
  else
    {:error, reason} -> {:error, format_error(reason)}
  end
end
```
